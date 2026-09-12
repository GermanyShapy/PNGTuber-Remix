extends Node
class_name ReactionConfig

@export var actor : Node
@export var animation_handler : Node
var currently_speaking : bool = false
var blinking : bool = false
var tween : Tween
var min_duration_timer : float = 0.0
var cast_timer : float = 0.0
var is_rest :bool = false
var was_rest_before :bool = false
var fading_lock : bool = false

var is_action_just_pressed :bool = false
var is_action_pressed :bool = false
var is_disappear_key_just_pressed :bool = false

var is_trying_to_appear :bool = false
var is_trying_to_disappear :bool = false

# Per-frame sprite_id -> SpriteObject cache. Rebuilt at most once per rendered
# frame; sprite add/remove only becomes visible to the cycle logic next frame,
# which is the same granularity the old per-sprite group scan effectively had.
static var _sprite_ids: Dictionary = {}
static var _sprite_ids_frame: int = -1

static func sprite_with_id(p_tree: SceneTree, p_id: Variant) -> Node:
	if p_tree == null:
		return null
	var frame := Engine.get_process_frames()
	if frame != _sprite_ids_frame:
		_sprite_ids_frame = frame
		_sprite_ids.clear()
		for s in p_tree.get_nodes_in_group("Sprites"):
			_sprite_ids[s.sprite_id] = s
	return _sprite_ids.get(p_id)

func _ready() -> void:
	Global.speaking.connect(speaking)
	Global.not_speaking.connect(not_speaking)
	Global.blink.connect(blink)
	Global.mode_changed.connect(update_to_mode_change)
	Global.blink.connect(editor_blink)
	Global.animation_state.connect(reset_animations)
	await  get_tree().physics_frame
	not_speaking()

func _process(delta: float) -> void:
	var gazing_l = Vector2(0, 0)
	var gazing_r = Vector2(0, 0)
	if Tracker.working && actor.sprite_data.follow_eye != 0:
		gazing_l = Tracker.smooth_gaze_left
		gazing_r = Tracker.smooth_gaze_right
		%Modifier1.modulate.a = 1

		if actor.sprite_data.should_blink:
			if actor.sprite_data.style_eye != 0:
				match actor.sprite_data.follow_eye:
					0:
						%Modifier.scale.y = 1
					1:
						%Modifier.scale.y = lerp(%Modifier.scale.y, Tracker.track_eye_left, 0.08)
					2:
						%Modifier.scale.y = lerp(%Modifier.scale.y, Tracker.track_eye_right, 0.08)
					3:
						%Modifier.scale.y = lerp(%Modifier.scale.y, (Tracker.track_eye_right + Tracker.track_eye_left)*0.5, 0.08)
			else:
				%Modifier.scale.y = 1
			
			var is_blinked = Tracker.is_blink
			if actor.sprite_data.follow_eye == 1:
				is_blinked = Tracker.is_blink_left
			elif actor.sprite_data.follow_eye == 2:
				is_blinked = Tracker.is_blink_right
			
			if is_blinked:
				if !actor.sprite_data.open_eyes:
					%Modifier1.show()
				else:
					%Modifier1.hide()
			elif !is_blinked:
				if !actor.sprite_data.open_eyes:
					%Modifier1.hide()
				else:
					%Modifier1.show()
	
	match actor.sprite_data.gaze_eye:
		1:
			%Sprite2D.position = %Sprite2D.position.lerp(actor.get_value("offset") + gazing_l, 0.25)
		2:
			%Sprite2D.position = %Sprite2D.position.lerp(actor.get_value("offset") + gazing_r, 0.25)

	if Tracker.working && actor.sprite_data.follow_mouth != 0:
		%Modifier.modulate.a = 1
		if actor.sprite_data.should_talk:
			if Tracker.is_mouth_open:
				if actor.sprite_data.open_mouth:
					%Modifier.show()
				else:
					%Modifier.hide()
			elif !Tracker.is_mouth_open:
				if actor.sprite_data.open_mouth:
					%Modifier.hide()
				else:
					%Modifier.show()
	
	if Global.settings_dict.checkinput != true:
		return
	
	var cycle = null
	var cycle_sprite_pos = 0
	
	is_trying_to_appear = false
	is_trying_to_disappear = false
	
	# Rest Check
	is_rest = actor.movements.rest
	
	if !is_rest and was_rest_before:	# Awaken
		# auto_show makes the sprite appear without its key (1.4.x semantics).
		# For a hold_to_show sprite the hold branch then raises "no key ->
		# disappear" every frame; the min_duration timer suppresses it until
		# min_duration elapses, so the sprite plays out and vanishes. With
		# min_duration = 0 the sprite is retracted next frame, but that 1-frame
		# pulse is a functional trigger: its retraction path (toggle_to back to
		# cycle pos 0) is what shows the next sprite in the model's chain, so
		# it must NOT be suppressed (suppressing it broke ball/electric-ball
		# chains -- the whole chain silently stalled).
		if actor.auto_show:
			is_trying_to_appear = true
			cast_timer = 0.0
	
	was_rest_before = is_rest
	
	if is_rest and actor.ignore_if_rest:
		if actor.hold_to_show and actor.was_active_before: # one last disapperance
			is_trying_to_disappear = true
			min_duration_timer = 0.0
		else:
			return

	# Conditions
	is_action_just_pressed = GlobInput.is_input_just_pressed(actor.saved_event, actor.inclusive_key_check)
	is_action_pressed = GlobInput.is_input_pressed(actor.saved_event, actor.inclusive_key_check)
	is_disappear_key_just_pressed = GlobInput.is_action_input_just_pressed(actor.disappear_keys, actor.inclusive_key_check)
	
	if is_action_just_pressed:
		if actor.show_only:
			is_trying_to_appear = true
		else:
			if !actor.was_active_before:
				is_trying_to_appear = true
			else:
				is_trying_to_disappear = true
	
	if actor.cast_time > 0.0 and cast_timer <= 0.0: # For "just_pressed" to show during cast time
		if !actor.hold_to_show and !actor.was_active_before:
			is_trying_to_appear = true
	
	if is_disappear_key_just_pressed:
		is_trying_to_disappear = true
	
	if actor.hold_to_show:
		if !actor.was_active_before and is_action_pressed:
			is_trying_to_appear = true
		elif !is_action_pressed and (actor.was_active_before or (is_trying_to_appear and actor.min_duration <= 0.0)):
			# Raised every frame while visible with no key down; the min_duration
			# timer below suppresses it until min_duration elapses, which is what
			# makes the sprite auto-vanish after its minimum duration.
			# A min_duration==0 sprite that auto-shows on awaken is retracted in
			# the SAME frame (is_trying_to_appear is still set at this point): its
			# cycle toggle-to and the retraction toggle-back then both complete
			# before the frame renders, so the pulse no longer flashes on screen
			# while still advancing the model's sprite chain.
			is_trying_to_disappear = true
		
	#Timer Tick
	if min_duration_timer > 0.0:
		min_duration_timer -= delta
		is_trying_to_disappear = false
	
	if cast_timer > 0.0:
		cast_timer -= delta
		is_trying_to_appear = false
		
	if 0.0 == actor.cast_time:
		cast_timer = 0.0
	elif !is_action_pressed:
		cast_timer = actor.cast_time

	#Cycle Check
	if actor.sprite_data.is_cycle and actor.sprite_data.cycle > 0:
		cycle = Global.settings_dict.cycles[actor.sprite_data.cycle - 1]
		cycle_sprite_pos = cycle.sprites.find(actor.sprite_id)
		
		if !actor.hold_to_show:
			# This used to walk every sprite in the tree for every cycle sprite
			# (O(cycle_sprites * sprites) per frame, ~1.4 ms on a 336-sprite
			# model). Resolve through a per-frame id map instead.
			var holder: Node = sprite_with_id(get_tree(), cycle.last_sprite)
			if holder != null and holder.sprite_data.is_cycle and holder.hold_to_show and holder.was_active_before:
				is_trying_to_appear = false
	
	#Finally, Show or Hide
	if is_trying_to_appear:
		if cycle != null and !actor.was_active_before:
			if cycle_sprite_pos == 0 and cycle_sprite_pos == cycle.pos:
				sprite_show(actor)
			else:
				GlobInput.cycle.toggle_to(cycle, cycle_sprite_pos)
		
		if !actor.was_active_before:
			sprite_show(actor)
			
	if is_trying_to_disappear:
		if cycle != null and actor.was_active_before:
			if cycle_sprite_pos != 0 and cycle_sprite_pos == cycle.pos:
				GlobInput.cycle.toggle_to(cycle, 0)
		
		if actor.was_active_before:
			sprite_hide(actor)
			
		if !actor.is_asset && !actor.sprite_object.visible:
			actor.sprite_object.visible = true
			actor.was_active_before = actor.sprite_object.visible

func update_to_mode_change(mode : int):
	match mode:
		0:
			%Modifier1.show()
			if actor.get_value("should_blink"):
				if actor.get_value("open_eyes"):
					if !blinking:
						%Modifier1.modulate.a = 1
					elif blinking:
						%Modifier1.modulate.a = 0.2

				elif !actor.get_value("open_eyes"):
					if blinking:
						%Modifier1.modulate.a = 1
					elif !blinking:
						%Modifier1.modulate.a = 0.2

			
			%Modifier.show()
			#%Modifier.modulate.a = 1
			if actor.get_value("should_talk"):
				if actor.get_value("open_mouth"):
					if currently_speaking:
						if actor.get_value("fade_asset"):
							actor.fade_asset(false, %Modifier, %Modifier)
						else:
							actor.fade_reset(%Modifier)
							%Modifier.modulate.a = 1
					else:
						if actor.get_value("fade_asset"):
							actor.fade_asset(true, %Modifier, %Modifier)
						else:
							actor.fade_reset(%Modifier)
							%Modifier.modulate.a = 0.2

				elif !actor.get_value("open_mouth"):
					if !currently_speaking:
						if actor.get_value("fade_asset"):
							actor.fade_asset(false, %Modifier, %Modifier)
						else:
							actor.fade_reset(%Modifier)
							%Modifier.modulate.a = 1
					else:
						if actor.get_value("fade_asset"):
							actor.fade_asset(true, %Modifier, %Modifier)
						else:
							actor.fade_reset(%Modifier)
							%Modifier.modulate.a = 0.2
			else:
				%Modifier.show()
				actor.fade_reset(%Modifier)
				#%Modifier.modulate.a = 1
		1:
			%Modifier1.modulate.a = 1
			if actor.get_value("should_blink"):
				if actor.get_value("open_eyes"):
					if !blinking:
						%Modifier1.show()
					elif blinking:
						%Modifier1.hide()

				elif !actor.get_value("open_eyes"):
					if blinking:
						%Modifier1.show()
					elif !blinking:
						%Modifier1.hide()

			#%Modifier.modulate.a = 1
			if actor.get_value("should_talk"):
				if actor.get_value("open_mouth"):
					if currently_speaking:
						if actor.get_value("fade_asset"):
							actor.fade_asset(false, %Modifier, %Modifier)
						else:
							actor.fade_reset(%Modifier)
							%Modifier.show()
					else:
						if actor.get_value("fade_asset"):
							actor.fade_asset(true, %Modifier, %Modifier)
						else:
							actor.fade_reset(%Modifier)
							%Modifier.hide()

				elif !actor.get_value("open_mouth"):
					if !currently_speaking:
						if actor.get_value("fade_asset"):
							actor.fade_asset(false, %Modifier, %Modifier)
						else:
							actor.fade_reset(%Modifier)
							%Modifier.show()
					else:
						if actor.get_value("fade_asset"):
							actor.fade_asset(true, %Modifier, %Modifier)
						else:
							actor.fade_reset(%Modifier)
							%Modifier.hide()
			else:
				%Modifier.show()
				actor.fade_reset(%Modifier)
				#%Modifier.modulate.a = 1

func editor_blink():
	if Tracker.working && actor.sprite_data.follow_eye != 0: return
	if Global.mode == 0:
		if actor.get_value("should_blink"):
			%Modifier1.show()
			if not actor.get_value("open_eyes"):
				%Modifier1.modulate.a = 1
				reset_animations()
			else:
				%Modifier1.modulate.a = 0.2
		else:
			%Modifier1.show()
			%Modifier1.modulate.a = 1
		
		blinking = true
		%Blink.wait_time = 0.2 * Global.settings_dict.blink_speed
		%Blink.start()
		await %Blink.timeout
		if actor.get_value("should_blink"):
			if not actor.get_value("open_eyes"):
				%Modifier1.modulate.a = 0.2
			else:
				%Modifier1.modulate.a = 1
				reset_animations()
		else:
			%Modifier1.modulate.a = 1
		blinking = false

func blink():
	if Tracker.working && actor.sprite_data.follow_eye != 0: return
	if Global.mode != 0:
		if actor.get_value("should_blink"):
			%Modifier1.modulate.a = 1
			if not actor.get_value("open_eyes"):
				%Modifier1.show()
				reset_animations()
			else:
				%Modifier1.hide()
		else:
			%Modifier1.modulate.a = 1
			%Modifier1.show()
		
		blinking = true
		%Blink.wait_time = 0.2 * Global.settings_dict.blink_speed
		%Blink.start()
		await %Blink.timeout
		if actor.get_value("should_blink"):
			if not actor.get_value("open_eyes"):
				%Modifier1.hide()
			else:
				%Modifier1.show()
				reset_animations()
		else:
			%Modifier1.show()
		blinking = false

func speaking():
	if Tracker.working && actor.sprite_data.follow_mouth != 0: return
	if Global.mode != 0:
		if actor.get_value("should_talk"):
			if actor.get_value("open_mouth"):
				reset_animations()
				if actor.get_value("fade_asset"):
					actor.fade_asset(false, %Modifier, %Modifier)
				else:
					actor.fade_reset(%Modifier)
					%Modifier.show()
			else:
				if actor.get_value("fade_asset"):
					actor.fade_asset(true, %Modifier, %Modifier)
				else:
					actor.fade_reset(%Modifier)
					%Modifier.hide()
		else:
			%Modifier.show()
			actor.fade_reset(%Modifier)
			
	elif Global.mode == 0:
		%Modifier.show()
		if actor.get_value("should_talk"):
			if actor.get_value("open_mouth"):
				if actor.get_value("fade_asset"):
					actor.fade_asset(false, %Modifier, %Modifier)
				else:
					actor.fade_reset(%Modifier)
					%Modifier.modulate.a = 1
					reset_animations()
			else:
				if actor.get_value("fade_asset"):
					actor.fade_asset(true, %Modifier, %Modifier)
				else:
					actor.fade_reset(%Modifier)
					%Modifier.modulate.a = 0.2
		else:
			actor.fade_reset(%Modifier)
	currently_speaking = true

func reset_animations(_place_holder : int = 0, force : bool = false):
	if actor.get_value("never_reset"):
		return

	# force=true is used by sprite_show: a shown one_shot sheet must always
	# restart from frame 0, even when the previous run was cut short by hide
	# (frame < last), otherwise the sprite "resumes" near the end on the next
	# press. Signal-driven calls (blink/speak) keep the frame==last guard so a
	# finished one_shot is not yanked back to frame 0 while it merely sits there.
	if force or (actor.get_value("one_shot") and actor.sprite_object.frame == (actor.get_value("hframes")*actor.get_value("vframes") -1)):
		reset_anim()

	if actor.get_value("should_reset"):
		reset_anim()

func reset_anim():
	if actor.referenced_data == null or !is_instance_valid(actor.referenced_data):
		return
	if actor.referenced_data.is_apng or actor.referenced_data.img_animated:
		animation_handler.index = 0
		animation_handler.proper_apng_one_shot()
	animation_handler.played_once = false
	if actor.sprite_type == "Sprite2D":
		actor.animation_reset()

func not_speaking():
	if Tracker.working && actor.sprite_data.follow_mouth != 0: return
	if Global.mode != 0:
		#%Modifier.modulate.a = 1
		if actor.get_value("should_talk"):
			if actor.get_value("open_mouth"):
				if actor.get_value("fade_asset"):
					actor.fade_asset(true, %Modifier, %Modifier)
				else:
					actor.fade_reset(%Modifier)
					%Modifier.hide()
			else:
				reset_animations()
				if actor.get_value("fade_asset"):
					actor.fade_asset(false, %Modifier, %Modifier)
				else:
					actor.fade_reset(%Modifier)
					%Modifier.show()
		else:
			%Modifier.show()
			actor.fade_reset(%Modifier)
			
	elif Global.mode == 0:
		%Modifier.show()
		#%Modifier.modulate.a = 1
		if actor.get_value("should_talk"):
			if actor.get_value("open_mouth"):
				if actor.get_value("fade_asset"):
					actor.fade_asset(true, %Modifier, %Modifier)
				else:
					actor.fade_reset(%Modifier)
					%Modifier.modulate.a = 0.2
			else:
				reset_animations()
				if actor.get_value("fade_asset"):
					actor.fade_asset(false, %Modifier, %Modifier)
				else:
					actor.fade_reset(%Modifier)
					%Modifier.modulate.a = 1
		else:
			actor.fade_reset(%Modifier)
			#%Modifier.modulate.a = 1
			
	currently_speaking = false

static func sprite_show(aim_actor : Node):
	var aim_sprite2d = aim_actor.sprite_object
	
	if aim_actor.min_duration > 0.00001:
		aim_actor.get_node("ReactionConfig").min_duration_timer = aim_actor.min_duration # start the duration protect
	if aim_actor.get_value("fade_asset"):
		aim_actor.fade_asset(aim_actor.was_active_before, aim_actor, aim_sprite2d)
		aim_actor.was_active_before = true
		#var new_visibility = await actor.fade_asset(actor.was_active_before, actor, %Sprite2D)
		#%Sprite2D.visible = new_visibility
		#actor.was_active_before = new_visibility
	else:
		aim_actor.fade_reset()
		aim_sprite2d.visible = true
		aim_actor.was_active_before = aim_sprite2d.visible
	aim_actor.get_node("ReactionConfig").reset_animations(0, true)
		
static func sprite_hide(aim_actor : Node):
	var aim_sprite2d = aim_actor.sprite_object
	
	if aim_actor.get_value("fade_asset"):
		aim_actor.fade_asset(aim_actor.was_active_before, aim_actor, aim_sprite2d)
		aim_actor.was_active_before = false
		#var new_visibility = await actor.fade_asset(actor.was_active_before, actor, %Sprite2D)
		#%Sprite2D.visible = new_visibility
		#actor.was_active_before = new_visibility
	else:
		aim_actor.fade_reset()
		aim_sprite2d.visible = false
		aim_actor.was_active_before = aim_sprite2d.visible
	
