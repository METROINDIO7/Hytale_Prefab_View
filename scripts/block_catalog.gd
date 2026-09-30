class_name BlockCatalog
extends RefCounted

## Dynamic block catalog that stores blocks imported from Hytale's Assets.zip.
## Resources (textures, meshes) are loaded on-demand from the zip.

static var _loaded := false
static var _blocks: Dictionary = {}   # block_id → { id, display_name, icon_path, texture_path, custom_model_path, ... }
static var _categories: Dictionary = {} # category_name → [block_id, ...]
static var _zip_path: String = ""


static func _ensure_loaded() -> void:
	if not _loaded:
		reload()


## Clears all data from the catalog.
static func clear() -> void:
	_blocks.clear()
	_categories.clear()


## Reloads the catalog from cache or triggers a fresh import.
## Skips reload if blocks are already loaded (e.g. just imported).
static func reload() -> void:
	if _loaded and not _blocks.is_empty():
		return
	_blocks.clear()
	_categories.clear()
	var cached := HytaleImporter.load_cached_catalog()
	if not cached.is_empty():
		for block_id in cached:
			_register_block(cached[block_id])
	# Restore zip path from cached data and ensure zip is open for lazy loading
	if _zip_path.is_empty() and not HytaleImporter._current_zip_path.is_empty():
		_zip_path = HytaleImporter._current_zip_path
	if not _zip_path.is_empty():
		HytaleImporter.reopen_zip()
	_loaded = true


## Imports blocks from a zip file and stores them in the catalog.
static func import_from_zip(zip_path: String) -> int:
	_zip_path = zip_path
	var importer := HytaleImporter.new()
	var catalog := importer.import_from_zip(zip_path)
	if catalog.is_empty():
		return 0
	_blocks.clear()
	_categories.clear()
	for block_id in catalog:
		_register_block(catalog[block_id])
	HytaleImporter.save_catalog(catalog)
	# Reopen zip so lazy loading works
	HytaleImporter.reopen_zip()
	_loaded = true
	return _blocks.size()


## Sets the zip path for lazy resource loading (call when zip is opened).
static func set_zip_path(zip_path: String) -> void:
	_zip_path = zip_path
	# Ensure zip is open for lazy loading
	if not zip_path.is_empty() and HytaleImporter._current_zip == null:
		HytaleImporter.reopen_zip()


## Registers a single block entry into the internal dictionaries.
static func _register_block(entry: Dictionary) -> void:
	var block_id: String = str(entry.get("id", ""))
	if block_id.is_empty():
		return
	_blocks[block_id] = entry
	var cat: String = str(entry.get("category", "Other"))
	if not _categories.has(cat):
		_categories[cat] = []
	if not (_categories[cat] as Array).has(block_id):
		(_categories[cat] as Array).append(block_id)


## Returns the full block definition dict for a given block_id.
static func get_definition(block_id: String) -> Dictionary:
	_ensure_loaded()
	return _blocks.get(block_id, {}) as Dictionary


## Returns true if the block exists in the catalog.
static func has_block(block_id: String) -> bool:
	_ensure_loaded()
	return _blocks.has(block_id)


## Returns the display name for a block.
static func get_display_name(block_id: String) -> String:
	_ensure_loaded()
	var entry: Dictionary = _blocks.get(block_id, {})
	if entry.is_empty():
		return block_id.replace("_", " ")
	return str(entry.get("display_name", block_id.replace("_", " ")))


## Returns the icon Texture2D for a block — loads on-demand from disk cache or zip.
static func get_icon(block_id: String) -> Texture2D:
	_ensure_loaded()
	var entry: Dictionary = _blocks.get(block_id, {})
	# Already cached?
	var cached: Variant = entry.get("icon_texture", null)
	if cached != null and cached is Texture2D:
		return cached as Texture2D
	# Try loading (disk cache first, then zip)
	var icon_path: String = str(entry.get("icon_path", ""))
	if icon_path.is_empty():
		return null
	var tex := HytaleImporter.get_icon_lazy(block_id, icon_path)
	if tex != null:
		entry["icon_texture"] = tex
	return tex


## Returns the albedo Texture2D for a block — loads on-demand from disk cache or zip.
static func get_texture(block_id: String) -> Texture2D:
	_ensure_loaded()
	var entry: Dictionary = _blocks.get(block_id, {})
	# Already cached?
	var cached: Variant = entry.get("texture", null)
	if cached != null and cached is Texture2D:
		return cached as Texture2D
	# Try loading (disk cache first, then zip)
	var tex_path: String = str(entry.get("texture_path", ""))
	if tex_path.is_empty():
		return null
	var tex := HytaleImporter.get_texture_lazy(block_id, tex_path)
	if tex != null:
		entry["texture"] = tex
	return tex


## Returns the custom mesh for a block — loads on-demand from disk cache or zip.
static func get_custom_mesh(block_id: String) -> Mesh:
	_ensure_loaded()
	var entry: Dictionary = _blocks.get(block_id, {})
	# Already cached?
	var cached: Variant = entry.get("custom_mesh", null)
	if cached != null and cached is Mesh:
		return cached as Mesh
	# Try loading (disk cache first, then zip)
	var model_path: String = str(entry.get("custom_model_path", ""))
	if model_path.is_empty():
		return null
	# Use atlas size computed during import (stored in catalog)
	var atlas_size := Vector2i(64, 64)
	var raw_atlas: Variant = entry.get("atlas_size", null)
	if raw_atlas is Vector2i:
		atlas_size = raw_atlas as Vector2i
	elif raw_atlas is String:
		# JSON serializes Vector2i as "(x, y)" string
		var s: String = raw_atlas
		s = s.strip_edges().replace("(", "").replace(")", "")
		var parts := s.split(",")
		if parts.size() == 2:
			atlas_size = Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
	elif raw_atlas is Dictionary:
		var d: Dictionary = raw_atlas
		atlas_size = Vector2i(int(d.get("x", 64)), int(d.get("y", 64)))
	var mesh := HytaleImporter.get_model_lazy(block_id, model_path, atlas_size)
	if mesh != null:
		entry["custom_mesh"] = mesh
	return mesh


## Returns the fallback color for a block.
static func get_fallback_color(block_id: String) -> Color:
	_ensure_loaded()
	var entry: Dictionary = _blocks.get(block_id, {})
	var val: Variant = entry.get("fallback_color", null)
	if val == null:
		return Color(0.72, 0.72, 0.72)
	if val is Color:
		return val as Color
	if val is String:
		var cleaned: String = (val as String).strip_edges().replace("(", "").replace(")", "")
		var parts := cleaned.split(",")
		if parts.size() >= 3:
			return Color(parts[0].strip_edges().to_float(), parts[1].strip_edges().to_float(), parts[2].strip_edges().to_float())
	return Color(0.72, 0.72, 0.72)


## Returns the draw type for a block.
static func get_draw_type(block_id: String) -> String:
	_ensure_loaded()
	var entry: Dictionary = _blocks.get(block_id, {})
	return str(entry.get("draw_type", "Cube"))


## Returns all block IDs in a given category.
static func get_blocks_in_category(category: String) -> Array:
	_ensure_loaded()
	return _categories.get(category, []) as Array


## Returns all category names.
static func get_categories() -> Array:
	_ensure_loaded()
	return _categories.keys()


## Returns a palette map: category_name → [block_id, ...]
static func get_palette_map() -> Dictionary:
	_ensure_loaded()
	var result := {}
	for cat in _categories:
		var blocks: Array = (_categories[cat] as Array).duplicate()
		blocks.sort()
		result[cat] = blocks
	return result


## Returns total number of blocks in the catalog.
static func get_block_count() -> int:
	_ensure_loaded()
	return _blocks.size()


## Returns all block IDs.
static func get_all_block_ids() -> Array:
	_ensure_loaded()
	return _blocks.keys()
