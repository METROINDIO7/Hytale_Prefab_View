# prefab_loader.gd
class_name PrefabLoader
extends RefCounted
static func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[PrefabLoader] Not found: " + path); return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return {}
	var content := f.get_as_text(); f.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		push_error("[PrefabLoader] JSON error: " + json.get_error_message()); return {}
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY: return {}
	return data
