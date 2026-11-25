extends HBoxContainer

## One direction row of the state panel: label + recording button + remove.
##
## The recording itself is the shared `RemapButton` with `key_type` set, so a
## direction is a first-class binding with chord members, exactly like the state
## hotkey. This root only names the row and hands `key_type` down.

@export var key_type : String = ""

const LABEL_KEYS := {
	"key_up": "TR_KEY_UP",
	"key_down": "TR_KEY_DOWN",
	"key_left": "TR_KEY_LEFT",
	"key_right": "TR_KEY_RIGHT",
}


func _ready() -> void:
	# Bare translation keys: Godot's draw-time auto-translation turns them into
	# the current language, and a language switch needs no refresh hook.
	%State.text = LABEL_KEYS.get(key_type, key_type)
	# The child's own _ready ran first, with key_type still empty; re-label it for
	# this slot now that the export is known.
	var remap_button : RemapButton = %StateRemapButton
	remap_button.key_type = key_type
	remap_button.update_key_text()


## Re-reads the selected state's binding for this slot.
func refresh() -> void:
	%StateRemapButton.update_key_text()
