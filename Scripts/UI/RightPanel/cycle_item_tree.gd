extends Tree

func _ready():
	pass
	
func update_tree_items():
	clear()
	set_column_title(0, "No.")
	set_column_expand(0, true)
	set_column_expand_ratio(0, 0)
	set_column_title(1, "TR_SPRITES")
	set_column_expand(0, true)
	var root = create_item()

	if %CycleChoice.get_selected_id() > 0:
		var cycle_id = %CycleChoice.get_selected_id() - 1
		var cycle = Global.settings_dict.cycles[cycle_id]
		
		var sprite_id_dict: Dictionary = {}
		for id in cycle.sprites:
			sprite_id_dict[id] = null
			
		for sprite in get_tree().get_nodes_in_group("Sprites"):
			if sprite.get_value("is_cycle") == false:
				continue
			if  sprite.sprite_id in cycle.sprites:
				sprite_id_dict[sprite.sprite_id] = sprite
		
		for id in sprite_id_dict:
			if sprite_id_dict[id] != null:
				add_cycle_tree_item(sprite_id_dict[id].sprite_name)
	else:
		pass
	
	update_minimum_size()
	
func add_cycle_tree_item(name):
	var item = create_item()
	item.set_text(0, str(get_root().get_child_count()))
	item.set_text(1, name)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is TreeItem and data.get_parent() == get_root():
		return true
	return false

func _get_drag_data(at_position: Vector2) -> Variant:
	drop_mode_flags = DROP_MODE_INBETWEEN
	var item = get_item_at_position(at_position - self.position)
	return item

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var n = get_drop_section_at_position(at_position - self.position)
	var item = get_item_at_position(at_position - self.position)
	
	var cycle_id = %CycleChoice.get_selected_id() - 1
	var cycle = Global.settings_dict.cycles[cycle_id]
	var dragged_index = (data as TreeItem).get_index()
	var target_index = (item as TreeItem).get_index() if n != -100 else 0
	var temp_sprite_id = cycle.sprites[dragged_index]
	
	if n == 1:
		target_index += 1
	
	(cycle.sprites as Array).remove_at(dragged_index)
	if dragged_index < target_index:
		target_index -= 1
	
	(cycle.sprites as Array).insert(target_index, temp_sprite_id)
	
	update_tree_items.call_deferred()
