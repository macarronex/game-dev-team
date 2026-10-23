extends SceneTree
## Procedural sound-effect generator (sfxr-style): JSON spec -> 16-bit mono .wav files.
##
## Usage (from the repository root):
##   godot --headless --path godot -s res://tools/sfxgen.gd -- art_src/sfx/player.json [more.json ...]
##
## A spec file holds one sound object, an array of them, or {"sounds": [...]}.
## See .claude/skills/sfx-pipeline/SKILL.md for every parameter.

const PEAK_DBFS: float = -1.0

var _repo_root: String = ""


func _init() -> void:
	_repo_root = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("Usage: godot --headless --path godot -s res://tools/sfxgen.gd -- <spec.json> ...")
		quit(2)
		return
	var failed: int = 0
	for arg: String in args:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_resolve(arg)))
		var sounds: Array = []
		if parsed is Array:
			sounds = parsed
		elif parsed is Dictionary and (parsed as Dictionary).has("sounds"):
			sounds = (parsed as Dictionary)["sounds"]
		elif parsed is Dictionary:
			sounds = [parsed]
		else:
			printerr("[sfxgen] Invalid or unreadable JSON: %s" % arg)
			failed += 1
			continue
		for s: Variant in sounds:
			if not _generate(s as Dictionary):
				failed += 1
	quit(1 if failed > 0 else 0)


func _resolve(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	return _repo_root.path_join(path).simplify_path()


func _generate(spec: Dictionary) -> bool:
	if not spec.has("name"):
		printerr("[sfxgen] Every sound needs a 'name'")
		return false
	var sound_name: String = str(spec["name"])
	var variations: int = maxi(1, int(spec.get("variations", 1)))
	var jitter: float = float(spec.get("pitch_jitter", 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 1))
	var base_output: String = str(spec.get("output", "res://assets/audio/sfx/%s.wav" % sound_name))

	for v: int in variations:
		var pitch: float = 1.0
		if variations > 1:
			pitch = 1.0 + rng.randf_range(-jitter, jitter)
		var samples: PackedFloat32Array = _synthesize(spec, pitch, rng.randi())
		if samples.is_empty():
			printerr("[sfxgen] %s: duration must be > 0" % sound_name)
			return false
		var output: String = base_output
		if variations > 1:
			output = "%s_%d.wav" % [base_output.get_basename(), v + 1]
		if not _save_wav(samples, int(spec.get("sample_rate", 44100)), output):
			return false
		print(
			(
				"[sfxgen] OK %s (%.3fs, pitch x%.3f)"
				% [output, samples.size() / float(spec.get("sample_rate", 44100)), pitch]
			)
		)
	return true


func _synthesize(spec: Dictionary, pitch: float, noise_seed: int) -> PackedFloat32Array:
	var sr: int = int(spec.get("sample_rate", 44100))
	var duration: float = float(spec.get("duration", 0.3))
	var n: int = int(duration * sr)
	var out: PackedFloat32Array = PackedFloat32Array()
	if n <= 0:
		return out
	out.resize(n)

	var wave: String = str(spec.get("wave", "square"))
	var f0: float = maxf(1.0, float(spec.get("freq_start", 440.0))) * pitch
	var f1: float = maxf(1.0, float(spec.get("freq_end", spec.get("freq_start", 440.0)))) * pitch
	var curve: String = str(spec.get("freq_curve", "linear"))
	var duty: float = clampf(float(spec.get("duty", 0.5)), 0.05, 0.95)
	var attack: float = maxf(0.0, float(spec.get("attack", 0.005)))
	var decay: float = maxf(0.0, float(spec.get("decay", 0.05)))
	var sustain_level: float = clampf(float(spec.get("sustain", 0.7)), 0.0, 1.0)
	var release: float = maxf(0.001, float(spec.get("release", 0.1)))
	var sustain_time: float = maxf(0.0, duration - attack - decay - release)
	var vib_depth: float = float(spec.get("vibrato_depth", 0.0))
	var vib_rate: float = float(spec.get("vibrato_rate", 0.0))
	var noise_mix: float = clampf(float(spec.get("noise_mix", 0.0)), 0.0, 1.0)
	var lowpass: float = clampf(float(spec.get("lowpass", 1.0)), 0.01, 1.0)
	var bits: int = int(spec.get("bitcrush", 0))
	var arpeggio: Array = spec.get("arpeggio", [])

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = noise_seed
	var phase: float = 0.0
	var noise_value: float = rng.randf_range(-1.0, 1.0)
	var noise_phase: float = 0.0
	var filtered: float = 0.0

	for i: int in n:
		var t: float = float(i) / sr
		var progress: float = float(i) / n
		var freq: float = (
			lerpf(f0, f1, progress) if curve == "linear" else f0 * pow(f1 / f0, progress)
		)
		for step: Variant in arpeggio:
			var step_d: Dictionary = step
			if t >= float(step_d.get("time", 0.0)):
				freq *= float(step_d.get("mult", 1.0))
		if vib_depth != 0.0 and vib_rate > 0.0:
			freq *= pow(2.0, vib_depth * sin(TAU * vib_rate * t) / 12.0)

		phase = fmod(phase + freq / sr, 1.0)
		noise_phase += freq * 2.0 / sr
		if noise_phase >= 1.0:
			noise_phase = fmod(noise_phase, 1.0)
			noise_value = rng.randf_range(-1.0, 1.0)

		var tone: float = 0.0
		match wave:
			"square":
				tone = 1.0 if phase < duty else -1.0
			"saw":
				tone = 2.0 * phase - 1.0
			"triangle":
				tone = 4.0 * absf(phase - 0.5) - 1.0
			"sine":
				tone = sin(TAU * phase)
			"noise":
				tone = noise_value
			_:
				tone = sin(TAU * phase)
		var sample: float = lerpf(tone, noise_value, noise_mix)

		filtered += lowpass * (sample - filtered)
		sample = filtered
		if bits > 0:
			var levels: float = pow(2.0, bits - 1)
			sample = round(sample * levels) / levels

		out[i] = sample * _envelope(t, attack, decay, sustain_level, sustain_time, release)

	# Normalize to the target peak, scaled by volume.
	var peak: float = 0.0
	for s: float in out:
		peak = maxf(peak, absf(s))
	if peak > 0.0:
		var target: float = (
			db_to_linear(PEAK_DBFS) * clampf(float(spec.get("volume", 0.8)), 0.0, 1.0)
		)
		var gain: float = target / peak
		for i: int in n:
			out[i] *= gain
	return out


func _envelope(t: float, a: float, d: float, s_level: float, s_time: float, r: float) -> float:
	if t < a:
		return t / a if a > 0.0 else 1.0
	t -= a
	if t < d:
		return lerpf(1.0, s_level, t / d)
	t -= d
	if t < s_time:
		return s_level
	t -= s_time
	return maxf(0.0, s_level * (1.0 - t / r))


func _save_wav(samples: PackedFloat32Array, sample_rate: int, output: String) -> bool:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	var abs_path: String = _resolve(output)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	if stream.save_to_wav(abs_path) != OK:
		printerr("[sfxgen] Cannot write %s" % abs_path)
		return false
	return true
