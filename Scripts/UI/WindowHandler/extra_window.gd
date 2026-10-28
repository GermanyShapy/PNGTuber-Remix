extends Window
class_name ExtraWindow

const WINDOW_SIZE := Vector2(512, 512)
const BUTTON_MARGIN: int = 16
# Alpha above this counts as solid. The answer comes from the GPU because sprite
# opacity is produced by the sprite shader, not by a CPU-side alpha mask.
const PROBE_ALPHA: float = 0.02
# Sample resolution for the hit test; each texel covers size/BITMAP_SIZE pixels.
const BITMAP_SIZE = 64
# Neighbourhood probed around the cursor to absorb the lag between sampling and
# using the answer.
const EDGE_SLACK: int = 1

var dragging := false
var offset := Vector2i.ZERO

var viewport_container := SubViewportContainer.new()
var viewport := SubViewport.new()
var effects := TextureRect.new()
var camera := WindowCamera.new()
var button := Button.new()
var control := Control.new()
var was_pressed_before := false
var mouse_pos :Vector2i = Vector2()
var update_buffer_lock :bool = false
# Downscaled mirror of this window rendered by the GPU. Reading it back costs a
# small fixed sync instead of transferring the full window every other frame.
var _sample_view :SubViewport
var _sample_camera :Camera2D
var _last_sample :Image
var _wct :Object
var _hwnd :int = 0

#var test_frame = 0

func _init(world: World2D, remove_window: Callable, lock_window: Callable, other_camera: Camera2D, container_material: ShaderMaterial, effects_material: ShaderMaterial) -> void:
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	add_child(viewport_container)
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.add_child(viewport)
	viewport_container.stretch = true
	viewport_container.material = container_material
	viewport.transparent_bg = true
	viewport.world_2d = world
	viewport.add_child(camera)
	camera.global_position = other_camera.global_position
	camera.zoom = other_camera.zoom
	viewport_container.add_child(effects)
	effects.texture = viewport.get_texture()
	effects.material = effects_material
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.stretch_mode = TextureRect.STRETCH_KEEP
	
	hide()
	size = WINDOW_SIZE
	title = "Window " + str(len(WindowHandler.windows) + 1)
	transient = false
	always_on_top = true
	transparent = true
	transparent_bg = true
	force_native = true
	
	close_requested.connect(remove_window.bind(self))
	
	add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_default_cursor_shape = Control.CURSOR_DRAG
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	
	control.add_child(button)
	button.theme = Settings.current_theme
	button.text = tr("TR_LOCK_SIZE")
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position -= Vector2.ONE * BUTTON_MARGIN
	button.pressed.connect(lock_window.bind(self))
	
	self.focus_entered.connect(on_focus_enter)
	
	# Same world, same camera, but a BITMAP_SIZE square target: the GPU does the
	# downscale, so the readback never touches the full-resolution frame.
	_sample_view = SubViewport.new()
	_sample_view.size = Vector2i(BITMAP_SIZE, BITMAP_SIZE)
	_sample_view.transparent_bg = true
	_sample_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sample_view.world_2d = world
	_sample_camera = Camera2D.new()
	_sample_view.add_child(_sample_camera)
	add_child(_sample_view)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("lmb"):
		offset = get_mouse_position()
		dragging = true
		
		was_pressed_before = true
	elif event.is_action_released("lmb"):
		dragging = false
		was_pressed_before = false
	
	viewport.push_input(event)

func _process(_delta: float) -> void:
	mouse_pos = DisplayServer.mouse_get_position()
	if dragging:
		position = mouse_pos - offset
	_update_click_through()

func _physics_process(_delta: float) -> void:
	# Only the sample matters now; the silhouette is read from its alpha channel.
	if !borderless or dragging or camera.panning:
		return
	update_buffer_lock = !update_buffer_lock
	if !update_buffer_lock:
		return
	_sample_camera.global_position = camera.global_position
	_sample_camera.zoom = camera.zoom * (float(BITMAP_SIZE) / maxf(float(size.x), 1.0))
	_last_sample = _sample_view.get_texture().get_image()

func _ready() -> void:
	_wct = ClassDB.instantiate("WinClickThrough")
	if _wct == null:
		push_warning("WinClickThrough extension missing; native click-through disabled")

func _exit_tree() -> void:
	if _wct != null and _hwnd != 0:
		_wct.call("set_click_through", _hwnd, false)

# Switches the whole window between hit-testable and click-through. No GDI region
# is involved, so rendering is never clipped to a silhouette.
func _update_click_through() -> void:
	if _wct == null:
		return
	if _hwnd == 0:
		if !is_visible():
			return
		_resolve_hwnd()
		if _hwnd == 0:
			return

	var through := true
	if !borderless or dragging or camera.panning:
		through = false
	else:
		var local := Vector2(mouse_pos - position)
		if local.x >= 0.0 and local.y >= 0.0 and local.x < float(size.x) and local.y < float(size.y):
			through = !_alpha_hit(local)
	_wct.call("set_click_through", _hwnd, through)

func _alpha_hit(local: Vector2) -> bool:
	if _last_sample == null:
		# No sample yet: stay interactive rather than swallow clicks.
		return true
	var px := Vector2i(local * float(BITMAP_SIZE) / Vector2(size))
	for dy in range(-EDGE_SLACK, EDGE_SLACK + 1):
		for dx in range(-EDGE_SLACK, EDGE_SLACK + 1):
			var q := px + Vector2i(dx, dy)
			if q.x < 0 or q.y < 0 or q.x >= _last_sample.get_width() or q.y >= _last_sample.get_height():
				continue
			if _last_sample.get_pixel(q.x, q.y).a > PROBE_ALPHA:
				return true
	return false

# get_window_id() is 0 until the native window exists, and id 0 means the MAIN
# window; resolving that id would make the whole application click-through.
func _resolve_hwnd() -> void:
	var wid := get_window_id()
	if wid == 0:
		return
	var main_hwnd: int = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, 0)
	var candidate: int = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, wid)
	if candidate == 0 or candidate == main_hwnd:
		return
	_hwnd = candidate

func on_focus_enter():
	pass
	if GlobInput.rawMouseInput != null:
		GlobInput.rawMouseInput.refresh()
