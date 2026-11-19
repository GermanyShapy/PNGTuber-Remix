extends RefCounted
class_name UnsavedGuard

## Single gate in front of anything that would replace or discard the model.
## request() returns whether a prompt was shown, so callers can debounce repeat
## requests: a second window close while the prompt is open must not stack
## dialogs on top of each other.

const DIALOG_SCENE := "res://UI/EditorUI/TopUI/Components/popup_panel.tscn"

static var _dialog: UnsavedDialog = null


## Builds the prompt ahead of time. Creating it inside a close notification does
## not work: the tree blocks add_child() while notifications propagate, and the
## dialog would end up without a parent.
static func prepare() -> void:
	_ensure_dialog()


## Runs p_action now when nothing is at risk, otherwise asks first. The action
## only ever runs from the confirm branch, which is what keeps a dismissed
## dialog from losing work.
static func request(p_kind: int, p_action: Callable, p_on_cancel: Callable = Callable()) -> bool:
	if not SaveAndLoad.is_dirty():
		p_action.call()
		return false
	var dialog := _ensure_dialog()
	if dialog == null or not dialog.is_inside_tree():
		# No scene to host the prompt, which also means no model to lose.
		p_action.call()
		return false
	dialog.ask(p_kind, p_action, p_on_cancel)
	return true


static func raise_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog) and _dialog.visible:
		_dialog.popup_centered()
		_dialog.get_cancel_button().grab_focus()


static func _ensure_dialog() -> UnsavedDialog:
	if _dialog != null and is_instance_valid(_dialog):
		return _dialog
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	_dialog = (load(DIALOG_SCENE) as PackedScene).instantiate() as UnsavedDialog
	tree.current_scene.add_child(_dialog)
	return _dialog
