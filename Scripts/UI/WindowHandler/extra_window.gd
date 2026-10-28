extends Window
class_name ExtraWindow

const WINDOW_SIZE := Vector2(512, 512)
const BUTTON_MARGIN: int = 16
# The silhouette is reduced to a convex hull, so extra sampling resolution buys
# nothing: 64 already resolves it, and the whole chain costs a third of 128.
const BITMAP_SIZE = 64
# Grown in window pixels so the grab margin no longer scales with the sample size.
const PASSTHROUGH_GROW: float = 10.0

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
var updated_image :Image
var update_buffer_lock :bool = false
var _last_polygon := PackedVector2Array()
# Downscaled mirror of this window rendered by the GPU. Reading it back costs a
# small fixed sync instead of transferring the full window every other frame.
var _sample_view :SubViewport
var _sample_camera :Camera2D

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
	
func _physics_process(_delta: float) -> void:
	if borderless and mouse_pos == mouse_pos.clamp(position, position + size) and !dragging and !camera.panning:
		update_buffer_lock = !update_buffer_lock
		if !update_buffer_lock:
			_sample_camera.global_position = camera.global_position
			_sample_camera.zoom = camera.zoom * (float(BITMAP_SIZE) / maxf(float(size.x), 1.0))
			updated_image = _sample_view.get_texture().get_image()
			return
			
		if updated_image == null:
			return
		
		var scale := Vector2(size) / Vector2(float(BITMAP_SIZE), float(BITMAP_SIZE))
		var bm = BitMap.new()
		
		bm.create_from_image_alpha(updated_image)
		#bm.grow_mask(3,Rect2(Vector2(), bm.get_size()))
		
		var array = bm.opaque_to_polygons(Rect2(Vector2(), bm.get_size()),1)
		
		if !array.is_empty():
			var polygon = PackedVector2Array()
			for p in array:
				polygon.append_array(p)
			polygon = Geometry2D.convex_hull(polygon)
			for index in polygon.size():
				polygon[index] *= scale
			polygon = Geometry2D.offset_polygon(polygon, PASSTHROUGH_GROW, Geometry2D.JOIN_MITER)[0]
			# Each assignment rebuilds a GDI region and makes the compositor redo the
			# window shape, so skip it while the silhouette is unchanged.
			if polygon == _last_polygon:
				return
			_last_polygon = polygon
			mouse_passthrough_polygon = polygon
		else:
			if !_last_polygon.is_empty():
				_last_polygon = PackedVector2Array()
				mouse_passthrough_polygon = []
	else:
		if !mouse_passthrough_polygon.is_empty():
			updated_image = null
			_last_polygon = PackedVector2Array()
			mouse_passthrough_polygon = []

func on_focus_enter():
	pass
	if GlobInput.rawMouseInput != null:
		GlobInput.rawMouseInput.refresh()
