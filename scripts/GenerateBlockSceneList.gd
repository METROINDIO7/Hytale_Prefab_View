@tool
extends EditorScript

const BLOCKS_DIR      := "res://scenes/blocks"
const ICONS_FOLDERS   := ["res://2d/Icons"]
const SCENE_OUT       := "res://data/block_scene_paths.json"
const ICONS_OUT       := "res://icon_paths.json"

func _run() -> void:
	_ensure_dir("res://data")

	# 1 ── Escenas de bloques
	var scene_paths: Array = []
	_scan_scenes(BLOCKS_DIR, scene_paths)
	scene_paths.sort()
	_write_json(SCENE_OUT, scene_paths)
	print("[Gen] %d escenas → %s" % [scene_paths.size(), SCENE_OUT])

	# 2 ── Íconos
	var icon_paths: Array = []
	for folder in ICONS_FOLDERS:
		_scan_icons(folder, icon_paths)
	icon_paths.sort()
	_write_json(ICONS_OUT, icon_paths)
	print("[Gen] %d íconos → %s" % [icon_paths.size(), ICONS_OUT])

func _scan_scenes(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "": break
		if entry.begins_with(".") or entry.begins_with("_"): continue
		var full := path.path_join(entry)
		if dir.current_is_dir(): _scan_scenes(full, out)
		elif entry.get_extension().to_lower() == "tscn": out.append(full)
	dir.list_dir_end()

func _scan_icons(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "": break
		if entry.begins_with("."): continue
		var full := path.path_join(entry)
		if dir.current_is_dir():
			_scan_icons(full, out)
		else:
			var ext := entry.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg", "webp", "svg"]:
				out.append(full)
	dir.list_dir_end()

func _ensure_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(path)):
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(path))

func _write_json(path: String, data: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo escribir: " + path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
