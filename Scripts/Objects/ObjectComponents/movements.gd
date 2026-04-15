extends Node

@export var actor : SpriteObject
@export var mesh : CustomMesh = null

@onready var dragger : Node2D = %Dragger
@onready var modifier_node : Node2D = %Modifier
@onready var modifier1_node : Node2D = %Modifier1
@onready var sprite_node : Node = %Sprite2D
@onready var follow_component : Node = %FollowPosition

var applied_pos : Vector2 = Vector2.ZERO
var applied_rotation : float = 0.0
var applied_scale : Vector2 = Vector2.ONE

var placeholder_position : Vector2 = Vector2.ZERO

var last_wobble_pos : Vector2 = Vector2.ZERO
var glob : Vector2 = Vector2.ZERO

var rot_drag : float = 0.0
var follow_point_rot : float = 0.0
var should_rot_rotation : float = 0.0
var last_rot : float = 0.0
var paused_rotation : float = 0.0

var paused_wobble : Vector2 = Vector2.ZERO

var calc_length : float = 0.0

var prev_smoothed_pos : Vector2 = Vector2.ZERO
var has_prev : bool = false
var biased : float = 0.0

var ik_smoothed_rot : float = 0.0
var ik_angular_velocity : float = 0.0

var last_modifier_position : Vector2 = Vector2.ZERO
var shadow_target : Vector2 = Vector2.ZERO

var index_change_len : float = 0.0
var index_change_len_y : float = 0.0

var rest : bool = false

var last_mouse_position : Vector2 = Vector2.ZERO
var last_dist : Vector2 = Vector2.ZERO
var applied_pos_offset : Vector2 = Vector2.ZERO

var modifier_global : Vector2 =  Vector2.ZERO
var yvel : float = 0.0

func _ready() -> void:
	placeholder_position = actor.global_position
	applied_pos = placeholder_position
	glob = placeholder_position
	await get_tree().create_timer(0.025).timeout
	ik_smoothed_rot = modifier1_node.global_rotation
	last_modifier_position = sprite_node.global_position
	dragger.top_level = true
	dragger.global_position = modifier_node.global_position

func _physics_process(delta: float) -> void:
	modifier_global = modifier1_node.global_position
	placeholder_position = modifier1_node.position
	applied_pos =  placeholder_position
	
	if !Global.static_view && actor.rest_mode != 4:
		if (actor.rest_mode == 2 or actor.rest_mode == 3) && rest:
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
	if !actor.get_value("follow_wa_tip"):
		follow_point_rot = 0.0
	else:
		follow_wiggle(delta)
	if !Global.static_view:
		var final_rot = applied_rotation + rot_drag + follow_point_rot + should_rot_rotation 
		modifier_node.rotation = GlobalCalculations.is_nan_or_inf(final_rot)
		modifier_node.position = GlobalCalculations.is_nan_or_inf(applied_pos)
	
	shadow_target = modifier_node.global_position + follow_component.final_target
	if actor.get_value("index_change") != 0 or actor.get_value("index_change_y") != 0:
		var test = (shadow_target - actor.global_position).normalized()
		var signed_len_x = (test.x)
		var signed_len_y = (test.y)
		index_change_len = lerp(index_change_len, signed_len_x, 0.95)
		index_change_len_y = lerp(index_change_len_y, signed_len_y, 0.95)
		index_change_len = index_change_len * actor.get_value("index_change")
		index_change_len_y = index_change_len_y * actor.get_value("index_change_y")
		modifier_node.z_index = clamp(floori(index_change_len + index_change_len_y), -250, 250)
	else:
		modifier_node.z_index = 0
	
	
	if actor.sprite_type == "Mesh" and mesh != null && is_instance_valid(mesh):
		var can_deform : bool = false
		if is_instance_valid(Global.mesh_text_node) && Global.mode == 2:
			can_deform = Global.mesh_text_node.deform
		if can_deform:
			return
			
		if Global.static_view:
			mesh.deform_x = 0.5
			mesh.deform_y = 0.5
		else:
			var t : Vector2 = (last_modifier_position - %Origin.global_position)
			var mesh_len = (last_wobble_pos + follow_component.final_target )
			var amp = Vector2(actor.get_value("xAmp"), actor.get_value("yAmp"))
			var middle_x = (abs(actor.get_value("pos_x_min"))+ actor.get_value("pos_x_max"))*0.5
			var middle_y = (abs(actor.get_value("pos_y_min"))+ actor.get_value("pos_y_max"))*0.5
			var follow_amp = Vector2(middle_x, middle_y)
			var final_amp = amp  + follow_amp 
			if actor.get_value("physics"):
				mesh_len +=   t
				var dir = Vector2(actor.get_value("mesh_phys_x"), actor.get_value("mesh_phys_y")).normalized()
				final_amp -=  (Vector2(300,300) -  abs(Vector2(actor.get_value("mesh_phys_x"), actor.get_value("mesh_phys_y"))))*dir
				
			var safe_deform_pos
			if Tracker.working:
				safe_deform_pos = mesh.apply_wobble_to_deformer(mesh_len , delta, final_amp, 0.08)
				
			else:
				safe_deform_pos = mesh.apply_wobble_to_deformer(mesh_len, delta, final_amp, 0.15)
			if abs(safe_deform_pos.x) != 0:
				mesh.deform_x = safe_deform_pos.x
			if abs(safe_deform_pos.y) != 0:
				mesh.deform_y = safe_deform_pos.y
			
			mesh.call_deferred("update_physics", delta, false)
	
		last_modifier_position = last_modifier_position.lerp(%Origin.global_position,0.125 )

func _process(_delta : float) -> void:
	if actor.get_value("static_obj"):
		var object_pos = actor.get_value("position")
		var pos = Global.main.get_node("%Node2D").to_global(actor.get_value("position"))
		var p = actor.get_parent()
		if (p is Sprite2D or p is WigglyAppendage2D or p is CustomMesh)  && is_instance_valid(p):
			var parent = p.owner
			if parent.get_value("static_obj"):
				pos = p.to_global(object_pos)
			
		%Rotation.global_position = pos

func static_prev() -> void:
	modifier_node.position = Vector2.ZERO
	modifier_node.rotation = 0.0
	modifier_node.scale = Vector2.ONE
	modifier1_node.position = Vector2.ZERO
	modifier1_node.rotation = 0.0
	modifier1_node.scale = Vector2.ONE
	sprite_node.self_modulate = actor.get_value("tint")
	modifier_node.z_index = 0

func movements(delta: float) -> void:
	glob = dragger.global_position
	apply_recursive_look_at_chain(actor)
	wobble(delta)
	drag(delta)

	if actor.get_value("ignore_bounce") && !actor.get_value("static_obj"):
		glob -= Vector2(0.0, Global.sprite_container.bounceChange)
	var l = glob - dragger.global_position
	var dir = l.normalized()
	var length : float = l.length() * (dir.x + dir.y)
	length = add_parent_physics(length)
	calc_length = length
	stretch(calc_length)
	rotational_drag(calc_length, delta)

func apply_recursive_look_at_chain(actor_node: SpriteObject) -> void:
	if actor_node == null or not is_instance_valid(actor_node):
		%Rotation.rotation = 0.0
		return
	if actor_node.target_ik != null and is_instance_valid(actor_node.target_ik):
		var root = actor_node.get_node("%Origin")
		var target = actor_node.target_ik.get_node("%Origin")
		if root != null and target != null:
			var target_pos: Vector2 = target.global_position - root.global_position
			apply_look_at_ik(target_pos, actor_node.get_node("%Rotation"))
			
			var ik_chain =  actor_node.target_ik.target_ik
			if ik_chain != null && is_instance_valid(ik_chain):
				var target_pos_2: Vector2 = ik_chain.get_node("%Origin").global_position - root.global_position
				apply_look_at_ik(target_pos_2, actor_node.get_node("%Rotation"))
				
			if actor_node.has_node("%Sprite2D"):
				var sprite_root = actor_node.get_node("%Sprite2D")
				for child in sprite_root.get_children():
					if child is SpriteObject && is_instance_valid(child):
						apply_recursive_look_at_chain(child)
		else:
			%Rotation.rotation = 0.0
	else:
		%Rotation.rotation = 0.0

func apply_look_at_ik(target_pos: Vector2, rotation_node : Node2D) -> void:
	var chain_softness: float = actor.get_value("chain_softness")
	var rot_min: float = actor.get_value("chain_rot_min")
	var rot_max: float = actor.get_value("chain_rot_max")
	var bone_len: float = actor.get_value("bone_length")
	var rigidity = 1.0/ max(chain_softness, 0.0001)
	var lerp_amount = clamp(target_pos.length() / max(bone_len, 0.001) * rigidity, 0.0, 1.0)
	var target_angle_global = target_pos.normalized().angle()
	target_angle_global = wrapf(target_angle_global, -PI, PI)
	target_angle_global = clamp(target_angle_global, rot_min, rot_max)
	rotation_node.global_rotation = lerp_angle(rotation_node.global_rotation,target_angle_global,lerp_amount)

func rest_mode_movements(delta : float) -> void:
	glob = dragger.global_position
	drag(delta)
	if !actor.get_value("ignore_bounce"):
		glob -= Vector2(Global.sprite_container.bounceChange, Global.sprite_container.bounceChange)
	var l = Vector2(glob - dragger.global_position)
	var l_norm = l.normalized()
	var length : float = l_norm.length() * (l.x - l.y)
	length = add_parent_physics(length)
	rotational_drag(length, delta)
	stretch(length)

func add_parent_physics(length : float) -> float:
	var leng = length
	if !actor.get_value("physics"):
		return leng
	var p = actor.get_parent()
	if (p is Sprite2D or p is WigglyAppendage2D or p is CustomMesh)  && is_instance_valid(p):
			var c_parent = actor.get_parent().owner
			if c_parent != null && is_instance_valid(c_parent):
				leng += c_parent.get_node("%Movements").calc_length
	return leng

func drag(_delta : float):
	var drag_speed = actor.get_value("dragSpeed")
	var target = modifier_node.global_position + last_wobble_pos
	if drag_speed > 0:
		var t = 1.0 / drag_speed
		dragger.global_position = dragger.global_position.lerp(target, t)
		applied_pos = applied_pos.lerp(actor.to_local(dragger.global_position), 0.5)
	else:
		dragger.global_position = target

func wobble(delta: float) -> void:
	if actor.is_default("xFrq"):
		if actor.get_value("pause_movement"):
			if actor.is_all_default("xFrq"):
				last_wobble_pos.x = 0
			else:
				paused_wobble.x += delta if Global.settings_dict.should_delta else 1.
		else:
			last_wobble_pos.x = sin((Global.tick-paused_wobble.x)*actor.get_value("xFrq"))*actor.get_value("xAmp")
	else:
		last_wobble_pos.x = sin((Global.tick)*actor.get_value("xFrq"))*actor.get_value("xAmp")
	
	if actor.is_default("yFrq"):
		if actor.get_value("pause_movement"):
			if actor.is_all_default("yFrq"):
				last_wobble_pos.y = 0
				print("d")
			else:
				paused_wobble.y += delta if Global.settings_dict.should_delta else 1.
		else:
			last_wobble_pos.y = sin((Global.tick-paused_wobble.y)*actor.get_value("yFrq"))*actor.get_value("yAmp")
	else:
		last_wobble_pos.y = sin((Global.tick)*actor.get_value("yFrq"))*actor.get_value("yAmp")
	
	
	applied_pos.x += last_wobble_pos.x
	applied_pos.y += last_wobble_pos.y

func rotational_drag(length, delta: float):
	if actor.is_default("rot_frq"):
		if actor.get_value("pause_movement"):
			if actor.is_all_default("rot_frq"):
				last_rot = 0
			else:
				paused_rotation += delta if Global.settings_dict.should_delta else 1.
		else:
			last_rot = sin((Global.tick-paused_rotation) * actor.get_value("rot_frq"))
			last_rot *= deg_to_rad(actor.get_value("rdragStr"))
	else:
		last_rot = sin((Global.tick-paused_rotation) * actor.get_value("rot_frq"))
		last_rot *= deg_to_rad(actor.get_value("rdragStr"))
	
	applied_rotation = lerp_angle(applied_rotation, last_rot, 0.15)
	yvel = ((length * actor.get_value("rdragStr")))*(actor.get_value("phys_eff")/200.0)
	
	#Calculate Max angle
	yvel = clamp(yvel,actor.get_value("rLimitMin"),actor.get_value("rLimitMax"))
	applied_rotation = lerp_angle(applied_rotation,deg_to_rad(yvel),0.15)

func stretch(length : float) -> void:
	var syvel : float = (length * actor.get_value("stretchAmount") * 0.01)* (actor.get_value("phys_eff")/200.0)
	var target : Vector2 = Vector2(1.0 - syvel, 1.0 + syvel)
	modifier_node.scale = modifier_node.scale.lerp(target, 0.15)

func follow_wiggle(_delta : float) -> void:
	var parent = actor.get_parent()
	if !parent or !(parent is WigglyAppendage2D):
		follow_point_rot = 0.0
		return

	var tip_index : int = clamp(actor.get_value("tip_point"), 0, parent.points.size() - 1)
	var raw_tip : Vector2 = parent.to_global(parent.points[tip_index])
	var real_tip : Vector2 = parent.points[tip_index]
	var local_tip : Vector2 = actor.to_local(raw_tip)
	
	if !has_prev:
		prev_smoothed_pos = local_tip
		has_prev = true

	var d : float = prev_smoothed_pos.distance_to(local_tip)
	var w : float = clamp(d * actor.get_value("follow_strength"), 0.0, 1.0)
	prev_smoothed_pos = prev_smoothed_pos.lerp(local_tip, w)

	applied_pos = prev_smoothed_pos

	var prev_point : Vector2 = local_tip
	if tip_index > 0:
		prev_point = parent.points[tip_index - 1]

	var dir : Vector2 = real_tip - prev_point
	
	var rest_angle : float = parent._rest_direction_angle
	var target_ang : float = wrapf(dir.rotated(-rest_angle).angle(), -PI, PI)

	if abs(target_ang - biased) < actor.get_value("rotation_threshold"):
		return

	biased = lerp(biased, target_ang, actor.get_value("follow_strength"))
	follow_point_rot = clamp(biased, deg_to_rad(actor.get_value("follow_wa_mini")), deg_to_rad(actor.get_value("follow_wa_max")))

func rainbow(delta : float) -> void:
	if actor.get_value("hidden_item") and Global.mode != 0:
		sprite_node.self_modulate.a = 0.0
		return

	if actor.get_value("rainbow"):
		var h_speed : float = actor.get_value("rainbow_speed") * delta
		if actor.get_value("rainbow_self"):
			sprite_node.self_modulate.s = 1.0
			modifier_node.modulate.s = 0.0
			sprite_node.self_modulate.h = wrap(sprite_node.self_modulate.h + h_speed, 0.0, 1.0)
		else:
			sprite_node.self_modulate.s = 0.0
			modifier_node.modulate.s = 1.0
			modifier_node.modulate.h = wrap(modifier_node.modulate.h + h_speed, 0.0, 1.0)
	else:
		sprite_node.self_modulate = actor.get_value("tint")
		modifier_node.modulate.s = 0.0

func auto_rotate():
	should_rot_rotation += actor.get_value("should_rot_speed")

func actor_get_parent():
	return get_parent()

func _on_sprite_object_visibility_changed() -> void:
	rest = !actor.is_visible_in_tree() if !(actor == null) else false
	
	if rest and actor.tween != null:
		actor.tween.kill()
		if actor.was_active_before:
			actor.modulate.a = 1.0
		else:
			actor.modulate.a = 0.0

######################################################
#
#
#extends Node
#
#@export var actor : SpriteObject
#@export var mesh : CustomMesh = null
#var modifier_node: Node2D
#var sprite_node: Node
#
#var applied_pos: Vector2 = Vector2.ZERO
#var applied_rotation: float = 0.0
#var applied_scale: Vector2 = Vector2.ONE
#
#var placeholder_position: Vector2 = Vector2.ZERO
#var prev_smoothed_pos: Vector2 = Vector2.ZERO
#var has_prev: bool = false
#var follow_point_rot: float = 0.0
#var biased: float = 0.0
#var strength: float = 0.0
#var _b: float = 0.0
#
#var last_wobble_pos: Vector2 = Vector2.ZERO
#var paused_wobble: Vector2 = Vector2.ZERO
#var paused_rotation: float = 0.0
#var rest: bool = false
#var index_change_len : float = 0
#var index_change_len_y : float = 0
#
#var shadow_dragger : Vector2 = Vector2(0,0)
#var glob: Vector2 = Vector2.ZERO
#var no_bounce_shadow_dragger : Vector2 = Vector2(0,0)
#var no_bounce_glob: Vector2 = Vector2.ZERO
#
#var last_rot: float = 0.0
#var should_rot_rotation: float = 0.0
#var rot_drag: float = 0.0
#var no_bounce_rot_drag: float = 0.0
#var no_bounce_stretch: Vector2 = Vector2.ONE
#var calc_length : float = 0.0
#var was_rainbow: bool = true
#var rot_frquecy: float = 0.0
#var rdrag_str: float = 0.0
#var stretch_amount: float = 0.0
#
#var ik_smoothed_rot : float = 0.0
#var ik_angular_velocity : float = 0.0
#
#var shadow_target : Vector2 = Vector2.ZERO
#
#var c_parent_movement
#var no_bounce : bool = false
#var relative_rot_drag : float = 0.0
#var relative_stretch : Vector2 = Vector2.ONE
#var relative_glob : Vector2 = Vector2.ZERO
#var last_follow_global_transform : Transform2D = Transform2D.IDENTITY # %Modifier1
#var last_follow_transform : Transform2D = Transform2D.IDENTITY # %Modifier1
#var last_movement_transform : Transform2D = Transform2D.IDENTITY # %Modifier
#var last_glob_transform : Transform2D = Transform2D.IDENTITY # %Modifier
#var last_no_bounce_transform : Transform2D = Transform2D.IDENTITY # %Modifier
#var last_modifier_position : Vector2 = Vector2.ZERO
#var last_mouse_position : Vector2 = Vector2.ZERO
#var last_dist : Vector2 = Vector2.ZERO
#var applied_pos_offset : Vector2 = Vector2.ZERO
#
#var modifier_global : Vector2 =  Vector2.ZERO
#var yvel : float = 0.0
#
#func _ready() -> void:
	#modifier_node = %Modifier
	#sprite_node =  %Sprite2D
	#
	#init_position.call_deferred()
#
#func init_position():
	#placeholder_position = actor.modifier1.global_position
	#last_follow_global_transform = actor.modifier1.global_transform
	#last_follow_transform = actor.modifier1.transform
	#applied_pos = placeholder_position
	#applied_rotation = 0.0
	#applied_scale = Vector2.ONE
	#glob = placeholder_position
	#shadow_dragger = applied_pos
	#no_bounce_shadow_dragger = applied_pos
	#modifier_node.rotation = 0.0
	#modifier_node.scale = Vector2.ONE
	#rot_frquecy = actor.get_value("rot_frq")
	#rdrag_str = actor.get_value("rdragStr")
	#stretch_amount = actor.get_value("stretchAmount")
	#
	#ik_smoothed_rot = actor.modifier1.global_rotation
	#last_modifier_position = sprite_node.global_position
	#actor.dragger.top_level = true
	#actor.dragger.global_position = modifier_node.global_position
#
#func _physics_process(delta: float) -> void:
	#modifier_global = actor.modifier1.global_position
	#placeholder_position = actor.modifier1.position
	#c_parent_movement = get_c_parent_movement()
	#rot_frquecy = actor.get_value("rot_frq")
	#rdrag_str = actor.get_value("rdragStr")
	#stretch_amount = actor.get_value("stretchAmount")
	#no_bounce = actor.get_value("ignore_bounce")
	#
	#(Global.sprite_container.movement_physics_process_stack).push_back(self.movement_physics_process)
#
#func movement_physics_process(delta: float) -> void:
	#if !actor.get_value("follow_wa_tip"):
		#follow_point_rot = 0.0
	#else:
		#follow_wiggle(delta)
	#placeholder_position = actor.modifier1.global_position
	#applied_pos =  placeholder_position
	#
	## Calculate movement data in diffrent mode
	#if !Global.static_view:
		#if actor.rest_mode == 0 or actor.rest_mode == 4:
			#modifier_node.position = Vector2.ZERO
			#modifier_node.rotation = 0.0
			#modifier_node.scale = Vector2.ONE
			#sprite_node.self_modulate = actor.get_value("tint")
			#return
		#elif rest and (actor.rest_mode == 2 or actor.rest_mode == 3 or actor.rest_mode == 6):
			#if actor.rest_mode == 6:
				#last_wobble_pos = Vector2.ZERO
				#paused_wobble = Vector2.ZERO
				#should_rot_rotation = 0.0
			#rest_mode_movements(delta)
		#else:
			#if actor.get_value("should_rotate"):
				#auto_rotate()
			#else:
				#should_rot_rotation = 0.0
			#rainbow(delta)
			#movements(delta)
			#
		## Apply the transforms
		#last_no_bounce_transform.rotated_local(follow_point_rot + should_rot_rotation)
		#last_no_bounce_transform.origin = last_follow_global_transform.affine_inverse() * last_no_bounce_transform.origin
		#last_no_bounce_transform = last_follow_global_transform * last_no_bounce_transform
		#
		#applied_rotation = rot_drag + follow_point_rot + should_rot_rotation
		#modifier_node.rotation = applied_rotation
		#modifier_node.global_position = applied_pos
		#modifier_node.scale = applied_scale
	#else:
		#static_prev()
		#
	## Z-Index
	#if actor.get_value("index_change") != 0.0 or actor.get_value("index_change_y") != 0.0:
		#shadow_target = modifier_node.global_position + actor.follow_componet.final_target
		#var test = (shadow_target - actor.global_position)
		#if !test.is_zero_approx():
			#test = test.normalized()
			#
		##var signed_len_x = (test.x)
		##var signed_len_y = (test.y)
		#index_change_len = lerp(index_change_len, (test.x), 0.95)
		#index_change_len_y = lerp(index_change_len_y, (test.y), 0.95)
		#index_change_len = index_change_len * actor.get_value("index_change")
		#index_change_len_y = index_change_len_y * actor.get_value("index_change_y")
		#modifier_node.z_index = floori(index_change_len + index_change_len_y)
	#
	#if mesh != null and is_instance_valid(mesh) and actor.sprite_type == "Mesh":
		#var can_deform : bool = false
		#if is_instance_valid(Global.mesh_text_node) && Global.mode == 2:
			#can_deform = Global.mesh_text_node.deform
			#var mesh_len = last_wobble_pos + actor.follow_componet.final_target + (actor.modifier1.global_position - last_modifier_position )
		#if can_deform:
			#return
			#
		#if Global.static_view:
			#mesh.deform_x = 0.5
			#mesh.deform_y = 0.5
		#else:
			#var t : Vector2 = (last_modifier_position - %Origin.global_position)
			#var mesh_len = (last_wobble_pos + actor.follow_component.final_target )
			#var amp = Vector2(actor.get_value("xAmp"), actor.get_value("yAmp"))
			#var middle_x = (abs(actor.get_value("pos_x_min"))+ actor.get_value("pos_x_max"))*0.5
			#var middle_y = (abs(actor.get_value("pos_y_min"))+ actor.get_value("pos_y_max"))*0.5
			#var follow_amp = Vector2(middle_x, middle_y)
			#var final_amp = amp  + follow_amp 
			#if actor.get_value("physics"):
				#mesh_len +=   t
				#var dir = Vector2(actor.get_value("mesh_phys_x"), actor.get_value("mesh_phys_y")).normalized()
				#final_amp -=  (Vector2(300,300) -  abs(Vector2(actor.get_value("mesh_phys_x"), actor.get_value("mesh_phys_y"))))*dir
				#
			#var safe_deform_pos
			#if Tracker.working:
				#safe_deform_pos = mesh.apply_wobble_to_deformer(mesh_len , delta, final_amp, 0.08)
				#
			#else:
				#safe_deform_pos = mesh.apply_wobble_to_deformer(mesh_len, delta, final_amp, 0.15)
			#if abs(safe_deform_pos.x) != 0:
				#mesh.deform_x = safe_deform_pos.x
			#if abs(safe_deform_pos.y) != 0:
				#mesh.deform_y = safe_deform_pos.y
			#
			#mesh.call_deferred("update_physics", delta, false)
	#
		#last_modifier_position = last_modifier_position.lerp(%Origin.global_position,0.125 )
	## Record the transforms
	#last_follow_global_transform = actor.modifier1.global_transform
	#last_follow_transform = actor.modifier1.transform
	#last_glob_transform = last_movement_transform
	#last_movement_transform = modifier_node.global_transform
	#
#func _process(_delta: float) -> void:
	#if actor.get_value("static_obj") and !actor.dragging:
		#(Global.sprite_container.movement_process_stack).push_back(self.static_obj_process)
#
#func static_obj_process(delta):
	#actor.global_position = Global.sprite_container.get_parent().get_parent().to_global(actor.get_value("position"))
	#
	#return # testing
	#var current_parent: SpriteObject = actor
	#var current_transform: Transform2D = actor.transform
	#while ((current_parent.get_parent() is Sprite2D or current_parent.get_parent() is WigglyAppendage2D) and is_instance_valid(current_parent) ):
		#current_parent = current_parent.get_parent().owner
		#current_transform.origin += current_parent.get_value("offset") as Vector2
		#current_transform = current_parent.transform * current_transform
		#
	#actor.global_transform = current_transform
#
#func static_prev() -> void:
	#modifier_node.position = Vector2.ZERO
	#modifier_node.rotation = 0.0
	#modifier_node.scale = Vector2.ONE
	#actor.modifier1.position = Vector2.ZERO
	#actor.modifier1.rotation = 0.0
	#actor.modifier1.scale = Vector2.ONE
	#sprite_node.self_modulate = actor.get_value("tint")
	#modifier_node.z_index = 0
#
#func get_c_parent_movement() -> Node:
	#if (is_instance_valid(actor) and (actor.get_parent() is Sprite2D or actor.get_parent() is WigglyAppendage2D)):
		#var c_parent = actor.get_parent().owner
		#if c_parent != null && is_instance_valid(c_parent):
			#return c_parent.movements
	#return null
	#
#func movements(delta):
	#if Global.static_view:
		#return
	## the root node calculate the original no_bounce_shadow_dragger
	## then following child node calculate based on its parent.
	#if c_parent_movement == null:
		#no_bounce_shadow_dragger.y -= Global.sprite_container.bounceChange
	#else:
		## restore the dragger based on the simulated last_no_bounce_transform
		## it remain the relative change of the movement without bounce effect
		#no_bounce_shadow_dragger = c_parent_movement.last_no_bounce_transform.affine_inverse() * no_bounce_shadow_dragger
		#no_bounce_shadow_dragger = c_parent_movement.last_movement_transform * no_bounce_shadow_dragger
		##no_bounce_shadow_dragger = restored_dragger
		## if the two position are similar, synchronize the data to avoid error accumulation
		#if no_bounce_shadow_dragger.is_equal_approx(shadow_dragger):
			#no_bounce_shadow_dragger = shadow_dragger
		#
	## if "physics" is disable, the movement will only be affected by its %Modifier1, instead of global space.
	## maintain the relative transform between shadow_dragger and %Modifier1,
	## then add on the inner movement(transform) of %Modifier1.
	## if the non-physics node has no parents(in other words, it's the outermost node),
	## it's will ignore bounce force and not jump anymore.
	#if !actor.get_value("physics"):
		#no_bounce = false
		#if c_parent_movement != null:
			#shadow_dragger = last_follow_global_transform.affine_inverse() * shadow_dragger
			#shadow_dragger = actor.modifier1.global_transform * shadow_dragger
			#shadow_dragger = actor.modifier1.transform.affine_inverse() * shadow_dragger
			#shadow_dragger = last_follow_transform * (shadow_dragger * actor.modifier1.transform)
		#else:
			#applied_pos.y -= Global.sprite_container.get_bounce_height()
	#
	#glob = shadow_dragger
	#no_bounce_glob = no_bounce_shadow_dragger
	#apply_recursive_look_at_chain(actor)
#
	#drag(delta, no_bounce)
	#wobble(delta)
	#
	## after apply position change, calculate rotation and stretch
	#var no_bounce_length = (no_bounce_glob.x - no_bounce_shadow_dragger.x) + (no_bounce_glob.y - no_bounce_shadow_dragger.y)
	#var length = (glob.x - shadow_dragger.x) + (glob.y - shadow_dragger.y)
	#relative_rot_drag = rot_drag - no_bounce_rot_drag
	#relative_stretch = applied_scale - no_bounce_stretch
	#relative_glob = glob + last_wobble_pos - no_bounce_glob
	#
	#if no_bounce:
		#length = no_bounce_length
		#shadow_dragger = no_bounce_shadow_dragger
		#glob = no_bounce_glob
	#
	#update_last_rot_frquecy(delta)
	#rot_drag = emulate_drag_rotation(rot_drag, length, delta)
	#applied_scale = emulate_drag_stretch(modifier_node.scale, length, delta)
	#
	#if no_bounce:
		#no_bounce_rot_drag = rot_drag
		#no_bounce_stretch = applied_scale
	#else:
		#no_bounce_rot_drag = emulate_drag_rotation(no_bounce_rot_drag, no_bounce_length, delta)
		#no_bounce_stretch = emulate_drag_stretch(no_bounce_stretch, no_bounce_length, delta)
		#
	## simulate the transform without bounce, based on movement local transform(no change yet)
	## it will be completed in movement_physics_process(delta):
	## rotation += follow_point_rot + should_rot_rotation, then convert to global transformation
	#last_no_bounce_transform = Transform2D(
			#relative_rot_drag + no_bounce_rot_drag, 
			#relative_stretch + no_bounce_stretch,
			#0.0,
			#relative_glob + no_bounce_shadow_dragger
		#)
	#
#func apply_recursive_look_at_chain(actor_node: SpriteObject) -> void:
	#if actor_node == null or not is_instance_valid(actor_node):
		#%Rotation.rotation = 0.0
		#return
	#if actor_node.target_ik != null and is_instance_valid(actor_node.target_ik):
		#var root = actor_node.get_node("%Origin")
		#var target = actor_node.target_ik.get_node("%Origin")
		#if root != null and target != null:
			#var target_pos: Vector2 = target.global_position - root.global_position
			#apply_look_at_ik(target_pos, actor_node.get_node("%Rotation"))
			#
			#var ik_chain =  actor_node.target_ik.target_ik
			#if ik_chain != null && is_instance_valid(ik_chain):
				#var target_pos_2: Vector2 = ik_chain.get_node("%Origin").global_position - root.global_position
				#apply_look_at_ik(target_pos_2, actor_node.get_node("%Rotation"))
				#
			#if actor_node.has_node("%Sprite2D"):
				#var sprite_root = actor_node.get_node("%Sprite2D")
				#for child in sprite_root.get_children():
					#if child is SpriteObject && is_instance_valid(child):
						#apply_recursive_look_at_chain(child)
		#else:
			#%Rotation.rotation = 0.0
	#else:
		#%Rotation.rotation = 0.0
#
#func apply_look_at_ik(target_pos: Vector2, rotation_node : Node2D) -> void:
	#var chain_softness: float = actor.get_value("chain_softness")
	#var rot_min: float = actor.get_value("chain_rot_min")
	#var rot_max: float = actor.get_value("chain_rot_max")
	#var bone_len: float = actor.get_value("bone_length")
	#var rigidity = 1.0/ max(chain_softness, 0.0001)
	#var lerp_amount = clamp(target_pos.length() / max(bone_len, 0.001) * rigidity, 0.0, 1.0)
	#var target_angle_global = target_pos.normalized().angle()
	#target_angle_global = wrapf(target_angle_global, -PI, PI)
	#target_angle_global = clamp(target_angle_global, rot_min, rot_max)
	#rotation_node.global_rotation = lerp_angle(rotation_node.global_rotation,target_angle_global,lerp_amount)
#
#func rest_mode_movements(delta : float) -> void:
	#if Global.static_view:
		#return
	## the root node calculate the original no_bounce_shadow_dragger
	## then following child node calculate based on its parent.
	#if c_parent_movement == null:
		#no_bounce_shadow_dragger.y -= Global.sprite_container.bounceChange
	#else:
		## restore the dragger based on the simulated last_no_bounce_transform
		## it remain the relative change of the movement without bounce effect
		#no_bounce_shadow_dragger = c_parent_movement.last_no_bounce_transform.affine_inverse() * no_bounce_shadow_dragger
		#no_bounce_shadow_dragger = c_parent_movement.last_movement_transform * no_bounce_shadow_dragger
		##no_bounce_shadow_dragger = restored_dragger
		## if the two position are similar, synchronize the data to avoid error accumulation
		#if no_bounce_shadow_dragger.is_equal_approx(shadow_dragger):
			#no_bounce_shadow_dragger = shadow_dragger
		#
	## if "physics" is disable, the movement will only be affected by its %Modifier1, instead of global space.
	## maintain the relative transform between shadow_dragger and %Modifier1,
	## then add on the inner movement(transform) of %Modifier1.
	## if the non-physics node has no parents(in other words, it's the outermost node),
	## it's will ignore bounce force and not jump anymore.
	#if !actor.get_value("physics"):
		#no_bounce = false
		#if c_parent_movement != null:
			#shadow_dragger = last_follow_global_transform.affine_inverse() * shadow_dragger
			#shadow_dragger = actor.modifier1.global_transform * shadow_dragger
			#shadow_dragger = actor.modifier1.transform.affine_inverse() * shadow_dragger
			#shadow_dragger = last_follow_transform * (shadow_dragger * actor.modifier1.transform)
		#else:
			#applied_pos.y -= Global.sprite_container.get_bounce_height()
	#
	#glob = shadow_dragger
	#no_bounce_glob = no_bounce_shadow_dragger
	#
	#drag(delta)
	#applied_pos += last_wobble_pos #Stay the last time(before rest) position
	#
	## after apply position change, calculate rotation and stretch
	#var no_bounce_length = (no_bounce_glob.x - no_bounce_shadow_dragger.x) + (no_bounce_glob.y - no_bounce_shadow_dragger.y)
	#var length = (glob.x - shadow_dragger.x) + (glob.y - shadow_dragger.y)
	#relative_rot_drag = rot_drag - no_bounce_rot_drag
	#relative_stretch = applied_scale - no_bounce_stretch
	#relative_glob = glob + last_wobble_pos - no_bounce_glob
	#
	#if no_bounce:
		#length = no_bounce_length
		#shadow_dragger = no_bounce_shadow_dragger
		#glob = no_bounce_glob
	#
	#update_last_rot_frquecy(delta)
	#rot_drag = emulate_drag_rotation(rot_drag, length, delta)
	#applied_scale = emulate_drag_stretch(modifier_node.scale, length, delta)
	#if no_bounce:
		#no_bounce_rot_drag = rot_drag
		#no_bounce_stretch = applied_scale
	#else:
		#no_bounce_rot_drag = emulate_drag_rotation(no_bounce_rot_drag, no_bounce_length, delta)
		#no_bounce_stretch = emulate_drag_stretch(no_bounce_stretch, no_bounce_length, delta)
	#
	## simulate the transform without bounce, based on movement local transform(no change yet)
	## it will be completed in movement_physics_process(delta):
	## rotation += follow_point_rot + should_rot_rotation, then convert to global transformation
	#last_no_bounce_transform = Transform2D(
			#relative_rot_drag + no_bounce_rot_drag, 
			#relative_stretch + no_bounce_stretch,
			#0.0,
			#relative_glob + no_bounce_shadow_dragger
		#)
#
#func add_parent_physics(length : float) -> float:
	#var leng = length
	#if !actor.get_value("physics"):
		#return leng
	#var p = actor.get_parent()
	#if (p is Sprite2D or p is WigglyAppendage2D or p is CustomMesh)  && is_instance_valid(p):
			#var c_parent = actor.get_parent().owner
			#if c_parent != null && is_instance_valid(c_parent):
				#leng += c_parent.get_node("%Movements").calc_length
	#return leng
	##var drag_speed = actor.get_value("dragSpeed")
	##var target = modifier_node.global_position + last_wobble_pos
	##if drag_speed > 0:
		##var t = 1.0 / drag_speed
		##dragger.global_position = dragger.global_position.lerp(target, t)
		##applied_pos = applied_pos.lerp(actor.to_local(dragger.global_position), 0.5)
	##else:
		##dragger.global_position = target
#func drag(_delta, no_bounce = false):
	#var drag_speed = actor.get_value("dragSpeed")
	#var target = modifier_node.global_position + last_wobble_pos
	#if drag_speed < 1.0:
		#drag_speed = 1.0
		#
	#var t = 1.0 / drag_speed
	#shadow_dragger = shadow_dragger.lerp(target, t)
	#no_bounce_shadow_dragger = no_bounce_shadow_dragger.lerp(target, t)
	#if no_bounce:
		#applied_pos = no_bounce_shadow_dragger
	#else:
		#applied_pos = shadow_dragger
	#
#
#func wobble(delta: float) -> void:
	#if false: #actor.get_value("pause_movement"):
		#if actor.is_all_default("xFrq"):
			#last_wobble_pos.x = 0
		#if actor.is_all_default("yFrq"):
			#last_wobble_pos.y = 0
	#else:
		#var offset = delta if Global.settings_dict.should_delta else 1.0
		#
		#if actor.get_value("xAmp") != 0.0:
			#paused_wobble.x += offset
			#last_wobble_pos.x = actor.get_value("xAmp") * sin(paused_wobble.x * actor.get_value("xFrq"))
		#else:
			#last_wobble_pos.x = 0
		#if actor.get_value("yAmp") != 0.0:
			#paused_wobble.y += offset
			#last_wobble_pos.y = actor.get_value("yAmp") * sin(paused_wobble.y * actor.get_value("yFrq"))
		#else:
			#last_wobble_pos.y = 0
			#
	#if actor.sprite_type == "Mesh" and mesh != null && is_instance_valid(mesh):
		#if !actor.get_value("move_with_wobble"):
			#return
	#
	#applied_pos += last_wobble_pos
#
#func update_last_rot_frquecy(delta: float):
	#if rot_frquecy == 0.0:
		#last_rot = 0.0
	#else:
		#if false: # actor.get_value("pause_movement"):
			#paused_rotation += delta if Global.settings_dict.should_delta else 1.
		#else:
			#last_rot = sin((Global.tick-paused_rotation) * rot_frquecy) * deg_to_rad(rdrag_str)
#
#func emulate_drag_rotation(last_rot_drag, length, delta: float) -> float:
	#if rdrag_str == 0.0 and last_rot_drag == 0.0:
		#return 0.0 #no need to rotation drag
		#
	#last_rot_drag = lerp_angle(last_rot_drag, last_rot, 0.15)
	#var yvel = 0.0
	#if rdrag_str != 0.0:
		#yvel = ((length * rdrag_str)* 0.5)
		#
	#return lerp_angle(last_rot_drag,deg_to_rad(yvel),0.08)
	#
#func emulate_drag_stretch(last_stretch, length, delta: float) -> Vector2:
	#if stretch_amount == 0.0 and last_stretch == Vector2.ONE:
		#return Vector2.ONE # no need to stretch
		#
	#var yvel = (length * stretch_amount * 0.01)
	#
	#return lerp(last_stretch, Vector2(1.0-yvel,1.0+yvel), 0.1)
#
#func rotational_drag(length, delta: float):
	#if rot_frquecy == 0.0:
		#last_rot = 0
		#if rdrag_str == 0.0 and rot_drag == 0.0:
			#return #no need to rotation drag
	#else:
		#if false: #actor.get_value("pause_movement"):
			#paused_rotation += delta if Global.settings_dict.should_delta else 1.
		#else:
			#last_rot = sin((Global.tick-paused_rotation) * rot_frquecy) * deg_to_rad(rdrag_str)
	#
	#applied_rotation = lerp_angle(applied_rotation, last_rot, 0.15)
	#yvel = ((length * actor.get_value("rdragStr")))*(actor.get_value("phys_eff")/200.0)
	#
	##Calculate Max angle
	#yvel = clamp(yvel,actor.get_value("rLimitMin"),actor.get_value("rLimitMax"))
	#applied_rotation = lerp_angle(applied_rotation,deg_to_rad(yvel),0.15)
#
#func stretch(length : float) -> void:
	#var syvel : float = (length * actor.get_value("stretchAmount") * 0.01)* (actor.get_value("phys_eff")/200.0)
	#var target : Vector2 = Vector2(1.0 - syvel, 1.0 + syvel)
	#modifier_node.scale = modifier_node.scale.lerp(target, 0.15)
#
#func follow_wiggle(_delta : float) -> void:
	#var parent = actor.get_parent()
	#if !parent or !(parent is WigglyAppendage2D):
		#follow_point_rot = 0.0
		#return
#
	#var tip_index : int = clamp(actor.get_value("tip_point"), 0, parent.points.size() - 1)
	#var raw_tip : Vector2 = parent.to_global(parent.points[tip_index])
	#var real_tip : Vector2 = parent.points[tip_index]
	#var local_tip : Vector2 = actor.to_local(raw_tip)
	#
	#if !has_prev:
		#prev_smoothed_pos = local_tip
		#has_prev = true
#
	#var d : float = prev_smoothed_pos.distance_to(local_tip)
	#var w : float = clamp(d * actor.get_value("follow_strength"), 0.0, 1.0)
	#prev_smoothed_pos = prev_smoothed_pos.lerp(local_tip, w)
#
	#applied_pos = prev_smoothed_pos
#
	#var prev_point : Vector2 = local_tip
	#if tip_index > 0:
		#prev_point = parent.points[tip_index - 1]
#
	#var dir : Vector2 = real_tip - prev_point
	#
	#var rest_angle : float = parent._rest_direction_angle
	#var target_ang : float = wrapf(dir.rotated(-rest_angle).angle(), -PI, PI)
#
	#if abs(target_ang - biased) < actor.get_value("rotation_threshold"):
		#return
#
	#biased = lerp(biased, target_ang, actor.get_value("follow_strength"))
	#follow_point_rot = clamp(biased, deg_to_rad(actor.get_value("follow_wa_mini")), deg_to_rad(actor.get_value("follow_wa_max")))
#
#func rainbow(delta : float) -> void:
	#if Global.mode != 0 and actor.get_value("hidden_item"):
		#sprite_node.self_modulate.a = 0.0
		#return
#
	#if actor.get_value("rainbow"):
		#var h_speed : float = actor.get_value("rainbow_speed") * delta
		#if actor.get_value("rainbow_self"):
			#sprite_node.self_modulate.s = 1.0
			#modifier_node.modulate.s = 0.0
			#sprite_node.self_modulate.h = wrap(sprite_node.self_modulate.h + h_speed, 0.0, 1.0)
		#else:
			#sprite_node.self_modulate.s = 0.0
			#modifier_node.modulate.s = 1.0
			#modifier_node.modulate.h = wrap(modifier_node.modulate.h + h_speed, 0.0, 1.0)
	#else:
		#if was_rainbow:
			#sprite_node.self_modulate = actor.get_value("tint")
			#modifier_node.modulate.s = 0
		#was_rainbow = false
#
#func auto_rotate():
	#should_rot_rotation += actor.get_value("should_rot_speed")
#
#func _on_sprite_object_visibility_changed() -> void:
	#rest = !actor.is_visible_in_tree() if !(actor == null) else false
	#
	#if rest and actor.tween != null:
		#actor.tween.kill()
		#if actor.was_active_before:
			#actor.modulate.a = 1.0
		#else:
			#actor.modulate.a = 0.0
