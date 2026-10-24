extends Button

class_name RemapButton

@export var action: String
var state_button: Node
# Collects the inputs pressed while awaiting; a binding commits once every
# member is released (see BindingSession).
var _session := BindingSession.new()


func _init():
	toggle_mode = true
	theme_type_variation = "RemapButton"


func _ready():
	set_process_input(false)
	Global.binding_labels_changed.connect(update_key_text)
	update_key_text()


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
	# Drops the awaiting state from any entry point (owning row hidden, a click
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
		# The owning panel/row was hidden mid-await: stop swallowing input.
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
			_remap_selected_state(event)
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
	_remap_selected_state(binding["primary"], binding["members"])


func _update_preview() -> void:
	var preview := _session.preview_text()
	text = preview if not preview.is_empty() else tr("TR_AWAITING_INPUT")


## Applies a bound event to the selected state's action. Shared by the
## mouse/keyboard path and the stick path (which passes a normalised axis event).
func _remap_selected_state(event: InputEvent, members: Array = []) -> void:
	if StateButton.selected_state != null && is_instance_valid(StateButton.selected_state):
		InputMap.action_erase_events(StateButton.selected_state.input_key)
		InputMap.action_add_event(StateButton.selected_state.input_key, event)
		StateButton.selected_state.apply_binding(event, members)
		GlobInput.refresh_action_cache()

	button_pressed = false


func update_key_text():
	if StateButton.selected_state != null && is_instance_valid(StateButton.selected_state):
		if InputMap.action_get_events(StateButton.selected_state.input_key).size() != 0:
			var members: Array = StateButton.selected_state.chord_modifiers
			var bound: InputEvent = InputMap.action_get_events(StateButton.selected_state.input_key)[0]
			BindingLabel.set_button_text(self, InputDisplayName.text(bound, members), not members.is_empty())
			# Compact in the button, full aliases in the tooltip.
			tooltip_text = InputDisplayName.full_text(bound, members) if not members.is_empty() else ""
		else:
			BindingLabel.set_button_text(self, tr("TR_BIND_KEY"), false)
			tooltip_text = ""


func update_stuff():
	if StateButton.selected_state != null && is_instance_valid(StateButton.selected_state):
		InputMap.action_erase_events(StateButton.selected_state.input_key)
		InputMap.action_add_event(StateButton.selected_state.input_key, state_button.saved_event)
	update_key_text()


func _on_remove_pressed():
	if StateButton.selected_state != null && is_instance_valid(StateButton.selected_state):
		if InputMap.action_get_events(StateButton.selected_state.input_key).size() != 0:
			InputMap.action_erase_events(StateButton.selected_state.input_key)
			StateButton.selected_state.apply_binding(null)
			update_key_text()
