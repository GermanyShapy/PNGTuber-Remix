extends Node

var should_change: bool = false

# Bounce UI is built at runtime: the panel scene stays untouched, so no scene
# format churn and the widgets inherit this panel's theme automatically.
var _bounce_inclusive: CheckBox
var _bounce_list: ItemList
var _bounce_add: Button
var _bounce_del: Button
var _bounce_remap: Button
var _bounce_selected: int = -1
# Collects the inputs pressed while awaiting; commits once every member is
# released (see BindingSession).
var _bounce_session := BindingSession.new()


func _ready() -> void:
	# `ready` never fires twice: awaiting it unconditionally hangs whenever this
	# panel is added to a tree whose scene is already up.
	var scene := get_tree().current_scene
	if scene != null and not scene.is_node_ready():
		await scene.ready
	Global.connect("update_anim", update_anim)
	%SquishAmount.get_node("%SliderValue").value_changed.connect(_on_squish_amount_changed)
	%SquishAmount.get_node("%SpinBoxValue").value_changed.connect(_on_squish_amount_changed)
	%BlinkChanceSlider.value = 10
	Global.slider_values.connect(set_slider_data)
	Global.binding_labels_changed.connect(_on_binding_labels_changed)
	# The binding set is rewritten by this panel, by a model load and by the
	# top-bar hotkey remap, so a single signal keeps the rows truthful.
	Global.bounce_bindings_changed.connect(_on_bounce_bindings_changed)
	# A new project clears the model-scoped bindings; the rows follow.
	Global.new_file.connect(_on_bounce_new_file)
	# Deferred: during _ready the parent is still setting up its children and
	# rejects add_child() outright.
	_build_bounce_ui.call_deferred()
	update_anim()


func set_slider_data(data):
	%BlinkChanceSlider.value = data.blink_chance
	%BlinkSpeedSlider.value = data.blink_speed


# Mirroring the container into the widgets must not emit their change signals:
# the toggled / value_changed handlers below call sprite_container.save_state(),
# which re-serializes the whole state dictionary even though this function only
# wrote back the values it had just read. The no-signal setters keep the display
# identical and drop that round trip from Global.update_anim.
func update_anim():
	should_change = false
	# The panel readies before main.gd has published the container, so the
	# first call has nothing to mirror yet -- the model-wide bounce widgets do
	# not depend on it and are refreshed below regardless.
	if Global.sprite_container != null:
		%BounceStateCheck.set_pressed_no_signal(Global.sprite_container.bounce_state)
		%MouthClosedAnim.select(Global.sprite_container.mouth_closed)
		%MouthOpenAnim.select(Global.sprite_container.mouth_open)
		%ShouldSquish.set_pressed_no_signal(Global.sprite_container.should_squish)
		%SquishAmount.get_node("%SliderValue").set_value_no_signal(Global.sprite_container.squish_amount)
	if _bounce_inclusive != null:
		_bounce_inclusive.set_pressed_no_signal(Global.settings_dict.get("bounce_inclusive", true))
	should_change = true


func _on_squish_amount_changed(value: float):
	if Global.sprite_container == null:
		return
	add_to_undo("squish_amount", Global.sprite_container.squish_amount, value)
	Global.sprite_container.squish_amount = value
	Global.sprite_container.save_state(Global.current_state)


func _on_blink_speed_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		add_to_undo("blink_speed", Global.sprite_container.blink_speed, %BlinkSpeedSlider.value)
		Global.settings_dict.blink_speed = %BlinkSpeedSlider.value
		%BlinkSpeedLabel.text = tr("TR_BLINK_SPEED") + " " + str(snappedf(%BlinkSpeedSlider.value, 0.1))


func _on_blink_speed_slider_value_changed(value):
	%BlinkSpeedLabel.text = tr("TR_BLINK_SPEED") + " " + str(snappedf(value, 0.1))
	Global.settings_dict.blink_speed = value


func _on_should_squish_toggled(toggled_on: bool) -> void:
	add_to_undo("should_squish", Global.sprite_container.should_squish, toggled_on)
	Global.sprite_container.should_squish = toggled_on
	Global.sprite_container.save_state(Global.current_state)


func _on_blink_chance_slider_value_changed(value: float) -> void:
	add_to_undo("blink_chance", Global.settings_dict.blink_chance, value)
	%BlinkChanceLabel.text = tr("TR_BLINK_CHANCE") + " " + str(value)
	Global.settings_dict.blink_chance = value


func _on_bounce_state_check_toggled(toggled_on):
	add_to_undo("bounce_state", Global.sprite_container.bounce_state, toggled_on)
	Global.sprite_container.bounce_state = toggled_on
	Global.sprite_container.save_state(Global.current_state)


func add_to_undo(action, value, new_value):
	if should_change:
		var d = {
			sprite_container = Global.sprite_container,
			state = Global.current_state,
			action = action,
			value = value,
			new_val = new_value,
		}
		UndoRedoManager.push_data(d)


func _on_mouth_closed_anim_item_selected(index: int) -> void:
	Global.sprite_container.mouth_closed = index
	var old_state = Global.sprite_container.current_mc_anim
	match index:
		0:
			Global.sprite_container.current_mc_anim = "Idle"
		1:
			Global.sprite_container.current_mc_anim = "Bouncy"
		3:
			Global.sprite_container.current_mc_anim = "One Bounce"
		4:
			Global.sprite_container.current_mc_anim = "Wobble"
		5:
			Global.sprite_container.current_mc_anim = "Squish"
		6:
			Global.sprite_container.current_mc_anim = "Float"

	add_to_undo("current_mc_anim", old_state, Global.sprite_container.current_mc_anim)

	Global.sprite_container.save_state(Global.current_state)


func _on_mouth_open_anim_item_selected(index: int) -> void:
	Global.sprite_container.mouth_open = index
	var old_state = Global.sprite_container.current_mo_anim
	match index:
		0:
			Global.sprite_container.current_mo_anim = "Idle"
		1:
			Global.sprite_container.current_mo_anim = "Bouncy"
		3:
			Global.sprite_container.current_mo_anim = "One Bounce"
		4:
			Global.sprite_container.current_mo_anim = "Wobble"
		5:
			Global.sprite_container.current_mo_anim = "Squish"
		6:
			Global.sprite_container.current_mo_anim = "Float"

	add_to_undo("current_mo_anim", old_state, Global.sprite_container.current_mo_anim)
	Global.sprite_container.save_state(Global.current_state)


# --- Bounce hotkeys --------------------------------------------------------
# Model-wide, unlike the per-state "bounce when changing states" checkbox right
# above them. The click-bounce opt-in lives in the top-bar settings instead: it
# only applies to the pop-up windows, which is a model-wide property.

func _build_bounce_ui() -> void:
	var host := get_parent() as Container
	if host == null:
		return
	
	var section := VBoxContainer.new()
	section.name = "BounceSection"
	section.add_theme_constant_override("separation", 4)
	
	var label := Label.new()
	label.text = "TR_BOUNCE_KEYS"
	label.tooltip_text = "TR_BOUNCE_KEYS_TOOLTIP"
	label.custom_minimum_size = Vector2(116, 0)
	label.add_theme_font_size_override("font_size", 16)
	section.add_child(label)
	
	var buttons := HBoxContainer.new()
	section.add_child(buttons)
	_bounce_add = _make_bounce_button(buttons, "TR_ADD_KEY")
	_bounce_add.pressed.connect(_on_bounce_add_pressed)
	_bounce_del = _make_bounce_button(buttons, "TR_DELETE_KEY")
	_bounce_del.pressed.connect(_on_bounce_del_pressed)
	_bounce_remap = _make_bounce_button(buttons, "TR_REMAP_KEY")
	_bounce_remap.toggle_mode = true
	_bounce_remap.toggled.connect(_on_bounce_remap_toggled)
	
	_bounce_list = ItemList.new()
	_bounce_list.custom_minimum_size = Vector2(0, 100)
	_bounce_list.auto_height = true
	_bounce_list.max_columns = 3
	_bounce_list.fixed_column_width = 122
	_bounce_list.allow_reselect = true
	_bounce_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bounce_list.item_selected.connect(_on_bounce_row_selected)
	section.add_child(_bounce_list)
	
	_bounce_inclusive = CheckBox.new()
	_bounce_inclusive.text = "TR_INCLUSIVE_KEY_CHECK"
	_bounce_inclusive.toggled.connect(_on_bounce_inclusive_toggled)
	section.add_child(_bounce_inclusive)
	
	host.add_child(section)
	# Sits right under "bounce when changing states": the sibling trigger.
	if %BounceStateCheck.get_parent() == host:
		host.move_child(section, %BounceStateCheck.get_index() + 1)
	
	set_process_input(false)
	_refresh_bounce_list()


func _make_bounce_button(p_parent: Control, p_text: String) -> Button:
	var button := Button.new()
	button.text = p_text
	button.theme_type_variation = &"RemapButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	p_parent.add_child(button)
	return button


func _bounce_keys() -> Array:
	var stored = Global.settings_dict.get("bounce_keys", [])
	return stored.duplicate(true) if stored is Array else []


func _bounce_chords() -> Array:
	var stored = Global.settings_dict.get("bounce_key_chords", [])
	return stored.duplicate(true) if stored is Array else []


## Valid row index, or -1 when the selection outlived its row.
func _bounce_row() -> int:
	if _bounce_list != null and _bounce_selected >= 0 and _bounce_selected < _bounce_list.item_count:
		return _bounce_selected
	return -1


## Rebuilt only on real edits: update_anim() runs on every state switch and must
## not drop the selection or interrupt a remap.
func _refresh_bounce_list(p_keep_selection: bool = false) -> void:
	if _bounce_list == null:
		return
	var keep := _bounce_selected
	var keys := _bounce_keys()
	var chords := _bounce_chords()
	_bounce_list.clear()
	for i in range(keys.size()):
		var members: Array = []
		if i < chords.size() and chords[i] is Array:
			members = chords[i]
		var text := "Null"
		if keys[i] is InputEvent:
			text = InputDisplayName.text(keys[i], members)
		_bounce_list.add_item(text)
	if p_keep_selection and keep >= 0 and keep < _bounce_list.item_count:
		_bounce_list.select(keep)
		_bounce_selected = keep
	else:
		_bounce_selected = -1
	_update_bounce_buttons()


func _on_binding_labels_changed() -> void:
	_refresh_bounce_list(true)


func _on_bounce_bindings_changed() -> void:
	_refresh_bounce_list(true)


func _on_bounce_new_file() -> void:
	_refresh_bounce_list()


func _update_bounce_buttons() -> void:
	if _bounce_del == null:
		return
	var has_row := _bounce_row() >= 0
	_bounce_del.disabled = not has_row
	_bounce_remap.disabled = not has_row


func _on_bounce_row_selected(index: int) -> void:
	_bounce_selected = index
	_update_bounce_buttons()


func _on_bounce_inclusive_toggled(toggled_on: bool) -> void:
	BounceInput.set_inclusive(toggled_on)


func _on_bounce_add_pressed() -> void:
	if _bounce_list == null:
		return
	var keys := _bounce_keys()
	var chords := _bounce_chords()
	keys.append(null)
	chords.append([])
	# Unbound rows never reach the InputMap, so this does not need a rebuild.
	Global.settings_dict["bounce_keys"] = keys
	Global.settings_dict["bounce_key_chords"] = chords
	_bounce_list.add_item("Null")
	_bounce_selected = keys.size() - 1
	_bounce_list.select(_bounce_selected)
	_update_bounce_buttons()


func _on_bounce_del_pressed() -> void:
	var row := _bounce_row()
	if row < 0:
		return
	var keys := _bounce_keys()
	var chords := _bounce_chords()
	keys.remove_at(row)
	if row < chords.size():
		chords.remove_at(row)
	_bounce_selected = -1
	BounceInput.rebuild(keys, chords)
	_refresh_bounce_list()


func _on_bounce_remap_toggled(toggled_on: bool) -> void:
	if _bounce_row() < 0:
		_bounce_remap.set_pressed_no_signal(false)
		return
	if toggled_on:
		_bounce_session.clear()
		_bounce_remap.text = tr("TR_AWAITING_INPUT")
		_bounce_remap.release_focus()
		MouseCaptureArea.show_for(_bounce_remap)
		set_process_input(true)
	else:
		_cancel_bounce_remap()


func _cancel_bounce_remap() -> void:
	_bounce_session.clear()
	set_process_input(false)
	if _bounce_remap == null:
		return
	MouseCaptureArea.hide_for(_bounce_remap)
	if _bounce_remap.button_pressed:
		_bounce_remap.set_pressed_no_signal(false)
	_bounce_remap.text = "TR_REMAP_KEY"


func _update_bounce_preview() -> void:
	var row := _bounce_row()
	if row < 0:
		return
	var preview := _bounce_session.preview_text()
	_bounce_list.set_item_text(row, preview if not preview.is_empty() else tr("TR_AWAITING_INPUT"))


func _try_commit_bounce() -> void:
	if not _bounce_session.is_ready():
		_update_bounce_preview()
		return
	var binding := _bounce_session.take()
	_bounce_session.clear()
	if binding.is_empty():
		return
	_bind_bounce_event(binding["primary"], binding["members"])


func _bind_bounce_event(event: InputEvent, members: Array = []) -> void:
	var row := _bounce_row()
	if row < 0:
		_cancel_bounce_remap()
		return
	var keys := _bounce_keys()
	var chords := _bounce_chords()
	# One row per binding: a duplicate would make erase-by-event ambiguous.
	for i in range(keys.size()):
		if i == row:
			continue
		var other: Array = []
		if i < chords.size() and chords[i] is Array:
			other = chords[i]
		if CustomHotkeyMapButton.is_same_binding(event, members, keys[i], other):
			_refresh_bounce_list()
			_cancel_bounce_remap()
			return
	while keys.size() <= row:
		keys.append(null)
	while chords.size() <= row:
		chords.append([])
	keys[row] = event
	chords[row] = members.duplicate(true)
	BounceInput.rebuild(keys, chords)
	_refresh_bounce_list()
	_bounce_list.select(row)
	_bounce_selected = row
	_update_bounce_buttons()
	_cancel_bounce_remap()


func _input(event: InputEvent) -> void:
	var panel := get_parent() as CanvasItem
	if panel == null or not panel.is_visible_in_tree():
		# The right panel was hidden mid-await: stop swallowing input.
		_cancel_bounce_remap()
		return
	if event is InputEventMouseMotion:
		return
	# Sticks report no release edge that can be stored, so coming back into the
	# deadzone only marks the member released.
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		if GlobInput.is_joy_pushed(event):
			_bounce_session.press(GlobInput.normalize_joy_event(event))
			_update_bounce_preview()
		else:
			_bounce_session.release_axis(event.axis)
			_try_commit_bounce()
		return
	# `_input` runs before GUI picking: a press on the capture pad is consumed
	# here, a press anywhere else cancels instead of binding a stray button.
	if event is InputEventMouseButton:
		var step := MouseCaptureArea.step_mouse(_bounce_remap, event)
		if step == MouseCaptureArea.MouseStep.PRESS_OUTSIDE:
			_cancel_bounce_remap()
			return
		if step == MouseCaptureArea.MouseStep.PRESS_ON_PAD:
			_bounce_session.press(event)
			_update_bounce_preview()
			return
		if step != MouseCaptureArea.MouseStep.RELEASE_ON_PAD:
			if not event.pressed:
				# Released off the pad: drop the member instead of leaving it
				# "held" in the session forever.
				_bounce_session.release(event)
			return
		get_viewport().set_input_as_handled()
		_bounce_session.press(event)
		_bounce_session.release(event)
		_try_commit_bounce()
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed:
			if event.echo:
				return
			_bounce_session.press(event)
			_update_bounce_preview()
			return
		if _bounce_session.is_empty():
			# Lone modifier, or a key already down when the wait started.
			_bounce_session.clear()
			_bind_bounce_event(event)
			return
		_bounce_session.release(event)
		_try_commit_bounce()
		return
	if event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		if event.pressed:
			_bounce_session.press(event)
			_update_bounce_preview()
		else:
			_bounce_session.release(event)
			_try_commit_bounce()
		return
