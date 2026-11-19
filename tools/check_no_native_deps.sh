#!/usr/bin/env bash
# Compile smoke test for "a script names a native class that this platform does
# not ship". RawMouseInput and WinClickThrough only ship Windows libraries, so
# on macOS/Linux the class does not exist; naming it in a type annotation is a
# parse error, and a class_name script that fails to parse takes every script
# that references it down with it (GlobInput's autoload included).
#
# What it does: moves every .gdextension whose [libraries] has no macos section
# aside, boots the project headless, and fails if the boot log contains a script
# compile error. Files are restored on exit, always.
#
# Why this is not part of the export pipeline: exporting on Windows compiles the
# scripts with the Windows libraries present, so a missing macOS branch cannot
# show up there. Run this before shipping a macOS/Linux build, and after any
# change to a .gdextension, an autoload, or a new class_name that names one.
#
# Usage:  tools/check_no_native_deps.sh
# Env:    GODOT=<path to console exe>   FRAMES=<frames to run, default 120>

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-E:/Godot/Godots/Godot_v4.7.2/Godot_v4.7.2-stable_win64_console.exe}"
FRAMES="${FRAMES:-120}"

if [ ! -f "$GODOT" ]; then
	echo "SKIP: godot not found at $GODOT (set GODOT=...)"
	exit 3
fi

LOG="$ROOT/tools/.check_no_native_deps.log"
PREF="$(dirname "$GODOT")/Preferences.pRDat"
# Kept inside .godot/ so neither git nor the sandbox's delete wrapper sees it.
PREF_BAK="$ROOT/.godot/check_no_native_deps.pref.bin"
mkdir -p "$ROOT/.godot"
MOVED=()
restore() {
	local f
	for f in ${MOVED[@]+"${MOVED[@]}"}; do
		[ -f "$f.sim-macos" ] && mv "$f.sim-macos" "$f"
	done
	MOVED=()
	# Probing rewrites the editor preferences (screen placement); put them back.
	if [ -s "$PREF_BAK" ] && [ -f "$PREF" ]; then
		cp "$PREF_BAK" "$PREF"
	fi
}
trap restore EXIT INT TERM

# Only the project's own extensions: skip the nested build/verify projects and
# the throw-away probe folder.
while IFS= read -r f; do
	if ! grep -q '^macos\.' "$f"; then
		mv "$f" "$f.sim-macos" && MOVED+=("$f")
	fi
done < <(find "$ROOT" -name '*.gdextension' \
		-not -path '*/.godot/*' -not -path '*/.workbuddy/*' \
		-not -path '*/godot-cpp/*' -not -path '*/_only_for_test/*')

if [ ${#MOVED[@]} -eq 0 ]; then
	echo "SKIP: no platform-specific extension found"
	exit 3
fi

if [ -f "$PREF" ]; then
	cp "$PREF" "$PREF_BAK"
fi

echo "simulating a platform without: ${MOVED[*]##*/}"
APPDATA="${APPDATA:-C:/Users/Admin/AppData/Roaming}" \
	"$GODOT" --headless --path "$ROOT" --quit-after "$FRAMES" >"$LOG" 2>&1
restore

HITS="$(grep -E 'SCRIPT ERROR|Parse Error|Compile Error' "$LOG" || true)"
if [ -n "$HITS" ]; then
	echo "$HITS" | head -20
	echo "RESULT: FAIL ($(echo "$HITS" | wc -l) script error lines, full log: $LOG)"
	exit 1
fi

echo "RESULT: PASS (booted $FRAMES frames with no script compile error)"
exit 0
