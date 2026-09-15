extends SpriteObject

func get_default_object_data() -> Dictionary:
	return {
		vframes = 1,
		wiggle = false,
		wiggle_amp = 0,
		wiggle_freq = 0,
		wiggle_physics = false,
		wiggle_rot_offset = Vector2(0.5, 0.5),
		follow_parent_effects = false,
		flip_sprite_h = false,
		flip_sprite_v = false,
		non_animated_sheet = false,
		animate_to_mouse = false,
		animate_to_mouse_speed = 10,
		animate_to_mouse_track_pos = true,
		frame = 0,
	}

var wiggle_val : float = 0

# get_state() runs for every sprite on every state switch. Resolving a %Name
# there costs a scene-tree lookup each time; SpriteObjectClass already caches
# modifier / modifier1 / sprite_object this way, so do the same for the one
# get_state still resolved per call (measured ~0.4-1.0 ms per switch @336).
# @onready is required: a plain `var x = %Node` initialiser runs before this
# node is in the tree, so it resolves to null and every later use errors.
@onready var hit_detection : StaticBody2D = %HitDetection

func _init() -> void:
	cached_defaults = DEFAULT_DATA.merged(get_default_object_data(), true)
	sprite_data = cached_defaults.duplicate(true)

func _ready():
	sprite_type = "Sprite2D"
	Global.image_replaced.connect(image_replaced)
	Global.reparent_objects.connect(reparent_obj)
	og_glob = get_value("position")
	animation()
	Global.reinfo.connect(sel)
	Global.deselect.connect(desel)
	grab_object.button_down.connect(_on_grab_button_down)
	grab_object.button_up.connect(_on_grab_button_up)

	await get_tree().create_timer(0.1).timeout
	if sprite_object == null or static_collision == null: return
	static_collision.shape.radius = 500
	static_collision.shape.height = 500
	if sprite_object.texture && !get_value("folder"):
		var w : float = float(sprite_object.texture.get_width())
		var h : float = float(sprite_object.texture.get_height())
		if w > 0 && h > 0:
			var r : float = min(w, h)
			static_collision.shape.height = h
			static_collision.shape.radius = Vector2(r, r).length()*0.5

func sel():
	if self in Global.held_sprites:
		selected = true
		%Origin.show()
		if get_value("folder"):
			%Grab.stretch_mode = TextureButton.StretchMode.STRETCH_KEEP
			%Grab.texture_normal.width = 500
			%Grab.texture_normal.height = 500
		%Grab.anchors_preset = Control.LayoutPreset.PRESET_FULL_RECT
		%Grab.modulate.a = 1.0
	else:
		%Origin.hide()

		desel()

func desel():
	%Origin.hide()
	selected = false

func animation():
	if not get_value("non_animated_sheet"):
		if not get_value("advanced_lipsync"):
			sprite_object.hframes = get_value("hframes")
			sprite_object.vframes = get_value("vframes")
			if get_value("hframes") > 1 or get_value("vframes") > 1:
				if get_value("one_shot") && sprite_object.frame == (get_value("hframes")*get_value("vframes")) - 1:
					return
				sprite_object.frame = wrapi(sprite_object.frame + 1, 0, (get_value("hframes")*get_value("vframes")))
			else:
				sprite_object.frame = 0

	elif get_value("non_animated_sheet"):
		sprite_object.hframes = get_value("hframes")
		sprite_object.vframes = get_value("vframes")
		if (get_value("hframes")*get_value("vframes")) - 1 > 1:
			if !get_value("animate_to_mouse"):
				sprite_object.frame = get_value("frame")
	
	if is_inside_tree():
		$Animation.wait_time = 1.0/get_value("animation_speed") 
		$Animation.start()

func animation_reset():
	if not get_value("non_animated_sheet"):
		if not get_value("advanced_lipsync"):
			sprite_object.frame = 0
	
	elif get_value("non_animated_sheet"):
		sprite_object.hframes = get_value("hframes")
		sprite_object.vframes = get_value("vframes")
		if (get_value("hframes")*get_value("vframes")) - 1 > 1:
			if !get_value("animate_to_mouse"):
				sprite_object.frame = get_value("frame")
	
	if is_inside_tree():
		$Animation.wait_time = 1.0/get_value("animation_speed") 
		$Animation.start()

func _process(_delta):
	if selected:
		%Grab.mouse_filter = Control.MouseFilter.MOUSE_FILTER_PASS
		%Selection.texture = sprite_object.texture
		%Selection.show()
		%Selection.hframes = sprite_object.hframes
		%Selection.vframes = sprite_object.vframes
		%Selection.frame = sprite_object.frame
		%Selection.flip_h = sprite_object.flip_h
		%Selection.flip_v = sprite_object.flip_v

		if get_value("wiggle"):
			%WiggleOrigin.show()
			var pos = (sprite_object.material.get_shader_parameter("rotation_offset") - Vector2.ONE / 2)* sprite_object.texture.get_size()
			%WiggleOrigin.position = Vector2(pos.x, pos.y)
			%Selection.material.set_shader_parameter("wiggle", true)
			%Selection.material.set_shader_parameter("rotation_offset", sprite_object.material.get_shader_parameter("rotation_offset"))
			%Selection.material.set_shader_parameter("rotation", sprite_object.material.get_shader_parameter("rotation"))
		else:
			%Selection.material.set_shader_parameter("wiggle", false)
			%WiggleOrigin.hide()

	else:
		%Grab.mouse_filter = Control.MouseFilter.MOUSE_FILTER_IGNORE
		%Selection.hide()
		%Grab.modulate.a = 0.0
		%WiggleOrigin.hide()

	if dragging:
		var mouse_pos = get_parent().to_local(get_global_mouse_position())
		for s in Global.held_sprites:
			var new_position: Vector2 = mouse_pos - drag_offsets[s]
			new_position = Global.snap_position(new_position)
			s.position = new_position
			s.sprite_data.position = new_position
			s.save_state(Global.current_state)
		Global.update_pos_spins.emit()

	if !Global.static_view:
		if get_value("wiggle"):
			wiggle_sprite()
	else:
		if get_value("wiggle"):
			sprite_object.material.set_shader_parameter("rotation", 0)

	advanced_lipsyc()

func _on_grab_button_down():
	if selected:
		if not Input.is_action_pressed("ctrl"):
			# Start dragging for all selected sprites
			dragging = true
			drag_offsets.clear()
			var mouse_pos = get_parent().to_local(get_global_mouse_position())
			for s in Global.held_sprites:
				drag_offsets[s] = mouse_pos - s.position
			begin_drag_record()

func _on_grab_button_up():
	if selected && dragging:
		save_state(Global.current_state)
		dragging = false
		end_drag_record()

func _input(event: InputEvent) -> void:
	if event.is_action_released("lmb"):
		if selected && dragging:
			save_state(Global.current_state)
			dragging = false
			end_drag_record()

func wiggle_sprite():
	var length: float = 0.0

	if get_value("wiggle_physics"):
		if (get_parent() is Sprite2D or get_parent() is WigglyAppendage2D) and is_instance_valid(get_parent()):
			var c_parent = get_parent().owner
			if c_parent != null and is_instance_valid(c_parent):
				var drag_node = c_parent.get_node_or_null("%Drag")
				var movements_node = c_parent.get_node_or_null("%Movements")
				if drag_node != null and movements_node != null:
					var c_parrent_length = movements_node.glob.y - drag_node.global_position.y
					var c_parrent_length2 = movements_node.glob.x - drag_node.global_position.x
					length += (c_parrent_length + c_parrent_length2) / 50.0

	wiggle_val = lerp(wiggle_val, sin((Global.tick * get_value("wiggle_freq"))+length)*get_value("wiggle_amp"), 0.05)

	if !get_parent() is Sprite2D:
		sprite_object.material.set_shader_parameter("rotation", wiggle_val )
	elif get_parent() is Sprite2D:
		if get_value("follow_parent_effects"):
			var c_parent = get_parent().owner
			sprite_object.material.set_shader_parameter("rotation", c_parent.get_node("%Sprite2D").material.get_shader_parameter("rotation"))
		else:
			sprite_object.material.set_shader_parameter("rotation", wiggle_val )

func advanced_lipsyc():
	if get_value("advanced_lipsync"):
		if sprite_object.hframes != 14:
			sprite_object.hframes = 14
		if reaction_config.currently_speaking:
			if GlobalAudioStreamPlayer.t.value == 0:
				sprite_object.frame_coords.x = 13
			else:
				sprite_object.frame_coords.x = GlobalAudioStreamPlayer.t.actual_value
		else:
			sprite_object.frame_coords.x = 13

func save_state(id):
	# Skip the deep copy when nothing changed. save_state() runs for every
	# sprite on every state switch as an editor-side safety net (some legacy UI
	# never saves on its own), and re-storing an identical dictionary measured
	# ~21 ms on a 336-sprite model while the unchanged case needs no work.
	if id >= 0 and id < states.size() and states[id] == sprite_data:
		return
	states[id] = sprite_data.duplicate(true)

# Side-effect half of get_state(). Global._apply_state() calls this instead of
# get_state() when the target state's content is identical to the current one:
# in that case every value the data-driven half would merge into sprite_data,
# and every property it would write, already holds the value it would write, so
# skipping it changes nothing observable.
# MUST stay in sync with get_state(): each item below also lives there.
func apply_state_side_effects(id) -> void:
	if id < 0 or id >= states.size(): return
	if (states[id] as Dictionary).is_empty():
		states[id] = sprite_data.duplicate(true)
		return
	if get_value("should_reset_state"):
		reaction_config.reset_anim()
	if !get_value("should_blink"):
		modifier1.show()
	else:
		reaction_config.update_to_mode_change(Global.mode)
	animation()
	advanced_lipsyc()
	if !get_value("should_blink"):
		modifier1.modulate.a = 1
		modifier1.show()

func get_state(id):
	if !states[id].is_empty():
		# %Sprite2D equals to get_node("Sprite2D")
		# actor.sprite_object is a cache ref of %Sprite2D
		# use %Sprite2D without cache will call get_node() lots of times, and make the program slower 
		var dict = states[id]
		sprite_data.merge(dict, true)
		
		if get_value("should_reset_state"):
			reaction_config.reset_anim()
		
		var old_glob = global_position

		# Every write below is guarded by a value comparison: with physics
		# interpolation enabled each write marks the CanvasItem dirty, and on a
		# 336-sprite model the unconditional version measured ~20 ms per state
		# switch for values that had not changed at all.
		var want_offset : Vector2 = get_value("offset")
		if sprite_object.position != want_offset:
			sprite_object.position = want_offset
		var want_scale := Vector2(
			-1.0 if get_value("flip_sprite_h") else 1.0,
			-1.0 if get_value("flip_sprite_v") else 1.0)
		if sprite_object.scale != want_scale:
			sprite_object.scale = want_scale

		var want_z : int = get_value("z_index")
		if modifier1.z_index != want_z:
			modifier1.z_index = want_z
		var want_colored : Color = get_value("colored")
		if modulate != want_colored:
			modulate = want_colored
		var want_tint : Color = get_value("tint")
		if sprite_object.self_modulate != want_tint:
			sprite_object.self_modulate = want_tint
		var want_hit : bool = get_value("can_be_hit")
		var want_disabled := not want_hit
		if static_collision.disabled != want_disabled:
			static_collision.disabled = want_disabled
		var hit_detect := hit_detection
		if hit_detect.get_collision_layer_value(2) != want_hit:
			hit_detect.set_collision_layer_value(2, want_hit)
		apply_transform()
	#	use apply_transform to update all
	#	global_position = get_value("global_position")
		
		var drag_snap = get_value("drag_snap")
		if (global_position - old_glob).length() > drag_snap && drag_snap != 999999.0:
			modifier.global_position = modifier1.global_position
			%Dragger.global_position = %Modifier.global_position
		
		var want_clip : int = get_value("clip")
		if sprite_object.get_clip_children_mode() != want_clip:
			sprite_object.set_clip_children_mode(want_clip)
		
		# get_shader_parameter() is a cheap dictionary read compared to the
		# re-batch a redundant set_shader_parameter() triggers.
		var mat : ShaderMaterial = sprite_object.material
		var want_wiggle = get_value("wiggle")
		if mat.get_shader_parameter("wiggle") != want_wiggle:
			mat.set_shader_parameter("wiggle", want_wiggle)
		var want_rot_off = get_value("wiggle_rot_offset")
		if mat.get_shader_parameter("rotation_offset") != want_rot_off:
			mat.set_shader_parameter("rotation_offset", want_rot_off)

		if get_value("advanced_lipsync"):
			sprite_object.hframes = 6

		if !get_value("should_blink"):
			modifier1.show()
		else:
			reaction_config.update_to_mode_change(Global.mode)

		if get_value("fade"):
			trigger_fade(visible)
		else:
			# A hidden asset must keep alpha at 0: get_state runs again at load
			# end (load_sprite_states) after sync_asset_visibility, and setting
			# a=colored.a here would resurrect the a=1.0 + visible=false pair,
			# making fade_asset's first show short-circuit (instant pop).
			if is_asset and !sprite_object.visible:
				if modulate.a != 0.0:
					modulate.a = 0.0
			else:
				var want_a : float = get_value("colored").a
				if modulate.a != want_a:
					modulate.a = want_a
			var want_visible : bool = get_value("visible")
			if visible != want_visible:
				visible = want_visible
		animation()
		set_blend(get_value("blend_mode"))
		advanced_lipsyc()

		# Same check as `!get_value("cycle") in range(cycles.size() + 1)`, but
		# that form built a fresh Array and linear-scanned it for every sprite
		# on every switch (measured ~262 us per switch on a 336-sprite model).
		var cyc : Variant = get_value("cycle")
		if cyc == null or cyc < 0 or cyc > Global.settings_dict.cycles.size():
			sprite_data.cycle = 0

		if !get_value("should_blink"):
			modifier1.modulate.a = 1
			modifier1.show()

	elif states[id].is_empty():
		states[id] = sprite_data.duplicate(true)

func check_talk():
	if get_value("should_talk"):
		if get_value("open_mouth"):
			%Rotation.hide()
		else:
			%Rotation.show()
	else:
		%Rotation.show()

func reposition_plus(parent):
	for i in parent:
		if i.sprite_id == parent_id:
			sprite_data.position -= i.get_value("offset")
			if is_plus_first_import:
				for state in states:
					if !state.is_empty():
						global = global_position
						state.position = get_value("position")

func apply_transform():
		var want_pos : Vector2 = get_value("position")
		var want_rot : float = get_value("rotation")
		var want_scale : Vector2 = get_value("scale")
		var want_skew : Vector2 = get_value("skew")
		# Node2D transform setters carry no value guard in the engine, so every
		# write below marks the CanvasItem dirty. Build the transform this call
		# would produce and bail out when the node already holds it: on the
		# 336-sprite reference model a real state switch leaves ~90% of the
		# sprites untouched. The target uses skew 0 because the explicit skew
		# reset below normalizes the node's own `skew` field first, so the body
		# is guaranteed to land exactly on it.
		var want := Transform2D(want_rot, want_scale, 0.0, want_pos)
		want.x = want.x.rotated(deg_to_rad(want_skew.x))
		want.y = want.y.rotated(deg_to_rad(want_skew.y))
		if transform == want:
			return
		# Resetting the skew field replaces the old "write a throwaway RIGHT/UP
		# basis pair and let the position setter decompose it again" trick: same
		# result, one write less, and the target above matches by construction.
		skew = 0.0
		position = want_pos
		rotation = want_rot
		scale = want_scale
		transform.x = transform.x.rotated(deg_to_rad(want_skew.x))
		transform.y = transform.y.rotated(deg_to_rad(want_skew.y))
