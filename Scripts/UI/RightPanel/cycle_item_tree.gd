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

	# "None" (0) maps to -1, and a stale selection after a cycle was removed maps
	# past the end -- both used to index out of range.
	var cycle_id = %CycleChoice.get_selected_id() - 1
	if cycle_id >= 0 and cycle_id < Global.settings_dict.cycles.size():
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
				add_cycle_tree_item(sprite_id_dict[id].sprite_name, id)
	else:
		pass
	
	update_minimum_size()
	
func add_cycle_tree_item(name, sprite_id = null):
	var item = create_item()
	item.set_text(0, str(get_root().get_child_count()))
	item.set_text(1, name)
	# The row remembers which member it stands for: ids without a sprite get no
	# row, so a row index is not an index into cycle.sprites.
	item.set_metadata(0, sprite_id)

# Null when the row holds no id: find() then reports -1 and the drop is ignored.
func _row_sprite_id(item) -> Variant:
	if item == null:
		return null
	return item.get_metadata(0)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is TreeItem and data.get_parent() == get_root():
		return true
	return false

func _get_drag_data(at_position: Vector2) -> Variant:
	drop_mode_flags = DROP_MODE_INBETWEEN
	var item = get_item_at_position(at_position)
	return item

# -100 means the drop is not over any row -- true both above the first row and
# below the last one. Those two ends insert at opposite ends of the list, so they
# are told apart by geometry: anything above the first row's top edge is the head.
func _dropped_above_first_row(y: float) -> bool:
	var root = get_root()
	if root == null:
		return true
	var first = root.get_first_child()
	if first == null:
		return true
	return y < get_item_area_rect(first).position.y

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var n = get_drop_section_at_position(at_position)
	var item = get_item_at_position(at_position)
	
	# selected_id 0 ("None") wraps to -1 and a removed cycle leaves the id past the
	# end; both used to index out of range before any of the work below.
	var cycle_id = %CycleChoice.get_selected_id() - 1
	if cycle_id < 0 or cycle_id >= Global.settings_dict.cycles.size():
		return
	var cycle = Global.settings_dict.cycles[cycle_id]
	# Resolved through the id each row carries, not get_index(): a member without
	# a sprite gets no row, so row order and list order can differ.
	var dragged_index : int = cycle.sprites.find(_row_sprite_id(data))
	if dragged_index < 0:
		return
	var target_index : int
	if n == -100:
		# Past either end of the list: above the first row inserts at the top,
		# below the last row appends.
		target_index = 0 if _dropped_above_first_row(at_position.y) else cycle.sprites.size()
	else:
		if item == null:
			return
		target_index = cycle.sprites.find(_row_sprite_id(item))
		if target_index < 0:
			return
		if n == 1:
			target_index += 1
	var temp_sprite_id = cycle.sprites[dragged_index]
	
	(cycle.sprites as Array).remove_at(dragged_index)
	if dragged_index < target_index:
		target_index -= 1
	target_index = clampi(target_index, 0, cycle.sprites.size())
	
	(cycle.sprites as Array).insert(target_index, temp_sprite_id)
	
	update_tree_items.call_deferred()
