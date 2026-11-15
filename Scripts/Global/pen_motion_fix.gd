class_name PenMotionFix
extends Node

## Makes a pen drag on a spin box behave like a mouse drag.
##
## Measured on this project (logs of 2026-11-15, plus engine source):
## * SpinBox captures the pointer while an arrow is dragged. Captured mode parks
##   the cursor at the window centre and clips it to the client rect, which turns
##   the engine's `relative` into "position - centre": one sign for the whole
##   gesture and orders of magnitude too large.
## * Hover is computed inside `push_input`, after `Node._input`, so
##   `window_input` is the only hook early enough to pin what the GUI sees.
##
## The capture is therefore kept -- it is the only thing that keeps the pointer
## hidden and unable to leave the window -- and only the movement is rebuilt from
## consecutive pen positions, with the reported position pinned at the press
## point so a hover never follows the pen across the UI.
##
## Leaving captured mode for a hidden pointer was tried and reverted: hiding
## drops the clip, but the hidden cursor style only applies inside the owning
## window, so the pointer reappears outside it, and warping it back emits a
## synthetic motion every frame whose `relative` undoes the step just taken --
## the value and the pointer both oscillate.
##
## Only `pressure > 0` samples are touched: a mouse reports exactly 0, and
## rewriting mouse samples made the engine's own deltas oscillate.

## A pen that stopped reporting begins a new gesture.
const PEN_GAP_MS: int = 1000
## Safety net for a release whose event never arrives.
const HOLD_MS: int = 3000

var _last_pos: Vector2 = Vector2.ZERO
var _last_ms: int = 0
var _valid: bool = false
## Set while a pen drag is being rewritten: positions are reported at `_anchor`.
var _frozen: bool = false
var _anchor: Vector2 = Vector2.ZERO
var _anchor_valid: bool = false
## The press carries the real pen position; the samples after the capture only
## report the warped cursor point.
var _press_pos: Vector2 = Vector2.ZERO
var _press_ms: int = 0
var _press_valid: bool = false
var _trace: bool = false
var _trace_count: int = 0


func _ready() -> void:
	# The marker file also arms tracing: launching from the editor does not
	# reliably forward user args, and a diagnostic that silently does nothing is
	# worse than none.
	_trace = Global.has_diag_flag("pen-trace") or FileAccess.file_exists("res://pen_trace.on")
	# `window_input` is emitted by Window::_window_input before it calls
	# push_input, so it is the only hook that runs before the engine computes
	# hover from the event.
	var window := get_viewport() as Window
	if window != null:
		window.window_input.connect(_on_window_input)
		set_process_input(false)
	else:
		set_process_input(true)
	# Every popup viewport owns an instance; nothing may run per frame unless a
	# pen drag is actually pinned.
	set_process(false)


func _on_window_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		fix(motion)
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_press_pos = button.position
			_press_ms = Time.get_ticks_msec()
			_press_valid = true
		else:
			end_drag()


## Fallback for viewports that are not a Window; `_input` is only enabled then.
func _input(event: InputEvent) -> void:
	_on_window_input(event)


func _engine_captured() -> bool:
	return Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED


## Captured mode clips the cursor to the client rect, and a pen then reports
## positions clamped to it: the reachable range shrinks with the window. Dropping
## the clip keeps the capture -- the cursor stays parked at the window centre, so
## it is never drawn -- while the pen reports its real position again.
func _release_clip() -> void:
	var raw: RawMouseInput = GlobInput.rawMouseInput
	if raw != null and raw.has_method("release_cursor_clip"):
		raw.release_cursor_clip()


func start_drag(p_now: int, p_real: Vector2) -> void:
	_frozen = true
	if !_anchor_valid:
		_anchor = _press_pos if _press_valid and p_now - _press_ms <= PEN_GAP_MS else p_real
		_anchor_valid = true
	_release_clip()
	set_process(true)


func end_drag() -> void:
	if !_frozen:
		return
	_frozen = false
	_anchor_valid = false
	set_process(false)
	if _trace:
		print("[pen] drag end")


func _process(_delta: float) -> void:
	# The engine re-applies the clip whenever the mouse mode is set again.
	_release_clip()
	# The engine ends the drag itself, but a lost release must not pin forever.
	if Time.get_ticks_msec() - _last_ms > HOLD_MS:
		end_drag()


func _pin(motion: InputEventMouseMotion) -> void:
	motion.position = _anchor
	motion.global_position = _anchor


## Rewrites the event in place. It is shared with the GUI pass that runs after
## the input pass, so the values here are what the widgets see.
func fix(motion: InputEventMouseMotion) -> void:
	# The engine drops the capture when the drag ends, so the mode is the honest
	# signal. Input.is_mouse_button_pressed() reports false for pen contacts.
	if _frozen and !_engine_captured():
		end_drag()

	if motion.pressure <= 0.0:
		# Mouse, or a pen out of contact: its own fields are never rewritten.
		if motion.button_mask == 0:
			_valid = false
		if _frozen:
			_pin(motion)
		return

	var now := Time.get_ticks_msec()
	var real := motion.position

	if _frozen:
		if _valid:
			motion.relative = real - _last_pos
		_pin(motion)
	elif _engine_captured():
		# The drag just started: from here on the widgets see the press point.
		start_drag(now, real)
		motion.relative = Vector2.ZERO
		_pin(motion)
	elif _valid and now - _last_ms <= PEN_GAP_MS:
		motion.relative = real - _last_pos
	# else: the first sample of a new gesture keeps the engine's own value.

	_last_pos = real
	_last_ms = now
	_valid = true
	_trace_sample(real, motion)


## Diagnostic (only when tracing is armed): the reachable range, the rebuilt
## delta, and which control the engine considers hovered. The window and screen
## geometry are printed so a stop at the client rect can be told from one at the
## desk.
func _trace_sample(p_real: Vector2, p_motion: InputEventMouseMotion) -> void:
	if !_trace:
		return
	_trace_count += 1
	if _trace_count % 10 != 0:
		return
	var hovered := "<none>"
	var viewport := get_viewport()
	if viewport != null:
		var control := viewport.gui_get_hovered_control()
		if control != null:
			hovered = "%s/%s" % [control.get_class(), control.name]
	print("[pen] pos=%s fixed=%s p=%.2f mode=%d frozen=%s anchor=%s win=%s+%s screen=%s over=%s" % [
		p_real, p_motion.relative, p_motion.pressure, Input.get_mouse_mode(),
		_frozen, _anchor, DisplayServer.window_get_position(),
		DisplayServer.window_get_size(), DisplayServer.screen_get_size(), hovered])
