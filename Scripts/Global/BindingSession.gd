class_name BindingSession
extends RefCounted

## Collects the inputs pressed while a remap widget is awaiting and decides when
## the binding is complete.
##
## Every member has to be released before the binding commits. A stick has no
## release edge that can be stored -- returning to centre reports a ~0 axis
## value, which would be an empty direction -- so coming back into the deadzone
## only marks the member released while the pushed direction stays stored.
## See .ai/docs/30-任务书/输入-按键组合chord_任务书.md §2.3/§2.4.

const MODIFIER_KEYS: Array = [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]

var _members: Array = []
var _seq: int = 0


static func is_modifier_event(p_event: InputEvent) -> bool:
	return p_event is InputEventKey and (p_event as InputEventKey).keycode in MODIFIER_KEYS


## True while any keyboard modifier is part of this event. Such a key is bound
## through the single-event path (the bits live in the event) and must not join
## a chord.
static func has_modifier(p_event: InputEvent) -> bool:
	if not (p_event is InputEventWithModifiers):
		return false
	var e := p_event as InputEventWithModifiers
	return e.ctrl_pressed or e.shift_pressed or e.alt_pressed or e.meta_pressed


func clear() -> void:
	_members.clear()
	_seq = 0


func is_empty() -> bool:
	return _members.is_empty()


## Records a press. Only a member that is not currently held counts as a new
## press and moves to the end of the order: a stick keeps reporting motion
## events while pushed and on its way back to centre, and bumping the order on
## those would turn the stick into the last member -- the primary -- even though
## the button was pressed after it.
func press(p_event: InputEvent) -> void:
	if is_modifier_event(p_event):
		return
	var key := _member_key(p_event)
	for m in _members:
		if m["key"] == key:
			m["ev"] = p_event
			if m["released"]:
				m["released"] = false
				_seq += 1
				m["seq"] = _seq
			return
	_seq += 1
	_members.append({"ev": p_event, "released": false, "key": key, "seq": _seq})


## Marks a pressed member released. For keys, buttons and mouse buttons the
## release event replaces the stored one, matching what the widgets always
## stored (only the code and the modifier bits are ever read back).
func release(p_event: InputEvent) -> void:
	var key := _member_key(p_event)
	for m in _members:
		if m["key"] == key:
			m["released"] = true
			m["ev"] = p_event
			return


## A stick or trigger came back into the deadzone: release the member but keep
## the direction event that was stored when it was pushed.
func release_axis(p_axis: int) -> void:
	var key := "ax:%d" % p_axis
	for m in _members:
		if m["key"] == key:
			m["released"] = true
			return


func is_ready() -> bool:
	if _members.is_empty():
		return false
	for m in _members:
		if not m["released"]:
			return false
	return true


## Returns {primary: InputEvent, members: Array}, members in press order and the
## primary last (the last member pressed). An empty dictionary means nothing to
## commit. A single member yields an empty member list -- a plain binding.
func take() -> Dictionary:
	if _members.is_empty():
		return {}
	var ordered := _members.duplicate()
	ordered.sort_custom(func(a, b): return a["seq"] < b["seq"])
	var primary: InputEvent = ordered[ordered.size() - 1]["ev"]
	var members: Array = []
	for i in range(ordered.size() - 1):
		members.append(ordered[i]["ev"])
	return {"primary": primary, "members": members}


func preview_text() -> String:
	var ordered := _members.duplicate()
	ordered.sort_custom(func(a, b): return a["seq"] < b["seq"])
	# A single member previews exactly like the committed binding; from two
	# members up the preview uses the compact labels so it fits the same control
	# that will show the finished chord.
	var single := ordered.size() == 1
	var parts: PackedStringArray = []
	for m in ordered:
		parts.append(InputDisplayName.text(m["ev"]) if single else InputDisplayName.compact(m["ev"]))
	if parts.is_empty():
		return ""
	return " + ".join(parts)


static func _member_key(p_event: InputEvent) -> String:
	if p_event is InputEventKey:
		return "k:%d" % (p_event as InputEventKey).keycode
	if p_event is InputEventJoypadButton:
		return "jb:%d" % (p_event as InputEventJoypadButton).button_index
	if p_event is InputEventJoypadMotion:
		return "ax:%d" % (p_event as InputEventJoypadMotion).axis
	if p_event is InputEventMouseButton:
		return "mb:%d" % (p_event as InputEventMouseButton).button_index
	return "other"
