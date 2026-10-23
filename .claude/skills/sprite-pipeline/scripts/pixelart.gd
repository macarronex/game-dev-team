extends SceneTree
## Pixel-art generator: JSON spec -> spritesheet PNG + SpriteFrames .tres + upscaled preview.
##
## Usage (from the repository root):
##   godot --headless --path godot -s res://tools/pixelart.gd -- art_src/sprites/hero.json [more.json ...]
##
## Spec paths can be absolute, res:// or relative to the repository root (parent of godot/).
## See .claude/skills/sprite-pipeline/SKILL.md for the spec format.

const PREVIEW_SCALE: int = 8
const PREVIEW_DIR: String = "art_src/preview"
const CHECKER_A: Color = Color(0.80, 0.80, 0.80)
const CHECKER_B: Color = Color(0.60, 0.60, 0.60)

var _repo_root: String = ""


func _init() -> void:
	_repo_root = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr(
			"Usage: godot --headless --path godot -s res://tools/pixelart.gd -- <spec.json> ..."
		)
		quit(2)
		return
	var failed: int = 0
	for arg: String in args:
		if not _build(_resolve(arg)):
			failed += 1
	quit(1 if failed > 0 else 0)


func _resolve(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	if path.is_absolute_path():
		return path
	return _repo_root.path_join(path).simplify_path()


func _build(spec_path: String) -> bool:
	var text: String = FileAccess.get_file_as_string(spec_path)
	if text.is_empty():
		printerr("[pixelart] Cannot read spec: %s" % spec_path)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		printerr("[pixelart] Invalid JSON in %s" % spec_path)
		return false
	var spec: Dictionary = parsed
	var errors: PackedStringArray = PackedStringArray()

	var sprite_name: String = str(spec.get("name", spec_path.get_file().get_basename()))
	var size: Array = spec.get("frame_size", [16, 16])
	var fw: int = int(size[0])
	var fh: int = int(size[1])
	var out_scale: int = maxi(1, int(spec.get("scale", 1)))
	var output: String = str(spec.get("output", "res://assets/sprites/%s.png" % sprite_name))

	var palette: Dictionary = _parse_palette(spec.get("palette", {}), errors)
	var outline_key: String = str(spec.get("outline", ""))
	if outline_key != "" and not palette.has(outline_key):
		errors.append("outline '%s' is not a palette key" % outline_key)

	var animations: Array = spec.get("animations", [])
	if animations.is_empty():
		errors.append("'animations' is empty")

	# Decode every frame into an Image first, so references ("anim:index") can be resolved.
	var decoded: Dictionary = {}  # anim name -> Array[Image]
	var max_frames: int = 0
	for anim_v: Variant in animations:
		var anim: Dictionary = anim_v
		var anim_name: String = str(anim.get("name", "default"))
		var frames_img: Array[Image] = []
		var frames: Array = anim.get("frames", [])
		var flip_of: String = str(anim.get("flip_x_of", ""))
		if flip_of != "":
			if not decoded.has(flip_of):
				errors.append(
					"%s: flip_x_of '%s' must reference an earlier animation" % [anim_name, flip_of]
				)
			else:
				for src: Image in decoded[flip_of]:
					var flipped: Image = src.duplicate()
					flipped.flip_x()
					frames_img.append(flipped)
		for i: int in frames.size():
			var frame: Variant = frames[i]
			var where: String = "%s[%d]" % [anim_name, i]
			if frame is String:
				var img_ref: Image = _resolve_ref(str(frame), decoded, where, errors)
				if img_ref != null:
					frames_img.append(img_ref)
			elif frame is Array:
				var img: Image = _decode_frame(frame, fw, fh, palette, where, errors)
				if img != null:
					if outline_key != "" and palette.has(outline_key):
						_apply_outline(img, palette[outline_key])
					frames_img.append(img)
			else:
				errors.append(
					(
						"%s: a frame must be an array of row strings or an 'anim:index' reference"
						% where
					)
				)
		decoded[anim_name] = frames_img
		max_frames = maxi(max_frames, frames_img.size())

	if not errors.is_empty():
		printerr("[pixelart] %s has errors:" % spec_path)
		for e: String in errors:
			printerr("  - " + e)
		return false

	# Sheet layout: one row per animation, frames left to right.
	var sheet: Image = Image.create_empty(
		fw * max_frames, fh * animations.size(), false, Image.FORMAT_RGBA8
	)
	sheet.fill(Color(0, 0, 0, 0))
	var row: int = 0
	for anim_v: Variant in animations:
		var anim_name: String = str((anim_v as Dictionary).get("name", "default"))
		var col: int = 0
		for img: Image in decoded[anim_name]:
			sheet.blit_rect(img, Rect2i(0, 0, fw, fh), Vector2i(col * fw, row * fh))
			col += 1
		row += 1

	var preview: Image = _make_preview(sheet)
	if out_scale > 1:
		sheet.resize(
			sheet.get_width() * out_scale, sheet.get_height() * out_scale, Image.INTERPOLATE_NEAREST
		)

	var out_abs: String = _resolve(output)
	DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())
	if sheet.save_png(out_abs) != OK:
		printerr("[pixelart] Cannot write %s" % out_abs)
		return false

	var preview_abs: String = _repo_root.path_join(PREVIEW_DIR).path_join(
		"%s_preview.png" % sprite_name
	)
	DirAccess.make_dir_recursive_absolute(preview_abs.get_base_dir())
	preview.save_png(preview_abs)

	var total_frames: int = 0
	for anim_name: String in decoded:
		total_frames += (decoded[anim_name] as Array).size()
	var want_frames: bool = bool(spec.get("sprite_frames", total_frames > 1))
	var tres_path: String = ""
	if want_frames:
		tres_path = output.get_basename() + "_frames.tres"
		if not _write_sprite_frames(
			tres_path, output, animations, decoded, fw * out_scale, fh * out_scale
		):
			return false

	print(
		(
			"[pixelart] OK %s -> %s (%dx%d, %d anims, %d frames)%s | preview: %s"
			% [
				sprite_name,
				output,
				sheet.get_width(),
				sheet.get_height(),
				animations.size(),
				total_frames,
				(" + " + tres_path) if tres_path != "" else "",
				preview_abs
			]
		)
	)
	return true


func _parse_palette(raw: Variant, errors: PackedStringArray) -> Dictionary:
	var palette: Dictionary = {}
	if not raw is Dictionary:
		errors.append("'palette' must be an object {char: '#rrggbb' | null}")
		return palette
	for key: Variant in raw:
		var k: String = str(key)
		if k.length() != 1:
			errors.append("palette key '%s' must be exactly one character" % k)
			continue
		var value: Variant = raw[key]
		if value == null or str(value) == "transparent":
			palette[k] = Color(0, 0, 0, 0)
		elif str(value).is_valid_html_color():
			palette[k] = Color.html(str(value))
		else:
			errors.append("palette '%s': invalid color '%s'" % [k, str(value)])
	return palette


func _decode_frame(
	rows: Array, fw: int, fh: int, palette: Dictionary, where: String, errors: PackedStringArray
) -> Image:
	if rows.size() != fh:
		errors.append("%s: has %d rows, expected %d" % [where, rows.size(), fh])
		return null
	var img: Image = Image.create_empty(fw, fh, false, Image.FORMAT_RGBA8)
	var ok: bool = true
	for y: int in fh:
		var line: String = str(rows[y])
		if line.length() != fw:
			errors.append("%s row %d: length %d, expected %d" % [where, y, line.length(), fw])
			ok = false
			continue
		for x: int in fw:
			var ch: String = line[x]
			if not palette.has(ch):
				errors.append("%s row %d col %d: '%s' not in palette" % [where, y, x, ch])
				ok = false
				continue
			img.set_pixel(x, y, palette[ch])
	return img if ok else null


func _resolve_ref(
	ref: String, decoded: Dictionary, where: String, errors: PackedStringArray
) -> Image:
	var parts: PackedStringArray = ref.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		errors.append("%s: reference '%s' must be 'anim:index'" % [where, ref])
		return null
	var anim_name: String = parts[0]
	var index: int = parts[1].to_int()
	if not decoded.has(anim_name) or index < 0 or index >= (decoded[anim_name] as Array).size():
		errors.append(
			(
				"%s: reference '%s' does not exist (only earlier frames can be referenced)"
				% [where, ref]
			)
		)
		return null
	return (decoded[anim_name][index] as Image).duplicate()


func _apply_outline(img: Image, color: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var src: Image = img.duplicate()
	for y: int in h:
		for x: int in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if (
					n.x >= 0
					and n.y >= 0
					and n.x < w
					and n.y < h
					and src.get_pixelv(n).a > 0.0
					and src.get_pixelv(n) != color
				):
					img.set_pixel(x, y, color)
					break


func _make_preview(sheet: Image) -> Image:
	var w: int = sheet.get_width() * PREVIEW_SCALE
	var h: int = sheet.get_height() * PREVIEW_SCALE
	var preview: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cell: int = maxi(1, PREVIEW_SCALE / 2)
	for y: int in h:
		for x: int in w:
			preview.set_pixel(x, y, CHECKER_A if ((x / cell) + (y / cell)) % 2 == 0 else CHECKER_B)
	var scaled: Image = sheet.duplicate()
	scaled.resize(w, h, Image.INTERPOLATE_NEAREST)
	preview.blend_rect(scaled, Rect2i(0, 0, w, h), Vector2i.ZERO)
	return preview


func _write_sprite_frames(
	tres_path: String, png_path: String, animations: Array, decoded: Dictionary, fw: int, fh: int
) -> bool:
	var subs: PackedStringArray = PackedStringArray()
	var anim_blocks: PackedStringArray = PackedStringArray()
	var row: int = 0
	for anim_v: Variant in animations:
		var anim: Dictionary = anim_v
		var anim_name: String = str(anim.get("name", "default"))
		var frame_entries: PackedStringArray = PackedStringArray()
		var durations: Array = anim.get("durations", [])
		var count: int = (decoded[anim_name] as Array).size()
		for i: int in count:
			var sub_id: String = "AtlasTexture_%s_%d" % [anim_name, i]
			(
				subs
				. append(
					(
						'[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("1_sheet")\nregion = Rect2(%d, %d, %d, %d)\n'
						% [sub_id, i * fw, row * fh, fw, fh]
					)
				)
			)
			var duration: float = float(durations[i]) if i < durations.size() else 1.0
			frame_entries.append(
				'{\n"duration": %s,\n"texture": SubResource("%s")\n}' % [str(duration), sub_id]
			)
		anim_blocks.append(
			(
				'{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
				% [
					", ".join(frame_entries),
					"true" if bool(anim.get("loop", true)) else "false",
					anim_name,
					str(float(anim.get("fps", 8)))
				]
			)
		)
		row += 1

	var out: String = (
		'[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (subs.size() + 2)
	)
	out += '[ext_resource type="Texture2D" path="%s" id="1_sheet"]\n\n' % png_path
	out += "\n".join(subs)
	out += "\n[resource]\nanimations = [%s]\n" % ", ".join(anim_blocks)

	var abs_path: String = _resolve(tres_path)
	var f: FileAccess = FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		printerr("[pixelart] Cannot write %s" % abs_path)
		return false
	f.store_string(out)
	f.close()
	return true
