class_name MouseCaptureArea
extends Button

## The "mouse bind capture pad" (TR_MOUSE_INPUT_AREA).
##
## It is a floating marker shown right below the remap button while that button
## awaits an input. Two things must BOTH hold:
##
## 1. A click must land on the pad, not on whatever the pad visually covers
##    (e.g. the "inclusive key check" checkbox) -- otherwise clicking the pad
##    silently toggles a checkbox behind it.
## 2. Hovering over the pad must NOT highlight the covered control either, or the
##    user sees a control "light up" that they cannot actually click.
##
## Godot's GUI picking walks *tree order* (last child = topmost), NOT `z_index`.
## So a pad that is a plain child of the button always loses to a later sibling
## control it covers -- verified empirically on 4.7.2: a STOP pad placed under the
## button still let the covered checkbox toggle *and* highlight on hover.
##
## Fix, two parts:
##  * `top_level = true` + `MOUSE_FILTER_STOP` lifts the pad out of the parent's
##    picking order so it is picked LAST -- it now wins hover AND click over the
##    covered control, so nothing behind it highlights any more.
##  * the owning remap widget still intercepts mouse buttons in `_input()` (which
##    runs BEFORE GUI picking) via `step_mouse()`: a press on the pad is marked
##    handled so the covered control can never react, and a press anywhere else
##    cancels the wait instead of binding a stray mouse button.
##
## Because the pad is a `top_level` control it no longer inherits its parent's
## visibility, so `_process()` also hides it when the owner (or its panel) goes
## away, and `_fit_to_parent()` positions it from the parent's *global* rect.
##
## The pad node is created lazily as a child of the target button and follows it
## while visible, so no scene edit is required and nothing shows up in the normal
## (not-awaiting) state.

const META_KEY := "_mouse_capture_area"
const META_PRESSED := "_mouse_capture_pressed"
const PAD_HEIGHT := 26.0
const MIN_PAD_WIDTH := 120.0

## What a remap widget should do with a mouse event it saw in `_input()`.
enum MouseStep {
	IGNORE,        ## not a bindable mouse button (motion, wheel) -- leave it alone
	PRESS_ON_PAD,  ## press landed on the pad, already consumed -> keep waiting
	PRESS_OUTSIDE, ## press landed elsewhere -> cancel the await
	RELEASE_ON_PAD ## release that finishes a pad press -> bind the event
}


func _init() -> void:
	name = "MouseCaptureArea"
	# STOP + top_level: the pad must win GUI picking (hover AND click) over the
	# control it covers. See the class comment for why tree order defeats a plain
	# child pad.
	mouse_filter = Control.MOUSE_FILTER_STOP
	top_level = true
	button_mask = 0
	focus_mode = Control.FOCUS_NONE
	z_index = 20
	visible = false
	set_process(true)


func _process(_delta: float) -> void:
	# Early-out first: the pad is hidden almost all of the time, and an invisible
	# pad has nothing to track either, so skip the ancestor walk entirely.
	if not visible:
		return
	var parent: Control = get_parent() as Control
	# A top_level control does not inherit its parent's visibility: drop out of
	# sight ourselves when the owning button (or the panel holding it) is hidden.
	if parent == null or not parent.is_visible_in_tree():
		visible = false
		return
	# Follow the owning button: keeps the pad aligned after resizes / scrolling.
	_fit_to_parent()


## Shows the pad right below `p_button`.
static func show_for(p_button: Control) -> void:
	var pad := _get_or_create(p_button)
	pad.text = TranslationServer.translate("TR_MOUSE_INPUT_AREA")
	pad._neutralize_hover()
	pad.visible = true
	pad._fit_to_parent()


static func hide_for(p_button: Control) -> void:
	# Also drop a half-finished pad press: otherwise a later stray release could
	# be mistaken for "the user released on the pad" and bind a random key.
	p_button.set_meta(META_PRESSED, false)
	if not p_button.has_meta(META_KEY):
		return
	var pad = p_button.get_meta(META_KEY)
	if is_instance_valid(pad):
		pad.visible = false


## True when the given *viewport-space* point (or the pointer, when omitted)
## sits on this button's visible pad.
static func is_over(p_button: Control, p_viewport_point = null) -> bool:
	var pad = _get_pad(p_button)
	if pad == null:
		return false
	if p_viewport_point == null:
		# Use the real pointer in *viewport* space (the same space as
		# `event.position`) so both branches run through the identical
		# transform-aware hit test. NB: pad.get_global_mouse_position() would
		# return pad-LOCAL coordinates and could not be compared against the
		# pad's global rect.
		var vp := p_button.get_viewport()
		if vp == null:
			return false
		p_viewport_point = vp.get_mouse_position()
	return _hits_pad_local(pad, p_viewport_point)


## Central decision helper for a remap widget's `_input()` while awaiting input.
## Consumes the press (so the control visually under the pad never reacts) when
## it lands on the pad.
static func step_mouse(p_button: Control, p_event: InputEvent) -> MouseStep:
	if not (p_event is InputEventMouseButton):
		return MouseStep.IGNORE
	# GlobalInput watches held key/button *state*; a wheel notch has no state to
	# poll (it arrives only as a press+release pair with nothing in between), so
	# the app can never act on a bound wheel event -- it would be a binding that
	# silently does nothing. Skip the wheel entirely: it must not bind, and it
	# must not be read as "clicked outside" either, so the panel still scrolls.
	if _is_wheel(p_event):
		return MouseStep.IGNORE
	if p_event.is_pressed():
		if is_over(p_button, p_event.position):
			_consume(p_button)
			p_button.set_meta(META_PRESSED, true)
			return MouseStep.PRESS_ON_PAD
		return MouseStep.PRESS_OUTSIDE
	if not bool(p_button.get_meta(META_PRESSED, false)):
		return MouseStep.IGNORE
	p_button.set_meta(META_PRESSED, false)
	_consume(p_button)
	return MouseStep.RELEASE_ON_PAD


## Engine-consistent hit test: transforms the viewport-space point into the pad's
## own canvas space exactly like Godot's `_gui_find_control_at_pos()` does, so the
## answer always agrees with what the GUI layer would have picked.
static func _hits_pad_local(pad: Control, p_viewport_point: Vector2) -> bool:
	var local: Vector2 = pad.get_global_transform_with_canvas().affine_inverse() * p_viewport_point
	return Rect2(Vector2.ZERO, pad.size).has_point(local)


## True for every wheel axis Godot delivers as an `InputEventMouseButton`.
## Verified names: button_index 4/5/6/7 -> Mouse Wheel Up/Down/Left/Right.
static func _is_wheel(p_event: InputEventMouseButton) -> bool:
	match p_event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, \
		MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
			return true
	return false


## The pad node, but only while it is actually visible.
static func _get_pad(p_button: Control):
	if not p_button.has_meta(META_KEY):
		return null
	var pad = p_button.get_meta(META_KEY)
	if not is_instance_valid(pad) or not pad.visible:
		return null
	return pad


static func _consume(p_button: Control) -> void:
	var vp := p_button.get_viewport()
	if vp != null:
		vp.set_input_as_handled()


static func _get_or_create(p_button: Control) -> MouseCaptureArea:
	if p_button.has_meta(META_KEY):
		var existing = p_button.get_meta(META_KEY)
		if is_instance_valid(existing):
			return existing
	var pad := MouseCaptureArea.new()
	p_button.add_child(pad)
	p_button.set_meta(META_KEY, pad)
	return pad


## The pad is a marker, not a control the user clicks on purpose. Since it now
## wins GUI picking it *does* receive hover, so mirror the `normal` stylebox onto
## `hover`/`pressed` to keep its look constant (no surprise highlight).
func _neutralize_hover() -> void:
	var normal := get_theme_stylebox("normal")
	if normal == null:
		return
	add_theme_stylebox_override("hover", normal)
	add_theme_stylebox_override("pressed", normal)


func _fit_to_parent() -> void:
	var parent: Control = get_parent() as Control
	if parent == null:
		return
	var width: float = maxf(parent.size.x, MIN_PAD_WIDTH)
	size = Vector2(width, PAD_HEIGHT)
	# `top_level` makes `position` relative to the canvas, not the parent, so
	# derive it from the parent's canvas-space rect instead of parent-local coords.
	var rect: Rect2 = parent.get_global_rect()
	position = Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + rect.size.y + 2.0)
