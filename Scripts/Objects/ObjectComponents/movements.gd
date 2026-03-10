extends Node

@export var actor: SpriteObject

var modifier_node: Node2D
var sprite_node: Node
var parent_node: Node
var parent_movements: Node
@export var mesh : CustomMesh = null

var applied_pos: Vector2 = Vector2.ZERO
var applied_rotation: float = 0.0
var applied_scale: Vector2 = Vector2.ONE

var placeholder_position: Vector2 = Vector2.ZERO
var prev_smoothed_pos: Vector2 = Vector2.ZERO
var has_prev: bool = false
var follow_point_rot: float = 0.0
var biased: float = 0.0
var strength: float = 0.0
var _b: float = 0.0

var last_wobble_pos: Vector2 = Vector2.ZERO
var paused_wobble: Vector2 = Vector2.ZERO
var paused_rotation: float = 0.0
var rest: bool = false
var index_change_len : float = 0
var index_change_len_y : float = 0

var shadow_dragger : Vector2 = Vector2(0,0)
var glob: Vector2 = Vector2.ZERO
var no_bounce_shadow_dragger : Vector2 = Vector2(0,0)
var no_bounce_glob: Vector2 = Vector2.ZERO

var last_rot: float = 0.0
var should_rot_rotation: float = 0.0
var rot_drag: float = 0.0
var no_bounce_rot_drag: float = 0.0
var no_bounce_stretch: Vector2 = Vector2.ONE

var rdrag_rad: float = 0.0
var shadow_target : Vector2 = Vector2.ZERO
var last_modifier_position = Vector2(0,0)

var last_follow_global_transform : Transform2D = Transform2D.IDENTITY # %Modifier1
var last_follow_transform : Transform2D = Transform2D.IDENTITY # %Modifier1
var last_movement_transform : Transform2D = Transform2D.IDENTITY # %Modifier
var last_glob_transform : Transform2D = Transform2D.IDENTITY # %Modifier
var last_no_bounce_transform : Transform2D = Transform2D.IDENTITY # %Modifier

func _ready() -> void:
	modifier_node = %Modifier
	sprite_node =  %Sprite2D
	
	parent_node = get_parent()
	if parent_node and parent_node.has_node("%Movements"):
		parent_movements = parent_node.get_node("%Movements")
	rdrag_rad = deg_to_rad(actor.get_value("rdragStr"))
	
	init_position.call_deferred()

func init_position():
	placeholder_position = actor.modifier1.global_position
	last_follow_global_transform = actor.modifier1.global_transform
	last_follow_transform = actor.modifier1.transform
	applied_pos = placeholder_position
	applied_rotation = 0.0
	applied_scale = Vector2.ONE
	shadow_dragger = applied_pos
	no_bounce_shadow_dragger = applied_pos
	modifier_node.rotation = 0.0
	modifier_node.scale = Vector2.ONE

func _physics_process(delta: float) -> void:
	(Global.sprite_container.movement_physics_process_stack as Array).push_front(self.movement_physics_process)

func movement_physics_process(delta: float) -> void:
	follow_wiggle(delta)
	placeholder_position = actor.modifier1.global_position
	applied_pos =  placeholder_position
	
	# Calculate movement data in diffrent mode
	if !Global.static_view and actor.rest_mode != 5:
		# ADD:  actor.rest_mode == 6 is "rest move and reset"
		if rest and (actor.rest_mode == 2 or actor.rest_mode == 3 or actor.rest_mode == 6):
			if actor.rest_mode == 6:
				last_wobble_pos = Vector2.ZERO
				paused_wobble = Vector2.ZERO
				should_rot_rotation = 0.0
			rest_mode_movements(delta)
		else:
			if actor.get_value("should_rotate"):
				auto_rotate()
			else:
				should_rot_rotation = 0.0
			rainbow(delta)
			movements(delta)
	elif Global.static_view:
		static_prev()
	else:
		modifier_node.position = Vector2(0,0)
		modifier_node.rotation = 0.0
		modifier_node.scale = Vector2(1,1)
		sprite_node.self_modulate = actor.get_value("tint")
	# Apply the transforms
	if not Global.static_view:
		last_no_bounce_transform.rotated_local(follow_point_rot + should_rot_rotation)
		last_no_bounce_transform.origin = last_follow_global_transform.affine_inverse() * last_no_bounce_transform.origin
		last_no_bounce_transform = last_follow_global_transform * last_no_bounce_transform
		
		applied_rotation = rot_drag + follow_point_rot + should_rot_rotation
		modifier_node.rotation = applied_rotation
		modifier_node.global_position = applied_pos
		modifier_node.scale = applied_scale
		
	# Z-Index
	var index_change = actor.get_value("index_change")
	var index_change_y = actor.get_value("index_change_y")
	if index_change != 0.0 or index_change_y != 0.0:
		shadow_target = modifier_node.global_position + actor.follow_componet.target_pos
		var test = (shadow_target - actor.global_position)
		if !test.is_zero_approx():
			test = test.normalized()
			
		var signed_len_x = (test.x)
		var signed_len_y = (test.y)
		index_change_len = lerp(index_change_len, signed_len_x, 0.95)
		index_change_len_y = lerp(index_change_len_y, signed_len_y, 0.95)
		index_change_len = index_change_len * index_change
		index_change_len_y = index_change_len_y * index_change_y
		modifier_node.z_index = floori(index_change_len + index_change_len_y)
	
	if actor.sprite_type == "Mesh" and mesh != null && is_instance_valid(mesh):
		var can_deform : bool = false
		if is_instance_valid(Global.mesh_text_node):
			can_deform = Global.mesh_text_node.deform
		if !mesh.editable && !can_deform:
			var mesh_len = last_wobble_pos + actor.follow_componet.target_pos + (actor.modifier1.global_position - last_modifier_position )
			var amp = Vector2(actor.get_value("xAmp"), actor.get_value("yAmp"))
			var follow_amp = Vector2(actor.get_value("look_at_mouse_pos"), actor.get_value("look_at_mouse_pos_y"))
			var final_amp = amp  + follow_amp + Vector2(25,25)
			var safe_deform_pos = mesh.apply_wobble_to_deformer(mesh_len, delta, final_amp, final_amp.length())
			if abs(safe_deform_pos.x) != 0:
				mesh.deform_x = safe_deform_pos.x
				mesh.update_physics(delta, false)
			if abs(safe_deform_pos.y) != 0:
				mesh.deform_y = safe_deform_pos.y
				mesh.update_physics(delta, false)
			
		last_modifier_position.lerp(actor.modifier1.global_position, 0.08)
	# Record the transforms
	last_follow_global_transform = actor.modifier1.global_transform
	last_follow_transform = actor.modifier1.transform
	last_glob_transform = last_movement_transform
	last_movement_transform = actor.modifier.global_transform
	pass
	
func _process(_delta: float) -> void:
	if actor.get_value("static_obj") and !actor.dragging:
		(Global.sprite_container.movement_process_stack as Array).push_front(self.static_obj_process)

func static_obj_process(delta):
	actor.global_position = Global.sprite_container.get_parent().get_parent().to_global(actor.get_value("position"))
	
	return
	var current_parent: SpriteObject = actor
	var current_transform: Transform2D = actor.transform
	while ((current_parent.get_parent() is Sprite2D or current_parent.get_parent() is WigglyAppendage2D) and is_instance_valid(current_parent) ):
		current_parent = current_parent.get_parent().owner
		current_transform.origin += current_parent.get_value("offset") as Vector2
		current_transform = current_parent.transform * current_transform
		
	actor.global_transform = current_transform

func static_prev():
	actor.modifier.position = Vector2(0,0)
	actor.modifier.rotation = 0.0
	actor.modifier.scale = Vector2(1,1)
	actor.sprite_object.self_modulate = actor.get_value("tint")
	actor.modifier1.position = Vector2.ZERO
	actor.modifier1.rotation = 0.0
	actor.modifier1.scale = Vector2(1,1)
	modifier_node.z_index = 0

func get_c_parent_movement() -> Node:
	if ((actor.get_parent() is Sprite2D or actor.get_parent() is WigglyAppendage2D) and is_instance_valid(parent_node) ):
		var c_parent = actor.get_parent().owner
		if c_parent != null && is_instance_valid(c_parent):
			return c_parent.movements
	return null
	
func movements(delta):
	if Global.static_view:
		return
	var c_parent_movement = get_c_parent_movement()
	var no_bounce = actor.get_value("ignore_bounce")
	# the root node calculate the original no_bounce_shadow_dragger
	# then following child node calculate based on its parent.
	if c_parent_movement == null:
		no_bounce_shadow_dragger.y -= Global.sprite_container.bounceChange
	else:
		# restore the dragger based on the simulated last_no_bounce_transform
		# it remain the relative change of the movement without bounce effect
		var restored_dragger = no_bounce_shadow_dragger
		restored_dragger = c_parent_movement.last_no_bounce_transform.affine_inverse() * restored_dragger
		restored_dragger = c_parent_movement.last_movement_transform * restored_dragger
		no_bounce_shadow_dragger = restored_dragger
		# if the two position are similar, synchronize the data to avoid error accumulation
		if no_bounce_shadow_dragger.is_equal_approx(shadow_dragger):
			no_bounce_shadow_dragger = shadow_dragger
		
	# if "physics" is disable, the movement will only be affected by its %Modifier1, instead of global space.
	# maintain the relative transform between shadow_dragger and %Modifier1,
	# then add on the inner movement(transform) of %Modifier1.
	# if the non-physics node has no parents(in other words, it's the outermost node),
	# it's will ignore bounce force and not jump anymore.
	if !actor.get_value("physics"):
		no_bounce = false
		if c_parent_movement != null:
			shadow_dragger = last_follow_global_transform.affine_inverse() * shadow_dragger
			shadow_dragger = actor.modifier1.global_transform * shadow_dragger
			shadow_dragger = actor.modifier1.transform.affine_inverse() * shadow_dragger
			shadow_dragger = last_follow_transform * (shadow_dragger * actor.modifier1.transform)
		else:
			applied_pos.y -= Global.sprite_container.get_bounce_height()
	
	glob = shadow_dragger
	no_bounce_glob = no_bounce_shadow_dragger

	drag(delta, no_bounce)
	wobble(delta)
	
	# after apply position change, calculate rotation and stretch
	var normal_length = (glob.x - shadow_dragger.x) + (glob.y - shadow_dragger.y)
	var no_bounce_length = (no_bounce_glob.x - no_bounce_shadow_dragger.x) + (no_bounce_glob.y - no_bounce_shadow_dragger.y)
	var length = normal_length if !no_bounce else no_bounce_length
	var relative_rot_drag = rot_drag - no_bounce_rot_drag
	var relative_stretch = applied_scale - no_bounce_stretch
	var relative_glob = glob - no_bounce_glob
	
	if no_bounce:
		shadow_dragger = no_bounce_shadow_dragger
		glob = no_bounce_glob
	
	update_last_rot_frquecy(delta)
	rot_drag = emulate_drag_rotation(rot_drag, length, delta)
	applied_scale = emulate_drag_stretch(modifier_node.scale, length, delta)
	no_bounce_rot_drag = emulate_drag_rotation(no_bounce_rot_drag, no_bounce_length, delta)
	no_bounce_stretch = emulate_drag_stretch(no_bounce_stretch, no_bounce_length, delta)
	
	# simulate the transform without bounce, based on movement local transform(no change yet)
	# it will be completed in movement_physics_process(delta):
	# rotation += follow_point_rot + should_rot_rotation, then convert to global transformation
	last_no_bounce_transform = Transform2D(
			relative_rot_drag + no_bounce_rot_drag, 
			relative_stretch + no_bounce_stretch,
			0.0,
			relative_glob + no_bounce_shadow_dragger
		)
	
	#if actor.hold_to_show and !shadow_dragger.is_equal_approx(Vector2.ZERO):
		#pass #TEST
		#print(actor.sprite_name + " => "
		#+ " |> dragger: " + str("[{x}, {y}]").format({"x": "%8.3f" % shadow_dragger.x, "y": "%8.3f" % shadow_dragger.y}) 
		#+ " |> glob: " + str("[{x}, {y}]").format({"x": "%8.3f" % glob.x, "y": "%8.3f" % glob.y}) 
		#+ " |> nb_dragger: " + str("[{x}, {y}]").format({"x": "%8.3f" % no_bounce_shadow_dragger.x, "y": "%8.3f" % no_bounce_shadow_dragger.y}) 
		#+ " |> nb_glob: " + str("[{x}, {y}]").format({"x": "%8.3f" % no_bounce_glob.x, "y": "%8.3f" % no_bounce_glob.y}) 
		#)
	
func rest_mode_movements(delta):
	if Global.static_view:
		return
	var c_parent_movement = get_c_parent_movement()
	var no_bounce = actor.get_value("ignore_bounce")
	# the root node calculate the original no_bounce_shadow_dragger
	# then following child node calculate based on its parent.
	if c_parent_movement == null:
		no_bounce_shadow_dragger.y -= Global.sprite_container.bounceChange
	else:
		# restore the dragger based on the simulated last_no_bounce_transform
		# it remain the relative change of the movement without bounce effect
		var restored_dragger = no_bounce_shadow_dragger
		restored_dragger = c_parent_movement.last_no_bounce_transform.affine_inverse() * restored_dragger
		restored_dragger = c_parent_movement.last_movement_transform * restored_dragger
		no_bounce_shadow_dragger = restored_dragger
		# if the two position are similar, synchronize the data to avoid error accumulation
		if no_bounce_shadow_dragger.is_equal_approx(shadow_dragger):
			no_bounce_shadow_dragger = shadow_dragger
		
	# if "physics" is disable, the movement will only be affected by its %Modifier1, instead of global space.
	# maintain the relative transform between shadow_dragger and %Modifier1,
	# then add on the inner movement(transform) of %Modifier1.
	# if the non-physics node has no parents(in other words, it's the outermost node),
	# it's will ignore bounce force and not jump anymore.
	if !actor.get_value("physics"):
		no_bounce = false
		if c_parent_movement != null:
			shadow_dragger = last_follow_global_transform.affine_inverse() * shadow_dragger
			shadow_dragger = actor.modifier1.global_transform * shadow_dragger
			shadow_dragger = actor.modifier1.transform.affine_inverse() * shadow_dragger
			shadow_dragger = last_follow_transform * (shadow_dragger * actor.modifier1.transform)
		else:
			applied_pos.y -= Global.sprite_container.get_bounce_height()
	
	glob = shadow_dragger
	no_bounce_glob = no_bounce_shadow_dragger
	
	drag(delta)
	applied_pos += last_wobble_pos #Stay the last time(before rest) position
	
	# after apply position change, calculate rotation and stretch
	var normal_length = (glob.x - shadow_dragger.x) + (glob.y - shadow_dragger.y)
	var no_bounce_length = (no_bounce_glob.x - no_bounce_shadow_dragger.x) + (no_bounce_glob.y - no_bounce_shadow_dragger.y)
	var length = normal_length if !no_bounce else no_bounce_length
	var relative_rot_drag = rot_drag - no_bounce_rot_drag
	var relative_stretch = applied_scale - no_bounce_stretch
	var relative_glob = glob - no_bounce_glob
	
	if no_bounce:
		shadow_dragger = no_bounce_shadow_dragger
		glob = no_bounce_glob
	
	update_last_rot_frquecy(delta)
	rot_drag = emulate_drag_rotation(rot_drag, length, delta)
	applied_scale = emulate_drag_stretch(modifier_node.scale, length, delta)
	no_bounce_rot_drag = emulate_drag_rotation(no_bounce_rot_drag, no_bounce_length, delta)
	no_bounce_stretch = emulate_drag_stretch(no_bounce_stretch, no_bounce_length, delta)
	
	# simulate the transform without bounce, based on movement local transform(no change yet)
	# it will be completed in movement_physics_process(delta):
	# rotation += follow_point_rot + should_rot_rotation, then convert to global transformation
	last_no_bounce_transform = Transform2D(
			relative_rot_drag + no_bounce_rot_drag, 
			relative_stretch + no_bounce_stretch,
			0.0,
			relative_glob + no_bounce_shadow_dragger
		)

func drag(_delta, no_bounce = false):
	var drag_speed = actor.get_value("dragSpeed")
	var target = applied_pos
	if drag_speed < 1.0:
		drag_speed = 1.0
		
	var t = 1.0 / drag_speed
	shadow_dragger = shadow_dragger.lerp(target, t)
	no_bounce_shadow_dragger = no_bounce_shadow_dragger.lerp(target, t)
	if no_bounce:
		applied_pos = no_bounce_shadow_dragger
	else:
		applied_pos = shadow_dragger
	

func wobble(delta: float) -> void:
	if actor.get_value("pause_movement"):
		if actor.is_all_default("xFrq"):
			last_wobble_pos.x = 0
		if actor.is_all_default("yFrq"):
			last_wobble_pos.y = 0
	else:
		var offset = delta if Global.settings_dict.should_delta else 1.0
		last_wobble_pos.x = 0
		last_wobble_pos.y = 0
		if actor.get_value("xAmp") != 0.0:
			paused_wobble.x += offset
			last_wobble_pos.x = actor.get_value("xAmp") * sin(paused_wobble.x * actor.get_value("xFrq"))
		if actor.get_value("yAmp") != 0.0:
			paused_wobble.y += offset
			last_wobble_pos.y = actor.get_value("yAmp") * sin(paused_wobble.y * actor.get_value("yFrq"))
		
	if actor.sprite_type == "Mesh" and mesh != null && is_instance_valid(mesh):
		if !actor.get_value("move_with_wobble"):
			return
	
	applied_pos += last_wobble_pos

func update_last_rot_frquecy(delta: float):
	var rot_frquecy = actor.get_value("rot_frq")
	var rdragStr = actor.get_value("rdragStr")
	
	if rot_frquecy == 0.0:
		last_rot = 0.0
	else:
		if actor.get_value("pause_movement"):
			paused_rotation += delta if Global.settings_dict.should_delta else 1.
		else:
			last_rot = sin((Global.tick-paused_rotation) * rot_frquecy) * deg_to_rad(rdragStr)

func emulate_drag_rotation(last_rot_drag, length, delta: float) -> float:
	var rot_frquecy = actor.get_value("rot_frq")
	var rdragStr = actor.get_value("rdragStr")
	
	if rdragStr == 0.0 and last_rot_drag == 0.0:
		return 0.0 #no need to rotation drag
	
	last_rot_drag = lerp_angle(last_rot_drag, last_rot, 0.15)
	var yvel = 0.0
	if rdragStr != 0.0:
		yvel = ((length * rdragStr)* 0.5)
		yvel = clamp(yvel,actor.get_value("rLimitMin"),actor.get_value("rLimitMax"))
	
	#rot_drag = GlobalCalculations.is_nan_or_inf(lerp_angle(rot_drag,deg_to_rad(yvel),0.08))
	return lerp_angle(last_rot_drag,deg_to_rad(yvel),0.08)
	
func emulate_drag_stretch(last_stretch, length, delta: float) -> Vector2:
	var stretchAmount = actor.get_value("stretchAmount")
	if stretchAmount == 0.0 and last_stretch == Vector2.ONE:
		return Vector2.ONE # no need to stretch
		
	var yvel = (length * stretchAmount * 0.01)
	var target = Vector2(1.0-yvel,1.0+yvel)
	
	return lerp(last_stretch,target,0.1)

func rotationalDrag(length, delta: float):
	var rot_frquecy = actor.get_value("rot_frq")
	var rdragStr = actor.get_value("rdragStr")
	
	if rot_frquecy == 0.0:
		last_rot = 0
		if rdragStr == 0.0 and rot_drag == 0.0:
			return #no need to rotation drag
	else:
		if actor.get_value("pause_movement"):
			paused_rotation += delta if Global.settings_dict.should_delta else 1.
		else:
			last_rot = sin((Global.tick-paused_rotation) * rot_frquecy) * deg_to_rad(actor.get_value("rdragStr"))
	
	rot_drag = lerp_angle(rot_drag, last_rot, 0.15)
	var yvel = 0.0
	if rdragStr != 0.0:
		yvel = ((length * actor.get_value("rdragStr"))* 0.5)
		yvel = clamp(yvel,actor.get_value("rLimitMin"),actor.get_value("rLimitMax"))
	
	#rot_drag = GlobalCalculations.is_nan_or_inf(lerp_angle(rot_drag,deg_to_rad(yvel),0.08))
	rot_drag = lerp_angle(rot_drag,deg_to_rad(yvel),0.08)

func stretch(length, _delta):
	var stretchAmount = actor.get_value("stretchAmount")
	if stretchAmount == 0.0 and modifier_node.scale == Vector2.ONE:
		return # no need to stretch
		
	var yvel = (length * stretchAmount * 0.01)
	var target = Vector2(1.0-yvel,1.0+yvel)
	
	applied_scale = lerp(modifier_node.scale,target,0.1)
	#modifier_node.scale

var points_cache: Array = []
var points_dirty: bool = true

func follow_wiggle(_delta):
	if not actor.get_value("follow_wa_tip"):
		follow_point_rot = 0.0
		return
	var parent = actor.get_parent()
	if not is_instance_valid(parent) or not (parent is WigglyAppendage2D):
		follow_point_rot = 0.0
		return
	var tip_index = clamp(actor.get_value("tip_point"), 0, parent.points.size() - 1)
	var raw_tip = parent.points[tip_index]
	var global_raw_tip = parent.to_global(parent.points[tip_index])
	var speed_strength = actor.get_value("follow_strength")
	if not has_prev:
		prev_smoothed_pos = global_raw_tip
		has_prev = true
	var d = prev_smoothed_pos.distance_to(global_raw_tip)
	var w = clamp(d * speed_strength, 0.0, 1.0)
	var smoothed = prev_smoothed_pos.lerp(global_raw_tip, w)
	prev_smoothed_pos = smoothed
	var parent_pos = actor.modifier1.global_position
	var final_pos = smoothed.lerp(parent_pos, actor.get_value("follow_strength"))
	actor.modifier1.global_position = final_pos
	
	var prev_point_pos
	if tip_index > 0:
		prev_point_pos = parent.points[tip_index - 1]
	else:
		prev_point_pos = raw_tip - Vector2(cos(parent._rest_direction_angle), sin(parent._rest_direction_angle))
	var dir = raw_tip - prev_point_pos
	if dir == Vector2.ZERO:
		dir = Vector2(cos(parent._rest_direction_angle), sin(parent._rest_direction_angle))
	var dir_angle = atan2(dir.y, dir.x)
	var rest_angle = parent._rest_direction_angle
	var min_angle = deg_to_rad(actor.get_value("follow_wa_mini")) + rest_angle
	var max_angle = deg_to_rad(actor.get_value("follow_wa_max")) + rest_angle
	var rel_angle = wrapf(dir_angle - rest_angle, -PI, PI)
	var target_ang = rest_angle + rel_angle

	if abs(target_ang - biased) < actor.get_value("rotation_threshold"):
		return

	_b = target_ang
	biased = lerp(biased, _b, actor.get_value("follow_strength"))
	follow_point_rot = GlobalCalculations.clamp_angle(biased, min_angle, max_angle, rest_angle)

func rainbow(delta):
	if Global.mode != 0 and actor.get_value("hidden_item"):
		sprite_node.self_modulate.a = 0.0
		return

	if actor.get_value("rainbow"):
		var h_speed = actor.get_value("rainbow_speed") * delta
		if not actor.get_value("rainbow_self"):
			sprite_node.self_modulate.s = 0
			modifier_node.modulate.s = 1
			modifier_node.modulate.h = wrap(modifier_node.modulate.h + h_speed, 0, 1)
		else:
			modifier_node.modulate.s = 0
			sprite_node.self_modulate.s = 1
			sprite_node.self_modulate.h = wrap(sprite_node.self_modulate.h + h_speed, 0, 1)
	else:
		if actor.get_value("tint") != sprite_node.self_modulate:
			sprite_node.self_modulate = actor.get_value("tint")
		modifier_node.modulate.s = 0

func auto_rotate():
	should_rot_rotation += actor.get_value("should_rot_speed")

func _frame_lerp(delta: float, base_t := 0.15) -> float:
	var fps = max(30.0, Engine.max_fps)
	var per_second_k = -log(1.0 - clamp(base_t, 0.001, 0.999)) * fps
	return clamp(1.0 - exp(-per_second_k * clamp(delta, 0.0, 1.0)), 0.0, 1.0)

func _on_sprite_object_visibility_changed() -> void:
	rest = !actor.is_visible_in_tree() if !(actor == null) else false
	
	if rest and actor.tween != null:
		actor.tween.kill()
		if actor.was_active_before:
			actor.modulate.a = 1.0
		else:
			actor.modulate.a = 0.0
