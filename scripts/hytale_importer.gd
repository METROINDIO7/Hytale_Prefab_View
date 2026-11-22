class_name HytaleImporter
extends RefCounted

## Imports blocks from Hytale's Assets.zip file.
## Two-phase: fast index of JSON paths, then parse + lazy-load resources.

const ITEMS_DIR := "Server/Item/Items"
const COMMON_PREFIX := "Common/"
const CACHE_DIR := "user://imported_blocks/"
const CACHE_FILE := "catalog.json"
const INDEX_FILE := "index.json"
const MANIFEST_FILE := "manifest.json"
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

# Path of the currently loaded zip (for lazy resource loading, main thread only)
static var _current_zip_path: String = ""
static var _current_zip: ZIPReader = null
static var _opened_zip_path: String = ""
static var _current_zip_version: String = ""
static var _cached_catalog_version: String = ""

# Runtime resource caches (shared by blocks that use the same source asset)
static var _icon_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _model_cache: Dictionary = {}


## Main entry point: imports blocks from a zip file.
func import_from_zip(zip_path: String) -> Dictionary:
	# The import thread uses its own ZIPReader; the static one is reserved for
	# lazy loading on the main thread so both never race on the same handle.
	var zip := ZIPReader.new()
	var err := zip.open(zip_path)
	if err != OK:
		push_error("[HytaleImporter] Cannot open zip: " + zip_path)
		import_error.emit("Cannot open zip: " + zip_path)
		return {}

	var all_files := zip.get_files()
	var file_set := {}
	for f in all_files:
		file_set[str(f).replace("\\", "/")] = true
	var version := _compute_zip_version(zip_path, all_files.size())
	_current_zip_path = zip_path
	_current_zip_version = version

	# Fast path: the catalog and extracted assets already match this exact zip.
	if _manifest_matches(version):
		var cached := load_cached_catalog()
		if not cached.is_empty() and _cached_catalog_version == version:
			progress_message = "Using cached import..."
			print("[HytaleImporter] Reusing cached catalog for ", zip_path)
			zip.close()
			import_finished.emit(cached.size())
			return cached

	# Phase 1: Fast index — just collect file paths, no JSON parsing
	progress_message = "Indexing zip..."

	# Try loading cached index first (avoids re-scanning the zip)
	var item_files: Array[String] = []
	var cached_index := load_index(version)
	if not cached_index.is_empty():
		item_files = cached_index
		print("[HytaleImporter] Using cached index: ", item_files.size(), " files")
	else:
		item_files = _index_json_files(all_files)
		print("[HytaleImporter] JSON files in ", ITEMS_DIR, ": ", item_files.size())
		_save_index(item_files, version)

	if item_files.is_empty():
		import_error.emit("No JSON files found at '%s'" % ITEMS_DIR)
		zip.close()
		return {}

	# Phase 2: Parse JSONs (no texture/model loading — that's lazy now)
	progress_total = item_files.size()
	var catalog := {}
	var blocks_skipped := 0

	for i in range(item_files.size()):
		var fpath: String = item_files[i]
		progress_current = i + 1
		if i % 50 == 0:
			progress_message = "Parsing block %d/%d..." % [i + 1, item_files.size()]

		var block_id := fpath.get_file().get_basename()
		var json_data: Variant = _read_json_from_zip_checked(zip, fpath, file_set)
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
	_extract_assets_to_disk(catalog, zip, file_set, version)

	zip.close()
	progress_message = "Done!"
	import_finished.emit(catalog.size())
	return catalog


## Extracts icons, textures and models from zip to disk for persistence.
## Assets are content-addressed by source path + zip version, so files shared by
## many blocks are written only once and never served from a stale zip.
func _extract_assets_to_disk(catalog: Dictionary, zip: ZIPReader,
		file_set: Dictionary, version: String) -> void:
	DirAccess.make_dir_recursive_absolute(ICONS_DIR)
	DirAccess.make_dir_recursive_absolute(TEXTURES_DIR)
	DirAccess.make_dir_recursive_absolute(MODELS_DIR)

	var icon_cache := {}
	var texture_cache := {}
	var model_cache := {}
	var written := {
		ICONS_DIR: {},
		TEXTURES_DIR: {},
		MODELS_DIR: {},
	}

	var total := catalog.size()
	progress_total = total
	progress_current = 0
	var idx := 0
	for block_id in catalog:
		idx += 1
		progress_current = idx
		if idx % 20 == 0:
			progress_message = "Extracting assets %d/%d..." % [idx, total]

		var entry: Dictionary = catalog[block_id]

		# Icons
		var icon_path: String = str(entry.get("icon_path", ""))
		if not icon_path.is_empty():
			var r := _extract_asset(zip, file_set, icon_path, ICONS_DIR,
					_asset_ext(icon_path, "png"), version, icon_cache, written)
			if bool(r.get("ok", false)):
				entry["icon_file"] = str(r.get("file", ""))

		# Block/cube textures (All / Sides / UpDown / Up / Down)
		var tex_keys := [
			"texture_path", "texture_all_path", "texture_sides_path",
			"texture_updown_path", "texture_up_path", "texture_down_path",
			"texture_north_path", "texture_south_path", "texture_east_path",
			"texture_west_path",
		]
		for key in tex_keys:
			var src: String = str(entry.get(key, ""))
			if src.is_empty():
				continue
			var r := _extract_asset(zip, file_set, src, TEXTURES_DIR,
					_asset_ext(src, "png"), version, texture_cache, written)
			if bool(r.get("ok", false)):
				entry[str(key).replace("_path", "_file")] = str(r.get("file", ""))

		# Custom model texture (atlas used by the model, not the cube texture)
		var model_tex_path: String = str(entry.get("custom_model_texture_path", ""))
		var atlas_path := model_tex_path
		if not model_tex_path.is_empty():
			var r := _extract_asset(zip, file_set, model_tex_path, TEXTURES_DIR,
					_asset_ext(model_tex_path, "png"), version, texture_cache, written)
			if bool(r.get("ok", false)):
				entry["model_texture_file"] = str(r.get("file", ""))
		elif not entry.get("texture_file", "").is_empty():
			entry["model_texture_file"] = entry["texture_file"]
		if atlas_path.is_empty():
			atlas_path = str(entry.get("texture_path", ""))

		# Custom model
		var model_path: String = str(entry.get("custom_model_path", ""))
		if not model_path.is_empty():
			var r := _extract_asset(zip, file_set, model_path, MODELS_DIR, "json",
					version, model_cache, written)
			if bool(r.get("ok", false)):
				entry["model_file"] = str(r.get("file", ""))

		# Atlas size must come from the model texture, otherwise UVs are wrong.
		if not atlas_path.is_empty() and texture_cache.has(atlas_path):
			var atlas_size: Vector2i = texture_cache[atlas_path].get("size", Vector2i.ZERO)
			if atlas_size.x > 0 and atlas_size.y > 0:
				entry["atlas_size"] = atlas_size

	# Remove files left over from previous zip versions / old cache layouts.
	var kept_icons: Dictionary = written[ICONS_DIR]
	var kept_textures: Dictionary = written[TEXTURES_DIR]
	var kept_models: Dictionary = written[MODELS_DIR]
	_cleanup_orphans(ICONS_DIR, kept_icons)
	_cleanup_orphans(TEXTURES_DIR, kept_textures)
	_cleanup_orphans(MODELS_DIR, kept_models)
	_write_manifest(version)


## Copies one asset from the zip to disk unless that exact version already
## exists. Returns {"file": <name>, "size": Vector2i, "ok": bool}.
static func _extract_asset(zip: ZIPReader, file_set: Dictionary, source_path: String,
		dest_dir: String, ext: String, version: String, cache: Dictionary,
		written: Dictionary) -> Dictionary:
	if cache.has(source_path):
		return cache[source_path]
	var result := {"file": "", "size": Vector2i.ZERO, "ok": false}
	var full := COMMON_PREFIX + source_path.replace("\\", "/")
	if zip != null and file_set.has(full):
		var bytes := zip.read_file(full)
		if bytes != null and bytes.size() > 0:
			var fname := _asset_file_name(source_path, ext, version)
			var dest := dest_dir + fname
			DirAccess.make_dir_recursive_absolute(dest_dir)
			if not FileAccess.file_exists(dest):
				var f := FileAccess.open(dest, FileAccess.WRITE)
				if f != null:
					f.store_buffer(bytes)
					f.close()
			result["file"] = fname
			result["ok"] = true
			if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp":
				result["size"] = _image_size_from_bytes(bytes)
			var dir_set: Dictionary = written.get(dest_dir, {})
			dir_set[fname] = true
			written[dest_dir] = dir_set
	cache[source_path] = result
	return result


static func _asset_file_name(source_path: String, ext: String, version: String) -> String:
	return (version + "|" + source_path).md5_text() + "." + ext


static func _asset_ext(source_path: String, fallback: String) -> String:
	var ext := source_path.get_extension().to_lower()
	if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp":
		return ext
	return fallback


## Reads PNG dimensions straight from the header (avoid decoding thousands of
## images just to know their size).
static func _image_size_from_bytes(bytes: PackedByteArray) -> Vector2i:
	if bytes.size() >= 24 and bytes[0] == 0x89 and bytes[1] == 0x50 \
			and bytes[2] == 0x4E and bytes[3] == 0x47:
		var w := int(bytes[16]) * 16777216 + int(bytes[17]) * 65536 \
				+ int(bytes[18]) * 256 + int(bytes[19])
		var h := int(bytes[20]) * 16777216 + int(bytes[21]) * 65536 \
				+ int(bytes[22]) * 256 + int(bytes[23])
		if w > 0 and h > 0:
			return Vector2i(w, h)
	var img := Image.new()
	if img.load_png_from_buffer(bytes) == OK:
		return img.get_size()
	if img.load_jpg_from_buffer(bytes) == OK:
		return img.get_size()
	if img.load_webp_from_buffer(bytes) == OK:
		return img.get_size()
	return Vector2i.ZERO


static func _cleanup_orphans(dir_path: String, keep: Dictionary) -> void:
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	var remove_list: Array[String] = []
	da.list_dir_begin()
	var fname := da.get_next()
	while not fname.is_empty():
		if not da.current_is_dir() and not keep.has(fname):
			remove_list.append(fname)
		fname = da.get_next()
	da.list_dir_end()
	for name in remove_list:
		da.remove(name)


static func _compute_zip_version(zip_path: String, file_count: int) -> String:
	var size := 0
	var f := FileAccess.open(zip_path, FileAccess.READ)
	if f != null:
		size = f.get_length()
		f.close()
	var mtime := FileAccess.get_modified_time(zip_path)
	return "%s|%d|%d|%d" % [zip_path.get_file(), size, mtime, file_count]


static func _manifest_matches(version: String) -> bool:
	var path := ASSETS_DIR + MANIFEST_FILE
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return false
	var data: Variant = json.get_data()
	if not (data is Dictionary):
		return false
	return str((data as Dictionary).get("version", "")) == version


static func _write_manifest(version: String) -> void:
	DirAccess.make_dir_recursive_absolute(ASSETS_DIR)
	var f := FileAccess.open(ASSETS_DIR + MANIFEST_FILE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"version": version}))
	f.close()


## Drops cached resources so the next lazy load uses the new zip contents.
static func clear_runtime_caches() -> void:
	_icon_cache.clear()
	_texture_cache.clear()
	_model_cache.clear()


## Fast index: returns list of JSON paths under ITEMS_DIR without parsing them.
func _index_json_files(files: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	var prefix := ITEMS_DIR.to_lower()
	for f in files:
		var fl := f.replace("\\", "/")
		if fl.to_lower().begins_with(prefix + "/") and fl.ends_with(".json"):
			result.append(f)
	return result


## Saves the index to disk for reuse (avoids re-scanning the zip).
static func _save_index(item_files: Array[String], version: String) -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open(CACHE_DIR + INDEX_FILE, FileAccess.WRITE)
	if f == null:
		return
	var json := JSON.stringify({"version": version, "files": item_files})
	f.store_string(json)
	f.close()


## Loads a saved index from disk, only if it belongs to the same zip version.
static func load_index(version: String = "") -> Array[String]:
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
	if str(d.get("version", "")) != version:
		return []
	var arr: Array = d.get("files", [])
	var result: Array[String] = []
	for s in arr:
		result.append(str(s))
	return result


## Parses a single block JSON into a catalog entry (no resource loading).
static func _parse_block(block_id: String, data: Dictionary) -> Dictionary:
	var bt_v: Variant = data.get("BlockType", null)
	if not (bt_v is Dictionary):
		return {}
	var bt: Dictionary = bt_v as Dictionary
	if bt.is_empty():
		return {}

	# Base data can live at the top level (single-state blocks) or inside
	# BlockType.State.Definitions.Block (multi-state / variant blocks). Merge
	# the defaults so DrawType, Textures and Material are not silently lost.
	var def: Dictionary = bt.duplicate(true)
	var state_v: Variant = def.get("State", null)
	if state_v is Dictionary:
		var defs_v: Variant = (state_v as Dictionary).get("Definitions", null)
		if defs_v is Dictionary:
			var defs: Dictionary = defs_v as Dictionary
			var base_v: Variant = defs.get("Block", null)
			if base_v is Dictionary:
				var base: Dictionary = base_v as Dictionary
				for key in base:
					if not def.has(key) or def[key] == null:
						def[key] = base[key]
			elif not def.has("DrawType") and not str(def.get("CustomModel", "")).is_empty():
				# Variant-only block (roofs, doors...): its default is a model.
				def["DrawType"] = "Model"

	var info := {}
	info["id"] = block_id
	info["display_name"] = block_id
	info["icon_path"] = str(data.get("Icon", ""))
	info["custom_model_path"] = str(def.get("CustomModel", ""))

	var draw_type := str(def.get("DrawType", ""))
	if draw_type.is_empty():
		draw_type = "Model" if not info["custom_model_path"].is_empty() else "Cube"
	info["draw_type"] = draw_type

	# Custom model texture
	var custom_tex_path := ""
	var custom_tex_v: Variant = def.get("CustomModelTexture", null)
	if custom_tex_v is Array and (custom_tex_v as Array).size() > 0:
		var first: Variant = (custom_tex_v as Array)[0]
		if first is Dictionary:
			custom_tex_path = str((first as Dictionary).get("Texture", ""))
	info["custom_model_texture_path"] = custom_tex_path

	# Texture paths per face group. Keep them separate so the cube can use the
	# right texture on the top/bottom faces (Sides + UpDown) and on directional
	# variants, instead of painting one texture over every face.
	var all_path := ""
	var sides_path := ""
	var updown_path := ""
	var up_path := ""
	var down_path := ""
	var north_path := ""
	var south_path := ""
	var east_path := ""
	var west_path := ""
	var textures_v: Variant = def.get("Textures", null)
	if textures_v is Array and (textures_v as Array).size() > 0:
		var tex_v: Variant = (textures_v as Array)[0]
		if tex_v is Dictionary:
			var tex_dict: Dictionary = tex_v as Dictionary
			all_path = str(tex_dict.get("All", ""))
			sides_path = str(tex_dict.get("Sides", ""))
			updown_path = str(tex_dict.get("UpDown", ""))
			up_path = str(tex_dict.get("Up", ""))
			down_path = str(tex_dict.get("Down", ""))
			north_path = str(tex_dict.get("North", ""))
			south_path = str(tex_dict.get("South", ""))
			east_path = str(tex_dict.get("East", ""))
			west_path = str(tex_dict.get("West", ""))
	info["texture_all_path"] = all_path
	info["texture_sides_path"] = sides_path
	info["texture_updown_path"] = updown_path
	info["texture_up_path"] = up_path
	info["texture_down_path"] = down_path
	info["texture_north_path"] = north_path
	info["texture_south_path"] = south_path
	info["texture_east_path"] = east_path
	info["texture_west_path"] = west_path

	var tex_path := all_path
	if tex_path.is_empty():
		tex_path = sides_path
	if tex_path.is_empty():
		tex_path = updown_path
	if tex_path.is_empty():
		tex_path = custom_tex_path
	info["texture_path"] = tex_path

	# Category
	var type_tags: Array = []
	var tags_v: Variant = data.get("Tags", null)
	if tags_v is Dictionary:
		var type_v: Variant = (tags_v as Dictionary).get("Type", null)
		if type_v is Array:
			type_tags = type_v as Array
	info["category"] = str(type_tags[0]) if type_tags.size() > 0 else "Other"

	# Fallback color
	var particle_color: String = str(def.get("ParticleColor", ""))
	if particle_color.is_empty():
		particle_color = str(def.get("TextureComputedColor", ""))
	info["fallback_color"] = _parse_hex_color(particle_color) if not particle_color.is_empty() else Color(0.72, 0.72, 0.72)

	info["material"] = str(def.get("Material", "Solid"))
	return info


## Reads a JSON file during the import pass, using the already-built file set
## instead of asking the zip for existence on every item (avoids repeated scans).
static func _read_json_from_zip_checked(zip: ZIPReader, path: String, file_set: Dictionary) -> Variant:
	var normalized := path.replace("\\", "/")
	if not file_set.has(normalized):
		return null
	var bytes := zip.read_file(path)
	if bytes == null or bytes.size() == 0:
		return null
	var text := bytes.get_string_from_utf8()
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


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
	# Save metadata used for cache validation / lazy loading.
	serializable["__zip_path"] = _current_zip_path
	serializable["__zip_version"] = _current_zip_version
	const RUNTIME_KEYS := ["icon_texture", "texture", "model_texture", "custom_mesh", "face_textures"]
	for block_id in catalog:
		var entry_v: Variant = catalog[block_id]
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v as Dictionary
		var save_entry := {}
		for key in entry:
			if RUNTIME_KEYS.has(key):
				continue
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
	# Restore metadata for lazy loading / cache validation.
	if d.has("__zip_path"):
		_current_zip_path = str(d["__zip_path"])
	if d.has("__zip_version"):
		_cached_catalog_version = str(d["__zip_version"])
	for key in d.keys():
		if str(key).begins_with("__"):
			d.erase(key)
	return d


## Loads an icon on-demand: tries disk cache first, then zip.
static func get_icon_lazy(block_id: String, rel_path: String, cached_file: String = "") -> Texture2D:
	if rel_path.is_empty():
		return null
	return _get_texture_cached(ICONS_DIR, block_id, rel_path, cached_file, _icon_cache, true)


## Loads a texture on-demand: tries disk cache first, then zip.
static func get_texture_lazy(block_id: String, rel_path: String, cached_file: String = "") -> Texture2D:
	if rel_path.is_empty():
		return null
	return _get_texture_cached(TEXTURES_DIR, block_id, rel_path, cached_file, _texture_cache, true)


## Loads the model atlas texture on-demand. When the catalog provides a cached
## file, use it directly (it may differ from the cube texture, e.g. ores).
static func get_model_texture_lazy(block_id: String, rel_path: String, cached_file: String = "") -> Texture2D:
	if rel_path.is_empty():
		return null
	return _get_texture_cached(TEXTURES_DIR, block_id, rel_path, cached_file, _texture_cache, false)


static func _get_texture_cached(dir_path: String, block_id: String, rel_path: String,
		cached_file: String, cache: Dictionary, allow_legacy: bool) -> Texture2D:
	var disk_path := ""
	if not cached_file.is_empty():
		disk_path = dir_path + cached_file
	elif allow_legacy:
		var legacy := dir_path + block_id + ".png"
		if FileAccess.file_exists(legacy):
			disk_path = legacy
	if not disk_path.is_empty() and FileAccess.file_exists(disk_path):
		if cache.has(disk_path):
			return cache[disk_path] as Texture2D
		var tex := _load_texture_from_disk(disk_path)
		cache[disk_path] = tex
		return tex
	# Fall back to the zip (main-thread lazy loading only).
	if _current_zip == null:
		return null
	var zip_key := "zip|" + COMMON_PREFIX + rel_path
	if cache.has(zip_key):
		return cache[zip_key] as Texture2D
	var zip_tex := _load_texture_from_zip(_current_zip, COMMON_PREFIX + rel_path)
	cache[zip_key] = zip_tex
	return zip_tex


## Loads a model mesh on-demand: tries disk cache first, then zip. Meshes are
## cached per source file + atlas size, so blocks sharing a model reuse it.
static func get_model_lazy(block_id: String, rel_path: String,
		atlas_size: Vector2i = Vector2i(64, 64), cached_file: String = "") -> Mesh:
	if rel_path.is_empty():
		return null
	var disk_path := ""
	if not cached_file.is_empty():
		disk_path = MODELS_DIR + cached_file
	else:
		var legacy := MODELS_DIR + block_id + ".json"
		if FileAccess.file_exists(legacy):
			disk_path = legacy
	if not disk_path.is_empty() and FileAccess.file_exists(disk_path):
		var key := disk_path + "|" + str(atlas_size)
		if _model_cache.has(key):
			return _model_cache[key] as Mesh
		var mesh := _load_blockymodel_from_disk(disk_path, atlas_size)
		_model_cache[key] = mesh
		return mesh
	# Fall back to zip
	if _current_zip == null:
		return null
	var zip_key := "zip|" + COMMON_PREFIX + rel_path + "|" + str(atlas_size)
	if _model_cache.has(zip_key):
		return _model_cache[zip_key] as Mesh
	var zip_mesh := _load_blockymodel_from_zip(_current_zip, COMMON_PREFIX + rel_path, atlas_size)
	_model_cache[zip_key] = zip_mesh
	return zip_mesh


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
## Reopens only when the requested path differs from the currently open zip.
static func reopen_zip() -> void:
	if _current_zip != null and _opened_zip_path == _current_zip_path:
		return
	if _current_zip != null:
		_current_zip.close()
		_current_zip = null
	_opened_zip_path = ""
	if not _current_zip_path.is_empty() and FileAccess.file_exists(_current_zip_path):
		var zip := ZIPReader.new()
		if zip.open(_current_zip_path) == OK:
			_current_zip = zip
			_opened_zip_path = _current_zip_path
