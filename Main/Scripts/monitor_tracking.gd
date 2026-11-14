# Special thanks for Guuvita for the help implementing this feature
extends Control
class_name Monitor

const ALL_SCREENS = 9999
var current_screen = ALL_SCREENS
var coords : Vector2 = Vector2(0,0)
var global_coords : Vector2 = Vector2(0,0)
var screen_count = 0

var _cached_screen_positions = {}

func get_cached_screen_position(screen: int):
	if _cached_screen_positions.has(screen):
		return _cached_screen_positions.get(screen)
	var _position = DisplayServer.screen_get_position(screen)
	_cached_screen_positions[screen] = _position
	return _position
	
## Screen rects in Godot's virtual-desktop coordinates, plus the one the cursor
## currently sits on. The layout is rebuilt lazily (and every 2 s as a safety
## net) because every sprite asks for the follow origin each physics frame, and
## DisplayServer.screen_get_* enumerates the monitors on each call.
var _screen_rects: Array[Rect2] = []
var _screen_rects_refresh_at: int = 0
var _mouse_screen_ready: bool = false
var _mouse_screen: int = 0
var _mouse_screen_rect: Rect2 = Rect2()

func _screen_layout() -> Array[Rect2]:
	var now := Time.get_ticks_msec()
	if _screen_rects.is_empty() or now >= _screen_rects_refresh_at:
		_screen_rects.clear()
		for i in DisplayServer.get_screen_count():
			_screen_rects.append(Rect2(
					Vector2(DisplayServer.screen_get_position(i)),
					Vector2(DisplayServer.screen_get_size(i))))
		# _mouse_screen_rect is a copy, so a rebuilt layout leaves it stale until
		# the cursor happens to leave it. Re-resolve on the next frame instead.
		_mouse_screen_ready = false
		_screen_rects_refresh_at = now + 2000
	return _screen_rects

func _set_mouse_screen(index: int, rect: Rect2) -> void:
	_mouse_screen = index
	_mouse_screen_rect = rect
	_mouse_screen_ready = true

func _refresh_mouse_screen() -> void:
	var pos: Vector2 = GlobInput.get_cursor_screen_position()
	var layout := _screen_layout()
	if _mouse_screen_ready and _mouse_screen_rect.has_point(pos):
		return
	for i in layout.size():
		if layout[i].has_point(pos):
			_set_mouse_screen(i, layout[i])
			return
	# Outside the cached layout: a resolution or monitor change happened.
	_screen_rects_refresh_at = 0
	layout = _screen_layout()
	for i in layout.size():
		if layout[i].has_point(pos):
			_set_mouse_screen(i, layout[i])
			return
	# Still unmatched, so the layout is mid-change or there are no monitors at
	# all. Fall back to the primary screen as an INDEX: SCREEN_PRIMARY is a
	# constant (-2), not a valid index, and screen_get_* return ZERO for it,
	# which zeroed the follow origin instead of providing a safe default.
	if layout.is_empty():
		_set_mouse_screen(0, Rect2())
		return
	var primary: int = clampi(DisplayServer.get_primary_screen(), 0, layout.size() - 1)
	_set_mouse_screen(primary, layout[primary])

## Index of the screen the cursor is on. Falls back to the primary screen's
## index when the cursor matches no cached rect, which keeps callers working
## right after a monitor change.
func get_mouse_screen() -> int:
	if not _mouse_screen_ready:
		_refresh_mouse_screen()
	return _mouse_screen

func get_mouse_screen_rect() -> Rect2:
	if not _mouse_screen_ready:
		_refresh_mouse_screen()
	return _mouse_screen_rect

var _cached_screen_key: int = -2147483648
var _cached_screen_size = Vector2.ZERO
func get_screen_size():
	# All Screens means "wherever the cursor is", not the primary monitor: using
	# the primary size with a secondary-display cursor pushed the follow offset
	# far past its clamp range, so the sprite stuck at the edge of one axis.
	var key: int = current_screen
	if current_screen == Monitor.ALL_SCREENS:
		key = 100000 + get_mouse_screen()
	if _cached_screen_key == key:
		return _cached_screen_size
	_cached_screen_key = key
	if current_screen == Monitor.ALL_SCREENS:
		_cached_screen_size = get_mouse_screen_rect().size
	else:
		var idx = clamp(current_screen, 0, DisplayServer.get_screen_count() - 1)
		_cached_screen_size = DisplayServer.screen_get_size(idx)
	return _cached_screen_size
var viewport_mouse_position: Vector2 = Vector2.ZERO

func _ready():
	screen_count = DisplayServer.get_screen_count()
	viewport_mouse_position = get_viewport().get_mouse_position()

func _physics_process(_delta: float) -> void:
	# Keeps the follow origin in sync with whichever screen the cursor is on;
	# costs one rect test per frame once the layout is cached.
	_refresh_mouse_screen()
	if current_screen == ALL_SCREENS:
		set_mouse_positions()
	else:
		if current_screen in range(screen_count):
			screen_based_position()
	viewport_mouse_position = get_viewport().get_mouse_position()

## Whether the cursor is on the configured screen. ALL_SCREENS means "any", and
## an index past the current layout (a monitor unplugged while it was selected)
## clamps to the last real screen instead of testing a zero-size rect, which used
## to report "outside" and silently zero the follow offset. Reads the cached
## layout because every sprite asks this once per physics frame.
func mouse_in_current_screen() -> bool:
	if current_screen == ALL_SCREENS:
		return true
	var layout := _screen_layout()
	if layout.is_empty():
		return true
	var idx: int = clampi(current_screen, 0, layout.size() - 1)
	return layout[idx].has_point(GlobInput.get_cursor_screen_position())

func set_mouse_positions():
	var global_mouse_pos = get_local_mouse_position()
	coords = global_mouse_pos
	global_coords = global_mouse_pos


func screen_based_position():
	if Global.settings_dict.snap_out_of_bounds:
		if !mouse_in_current_screen():
			coords = Vector2(0,0)
			global_coords = Vector2(0,0)
			return
	set_mouse_positions()
