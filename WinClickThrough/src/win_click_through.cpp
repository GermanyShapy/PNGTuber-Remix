#include "win_click_through.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/rect2i.hpp>

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

using namespace godot;

void WinClickThrough::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_click_through", "hwnd", "enabled"), &WinClickThrough::set_click_through);
	ClassDB::bind_method(D_METHOD("is_click_through", "hwnd"), &WinClickThrough::is_click_through);
	ClassDB::bind_method(D_METHOD("get_extended_style", "hwnd"), &WinClickThrough::get_extended_style);
	ClassDB::bind_method(D_METHOD("is_window", "hwnd"), &WinClickThrough::is_window);
	ClassDB::bind_method(D_METHOD("hits_window", "hwnd", "x", "y"), &WinClickThrough::hits_window);
	ClassDB::bind_method(D_METHOD("get_screen_pixel", "x", "y"), &WinClickThrough::get_screen_pixel);
	ClassDB::bind_method(D_METHOD("get_window_rect", "hwnd"), &WinClickThrough::get_window_rect);
	ClassDB::bind_method(D_METHOD("find_window_by_title", "title"), &WinClickThrough::find_window_by_title);
	ClassDB::bind_method(D_METHOD("get_window_info", "hwnd"), &WinClickThrough::get_window_info);
}

static HWND to_hwnd(int64_t p_hwnd) {
	return reinterpret_cast<HWND>(static_cast<intptr_t>(p_hwnd));
}

void WinClickThrough::set_click_through(int64_t p_hwnd, bool p_enabled) {
	HWND hwnd = to_hwnd(p_hwnd);
	if (!IsWindow(hwnd)) {
		return;
	}

	LONG_PTR ex = GetWindowLongPtrW(hwnd, GWL_EXSTYLE);

	if (p_enabled) {
		// Idempotent and self-healing: the engine rewrites the whole extended style
		// on borderless/always-on-top changes, dropping these bits.
		LONG_PTR want = ex | WS_EX_LAYERED | WS_EX_TRANSPARENT;
		if (ex == want) {
			return;
		}
		SetWindowLongPtrW(hwnd, GWL_EXSTYLE, want);
		// A layered window without attributes set is never composited, so this
		// call is mandatory even though it changes no pixel.
		SetLayeredWindowAttributes(hwnd, 0, 255, LWA_ALPHA);
	} else {
		// Keep WS_EX_LAYERED: removing it re-composites the window and flashes.
		LONG_PTR want = ex & ~static_cast<LONG_PTR>(WS_EX_TRANSPARENT);
		if (ex == want) {
			return;
		}
		SetWindowLongPtrW(hwnd, GWL_EXSTYLE, want);
	}
}

bool WinClickThrough::is_click_through(int64_t p_hwnd) const {
	HWND hwnd = to_hwnd(p_hwnd);
	if (!IsWindow(hwnd)) {
		return false;
	}
	return (GetWindowLongPtrW(hwnd, GWL_EXSTYLE) & WS_EX_TRANSPARENT) != 0;
}

int64_t WinClickThrough::get_extended_style(int64_t p_hwnd) const {
	HWND hwnd = to_hwnd(p_hwnd);
	if (!IsWindow(hwnd)) {
		return 0;
	}
	return static_cast<int64_t>(GetWindowLongPtrW(hwnd, GWL_EXSTYLE));
}

bool WinClickThrough::is_window(int64_t p_hwnd) const {
	return IsWindow(to_hwnd(p_hwnd)) != 0;
}

bool WinClickThrough::hits_window(int64_t p_hwnd, int32_t p_x, int32_t p_y) const {
	HWND hwnd = to_hwnd(p_hwnd);
	if (!IsWindow(hwnd)) {
		return false;
	}
	POINT pt;
	pt.x = p_x;
	pt.y = p_y;
	return WindowFromPoint(pt) == hwnd;
}

int64_t WinClickThrough::get_screen_pixel(int32_t p_x, int32_t p_y) const {
	HDC hdc = GetDC(nullptr);
	if (hdc == nullptr) {
		return -1;
	}
	COLORREF color = GetPixel(hdc, p_x, p_y);
	ReleaseDC(nullptr, hdc);
	if (color == CLR_INVALID) {
		return -1;
	}
	// COLORREF is 0x00BBGGRR; return 0xRRGGBB so callers can compare with Color8().
	return static_cast<int64_t>(((color & 0xFF) << 16) | (color & 0xFF00) | ((color >> 16) & 0xFF));
}

PackedInt32Array WinClickThrough::get_window_rect(int64_t p_hwnd) const {
	PackedInt32Array out;
	HWND hwnd = to_hwnd(p_hwnd);
	if (!IsWindow(hwnd)) {
		return out;
	}
	RECT rc;
	if (!GetWindowRect(hwnd, &rc)) {
		return out;
	}
	out.push_back(rc.left);
	out.push_back(rc.top);
	out.push_back(rc.right - rc.left);
	out.push_back(rc.bottom - rc.top);
	return out;
}

int64_t WinClickThrough::find_window_by_title(const String &p_title) const {
	Char16String title = p_title.utf16();
	HWND found = FindWindowW(nullptr, reinterpret_cast<LPCWSTR>(title.get_data()));
	return static_cast<int64_t>(reinterpret_cast<intptr_t>(found));
}

Dictionary WinClickThrough::get_window_info(int64_t p_hwnd) const {
	Dictionary info;
	HWND hwnd = to_hwnd(p_hwnd);
	if (!IsWindow(hwnd)) {
		return info;
	}
	RECT rc;
	GetWindowRect(hwnd, &rc);
	info["visible"] = IsWindowVisible(hwnd) != 0;
	info["rect"] = Rect2i(rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top);
	info["style"] = static_cast<int64_t>(GetWindowLongPtrW(hwnd, GWL_STYLE));
	info["ex_style"] = static_cast<int64_t>(GetWindowLongPtrW(hwnd, GWL_EXSTYLE));
	info["owner"] = static_cast<int64_t>(reinterpret_cast<intptr_t>(GetWindow(hwnd, GW_OWNER)));
	return info;
}
