# WinClickThrough

Minimal GDExtension exposing the two Win32 calls GDScript cannot reach:

| Method | Purpose |
|---|---|
| `set_click_through(hwnd, enabled)` | Adds `WS_EX_LAYERED \| WS_EX_TRANSPARENT` plus a no-op `LWA_ALPHA` attribute, or removes only `WS_EX_TRANSPARENT` |
| `is_click_through(hwnd)` / `get_extended_style(hwnd)` | Inspect the current state |
| `is_window(hwnd)` | Validate a handle |
| `hits_window(hwnd, x, y)` | `WindowFromPoint` check |
| `get_window_rect(hwnd)` | `[x, y, w, h]` |
| `find_window_by_title(title)` | Top-level lookup by exact title |
| `get_screen_pixel(x, y)` | Composed desktop pixel as `0xRRGGBB` |

`WS_EX_LAYERED` is what makes hit-test exclusion work across processes; it is
added alongside `WS_EX_NOREDIRECTIONBITMAP`, so the D3D12 composition path keeps
working. `reloadable` is off on purpose: `ExtraWindow` holds a Ref to an
instance, and a hot-reload would leave it pointing at an unloaded library.

## Build

Prerequisites: MinGW g++ (MSYS2), scons, and the `godot-cpp` submodule.

```bash
git submodule update --init --recursive

# 1. Generate bindings and build the static library (once, ~10-20 min)
cd WinClickThrough/godot-cpp
scons platform=windows target=template_debug -j4
scons platform=windows target=template_release -j4

# 2. Build this extension (seconds)
cd ../src
PROCESSOR_ARCHITECTURE=AMD64 MINGW_BIN=/path/to/mingw64/bin scons platform=windows build=debug
PROCESSOR_ARCHITECTURE=AMD64 MINGW_BIN=/path/to/mingw64/bin scons platform=windows build=release
```

Output lands in `WinClickThrough/windows/`. The MinGW runtime is linked
statically, so the DLL has no sibling dependencies.

`PROCESSOR_ARCHITECTURE` must be exported explicitly because scons' Intel
compiler probe reads it unconditionally on some shells.
