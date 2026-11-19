extends Control

var _quit_prompt_open := false

func _ready() -> void:
	# The close request is answered by the unsaved guard, so the engine must not
	# accept the quit on its own before the dialog can answer.
	get_tree().auto_accept_quit = false
	Global.swtich_session_popup = %MenuScreenPopup
	await get_tree().create_timer(0.1).timeout
	# Build the prompt now, while the tree is idle: a close notification blocks
	# add_child(), so the first quit would otherwise get no dialog.
	UnsavedGuard.prepare()
	#init_switch_session()
	Global.diag_trace("ready:auto_load_model enter")
	auto_load_model()
	Global.diag_trace("ready:auto_load_model exit")
	if Global.has_diag_flag("no-gihook"):
		print("[diag] GlobInput hook disabled by --no-gihook")
	else:
		Global.diag_phase("gi_start_hook")
		Global.diag_trace("ready:gi_start_hook enter")
		GlobInput.start_hook()
		Global.diag_trace("ready:gi_start_hook exit")
		Global.diag_phase("")
	Global.diag_phase("update_tracking_backend")
	Global.diag_trace("ready:update_tracking_backend enter")
	Settings.update_tracking_backend()
	Global.diag_trace("ready:update_tracking_backend exit")
	Global.diag_phase("")

func init_switch_session():
	if Settings.theme_settings.session == 1:
		Global.new_file.emit()
		for i in %Scene.get_children():
			i.queue_free()
		%Scene.add_child(%MenuScreenPopup.streamer_mode.instantiate())

func auto_load_model():
	if Settings.theme_settings.auto_load:
		if FileAccess.file_exists(Settings.theme_settings.path):
			await get_tree().create_timer(0.1).timeout
			SaveAndLoad.load_file(Settings.theme_settings.path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()

func _request_quit() -> void:
	if _quit_prompt_open:
		# A second close request must not stack another dialog; bring the
		# existing one back to the front instead.
		UnsavedGuard.raise_dialog()
		return
	_quit_prompt_open = UnsavedGuard.request(UnsavedDialog.Ask.QUIT, _quit_now, _on_quit_cancelled)

func _on_quit_cancelled() -> void:
	_quit_prompt_open = false

func _quit_now() -> void:
	# Reset first: if the process somehow survives the quit below, the next close
	# request has to be able to raise a dialog instead of being swallowed.
	_quit_prompt_open = false
	# This path is what a user hits when the window is stuck: the trace tells
	# us whether stop_hook() is where it never returns.
	Global.diag_trace("close:stop_hook enter")
	GlobInput.stop_hook()
	Global.diag_trace("close:stop_hook exit")
	get_tree().quit()
	OS.kill(OS.get_process_id())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("save"):
		if Global.save_path:
			SaveAndLoad.save_file(Global.save_path)
		elif Global.main != null and Global.main.has_method("save_as_file"):
			# The streamer scene has no save UI at all, so a demo model opened
			# there must not reach a missing method through Ctrl+S.
			Global.main.save_as_file()
	if event.is_action_pressed("desel"):
		Global.deselect.emit()
