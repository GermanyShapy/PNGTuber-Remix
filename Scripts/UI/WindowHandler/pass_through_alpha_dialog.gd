extends AcceptDialog
class_name PassThroughAlphaDialog

## Hover opacity while whole-window passthrough is on.
## Mirrors the grid-size dialog: a single value with a spin box, applied on
## confirm. Drawn as its own OS window because subwindow embedding is disabled
## project-wide, so it stays usable while the extra windows swallow the cursor.

const MIN_PERCENT := 10
const MAX_PERCENT := 100
const STEP_PERCENT := 5

var label: Label
var note: Label
var spin: SpinBox

func _ready() -> void:
	min_size = Vector2i(420, 170)

	var container := VBoxContainer.new()
	# Anchored explicitly: a plain child of a Window keeps a zero-size rect.
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 12
	container.offset_top = 12
	container.offset_right = -12
	# Leave room for the confirm button the dialog places at the bottom itself.
	container.offset_bottom = -52
	container.add_theme_constant_override("separation", 8)
	add_child(container)

	# Two single-line labels instead of one wrapped label: word wrap makes the
	# minimum width unknown, and the dialog then sizes itself from a zero width.
	label = Label.new()
	container.add_child(label)

	note = Label.new()
	note.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
	container.add_child(note)

	spin = SpinBox.new()
	spin.min_value = MIN_PERCENT
	spin.max_value = MAX_PERCENT
	spin.step = STEP_PERCENT
	spin.suffix = "%"
	spin.allow_greater = false
	spin.allow_lesser = false
	container.add_child(spin)

	confirmed.connect(_apply)

## Text is refreshed on every open so a language change is picked up, and the
## value is re-read from Settings rather than cached from the last edit.
func open(p_theme: Theme, current_percent: int) -> void:
	theme = p_theme
	title = tr("TR_PASS_THROUGH_ALPHA")
	ok_button_text = tr("TR_APPLY")
	label.text = tr("TR_PASS_THROUGH_ALPHA_INFO")
	note.text = tr("TR_PASS_THROUGH_ALPHA_NOTE")
	spin.value = float(clampi(current_percent, MIN_PERCENT, MAX_PERCENT))
	# The pet window itself is usually always-on-top; a plain dialog would end up
	# underneath it and look like nothing happened.
	always_on_top = true
	popup_centered()
	spin.grab_focus()
	spin.get_line_edit().select_all()

func _apply() -> void:
	Settings.set_window_pass_through_alpha(int(spin.value))
