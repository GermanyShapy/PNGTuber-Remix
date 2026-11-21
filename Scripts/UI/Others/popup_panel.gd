extends ConfirmationDialog
class_name UnsavedDialog

## Shared "you have unsaved edits" prompt. Two things decide its shape:
## the confirm button names the action it lets through, and the wording of the
## body depends on what the last save point actually was.

enum Ask { OPEN, QUIT }

var _kind: int = Ask.OPEN
var _action: Callable = Callable()
var _on_cancel: Callable = Callable()
var _fired: bool = false
var _save_failed: bool = false


func _ready() -> void:
	confirmed.connect(_confirm)
	canceled.connect(_cancel)
	close_requested.connect(_cancel)
	# The light themes paint button labels dark on a mid-grey face, which makes
	# these two read as form controls instead of actions. White at rest matches
	# the focus colour, so the label no longer changes when the button is picked.
	for button in [get_ok_button(), get_cancel_button()]:
		button.add_theme_color_override("font_color", Color.WHITE)


func ask(p_kind: int, p_action: Callable, p_on_cancel: Callable = Callable()) -> void:
	_kind = p_kind
	_action = p_action
	_on_cancel = p_on_cancel
	_fired = false
	_save_failed = false

	theme = Settings.current_theme
	title = _t("TR_UNSAVED_TITLE")
	dialog_text = _body()
	cancel_button_text = _t("TR_BACK_TO_CHECK")
	if p_kind == Ask.QUIT:
		# The confirm button states what actually happens, so "save on exit"
		# never turns a quit into a silent save the user did not read.
		ok_button_text = _t("TR_SAVE_AND_QUIT") if Settings.theme_settings.save_on_exit else _t("TR_QUIT_NOW")
	else:
		ok_button_text = _t("TR_OPEN_NEW_MODEL")

	# Long Russian or English text must not be clipped by the fixed size. The
	# height floor covers headless runs, where the wrapped label measures as one
	# line and would otherwise leave no room for the second paragraph.
	reset_size()
	size.y = maxi(size.y, 190)
	popup_centered()
	# Back is the safe default: Enter and Esc must not discard work.
	get_cancel_button().grab_focus()


func _t(p_key: String) -> String:
	var out := TranslationServer.translate(p_key)
	return out if not out.is_empty() else p_key


func _body() -> String:
	var head := _t("TR_UNSAVED_OPEN_TEXT") if _kind == Ask.OPEN else _t("TR_UNSAVED_QUIT_TEXT")
	var tail := ""
	var just_now := Time.get_ticks_msec() - SaveAndLoad.baseline_ms < 1000
	match SaveAndLoad.baseline_kind:
		SaveAndLoad.BaselineKind.SAVED:
			# A whole sentence for the first second: "just now" does not fit a
			# pattern that already carries "ago" in every language.
			tail = _t("TR_UNSAVED_SINCE_SAVE_JUST") if just_now else _with_elapsed("TR_UNSAVED_SINCE_SAVE")
		SaveAndLoad.BaselineKind.LOADED:
			tail = _t("TR_UNSAVED_SINCE_OPEN_JUST") if just_now else _with_elapsed("TR_UNSAVED_SINCE_OPEN")
		_:
			tail = _t("TR_UNSAVED_NEVER_SAVED")
	return "%s\n\n%s" % [head, tail]


## A translation that lost its placeholder would make "%" throw, so fall back
## to the plain line: a missing stub is not worth a broken dialog.
func _with_elapsed(p_key: String) -> String:
	var pattern := _t(p_key)
	if not pattern.contains("%"):
		return pattern
	return pattern % _elapsed()


func _elapsed() -> String:
	var ms := Time.get_ticks_msec() - SaveAndLoad.baseline_ms
	if ms < 1000:
		return _t("TR_UNSAVED_JUST_NOW")
	var secs := int(ms / 1000)
	if secs < 60:
		return "%d %s" % [secs, _t("TR_UNIT_SEC")]
	var mins := int(secs / 60)
	if mins < 60:
		var rest_secs := secs % 60
		if rest_secs == 0:
			return "%d %s" % [mins, _t("TR_UNIT_MIN")]
		return "%d %s %d %s" % [mins, _t("TR_UNIT_MIN"), rest_secs, _t("TR_UNIT_SEC")]
	var hours := int(mins / 60)
	var rest_mins := mins % 60
	if rest_mins == 0:
		return "%d %s" % [hours, _t("TR_UNIT_HOUR")]
	return "%d %s %d %s" % [hours, _t("TR_UNIT_HOUR"), rest_mins, _t("TR_UNIT_MIN")]


func _confirm() -> void:
	if _fired:
		return
	# "Save and quit" must not quit on top of a failed write, that is the exact
	# loss this dialog exists to prevent. Keep the prompt open, say so, and let
	# the next click fall through to a plain quit.
	if _kind == Ask.QUIT and Settings.theme_settings.save_on_exit and not _save_failed:
		if not Settings.save_model_for_quit():
			_save_failed = true
			dialog_text = _t("TR_UNSAVED_SAVE_FAILED")
			ok_button_text = _t("TR_QUIT_NOW")
			return
	_fired = true
	# dialog_hide_on_ok is off, because AcceptDialog hides itself before it
	# emits confirmed, which would close the prompt before a failed save could
	# report anything. Hiding here keeps that order under our control.
	hide()
	var cb := _action
	_action = Callable()
	_on_cancel = Callable()
	if cb.is_valid():
		cb.call()


func _cancel() -> void:
	if _fired:
		return
	_fired = true
	hide()
	var cb := _on_cancel
	_action = Callable()
	_on_cancel = Callable()
	if cb.is_valid():
		cb.call()
