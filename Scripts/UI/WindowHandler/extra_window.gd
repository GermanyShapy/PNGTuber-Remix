extends Window

class_name ExtraWindow

const WINDOW_SIZE := Vector2(512, 512)
const BUTTON_MARGIN: int = 16
const BITMAP_SIZE = 128

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

var test_frame = 0

func _init(world: World2D, remove_window: Callable, lock_window: Callable, other_camera: Camera2D, container_material: ShaderMaterial, effects_material: ShaderMaterial) -> void:
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
	
	hide()
	size = WINDOW_SIZE
	title = tr("TR_WINDOW") + " " + str(len(WindowHandler.windows) + 1)
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
	button.pressed.connect(lock_window.bind(self ))
	
	self.focus_entered.connect(on_focus_enter)


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
	
func _physics_process(delta: float) -> void:
	if borderless and mouse_pos == mouse_pos.clamp(position, position + size) and !dragging and !camera.panning:
		update_buffer_lock = !update_buffer_lock
		if !update_buffer_lock:
			updated_image = get_texture().get_image()
			return
			
		if updated_image == null:
			return
		
		var image_original_size = updated_image.get_size()
		updated_image.resize(BITMAP_SIZE, BITMAP_SIZE, Image.INTERPOLATE_NEAREST)
		var scale = Vector2(float(image_original_size.x) / float(BITMAP_SIZE), float(image_original_size.y) / float(BITMAP_SIZE))
		var bm = BitMap.new()
		
		bm.create_from_image_alpha(updated_image)
		#bm.grow_mask(3,Rect2(Vector2(), bm.get_size()))
		
		var array = bm.opaque_to_polygons(Rect2(Vector2(), bm.get_size()),1)
		
		if !array.is_empty():
			var polygon = PackedVector2Array()
			for p in array:
				polygon.append_array(p)
			polygon = Geometry2D.offset_polygon(Geometry2D.convex_hull(polygon),2.5,Geometry2D.JOIN_MITER)[0]
			for index in polygon.size():
				polygon[index] *= scale
			mouse_passthrough_polygon = polygon
			
			test_frame += 1
			if test_frame % 30 == 0:
				print("___ Tick " + str(Engine.get_physics_frames()) + " ___")
				print("window: " + str(size) + " in " + str(position))
				print("window.stretch_transform: " + str(get_stretch_transform()))
				print("image: " + str(image_original_size))
				print("viewport.scale: " + str(viewport_container.scale))
				print("points: " + str(polygon.size()) + " ->>> " + str(polygon))
		else:
			mouse_passthrough_polygon = []
	else:
		if !mouse_passthrough_polygon.is_empty():
			updated_image = null
			mouse_passthrough_polygon = []

func on_focus_enter():
	pass
	if GlobInput.rawMouseInput != null:
		GlobInput.rawMouseInput.refresh()
