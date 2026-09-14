extends GridContainer

enum ModelAnimationType {
	MouthClosed,
	MouthOpen,
}

@export var type : ModelAnimationType

const KEY_X_FREQ_WOBBLE := "TR_X_FREQUENCY_WOBBLE"
const KEY_X_AMP_WOBBLE  := "TR_X_AMPLITUDE_WOBBLE"
const KEY_Y_FREQ_WOBBLE := "TR_Y_FREQUENCY_WOBBLE"
const KEY_Y_AMP_WOBBLE  := "TR_Y_AMPLITUDE_WOBBLE"

func _ready() -> void:
	await get_tree().current_scene.ready
	%BounceAmountSlider.get_node("%SliderValue").value_changed.connect(_on_bounce_amount_slider_value_changed)
	%GravityAmountSlider.get_node("%SliderValue").value_changed.connect(_on_gravity_amount_slider_value_changed)
	Global.update_anim.connect(set_data)
	set_data()


# Label keeps the assigned string as its raw value and derives what is displayed
# from it via atr(). Writing an already translated string therefore destroys the
# translation key, and the label can no longer follow later locale changes.
# The wobble labels embed a value, so they must be rebuilt from the keys.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_wobble_labels()


func _refresh_wobble_labels() -> void:
	%XFreqWobbleLabel.text = _localize_value(KEY_X_FREQ_WOBBLE, %XFreqWobbleSlider.value)
	%XAmpWobbleLabel.text = _localize_value(KEY_X_AMP_WOBBLE, %XAmpWobbleSlider.value)
	%YFreqWobbleLabel.text = _localize_value(KEY_Y_FREQ_WOBBLE, %YFreqWobbleSlider.value)
	%YAmpWobbleLabel.text = _localize_value(KEY_Y_AMP_WOBBLE, %YAmpWobbleSlider.value)


func _localize_value(p_key: String, p_value: float) -> String:
	return tr(p_key).format({ "value": p_value })


# Every write here must go through set_value_no_signal(): the value_changed
# handlers below call sprite_container.save_state(), a full read -> write ->
# write-back round trip of the whole state dictionary. set_data() only mirrors
# values that were just read back from the container, so those handlers have
# nothing to persist -- they re-serialize identical data. Slider and spin box are
# both written, so the no-signal path keeps the display consistent.
func set_data() -> void:
	var container = Global.sprite_container
	var p = container.state_param_mc if type == ModelAnimationType.MouthClosed else container.state_param_mo

	_set_better_slider(%BounceAmountSlider, p.bounce_energy)
	_set_better_slider(%GravityAmountSlider, p.bounce_gravity)

	%XFreqWobbleSlider.set_value_no_signal(p.xFrq)
	%XAmpWobbleSlider.set_value_no_signal(p.xAmp)
	%YFreqWobbleSlider.set_value_no_signal(p.yFrq)
	%YAmpWobbleSlider.set_value_no_signal(p.yAmp)

	_refresh_wobble_labels()


# Writes a BetterSlider's HSlider and SpinBox pair without emitting value_changed
# (see set_data above).
func _set_better_slider(p_slider: Node, p_value: float) -> void:
	p_slider.get_node("%SliderValue").set_value_no_signal(p_value)
	p_slider.get_node("%SpinBoxValue").set_value_no_signal(p_value)

func _on_bounce_amount_slider_value_changed(value):
	if type == ModelAnimationType.MouthClosed:
		Global.sprite_container.state_param_mc.bounce_energy = value
		%BounceAmountSlider.get_node("%SpinBoxValue").value = value
	if type == ModelAnimationType.MouthOpen:
		Global.sprite_container.state_param_mo.bounce_energy = value
		%BounceAmountSlider.get_node("%SpinBoxValue").value = value
	Global.sprite_container.save_state(Global.current_state)
	
#	%BounceAmount.text = "Bounce Amount : " + str(value)

func _on_gravity_amount_slider_value_changed(value):
	if type == ModelAnimationType.MouthClosed:
		Global.sprite_container.state_param_mc.bounce_gravity = value
		%GravityAmountSlider.get_node("%SpinBoxValue").value = value
	if type == ModelAnimationType.MouthOpen:
		Global.sprite_container.state_param_mo.bounce_gravity = value
		%GravityAmountSlider.get_node("%SpinBoxValue").value = value
	Global.sprite_container.save_state(Global.current_state)

func _on_x_freq_wobble_slider_value_changed(value):
	if type == ModelAnimationType.MouthClosed:
		Global.sprite_container.state_param_mc.xFrq = value
	if type == ModelAnimationType.MouthOpen:
		Global.sprite_container.state_param_mo.xFrq = value

	_refresh_wobble_labels()
	Global.sprite_container.save_state(Global.current_state)

func _on_x_amp_wobble_slider_value_changed(value):
	if type == ModelAnimationType.MouthClosed:
		Global.sprite_container.state_param_mc.xAmp = value
	if type == ModelAnimationType.MouthOpen:
		Global.sprite_container.state_param_mo.xAmp = value

	_refresh_wobble_labels()
	Global.sprite_container.save_state(Global.current_state)

func _on_y_freq_wobble_slider_value_changed(value):
	if type == ModelAnimationType.MouthClosed:
		Global.sprite_container.state_param_mc.yFrq = value
	if type == ModelAnimationType.MouthOpen:
		Global.sprite_container.state_param_mo.yFrq = value

	_refresh_wobble_labels()
	Global.sprite_container.save_state(Global.current_state)

func _on_y_amp_wobble_slider_value_changed(value):
	if type == ModelAnimationType.MouthClosed:
		Global.sprite_container.state_param_mc.yAmp = value
	if type == ModelAnimationType.MouthOpen:
		Global.sprite_container.state_param_mo.yAmp = value

	_refresh_wobble_labels()
	Global.sprite_container.save_state(Global.current_state)
