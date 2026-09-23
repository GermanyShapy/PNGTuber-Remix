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

## Joypad button -> translations.csv key. Every user-visible pad label lives in
## the CSV: the face/shoulder/trigger rows name all three vendor layouts at once
## ("Xb A / PS ✕ / NS B"), because the engine only exposes a *position*
## (0 = bottom, 1 = right, 2 = left, 3 = top) and never reports which pad is
## connected -- listing them beats guessing. Those self-identifying rows carry no
## prefix; L3 / R3 / Back / Guide / Start do.
const JOY_BUTTON_TR: Dictionary = {
	JOY_BUTTON_A: "TR_INPUT_JOY_B_BOTTOM",
	JOY_BUTTON_B: "TR_INPUT_JOY_B_RIGHT",
	JOY_BUTTON_X: "TR_INPUT_JOY_B_LEFT",
	JOY_BUTTON_Y: "TR_INPUT_JOY_B_TOP",
	JOY_BUTTON_LEFT_SHOULDER: "TR_INPUT_JOY_LB",
	JOY_BUTTON_RIGHT_SHOULDER: "TR_INPUT_JOY_RB",
	JOY_BUTTON_LEFT_STICK: "TR_INPUT_JOY_L3",
	JOY_BUTTON_RIGHT_STICK: "TR_INPUT_JOY_R3",
	JOY_BUTTON_BACK: "TR_INPUT_JOY_BACK",
	JOY_BUTTON_GUIDE: "TR_INPUT_JOY_GUIDE",
	JOY_BUTTON_START: "TR_INPUT_JOY_START",
}

## Rows that already name all three vendors, so they are shown bare.
const JOY_BUTTON_SELF_LABELLED: Array = [
	JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
]

## D-pad directions. The arrow itself is a glyph, not a word -- the same four
## symbols the keyboard's arrow keys use (see GLYPHS), so it stays in code and
## only the prefix is localised.
const JOY_DPAD_GLYPHS: Dictionary = {
	JOY_BUTTON_DPAD_UP: "↑",
	JOY_BUTTON_DPAD_DOWN: "↓",
	JOY_BUTTON_DPAD_LEFT: "←",
	JOY_BUTTON_DPAD_RIGHT: "→",
}

## Stick axis -> translations.csv key. The triggers are handled separately, they
## are axes too but read as buttons.
const JOY_AXIS_TR: Dictionary = {
	JOY_AXIS_LEFT_X: "TR_INPUT_JOY_LEFT_STICK",
	JOY_AXIS_LEFT_Y: "TR_INPUT_JOY_LEFT_STICK",
	JOY_AXIS_RIGHT_X: "TR_INPUT_JOY_RIGHT_STICK",
	JOY_AXIS_RIGHT_Y: "TR_INPUT_JOY_RIGHT_STICK",
}

## Prefix for joypad labels that are not self-identifying (L3 / R3 / Back /
## Guide / Start). The face, shoulder and trigger rows name all three vendors at
## once, and the sticks already say what they are -- neither needs this.
##
## The trailing space belongs to the locale (English needs one, Chinese does
## not), which is the same convention TR_INPUT_KEY_KP uses.
const JOY_PREFIX_TR := "TR_INPUT_JOY_PREFIX"

## Prefix for the D-pad, which is drawn as an arrow rather than spelled out: a
## bare "↑" would be indistinguishable from the keyboard's up arrow.
const JOY_DPAD_PREFIX_TR := "TR_INPUT_JOY_DPAD"


## The display label for any InputEvent. Never use this for comparisons or as a
## storage key — several call sites rely on the raw `as_text()` for identity.
static func text(p_event: InputEvent) -> String:
	if p_event == null:
		return ""
	if p_event is InputEventMouseButton:
		return _mouse_text(p_event)
	if p_event is InputEventKey:
		return _key_text(p_event)
	if p_event is InputEventJoypadButton:
		return _joy_button_text(p_event)
	if p_event is InputEventJoypadMotion:
		return _joy_motion_text(p_event)
	return p_event.as_text()


static func _joy_prefix() -> String:
	return _lookup(JOY_PREFIX_TR, "Gamepad ")


static func _joy_dpad_prefix() -> String:
	return _lookup(JOY_DPAD_PREFIX_TR, "D-Pad ")


static func _joy_button_text(p_event: InputEventJoypadButton) -> String:
	var idx := p_event.button_index
	if JOY_BUTTON_TR.has(idx):
		var label := _lookup(JOY_BUTTON_TR[idx], "Button %d" % idx)
		if idx in JOY_BUTTON_SELF_LABELLED:
			return label
		return _joy_prefix() + label
	if JOY_DPAD_GLYPHS.has(idx):
		return _joy_dpad_prefix() + JOY_DPAD_GLYPHS[idx]
	return _joy_prefix() + ("Button %d" % idx)


## Sticks render as the stick name plus a direction arrow. Godot reports Y
## positive downwards, so +Y is the down arrow.
static func _joy_motion_text(p_event: InputEventJoypadMotion) -> String:
	match p_event.axis:
		JOY_AXIS_TRIGGER_LEFT:
			return _lookup("TR_INPUT_JOY_LT", "LT / L2 / ZL")
		JOY_AXIS_TRIGGER_RIGHT:
			return _lookup("TR_INPUT_JOY_RT", "RT / R2 / ZR")

	var positive := "→"
	var negative := "←"
	if p_event.axis == JOY_AXIS_LEFT_Y or p_event.axis == JOY_AXIS_RIGHT_Y:
		positive = "↓"
		negative = "↑"

	var label := "Axis %d" % p_event.axis
	if JOY_AXIS_TR.has(p_event.axis):
		label = _lookup(JOY_AXIS_TR[p_event.axis], label)
	return label + (positive if p_event.axis_value >= 0.0 else negative)


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
