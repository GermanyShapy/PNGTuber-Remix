@icon("res://UI/BetterSlider/BetSIcon .png")
extends HBoxContainer
class_name BetterSlider

enum Type {
	
	Both,
	Spin,
	Slide,
	NoLabel,
	NoLabelSpin,

}

var should_change : bool = false
@export var sp_type : String = "Null"
@export var label_text : String = "placeholder"
@export var mini_value : float
@export var max_value : float
@export var step : float
@export var value : float
@export var ui_type : Type
@export var value_to_update : String = "position": get = get_value
@export var has_alt_values := false

# Called when the node enters the scene tree for the first time.
func _ready():
	Global.reinfo.connect(enable)
	Global.deselect.connect(nullfy)
	Global.editing_for_changed.connect(enable)
	nullfy()
	%SpinBoxValue.get_line_edit().focus_mode = 1
	%SpinBoxValue.min_value = mini_value
	%SpinBoxValue.max_value = max_value
	%SpinBoxValue.step = step
	
	%SliderValue.min_value = mini_value
	%SliderValue.max_value = max_value
	%SliderValue.step = step
	
	%SpinBoxValue.get_line_edit().focus_entered.connect(f_entered)
	%SpinBoxValue.get_line_edit().focus_exited.connect(release)
	%BetterSliderLabel.text = label_text
	ready_type(ui_type)

func ready_type(typ):
	match typ:
		Type.Both:
			pass
		Type.Spin:
			%SliderValue.hide()
			%SliderValue.editable = false
			%SpinBoxValue.set_h_size_flags(Control.SIZE_EXPAND_FILL)
			%SpinBoxValue.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_FILL)
		Type.Slide:
			%SpinBoxValue.hide()
			%SpinBoxValue.editable = false
		Type.NoLabel:
			%BetterSliderLabel.hide()
		Type.NoLabelSpin:
			%SpinBoxValue.set_h_size_flags(Control.SIZE_EXPAND_FILL)
			%SpinBoxValue.set_horizontal_alignment(HORIZONTAL_ALIGNMENT_FILL)
			%SpinBoxValue.hide()
			%SpinBoxValue.editable = false
			%BetterSliderLabel.hide()


func get_value() -> String:
	if !has_alt_values:
		return value_to_update
	
	match Global.editing_for:
		Global.Mouth.Open:
			return "mo_" + value_to_update
		Global.Mouth.Screaming:
			return "scream_" + value_to_update
	
	return value_to_update


func release():
	Global.spinbox_held = false

func f_entered():
	Global.spinbox_held = true

func _on_spin_box_value_value_changed(nvalue):
	Global.spinbox_held = false
	%SliderValue.value = nvalue
	%SpinBoxValue.get_line_edit().release_focus()
	if should_change:
		for i in Global.held_sprites:
			if i != null && is_instance_valid(i) && sp_type != "Null":
				i.sprite_data[value_to_update] = nvalue
				StateButton.multi_edit(nvalue, value_to_update, i, i.states)
				i.save_state(Global.current_state)

func _on_slider_value_value_changed(nvalue):
	if should_change:
		%SpinBoxValue.value = nvalue
		for i in Global.held_sprites:
			if i != null && is_instance_valid(i) && sp_type != "Null":
				i.sprite_data[value_to_update] = nvalue
				if i.sprite_type == "WiggleApp" && sp_type == "WiggleApp":
					i.update_wiggle_parts()
				i.save_state(Global.current_state)
			

func _on_spin_box_value_focus_exited() -> void:
	Global.spinbox_held = false
	%SpinBoxValue.release_focus()

func nullfy():
	if sp_type != "Null":
		%SpinBoxValue.editable = false
		%SliderValue.editable = false

func enable():
	should_change = false
	for i in Global.held_sprites:
		if i.sprite_type == sp_type:
			%SpinBoxValue.editable = true
			%SliderValue.editable = true
			%SpinBoxValue.value =  i.sprite_data[value_to_update]
			%SliderValue.value = i.sprite_data[value_to_update]
			
		if sp_type == "":
			%SpinBoxValue.editable = true
			%SliderValue.editable = true
			%SliderValue.value = i.sprite_data[value_to_update]
			%SpinBoxValue.value =  i.sprite_data[value_to_update]
	should_change = true


func _on_slider_value_drag_ended(value_changed: bool) -> void:
	if value_changed && sp_type != "Null":
		var undo_redo_data : Array = []
		for i in Global.held_sprites:
			var og_val = i.sprite_data.duplicate()
			i.sprite_data[value_to_update] = %SliderValue.value
			if i.sprite_type == "WiggleApp" && sp_type == "WiggleApp":
				i.update_wiggle_parts()
			i.save_state(Global.current_state)
			undo_redo_data.append({sprite_object = i, 
			data = i.sprite_data.duplicate(), 
			og_data = og_val,
			data_type = "sprite_data", 
			state = Global.current_state})
