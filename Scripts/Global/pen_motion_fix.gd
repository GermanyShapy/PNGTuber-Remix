class_name PenMotionFix
extends Node

## Makes a pen drag on a spin box behave like a mouse drag.
##
## A spin box drag accumulates `relative` and maps the running total through a
## power curve, so its value is a function of the whole distance travelled and a
## single stray pixel late in a gesture is amplified. A mouse feeds that total
## with a continuous stream. A pen only reports where it is, and while the engine
## has the pointer captured its `relative` is the offset from the capture point
## rather than a movement.
##
## Samples whose `relative` is that offset are rewritten here into a real
## movement -- or into zero when the position cannot be trusted -- so nothing the
## engine derived from the absolute position reaches a widget. Everything else is
## left untouched, which is what keeps mouse drags working.
##
## The test is per sample, never per gesture: the pen and the mouse can both
## report during one gesture (a pen resting on the tablet keeps sending samples),
## and latching a device would break whichever one was not latched.
##
## Positions are also reported at the press point, because hover is computed
## inside `push_input`, after Node._input -- which is why the hook is
## `window_input`, emitted before the event is pushed.
##
## The capture is kept: it is what keeps the pointer hidden and unable to leave
## the window. Its clip is dropped through the extension, because a clipped pen
## position stops at the window border and a small window would then bound the
## reachable range.

## A pen that stopped reporting has left the tablet's range, not moved.
const SAMPLE_GAP_MS: int = 120
## Fastest believable travel. A larger step is a re-acquired position.
const MAX_SPEED_PX_S: float = 8000.0
## Bounds for the measured sample interval, so a stalled frame cannot license a
## large step.
const DT_MIN_MS: float = 4.0
const DT_MAX_MS: float = 40.0
## Slack for matching `relative` against the offset from the capture point. The
## engine computes both in whole pixels, so anything above rounding is a
## different quantity.
const ECHO_TOL_PX: float = 0.75
## Safety net for a release whose event never arrives.
const HOLD_MS: int = 3000

var _last_pos: Vector2 = Vector2.ZERO
var _last_ms: int = 0
## The previous position is usable as a reference.
var _valid: bool = false
## Left button held.
var _gesture: bool = false
## Positions are being reported at `_anchor` instead of where the pen is.
var _frozen: bool = false
var _anchor: Vector2 = Vector2.ZERO
## Where the engine parked the cursor when it captured the pointer.
var _centre: Vector2 = Vector2.ZERO
var _press_pos: Vector2 = Vector2.ZERO
var _authored: Vector2 = Vector2.ZERO
var _samples: int = 0
var _dropped: int = 0
var _trace: bool = false
var _trace_count: int = 0


func _ready() -> void:
	# The marker file also arms tracing: launching from the editor does not
	# reliably forward user args, and a diagnostic that silently does nothing is
	# worse than none.
	_trace = Global.has_diag_flag("pen-trace") or FileAccess.file_exists("res://pen_trace.on")
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
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if button.pressed:
		_begin_gesture(button.position)
	else:
		end_drag()


## Fallback for viewports that are not a Window; `_input` is only enabled then.
func _input(event: InputEvent) -> void:
	_on_window_input(event)


func _engine_captured() -> bool:
	return Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED


func _begin_gesture(p_pos: Vector2) -> void:
	_gesture = true
	_press_pos = p_pos
	_authored = Vector2.ZERO
	_samples = 0
	_dropped = 0
	# The press point is where the widget must stay: every sample after the
	# capture reports the parked cursor instead.
	_valid = false


func end_drag() -> void:
	if !_gesture and !_frozen:
		return
	if _trace:
		print("[pen] gesture end samples=%d authored=%s net=%s dropped=%d" % [
			_samples, _authored, _last_pos - _press_pos, _dropped])
	_gesture = false
	_frozen = false
	_valid = false
	set_process(false)


## Captured mode clips the cursor to the client rect, and a pen then reports
## positions clamped to it: the reachable range would shrink with the window.
## Dropping the clip keeps the capture, which parks the cursor inside the window
## and therefore never draws it, while the pen reports its real position again.
func _release_clip() -> void:
	# Typed as Object: RawMouseInput only ships a Windows library, so naming the
	# type would stop this script from compiling on every other platform -- and
	# an uncompilable class_name breaks the autoload that references it.
	var raw: Object = GlobInput.rawMouseInput
	if raw != null and raw.has_method("release_cursor_clip"):
		raw.release_cursor_clip()


func start_drag(p_real: Vector2) -> void:
	_frozen = true
	_anchor = _press_pos if _gesture else p_real
	_centre = get_viewport().get_visible_rect().size * 0.5
	_release_clip()
	set_process(true)


func _process(_delta: float) -> void:
	# The engine re-applies the clip whenever the mouse mode is set again.
	_release_clip()
	if _frozen and Time.get_ticks_msec() - _last_ms > HOLD_MS:
		end_drag()


## Movement of this sample, or zero when the previous position cannot serve as a
## reference: a gap means the pen left the tablet, and a step faster than a hand
## is a re-acquired position rather than travel.
func _step(p_real: Vector2, p_now: int) -> Vector2:
	if !_valid:
		return Vector2.ZERO
	var elapsed := p_now - _last_ms
	if elapsed > SAMPLE_GAP_MS:
		return Vector2.ZERO
	var delta := p_real - _last_pos
	var allowed := MAX_SPEED_PX_S * clampf(float(elapsed), DT_MIN_MS, DT_MAX_MS) / 1000.0
	if delta.length() > allowed:
		_dropped += 1
		if _trace:
			print("[pen] drop ", delta, " > ", allowed)
		return Vector2.ZERO
	return delta


## Whether the engine built this `relative` out of the absolute position, which
## is what it does for a device that only reports where it is. A mouse reports a
## movement instead, so its `relative` stays unrelated to the offset from the
## capture point even though its position sits on that same point.
func _echoes_position(p_motion: InputEventMouseMotion) -> bool:
	var offset := p_motion.position - _centre
	return (p_motion.relative - offset).length() <= ECHO_TOL_PX


func _pin(motion: InputEventMouseMotion) -> void:
	motion.position = _anchor
	motion.global_position = _anchor


## Rewrites the event in place. It runs before the event is pushed, so the values
## here are what the widgets see.
func fix(motion: InputEventMouseMotion) -> void:
	var now := Time.get_ticks_msec()
	if _frozen and !_engine_captured():
		# The engine drops the capture when its own drag ends.
		end_drag()

	if !_gesture:
		# Outside a gesture `relative` only drives hover, which this node does not
		# own: the engine's value is left exactly as it came in.
		return

	var real := motion.position
	if !_frozen:
		if !_engine_captured():
			# Before the capture the engine has no drag of its own to feed.
			return
		start_drag(real)
		motion.relative = Vector2.ZERO
		_pin(motion)
		_last_pos = real
		_last_ms = now
		_valid = true
		return

	if motion.pressure > 0.0 or _echoes_position(motion):
		motion.relative = _step(real, now)
		_authored += motion.relative
		_samples += 1
	_pin(motion)
	_last_pos = real
	_last_ms = now
	_valid = true
	_trace_sample(real, motion)


## Diagnostic (only when tracing is armed): the reachable range, the authored
## delta, and which control the engine considers hovered. The per-gesture totals
## printed by end_drag() tell whether the authored stream followed the pen.
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
	print("[pen] pos=%s fixed=%s p=%.2f mask=%d mode=%d frozen=%s anchor=%s over=%s" % [
		p_real, p_motion.relative, p_motion.pressure, p_motion.button_mask,
		Input.get_mouse_mode(), _frozen, _anchor, hovered])
