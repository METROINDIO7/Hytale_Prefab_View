class_name BlockCatalog
extends RefCounted

const BLOCKS_DIR := "res://scenes/blocks"
const GENERATED_PALETTE_PATH := "res://data/generated_block_palette.json"

static var _loaded := false
static var _scene_by_id: Dictionary = {}
static var _data_by_id: Dictionary = {}
static var _category_map: Dictionary = {}
static var _generated_palette_map: Dictionary = {}
static var _generated_block_ids: Dictionary = {}


const SCENE_PATHS_LIST := "res://data/block_scene_paths.json"

static func _load_scene_paths() -> Array:
	if not FileAccess.file_exists(SCENE_PATHS_LIST):
		return []
	var raw := FileAccess.get_file_as_string(SCENE_PATHS_LIST)
	if raw.is_empty():
		return []
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed as Array

static func _scan_dir(dir_path: String) -> void:
	# En exports, DirAccess sobre res:// dentro del PCK no es confiable.
	# Usamos la lista pre-generada si existe.
	if not OS.has_feature("editor"):
		var paths := _load_scene_paths()
		if not paths.is_empty():
			for scene_path in paths:
				_register_scene(scene_path)
			return
		else:
			push_warning("BlockCatalog: no se encontró block_scene_paths.json. Ejecuta GenerateBlockSceneList antes de exportar.")
			return

	# En el editor: escaneo dinámico normal
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with(".") or entry.begins_with("_"):
			continue
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full_path)
			continue
		if entry.get_extension().to_lower() != "tscn":
			continue
		_register_scene(full_path)
	dir.list_dir_end()




static func reload() -> void:
	_loaded = true
	_scene_by_id.clear()
	_data_by_id.clear()
	_category_map.clear()
	_generated_block_ids.clear()
	_generated_palette_map = _load_generated_palette()
	for category in _generated_palette_map.keys():
		for block_id in (_generated_palette_map[category] as Array):
			_generated_block_ids[String(block_id)] = true
	_scan_dir(BLOCKS_DIR)
	for category in _category_map.keys():
		(_category_map[category] as Array).sort()
	for category in _generated_palette_map.keys():
		(_generated_palette_map[category] as Array).sort()


static func get_palette_map(legacy_palette: Dictionary = {}) -> Dictionary:
	_ensure_loaded()
	var merged := {}
	var use_generated := not _generated_palette_map.is_empty()
	
	if use_generated:
		for category in _generated_palette_map.keys():
			merged[category] = (_generated_palette_map[category] as Array).duplicate()
	else:
		for category in legacy_palette.keys():
			merged[category] = (legacy_palette[category] as Array).duplicate()
	
	for category in _category_map.keys():
		if not merged.has(category):
			merged[category] = []
		for block_id in _category_map[category]:
			if use_generated and not _generated_block_ids.has(String(block_id)):
				continue
			if not merged[category].has(block_id):
				merged[category].append(block_id)
	return merged


static func get_scene_for(block_id: String) -> PackedScene:
	_ensure_loaded()
	return _scene_by_id.get(block_id, null) as PackedScene


static func get_definition(block_id: String) -> Dictionary:
	_ensure_loaded()
	return (_data_by_id.get(block_id, {}) as Dictionary).duplicate(true)


static func has_custom_definition(block_id: String) -> bool:
	_ensure_loaded()
	return _data_by_id.has(block_id)


static func _ensure_loaded() -> void:
	if not _loaded:
		reload()


static func _load_generated_palette() -> Dictionary:
	if not FileAccess.file_exists(GENERATED_PALETTE_PATH):
		return {}
	
	var raw := FileAccess.get_file_as_string(GENERATED_PALETTE_PATH)
	if raw.is_empty():
		return {}
	
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	
	var normalized := {}
	for category in (parsed as Dictionary).keys():
		var values := (parsed[category] as Array)
		normalized[String(category)] = values.duplicate()
	return normalized


static func _register_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		print("Failed to load scene: ", scene_path)
		return
	
	var instance := packed.instantiate()
	if instance == null:
		print("Failed to instantiate scene: ", scene_path)
		return
	if instance is BlockPaletteButton:
		var block_btn := instance as BlockPaletteButton
		var block_id := block_btn.get_block_id()
		if not block_id.is_empty():
			_scene_by_id[block_id] = packed
			var data = block_btn.get_block_data()
			_data_by_id[block_id] = data
			var cat := block_btn.category if block_btn.category.strip_edges() != "" else "Custom"
			if not _category_map.has(cat):
				_category_map[cat] = []
			(_category_map[cat] as Array).append(block_id)
	else:
		print("Scene ", scene_path, " does not have BlockPaletteButton")
	instance.free()
