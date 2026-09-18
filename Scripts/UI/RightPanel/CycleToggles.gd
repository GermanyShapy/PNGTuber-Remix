extends Button


func _ready():
	set_process_input(false)
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
	# Guard the index: selected id 0 ("None") would otherwise wrap to -1 and
	# silently overwrite the LAST cycle's binding.
	var cycle_id: int = %CycleChoice.get_selected_id() - 1
	if cycle_id >= 0 and cycle_id < Global.settings_dict.cycles.size():
		Global.settings_dict.cycles[cycle_id].toggle = event.duplicate()
	update_key_text()
	button_pressed = false

func update_key_text():
	if %CycleChoice.get_selected_id() > 0:
		if Global.settings_dict.cycles[%CycleChoice.get_selected_id()-1].toggle != null:
			self.text = InputDisplayName.text(Global.settings_dict.cycles[%CycleChoice.get_selected_id()-1].toggle)
		else:
			self.text = tr("TR_BIND_KEY")
	else:
		self.text = tr("TR_BIND_KEY")

func _on_cycle_del_pressed() -> void:
	if %CycleChoice.get_selected_id() > 0:
		Global.settings_dict.cycles[%CycleChoice.get_selected_id()-1].toggle = null
	update_key_text()
