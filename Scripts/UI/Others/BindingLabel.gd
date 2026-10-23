class_name BindingLabel
extends RefCounted

## Writes a binding label into a Button so a long chord stays readable.
##
## A chord label grows with every member (" LB +  B +  X +  Y") and the panels
## that show one are narrow, so plain `text = ...` clipped it (T10-4). Buttons on
## 4.7.2 support autowrap: `AUTOWRAP_WORD_SMART` breaks at the spaces around the
## "+" and the button's minimum height grows to two lines, while a label that
## still fits stays on one line. Single-key labels never wrap, so nothing about
## them changes.

static func set_button_text(p_button: Button, p_text: String, p_has_members: bool) -> void:
	p_button.text = p_text
	p_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if p_has_members else TextServer.AUTOWRAP_OFF
