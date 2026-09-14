extends Node2D

enum Mouth {
	Closed,
	Open,
	Screaming
}

signal key_pressed
signal blink

signal reinfo
signal animation_state
signal slider_values
signal light_info

signal speaking
signal not_speaking

signal update_anim
signal remake_layers
signal update_layers
signal update_layer_visib
signal reparent_objects
signal reparent_layers

signal new_file
signal load_model
signal project_updates

signal mode_changed
signal deselect
signal theme_update

signal update_pos_spins
signal update_offset_spins

signal delete_states
signal remake_states
signal remake_for_plus
signal reset_states

signal update_mouse_vel_pos
signal editing_for_changed
signal add_window
signal edit_windows

signal update_ui_pieces
signal image_replaced
signal add_new_image
signal delete_image
signal remake_image_manager
signal show_model_warning

signal dev_mode

# Remix version
@onready var version: String = ProjectSettings.get_setting("application/config/version")

var blink_timer : Timer = Timer.new()
var held_sprite = null
var held_sprites : Array[SpriteObject] = []
var tick = 0
var current_state : int = 0
var mouth := Mouth.Closed:
	set(x):
		if x == mouth: return
		mouth = x
		_refresh_mouth_prefix()
var editing_for := Mouth.Closed:
	set(x):
		if x == editing_for: return
		editing_for = x
		_refresh_mouth_prefix()
		editing_for_changed.emit()

# Mouth-variant prefix cache for SpriteObjectClass.get_value(). The prefix
# depends only on editing_for / mouth -- never on the sprite -- so resolving it
# once per change turns the hot path (get_value runs ~35x per sprite per state
# switch) into a single member read instead of a property read + branch + match.
# An empty prefix means "no variant lookup, return the plain value", which is
# exactly what Mouth.Closed used to short-circuit to.
var mouth_prefix : String = ""

func _refresh_mouth_prefix() -> void:
	var st : int = editing_for
	if st == Mouth.Closed:
		st = mouth
	match st:
		Mouth.Open: mouth_prefix = "mo_"
		Mouth.Screaming: mouth_prefix = "scream_"
		_: mouth_prefix = ""

var settings_dict : Dictionary = {
	sensitivity_limit = 1,
	volume_limit = 0.1,
	volume_delay = 0.5,
	blink_speed = 1,
	blink_chance = 10,
	checkinput = true,
	bg_color = Color.SLATE_GRAY,
	is_transparent = false,
	states = [{}],
	light_states = [{}],
	darken = false,
	anti_alias = true,

	dim_color = Color.DIM_GRAY,
	auto_save = false,
	auto_save_timer = 1.0,

	saved_inputs = [],
	zoom = Vector2(1,1),
	pan = Vector2(0, 0),

	should_delta = true,
	max_fps = 60,
	monitor = Monitor.ALL_SCREENS,
	snap_out_of_bounds = true,
	cycles = [],

	trimmed = false,
	
	custom_hotkeys = {}
}

var image_manager_data : Array = []

var mode: int = 0: set = set_mode

var show_warning: bool = false:
	set(n_mode):
		show_model_warning.emit(n_mode)
		show_warning = n_mode

var new_rot = 0
var static_view : bool = false
var spinbox_held : bool = false

var main = null
var sprite_container = null

var grid_visible: bool = false
var grid_snap: bool = false
var grid_size: float = 1.0
var grid_overlay: Node2D = null

func snap_position(pos: Vector2) -> Vector2:
	if !grid_snap or grid_size <= 0.0:
		return pos
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)
var viewer = null
var viewport = null
var top_ui = null
var file_dialog : FileDialog = null
var light = null
var camera : Camera2D = null
var camera_pos : Node2D = null
var mesh_pointer : Node2D = null

var throwable_spawner : Node2D = null

var frame_counter : int = 0
const FRAME_INTERVAL : int = 3  # Run every 5 frames
var swtich_session_popup : Node = null
var over_tex : bool = false
var over_normal_tex : bool = false

var over_mesh_tex : bool = false
var mesh_text_node : Node = null

var save_path : String = ""

# State-switch throttling. When a rendered frame overruns its budget the engine
# catches up by running several physics ticks in the next one, and StateButton
# polls its hotkey from _physics_process while StandGlobalInput refreshes
# just_pressed_details only once per *rendered* frame -- so a single key press
# used to fire a full switch per tick (~85 ms x 5 on a 336-sprite model).
# Requests arriving inside the same rendered frame are coalesced here and the
# last one is applied once, when _process drains it at the end of that frame.
var _switch_frame : int = -1
var _coalesced_state : int = -1

var is_editor : bool = true:
	set(x):
		if x == is_editor:
			is_editor = x
			return
		var was_editor := is_editor
		is_editor = x
		Settings.change_cursor()
		# Editor panels are not refreshed while in preview mode (see
		# _emit_state_signals), so push one full refresh on the way back.
		if x and not was_editor:
			call_deferred("_refresh_editor_ui")

var image_data = ImageData.new()
var image_data_normal = ImageData.new()
var selected_mesh_inx : int = 1
var folder_texture : Texture2D = null

var obj : Object = Object.new()

func _ready():
	DisplayServer.register_additional_output(obj)
	var img = Image.create_empty(32,32, false, Image.FORMAT_RGBA8)
	folder_texture = ImageTexture.create_from_image(img)
	create_placeholders()
	get_window().min_size = Vector2(360,360) # For those who want to use the main window as a desktop pet
	add_child(blink_timer)
	blinking()
	get_window().title = "PNGTuber-Remix V" + version
	current_state = 0

func _exit_tree() -> void:
	DisplayServer.unregister_additional_output(obj)

func create_placeholders():
	image_data.runtime_texture = preload("res://Misc/TestAssets/Placeholder.png")
	image_data_normal.runtime_texture = preload("res://Misc/TestAssets/Placeholder_n.png")

func set_mode(new_mode) -> void:
	if new_mode == mode: return
	mode = new_mode

	match mode:
		0:
			get_viewport().transparent_bg = false
			RenderingServer.set_default_clear_color(Color.SLATE_GRAY)
			if main.has_node("%Control"):
				main.get_node("%Control").show()
				var control = main.get_node("%Control")
				control.get_node("%RightPanel").show()
				control.get_node("%MeshPanel").hide()
				control.get_node("%BrushesPanel").hide()
				control.get_node("%BrushData").hide()
			is_editor = true
		1:
			RenderingServer.set_default_clear_color(settings_dict.bg_color)
			get_viewport().transparent_bg = settings_dict.is_transparent
			if main.has_node("%Control"):
				main.get_node("%Control").hide()
			is_editor = false
			if light != null && is_instance_valid(light):
				light.get_node("Grab").hide()
			deselect.emit()
			static_view = false
		2:
			get_viewport().transparent_bg = false
			RenderingServer.set_default_clear_color(Color.SLATE_GRAY)
			if main.has_node("%Control"):
				main.get_node("%Control").show()
				var control = main.get_node("%Control")
				control.get_node("%RightPanel").hide()
				control.get_node("%MeshPanel").show()
				control.get_node("%BrushesPanel").show()
				control.get_node("%BrushData").show()
			is_editor = true

	for i in Global.get_tree().get_nodes_in_group("Meshes"):
		i.get_node("%MeshEditor").queue_redraw()

	#save current change
	for i in get_tree().get_nodes_in_group("Sprites"):
		i.save_state(current_state)

	Settings.theme_settings.mode = mode
	Settings.save()
	mode_changed.emit(mode)

func blinking():
	blink_timer.wait_time = settings_dict.blink_speed
	blink_timer.start()
	await blink_timer.timeout
	var rand = randi() % int(settings_dict.blink_chance)
	if rand == 0:
		blink.emit()
	blinking()

func load_sprite_states(state):
	# A structural reload (model load / state added / state deleted) is not a
	# switch, so reset the throttle baseline: a switch issued later in this very
	# frame must apply immediately instead of being coalesced onto the reload.
	_switch_frame = -1
	_coalesced_state = -1

	current_state = state
	for i in get_tree().get_nodes_in_group("Sprites"):
		i.get_state(current_state)

	# include_layer_visib stays false: the original load path never repainted
	# the layer-visibility buttons, only get_sprite_states did.
	_emit_state_signals(current_state, false)

func get_sprite_states(state):
	# Coalesce every further request inside the same rendered frame: a physics
	# catch-up burst must not multiply the cost of one key press.
	var frame := Engine.get_process_frames()
	if frame == _switch_frame:
		_coalesced_state = state
		return
	_apply_state(state)

# Unconditional apply. Must stay free of the coalescing guard above: _process
# drains the pending request within the very same frame the burst arrived in,
# so re-entering get_sprite_states() there would coalesce onto itself and
# postpone the switch by a frame.
func _apply_state(state):
	_switch_frame = Engine.get_process_frames()
	_coalesced_state = -1

	var group_sprites: Array[Node] = get_tree().get_nodes_in_group("Sprites")
	if is_editor:
		for i in group_sprites:
			i.save_state(current_state)

	var from := current_state
	current_state = state

	for i in group_sprites:
		# Identical content: get_state() would merge the same values back into
		# sprite_data and re-write every guarded property with the value it
		# already holds (measured: the data-driven half is ~57% of get_state,
		# and 42% of all switches -- ~98% within a cluster -- are identical).
		# Safe because is_editor just ran save_state(from), so states[from]
		# mirrors sprite_data; any real difference, including an unsaved edit,
		# makes the comparison fail and takes the full path instead.
		var st : Array = i.states
		if (from < st.size() and state < st.size()
				and i.has_method("apply_state_side_effects")
				and st[from] == st[state]):
			i.apply_state_side_effects(state)
		else:
			i.get_state(current_state)

	_emit_state_signals(current_state)

# Signals are split by who consumes them:
#   * animation_state -> SpritesContainer.get_state + reaction_config.
#     reset_animations; light_info -> light_source.get_state (LightSource lives
#     inside the rendered SubViewport). Both drive the model itself.
#   * update_anim -> model_effects / model_animation_parameters set_data(),
#     which push values into sliders and those value_changed handlers call
#     sprite_container.save_state() again. That write-back is a persistence
#     side effect, not just a repaint, so it stays unconditional.
#   * reinfo / update_layer_visib only repaint editor panels that do not exist
#     in preview mode -- and reinfo alone walks every sprite in the model
#     (336 sel() calls, ~11 ms), so they are skipped there.
# When the editor comes back, the is_editor setter pushes a full refresh.
func _emit_state_signals(state : int, include_layer_visib : bool = true) -> void:
	animation_state.emit(state)
	light_info.emit(state)
	update_anim.emit()

	if is_editor:
		reinfo.emit()
		if include_layer_visib:
			update_layer_visib.emit()

func _refresh_editor_ui() -> void:
	reinfo.emit()
	update_layer_visib.emit()
	update_anim.emit()

func _input(_event : InputEvent):
	for i in held_sprites:
		if i != null && is_instance_valid(i):
			if Input.is_action_pressed("ctrl"):
				if Input.is_action_pressed("scrollup"):
					i.sprite_data.rotation -= 0.05
					rot(i)

				elif Input.is_action_pressed("scrolldown"):
					i.sprite_data.rotation += 0.05
					rot(i)

func offset(i):
	i.get_node("%Grab").anchors_preset = Control.LayoutPreset.PRESET_FULL_RECT
	i.sprite_data.position = i.position
	i.sprite_data.offset = i.get_node("%Sprite2D").position
	i.save_state(current_state)

	update_offset_spins.emit()

func _process(delta):
	if _coalesced_state >= 0:
		var pending := _coalesced_state
		_coalesced_state = -1
		# Only apply when the coalesced target actually differs: repeats of a
		# switch that already happened must not cost another full pass.
		if pending != current_state:
			_apply_state(pending)
	if settings_dict.should_delta:
		tick = wrap(tick + delta, 0, 922337203685477630)
	else:
		tick = wrap(tick + 1, 0, 922337203685477630)
	if !spinbox_held:
		moving_origin(delta)
		moving_sprite(delta)

func moving_origin(delta):
	for i in held_sprites:
		if i != null && is_instance_valid(i):
			if Input.is_action_pressed("up"):
				i.get_node("%Sprite2D").global_position.y += 10 * delta
				i.global_position.y -= 10 * delta
				offset(i)
			elif Input.is_action_pressed("down"):
				i.get_node("%Sprite2D").global_position.y -= 10 * delta
				i.global_position.y += 10 * delta
				offset(i)
			if Input.is_action_pressed("left"):
				i.get_node("%Sprite2D").global_position.x += 10 * delta
				i.global_position.x -= 10 * delta
				offset(i)
			elif Input.is_action_pressed("right"):
				i.get_node("%Sprite2D").global_position.x -= 10 * delta
				i.global_position.x += 10 * delta

				offset(i)


		if main.can_scroll:
			if Input.is_action_pressed("ctrl"):
				if Input.is_action_just_pressed("lmb"):
					var of = i.get_parent().get_global_mouse_position() - i.global_position
					i.global_position += of
					i.get_node("%Sprite2D").global_position -= of

					offset(i)

func rot(i):
	i.rotation = i.get_value("rotation")
	i.save_state(current_state)
	update_pos_spins.emit()

func moving_sprite(delta):
	for i in held_sprites:
		if i != null && is_instance_valid(i):
			if Input.is_action_pressed("w"):
				i.position.y -= 10 * delta
				i.sprite_data.position.y -= 10 * delta
				update_spins()
			elif Input.is_action_pressed("s_move"):
				i.position.y += 10 * delta
				i.sprite_data.position.y += 10 * delta
				update_spins()

			if Input.is_action_pressed("a"):
				i.position.x -= 10 * delta
				i.sprite_data.position.x -= 10 * delta
				update_spins()

			elif Input.is_action_pressed("d"):
				i.position.x += 10 * delta
				i.sprite_data.position.x += 10 * delta
				update_spins()

func update_spins():
	for i in held_sprites:
		if i != null && is_instance_valid(i):
			i.save_state(current_state)
			update_pos_spins.emit()

func _physics_process(_delta: float) -> void:
	mouse_delay()
	if Input.is_action_just_pressed("debug_rep"):
		print_orphan_nodes()

func mouse_delay():
	frame_counter += 1
	if frame_counter >= FRAME_INTERVAL:
		update_mouse_vel_pos.emit()
		frame_counter = 0

func update_camera_smoothing() -> void:
	if !is_instance_valid(camera): return
	camera.position_smoothing_enabled = Settings.theme_settings.floaty_panning
