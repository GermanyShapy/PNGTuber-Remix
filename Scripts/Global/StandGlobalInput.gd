class_name StandGlobalInput
extends GlobalInput

@onready var cycle :Node = %Cycle

var rawMouseInput : RawMouseInput = null;
var mouse_relative_movement:Vector2i = Vector2i.ZERO
var is_mouse_relative_movement:bool = false
var mouse_relative_movement_buffer:Vector2i = Vector2i.ZERO
var is_mouse_relative_movement_buffer:bool = false

func _ready() -> void:
	# use_physics_frames = true
	call_deferred("_rawmouse_init");

func _rawmouse_init():
	if rawMouseInput == null and OS.get_name() == "Windows":
		print("raw input init start")
		rawMouseInput = RawMouseInput.new()
		rawMouseInput.raw_mouse.connect(_on_raw_mouse_input_updated)

		add_child(rawMouseInput);

		if !rawMouseInput.is_inited:
			print("raw input init failed")
			remove_child(rawMouseInput)
			rawMouseInput = null
		else:
			print("raw input init end")

func _process(_delta: float) -> void:
	if rawMouseInput != null:
		mouse_relative_movement = mouse_relative_movement_buffer
		mouse_relative_movement_buffer = Vector2i.ZERO
		is_mouse_relative_movement = is_mouse_relative_movement_buffer
		is_mouse_relative_movement_buffer = false

# win32/api/winuser/ns-winuser-rawmouse usFlags
enum Raw_Mouse_Input_Flags {
	MOUSE_MOVE_RELATIVE = 0x00,
	MOUSE_MOVE_ABSOLUTE = 0x01,
	MOUSE_VIRTUAL_DESKTOP = 0x02,
	MOUSE_ATTRIBUTES_CHANGED = 0x04,
	MOUSE_MOVE_NOCOALESCE = 0x08,
}

func _on_raw_mouse_input_updated(lLastX: int, lLastY: int) -> void:
	mouse_relative_movement_buffer.x += lLastX
	mouse_relative_movement_buffer.y += lLastY
	is_mouse_relative_movement_buffer = true

func refresh_raw_mouse_input():
	if rawMouseInput != null:
		rawMouseInput.refresh()

# --- Joypad binding helpers --------------------------------------------------
#
# Used by the key-binding widgets (`CustomHotkeyMapButton` / `AssetStateButton` /
# `StateRemapButton`). They live here rather than in a separate helper class so
# the deadzone stays in the same namespace as the property that owns it
# (`GlobInput.joy_deadzone`) -- which is also the value the native trigger check
# uses, so a direction that can be bound is always a direction that fires.
#
# Why a stick cannot be bound "on release" like a key or a button: while it is
# pushed its events report `is_released() == false`, and the event sent when it
# returns to centre carries `axis_value == 0`. Binding that would store an empty
# direction, and on a stick whose resting value is not exactly 0 the release
# branch would never be reached at all. So the widgets bind the first event that
# crosses the deadzone and stop awaiting immediately.

## True when this axis event is pushed far enough in either direction to bind.
func is_joy_pushed(p_event: InputEventJoypadMotion) -> bool:
	return absf(p_event.axis_value) >= joy_deadzone


## Stored form of a stick binding: axis plus direction only. The magnitude is
## device specific and every comparison is by sign, so it is normalised away.
func normalize_joy_event(p_event: InputEventJoypadMotion) -> InputEventJoypadMotion:
	var normalized := InputEventJoypadMotion.new()
	normalized.axis = p_event.axis
	normalized.axis_value = 1.0 if p_event.axis_value >= 0.0 else -1.0
	return normalized
