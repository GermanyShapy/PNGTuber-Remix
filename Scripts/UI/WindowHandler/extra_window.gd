extends Window
class_name ExtraWindow

const WINDOW_SIZE := Vector2(512, 512)
const BUTTON_MARGIN: int = 16

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
# Hit-test / click-through state machine, kept in its own node.
var click_through :ClickThroughController

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
	
	click_through = ClickThroughController.new()
	click_through.target = self
	click_through.world = world
	add_child(click_through)

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

func on_focus_enter():
	pass
	if GlobInput.rawMouseInput != null:
		GlobInput.rawMouseInput.refresh()
