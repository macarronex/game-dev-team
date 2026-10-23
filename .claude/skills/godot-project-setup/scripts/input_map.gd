extends SceneTree
## Writes input actions from a JSON spec into project.godot (replaces the listed actions only).
##
## Usage (from the repository root):
##   godot --headless --path godot -s res://tools/input_map.gd -- [res://tools/input_map.json]
##
## Spec: { "move_left": { "keys": ["A", "Left"], "joy_buttons": ["dpad_left"],
##                        "joy_axes": [{"axis": "left_x", "value": -1.0}], "mouse_buttons": [], "deadzone": 0.2 } }
## Keys use Godot key names (OS.find_keycode_from_string) and are stored as physical keycodes,
## so WASD keeps its position on AZERTY/QWERTZ keyboards.

const JOY_BUTTONS: Dictionary = {
	"a": JOY_BUTTON_A,
	"b": JOY_BUTTON_B,
	"x": JOY_BUTTON_X,
	"y": JOY_BUTTON_Y,
	"back": JOY_BUTTON_BACK,
	"guide": JOY_BUTTON_GUIDE,
	"start": JOY_BUTTON_START,
	"left_stick": JOY_BUTTON_LEFT_STICK,
	"right_stick": JOY_BUTTON_RIGHT_STICK,
	"lb": JOY_BUTTON_LEFT_SHOULDER,
	"rb": JOY_BUTTON_RIGHT_SHOULDER,
	"dpad_up": JOY_BUTTON_DPAD_UP,
	"dpad_down": JOY_BUTTON_DPAD_DOWN,
	"dpad_left": JOY_BUTTON_DPAD_LEFT,
	"dpad_right": JOY_BUTTON_DPAD_RIGHT,
}
const JOY_AXES: Dictionary = {
	"left_x": JOY_AXIS_LEFT_X,
	"left_y": JOY_AXIS_LEFT_Y,
	"right_x": JOY_AXIS_RIGHT_X,
	"right_y": JOY_AXIS_RIGHT_Y,
	"lt": JOY_AXIS_TRIGGER_LEFT,
	"rt": JOY_AXIS_TRIGGER_RIGHT,
}
const MOUSE_BUTTONS: Dictionary = {
	"left": MOUSE_BUTTON_LEFT,
	"right": MOUSE_BUTTON_RIGHT,
	"middle": MOUSE_BUTTON_MIDDLE,
	"wheel_up": MOUSE_BUTTON_WHEEL_UP,
	"wheel_down": MOUSE_BUTTON_WHEEL_DOWN,
}


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var spec_path: String = args[0] if args.size() > 0 else "res://tools/input_map.json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	if not parsed is Dictionary:
		printerr("[input_map] Cannot read or parse %s" % spec_path)
		quit(1)
		return
	var spec: Dictionary = parsed
	var errors: PackedStringArray = PackedStringArray()

	for action_v: Variant in spec:
		var action_name: String = str(action_v)
		var a: Dictionary = spec[action_v]
		var events: Array[InputEvent] = []
		for key_v: Variant in a.get("keys", []):
			var code: Key = OS.find_keycode_from_string(str(key_v))
			if code == KEY_NONE:
				errors.append("%s: unknown key '%s'" % [action_name, str(key_v)])
				continue
			var ev_key: InputEventKey = InputEventKey.new()
			ev_key.physical_keycode = code
			events.append(ev_key)
		for btn_v: Variant in a.get("joy_buttons", []):
			var btn: int = _lookup(btn_v, JOY_BUTTONS)
			if btn < 0:
				errors.append("%s: unknown joy button '%s'" % [action_name, str(btn_v)])
				continue
			var ev_btn: InputEventJoypadButton = InputEventJoypadButton.new()
			ev_btn.button_index = btn as JoyButton
			events.append(ev_btn)
		for axis_v: Variant in a.get("joy_axes", []):
			var axis_d: Dictionary = axis_v
			var axis: int = _lookup(axis_d.get("axis", ""), JOY_AXES)
			if axis < 0:
				errors.append(
					"%s: unknown joy axis '%s'" % [action_name, str(axis_d.get("axis", ""))]
				)
				continue
			var ev_axis: InputEventJoypadMotion = InputEventJoypadMotion.new()
			ev_axis.axis = axis as JoyAxis
			ev_axis.axis_value = float(axis_d.get("value", 1.0))
			events.append(ev_axis)
		for mb_v: Variant in a.get("mouse_buttons", []):
			var mb: int = _lookup(mb_v, MOUSE_BUTTONS)
			if mb < 0:
				errors.append("%s: unknown mouse button '%s'" % [action_name, str(mb_v)])
				continue
			var ev_mouse: InputEventMouseButton = InputEventMouseButton.new()
			ev_mouse.button_index = mb as MouseButton
			events.append(ev_mouse)
		(
			ProjectSettings
			. set_setting(
				"input/" + action_name,
				{
					"deadzone": float(a.get("deadzone", 0.2)),
					"events": events,
				}
			)
		)

	if not errors.is_empty():
		for e: String in errors:
			printerr("[input_map] " + e)
		quit(1)
		return
	var err: Error = ProjectSettings.save()
	if err != OK:
		printerr("[input_map] ProjectSettings.save() failed: %s" % error_string(err))
		quit(1)
		return
	print("[input_map] OK: %d actions written to project.godot" % spec.size())
	quit(0)


func _lookup(value: Variant, table: Dictionary) -> int:
	if value is int or value is float:
		return int(value)
	var key: String = str(value).to_lower()
	return int(table[key]) if table.has(key) else -1
