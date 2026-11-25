extends Node
class_name GlobalCalculations

static func is_nan_or_inf(value, should_be_one := false):
	var fallback := 1.0 if should_be_one else 0.0

	if value is float or value is int:
		return fallback if (is_inf(value) or is_nan(value)) else value

	elif value is Vector2 or value is Vector2i:
		var x = fallback if (is_inf(value.x) or is_nan(value.x)) else value.x
		var y = fallback if (is_inf(value.y) or is_nan(value.y)) else value.y
		return Vector2(x, y)
	
	return value


static func clamp_angle(value: float, min_angle: float, max_angle: float, rest: float = 0.0) -> float:
	var v = value + rest
	var n = min_angle + rest
	var m = max_angle + rest
	if n <= m:
		return clampf(v, n, m)
	if v > m and v < n:
		var dist_min = abs(v - n)
		var dist_max = abs(v - m)
		return n if dist_min < dist_max else m
	return v


static func _get_distance(a: float, b: float) -> float:
	return a - b

static func some_keyboard_calc_wasd(type_name: String = "follow_type", actor: Node = null) -> Vector2:
	var normal = Vector2(0.0, 0.0)
	if actor.get_value(type_name) in [3, 4, 5]:
		var ws: Vector2 = Vector2.ZERO
		var ad: Vector2 = Vector2.ZERO
		if GlobInput.is_key_pressed(KEY_W):
			ws.y = 1.0
		if GlobInput.is_key_pressed(KEY_S):
			ws.x = 1.0
		if GlobInput.is_key_pressed(KEY_A):
			ad.y = 1.0
		if GlobInput.is_key_pressed(KEY_D):
			ad.x = 1.0

		if actor.get_value(type_name) == 3:
			normal = Vector2(ws.x - ws.y, ws.x - ws.y)
		elif actor.get_value(type_name) == 4:
			normal = Vector2(ad.x - ad.y, ad.x - ad.y)
		elif actor.get_value(type_name) == 5:
			normal = Vector2(ad.x - ad.y, ws.x - ws.y)

	elif actor.get_value(type_name) in [6, 7, 8]:
		var ws: Vector2 = Vector2.ZERO
		var ad: Vector2 = Vector2.ZERO
		if GlobInput.is_action_pressed("Up"):
			ws.y = 1.0
		if GlobInput.is_action_pressed("Down"):
			ws.x = 1.0
		if GlobInput.is_action_pressed("Left"):
			ad.y = 1.0
		if GlobInput.is_action_pressed("Right"):
			ad.x = 1.0

		if actor.get_value(type_name) == 6:
			normal = Vector2(ws.x - ws.y, ws.x - ws.y)
		elif actor.get_value(type_name) == 7:
			normal = Vector2(ad.x - ad.y, ad.x - ad.y)
		elif actor.get_value(type_name) == 8:
			normal = Vector2(ad.x - ad.y, ws.x - ws.y)

	return normal


## Direction vector of the per-state custom keys (follow type 14).
##
## Reads `selected_state` on purpose, matching upstream: the state currently
## picked in the editor decides the key table for every sprite. An unbound slot
## contributes zero, and no slot bound at all yields a zero vector -- which the
## move/rotate/scale chains treat exactly like "no key held", never a fallback.
static func some_keyboard_custom() -> Vector2:
	var state : StateButton = StateButton.selected_state
	if state == null or not is_instance_valid(state):
		return Vector2.ZERO
	var up : float = 1.0 if state.custom_key_pressed("key_up") else 0.0
	var down : float = 1.0 if state.custom_key_pressed("key_down") else 0.0
	var left : float = 1.0 if state.custom_key_pressed("key_left") else 0.0
	var right : float = 1.0 if state.custom_key_pressed("key_right") else 0.0

	return Vector2(right - left, down - up)
