class_name StandGlobalInput
extends GlobalInput

@onready var cycle :Node = %Cycle

# Typed as Object on purpose: the extension only ships a Windows library, so on other
# platforms the class is never registered and naming the type would break this script.
var rawMouseInput : Object = null;
var mouse_relative_movement:Vector2i = Vector2i.ZERO
var is_mouse_relative_movement:bool = false
var mouse_relative_movement_buffer:Vector2i = Vector2i.ZERO
var is_mouse_relative_movement_buffer:bool = false

## An absolute device (pen tablet, RDP session) keeps reporting while it drives
## the pointer. Once it stops, the system cursor is authoritative again; the
## window has to be short enough that a mouse move is not masked by a stale pen.
const ABSOLUTE_CURSOR_MAX_AGE_MS: int = 150

## How long an event position stays usable after the last mouse event.
const EVENT_CURSOR_MAX_AGE_MS: int = 150

## Distance within which an absolute report and the system cursor describe the
## same point. A wrong mapping is off by a whole screen edge, never by pixels.
const ABSOLUTE_CURSOR_AGREE_PX: float = 8.0

var mouse_absolute_position: Vector2 = Vector2.ZERO
var mouse_absolute_age_ms: int = -1
## Whether the absolute reports of the current device can be interpreted as
## screen coordinates. Decided only while the system cursor is alive, because
## that is the one moment the two can be compared; see _update_absolute_trust().
var _absolute_report_trusted: bool = false
## (absolute, relative) report totals from the extension. Diagnostic only: it
## tells which unit the delta of a given tablet is expressed in.
var raw_report_counts: Vector2i = Vector2i.ZERO

## Cached once per frame: the follow code runs per sprite, and
## DisplayServer.mouse_get_position() / window_get_position() enumerate the
## monitors internally, so calling them per sprite was pure overhead.
var cursor_screen_position: Vector2 = Vector2.ZERO
var _sys_last: Vector2 = Vector2(-1, -1)
var _sys_stable_frames: int = 0
## Latch for the event path. A pen that stops does not restart the system
## cursor, so expiring on a stale event would teleport the sprite back to
## wherever the mouse was left. Only real cursor motion ends the override.
var _use_event_cursor: bool = false
var _event_cursor_position: Vector2 = Vector2.ZERO

## Screen-space cursor position, refreshed once per frame.
func get_cursor_screen_position() -> Vector2:
	return cursor_screen_position

## A pen in Windows Ink mode feeds pointer events to the focused window while
## GetCursorPos stays frozen, so a still system cursor plus a fresh event means
## the event is the truthful one. Everything else keeps the system cursor.
func _update_cursor_screen_position() -> void:
	var sys := Vector2(DisplayServer.mouse_get_position())
	if sys == _sys_last:
		_sys_stable_frames += 1
	else:
		_sys_last = sys
		_sys_stable_frames = 0
		_use_event_cursor = false
		# A moving cursor is the only thing an absolute report can be checked
		# against, so this is the only moment the mapping can be judged.
		_update_absolute_trust(sys)

	var event_age: int = -1 if mouse_event_tick < 0 else Time.get_ticks_msec() - mouse_event_tick
	if event_age >= 0 and event_age <= EVENT_CURSOR_MAX_AGE_MS:
		# Screen space = window origin + viewport position, the same relation
		# the engine uses to derive the viewport mouse position in the first place.
		_event_cursor_position = Vector2(DisplayServer.window_get_position()) + mouse_event_position
		if _sys_stable_frames >= 2:
			_use_event_cursor = true

	if _use_event_cursor:
		cursor_screen_position = _event_cursor_position
	elif _absolute_report_usable():
		cursor_screen_position = mouse_absolute_position
	else:
		cursor_screen_position = sys

## A pen display may normalise its absolute reports over its own screen without
## setting MOUSE_VIRTUAL_DESKTOP. Reading those as primary-screen coordinates
## offsets them by a whole monitor width, which would drag the sprite to a clamp
## edge -- and the absolute channel outranks the cursor, so it would mask the one
## source that is right. While the cursor is alive the two can be compared, so a
## device that disagrees is marked untrusted; it only earns trust by agreeing.
func _update_absolute_trust(p_sys: Vector2) -> void:
	if mouse_absolute_age_ms < 0 or mouse_absolute_age_ms > ABSOLUTE_CURSOR_MAX_AGE_MS:
		return # nothing to judge against, keep the previous verdict
	_absolute_report_trusted = mouse_absolute_position.distance_squared_to(p_sys) \
			<= ABSOLUTE_CURSOR_AGREE_PX * ABSOLUTE_CURSOR_AGREE_PX

## A pinned cursor cannot cross-check the report, so the last verdict stands:
## that is the case the channel exists for. Freshness still applies either way.
func _absolute_report_usable() -> bool:
	return _absolute_report_trusted \
			and mouse_absolute_age_ms >= 0 \
			and mouse_absolute_age_ms <= ABSOLUTE_CURSOR_MAX_AGE_MS

## Diagnostic (`-- --cursor-trace`): prints every cursor source four times a
## second, so "the pen freezes GetCursorPos" can be told apart from "the pen
## never reaches Raw Input" without guessing.
var _cursor_trace: bool = false
var _cursor_trace_accum: float = 0.0

## Last position delivered by a mouse event. Windows Ink keeps sending pen
## positions as mouse events to the focused window even while GetCursorPos is
## frozen, so this may work as a fallback that needs no native code.
var mouse_event_position: Vector2 = Vector2.ZERO
var mouse_event_global: Vector2 = Vector2.ZERO
var mouse_event_tick: int = -1

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		mouse_event_position = event.position
		mouse_event_global = event.global_position
		mouse_event_tick = Time.get_ticks_msec()

func _ready() -> void:
	# use_physics_frames = true
	# Consumers read the per-frame cursor cache, so this must refresh before any
	# of them. Autoload order alone would only be guaranteed by tree position.
	process_priority = -100
	call_deferred("_rawmouse_init");
	_cursor_trace = Global.has_diag_flag("cursor-trace")
	_install_pen_fix()

## Pen samples need their `relative` rebuilt (see PenMotionFix). Popups are real
## OS windows here -- embed_subwindows=false -- so they are separate viewports:
## the main window is covered by an instance under this autoload, every other
## window gets its own as it enters the tree.
func _install_pen_fix() -> void:
	var main_fix := PenMotionFix.new()
	main_fix.name = "PenMotionFix"
	add_child(main_fix)
	for window in get_tree().root.find_children("*", "Window", true, false):
		_on_node_added(window)
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is Window and node != get_tree().root and node.get_node_or_null("PenMotionFix") == null:
		var fix := PenMotionFix.new()
		fix.name = "PenMotionFix"
		node.add_child(fix)

func _rawmouse_init():
	if Global.has_diag_flag("no-rawmouse"):
		print("[diag] RawMouseInput disabled by --no-rawmouse")
		return
	# The extension only ships a Windows library, so the class is absent
	# elsewhere; guard before touching it.
	if rawMouseInput == null and OS.get_name() == "Windows" and ClassDB.class_exists("RawMouseInput"):
		print("raw input init start")
		Global.diag_phase("rawmouse_new")
		Global.diag_trace("rawmouse:new enter")
		rawMouseInput = ClassDB.instantiate("RawMouseInput")
		Global.diag_trace("rawmouse:new exit")
		rawMouseInput.raw_mouse.connect(_on_raw_mouse_input_updated)

		# add_child runs the plugin's _enter_tree/_ready, which is where it hooks
		# the window procedure and starts its reader thread.
		Global.diag_phase("rawmouse_add_child")
		Global.diag_trace("rawmouse:add_child enter")
		add_child(rawMouseInput);
		Global.diag_trace("rawmouse:add_child exit")
		Global.diag_phase("")

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

		# One native call per frame: the age is computed on read so it keeps
		# growing while the device is idle, which is what expires the override.
		var absolute: Vector2i = rawMouseInput.get_mouse_absolute_position()
		mouse_absolute_position = Vector2(absolute)
		mouse_absolute_age_ms = rawMouseInput.get_mouse_absolute_age_ms()
		raw_report_counts = rawMouseInput.get_report_counts()

	_update_cursor_screen_position()

	if _cursor_trace:
		_cursor_trace_accum += _delta
		if _cursor_trace_accum >= 0.25:
			_cursor_trace_accum = 0.0
			# Three candidate sources side by side: the system cursor, the raw
			# absolute report, and the engine's own viewport position (which a
			# pen pointer event updates even when GetCursorPos is frozen).
			print("[cursor] cur=%s sys=%s abs=%s age=%d cnt=%s vp=%s win=%s rel=%s rawrel=%s ev=%s evg=%s evage=%d" % [
					cursor_screen_position,
					DisplayServer.mouse_get_position(), mouse_absolute_position,
					mouse_absolute_age_ms, raw_report_counts, get_viewport().get_mouse_position(),
					DisplayServer.window_get_position(), is_mouse_relative_movement,
					mouse_relative_movement, mouse_event_position, mouse_event_global,
					-1 if mouse_event_tick < 0 else Time.get_ticks_msec() - mouse_event_tick])

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
