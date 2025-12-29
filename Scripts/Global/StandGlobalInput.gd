class_name StandGlobalInput
extends GlobalInput

var just_pressed_details:Dictionary = {}
var just_released_details:Dictionary = {}
var pressed_details:Dictionary = {}
var pressed_before_details:Dictionary = {}

func _ready() -> void:
	use_physics_frames = true

func _physics_process(delta: float) -> void:
	pressed_before_details = pressed_details
	pressed_details = get_keys_pressed_detailed()
	
	just_pressed_details.clear()
	just_released_details.clear()
	
	for key in pressed_details:
		if key != "os" and !pressed_before_details.has(key):
			just_pressed_details[key] = true
	
	for key in pressed_before_details:
		if key != "os" and !pressed_details.has(key):
			just_released_details[key] = true
	
	#if !pressed_details.is_empty() or !pressed_before_details.is_empty():
		#print("pressed: " + str(pressed_details) + "     pressed_before: " + str(pressed_before_details))
	#if !just_pressed_details.is_empty():
		#print("  just_pressed: " + str(just_pressed_details))
	#if !just_released_details.is_empty():
		#print("  just_released: " + str(just_released_details))
	
func get_stand_key_string(keycode):
	if KEY_QUOTELEFT == keycode:
		return OS.get_keycode_string(KEY_ASCIITILDE)
	elif KEY_EQUAL == keycode:
		return OS.get_keycode_string(KEY_PLUS)
	elif KEY_APOSTROPHE == keycode:
		return OS.get_keycode_string(KEY_QUOTEDBL)
	
	return OS.get_keycode_string(keycode)

func check_input(input: InputEvent, details: Dictionary, is_inclusive_mode = false) -> bool:
	var keycode = 0
	var key = 0
	
	if input is InputEventKey:
		keycode = input.keycode
		key = get_stand_key_string(input.keycode)
			
	elif input is InputEventMouseButton:
		keycode = input.button_index
		key = OS.get_keycode_string(input.button_index)
	else:
		return false
	
	if is_inclusive_mode == true:
		#trigger any key(including modified keys) in this event
		if details.has(key):
			pass
		elif input.ctrl_pressed and details.has("Ctrl"):
			pass
		elif input.shift_pressed and details.has("Shift"):
			pass
		elif input.alt_pressed and details.has("Alt"):
			pass
		elif input.meta_pressed and details.has("Meta"):
			pass
		else:
			return false
			
		#full condition check
		if !pressed_details.has(key):
			return false
		if (keycode == KEY_CTRL or input.ctrl_pressed) and !pressed_details.has("Ctrl"):
			return false
		if (keycode == KEY_SHIFT or input.shift_pressed) and !pressed_details.has("Shift"):
			return false
		if (keycode == KEY_ALT or input.alt_pressed) and !pressed_details.has("Alt"):
			return false
		if (keycode == KEY_META or input.meta_pressed) and !pressed_details.has("Meta"):
			return false
			
		return true
	else:
		if details.has(key):
			if (keycode == KEY_CTRL or input.ctrl_pressed) != pressed_details.has("Ctrl"):
				return false
			if (keycode == KEY_SHIFT or input.shift_pressed) != pressed_details.has("Shift"):
				return false
			if (keycode == KEY_ALT or input.alt_pressed) != pressed_details.has("Alt"):
				return false
			if (keycode == KEY_META or input.meta_pressed) != pressed_details.has("Meta"):
				return false
			
			return true

	return false

func check_input_just_released(input: InputEvent, is_inclusive_mode = false) -> bool:
	var keycode = 0
	var key = 0
	var pressed_count = 0
	var just_released_count = 0
	var input_event_key_count = 1
	
	if input is InputEventKey:
		keycode = input.keycode
		key = get_stand_key_string(input.keycode)
	elif input is InputEventMouseButton:
		keycode = input.button_index
		key = input.button_index
	else:
		return false
	if pressed_details.has(key):
		pressed_count += 1
	if just_released_details.has(key):
		just_released_count += 1
		
	if input.ctrl_pressed:
		input_event_key_count += 1
		if pressed_details.has("Ctrl"):
			pressed_count += 1
		if just_released_details.has("Ctrl"):
			just_released_count += 1
	if input.shift_pressed:
		input_event_key_count += 1
		if pressed_details.has("Shift"):
			pressed_count += 1
		if just_released_details.has("Shift"):
			just_released_count += 1
	if input.alt_pressed:
		input_event_key_count += 1
		if pressed_details.has("Alt"):
			pressed_count += 1
		if just_released_details.has("Alt"):
			just_released_count += 1
	if input.meta_pressed:
		input_event_key_count += 1
		if pressed_details.has("Meta"):
			pressed_count += 1
		if just_released_details.has("Meta"):
			just_released_count += 1
	
	if just_released_count > 1 and pressed_count + just_released_count == input_event_key_count:
		return true
	
	return false

func is_input_just_pressed(input: InputEvent, is_inclusive_mode = false) -> bool:
	return check_input(input, just_pressed_details, is_inclusive_mode)
		
func is_input_just_released(input: InputEvent, is_inclusive_mode = false) -> bool:
	return check_input_just_released(input, is_inclusive_mode)
		
func is_input_pressed(input: InputEvent, is_inclusive_mode = false) -> bool:
	return check_input(input, pressed_details, is_inclusive_mode)

func is_action_input_just_pressed(action: String, is_inclusive_mode = false) -> bool:
	for action_event:InputEvent in InputMap.action_get_events(action):
		if is_input_just_pressed(action_event, is_inclusive_mode):
			return true
	
	return false
	
func is_action_input_just_released(action: String, is_inclusive_mode = false) -> bool:
	for action_event:InputEvent in InputMap.action_get_events(action):
		if is_input_just_released(action_event, is_inclusive_mode):
			return true
	
	return false

func is_action_input_pressed(action: String, is_inclusive_mode = false) -> bool:
	for action_event:InputEvent in InputMap.action_get_events(action):
		if is_input_pressed(action_event, is_inclusive_mode):
			return true
	
	return false
