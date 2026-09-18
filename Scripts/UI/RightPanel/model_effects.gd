extends VBoxContainer

var should_change : bool = false

func _ready() -> void:
	Global.update_anim.connect(set_data)
	await get_tree().current_scene.ready
	set_data()

func set_data():
	should_change = false
	if Global.sprite_container != null && is_instance_valid(Global.sprite_container):
		var fx = Global.sprite_container.model_effects
		# UI-only refresh: emitting item_selected here would run the persisting
		# handler below, and its save_state() writes back the very values this
		# function just read out of the container.
		_apply_effect_type(fx.effect_type)
		%EffectType.select(fx.effect_type)
		%EffectColor.color = fx.effect_color
		%EffectColor2.color = fx.effect_color
		%SizeSlider.value = fx.effect_size
		%SizeSlider2.value = fx.effect_size
		%RollSpeed.value = fx.roll_speed
		%RollSize.value = fx.roll_size
		%Aberration.value = fx.aberration
	#	%RainbowCheck
	should_change = true

# Widgets and shader state that follow the selected effect type. Split out of the
# handler so set_data() can refresh them without re-persisting the state.
func _apply_effect_type(index: int) -> void:
	Global.viewer.material.set_shader_parameter("effect", index)
	%PanelContainer.hide()
	match index:
		0:
			%PanelContainer.hide()
		1:
			%TabContainer.current_tab = 0
			%PanelContainer.show()
		2:
			%TabContainer.current_tab = 1
			%PanelContainer.show()
		4:
			%TabContainer.current_tab = 2
			%PanelContainer.show()
		3:
			%TabContainer.current_tab = 3
			%PanelContainer.show()

func _on_option_button_item_selected(index: int) -> void:
	Global.sprite_container.model_effects.effect_type = index
	_apply_effect_type(index)
	Global.sprite_container.save_state(Global.current_state)

func _on_effect_color_color_changed(color: Color) -> void:
	if !should_change: return
	%EffectColor2.color = color
	Global.viewer.material.set_shader_parameter("line_color", color)
	Global.sprite_container.model_effects.effect_color = color
	Global.sprite_container.save_state(Global.current_state)

func _on_size_slider_value_changed(value: float) -> void:
	if !should_change: return
	%SizeSlider2.value = value
	%SizeLabel.text = tr("TR_EFFECT_SIZE") + ": " + str(value)
	Global.viewer.material.set_shader_parameter("line_scale", value)
	Global.sprite_container.model_effects.effect_size = value
	Global.sprite_container.save_state(Global.current_state)

func _on_rainbow_check_toggled(_toggled_on: bool) -> void:
	pass # Replace with function body.

func _on_color_blindness_helper_options_item_selected(index: int) -> void:
	if !should_change: return
	Global.sprite_container.model_effects.color_blindness_effect = index
	Global.viewport.material.set_shader_parameter("effect", index)
	Global.sprite_container.save_state(Global.current_state)

func _on_size_slider_2_value_changed(value: float) -> void:
	if !should_change: return
	%SizeSlider.value = value
	%SizeLabel2.text = tr("TR_EFFECT_SIZE") + ": " + str(value)
	Global.viewer.material.set_shader_parameter("line_scale", value)
	Global.sprite_container.model_effects.effect_size = value
	Global.sprite_container.save_state(Global.current_state)

func _on_effect_color_2_color_changed(color: Color) -> void:
	if !should_change: return
	%EffectColor.color = color
	Global.viewer.material.set_shader_parameter("line_color", color)
	Global.sprite_container.model_effects.effect_color = color
	Global.sprite_container.save_state(Global.current_state)


func _on_size_label_visibility_changed() -> void:
	var value = Global.sprite_container.model_effects.effect_size
	%SizeLabel.text = tr("TR_EFFECT_SIZE") + ": " + str(value)
	%SizeLabel2.text = tr("TR_EFFECT_SIZE") + ": " + str(value)

func _on_roll_speed_value_changed(value: float) -> void:
	if !should_change: return
	Global.viewer.material.set_shader_parameter("roll_speed", value)
	Global.sprite_container.model_effects.roll_speed = value
	Global.sprite_container.save_state(Global.current_state)

func _on_roll_size_value_changed(value: float) -> void:
	if !should_change: return
	Global.viewer.material.set_shader_parameter("aberration", value)
	Global.sprite_container.model_effects.aberration = value
	Global.sprite_container.save_state(Global.current_state)
