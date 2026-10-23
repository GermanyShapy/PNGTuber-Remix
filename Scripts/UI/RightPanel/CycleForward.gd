extends Button

# Collects the inputs pressed while awaiting; a binding commits once every
# member is released (see BindingSession).
var _session := BindingSession.new()


func _ready():
	set_process_input(false)
	# Vendor-label style is a setting: re-derive our own text when it changes.
	Global.binding_labels_changed.connect(update_key_text)
	update_key_text()

func _toggled(toggle):
	set_process_input(toggle)
	if toggle:
		text = tr("TR_AWAITING_INPUT")
		release_focus()
		MouseCaptureArea.show_for(self)
	else:
		# Never re-grab focus: a focused toggle Button swallows the next
		# ui_accept and silently re-arms this widget.
		update_key_text()
		release_focus()
		MouseCaptureArea.hide_for(self)
		

func cancel_await() -> void:
	# Drops the awaiting state from any entry point (cycle row hidden, a click
	# outside the capture pad, ...) without relying on the toggled() gate.
	set_process_input(false)
	MouseCaptureArea.hide_for(self)
	if button_pressed:
		button_pressed = false
	else:
		update_key_text()


func _input(event):
	if not is_visible_in_tree():
		# The cycle row was hidden (no cycle selected / deselected): stop
		# swallowing input and drop the await.
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
			# A modifier is part of the key event itself: it never joins a chord,
			# and it cancels whatever chord was being built (D4).
			if BindingSession.is_modifier_event(event) or BindingSession.has_modifier(event):
				_session.clear()
				return
			_session.press(event)
			_update_preview()
			return
		if _session.is_empty() or BindingSession.has_modifier(event):
			_session.clear()
			_commit_binding(event)
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
	_commit_binding(binding["primary"], binding["members"])


func _update_preview() -> void:
	var preview := _session.preview_text()
	text = preview if not preview.is_empty() else tr("TR_AWAITING_INPUT")


func _commit_binding(event: InputEvent, members: Array = []) -> void:
	# Guard the index: selected id 0 ("None") would otherwise wrap to -1 and
	# silently overwrite the LAST cycle's binding.
	var cycle_id: int = %CycleChoice.get_selected_id() - 1
	if cycle_id >= 0 and cycle_id < Global.settings_dict.cycles.size():
		Global.settings_dict.cycles[cycle_id].forward = event.duplicate()
		Global.settings_dict.cycles[cycle_id]["forward_chord"] = members.duplicate(true)
	GlobInput.refresh_action_cache()
	update_key_text()
	button_pressed = false

func update_key_text():
	if %CycleChoice.get_selected_id() > 0:
		if Global.settings_dict.cycles[%CycleChoice.get_selected_id()-1].forward != null:
			var cyc = Global.settings_dict.cycles[%CycleChoice.get_selected_id()-1]
			var members: Array = cyc.get("forward_chord", [])
			BindingLabel.set_button_text(self, InputDisplayName.text(cyc.forward, members), not members.is_empty())
			# Compact in the button, full aliases in the tooltip.
			tooltip_text = InputDisplayName.full_text(cyc.forward, members) if not members.is_empty() else ""
		else:
			BindingLabel.set_button_text(self, tr("TR_BIND_KEY"), false)
			tooltip_text = ""
	else:
		BindingLabel.set_button_text(self, tr("TR_BIND_KEY"), false)
		tooltip_text = ""

func _on_cycle_del_pressed() -> void:
	if %CycleChoice.get_selected_id() > 0:
		Global.settings_dict.cycles[%CycleChoice.get_selected_id()-1].forward = null
		Global.settings_dict.cycles[%CycleChoice.get_selected_id()-1]["forward_chord"] = []
	update_key_text()
