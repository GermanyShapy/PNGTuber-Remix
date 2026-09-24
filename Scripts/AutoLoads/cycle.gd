extends Node

func _process(_delta: float) -> void:
	update_cycles()

func update_cycles(settings_dict = Global.settings_dict):
	for cycle in settings_dict.cycles:
		if cycle.sprites.size() == 0:
			continue
		var toggle = cycle.get("toggle", null)
		var forward = cycle.get("forward", null)
		var backward = cycle.get("backward", null)

		if toggle != null:
			if GlobInput.is_input_just_pressed(toggle,true):
				toggle_cycle(cycle)

		if forward != null:
			if GlobInput.is_input_just_pressed(forward,true):
				toggle_forward(cycle)

		if backward != null:
			if GlobInput.is_input_just_pressed(backward,true):
				toggle_backward(cycle)

func toggle_cycle(cycle):
	if cycle.sprites.size() < 1 : return
	cycle.active = !cycle.active
	if cycle.active:
		var array = cycle.sprites.duplicate()
		if array.has(cycle.last_sprite) and array.size() > 1:
			array.remove_at(array.find(cycle.last_sprite))
		if array.size() > 0:
			# pick_random() returns a sprite_id, and toggle_to() takes a slot: the id
			# MUST go through find(), otherwise it gets wrapped as an index -- ids are
			# huge numbers, so every member collapses onto whichever slot the wrap
			# happens to hit (measured: a whole cycle stuck on slot 0). See
			# 50-报告/精灵与动画/循环切换与读档显隐-合流定位与修复方案-2026-09-24.md
			var rand_index : int = cycle.sprites.find(array.pick_random())
			if rand_index >= 0:
				toggle_to(cycle, rand_index)

	else:
		for sprite in get_tree().get_nodes_in_group("Sprites"):
			if sprite.sprite_id in cycle.sprites and sprite.get_value("is_cycle"):
				if sprite.was_active_before and !_hold_key_down(sprite):
					ReactionConfig.sprite_hide(sprite)

func toggle_forward(cycle):
	toggle_to(cycle, wrap(cycle.pos + 1, 0, cycle.sprites.size()))

func toggle_backward(cycle):
	toggle_to(cycle, wrap(cycle.pos - 1, 0, cycle.sprites.size()))

func toggle_to(cycle, pos):
	cycle.active = true
	cycle.pos = wrap(pos, 0, cycle.sprites.size())
	cycle.last_sprite = cycle.sprites[cycle.pos]
	for sprite in get_tree().get_nodes_in_group("Sprites"):
		#target
		if sprite.sprite_id == cycle.last_sprite and sprite.get_value("is_cycle"):
			if !sprite.was_active_before:
				ReactionConfig.sprite_show(sprite)
		#other sprites
		elif sprite.sprite_id in cycle.sprites and sprite.get_value("is_cycle"):
			# A member whose own key is still held owns the screen (reaction_config.gd
			# "#Cycle Check" suppresses the other members for exactly that reason).
			# Retracting one here would fight the hold branch and blink it out mid-hold.
			if sprite.was_active_before and !_hold_key_down(sprite):
				ReactionConfig.sprite_hide(sprite)

## True while a hold_to_show cycle member's own key is down. Only hold_to_show
## members carry that state, so sprites without a key never reach the query.
func _hold_key_down(sprite) -> bool:
	if not sprite.hold_to_show:
		return false
	return GlobInput.is_input_pressed(sprite.saved_event, sprite.inclusive_key_check)
