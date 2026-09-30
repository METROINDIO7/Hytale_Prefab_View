class_name BlockyIO
extends RefCounted

## Load/save helpers for .blockymodel and .blockyanim files.

static func load_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("File not found: " + path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open: " + path + " (err " + str(FileAccess.get_open_error()) + ")")
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("Invalid JSON in " + path + ": " + json.get_error_message())
		return null
	return json.data


static func save_json_file(path: String, data) -> Error:
	var text := JSON.stringify(data, "  ", false)
	if text == "":
		text = "{}"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write: " + path)
		return FileAccess.get_open_error()
	f.store_string(text + "\n")
	f.close()
	return OK


static func load_blockymodel(path: String) -> BlockyModelData:
	var d: Variant = load_json_file(path)
	if d is Dictionary:
		return BlockyModelData.from_dict(d)
	return null


static func save_blockymodel(path: String, model: BlockyModelData) -> Error:
	model.rebuild_ids()
	return save_json_file(path, model.to_dict())


static func load_blockyanim(path: String) -> BlockyAnimData:
	var d: Variant = load_json_file(path)
	if d is Dictionary:
		return BlockyAnimData.from_dict(d)
	return null


static func save_blockyanim(path: String, anim: BlockyAnimData) -> Error:
	return save_json_file(path, anim.to_dict())
