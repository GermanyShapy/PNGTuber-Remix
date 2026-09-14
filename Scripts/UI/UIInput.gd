extends Node

var should_change: bool = false

# Sprite list the chain dropdown was last built from; see _sync_chain_target().
var _chain_names := PackedStringArray()


func _ready() -> void:
	await get_tree().current_scene.ready
	held_sprite_is_null()

	Global.reinfo.connect(reinfo)
	Global.deselect.connect(held_sprite_is_null)
	Global.show_model_warning.connect(show_model_warning)
	Global.dev_mode.connect(check_dev_mode)

	%InfluRad.value = MeshEditor.influence_radius
	%InfluStrength.value = MeshEditor.influence_strength
	%InfluRad.get_line_edit().add_theme_font_size_override("placeholder", 12)
	%InfluStrength.get_line_edit().add_theme_font_size_override("placeholder", 12)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		if _has_valid_held_sprite():
			held_sprite_is_true()
		else:
			held_sprite_is_null()


func check_dev_mode(_check: bool = false) -> void:
	pass
	# %Inspector.set_tab_hidden(7, !_check)


func show_model_warning(_warn: bool) -> void:
	%ModelSizeWarning.visible = _warn


#region Update Slider info
func _has_valid_held_sprite() -> bool:
	for i in Global.held_sprites:
		if i != null and is_instance_valid(i):
			return true
	return false


func held_sprite_is_null() -> void:
	if !Global.is_editor:
		return
	%SpriteID.text = "%s %d" % [tr("TR_SPRITE_ID_LABEL"), 0]
	%ParentID.text = "%s %d" % [tr("TR_PARENT_ID_LABEL"), 0]
	%Name.editable = false
	%Name.text = ""
	%AdvancedLipSync.disabled = true


func held_sprite_is_true() -> void:
	if !Global.is_editor:
		return
	Global.top_ui.get_node("%DeselectButton").show()
	%Name.editable = true
	%AdvancedLipSync.disabled = true

	for i in Global.held_sprites:
		if i != null and is_instance_valid(i):
			if i.sprite_type == "Sprite2D":
				%AdvancedLipSync.disabled = false

			%SpriteID.text = "%s %d" % [tr("TR_SPRITE_ID_LABEL"), int(i.sprite_id)]
			%ParentID.text = "%s %d" % [tr("TR_PARENT_ID_LABEL"), int(i.parent_id)]


func reinfo() -> void:
	held_sprite_is_null()
	should_change = false

	for i in Global.held_sprites:
		if i != null and is_instance_valid(i):
			%Name.text = i.sprite_name
			if i.sprite_type == "Sprite2D":
				%AdvancedLipSync.button_pressed = i.get_value("advanced_lipsync")

	await get_tree().create_timer(0.01).timeout
	held_sprite_is_true()

	_sync_chain_target()
	should_change = true


# Rebuilding this dropdown costs ~190 us per sprite -- OptionButton.add_item()
# re-measures the popup's minimum size over all existing items, so the rebuild is
# O(n^2) and measured 63 ms on a 336-sprite model. reinfo fires on every state
# switch, undo/redo, layer edit and file import, so only rebuild when the sprite
# list actually changed; the selected entry is re-synced on every call.
func _sync_chain_target() -> void:
	var group : Array = get_tree().get_nodes_in_group("Sprites")
	var names := PackedStringArray()
	for i in group:
		names.append(i.sprite_name)

	if names != _chain_names:
		_chain_names = names
		%ChainTarget.clear()
		%ChainTarget.add_item("None")
		for idx in group.size():
			%ChainTarget.add_item(names[idx])
			%ChainTarget.set_item_metadata(idx + 1, group[idx])

	%ChainTarget.select(_chain_target_index(group))


# Dropdown index of the first held sprite's IK target, or 0 for "None".
func _chain_target_index(p_group: Array) -> int:
	if Global.held_sprites.is_empty():
		return 0
	var sp = Global.held_sprites[0]
	if sp == null or not is_instance_valid(sp):
		return 0
	if sp.target_ik == null or not is_instance_valid(sp.target_ik):
		return 0
	for idx in p_group.size():
		if p_group[idx] == sp.target_ik:
			return idx + 1
	return 0


func _on_name_text_submitted(new_text) -> void:
	if Global.held_sprites.size() <= 1:
		Global.held_sprites[0].treeitem.set_text(0, new_text)
		Global.held_sprites[0].sprite_name = new_text
		Global.held_sprites[0].save_state(Global.current_state)
	else:
		for i in Global.held_sprites.size():
			Global.held_sprites[i].treeitem.set_text(0, new_text + str(i + 1))
			Global.held_sprites[i].sprite_name = new_text + str(i + 1)
			Global.held_sprites[i].save_state(Global.current_state)

	Global.spinbox_held = false
	%Name.release_focus()
#endregion


#region Advanced-LipSync
func _on_advanced_lip_sync_toggled(toggled_on) -> void:
	if should_change:
		for i in Global.held_sprites:
			if i != null and is_instance_valid(i):
				if i.sprite_type == "Sprite2D":
					i.sprite_data.advanced_lipsync = toggled_on
					i.sprite_data.animation_speed = 1

					if toggled_on:
						i.get_node("%Sprite2D").hframes = 6
					else:
						i.get_node("%Sprite2D").hframes = 1

					i.advanced_lipsyc()
					i.get_node("%Sprite2D/Grab").anchors_preset = Control.LayoutPreset.PRESET_FULL_RECT
					i.save_state(Global.current_state)
					Global.reinfo.emit()


func _on_advanced_lip_sync_mouse_entered() -> void:
	%AdvancedLipSyncLabel.show()


func _on_advanced_lip_sync_mouse_exited() -> void:
	%AdvancedLipSyncLabel.hide()
#endregion


func _on_name_focus_entered() -> void:
	Global.spinbox_held = true


func _on_name_focus_exited() -> void:
	Global.spinbox_held = false


func _on_chain_target_item_selected(index: int) -> void:
	var selected = %ChainTarget.get_item_metadata(index)

	if selected != null and is_instance_valid(selected):
		for i in Global.held_sprites:
			i.target_ik = selected
	else:
		for i in Global.held_sprites:
			i.target_ik = null


func _on_influ_rad_value_changed(value: float) -> void:
	MeshEditor.influence_radius = value


func _on_influ_strength_value_changed(value: float) -> void:
	MeshEditor.influence_strength = value
