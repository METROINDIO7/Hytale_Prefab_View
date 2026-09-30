class_name MeshGen
extends RefCounted

## Builds Godot ArrayMesh objects for blockymodel box/quad shapes, with UVs
## that match the official Blockbench Hytale plugin rendering (the reference
## for what the game shows):
## - Per-face quad vertex order follows Blockbench's cube `setShape`, and UVs
##   are assigned by `updateUV` in plain A,B,C,D grid order.
## - UV rectangles are derived from textureLayout offset/mirror/angle exactly
##   like the plugin's import code, and the per-vertex assignment follows
##   Blockbench's `updateUV` (which flips the atlas v axis for three.js).
##
## Winding is corrected per face so front faces point outward (Godot front
## faces have their right-hand cross product toward the viewer).

## Blockbench vertex index -> our corner index (see _corner()).
## BB 0=(+x,+y,+z) 1=(+x,+y,-z) 2=(+x,-y,+z) 3=(+x,-y,-z)
## BB 4=(-x,+y,-z) 5=(-x,+y,+z) 6=(-x,-y,-z) 7=(-x,-y,+z)
const _BB_TO_CORNER := [2, 6, 1, 5, 7, 3, 4, 0]

## Geometry vertex order per face, in A,B,C,D (UV grid) order matching
## Blockbench's `setShape` + `updateUV` (the reference renderer): the four
## positions of each face are assigned UVs in a plain grid, A=(u0,v0) top-left,
## B=(u1,v0) top-right, C=(u0,v1) bottom-left, D=(u1,v1) bottom-right.
## Corners use our numbering (see _corner()). Hytale face -> Blockbench
## direction: front=south, back=north, right=east, left=west, top=up, bottom=down.
## NOTE: this is intentionally NOT getVertexIndices(); that list is used only for
## editing/painting and its C/D order is swapped relative to the rendered mesh.
const FACE_CORNERS := {
	"front": [3, 2, 0, 1],
	"back": [6, 7, 5, 4],
	"right": [2, 6, 1, 5],
	"left": [7, 3, 4, 0],
	"top": [7, 6, 3, 2],
	"bottom": [0, 1, 4, 5],
}

const FACE_NORMALS := {
	"front": Vector3(0.0, 0.0, 1.0),
	"back": Vector3(0.0, 0.0, -1.0),
	"left": Vector3.LEFT,
	"right": Vector3.RIGHT,
	"top": Vector3.UP,
	"bottom": Vector3.DOWN,
}


## Box corners in local space (box centered at origin, half extents given).
static func _corner(i: int, hx: float, hy: float, hz: float) -> Vector3:
	match i:
		0: return Vector3(-hx, -hy, hz)
		1: return Vector3(hx, -hy, hz)
		2: return Vector3(hx, hy, hz)
		3: return Vector3(-hx, hy, hz)
		4: return Vector3(-hx, -hy, -hz)
		5: return Vector3(hx, -hy, -hz)
		6: return Vector3(hx, hy, -hz)
		7: return Vector3(-hx, hy, -hz)
	return Vector3.ZERO


## Computes the UV rectangle [u0, v0, u1, v1] in blockymodel pixels for a face
## of the given width/height, replicating the plugin's import switch on the
## layout angle, with mirror applied via +/- 1 multipliers.
static func _layout_rect(data: Dictionary, w: float, h: float) -> Array:
	var offset: Vector2 = data.get("offset", Vector2.ZERO)
	var mirror: Vector2 = data.get("mirror", Vector2.ZERO)
	var ox := offset.x
	var oy := offset.y
	var mx := -1.0 if mirror.x > 0.5 else 1.0
	var my := -1.0 if mirror.y > 0.5 else 1.0
	match int(data.get("angle", 0)):
		90:
			return [ox, oy + w * mx, ox - h * my, oy]
		180:
			return [ox - w * mx, oy - h * my, ox, oy]
		270:
			return [ox + h * my, oy, ox, oy - w * mx]
	return [ox, oy, ox + w * mx, oy + h * my]


## Per-vertex UVs (normalized, A,B,C,D order) for a face, replicating
## Blockbench's `updateUV` (base assignment + 90-degree vertex rotation).
static func _face_uvs(data: Dictionary, w_px: float, h_px: float, atlas: Vector2) -> Array:
	var rect: Array = _layout_rect(data, w_px, h_px)
	var u0: float = rect[0]
	var v0: float = rect[1]
	var u1: float = rect[2]
	var v1: float = rect[3]
	var arr := [
		Vector2(u0, v0),
		Vector2(u1, v0),
		Vector2(u0, v1),
		Vector2(u1, v1),
	]
	var rot := int(data.get("angle", 0))
	while rot > 0:
		var a: Vector2 = arr[0]
		arr[0] = arr[2]
		arr[2] = arr[3]
		arr[3] = arr[1]
		arr[1] = a
		rot -= 90
	for i in 4:
		arr[i] = arr[i] / atlas
	return arr


static func _atlas(atlas_size: Vector2i) -> Vector2:
	return Vector2(maxi(atlas_size.x, 1), maxi(atlas_size.y, 1))


## Emits two triangles for a quad A,B,C,D with winding such that the right-hand
## cross product points toward `face_normal` (Godot front faces face the
## viewer). Vertices are stored in UV grid order (A,B,C,D = top-left, top-right,
## bottom-left, bottom-right), so the geometric boundary is A,B,D,C. Appends to
## the given arrays; `base` is the first vertex index.
static func _append_quad_face(
		verts: PackedVector3Array, _normals: PackedVector3Array,
		_uvs: PackedVector2Array, indices: PackedInt32Array,
		base: int, face_normal: Vector3) -> void:
	var c1 := (verts[base + 1] - verts[base]).cross(verts[base + 3] - verts[base])
	if c1.dot(face_normal) >= 0.0:
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 3)
		indices.append(base)
		indices.append(base + 3)
		indices.append(base + 2)
	else:
		indices.append(base)
		indices.append(base + 2)
		indices.append(base + 3)
		indices.append(base)
		indices.append(base + 3)
		indices.append(base + 1)


## Build a box mesh (centered at origin) from a BlockyNodeData.
## Returns ArrayMesh with per-face UVs.
static func make_box_mesh(node: BlockyNodeData, atlas_size: Vector2i = Vector2i(64, 64)) -> ArrayMesh:
	var s := node.size / BlockySettings.current.block_size
	var hx := s.x / 2.0
	var hy := s.y / 2.0
	var hz := s.z / 2.0
	var atlas := _atlas(atlas_size)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for face in FACE_CORNERS:
		var corner_list: Array = FACE_CORNERS[face]
		var face_normal: Vector3 = FACE_NORMALS[face]
		var fs := node.face_size(face)
		var face_uvs := _face_uvs(node.texture_layout.get(face, {}), fs.x, fs.y, atlas)
		var base := verts.size()
		for c in 4:
			var corner_index: int = corner_list[c]
			verts.append(_corner(corner_index, hx, hy, hz))
			normals.append(face_normal)
			uvs.append(face_uvs[c])
		_append_quad_face(verts, normals, uvs, indices, base, face_normal)

	return _build_mesh(verts, normals, uvs, indices)


## Returns the Hytale face that matches a quad normal direction.
static func _quad_face(n: Vector3) -> String:
	if absf(n.x) > 0.5:
		return "right" if n.x > 0 else "left"
	if absf(n.y) > 0.5:
		return "top" if n.y > 0 else "bottom"
	return "front" if n.z > 0 else "back"


## Build a flat quad mesh from a BlockyNodeData. The quad is placed in the
## plane/axes matching its normal, exactly like the flattened cube the plugin
## reconstructs for a quad node.
static func make_quad_mesh(node: BlockyNodeData, atlas_size: Vector2i = Vector2i(64, 64)) -> ArrayMesh:
	var w := node.size.x / BlockySettings.current.block_size
	var h := node.size.y / BlockySettings.current.block_size
	var atlas := _atlas(atlas_size)
	var n := node.quad_normal
	var face := _quad_face(n)

	var hx := 0.0
	var hy := 0.0
	var hz := 0.0
	if absf(n.z) > 0.5:
		hx = w / 2.0
		hy = h / 2.0
	elif absf(n.x) > 0.5:
		hy = h / 2.0
		hz = w / 2.0
	else:
		hx = w / 2.0
		hz = h / 2.0

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var corner_list: Array = FACE_CORNERS[face]
	var face_uvs := _face_uvs(node.texture_layout.get(face, {}), node.size.x, node.size.y, atlas)
	var base := 0
	for c in 4:
		var corner_index: int = corner_list[c]
		verts.append(_corner(corner_index, hx, hy, hz))
		normals.append(n)
		uvs.append(face_uvs[c])
	_append_quad_face(verts, normals, uvs, indices, base, n)

	return _build_mesh(verts, normals, uvs, indices)


static func _build_mesh(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, 0)
	return mesh
