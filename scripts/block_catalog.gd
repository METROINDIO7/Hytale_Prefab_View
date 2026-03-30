class_name BlockCatalog
extends RefCounted

const BLOCKS_DIR := "res://scenes/blocks"

static var _loaded := false
static var _scene_by_id: Dictionary = {}
static var _data_by_id: Dictionary = {}
static var _category_map: Dictionary = {}


static func reload() -> void:
	_loaded = true
	_scene_by_id.clear()
	_data_by_id.clear()
	_category_map.clear()
	_scan_dir(BLOCKS_DIR)
	for category in _category_map.keys():
		(_category_map[category] as Array).sort()


static func get_palette_map(legacy_palette: Dictionary = {}) -> Dictionary:
	_ensure_loaded()
	var merged := {}
	for category in legacy_palette.keys():
		merged[category] = (legacy_palette[category] as Array).duplicate()
	for category in _category_map.keys():
		if not merged.has(category):
			merged[category] = []
		for block_id in _category_map[category]:
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


static func _scan_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		
		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full_path)
			continue
		
		if entry.get_extension().to_lower() != "tscn":
			continue
		_register_scene(full_path)
	dir.list_dir_end()


static func _register_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	
	var instance := packed.instantiate()
	if instance is BlockPaletteButton:
		var block_btn := instance as BlockPaletteButton
		var block_id := block_btn.get_block_id()
		if not block_id.is_empty():
			_scene_by_id[block_id] = packed
			_data_by_id[block_id] = block_btn.get_block_data()
			var cat := block_btn.category if block_btn.category.strip_edges() != "" else "Custom"
			if not _category_map.has(cat):
				_category_map[cat] = []
			(_category_map[cat] as Array).append(block_id)
	instance.free()
