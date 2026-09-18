class_name InputDisplayName
extends RefCounted

## Turns a bound InputEvent into a human-readable, localised label.
##
## `InputEvent.as_text()` is English-only and, worse, names printable keys after
## the *key* instead of the glyph. Measured on Godot 4.7.2:
##
## | event                  | as_text()          | wanted      |
## |---|---|---|
## | `KEY_QUOTELEFT`        | `QuoteLeft`        | `` ` ``     |
## | `KEY_MINUS`            | `Minus`            | `-`         |
## | `KEY_UP`               | `Up`               | `↑`         |
## | `MOUSE_BUTTON_LEFT`    | `Left Mouse Button`| `鼠标左键`  |
##
## Four groups, applied in this order:
##
## 1. **GLYPHS** (locale independent) — symbol keys and the four arrow keys. A
##    glyph carries no language, so it is never routed through translations.csv.
## 2. **ALIASES** (locale independent) — conventional abbreviations that are the
##    label users actually look for (`Escape` -> `Esc`), not a translation.
## 3. **NAMED FUNCTION KEYS** — only the ones whose English name is opaque to a
##    non-English user: Space / Enter / Backspace / Delete / Insert, plus the
##    keypad prefix `Kp ` (keypad operators print their symbol: `Kp Add` ->
##    `小键盘+`). Deliberately *left in English*: Tab, Shift, Ctrl, Alt, the
##    `Meta`/`Windows` key, the F-keys, CapsLock/NumLock/ScrollLock, Print, Pause
##    and Menu.
## 4. **Everything else falls through unchanged** — letters, digits, and any shape
##    we do not recognise. Adding another named key is a one-line change in
##    GLYPHS / ALIASES / NAME_TR plus a row in translations.csv; nothing else
##    needs touching.
##
## A shortcut such as `Ctrl+S` therefore becomes `Ctrl+S` in English and
## `Ctrl+S` too in Chinese — only the *key* part is ever rewritten, and the
## modifier prefix is taken verbatim from the event itself (see `_key_text()`),
## so the OS-dependent platform naming (`Windows` vs `Cmd` vs `Meta`) stays right.

## Locale-independent glyphs. Keys are Godot's own `as_text()` names.
const GLYPHS: Dictionary = {
	"QuoteLeft": "`",
	"Minus": "-",
	"Equal": "=",
	"BracketLeft": "[",
	"BracketRight": "]",
	"BackSlash": "\\",
	"Semicolon": ";",
	"Apostrophe": "'",
	"Comma": ",",
	"Period": ".",
	"Slash": "/",
	"Up": "↑",
	"Down": "↓",
	"Left": "←",
	"Right": "→",
}

## Conventional abbreviations that are the *same in every locale* — they are the
## label users actually look for, not a translation.
const ALIASES: Dictionary = {
	"Escape": "Esc",
}

## Godot key name -> translations.csv key. See the class comment for what is
## intentionally absent.
const NAME_TR: Dictionary = {
	"Space": "TR_INPUT_KEY_SPACE",
	"Enter": "TR_INPUT_KEY_ENTER",
	"Backspace": "TR_INPUT_KEY_BACKSPACE",
	"Delete": "TR_INPUT_KEY_DELETE",
	"Insert": "TR_INPUT_KEY_INSERT",
}

## Godot names every keypad key "Kp " + a bare key name (measured: "Kp 0"..
## "Kp 9", "Kp Add", "Kp Subtract", "Kp Multiply", "Kp Divide", "Kp Period",
## "Kp Enter"). Translate the prefix; the operators become the symbol they
## actually print, by the same reasoning as GLYPHS.
const KP_PREFIX := "Kp "
const KP_EXTRAS: Dictionary = {
	"Add": "+",
	"Subtract": "-",
	"Multiply": "*",
	"Divide": "/",
	"Period": ".",
}

## Godot mouse name -> translations.csv key (`as_text()` without the optional
## ` (Double Click)` suffix, which is handled separately).
const MOUSE_TR: Dictionary = {
	"Left Mouse Button": "TR_INPUT_MOUSE_LEFT",
	"Right Mouse Button": "TR_INPUT_MOUSE_RIGHT",
	"Middle Mouse Button": "TR_INPUT_MOUSE_MIDDLE",
	"Mouse Wheel Up": "TR_INPUT_MOUSE_WHEEL_UP",
	"Mouse Wheel Down": "TR_INPUT_MOUSE_WHEEL_DOWN",
	"Mouse Wheel Left": "TR_INPUT_MOUSE_WHEEL_LEFT",
	"Mouse Wheel Right": "TR_INPUT_MOUSE_WHEEL_RIGHT",
	"Mouse Thumb Button 1": "TR_INPUT_MOUSE_THUMB_1",
	"Mouse Thumb Button 2": "TR_INPUT_MOUSE_THUMB_2",
}

const DOUBLE_CLICK_SUFFIX := " (Double Click)"


## The display label for any InputEvent. Never use this for comparisons or as a
## storage key — several call sites rely on the raw `as_text()` for identity.
static func text(p_event: InputEvent) -> String:
	if p_event == null:
		return ""
	if p_event is InputEventMouseButton:
		return _mouse_text(p_event)
	if p_event is InputEventKey:
		return _key_text(p_event)
	return p_event.as_text()


## Returns Godot's own text, minus the localisation. Only for identity checks
## that must stay stable across locales (saved settings, dict keys).
static func raw(p_event: InputEvent) -> String:
	return p_event.as_text() if p_event != null else ""


static func _key_text(p_event: InputEventKey) -> String:
	var full := p_event.as_text()
	# Re-render the same event with every modifier flag cleared: what is left is
	# exactly the trailing key name Godot appended to the modifier prefix. Taking
	# the prefix from the engine this way keeps the OS-dependent platform naming
	# (`Windows` / `Cmd` / `Meta`) correct and stays safe even if some key name
	# ever contained a '+'.
	var bare := p_event.duplicate() as InputEventKey
	if bare == null:
		return full  # never crash a UI refresh over a label
	bare.ctrl_pressed = false
	bare.shift_pressed = false
	bare.alt_pressed = false
	bare.meta_pressed = false
	var key_name := bare.as_text()
	if not full.ends_with(key_name):
		return full  # unexpected shape: never mangle it
	var prefix := full.substr(0, full.length() - key_name.length())
	return prefix + _translate_key(key_name)


static func _mouse_text(p_event: InputEventMouseButton) -> String:
	var full := p_event.as_text()
	var suffix := ""
	if full.ends_with(DOUBLE_CLICK_SUFFIX):
		full = full.substr(0, full.length() - DOUBLE_CLICK_SUFFIX.length())
		suffix = _lookup("TR_INPUT_DOUBLE_CLICK", DOUBLE_CLICK_SUFFIX)
	if MOUSE_TR.has(full):
		return _lookup(MOUSE_TR[full], full) + suffix
	return full + suffix


static func _translate_key(p_key_name: String) -> String:
	if GLYPHS.has(p_key_name):
		return GLYPHS[p_key_name]
	if ALIASES.has(p_key_name):
		return ALIASES[p_key_name]
	if p_key_name.begins_with(KP_PREFIX):
		return _translate_kp(p_key_name.substr(KP_PREFIX.length()))
	if NAME_TR.has(p_key_name):
		return _lookup(NAME_TR[p_key_name], p_key_name)
	return p_key_name


## `p_rest` is the bare key name that follows "Kp ", e.g. "0" or "Add".
## "Enter" / "Period" reuse the normal tables; digits fall through unchanged.
static func _translate_kp(p_rest: String) -> String:
	if KP_EXTRAS.has(p_rest):
		p_rest = KP_EXTRAS[p_rest]
	elif NAME_TR.has(p_rest):
		p_rest = _lookup(NAME_TR[p_rest], p_rest)
	return _lookup("TR_INPUT_KEY_KP", KP_PREFIX) + p_rest


## Resolves a translations.csv key, falling back to `p_fallback` when the row is
## missing (stale import, or a locale added later) so the user never sees "TR_…".
static func _lookup(p_tr_key: String, p_fallback: String) -> String:
	var value := TranslationServer.translate(p_tr_key)
	return p_fallback if value == p_tr_key else value
