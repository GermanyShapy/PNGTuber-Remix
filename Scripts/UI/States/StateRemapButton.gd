extends Button

class_name RemapButton

@export var action: String
var state_button: Node


func _init():
	toggle_mode = true
	theme_type_variation = "RemapButton"


func _ready():
	set_process_input(false)
	update_key_text()


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
	# Drops the awaiting state from any entry point (owning row hidden, a click
	# outside the capture pad, ...) without relying on the toggled() gate.
	set_process_input(false)
	MouseCaptureArea.hide_for(self)
	if button_pressed:
		button_pressed = false
	else:
		update_key_text()


func _input(event):
	if not is_visible_in_tree():
		# The owning panel/row was hidden mid-await: stop swallowing input.
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
		_remap_selected_state(GlobInput.normalize_joy_event(event))
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
	_remap_selected_state(event)


## Applies a bound event to the selected state's action. Shared by the
## mouse/keyboard path and the stick path (which passes a normalised axis event).
func _remap_selected_state(event: InputEvent) -> void:
	if StateButton.selected_state != null && is_instance_valid(StateButton.selected_state):
		InputMap.action_erase_events(StateButton.selected_state.input_key)
		InputMap.action_add_event(StateButton.selected_state.input_key, event)
		StateButton.selected_state.saved_event = event

	button_pressed = false


func update_key_text():
	if StateButton.selected_state != null && is_instance_valid(StateButton.selected_state):
		if InputMap.action_get_events(StateButton.selected_state.input_key).size() != 0:
			text = InputDisplayName.text(InputMap.action_get_events(StateButton.selected_state.input_key)[0])
		else:
			text = "Null"


func update_stuff():
	if StateButton.selected_state != null && is_instance_valid(StateButton.selected_state):
		InputMap.action_erase_events(StateButton.selected_state.input_key)
		InputMap.action_add_event(StateButton.selected_state.input_key, state_button.saved_event)
	update_key_text()


func _on_remove_pressed():
	if StateButton.selected_state != null && is_instance_valid(StateButton.selected_state):
		if InputMap.action_get_events(StateButton.selected_state.input_key).size() != 0:
			InputMap.action_erase_events(StateButton.selected_state.input_key)
			StateButton.selected_state.saved_event = null
			update_key_text()
