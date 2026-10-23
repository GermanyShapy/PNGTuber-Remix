extends Node

var devices : Array = []
var change_setting : bool = false
var counter : int = 0

func _ready() -> void:
	%UIThemeButton.item_selected.connect(Settings._on_ui_theme_button_item_selected)
	%UIThemeButton.select(Settings.theme_settings.theme_id)
	%MicroPhoneMenu.get_popup().connect("id_pressed",choosing_device)
	_populate_languages()
	LanguageManager.language_changed.connect(_on_language_changed)
	get_parent().close_requested.connect(close)
	sliders_revalue(Global.settings_dict)
	devices = GlobalMicAudio.mic_input.get_device_names()
	for i in devices:
		%MicroPhoneMenu.get_popup().add_item(i)
		if i == Settings.theme_settings.microphone:
			%MicroPhoneMenu.select(devices.find(i))
	%SelectedScreen.add_item("All Screens")
	for i in DisplayServer.get_screen_count():
		%SelectedScreen.add_item("Screen " + str(i))
	if Global.settings_dict.monitor == Monitor.ALL_SCREENS:
		%SelectedScreen.select(0)
	else:
		if %SelectedScreen.item_count > Global.settings_dict.monitor:
			%SelectedScreen.select(Global.settings_dict.monitor + 1)
		else:
			Global.settings_dict.monitor = Monitor.ALL_SCREENS
			%SelectedScreen.select(0)
	check_data()
	_build_gamepad_label_option()
	init_hotkey_list()

func _populate_languages() -> void:
	%LanguageOptions.clear()
	var selected_index := 0
	for index in LanguageManager.available_languages.size():
		var locale_code: String = LanguageManager.available_languages[index]
		%LanguageOptions.add_item(LanguageManager.get_display_name(locale_code))
		if locale_code == LanguageManager.get_current_locale():
			selected_index = index
	%LanguageOptions.select(selected_index)

func _on_remix_language_set(index: int) -> void:
	if index < 0 or index >= LanguageManager.available_languages.size():
		return
	LanguageManager.set_language(LanguageManager.available_languages[index])
	
func _on_language_changed(_locale: String) -> void:
	_populate_languages()
	_localize_gamepad_label_option()


# --- Gamepad label style -----------------------------------------------------
#
# Built at runtime instead of living in the scene: it is one label plus one
# dropdown, and adding them here keeps the popup's .tscn untouched. The choice
# is stored in Global.settings_dict, so it is written into the model and loaded
# back with it.

const GAMEPAD_LABEL_OPTIONS: Array = [
	{"id": 0, "text": "TR_GAMEPAD_LABELS_ALL"},
	{"id": 1, "text": "TR_GAMEPAD_LABELS_XB"},
	{"id": 2, "text": "TR_GAMEPAD_LABELS_PS"},
	{"id": 3, "text": "TR_GAMEPAD_LABELS_NS"},
]

var _gamepad_label_title: Label
var _gamepad_label_option: OptionButton


func _build_gamepad_label_option() -> void:
	if _gamepad_label_option != null:
		return
	var grid: GridContainer = %MaxFPS.get_parent()
	_gamepad_label_title = Label.new()
	_gamepad_label_title.name = "GamepadLabelsLabel"
	_gamepad_label_title.custom_minimum_size = Vector2(144, 0)
	_gamepad_label_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gamepad_label_option = OptionButton.new()
	_gamepad_label_option.name = "GamepadLabelsOption"
	_gamepad_label_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_gamepad_label_title)
	grid.add_child(_gamepad_label_option)
	_gamepad_label_option.item_selected.connect(_on_gamepad_label_selected)
	_localize_gamepad_label_option()
	gamepad_label_select(int(Global.settings_dict.get("gamepad_labels", 0)))


func _localize_gamepad_label_option() -> void:
	if _gamepad_label_option == null:
		return
	_gamepad_label_title.text = tr("TR_GAMEPAD_LABELS")
	_gamepad_label_title.tooltip_text = tr("TR_GAMEPAD_LABELS_TOOLTIP")
	var current := _gamepad_label_option.get_selected_id()
	_gamepad_label_option.clear()
	for option in GAMEPAD_LABEL_OPTIONS:
		_gamepad_label_option.add_item(tr(option["text"]), int(option["id"]))
	gamepad_label_select(current)


## Selects by the *stored value* (item id), never by index: the ids are what the
## save file holds, and the ones already published must stay put.
func gamepad_label_select(style_id: int) -> void:
	if _gamepad_label_option == null:
		return
	var idx := _gamepad_label_option.get_item_index(style_id)
	_gamepad_label_option.select(idx if idx >= 0 else 0)


func _on_gamepad_label_selected(index: int) -> void:
	Global.settings_dict["gamepad_labels"] = _gamepad_label_option.get_item_id(index)
	# Every binding label is written imperatively (vendor choice, chord members),
	# so nothing re-derives it on its own: let the widgets that draw one repaint.
	Global.binding_labels_changed.emit()

func close():
	get_parent().queue_free()

func check_data():
	change_setting = false
	# Null until _build_gamepad_label_option() has run; the build syncs it itself.
	gamepad_label_select(int(Global.settings_dict.get("gamepad_labels", 0)))
	%AutoLoadCheck.button_pressed = Settings.theme_settings.auto_load
	%SaveOnExitCheck.button_pressed = Settings.theme_settings.save_on_exit
	%AutoSaveCheck.button_pressed = Global.settings_dict.auto_save
	%ImportTrim.button_pressed = Settings.theme_settings.enable_trimmer
	%UIScalingSpinBox.value = Settings.theme_settings.ui_scaling
	%CustomCursorEditor.button_pressed = Settings.theme_settings.custom_cursor_editor
	%CustomCursorPreview.button_pressed = Settings.theme_settings.custom_cursor_preview
	%FloatyPanning.button_pressed = Settings.theme_settings.floaty_panning
	#%UseThreads.button_pressed = Settings.theme_settings.use_threading
	%KeepOldTrimData.button_pressed = Settings.theme_settings.save_raw_sprite
	%SaveUnusedImages.button_pressed = Settings.theme_settings.save_unused_files
	%PhysicsTick.value = Settings.theme_settings.phys_tick_per_frame
	%PhysicsSteps.value = Settings.theme_settings.phys_steps
	%JitterFix.value = Settings.theme_settings.phys_jitter
	%DevMode.button_pressed = Settings.theme_settings.dev_mode
	%FollowMouseGlobalInput.button_pressed = Settings.theme_settings.use_glob_input

	if OS.has_feature("windows"):
		%BackendOption.set_item_disabled(0, false)
		%BackendOption.set_item_disabled(1, true)
	elif OS.has_feature("linux"):
		%BackendOption.set_item_disabled(1, false)
		%BackendOption.set_item_disabled(0, true)
	else:
		%BackendOption.set_item_disabled(0, true)
		%BackendOption.set_item_disabled(1, true)
		%BackendOption.select(2)

	match Settings.theme_settings.backend_type:
		"windows":
			if OS.has_feature("windows"):
				%BackendOption.select(0)
			else:
				%BackendOption.set_item_disabled(0, true)
				%BackendOption.select(2)
		"x11":
			if OS.has_feature("linux"):
				%BackendOption.select(1)
			else:
				%BackendOption.set_item_disabled(1, true)
				%BackendOption.select(2)
		"dummy":
			%BackendOption.select(2)
		_:
			%BackendOption.select(2)

	change_setting = true

## One row per distinct binding, stored as {"event": InputEvent, "members": Array}.
## A chord is a primary event plus its member set, so identity can no longer be
## "primary event only": LB and LB+B would collapse into one row, and the
## surviving row could neither display nor address the chord (the settings list
## re-scans every binding when it opens).
func append_unique_hotkey_to_dict(hotkey_event: InputEvent, dict: Dictionary, members: Array = []):
	if hotkey_event == null:
		return
	for hotkey_name in dict:
		var entry: Dictionary = dict[hotkey_name]
		if CustomHotkeyMapButton.is_same_binding(entry["event"], entry["members"], hotkey_event, members):
			return
	dict[_binding_name(hotkey_event, members)] = {
		"event": hotkey_event.duplicate(),
		"members": members.duplicate(true),
	}


## Name of a binding row. Built from `as_text()` on purpose: the name is the key
## of a persisted dictionary, so it must not depend on the UI language or on
## which controller happens to be connected.
func _binding_name(hotkey_event: InputEvent, members: Array) -> String:
	var parts: PackedStringArray = []
	for m in members:
		parts.append(_stable_name(m as InputEvent))
	parts.append(_stable_name(hotkey_event))
	var base := " + ".join(parts)
	var name := base
	var suffix := 2
	while Global.settings_dict.custom_hotkeys.has(name):
		name = "%s (%d)" % [base, suffix]
		suffix += 1
	return name


## `as_text()` on a joypad button appends the whole vendor alias list
## ("Joypad Button 9 (Left Shoulder, Sony L1, Xbox LB)"). That is noise in a name
## field, and two members made the row unreadable -- drop the parenthesised part.
## The number that identifies the button is always outside it.
func _stable_name(p_event: InputEvent) -> String:
	var raw := p_event.as_text() if p_event != null else ""
	var cut := raw.find(" (")
	return raw if cut < 0 else raw.substr(0, cut)


func init_hotkey_list():
	# This list can be built before any model is loaded, so the chord table may
	# not exist yet (it is normally created by the binding widgets / on load).
	if not Global.settings_dict.has("custom_hotkey_chords"):
		Global.settings_dict["custom_hotkey_chords"] = {}
	#Search all states and sprites
	var state_buttons = get_tree().get_nodes_in_group("StateButtons")
	var sprites = get_tree().get_nodes_in_group("Sprites")
	var hotkey_dict: Dictionary = {}
	
	for state_btn: StateButton in state_buttons:
		append_unique_hotkey_to_dict(state_btn.saved_event, hotkey_dict, state_btn.chord_modifiers)
		
	for sprite: SpriteObject in sprites:
		append_unique_hotkey_to_dict(sprite.saved_event, hotkey_dict, sprite.chord_modifiers)

		if InputMap.has_action(sprite.disappear_keys): #disappear keys
			var dis_action_events = InputMap.action_get_events(sprite.disappear_keys)
			for id in dis_action_events.size():
				var dis_members: Array = sprite.disappear_chords[id] if id < sprite.disappear_chords.size() else []
				append_unique_hotkey_to_dict(dis_action_events[id], hotkey_dict, dis_members)
	
	for cycle in Global.settings_dict.cycles:
		append_unique_hotkey_to_dict(cycle.toggle, hotkey_dict, cycle.get("toggle_chord", []))
		append_unique_hotkey_to_dict(cycle.forward, hotkey_dict, cycle.get("forward_chord", []))
		append_unique_hotkey_to_dict(cycle.backward, hotkey_dict, cycle.get("backward_chord", []))

	#Get intersection of scaned hotkeys and global hotkeys
	#New hotkeys will be added, named by its event
	#Unexisting global hotkeys will be removed
	for hotkey_name in hotkey_dict:
		var entry: Dictionary = hotkey_dict[hotkey_name]
		var is_diffent = true
		for existing_name in Global.settings_dict.custom_hotkeys:
			var existing_members: Array = Global.settings_dict.custom_hotkey_chords.get(existing_name, [])
			if CustomHotkeyMapButton.is_same_binding(Global.settings_dict.custom_hotkeys[existing_name], existing_members, entry["event"], entry["members"]):
				is_diffent = false
				break
		
		if is_diffent:
			Global.settings_dict.custom_hotkeys[hotkey_name] = entry["event"]
			# The member set travels with the name: without it the row displays
			# the primary only and matches no binding at all.
			Global.settings_dict.custom_hotkey_chords[hotkey_name] = entry["members"]
	
	var union_hotkeys = (Global.settings_dict.custom_hotkeys as Dictionary).duplicate()
	for hotkey_name in union_hotkeys:
		var is_diffent = true
		var union_members: Array = Global.settings_dict.custom_hotkey_chords.get(hotkey_name, [])
		for scanned_name in hotkey_dict:
			var entry: Dictionary = hotkey_dict[scanned_name]
			if CustomHotkeyMapButton.is_same_binding(union_hotkeys[hotkey_name], union_members, entry["event"], entry["members"]):
				is_diffent = false
				break
		
		if is_diffent:
			Global.settings_dict.custom_hotkeys.erase(hotkey_name)
			Global.settings_dict.custom_hotkey_chords.erase(hotkey_name)

	# Drops member sets orphaned by older builds / hand-edited settings: the
	# table is keyed by hotkey name, so a name that no longer exists is dead.
	for chord_name in (Global.settings_dict.custom_hotkey_chords as Dictionary).duplicate():
		if not Global.settings_dict.custom_hotkeys.has(chord_name):
			Global.settings_dict.custom_hotkey_chords.erase(chord_name)
			
	Global.settings_dict.custom_hotkeys.sort()
	#####################
	#Create Items
	for hotkey_name in Global.settings_dict.custom_hotkeys:
		var new_item = preload("res://UI/EditorUI/TopUI/Components/hotkey_item.tscn").instantiate()
		var btn = new_item.get_node("%CustomHotkeyMapButton") as CustomHotkeyMapButton
		btn.hotkey_name = hotkey_name
		btn.hotkey_event = (Global.settings_dict.custom_hotkeys[hotkey_name] as InputEvent).duplicate()
		%HotkeyItemList.add_child(new_item)

func _physics_process(_delta):
	%VolumeBar.value = GlobalMicAudio.volume
	%DelayBar.value = GlobalMicAudio.delay

func sliders_revalue(settings_dict):
	%InputCheckButton.button_pressed = settings_dict.checkinput
	%VolumeSlider.value = settings_dict.volume_limit
	%SensitivitySlider.value = settings_dict.sensitivity_limit
	%AntiAlCheck.button_pressed = settings_dict.anti_alias
#	$TopBarInput.origin_alias()
	%AutoSaveCheck.button_pressed = settings_dict.auto_save
	%AutoSaveSpin.value = settings_dict.auto_save_timer
	%DelaySlider.value = settings_dict.volume_delay
	%DeltaTimeCheck.button_pressed = settings_dict.should_delta
	#%MaxFPSlider.value = settings_dict.max_fps
	match_fps(settings_dict.max_fps)
	
	%OutOfBounds.button_pressed = settings_dict.snap_out_of_bounds

func _on_volume_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Global.settings_dict.volume_limit = %VolumeSlider.value

func _on_delay_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Global.settings_dict.volume_delay = %DelaySlider.value

func _on_sensitivity_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Global.settings_dict.sensitivity_limit = %SensitivitySlider.value

func _on_sensitivity_slider_value_changed(value: float) -> void:
	%SensitivityBar.value = value

func _on_auto_load_check_toggled(toggled_on: bool) -> void:
	Settings.theme_settings.auto_load = toggled_on
	Settings.save()

func _on_save_on_exit_check_toggled(toggled_on: bool) -> void:
	Settings.theme_settings.save_on_exit = toggled_on
	Settings.save()

func _on_delta_time_check_toggled(toggled_on: bool) -> void:
	Global.settings_dict.should_delta = toggled_on

func _on_auto_save_spin_value_changed(value):
	Global.settings_dict.auto_save_timer = value
	Settings.setup_auto_save()

func choosing_device(id):
	if id != null:
		if GlobalMicAudio.mic_input.get_device_names().has(devices[id]):
			GlobalMicAudio.mic_input.set_microphone(id)
			GlobalMicAudio.mic_input.start_audio()
			Settings.theme_settings.microphone = devices[id]
			Settings.save()
	else:
		reset_mic_list()

func _on_reset_mic_button_pressed():
	reset_mic_list()

func reset_mic_list():
	%MicroPhoneMenu.get_popup().clear()
	devices = GlobalMicAudio.mic_input.get_device_names()
	for i in devices:
		%MicroPhoneMenu.get_popup().add_item(i)
	choosing_device(0)

func _on_anti_al_check_toggled(toggled_on):
	Global.settings_dict.anti_alias = toggled_on
	if toggled_on:
		Global.sprite_container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		Global.sprite_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

func _on_input_check_button_toggled(toggled_on):
	Global.settings_dict.checkinput = toggled_on

func _on_auto_save_check_toggled(toggled_on):
	Global.settings_dict.auto_save = toggled_on
	Settings.setup_auto_save()

func _on_import_trim_toggled(toggled_on: bool) -> void:
	Settings.theme_settings.enable_trimmer = toggled_on
	Settings.save()

func _on_selected_screen_item_selected(index: int) -> void:
	if index == 0:
		Global.main.get_node("%Marker").current_screen = Monitor.ALL_SCREENS
	else:
		Global.main.get_node("%Marker").current_screen = index - 1
	Global.settings_dict.monitor = Global.main.get_node("%Marker").current_screen
	print(Global.settings_dict.monitor)

func _on_ui_scaling_slider_value_changed(value: float) -> void:
	if change_setting:
		Settings.theme_settings.ui_scaling = value
		Settings.scale_window()
		Settings.save()
		%UIScalingSpinBox.value = value
		get_parent().move_to_center()

func _on_ui_scaling_spin_box_value_changed(value: float) -> void:
	if change_setting:
		Settings.theme_settings.ui_scaling = value
		Settings.scale_window()
		Settings.save()
		get_parent().move_to_center()

func cursor_changed():
	Settings.change_cursor()
	Settings.save()

func _on_custom_cursor_editor_toggled(toggled_on: bool) -> void:
	if !change_setting: return
	Settings.theme_settings.custom_cursor_editor = toggled_on
	cursor_changed()
	Settings.save()

func _on_custom_cursor_preview_toggled(toggled_on: bool) -> void:
	if !change_setting: return
	Settings.theme_settings.custom_cursor_preview = toggled_on
	cursor_changed()
	Settings.save()

func _on_select_cursor_file_selected(path: String) -> void:
	if !change_setting: return
	Settings.theme_settings.custom_cursor_path = path
	cursor_changed()
	Settings.save()

func _on_remove_custom_cursor_pressed() -> void:
	if !change_setting: return
	Settings.theme_settings.custom_cursor_path = ""
	cursor_changed()
	Settings.save()

func _on_floaty_panning_toggled(toggled_on: bool) -> void:
	if !change_setting: return
	Settings.theme_settings.floaty_panning = toggled_on
	Settings.save()
	Global.update_camera_smoothing()

func _on_use_threads_toggled(_toggled_on: bool) -> void:
	if !change_setting: return
	Settings.theme_settings.use_threading = false
	Settings.save()

func _on_keep_old_trim_data_toggled(toggled_on: bool) -> void:
	Settings.theme_settings.save_raw_sprite = toggled_on
	Settings.save()

func _on_out_of_bounds_toggled(toggled_on: bool) -> void:
	Global.settings_dict.snap_out_of_bounds = toggled_on

func _on_save_unused_images_toggled(toggled_on: bool) -> void:
	Settings.theme_settings.save_unused_files = toggled_on
	Settings.save()

func _on_backend_option_item_selected(index: int) -> void:
	match index:
		0:
			Settings.theme_settings.backend_type = "windows"
		1:
			Settings.theme_settings.backend_type = "x11"
		2:
			Settings.theme_settings.backend_type = "dummy"
	Settings.save()
	Settings.update_tracking_backend()

func _on_physics_tick_value_changed(value: float) -> void:
	if !change_setting: return
	Settings.theme_settings.phys_tick_per_frame = value
	Engine.physics_ticks_per_second = int(value)
	Settings.save()

func _on_physics_steps_value_changed(value: float) -> void:
	if !change_setting: return
	Settings.theme_settings.phys_steps = value
	Engine.max_physics_steps_per_frame = int(value)
	Settings.save()

func _on_jitter_fix_drag_ended(value_changed: bool) -> void:
	if !change_setting: return
	if !value_changed: return
	Settings.theme_settings.phys_jitter = %JitterFix.value
	Engine.physics_jitter_fix = %JitterFix.value
	Settings.save()

func _on_pickles_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("lmb"):
		counter += 1
		check_dev_mode()

func check_dev_mode():
	if counter >= 10:
		%DevMode.show()
		%DevWarning.show()

func _on_dev_mode_toggled(toggled_on: bool) -> void:
	if change_setting:
		Settings.theme_settings.dev_mode = toggled_on
		Global.dev_mode.emit(Settings.theme_settings.dev_mode)
		Settings.save()

func _on_follow_mouse_global_input_toggled(toggled_on: bool) -> void:
	if change_setting:
		Settings.theme_settings.use_glob_input = toggled_on
		Settings.save()

func _on_max_fps_item_selected(index: int) -> void:
	match index:
		0:
			Global.settings_dict.max_fps = 8
		1:
			Global.settings_dict.max_fps = 10
		2:
			Global.settings_dict.max_fps = 12
		3:
			Global.settings_dict.max_fps = 15
		4:
			Global.settings_dict.max_fps = 30
		5:
			Global.settings_dict.max_fps = 60
		6:
			Global.settings_dict.max_fps = 90
		7:
			Global.settings_dict.max_fps = 120
		8:
			Global.settings_dict.max_fps = 240
	
	Engine.max_fps = Global.settings_dict.max_fps

func match_fps(fps):
	match fps:
		8:
			%MaxFPS.select(0)
		10:
			%MaxFPS.select(1)
		12:
			%MaxFPS.select(2)
		15:
			%MaxFPS.select(3)
		30:
			%MaxFPS.select(4)
		60:
			%MaxFPS.select(5)
		90:
			%MaxFPS.select(6)
		120:
			%MaxFPS.select(7)
		240:
			%MaxFPS.select(8)
		0:
			Global.settings_dict.max_fps = 240
			Engine.max_fps = Global.settings_dict.max_fps
			%MaxFPS.select(8)
		_:
			Global.settings_dict.max_fps = 60
			Engine.max_fps = Global.settings_dict.max_fps
			%MaxFPS.select(5)
