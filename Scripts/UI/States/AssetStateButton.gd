extends Button

@export var action: String

enum Remap {
	Asset,
	Keys,
}

var current_remap: Remap
var selected_item = null
# Row index of the selected disappear key; -1 means "no selection". Kept as an
# int on purpose: it is used in comparisons and as an ItemList index.
var id: int = -1
# Collects the inputs pressed while awaiting; a binding commits once every
# member is released (see BindingSession).
var _session := BindingSession.new()

# The stored index can outlive its row (list rebuilt for another sprite, row
# deleted). Callers must go through this instead of reading `id` directly.
func _selected_id() -> int:
	if id >= 0 and id < %ShouldDisList.item_count:
		return id
	return -1

func _update_action_buttons_enabled() -> void:
	var has_row := _selected_id() >= 0
	%ShouldDisRemapButton.disabled = not has_row
	%ShouldDisDelButton.disabled = not has_row

# Called when the list is rebuilt (selection changed to another sprite): the old
# index refers to rows that no longer exist.
func reset_selection() -> void:
	id = -1
	_update_action_buttons_enabled()


func _init():
	toggle_mode = true
	theme_type_variation = "RemapButton"


func _ready():
	set_process_input(false)
	# Vendor-label style is a setting: re-derive our own text when it changes.
	Global.binding_labels_changed.connect(update_key_text)
	update_key_text()


func _toggled(_button_pressed):
	current_remap = Remap.Asset
	if %IsAssetCheck.button_pressed:
		set_process_input(_button_pressed)
		if _button_pressed:
			_session.clear()
			# While awaiting we must not hold key focus: a focused Button eats
			# ui_accept (Enter/Space) and the Tab/arrow ui_* actions before they
			# reach our _input() handler.
			text = tr("TR_AWAITING_INPUT")
			release_focus()
			MouseCaptureArea.show_for(self)
		else:
			# Never re-grab focus here: a focused toggle Button swallows the next
			# ui_accept, silently re-arming this widget and stealing later keys.
			update_key_text()
			release_focus()
			MouseCaptureArea.hide_for(self)
	else:
		# The bind button is inert while "Is Asset" is off: make sure no await
		# state (and no capture pad) is left behind.
		set_process_input(false)
		MouseCaptureArea.hide_for(self)


func cancel_remap() -> void:
	# Leaves the awaiting state from any entry point (deselect, unchecking
	# "Is Asset", a click outside the capture pad) without depending on the
	# toggled() gate, which is skipped while "Is Asset" is off.
	_session.clear()
	set_process_input(false)
	MouseCaptureArea.hide_for(self)
	MouseCaptureArea.hide_for(%ShouldDisRemapButton)
	if button_pressed:
		button_pressed = false
	else:
		update_key_text()
	if %ShouldDisRemapButton.button_pressed:
		%ShouldDisRemapButton.button_pressed = false


func _input(event):
	if Global.held_sprites.is_empty():
		# The selection disappeared while we were awaiting (deselect). Never
		# index [0]; just leave the awaiting state cleanly.
		cancel_remap()
		return
	if not is_visible_in_tree():
		# The right panel was hidden mid-await: stop swallowing input.
		cancel_remap()
		return
	if event is InputEventMouseMotion:
		return
	# Sticks report no release edge that can be stored, so coming back into the
	# deadzone only marks the member released (BindingSession.release_axis).
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		if GlobInput.is_joy_pushed(event):
			_session.press(GlobInput.normalize_joy_event(event))
			_update_preview()
		else:
			_session.release_axis(event.axis)
			_try_commit()
		return
	var awaiting_button: Control = self if current_remap == Remap.Asset else %ShouldDisRemapButton
	# `_input` runs before GUI picking, so a press that lands on the visible
	# capture pad can be swallowed here before the control the pad covers (e.g.
	# the "inclusive key check" checkbox) ever sees it. A mouse press anywhere
	# else means "cancel the await", never "bind this mouse button".
	if event is InputEventMouseButton:
		var step := MouseCaptureArea.step_mouse(awaiting_button, event)
		if step == MouseCaptureArea.MouseStep.PRESS_OUTSIDE:
			cancel_remap()
			return
		if step == MouseCaptureArea.MouseStep.PRESS_ON_PAD:
			_session.press(event)
			_update_preview()
			return
		if step != MouseCaptureArea.MouseStep.RELEASE_ON_PAD:
			# Press on the pad (already consumed) or an orphan release: keep
			if not event.pressed:
				# Released off the pad: drop the member instead of leaving it
				# "held" in the session forever.
				_session.release(event)
			# waiting / ignore, never bind.
			return
		get_viewport().set_input_as_handled()
		_session.press(event)
		_session.release(event)
		_try_commit()
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed:
			# Auto-repeat is not a new press: it must not reorder the
			# chord members or become the primary.
			if event.echo:
				return
			# A modifier key never joins a chord (D4): its bits travel inside the
			# events of the keys pressed while it is held, so it is only tracked
			# for the preview. It must not cancel them either -- with a modifier
			# down, Godot stamps its bit onto every key event, so cancelling would
			# swallow the whole combination and leave the session empty.
			_session.press(event)
			_update_preview()
			return
		if _session.is_empty():
			# Nothing joined the session: a lone modifier, or a key already down
			# when the wait started. Bind it on its own, the way the old
			# single-event path did -- upstream binds a lone modifier too.
			_session.clear()
			_bind_event(event)
			return
		_session.release(event)
		_try_commit()
		return
	if event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_session.press(event)
			_update_preview()
		else:
			_session.release(event)
			_try_commit()
		return


func _try_commit() -> void:
	if not _session.is_ready():
		_update_preview()
		return
	var binding := _session.take()
	_session.clear()
	if binding.is_empty():
		return
	_bind_event(binding["primary"], binding["members"])


func _update_preview() -> void:
	if current_remap == Remap.Asset:
		text = _session.preview_text() if not _session.is_empty() else tr("TR_AWAITING_INPUT")
	else:
		var sel := _selected_id()
		if sel >= 0:
			var preview := _session.preview_text()
			%ShouldDisList.set_item_text(sel, preview if not preview.is_empty() else tr("TR_AWAITING_INPUT"))


## Applies a binding to whichever target this widget is currently remapping.
## Shared by every input path (a stick passes a normalised axis event).
func _bind_event(event: InputEvent, members: Array = []) -> void:
	if current_remap == Remap.Asset:
		if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
			Global.held_sprites[0].apply_binding(event, members)
			action = str(Global.held_sprites[0].sprite_id)
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)
		GlobInput.refresh_action_cache()
		update_other_assets()
		button_pressed = false

	elif current_remap == Remap.Keys:
		# The awaited row can disappear while we wait (list rebuilt, row deleted).
		var sel := _selected_id()
		if sel < 0:
			cancel_remap()
			return
		if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
			var sprite = Global.held_sprites[0]
			# `:=` cannot infer through an untyped Array element; spelled out.
			var action_name: String = sprite.disappear_keys
			if InputMap.has_action(action_name):
				var input_array: Array = InputMap.action_get_events(action_name)
				if sel < input_array.size():
					# action_add_event appends, so erase_event + add_event would
					# move this row to the end and desync the list order from the
					# event order. Rewrite the whole list instead.
					input_array[sel] = event
					InputMap.action_erase_events(action_name)
					for e in input_array:
						InputMap.action_add_event(action_name, e)
				else:
					InputMap.action_add_event(action_name, event)
			else:
				InputMap.add_action(action_name)
				InputMap.action_add_event(action_name, event)

			while sprite.disappear_chords.size() <= sel:
				sprite.disappear_chords.append([])
			sprite.disappear_chords[sel] = members.duplicate(true)
			sprite.apply_disappear_chords(sprite.disappear_chords)
		
		%ShouldDisList.set_item_text(sel, InputDisplayName.text(event, members))
		GlobInput.refresh_action_cache()
		%ShouldDisRemapButton.button_pressed = false


func update_other_assets():
	if Global.held_sprites.is_empty():
		return
	for i in get_tree().get_nodes_in_group("Sprites"):
		if i != Global.held_sprites[0]:
			if i.saved_event != null:
				# Identity comparison between STORED events: keep the RAW
				# as_text() here. Routing this through InputDisplayName would
				# compare localised labels and silently mis-match.
				if Global.held_sprites[0].saved_event.as_text() == i.saved_event.as_text():
					i.sync_asset_visibility(Global.held_sprites[0].get_node("%Sprite2D").visible)

func update_key_text():
	if InputMap.action_get_events(action).size() != 0:
		var members: Array = []
		if not Global.held_sprites.is_empty() and Global.held_sprites[0] != null and is_instance_valid(Global.held_sprites[0]):
			members = Global.held_sprites[0].chord_modifiers
		var bound: InputEvent = InputMap.action_get_events(action)[0]
		BindingLabel.set_button_text(self, InputDisplayName.text(bound, members), not members.is_empty())
		# A chord is drawn with compact labels so it fits the button; the tooltip
		# keeps every vendor alias of every member.
		tooltip_text = InputDisplayName.full_text(bound, members) if not members.is_empty() else ""
	else:
		BindingLabel.set_button_text(self, tr("TR_BIND_KEY"), false)
		tooltip_text = ""

func update_stuff():
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		if Global.held_sprites[0].saved_event != null:
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, Global.held_sprites[0].saved_event)

			update_key_text()

func _on_remove_asset_button_pressed():
	if InputMap.action_get_events(action).size() != 0:
		InputMap.action_erase_events(action)
		Global.held_sprites[0].apply_binding(null)
		GlobInput.refresh_action_cache()
		update_key_text()

func _on_is_asset_check_toggled(toggled_on):
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		if toggled_on:
			if !InputMap.has_action(action):
				InputMap.add_action(action)
				ReactionConfig.sprite_show(Global.held_sprites[0])
		else:
			if InputMap.has_action(action):
				InputMap.erase_action(action)
				Global.held_sprites[0].apply_binding(null)
				ReactionConfig.sprite_show(Global.held_sprites[0])
				update_key_text()
				%IsAssetButton.release_focus()
			# Unchecking "Is Asset" must also drop any pending await / capture pad.
			cancel_remap()

		Global.held_sprites[0].is_asset = toggled_on

func _on_should_disappear_check_toggled(toggled_on):
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		Global.held_sprites[0].should_disappear = toggled_on
	if toggled_on:
		%ShouldDisListContainer.show()
	else:
		%ShouldDisListContainer.hide()


func _on_should_dis_add_button_pressed():
	%ShouldDisList.add_item("Null")
	# Selecting right away is what makes Remap/Delete meaningful.
	# `:=` cannot infer through a `%Node` access; the type is spelled out.
	var new_row: int = %ShouldDisList.item_count - 1
	id = new_row
	%ShouldDisList.select(new_row)
	_update_action_buttons_enabled()


func _on_should_dis_del_button_pressed():
	var sel := _selected_id()
	if sel < 0:
		return
	%ShouldDisList.remove_item(sel)

	if not Global.held_sprites.is_empty():
		var held = Global.held_sprites[0]
		if held != null && is_instance_valid(held):
			var action_name = held.disappear_keys
			if InputMap.has_action(action_name):
				var events = InputMap.action_get_events(action_name)
				if sel < events.size():
					InputMap.action_erase_event(action_name, events[sel])
				# The chord table is index-parallel: dropping a row must drop its
				# entry, otherwise every later row inherits the wrong members.
				if sel < held.disappear_chords.size():
					held.disappear_chords.remove_at(sel)
					held.apply_disappear_chords(held.disappear_chords)

	id = -1
	%ShouldDisList.deselect_all()
	_update_action_buttons_enabled()


func _on_should_dis_list_item_selected(index):
	id = index
	_update_action_buttons_enabled()


func _on_should_dis_remap_button_toggled(toggled_on):
	current_remap = Remap.Keys
	var sel := _selected_id()
	if toggled_on:
		# No row (or a stale index): drop the await instead of leaving the button
		# half-pressed and writing later to a row that does not exist.
		if sel < 0:
			%ShouldDisRemapButton.button_pressed = false
			return
		%ShouldDisList.set_item_text(sel, tr("TR_AWAITING_INPUT"))
	set_process_input(toggled_on)
	if toggled_on:
		MouseCaptureArea.show_for(%ShouldDisRemapButton)
	else:
		MouseCaptureArea.hide_for(%ShouldDisRemapButton)
	# Keep key focus off this button at all times: while awaiting it would
	# swallow ui_accept, and re-grabbing it on exit re-arms on the next Enter.
	%ShouldDisRemapButton.release_focus()

func _on_should_dis_list_empty_clicked(_at_position, _mouse_button_index):
	selected_item = null
	id = -1
	_update_action_buttons_enabled()


func _on_should_dis_list_focus_exited():
	selected_item = null
	id = -1
	_update_action_buttons_enabled()


func _on_dont_hide_on_toggle_check_toggled(toggled_on: bool) -> void:
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		Global.held_sprites[0].show_only = toggled_on


func _on_hold_to_show_on_toggle_check_toggled(toggled_on: bool) -> void:
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		Global.held_sprites[0].hold_to_show = toggled_on

func _on_min_duration_spin_box_value_changed(value: float) -> void:
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		Global.held_sprites[0].min_duration = value

func _on_tail_duration_spin_box_value_changed(value: float) -> void:
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		Global.held_sprites[0].tail_duration = value

func _on_inclusive_key_check_on_toggle_check_toggled(toggled_on: bool) -> void:
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		Global.held_sprites[0].inclusive_key_check = toggled_on

func _on_ignore_if_rest_on_toggle_check_toggled(toggled_on: bool) -> void:
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		Global.held_sprites[0].ignore_if_rest = toggled_on

func _on_auto_show_on_toggle_check_toggled(toggled_on: bool) -> void:
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		Global.held_sprites[0].auto_show = toggled_on

func _on_auto_hide_on_toggle_check_toggled(toggled_on: bool) -> void:
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		Global.held_sprites[0].auto_hide = toggled_on

func _on_cast_time_spin_box_value_changed(value: float) -> void:
	if Global.held_sprites[0] != null && is_instance_valid(Global.held_sprites[0]):
		Global.held_sprites[0].cast_time = value
