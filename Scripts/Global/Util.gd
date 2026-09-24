class_name Util

## Returns the parent of the provided path. If an error occurs, then the provided
## path is returned.
static func get_parent_path(path: String) -> String:
	var parent_slash_index = path.rfind("/");
	if parent_slash_index < 0:
		return path;
	return path.substr(0, parent_slash_index);

## Localised default label of the cycle at `p_index` (for example "Cycle 3"). It is
## public because UI also uses it to reveal the identity of a renamed cycle.
static func cycle_default_label(p_index: int) -> String:
	# tr() is an Object method, so a static context has to go through TranslationServer.
	return "%s %d" % [TranslationServer.translate("TR_CYCLE"), p_index + 1];

## Single source of truth for a cycle's display label: a user given name wins, an
## empty or missing one falls back to the localised default. Never read
## `cycles[i].name` with dot access -- old saves simply do not have the key.
static func cycle_label(p_cycles: Array, p_index: int) -> String:
	if p_index < 0 or p_index >= p_cycles.size():
		return "";
	var entry: Variant = p_cycles[p_index];
	if typeof(entry) != TYPE_DICTIONARY:
		return "";
	var cycle := entry as Dictionary;
	var custom := str(cycle.get("name", "")).strip_edges();
	if custom.is_empty():
		return cycle_default_label(p_index);
	return custom;

## Writes a user given cycle name. Empty text -- or text equal to the default label
## -- erases the key, so a cycle nobody renamed keeps following the locale.
## Returns true only when the stored data actually changed.
static func set_cycle_name(p_cycles: Array, p_index: int, p_name: String) -> bool:
	if p_index < 0 or p_index >= p_cycles.size():
		return false;
	var entry: Variant = p_cycles[p_index];
	if typeof(entry) != TYPE_DICTIONARY:
		return false;
	var cycle := entry as Dictionary;
	var typed := p_name.strip_edges();
	if typed.is_empty() or typed == cycle_default_label(p_index):
		if not cycle.has("name"):
			return false;
		cycle.erase("name");
		return true;
	if str(cycle.get("name", "")) == typed:
		return false;
	cycle["name"] = typed;
	return true;
