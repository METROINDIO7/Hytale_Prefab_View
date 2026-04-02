class_name BlockRenderer
extends Node3D

const BLOCK_SIZE := 1.0

signal blocks_changed(total: int, unique_types: int)

# ── Group data ────────────────────────────────────────────────────────────────
class GroupData:
	var name    : String
	var label   : String = ""
	var blocks  : Dictionary = {}
	var node    : Node3D
	var color   : Color

const DEFAULT_GROUP := "Default"
const GROUP_COLORS : Array = [
	Color(0.30, 0.65, 1.00), Color(0.40, 0.90, 0.45),
	Color(1.00, 0.70, 0.20), Color(0.90, 0.35, 0.35),
	Color(0.75, 0.45, 1.00), Color(0.30, 0.90, 0.80),
	Color(1.00, 0.85, 0.25), Color(0.80, 0.55, 0.30),
]

# ── Instance variables ────────────────────────────────────────────────────────
var _groups            : Dictionary = {}
var _color_index       : int = 0
var _render_mesh_cache : Dictionary = {}
var _dirty_groups      : Dictionary = {}
var _rebuild_scheduled : bool = false
var _bulk_edit_depth   : int = 0
var _needs_change_emit : bool = false

# ── Categories for auto-color (19 categories, cleaned) ───────────────────────
const _CATEGORIES : Array = [
	["Beams",              Color(0.65, 0.52, 0.38)],  # (11)
	["Bone",               Color(0.75, 0.75, 0.75)],  # (3)
	["Build_Black_Cube",   Color(0.60, 0.70, 0.75)],  # (58)
	["Clay",               Color(0.72, 0.45, 0.35)],  # (19)
	["Cloth_Block_Wool",   Color(0.85, 0.48, 0.65)],  # (60)
	["Deco_Iron_Bars",     Color(0.75, 0.75, 0.75)],  # (4)
	["Dirt",               Color(0.52, 0.36, 0.20)],  # (17)
	["Fluid_Lava",         Color(0.85, 0.40, 0.10)],  # (6)
	["Metal_Iron",         Color(0.72, 0.74, 0.78)],  # (80)
	["Ore_Iron_Basalt",    Color(0.68, 0.55, 0.48)],  # (14)
	["Planks",             Color(0.62, 0.42, 0.22)],  # (11)
	["Rock_Stone_Brick",   Color(0.55, 0.55, 0.58)],  # (608)
	["Rubble_Stone",       Color(0.52, 0.50, 0.48)],  # (32)
	["Sand",               Color(0.90, 0.82, 0.55)],  # (19)
	["Snow",               Color(0.92, 0.94, 0.98)],  # (14)
	["Soil",               Color(0.28, 0.62, 0.22)],  # (128)
	["Wood",               Color(0.62, 0.42, 0.22)],  # (356)
	["Wood Dec",           Color(0.65, 0.52, 0.38)],  # (11)
	["Wood Orn",           Color(0.75, 0.62, 0.42)],  # (11)
]


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	create_group(DEFAULT_GROUP)


# ── Group management ──────────────────────────────────────────────────────────

func create_group(gname: String) -> GroupData:
	if _groups.has(gname):
		return _groups[gname]
	var gd := GroupData.new()
	gd.name = gname
	gd.color = GROUP_COLORS[_color_index % GROUP_COLORS.size()]
	_color_index += 1
	gd.node = Node3D.new()
	gd.node.name = gname
	add_child(gd.node)
	_groups[gname] = gd
	return gd


func remove_group(gname: String) -> void:
	if gname == DEFAULT_GROUP:
		push_warning("[BR] Cannot remove the Default group.")
		return
	if not _groups.has(gname):
		return

	var gd: GroupData = _groups[gname]

	# Free the Node3D (and all its MultiMeshInstance3D children) and discard
	# all block data — blocks are NOT migrated to another group.
	gd.node.queue_free()
	_groups.erase(gname)

	_emit_changed()

func set_group_visible(gname: String, visi: bool) -> void:
	if _groups.has(gname):
		(_groups[gname] as GroupData).node.visible = visi


func is_group_visible(gname: String) -> bool:
	if _groups.has(gname):
		return (_groups[gname] as GroupData).node.visible
	return true


func rename_group_label(gname: String, label: String) -> void:
	if _groups.has(gname):
		(_groups[gname] as GroupData).label = label


func get_group_names() -> Array:
	return _groups.keys()


func get_group_data(gname: String) -> GroupData:
	return _groups.get(gname, null)


func get_preview_color(bname: String) -> Color:
	return _get_color(bname)


func show_all_groups() -> void:
	for gn in _groups:
		(_groups[gn] as GroupData).node.visible = true


func hide_all_groups() -> void:
	for gn in _groups:
		(_groups[gn] as GroupData).node.visible = false


# ── Block CRUD ────────────────────────────────────────────────────────────────

func begin_bulk_edit() -> void:
	_bulk_edit_depth += 1


func end_bulk_edit() -> void:
	_bulk_edit_depth = maxi(0, _bulk_edit_depth - 1)
	if _bulk_edit_depth == 0:
		_queue_rebuild_flush()


func add_block(pos: Vector3i, bname: String, group: String = DEFAULT_GROUP) -> bool:
	if not _groups.has(group):
		create_group(group)
	
	var key := _key(pos.x, pos.y, pos.z)
	var old_value = (_groups[group] as GroupData).blocks.get(key, null)
	if old_value == bname:
		return false
	
	(_groups[group] as GroupData).blocks[key] = bname
	_mark_group_dirty(group)
	return true


func remove_block(pos: Vector3i) -> bool:
	var k := _key(pos.x, pos.y, pos.z)
	for gn in _groups:
		if (_groups[gn] as GroupData).blocks.has(k):
			(_groups[gn] as GroupData).blocks.erase(k)
			_mark_group_dirty(String(gn))
			return true
	return false


func has_block(pos: Vector3i) -> bool:
	var k := _key(pos.x, pos.y, pos.z)
	for gn in _groups:
		if (_groups[gn] as GroupData).blocks.has(k):
			return true
	return false


func get_block_at(pos: Vector3i) -> String:
	var k := _key(pos.x, pos.y, pos.z)
	for gn in _groups:
		if (_groups[gn] as GroupData).blocks.has(k):
			return (_groups[gn] as GroupData).blocks[k]
	return ""


func get_all_blocks() -> Dictionary:
	var merged: Dictionary = {}
	for gn in _groups:
		for k in (_groups[gn] as GroupData).blocks:
			merged[k] = (_groups[gn] as GroupData).blocks[k]
	return merged


func get_block_count() -> int:
	var n := 0
	for gn in _groups:
		n += (_groups[gn] as GroupData).blocks.size()
	return n


func load_from_prefab(data: Dictionary) -> void:
	clear_all()
	if data.has("blocks"):
		for b in data["blocks"]:
			add_block(
				Vector3i(b.get("x", 0), b.get("y", 0), b.get("z", 0)),
				b.get("name", "Unknown"),
				DEFAULT_GROUP
			)
	rebuild_all()


func clear_all() -> void:
	for gn in _groups.keys():
		(_groups[gn] as GroupData).node.queue_free()
	_groups.clear()
	_color_index = 0
	_render_mesh_cache.clear()
	_dirty_groups.clear()
	_rebuild_scheduled = false
	_bulk_edit_depth = 0
	_needs_change_emit = false
	create_group(DEFAULT_GROUP)


# ── Rebuild geometry ──────────────────────────────────────────────────────────

func rebuild_all() -> void:
	_dirty_groups.clear()
	_rebuild_scheduled = false
	for gn in _groups:
		rebuild_group(gn)
	_needs_change_emit = false
	_emit_changed()


func _mark_group_dirty(gname: String) -> void:
	_dirty_groups[gname] = true
	_needs_change_emit = true
	_queue_rebuild_flush()


func _queue_rebuild_flush() -> void:
	if _rebuild_scheduled:
		return
	_rebuild_scheduled = true
	call_deferred("_flush_dirty_groups")


func _flush_dirty_groups() -> void:
	_rebuild_scheduled = false
	var dirty_names := _dirty_groups.keys()
	_dirty_groups.clear()
	for gn in dirty_names:
		rebuild_group(String(gn))
	
	if _bulk_edit_depth == 0 and _needs_change_emit:
		_needs_change_emit = false
		_emit_changed()


func rebuild_group(gname: String) -> void:
	if not _groups.has(gname):
		return
	var gd: GroupData = _groups[gname]
	for c in gd.node.get_children():
		c.queue_free()

	if gd.blocks.is_empty():
		return

	var batches: Dictionary = {}
	for k in gd.blocks:
		var bname: String = gd.blocks[k]
		if not batches.has(bname):
			batches[bname] = {
				"mesh": _get_render_mesh(bname),
				"transforms": []
			}
		var p = k.split(",")
		var t := Transform3D()
		t.origin = Vector3(int(p[0]), int(p[1]), int(p[2])) * BLOCK_SIZE
		batches[bname]["transforms"].append(t)

	for bname in batches:
		var mesh: Mesh = batches[bname]["mesh"]
		var tfs: Array = batches[bname]["transforms"]
		if mesh == null or tfs.is_empty():
			continue
		
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = tfs.size()
		for i in range(tfs.size()):
			mm.set_instance_transform(i, tfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		gd.node.add_child(mmi)


func _get_render_mesh(bname: String) -> Mesh:
	if _render_mesh_cache.has(bname):
		return _render_mesh_cache[bname] as Mesh
	
	var block_def := BlockCatalog.get_definition(bname)
	if block_def.is_empty():
		print("No definition for ", bname)
		return null
	
	var mesh := block_def.get("custom_mesh", null) as Mesh
	if mesh != null:
		mesh = mesh.duplicate(true)
	else:
		# Create custom cube mesh with proper UVs for full texture per face
		mesh = _create_cube_mesh_with_full_uvs()
	
	var material := _build_block_material(block_def, _get_color(bname))
	_apply_material_to_mesh(mesh, material)
	_render_mesh_cache[bname] = mesh
	return mesh


func _build_block_material(block_def: Dictionary, base_color: Color) -> Material:
	var mat := StandardMaterial3D.new()
	var albedo := block_def.get("fallback_color", base_color) as Color
	mat.albedo_color = albedo
	mat.roughness = 0.75
	mat.metallic = 0.05
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # Disable culling to show both sides
	
	var tex := block_def.get("albedo_texture", null) as Texture2D
	print("Texture for ", block_def.get("block_id", "unknown"), ": ", tex != null)
	if tex != null:
		mat.albedo_texture = tex
	
	if albedo.a < 1.0:
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	
	return mat


func _create_cube_mesh_with_full_uvs() -> Mesh:
	# Create a cube mesh with proper UVs so each face uses the full texture (0-1 UVs)
	var mesh := ArrayMesh.new()
	
	var size := BLOCK_SIZE * 0.97
	var half_size := size * 0.5
	
	# Define vertices for a cube (counter-clockwise winding for correct normals)
	var vertices := PackedVector3Array([
		# Front face (Z+)
		Vector3(-half_size, -half_size, half_size),  # bottom-left
		Vector3(half_size, -half_size, half_size),   # bottom-right
		Vector3(half_size, half_size, half_size),    # top-right
		Vector3(-half_size, half_size, half_size),   # top-left
		
		# Back face (Z-)
		Vector3(half_size, -half_size, -half_size),   # bottom-left
		Vector3(-half_size, -half_size, -half_size),  # bottom-right
		Vector3(-half_size, half_size, -half_size),   # top-right
		Vector3(half_size, half_size, -half_size),    # top-left
		
		# Left face (X-)
		Vector3(-half_size, -half_size, -half_size),  # bottom-left
		Vector3(-half_size, -half_size, half_size),   # bottom-right
		Vector3(-half_size, half_size, half_size),    # top-right
		Vector3(-half_size, half_size, -half_size),   # top-left
		
		# Right face (X+)
		Vector3(half_size, -half_size, half_size),    # bottom-left
		Vector3(half_size, -half_size, -half_size),   # bottom-right
		Vector3(half_size, half_size, -half_size),    # top-right
		Vector3(half_size, half_size, half_size),     # top-left
		
		# Top face (Y+)
		Vector3(-half_size, half_size, half_size),    # bottom-left
		Vector3(half_size, half_size, half_size),     # bottom-right
		Vector3(half_size, half_size, -half_size),    # top-right
		Vector3(-half_size, half_size, -half_size),   # top-left
		
		# Bottom face (Y-)
		Vector3(-half_size, -half_size, -half_size),  # bottom-left
		Vector3(half_size, -half_size, -half_size),   # bottom-right
		Vector3(half_size, -half_size, half_size),    # top-right
		Vector3(-half_size, -half_size, half_size)    # top-left
	])
	
	# UVs - each face uses full texture (0-1), corrected for proper orientation
	var uvs := PackedVector2Array()
	for i in range(6):  # 6 faces
		uvs.append_array([
			Vector2(0, 1),  # bottom-left
			Vector2(1, 1),  # bottom-right
			Vector2(1, 0),  # top-right
			Vector2(0, 0)   # top-left
		])
	
	# Normals (one per vertex, inverted for correct culling)
	var normals := PackedVector3Array([
		# Front (Z- - inverted)
		Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1),
		# Back (Z+ - inverted)
		Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1),
		# Left (X+ - inverted)
		Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0),
		# Right (X- - inverted)
		Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0),
		# Top (Y- - inverted)
		Vector3(0, -1, 0), Vector3(0, -1, 0), Vector3(0, -1, 0), Vector3(0, -1, 0),
		# Bottom (Y+ - inverted)
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0)
	])
	
	# Indices for triangles (clockwise winding to match inverted normals)
	var indices := PackedInt32Array([
		# Front face (0-3) - clockwise
		0, 1, 2, 2, 3, 0,
		# Back face (4-7) - clockwise
		4, 5, 6, 6, 7, 4,
		# Left face (8-11) - clockwise
		8, 9, 10, 10, 11, 8,
		# Right face (12-15) - clockwise
		12, 13, 14, 14, 15, 12,
		# Top face (16-19) - clockwise
		16, 17, 18, 18, 19, 16,
		# Bottom face (20-23) - clockwise
		20, 21, 22, 22, 23, 20
	])
	
	# Create arrays
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	# Add surface
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh


func _apply_material_to_mesh(mesh: Mesh, material: Material) -> void:
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = material
		return
	
	for surface in range(mesh.get_surface_count()):
		mesh.surface_set_material(surface, material)


func _emit_changed() -> void:
	var total := 0
	var types: Dictionary = {}
	for gn in _groups:
		for k in (_groups[gn] as GroupData).blocks:
			total += 1
			types[(_groups[gn] as GroupData).blocks[k]] = true
	blocks_changed.emit(total, types.size())


func get_bounds() -> Dictionary:
	var all := get_all_blocks()
	if all.is_empty():
		return {}
	var mnx := INF
	var mny := INF
	var mnz := INF
	var mxx := -INF
	var mxy := -INF
	var mxz := -INF
	for k in all:
		var p = k.split(",")
		var x := float(p[0])
		var y := float(p[1])
		var z := float(p[2])
		if x < mnx: mnx = x
		if y < mny: mny = y
		if z < mnz: mnz = z
		if x > mxx: mxx = x
		if y > mxy: mxy = y
		if z > mxz: mxz = z
	var bmin := Vector3(mnx, mny, mnz)
	var bmax := Vector3(mxx, mxy, mxz)
	var bsize := bmax - bmin + Vector3.ONE
	return {"min": bmin, "max": bmax, "size": bsize, "center": bmin + bsize * 0.5}


func get_center() -> Vector3:
	return get_bounds().get("center", Vector3.ZERO)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _key(x: int, y: int, z: int) -> String:
	return "%d,%d,%d" % [x, y, z]


func _get_color(bname: String) -> Color:
	var low := bname.to_lower()
	for e in _CATEGORIES:
		if low.contains(e[0].to_lower()):
			return e[1]
	var h := bname.hash()
	return Color(
		0.35 + (h & 0xFF) / 510.0,
		0.35 + ((h >> 8) & 0xFF) / 510.0,
		0.35 + ((h >> 16) & 0xFF) / 510.0
	)
