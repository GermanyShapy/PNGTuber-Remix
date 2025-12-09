extends Node

func _ready() -> void:
	await get_tree().current_scene.ready
	%MouthOpenAnim.get_popup().connect("id_pressed",_on_mo_anim_state_pressed)
	%MouthClosedAnim.get_popup().connect("id_pressed",_on_mc_anim_state_pressed)
	Global.connect("reinfoanim", reinfoanim)
	%SquishAmount.get_node("%SliderValue").value_changed.connect(_on_squish_amount_changed)
	%SquishAmount.get_node("%SpinBoxValue").value_changed.connect(_on_squish_amount_changed)
	%BlinkChanceSlider.value = 10
	Global.slider_values.connect(set_slider_data)
	

func set_slider_data(data):
	%BlinkChanceSlider.value = data.blink_chance
	%BlinkSpeedSlider.value = data.blink_speed


func reinfoanim():
	%BounceStateCheck.button_pressed = Global.sprite_container.bounce_state
	%MouthClosedAnim.text = Global.sprite_container.current_mc_anim
	%MouthOpenAnim.text = Global.sprite_container.current_mo_anim
	%ShouldSquish.button_pressed = Global.sprite_container.should_squish
	%SquishAmount.get_node("%SliderValue").value = Global.sprite_container.squish_amount


func _on_mo_anim_state_pressed(id):
	Global.sprite_container.mouth_open = id
	match id:
		0:
			Global.sprite_container.current_mo_anim = "Idle"
		1:
			Global.sprite_container.current_mo_anim = "Bouncy"
		2:
			Global.sprite_container.current_mo_anim = "Wavy"
		3:
			Global.sprite_container.current_mo_anim = "One Bounce"
		4:
			Global.sprite_container.current_mo_anim = "Wobble"
		5:
			Global.sprite_container.current_mo_anim = "Squish"
		6:
			Global.sprite_container.current_mo_anim = "Float"
			
	%MouthOpenAnim.text = Global.sprite_container.current_mo_anim
	
	Global.sprite_container.save_state(Global.current_state)

func _on_mc_anim_state_pressed(id):
	Global.sprite_container.mouth_closed = id
	match id:
		0:
			Global.sprite_container.current_mc_anim = "Idle"
		1:
			Global.sprite_container.current_mc_anim = "Bouncy"
		2:
			Global.sprite_container.current_mc_anim = "Wavy"
			
		3:
			Global.sprite_container.current_mc_anim = "One Bounce"
			
		4:
			Global.sprite_container.current_mc_anim = "Wobble"
			
		5:
			Global.sprite_container.current_mc_anim = "Squish"
			
		6:
			Global.sprite_container.current_mc_anim = "Float"
			
	%MouthClosedAnim.text = Global.sprite_container.current_mc_anim
	Global.sprite_container.save_state(Global.current_state)

func _on_squish_amount_changed(value : float):
	Global.sprite_container.squish_amount = value
	Global.sprite_container.save_state(Global.current_state)


func _on_blink_speed_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Global.settings_dict.blink_speed = %BlinkSpeedSlider.value
		%BlinkSpeedLabel.text = "Blink Speed : " + str(snappedf(%BlinkSpeedSlider.value, 0.1))


func _on_blink_speed_slider_value_changed(value):
	%BlinkSpeedLabel.text = "Blink Speed : " + str(snappedf(value, 0.1))
	Global.settings_dict.blink_speed = value

func _on_should_squish_toggled(toggled_on: bool) -> void:
	Global.sprite_container.should_squish = toggled_on
	Global.sprite_container.save_state(Global.current_state)


func _on_blink_chance_slider_value_changed(value: float) -> void:
	%BlinkChanceLabel.text = "Blink Chance : " + str(value)
	Global.settings_dict.blink_chance = value


func _on_bounce_state_check_toggled(toggled_on):
	Global.sprite_container.bounce_state = toggled_on
	Global.sprite_container.save_state(Global.current_state)
