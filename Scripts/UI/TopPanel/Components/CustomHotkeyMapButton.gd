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
	set_process_unhandled_input(false)
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
	set_process_unhandled_input(_button_pressed)
	if _button_pressed:
		text = tr("TR_AWAITING_INPUT")
		release_focus()
	else:
		update_key_text()
		grab_focus()
		

func _unhandled_input(event):
	if not event is InputEventMouseMotion:
		if event.is_released():
			update_hotkey_event(event)
				
			button_pressed = false
	

func update_key_text():
	if hotkey_event != null && is_instance_valid(hotkey_event):
		text = "%s" % hotkey_event.as_text()
	else:
		text = "Null"

static func is_same_hotkey_event(event1: InputEvent, event2: InputEvent) -> bool:
	var result = true
	
	if event1 is InputEventKey and event2 is InputEventKey:
		result = result and event1.keycode == event2.keycode
	elif event1 is InputEventMouseButton and event2 is InputEventMouseButton:
		result = result and event1.button_index == event2.button_index
	else:
		result = false
		
	result = result and event1.ctrl_pressed == event2.ctrl_pressed
	result = result and event1.shift_pressed == event2.shift_pressed
	result = result and event1.alt_pressed == event2.alt_pressed
	result = result and event1.meta_pressed == event2.meta_pressed
		
	return result

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
		var dis_action_events = InputMap.action_get_events(sprite.disappear_keys)
		var changed_hotkey: Array = []
		for id in dis_action_events.size():
			if is_same_hotkey_event(hotkey_event, dis_action_events[id]):
				changed_hotkey.append(dis_action_events.get(id))
		
		for old_event in changed_hotkey:
			var new_event = (event as InputEvent).duplicate()
			InputMap.action_erase_event(sprite.disappear_keys, old_event)
			InputMap.action_add_event(sprite.disappear_keys, new_event)
	
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
