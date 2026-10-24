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
# Modifier keys held while the session runs. They never become members: their
# bits travel inside the events of the keys pressed after them, which is what
# makes "Ctrl + A" a single binding and "Ctrl + A + B" a chord. Tracked only so
# the widget can echo a modifier that has no primary key yet.
var _pending_modifiers: Array = []


static func is_modifier_event(p_event: InputEvent) -> bool:
	return p_event is InputEventKey and (p_event as InputEventKey).keycode in MODIFIER_KEYS


## True while any keyboard modifier is part of this event.
##
## This is NOT a test for "the event is a modifier key": while a modifier is
## physically held, Godot stamps its bit onto *every* key event, so a plain key
## pressed in that window carries it too. Use it to read the combination of an
## event, never to decide whether a key may join a session.
static func has_modifier(p_event: InputEvent) -> bool:
	if not (p_event is InputEventWithModifiers):
		return false
	var e := p_event as InputEventWithModifiers
	return e.ctrl_pressed or e.shift_pressed or e.alt_pressed or e.meta_pressed


func clear() -> void:
	_members.clear()
	_pending_modifiers.clear()
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
		var mkey := _member_key(p_event)
		for held in _pending_modifiers:
			if _member_key(held) == mkey:
				return
		_pending_modifiers.append(p_event)
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
##
## The modifier bits of the *press* are kept: they describe the combination the
## user pressed, while the release only reports whatever happens to be held at
## that moment. Letting go of Ctrl before the key would otherwise drop it from
## the binding.
func release(p_event: InputEvent) -> void:
	var key := _member_key(p_event)
	if is_modifier_event(p_event):
		for i in range(_pending_modifiers.size()):
			if _member_key(_pending_modifiers[i]) == key:
				_pending_modifiers.remove_at(i)
				return
		return
	for m in _members:
		if m["key"] == key:
			m["released"] = true
			if m["ev"] is InputEventWithModifiers and p_event is InputEventWithModifiers:
				var s := m["ev"] as InputEventWithModifiers
				var r := p_event as InputEventWithModifiers
				s.ctrl_pressed = s.ctrl_pressed or r.ctrl_pressed
				s.shift_pressed = s.shift_pressed or r.shift_pressed
				s.alt_pressed = s.alt_pressed or r.alt_pressed
				s.meta_pressed = s.meta_pressed or r.meta_pressed
				m["ev"] = s
			else:
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
	if ordered.is_empty():
		# No primary key yet: echo the modifiers held so far. Once a key joins,
		# its own event carries the same bits and the preview shows them.
		var mods: PackedStringArray = []
		for held in _pending_modifiers:
			mods.append(InputDisplayName.text(held))
		return " + ".join(mods) if not mods.is_empty() else ""
	# Preview exactly like the committed binding: the last member pressed is the
	# primary, the rest are members, and the shared modifier prints once.
	var last: InputEvent = ordered[ordered.size() - 1]["ev"]
	var others: Array = []
	for i in range(ordered.size() - 1):
		others.append(ordered[i]["ev"])
	return InputDisplayName.text(last, others)


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
