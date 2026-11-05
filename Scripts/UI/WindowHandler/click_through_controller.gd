extends Node
class_name ClickThroughController

# Owns the whole-window click-through state machine: a downscaled GPU sample of
# the target window answers "is the cursor over a solid pixel?", and that answer
# is pushed to Win32 as a single WS_EX_TRANSPARENT toggle.

# Alpha above this counts as solid. The answer comes from the GPU because sprite
# opacity is produced by the sprite shader, not by a CPU-side alpha mask.
const PROBE_ALPHA: float = 0.02
# Long-edge sample resolution. The probe keeps the window's aspect ratio, so
# non-square windows stay aligned.
const BITMAP_SIZE: int = 64
# Neighbourhood probed around the cursor to absorb the lag between sampling and
# using the answer.
const EDGE_SLACK: int = 1
# Give up resolving the native handle after this many attempts; a window that
# never produces a valid id should not cost two syscalls per frame forever.
const HWND_RETRIES: int = 120

# The owning window. Kept as Node to avoid a class cycle with ExtraWindow.
var target: Node
# World shared with the owner's viewport, so the probe renders the same scene.
var world: World2D

var _sample_view: SubViewport
var _sample_camera: Camera2D
var _last_sample: Image
var _wct: Object
var _hwnd: int = 0
var _hwnd_retries: int = 0
# Window pixels per sample texel; drives the probe zoom and the lookup scale.
var _sample_scale: float = 1.0
var _sample_toggle: bool = false


func _ready() -> void:
	_wct = ClassDB.instantiate("WinClickThrough")
	if _wct == null:
		push_warning("WinClickThrough extension missing; native click-through disabled")
		set_process(false)
		set_physics_process(false)
		return

	_sample_view = SubViewport.new()
	_sample_view.size = Vector2i(BITMAP_SIZE, BITMAP_SIZE)
	_sample_view.transparent_bg = true
	_sample_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sample_view.world_2d = world
	_sample_camera = Camera2D.new()
	_sample_view.add_child(_sample_camera)
	add_child(_sample_view)


func _exit_tree() -> void:
	if _wct != null and _hwnd != 0:
		_wct.call("set_click_through", _hwnd, false)


func _process(_delta: float) -> void:
	_apply()


func _physics_process(_delta: float) -> void:
	# Only the sample matters here; the silhouette is read from its alpha channel.
	if !_wants_sample():
		return
	_sample_toggle = !_sample_toggle
	if !_sample_toggle:
		return
	var w := target
	var k := maxf(float(w.size.x), float(w.size.y)) / float(BITMAP_SIZE)
	if !is_equal_approx(k, _sample_scale):
		_sample_scale = maxf(k, 1.0)
		var probe := Vector2i(
			maxi(2, int(round(float(w.size.x) / _sample_scale))),
			maxi(2, int(round(float(w.size.y) / _sample_scale))))
		if probe != _sample_view.size:
			_sample_view.size = probe
	_sample_camera.global_position = w.camera.global_position
	_sample_camera.zoom = w.camera.zoom / _sample_scale
	_last_sample = _sample_view.get_texture().get_image()


func _wants_sample() -> bool:
	var w := target
	return w.borderless and !w.dragging and !w.camera.panning


func _apply() -> void:
	if _wct == null:
		return
	if _hwnd == 0:
		var w := target
		if !w.is_visible() or _hwnd_retries >= HWND_RETRIES:
			return
		_hwnd_retries += 1
		_resolve_hwnd()
		if _hwnd == 0:
			return

	var through := true
	if !_wants_sample():
		through = false
	else:
		var w := target
		var local := Vector2(w.mouse_pos - w.position)
		if local.x >= 0.0 and local.y >= 0.0 and local.x < float(w.size.x) and local.y < float(w.size.y):
			through = !_alpha_hit(local)
	_wct.call("set_click_through", _hwnd, through)


## True when the cursor sits on a solid pixel of the model.
## Deliberately requires borderless: the probe only runs in that state, and the
## window origin includes the title bar otherwise, which offsets the lookup.
## Returns false (unlike _alpha_hit) when there is no sample yet: swallowing a
## click is the lesser evil for click-through, but a bounce is not.
func is_cursor_over_model() -> bool:
	var w := target
	if w == null or not w.borderless or _last_sample == null:
		return false
	return _alpha_hit(Vector2(w.mouse_pos - w.position))


func _alpha_hit(local: Vector2) -> bool:
	if _last_sample == null:
		# No sample yet: stay interactive rather than swallow clicks.
		return true
	var w := _last_sample.get_width()
	var h := _last_sample.get_height()
	var px := Vector2i(local / _sample_scale)
	for dy in range(-EDGE_SLACK, EDGE_SLACK + 1):
		for dx in range(-EDGE_SLACK, EDGE_SLACK + 1):
			var q := px + Vector2i(dx, dy)
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			if _last_sample.get_pixel(q.x, q.y).a > PROBE_ALPHA:
				return true
	return false


# get_window_id() is 0 until the native window exists, and id 0 means the MAIN
# window; resolving that id would make the whole application click-through.
func _resolve_hwnd() -> void:
	var wid: int = target.get_window_id()
	if wid == 0:
		return
	var main_hwnd: int = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, 0)
	var candidate: int = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, wid)
	if candidate == 0 or candidate == main_hwnd:
		return
	_hwnd = candidate
