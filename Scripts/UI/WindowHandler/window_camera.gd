extends Camera2D
class_name WindowCamera

var panning := false
var _pan_anchor := Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("scrollup"):
		set_zoom_to(zoom * 1.1)
	elif event.is_action_pressed("scrolldown"):
		set_zoom_to(zoom / 1.1)
	
	if event.is_action_pressed("pan"):
		panning = true
		# Anchor on the event position: the viewport's own mouse position is still
		# the previous frame's value at this point.
		var mb := event as InputEventMouse
		_pan_anchor = mb.position if mb != null else _mouse_local()
	elif event.is_action_released("pan"):
		panning = false

func _process(_delta: float) -> void:
	if !panning: return
	# Screen-space delta on purpose: get_global_mouse_position() moves with this
	# camera, so using it as the delta feeds back into the transform and the view
	# bounces back to where it started.
	var current := _mouse_local()
	global_position -= (current - _pan_anchor) / zoom
	_pan_anchor = current

func _mouse_local() -> Vector2:
	return get_viewport().get_mouse_position()

func set_zoom_to(new_zoom: Vector2) -> void:
	var mouse_pos := get_global_mouse_position()
	var cam_pos := get_screen_center_position()
	var last_zoom: float = zoom.x
	
	zoom = new_zoom.clampf(0.01, 5.)
	
	var change: float = zoom.x / last_zoom
	global_position = (cam_pos - mouse_pos) / change + mouse_pos
	reset_smoothing()
