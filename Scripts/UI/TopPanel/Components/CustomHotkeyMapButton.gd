extends Button
class_name CustomHotkeyMapButton
		
@export var hotkey_name_line_edit: LineEdit
var hotkey_name: String
var hotkey_event: InputEvent:
	get:
		if hotkey_name == null or hotkey_name.is_empty():
			return null
		return Global.settings_dict.custom_hotkeys[hotkey_name]
	set(value):
		Global.settings_dict.custom_hotkeys[hotkey_name] = value

var hotkey_state_buttons: Array[Node]
var hotkey_asset_sprites: Array[Node]
var hotkey_disappear_sprites: Array[Node]
var hotkey_cycles: Array
# Collects the inputs pressed while awaiting; a binding commits once every
# member is released (see BindingSession).
var _session := BindingSession.new()

func _init():
	toggle_mode = true
	theme_type_variation = "RemapButton"
	
	
func _ready():
	set_process_input(false)
	_ensure_chord_dict()
	# Vendor-label style is a setting: re-derive our own text when it changes.
	Global.binding_labels_changed.connect(update_key_text)
	update_key_text()
	refresh_hotkey_ref_arrays()
	hotkey_name_line_edit.text = hotkey_name

func refresh_hotkey_ref_arrays():
	hotkey_state_buttons.clear()
	hotkey_asset_sprites.clear()
	hotkey_disappear_sprites.clear()
	hotkey_cycles.clear()
	
	var state_buttons = get_tree().get_nodes_in_group("StateButtons")
	var sprites = get_tree().get_nodes_in_group("Sprites")
	
	var hotkey_members := _current_members()

	for state_btn: StateButton in state_buttons:
		if state_btn.saved_event == null:
			continue
		if is_same_binding(hotkey_event, hotkey_members, state_btn.saved_event, state_btn.chord_modifiers):
			hotkey_state_buttons.append(state_btn)
			
	for sprite: SpriteObject in sprites:
		if sprite.saved_event == null:
			continue
		if is_same_binding(hotkey_event, hotkey_members, sprite.saved_event, sprite.chord_modifiers):
			hotkey_asset_sprites.append(sprite)

		if InputMap.has_action(sprite.disappear_keys): #disappear keys
			var dis_action_events = InputMap.action_get_events(sprite.disappear_keys)
			for id in dis_action_events.size():
				var target_members: Array = sprite.disappear_chords[id] if id < sprite.disappear_chords.size() else []
				if is_same_binding(hotkey_event, hotkey_members, dis_action_events[id], target_members):
					hotkey_disappear_sprites.append(sprite)
					break
	
	for cycle in Global.settings_dict.cycles:
		if is_same_binding(hotkey_event, hotkey_members, cycle.toggle, cycle.get("toggle_chord", [])) \
			or is_same_binding(hotkey_event, hotkey_members, cycle.forward, cycle.get("forward_chord", [])) \
			or is_same_binding(hotkey_event, hotkey_members, cycle.backward, cycle.get("backward_chord", [])):
			hotkey_cycles.append(cycle)

func _toggled(_button_pressed):
	set_process_input(_button_pressed)
	if _button_pressed:
		_session.clear()
		text = tr("TR_AWAITING_INPUT")
		release_focus()
		MouseCaptureArea.show_for(self)
	else:
		update_key_text()
		release_focus()
		MouseCaptureArea.hide_for(self)
		

func cancel_await() -> void:
	# Drops the awaiting state from any entry point (popup closed, a click
	# outside the capture pad, ...) without relying on the toggled() gate.
	_session.clear()
	set_process_input(false)
	MouseCaptureArea.hide_for(self)
	if button_pressed:
		button_pressed = false
	else:
		update_key_text()


func _input(event):
	if not is_visible_in_tree():
		# The settings popup was closed mid-await: stop swallowing input.
		cancel_await()
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
	# `_input` runs before GUI picking, so a press that lands on the capture pad
	# is swallowed here before the control the pad covers ever reacts. A mouse
	# press anywhere else cancels the await, never binds a stray mouse button.
	if event is InputEventMouseButton:
		var step := MouseCaptureArea.step_mouse(self, event)
		if step == MouseCaptureArea.MouseStep.PRESS_OUTSIDE:
			cancel_await()
			return
		if step == MouseCaptureArea.MouseStep.PRESS_ON_PAD:
			_session.press(event)
			_update_preview()
			return
		if step != MouseCaptureArea.MouseStep.RELEASE_ON_PAD:
			return
			if not event.pressed:
				# Released off the pad: drop the member instead of leaving it
				# "held" in the session forever.
				_session.release(event)
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
			update_hotkey_event(event)
			button_pressed = false
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
	update_hotkey_event(binding["primary"], binding["members"])
	button_pressed = false


func _update_preview() -> void:
	var preview := _session.preview_text()
	text = preview if not preview.is_empty() else tr("TR_AWAITING_INPUT")


func _ensure_chord_dict() -> void:
	if not Global.settings_dict.has("custom_hotkey_chords"):
		Global.settings_dict["custom_hotkey_chords"] = {}


func update_key_text():
	if hotkey_event != null && is_instance_valid(hotkey_event):
		_ensure_chord_dict()
		var members: Array = Global.settings_dict.custom_hotkey_chords.get(hotkey_name, [])
		BindingLabel.set_button_text(self, InputDisplayName.text(hotkey_event, members), not members.is_empty())
		# Compact in the row, full aliases in the tooltip.
		tooltip_text = InputDisplayName.full_text(hotkey_event, members) if not members.is_empty() else ""
	else:
		BindingLabel.set_button_text(self, "Null", false)
		tooltip_text = ""

static func is_same_hotkey_event(event1: InputEvent, event2: InputEvent) -> bool:
	if event1 == null or event2 == null:
		return false

	if event1 is InputEventKey and event2 is InputEventKey:
		if event1.keycode != event2.keycode:
			return false
	elif event1 is InputEventMouseButton and event2 is InputEventMouseButton:
		if event1.button_index != event2.button_index:
			return false
	elif event1 is InputEventJoypadButton and event2 is InputEventJoypadButton:
		# Device is deliberately not compared: a binding has to survive a
		# reconnect or a different USB port.
		if event1.button_index != event2.button_index:
			return false
	elif event1 is InputEventJoypadMotion and event2 is InputEventJoypadMotion:
		# Axis plus direction only -- the magnitude is device specific.
		if event1.axis != event2.axis:
			return false
		if (event1.axis_value >= 0.0) != (event2.axis_value >= 0.0):
			return false
	else:
		return false

	# A joypad event carries no modifiers at all, and reading `ctrl_pressed` off
	# one raises a runtime error -- so the modifier comparison only applies when
	# both sides actually have modifiers.
	if not (event1 is InputEventWithModifiers and event2 is InputEventWithModifiers):
		return true

	return event1.ctrl_pressed == event2.ctrl_pressed \
		and event1.shift_pressed == event2.shift_pressed \
		and event1.alt_pressed == event2.alt_pressed \
		and event1.meta_pressed == event2.meta_pressed

func update_hotkey_event(event, p_members: Array = []):
	_ensure_chord_dict()
	var members: Array = p_members.duplicate(true) if p_members != null else []
	var previous_members := _current_members()

	#Check for duplicate bindings (primary plus members)
	for another_name in Global.settings_dict.custom_hotkeys:
		if another_name == hotkey_name:
			continue
		var another_event: InputEvent = Global.settings_dict.custom_hotkeys[another_name]
		var another_members: Array = Global.settings_dict.custom_hotkey_chords.get(another_name, [])
		if is_same_binding(event, members, another_event, another_members):
			update_key_text()
			return
	
	var action_name = ""
	
	for state_btn: StateButton in hotkey_state_buttons:
		var new_event = (event as InputEvent).duplicate()
		action_name = state_btn.input_key
		InputMap.action_erase_events(action_name)
		InputMap.action_add_event(action_name, new_event)
		state_btn.apply_binding(new_event, members)
			
	for sprite: SpriteObject in hotkey_asset_sprites:
		var new_event = (event as InputEvent).duplicate()
		action_name = str(sprite.sprite_id)
		InputMap.action_erase_events(action_name)
		InputMap.action_add_event(action_name, new_event)
		sprite.apply_binding(new_event, members)

	for sprite: SpriteObject in hotkey_disappear_sprites:
		var dis_action_events: Array = InputMap.action_get_events(sprite.disappear_keys)
		var changed := false
		for id in dis_action_events.size():
			var target_members: Array = sprite.disappear_chords[id] if id < sprite.disappear_chords.size() else []
			if is_same_binding(hotkey_event, previous_members, dis_action_events[id], target_members):
				dis_action_events[id] = (event as InputEvent).duplicate()
				while sprite.disappear_chords.size() <= id:
					sprite.disappear_chords.append([])
				sprite.disappear_chords[id] = members.duplicate(true)
				changed = true
		# action_add_event appends: erase_event + add_event would move every
		# replaced row to the end. Rewrite the whole list to keep the order.
		if changed:
			InputMap.action_erase_events(sprite.disappear_keys)
			for e in dis_action_events:
				InputMap.action_add_event(sprite.disappear_keys, e)
			sprite.apply_disappear_chords(sprite.disappear_chords)
	
	for cycle in hotkey_cycles:
		if is_same_binding(hotkey_event, previous_members, cycle.toggle, cycle.get("toggle_chord", [])):
			cycle.toggle = (event as InputEvent).duplicate()
			cycle["toggle_chord"] = members.duplicate(true)
		if is_same_binding(hotkey_event, previous_members, cycle.forward, cycle.get("forward_chord", [])):
			cycle.forward = (event as InputEvent).duplicate()
			cycle["forward_chord"] = members.duplicate(true)
		if is_same_binding(hotkey_event, previous_members, cycle.backward, cycle.get("backward_chord", [])):
			cycle.backward = (event as InputEvent).duplicate()
			cycle["backward_chord"] = members.duplicate(true)
	
	hotkey_event = (event as InputEvent).duplicate()
	Global.settings_dict.custom_hotkey_chords[hotkey_name] = members.duplicate(true)
	GlobInput.refresh_action_cache()
	update_key_text()
	TopBarInput.desel_everything()


func _current_members() -> Array:
	_ensure_chord_dict()
	return Global.settings_dict.custom_hotkey_chords.get(hotkey_name, [])


## Full binding identity: primary event plus member set. Two bindings that only
## share the primary event are different bindings.
static func is_same_binding(p_e1: InputEvent, p_m1: Array, p_e2: InputEvent, p_m2: Array) -> bool:
	if not is_same_hotkey_event(p_e1, p_e2):
		return false
	var a: Array = p_m1 if p_m1 is Array else []
	var b: Array = p_m2 if p_m2 is Array else []
	if a.size() != b.size():
		return false
	var used: Array = []
	for x in a:
		var found := false
		for i in range(b.size()):
			if i in used:
				continue
			if is_same_hotkey_event(x, b[i]):
				used.append(i)
				found = true
				break
		if not found:
			return false
	return true


func _on_hotkey_name_text_submitted(new_text):
	if hotkey_name == new_text:
		return
	
	var is_duplicate_name = false
	#Check for duplicate names
	for name in Global.settings_dict.custom_hotkeys:
		if new_text == name:
			is_duplicate_name = true
			break
	
	if !is_duplicate_name:
		var event = Global.settings_dict.custom_hotkeys[hotkey_name]
		Global.settings_dict.custom_hotkeys[new_text] = event
		Global.settings_dict.custom_hotkeys.erase(hotkey_name)
		# The chord table is keyed by hotkey name: rename it together with the
		# binding or the members are orphaned under the old name.
		_ensure_chord_dict()
		var members: Array = Global.settings_dict.custom_hotkey_chords.get(hotkey_name, [])
		Global.settings_dict.custom_hotkey_chords[new_text] = members
		Global.settings_dict.custom_hotkey_chords.erase(hotkey_name)
		hotkey_name = new_text
	else:
		hotkey_name_line_edit.text = hotkey_name
	
	Global.spinbox_held = false
	hotkey_name_line_edit.release_focus()
	
func _on_hotkey_name_focus_entered() -> void:
	Global.spinbox_held = true

func _on_hotkey_name_focus_exited() -> void:
	Global.spinbox_held = false
	_on_hotkey_name_text_submitted(hotkey_name_line_edit.text)

func _on_hotkey_name_mouse_exited() -> void:
	Global.spinbox_held = false
	_on_hotkey_name_text_submitted(hotkey_name_line_edit.text)
