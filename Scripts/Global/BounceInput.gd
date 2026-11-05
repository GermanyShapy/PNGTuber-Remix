class_name BounceInput

## Single owner of the model bounce hotkey action: the action name, its cached
## chord map and the per-tick query live here so the UI, the save loader and
## SpritesContainer cannot drift apart.

const ACTION := "model_bounce"

# False when nothing is bound, so polling costs one bool test per tick.
static var _active: bool = false
# Read once per rebuild instead of once per physics tick.
static var _inclusive: bool = true
# Action event index -> chord members. The key is the ACTION's index, not the
# list row: unbound rows never reach the action, so both would diverge.
static var _chord_map: Dictionary = {}


## Replaces the whole binding set. UI edits and save loading both land here.
## Untyped params on purpose: a hand-edited save can hold anything.
static func rebuild(p_keys = [], p_chords = []) -> void:
	var keys: Array = p_keys if p_keys is Array else []
	var chords: Array = p_chords if p_chords is Array else []
	Global.settings_dict["bounce_keys"] = keys.duplicate(true)
	Global.settings_dict["bounce_key_chords"] = chords.duplicate(true)
	_inclusive = Global.settings_dict.get("bounce_inclusive", true)
	if InputMap.has_action(ACTION):
		InputMap.erase_action(ACTION)
	_chord_map.clear()
	var action_idx: int = 0
	for i in keys.size():
		var ev = keys[i]
		if not (ev is InputEvent):
			continue
		if not InputMap.has_action(ACTION):
			InputMap.add_action(ACTION)
		InputMap.action_add_event(ACTION, ev)
		var members: Array = []
		if i < chords.size() and chords[i] is Array:
			members = chords[i]
		if not members.is_empty():
			_chord_map[action_idx] = members
		action_idx += 1
	_active = action_idx > 0
	# Unconditional: a rebuild that only erased the action must also drop it
	# from the native layer's cached table.
	GlobInput.refresh_action_cache()
	# Every writer of the binding set lands here, so this is the one place that
	# keeps the editor list in sync -- a load or a top-bar remap would leave it
	# showing stale rows otherwise.
	Global.bounce_bindings_changed.emit()


## The inclusive flag is a setting, not part of the binding set: changing it
## must not rebuild (and thereby reorder) the action.
static func set_inclusive(p_inclusive: bool) -> void:
	_inclusive = p_inclusive
	Global.settings_dict["bounce_inclusive"] = p_inclusive


## One query per physics tick; false immediately when nothing is bound.
static func poll() -> bool:
	if not _active:
		return false
	return GlobInput.is_action_just_pressed(ACTION, _inclusive, _chord_map)
