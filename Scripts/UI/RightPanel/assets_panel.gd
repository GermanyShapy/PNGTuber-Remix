extends VBoxContainer

## Cycle the rename field is currently bound to (-1 = none). Tracked so a pending
## edit is always stored on the cycle it was typed for, never on whichever cycle
## the dropdown happens to point at by the time the field loses focus.
var _cycle_name_index: int = -1
## Text this script last wrote into the field (not what the user typed). An
## untouched field must never count as a rename: storing the default label would
## freeze it into the save file and stop it following the locale.
var _cycle_name_pristine: String = ""


func _ready() -> void:
	Global.deselect.connect(nullfy)
	Global.reinfo.connect(enable)
	Global.load_model.connect(update_cycle_choice)
	Global.new_file.connect(clear_cycle_choice)
	# Default cycle labels are built imperatively, so they never follow the locale
	# on their own (see Util.cycle_default_label).
	LanguageManager.language_changed.connect(_on_language_changed)
	nullfy()

func nullfy():
	# Deselecting must also drop any pending bind await: otherwise the widget
	# keeps processing input while held_sprites is empty and the next stray
	# click indexes held_sprites[0] (out of bounds). Covers both the asset
	# bind and the disappear-key remap (they share _input).
	%IsAssetButton.cancel_remap()
	%IsAssetCheck.disabled = true
	%IsAssetButton.disabled = true
	%RemoveAssetButton.disabled = true
	%ShouldDisappearCheck.disabled = true
	%DontHideOnToggleCheck.disabled = true
	%HoldToShowCheck.disabled = true
	%MinDurationSpinBox.editable = false
	%CastTimeSpinBox.editable = false
	%InclusiveKeyCheck.disabled = true
	%IgnoreIfRestCheck.disabled = true
	%AutoShowCheck.disabled = true
	%AutoHideCheck.disabled = true
	%ShouldDisDelButton.disabled = true
	%ShouldDisRemapButton.disabled = true
	%ShouldDisAddButton.disabled = true
	%ShouldDisDelButton.disabled = true
	%ShouldDisRemapButton.disabled = true
	%ShouldDisListContainer.hide()
	%CycleChoiceSprite.disabled = true
	#%CycleMargin.hide()
	_on_cycle_choice_item_selected(%CycleChoice.selected)

func enable():
	if Global.held_sprites.size() == 1:
		%IsAssetCheck.disabled = false
		%IsAssetButton.disabled = false
		%RemoveAssetButton.disabled = false
		%ShouldDisappearCheck.disabled = false
		%DontHideOnToggleCheck.disabled = false
		%HoldToShowCheck.disabled = false
		%MinDurationSpinBox.editable = true
		%CastTimeSpinBox.editable = true
		%InclusiveKeyCheck.disabled = false
		%IgnoreIfRestCheck.disabled = false
		%AutoShowCheck.disabled = false
		%AutoHideCheck.disabled = false
		%ShouldDisAddButton.disabled = false
		%ShouldDisDelButton.disabled = false
		%ShouldDisRemapButton.disabled = false
		%IsAssetButton.text = "Null"
		%CycleChoiceSprite.disabled = false
		
		set_data()
	else:
		nullfy()

func set_data():
	%IsAssetButton.action = str(Global.held_sprites[0].sprite_id)
	%IsAssetCheck.button_pressed = Global.held_sprites[0].is_asset
	%DontHideOnToggleCheck.button_pressed = Global.held_sprites[0].show_only
	%ShouldDisList.clear()
	if InputMap.has_action(Global.held_sprites[0].disappear_keys):
		for i in InputMap.action_get_events(Global.held_sprites[0].disappear_keys):
			%ShouldDisList.add_item(InputDisplayName.text(i))
	# Rows now belong to another sprite; any previously selected index is stale.
	%IsAssetButton.reset_selection()
	%ShouldDisappearCheck.button_pressed = Global.held_sprites[0].should_disappear
	if %ShouldDisappearCheck.button_pressed:
		%ShouldDisListContainer.show()
	else:
		%ShouldDisListContainer.hide()
	%HoldToShowCheck.button_pressed = Global.held_sprites[0].hold_to_show
	%MinDurationSpinBox.value = Global.held_sprites[0].min_duration
	%CastTimeSpinBox.value = Global.held_sprites[0].cast_time
	%InclusiveKeyCheck.button_pressed = Global.held_sprites[0].inclusive_key_check
	%IgnoreIfRestCheck.button_pressed =  Global.held_sprites[0].ignore_if_rest
	%AutoShowCheck.button_pressed =  Global.held_sprites[0].auto_show
	%AutoHideCheck.button_pressed =  Global.held_sprites[0].auto_hide
	%IsAssetButton.update_key_text()
	%CycleChoiceSprite.select(_held_sprite_cycle())
	if !Global.held_sprites[0].sprite_data.is_cycle:
		%CycleChoiceSprite.disabled = true
	_on_cycle_choice_item_selected(%CycleChoice.selected)
	
func _on_cycle_choice_item_selected(index: int) -> void:
	# Flush a pending rename first: the field is about to be repointed at another
	# cycle, and the typed text belongs to the one that was selected.
	_commit_cycle_name()
	_sync_cycle_name_field(index - 1)
	if index <= 0:
		%CycleMargin.hide()
	else:
		%CycleMargin.show()
		%CycleKey.update_key_text()
		%CycleForward.update_key_text()
		%CycleBackward.update_key_text()
	# Always refresh the tree: leaving it filled with another cycle's rows is how
	# stale entries survive a rebuild (the margin hiding them is not a design).
	%CycleItemTree.update_tree_items()

func _on_add_cycle_pressed() -> void:
	# Commit before the rebuild repoints the rename field.
	_commit_cycle_name()
	Global.settings_dict.cycles.append({
		toggle = null,
		forward = null,
		backward = null,
		sprites = [],
		pos = 0,
		last_sprite = 0,
		active = false,
	})
	# Adding a cycle is almost always followed by configuring it, so select it.
	_rebuild_cycle_choice(Global.settings_dict.cycles.size() - 1)


func _on_delete_cycle_pressed() -> void:
	# "> 0" and not "!= 0": an empty dropdown reports -1, which would wrap the
	# index below zero.
	if %CycleChoice.get_selected_id() > 0:
		# Commit while the index still exists: the shift below invalidates it.
		_commit_cycle_name()
		var cycle_id = %CycleChoice.get_selected_id() - 1
		var cycle = Global.settings_dict.cycles[cycle_id]
		var behind_sprites: Array = []
		# clear relative sprite cycle bindings.
		for sprite in get_tree().get_nodes_in_group("Sprites"):
			if sprite.get_value("is_cycle") == false:
				continue
			if  sprite.sprite_id in cycle.sprites:
				sprite.sprite_data.cycle = 0
				sprite.sync_sprite_cycle_in_states()
			elif sprite.get_value("cycle") - 1 > cycle_id:
				behind_sprites.append(sprite)
		
		# the behind cycle numbers will be shifted forward to compensate.
		for sprite in behind_sprites:
			sprite.sprite_data.cycle = sprite.sprite_data.cycle - 1
			sprite.sync_sprite_cycle_in_states()
		# remove target cycle data
		Global.settings_dict.cycles.remove_at(cycle_id)
		# Keep the panel on a cycle that still exists (clamped by the rebuild).
		_rebuild_cycle_choice(cycle_id)

func _on_cycle_choice_sprite_item_selected(index: int) -> void:
	if %CycleChoiceSprite.get_selected_id() != 0:
		for i in Global.held_sprites:
			if i != null && is_instance_valid(i):
				if index == i.sprite_data.cycle:
					continue
				i.sprite_data.cycle = index
				i.sync_sprite_cycle_in_states()
				for l in Global.settings_dict.cycles:
					if l.sprites.has(i.sprite_id):
						l.sprites.remove_at(l.sprites.find(i.sprite_id))
				Global.settings_dict.cycles[%CycleChoiceSprite.get_selected_id() - 1].sprites.append(i.sprite_id)
	if %CycleChoiceSprite.get_selected_id() == 0:
		for i in Global.held_sprites:
			if i != null && is_instance_valid(i):
				i.sprite_data.cycle = index
				i.sync_sprite_cycle_in_states()
				for l in Global.settings_dict.cycles:
					if l.sprites.has(i.sprite_id):
						l.sprites.remove_at(l.sprites.find(i.sprite_id))
						i.get_node("%Sprite2D").show()
	
	%CycleItemTree.update_tree_items()
	
func update_cycle_choice():
	_rebuild_cycle_choice(-1)

## Rebuilds both dropdowns from `Global.settings_dict.cycles` and re-selects a row.
## `p_select_cycle` is a 0-based cycle index (-1 keeps the row that was selected
## before, as long as it still exists). Both dropdowns keep "None" at item 0, so a
## cycle index is always one below its item index. Item text is written by
## refresh_cycle_labels() only, and the panel body is refreshed by hand because
## select() emits no signal (see docs/40-设计 §4.4).
func _rebuild_cycle_choice(p_select_cycle: int) -> void:
	var cycles: Array = Global.settings_dict.cycles
	# Read before clear(): an empty OptionButton reports -1.
	var previous: int = %CycleChoice.selected - 1
	%CycleChoiceSprite.clear()
	%CycleChoice.clear()
	%CycleChoiceSprite.add_item(tr("TR_NONE"))
	%CycleChoice.add_item(tr("TR_NONE"))
	for i in cycles.size():
		%CycleChoiceSprite.add_item(Util.cycle_default_label(i))
		%CycleChoice.add_item(Util.cycle_default_label(i))
	refresh_cycle_labels()
	var target: int = p_select_cycle if p_select_cycle >= 0 else previous
	%CycleChoice.select(clampi(target + 1, 0, cycles.size()))
	# Display-only: select() emits nothing, and the sprite binding stays the truth.
	%CycleChoiceSprite.select(_held_sprite_cycle())
	_cycle_name_index = -1
	_cycle_name_pristine = ""
	_on_cycle_choice_item_selected(%CycleChoice.selected)

## The only writer of cycle labels in the two dropdowns. Everything that can change
## a name, the cycle count or the locale funnels through here -- updating one
## dropdown on its own is exactly how the two drift apart (docs/40-设计 §4.4.2).
func refresh_cycle_labels() -> void:
	var cycles: Array = Global.settings_dict.cycles
	for dropdown: OptionButton in [%CycleChoice, %CycleChoiceSprite]:
		for i in cycles.size():
			var item_index: int = i + 1
			# Guard against a caller refreshing before the items are rebuilt.
			if item_index >= dropdown.item_count:
				break
			dropdown.set_item_text(item_index, Util.cycle_label(cycles, i))
			# The tooltip keeps the numbered identity visible when a custom name
			# is truncated or duplicated.
			dropdown.set_item_tooltip(item_index, Util.cycle_default_label(i))

## Binds the rename field to `p_cycle_index` (-1 = no cycle selected). The text
## written here is remembered as pristine, see _cycle_name_pristine.
func _sync_cycle_name_field(p_cycle_index: int) -> void:
	var cycles: Array = Global.settings_dict.cycles
	_cycle_name_index = p_cycle_index
	if p_cycle_index < 0 or p_cycle_index >= cycles.size():
		_cycle_name_pristine = ""
		if not %CycleName.text.is_empty():
			%CycleName.text = ""
		%CycleName.editable = false
		return
	var label: String = Util.cycle_label(cycles, p_cycle_index)
	_cycle_name_pristine = label
	# Only assign when it differs: set_text() drops the caret and the undo history.
	if %CycleName.text != label:
		%CycleName.text = label
	%CycleName.editable = true

## Stores what the user typed in the rename field, if it differs from the text this
## script put there. Writes only, never rebuilds: rebuilding would kill the caret.
func _commit_cycle_name() -> void:
	var cycles: Array = Global.settings_dict.cycles
	var cycle_index: int = _cycle_name_index
	if cycle_index < 0 or cycle_index >= cycles.size():
		return
	var typed: String = %CycleName.text.strip_edges()
	if typed == _cycle_name_pristine:
		return
	_cycle_name_pristine = typed
	if not Util.set_cycle_name(cycles, cycle_index, typed):
		return
	refresh_cycle_labels()
	# Re-normalise the field only when what it shows is not what got stored (a
	# trimmed name, or a cleared one); otherwise the caret would jump to the end.
	var label: String = Util.cycle_label(cycles, cycle_index)
	if %CycleName.text != label:
		%CycleName.text = label
		_cycle_name_pristine = label

## Cycle the sprite dropdown should show: the held sprite's real binding (0 = none),
## so the display can never disagree with sprite_data.cycle.
func _held_sprite_cycle() -> int:
	if Global.held_sprites.size() != 1:
		return 0
	var sprite = Global.held_sprites[0]
	if sprite == null or not is_instance_valid(sprite):
		return 0
	var bound: int = sprite.sprite_data.get("cycle", 0)
	return clampi(bound, 0, Global.settings_dict.cycles.size())

func _on_cycle_name_text_submitted(_new_text: String) -> void:
	_commit_cycle_name()

func _on_cycle_name_focus_entered() -> void:
	# Global._process moves the selected sprite on arrow keys unless this flag is
	# set, and a LineEdit lets the up/down keys through to it.
	_cycle_name_index = %CycleChoice.get_selected_id() - 1
	Global.spinbox_held = true

func _on_cycle_name_focus_exited() -> void:
	Global.spinbox_held = false
	_commit_cycle_name()

# No mouse_exited commit on purpose: the pointer merely passing over the field
# would confirm a half-typed name (measured as odd in manual testing). Enter and
# losing focus are the two intended commit points.

func _on_language_changed(_locale_code: String) -> void:
	# Commit first: the labels about to be compared against are already localised.
	_commit_cycle_name()
	refresh_cycle_labels()
	_sync_cycle_name_field(_cycle_name_index)

func clear_cycle_choice():
	Global.settings_dict.cycles.clear()
	update_cycle_choice()

func _on_is_cycle_checkbox_changed(button_changed):
	if !button_changed:
		%CycleChoiceSprite.select(0)
		(%CycleChoiceSprite.item_selected as Signal).emit(%CycleChoiceSprite.selected)
		%CycleChoiceSprite.disabled = true
	else:
		%CycleChoiceSprite.disabled = false
		for i in Global.held_sprites:
			if i != null && is_instance_valid(i):
				i.sync_sprite_cycle_in_states()
