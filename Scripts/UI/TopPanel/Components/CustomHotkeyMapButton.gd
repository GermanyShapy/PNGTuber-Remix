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

func _init():
	toggle_mode = true
	theme_type_variation = "RemapButton"
	
	
func _ready():
	set_process_input(false)
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
	
	for state_btn: StateButton in state_buttons:
		if state_btn.saved_event == null:
			continue
		if is_same_hotkey_event(hotkey_event, state_btn.saved_event):
			hotkey_state_buttons.append(state_btn)
			
	for sprite: SpriteObject in sprites:
		if sprite.saved_event == null:
			continue
		if is_same_hotkey_event(hotkey_event, sprite.saved_event):
			hotkey_asset_sprites.append(sprite)

		if InputMap.has_action(sprite.disappear_keys): #disappear keys
			var dis_action_events = InputMap.action_get_events(sprite.disappear_keys)
			for id in dis_action_events.size():
				if is_same_hotkey_event(hotkey_event, dis_action_events[id]):
					hotkey_disappear_sprites.append(sprite)
					break
	
	for cycle in Global.settings_dict.cycles:
		var toggle_event = cycle.toggle
		var forward_event = cycle.forward
		var backward_event = cycle.backward
		
		if is_same_hotkey_event(hotkey_event, toggle_event) or is_same_hotkey_event(hotkey_event, forward_event) or is_same_hotkey_event(hotkey_event, backward_event):
			hotkey_cycles.append(cycle)

func _toggled(_button_pressed):
	set_process_input(_button_pressed)
	if _button_pressed:
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
	# A stick binds the moment its direction crosses the deadzone -- see
	# StandGlobalInput.is_joy_pushed() for why "on release" cannot work.
	if event is InputEventJoypadMotion:
		if not GlobInput.is_joy_pushed(event):
			return
		get_viewport().set_input_as_handled()
		update_hotkey_event(GlobInput.normalize_joy_event(event))
		button_pressed = false
		return
	# `_input` runs before GUI picking, so a press that lands on the capture pad
	# is swallowed here before the control the pad covers ever reacts. A mouse
	# press anywhere else cancels the await, never binds a stray mouse button.
	if event is InputEventMouseButton:
		var step := MouseCaptureArea.step_mouse(self, event)
		if step == MouseCaptureArea.MouseStep.PRESS_OUTSIDE:
			cancel_await()
			return
		if step != MouseCaptureArea.MouseStep.RELEASE_ON_PAD:
			return
	elif not event.is_released():
		# Swallow the key press too: otherwise the key could still fire a
		# shortcut or move focus before its release binds it.
		get_viewport().set_input_as_handled()
		return
	# Swallow the bound event so it cannot also drive the GUI afterwards.
	get_viewport().set_input_as_handled()
	update_hotkey_event(event)

	button_pressed = false


func update_key_text():
	if hotkey_event != null && is_instance_valid(hotkey_event):
		text = InputDisplayName.text(hotkey_event)
	else:
		text = "Null"

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

func update_hotkey_event(event):
	#Check for duplicate hotkey events
	for another_hotkey_event: InputEvent in Global.settings_dict.custom_hotkeys.values():
		if is_same_hotkey_event(event, another_hotkey_event):
			update_key_text()
			return
	
	var action_name = ""
	
	for state_btn: StateButton in hotkey_state_buttons:
		var new_event = (event as InputEvent).duplicate()
		action_name = state_btn.input_key
		InputMap.action_erase_events(action_name)
		InputMap.action_add_event(action_name, new_event)
		state_btn.saved_event = new_event
			
	for sprite: SpriteObject in hotkey_asset_sprites:
		var new_event = (event as InputEvent).duplicate()
		action_name = str(sprite.sprite_id)
		InputMap.action_erase_events(action_name)
		InputMap.action_add_event(action_name, new_event)
		sprite.saved_event = new_event

	for sprite: SpriteObject in hotkey_disappear_sprites:
		var dis_action_events: Array = InputMap.action_get_events(sprite.disappear_keys)
		var changed := false
		for id in dis_action_events.size():
			if is_same_hotkey_event(hotkey_event, dis_action_events[id]):
				dis_action_events[id] = (event as InputEvent).duplicate()
				changed = true
		# action_add_event appends: erase_event + add_event would move every
		# replaced row to the end. Rewrite the whole list to keep the order.
		if changed:
			InputMap.action_erase_events(sprite.disappear_keys)
			for e in dis_action_events:
				InputMap.action_add_event(sprite.disappear_keys, e)
	
	for cycle in hotkey_cycles:
		var toggle_event = cycle.toggle
		var forward_event = cycle.forward
		var backward_event = cycle.backward
		
		if is_same_hotkey_event(hotkey_event, toggle_event):
			cycle.toggle = (event as InputEvent).duplicate()
		if is_same_hotkey_event(hotkey_event, forward_event):
			cycle.forward = (event as InputEvent).duplicate()
		if is_same_hotkey_event(hotkey_event, backward_event):
			cycle.backward = (event as InputEvent).duplicate()
	
	hotkey_event = (event as InputEvent).duplicate()
	GlobInput.refresh_action_cache()
	update_key_text()
	TopBarInput.desel_everything()

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
