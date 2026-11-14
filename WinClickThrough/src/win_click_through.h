#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>

namespace godot {

// Minimal Win32 window-style helper. Only exists to toggle WS_EX_TRANSPARENT on a
// native window, which GDScript cannot reach; everything else stays in GDScript.
class WinClickThrough : public RefCounted {
	GDCLASS(WinClickThrough, RefCounted)

protected:
	static void _bind_methods();

public:
	// Adds WS_EX_LAYERED | WS_EX_TRANSPARENT plus a no-op LWA_ALPHA attribute.
	// Windows only honours cross-process hit-test exclusion for layered windows.
	void set_click_through(int64_t p_hwnd, bool p_enabled);

	// Lets the caller notice when the engine rewrote the extended style.
	bool is_click_through(int64_t p_hwnd) const;
	int64_t get_extended_style(int64_t p_hwnd) const;
	bool is_window(int64_t p_hwnd) const;

	// Adds or removes WS_EX_NOACTIVATE on its own. Deliberately bypasses the
	// engine's WINDOW_FLAG_NO_FOCUS path: that path rewrites GWL_STYLE without
	// WS_VISIBLE and never re-shows the window, hiding it permanently.
	bool set_no_activate(int64_t p_hwnd, bool p_enabled);
	bool is_no_activate(int64_t p_hwnd) const;

	// Whole-window opacity via LWA_ALPHA. No-op unless the window is layered.
	void set_alpha(int64_t p_hwnd, int32_t p_alpha) const;
	// Current LWA_ALPHA value, 255 when unset, -1 on failure.
	int32_t get_alpha(int64_t p_hwnd) const;

	// True when the point (screen pixels) resolves to this very window, i.e. a
	// click there would be swallowed instead of reaching the desktop.
	bool hits_window(int64_t p_hwnd, int32_t p_x, int32_t p_y) const;

	// Reads a composed desktop pixel, so callers can tell whether the window is
	// still being presented after its extended style changed. Returns -1 on failure.
	int64_t get_screen_pixel(int32_t p_x, int32_t p_y) const;

	// Window rectangle in screen coordinates as [x, y, width, height].
	godot::PackedInt32Array get_window_rect(int64_t p_hwnd) const;

	// Top-level window lookup by exact title; returns 0 when absent.
	int64_t find_window_by_title(const godot::String &p_title) const;

	// visible / rect / style / ex_style / owner of an arbitrary window.
	godot::Dictionary get_window_info(int64_t p_hwnd) const;
};

} // namespace godot
