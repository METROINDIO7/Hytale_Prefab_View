class_name HytaleImporter
extends RefCounted

## Imports blocks from Hytale's Assets.zip file.
## Two-phase: fast index of JSON paths, then parse + lazy-load resources.

const ITEMS_DIR := "Server/Item/Items"
const COMMON_PREFIX := "Common/"
const CACHE_DIR := "user://imported_blocks/"
const CACHE_FILE := "catalog.json"
const INDEX_FILE := "index.json"
const ASSETS_DIR := "user://imported_blocks/assets/"
const ICONS_DIR := "user://imported_blocks/assets/icons/"
const TEXTURES_DIR := "user://imported_blocks/assets/textures/"
const MODELS_DIR := "user://imported_blocks/assets/models/"

signal import_finished(block_count: int)
signal import_error(message: String)

# Shared state for thread-safe progress reporting
var progress_message: String = ""
var progress_current: int = 0
var progress_total: int = 0

# Path of the currently loaded zip (for lazy resource loading)
static var _current_zip_path: String = ""
static var _current_zip: ZIPReader = null


## Main entry point: imports blocks from a zip file.
func import_from_zip(zip_path: String) -> Dictionary:
	_current_zip_path = zip_path
	if _current_zip != null:
		_current_zip.close()
	_current_zip = ZIPReader.new()
	var err := _current_zip.open(zip_path)
	if err != OK:
		push_error("[HytaleImporter] Cannot open zip: " + zip_path)
		import_error.emit("Cannot open zip: " + zip_path)
		return {}

	# Phase 1: Fast index — just collect file paths, no JSON parsing
	progress_message = "Indexing zip..."

	# Try loading cached index first (avoids re-scanning the zip)
	var item_files: Array[String] = []
	var cached_index := load_index()
	if not cached_index.is_empty():
		item_files = cached_index
		print("[HytaleImporter] Using cached index: ", item_files.size(), " files")
	else:
		item_files = _index_json_files(_current_zip)
		print("[HytaleImporter] JSON files in ", ITEMS_DIR, ": ", item_files.size())
		_save_index(item_files)

	if item_files.is_empty():
		import_error.emit("No JSON files found at '%s'" % ITEMS_DIR)
		_current_zip.close()
		return {}

	# Phase 2: Parse JSONs (no texture/model loading — that's lazy now)
	progress_total = item_files.size()
	var catalog := {}
	var blocks_skipped := 0

	for i in range(item_files.size()):
		var fpath: String = item_files[i]
		if i % 50 == 0:
			progress_current = i
			progress_message = "Parsing block %d/%d..." % [i, item_files.size()]

		var block_id := fpath.get_file().get_basename()
		var json_data: Variant = _read_json_from_zip(_current_zip, fpath)
		if json_data == null or not (json_data is Dictionary):
			continue

		var block_data: Dictionary = json_data as Dictionary
		if not block_data.has("BlockType"):
			blocks_skipped += 1
			continue

		var block_info := _parse_block(block_id, block_data)
		if block_info.is_empty():
			continue

		catalog[block_id] = block_info

	print("[HytaleImporter] Blocks imported: ", catalog.size(), " (skipped ", blocks_skipped, " non-block items)")

	# Phase 3: Extract assets to disk for persistence across sessions
	progress_message = "Extracting assets to disk..."
	_extract_assets_to_disk(catalog)

	progress_message = "Done!"
	import_finished.emit(catalog.size())
	return catalog


## Extracts icons, textures and models from zip to disk for persistence.
func _extract_assets_to_disk(catalog: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ICONS_DIR)
	DirAccess.make_dir_recursive_absolute(TEXTURES_DIR)
	DirAccess.make_dir_recursive_absolute(MODELS_DIR)

	var total := catalog.size()
	var idx := 0
	for block_id in catalog:
		idx += 1
		if idx % 20 == 0:
			progress_current = idx
			progress_message = "Extracting assets %d/%d..." % [idx, total]

		var entry: Dictionary = catalog[block_id]

		# Extract icon
		var icon_path: String = str(entry.get("icon_path", ""))
		if not icon_path.is_empty():
			_extract_file_from_zip(COMMON_PREFIX + icon_path, ICONS_DIR + block_id + ".png")

		# Extract texture
		var tex_path: String = str(entry.get("texture_path", ""))
		if not tex_path.is_empty():
			_extract_file_from_zip(COMMON_PREFIX + tex_path, TEXTURES_DIR + block_id + ".png")

		# Extract custom model
		var model_path: String = str(entry.get("custom_model_path", ""))
		if not model_path.is_empty():
			_extract_file_from_zip(COMMON_PREFIX + model_path, MODELS_DIR + block_id + ".json")
			# Detect atlas size for custom models (only once, during import)
			if not tex_path.is_empty():
				var img := Image.new()
				img.load(TEXTURES_DIR + block_id + ".png")
				if img.get_width() > 0 and img.get_height() > 0:
					entry["atlas_size"] = Vector2i(img.get_width(), img.get_height())


## Extracts a single file from zip to a destination path on disk.
func _extract_file_from_zip(zip_path: String, dest_path: String) -> void:
	if _current_zip == null or not _current_zip.file_exists(zip_path):
		return
	var bytes := _current_zip.read_file(zip_path)
	if bytes == null or bytes.size() == 0:
		return
	DirAccess.make_dir_recursive_absolute(dest_path.get_base_dir())
	var f := FileAccess.open(dest_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(bytes)
	f.close()


## Fast index: returns list of JSON paths under ITEMS_DIR without parsing them.
func _index_json_files(zip: ZIPReader) -> Array[String]:
	var result: Array[String] = []
	var files := zip.get_files()
	var prefix := ITEMS_DIR.to_lower()
	for f in files:
		var fl := f.replace("\\", "/")
		if fl.to_lower().begins_with(prefix + "/") and fl.ends_with(".json"):
			result.append(f)
	return result


## Saves the index to disk for reuse (avoids re-scanning the zip).
static func _save_index(item_files: Array[String]) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open(CACHE_DIR + INDEX_FILE, FileAccess.WRITE)
	if f == null:
		return
	var json := JSON.stringify({"files": item_files})
	f.store_string(json)
	f.close()


## Loads a saved index from disk.
static func load_index() -> Array[String]:
	var path := CACHE_DIR + INDEX_FILE
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return []
	var data: Variant = json.get_data()
	if not (data is Dictionary):
		return []
	var d: Dictionary = data as Dictionary
	var arr: Array = d.get("files", [])
	var result: Array[String] = []
	for s in arr:
		result.append(str(s))
	return result


## Parses a single block JSON into a catalog entry (no resource loading).
static func _parse_block(block_id: String, data: Dictionary) -> Dictionary:
	var bt: Dictionary = data.get("BlockType", {})
	if bt.is_empty():
		return {}

	var info := {}
	info["id"] = block_id
	info["display_name"] = block_id
	info["icon_path"] = str(data.get("Icon", ""))
	info["draw_type"] = str(bt.get("DrawType", "Cube"))

	# Texture path — check All, Sides, UpDown
	var textures: Array = bt.get("Textures", [])
	if textures.size() > 0 and textures[0] is Dictionary:
		var tex_dict: Dictionary = textures[0] as Dictionary
		var tex_path: String = str(tex_dict.get("All", ""))
		if tex_path.is_empty():
			tex_path = str(tex_dict.get("Sides", ""))
		if tex_path.is_empty():
			tex_path = str(tex_dict.get("UpDown", ""))
		info["texture_path"] = tex_path
	else:
		info["texture_path"] = ""

	# Custom model
	info["custom_model_path"] = str(bt.get("CustomModel", ""))

	# Custom model texture
	var custom_tex: Array = bt.get("CustomModelTexture", [])
	if custom_tex.size() > 0 and custom_tex[0] is Dictionary:
		info["custom_model_texture_path"] = str((custom_tex[0] as Dictionary).get("Texture", ""))
	else:
		info["custom_model_texture_path"] = ""

	# For Model draw type: model texture is the primary texture
	if info["draw_type"].to_lower() == "model" and not info["custom_model_texture_path"].is_empty():
		info["texture_path"] = info["custom_model_texture_path"]

	# Fallback: if no texture_path, use model texture
	if info["texture_path"].is_empty() and not info["custom_model_texture_path"].is_empty():
		info["texture_path"] = info["custom_model_texture_path"]

	# Category
	var tags: Dictionary = data.get("Tags", {})
	var type_tags: Array = tags.get("Type", [])
	info["category"] = str(type_tags[0]) if type_tags.size() > 0 else "Other"

	# Fallback color
	var particle_color: String = str(bt.get("ParticleColor", ""))
	if particle_color.is_empty():
		particle_color = str(bt.get("TextureComputedColor", ""))
	info["fallback_color"] = _parse_hex_color(particle_color) if not particle_color.is_empty() else Color(0.72, 0.72, 0.72)

	info["material"] = str(bt.get("Material", "Solid"))
	return info


## Reads and parses a JSON file from inside the zip.
static func _read_json_from_zip(zip: ZIPReader, path: String) -> Variant:
	if not zip.file_exists(path):
		return null
	var bytes := zip.read_file(path)
	if bytes == null or bytes.size() == 0:
		return null
	var text := bytes.get_string_from_utf8()
	if text.is_empty():
		return null
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return null
	return json.data


## Loads a texture from the zip on-demand (lazy).
static func _load_texture_from_zip(zip: ZIPReader, path: String) -> Texture2D:
	if not zip.file_exists(path):
		return null
	var bytes := zip.read_file(path)
	if bytes == null or bytes.size() == 0:
		return null
	var img := Image.new()
	var ext := path.get_extension().to_lower()
	var load_err: Error
	match ext:
		"png":
			load_err = img.load_png_from_buffer(bytes)
		"jpg", "jpeg":
			load_err = img.load_jpg_from_buffer(bytes)
		"webp":
			load_err = img.load_webp_from_buffer(bytes)
		_:
			load_err = img.load_png_from_buffer(bytes)
	if load_err != OK:
		return null
	return ImageTexture.create_from_image(img)


## Loads a .blockymodel from the zip on-demand (lazy).
static func _load_blockymodel_from_zip(zip: ZIPReader, path: String, atlas_size: Vector2i) -> Mesh:
	var json_data: Variant = _read_json_from_zip(zip, path)
	if json_data == null or not (json_data is Dictionary):
		return null
	var model := BlockyModelData.from_dict(json_data as Dictionary)
	if model == null or model.nodes.is_empty():
		return null
	return _merge_model_meshes(model.nodes, atlas_size)


## Merges multiple BlockyNodeData into a single ArrayMesh (recurses children).
static func _merge_model_meshes(nodes: Array[BlockyNodeData], atlas_size: Vector2i) -> ArrayMesh:
	var all_verts := PackedVector3Array()
	var all_normals := PackedVector3Array()
	var all_uvs := PackedVector2Array()
	var all_indices := PackedInt32Array()
	var vtx_off := [0]  # mutable wrapper for int

	_flatten_and_merge(nodes, Vector3.ZERO, all_verts, all_normals, all_uvs, all_indices, vtx_off, atlas_size)

	if all_verts.size() == 0:
		return null

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = all_verts
	arrays[Mesh.ARRAY_NORMAL] = all_normals
	arrays[Mesh.ARRAY_TEX_UV] = all_uvs
	arrays[Mesh.ARRAY_INDEX] = all_indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


## Recursively flattens node tree and merges geometry into target arrays.
static func _flatten_and_merge(nodes: Array[BlockyNodeData], parent_offset: Vector3,
		out_verts: PackedVector3Array, out_normals: PackedVector3Array,
		out_uvs: PackedVector2Array, out_indices: PackedInt32Array, vtx_off: Array,
		atlas_size: Vector2i) -> void:
	for node in nodes:
		var bs := BlockySettings.current.block_size
		var node_offset := parent_offset + node.position / bs
		var node_rot := node.orientation
		var node_basis := Basis(node_rot)
		if node.has_geometry():
			var mesh: ArrayMesh
			if node.shape_type == "box":
				mesh = MeshGen.make_box_mesh(node, atlas_size)
			else:
				mesh = MeshGen.make_quad_mesh(node, atlas_size)
			if mesh != null:
				# shape_offset: pivot -> mesh center, in scene units
				var shape_off := node.shape_offset / bs
				for surface_idx in range(mesh.get_surface_count()):
					var surface_arrays := mesh.surface_get_arrays(surface_idx)
					var verts: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = surface_arrays[Mesh.ARRAY_NORMAL]
					var uvs: PackedVector2Array = surface_arrays[Mesh.ARRAY_TEX_UV]
					var indices: PackedInt32Array = surface_arrays[Mesh.ARRAY_INDEX]
					for v in verts:
						# Apply rotation, then offset: pivot + rot * (shape_off + local_v)
						out_verts.append(node_basis * (shape_off + v) + node_offset)
					for n in normals:
						out_normals.append(node_basis * n)
					out_uvs.append_array(uvs)
					for idx in indices:
						out_indices.append(idx + vtx_off[0])
					vtx_off[0] += verts.size()
		if not node.children.is_empty():
			_flatten_and_merge(node.children, node_offset, out_verts, out_normals, out_uvs, out_indices, vtx_off, atlas_size)


## Parses a hex color string like "#58ad9b" into a Color.
static func _parse_hex_color(hex: String) -> Color:
	var h := hex.strip_edges()
	if h.begins_with("#"):
		h = h.substr(1)
	if h.length() != 6:
		return Color(0.72, 0.72, 0.72)
	var r := h.substr(0, 2).hex_to_int() / 255.0
	var g := h.substr(2, 2).hex_to_int() / 255.0
	var b := h.substr(4, 2).hex_to_int() / 255.0
	return Color(r, g, b)


## Saves the imported catalog to disk for caching.
static func save_catalog(catalog: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open(CACHE_DIR + CACHE_FILE, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var serializable := {}
	# Save the zip path for lazy loading on next session
	serializable["__zip_path"] = _current_zip_path
	for block_id in catalog:
		var entry: Dictionary = catalog[block_id]
		var save_entry := {}
		for key in entry:
			var val = entry[key]
			if val is Texture2D or val is Mesh or val is Image:
				continue
			save_entry[key] = val
		serializable[block_id] = save_entry
	f.store_string(JSON.stringify(serializable, "\t"))
	f.close()
	return OK


## Loads a previously saved catalog from disk.
static func load_cached_catalog() -> Dictionary:
	var path := CACHE_DIR + CACHE_FILE
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = data as Dictionary
	# Restore zip path for lazy loading
	if d.has("__zip_path"):
		_current_zip_path = str(d["__zip_path"])
		d.erase("__zip_path")
	return d


## Loads an icon on-demand: tries disk cache first, then zip.
static func get_icon_lazy(block_id: String, rel_path: String) -> Texture2D:
	if rel_path.is_empty():
		return null
	# Try disk cache first (icons directory)
	var disk_path := ICONS_DIR + block_id + ".png"
	if FileAccess.file_exists(disk_path):
		return _load_texture_from_disk(disk_path)
	# Fall back to zip
	if _current_zip == null:
		return null
	return _load_texture_from_zip(_current_zip, COMMON_PREFIX + rel_path)


## Loads a texture on-demand: tries disk cache first, then zip.
static func get_texture_lazy(block_id: String, rel_path: String) -> Texture2D:
	if rel_path.is_empty():
		return null
	# Try disk cache first (textures directory)
	var disk_path := TEXTURES_DIR + block_id + ".png"
	if FileAccess.file_exists(disk_path):
		return _load_texture_from_disk(disk_path)
	# Fall back to zip
	if _current_zip == null:
		return null
	return _load_texture_from_zip(_current_zip, COMMON_PREFIX + rel_path)


## Loads a model mesh on-demand: tries disk cache first, then zip.
static func get_model_lazy(block_id: String, rel_path: String, atlas_size: Vector2i = Vector2i(64, 64)) -> Mesh:
	if rel_path.is_empty():
		return null
	# Try disk cache first
	var disk_path := MODELS_DIR + block_id + ".json"
	if FileAccess.file_exists(disk_path):
		return _load_blockymodel_from_disk(disk_path, atlas_size)
	# Fall back to zip
	if _current_zip == null:
		return null
	return _load_blockymodel_from_zip(_current_zip, COMMON_PREFIX + rel_path, atlas_size)


## Loads a texture from a file on disk.
static func _load_texture_from_disk(path: String) -> Texture2D:
	var img := Image.new()
	var ext := path.get_extension().to_lower()
	var err: Error
	match ext:
		"png":
			err = img.load(path)
		"jpg", "jpeg":
			err = img.load(path)
		"webp":
			err = img.load(path)
		_:
			err = img.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)


## Loads a blockymodel JSON from disk and converts to ArrayMesh.
static func _load_blockymodel_from_disk(path: String, atlas_size: Vector2i) -> Mesh:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var data = json.get_data()
	if data == null or not (data is Dictionary):
		return null
	var model := BlockyModelData.from_dict(data as Dictionary)
	if model == null or model.nodes.is_empty():
		return null
	return _merge_model_meshes(model.nodes, atlas_size)


## Re-opens the current zip (call this when starting a new session).
## Skips if the zip is already open (avoids unnecessary close+reopen).
static func reopen_zip() -> void:
	if _current_zip != null:
		return
	if not _current_zip_path.is_empty() and FileAccess.file_exists(_current_zip_path):
		_current_zip = ZIPReader.new()
		_current_zip.open(_current_zip_path)
