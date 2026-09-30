class_name BlockyNodeData
extends RefCounted

## A node in a Hytale BlockyModel.
##
## Shape semantics (matches the official Blockbench Hytale plugin):
## - `position` is the node pivot, relative to the parent node's mesh center.
## - `shape_offset` is the box/quad center, relative to the node pivot, in the
##   node's pre-rotation frame.
## - `size` is in blocky pixels (1 block = BlockySettings.block_size).
## - Quads are flat planes; `quad_normal` is the plane normal, and `size`
##   holds (width, height, 0).

const FACE_NAMES := ["front", "back", "left", "right", "top", "bottom"]

var id: String = ""
var name: String = ""
var position := Vector3.ZERO
var orientation := Quaternion.IDENTITY

var shape_type: String = "none"       # "box" | "quad" | "none"
var shape_offset := Vector3.ZERO
var stretch := Vector3.ONE
var size := Vector3.ZERO
var quad_normal := Vector3.FORWARD     # quads only
var visible := true
var double_sided := false
var shading_mode: String = "standard"
var unwrap_mode: String = "custom"
var is_piece := false
var is_static_box := false
var texture_layout := {}              # face -> {"offset":Vector2, "mirror":Vector2, "angle":int}

var children: Array[BlockyNodeData] = []


func has_geometry() -> bool:
	return shape_type == "box" or shape_type == "quad"


func count_including_children() -> int:
	var total := 1
	for c in children:
		total += c.count_including_children()
	return total


func collect_names(out: Array[String]) -> void:
	out.append(name)
	for c in children:
		c.collect_names(out)


func collect_nodes(out: Array) -> void:
	out.append(self)
	for c in children:
		c.collect_nodes(out)


func rebuild_ids(counter: Array) -> void:
	id = str(counter[0])
	counter[0] += 1
	for c in children:
		c.rebuild_ids(counter)


func clone_deep() -> BlockyNodeData:
	var n := BlockyNodeData.new()
	n.id = id
	n.name = name
	n.position = position
	n.orientation = orientation
	n.shape_type = shape_type
	n.shape_offset = shape_offset
	n.stretch = stretch
	n.size = size
	n.quad_normal = quad_normal
	n.visible = visible
	n.double_sided = double_sided
	n.shading_mode = shading_mode
	n.unwrap_mode = unwrap_mode
	n.is_piece = is_piece
	n.is_static_box = is_static_box
	for key in texture_layout:
		n.texture_layout[key] = texture_layout[key].duplicate(true)
	for c in children:
		n.children.append(c.clone_deep())
	return n


# ---------------------------------------------------------------------------
# JSON serialization
# ---------------------------------------------------------------------------

static func _vec3(v: Vector3) -> Dictionary:
	return {"x": _num(v.x), "y": _num(v.y), "z": _num(v.z)}


static func _vec2(v: Vector2) -> Dictionary:
	return {"x": _num(v.x), "y": _num(v.y)}


static func _quat(q: Quaternion) -> Dictionary:
	return {"x": _num(q.x), "y": _num(q.y), "z": _num(q.z), "w": _num(q.w)}


static func _num(f: float) -> float:
	return snappedf(f, 0.0001)


func to_dict() -> Dictionary:
	var d := {
		"id": id,
		"name": name,
		"position": _vec3(position),
		"orientation": _quat(orientation),
		"shape": {
			"type": shape_type,
			"offset": _vec3(shape_offset),
			"stretch": _vec3(stretch),
			"settings": {},
			"visible": visible,
			"doubleSided": double_sided,
			"shadingMode": shading_mode,
			"unwrapMode": unwrap_mode,
			"textureLayout": {},
		},
	}
	if shape_type == "box":
		d["shape"]["settings"]["size"] = _vec3(size)
	elif shape_type == "quad":
		d["shape"]["settings"]["size"] = {"x": _num(size.x), "y": _num(size.y)}
		d["shape"]["settings"]["normal"] = quad_normal_str()
	if is_piece:
		d["shape"]["settings"]["isPiece"] = true
	if is_static_box:
		d["shape"]["settings"]["isStaticBox"] = true
	var tlayout := {}
	for face in texture_layout:
		var data: Dictionary = texture_layout[face]
		tlayout[face] = {
			"offset": _vec2(data.get("offset", Vector2.ZERO)),
			"mirror": {
				"x": bool(data.get("mirror", Vector2.ZERO).x),
				"y": bool(data.get("mirror", Vector2.ZERO).y),
			},
			"angle": int(data.get("angle", 0)),
		}
	d["shape"]["textureLayout"] = tlayout
	if not children.is_empty():
		var arr: Array = []
		for c in children:
			arr.append(c.to_dict())
		d["children"] = arr
	return d


func quad_normal_str() -> String:
	if absf(quad_normal.x) > 0.5:
		return "+X" if quad_normal.x > 0 else "-X"
	if absf(quad_normal.y) > 0.5:
		return "+Y" if quad_normal.y > 0 else "-Y"
	return "+Z" if quad_normal.z > 0 else "-Z"


static func _read_vec3(d: Dictionary, key: String) -> Vector3:
	if not d.has(key):
		return Vector3.ZERO
	var v = d[key]
	if v is Dictionary:
		return Vector3(
			float(v.get("x", 0.0)),
			float(v.get("y", 0.0)),
			float(v.get("z", 0.0)))
	return Vector3.ZERO


static func _read_vec2(d: Dictionary, key: String) -> Vector2:
	if not d.has(key):
		return Vector2.ZERO
	var v = d[key]
	if v is Dictionary:
		return Vector2(
			float(v.get("x", 0.0)),
			float(v.get("y", 0.0)))
	return Vector2.ZERO


static func _read_quat(d: Dictionary, key: String) -> Quaternion:
	if not d.has(key):
		return Quaternion.IDENTITY
	var v = d[key]
	if v is Dictionary:
		return Quaternion(
			float(v.get("x", 0.0)),
			float(v.get("y", 0.0)),
			float(v.get("z", 0.0)),
			float(v.get("w", 1.0))).normalized()
	return Quaternion.IDENTITY


static func _parse_normal(v) -> Vector3:
	if v is String:
		match v:
			"+X": return Vector3.RIGHT
			"-X": return Vector3.LEFT
			"+Y": return Vector3.UP
			"-Y": return Vector3.DOWN
			"-Z": return Vector3.BACK
			_: return Vector3.FORWARD
	if v is Dictionary:
		return _read_vec3(v, "")
	return Vector3.FORWARD


static func from_dict(d: Dictionary) -> BlockyNodeData:
	var n := BlockyNodeData.new()
	n.id = str(d.get("id", ""))
	n.name = str(d.get("name", n.id))
	n.position = _read_vec3(d, "position")
	n.orientation = _read_quat(d, "orientation")
	var shape: Dictionary = d.get("shape", {})
	if not shape.is_empty():
		n.shape_type = str(shape.get("type", "none"))
		n.shape_offset = _read_vec3(shape, "offset")
		n.stretch = _read_vec3(shape, "stretch")
		n.visible = bool(shape.get("visible", true))
		n.double_sided = bool(shape.get("doubleSided", false))
		n.shading_mode = str(shape.get("shadingMode", "standard"))
		n.unwrap_mode = str(shape.get("unwrapMode", "custom"))
		var settings: Dictionary = shape.get("settings", {})
		if settings.has("size"):
			var s = settings["size"]
			if s is Dictionary:
				n.size.x = float(s.get("x", 0.0))
				n.size.y = float(s.get("y", 0.0))
				n.size.z = float(s.get("z", 0.0))
		if settings.has("normal"):
			n.quad_normal = _parse_normal(settings["normal"])
		n.is_piece = bool(settings.get("isPiece", false))
		n.is_static_box = bool(settings.get("isStaticBox", false))
		var tlayout: Dictionary = shape.get("textureLayout", {})
		for face in tlayout:
			var fd: Dictionary = tlayout[face]
			var entry := {
				"offset": _read_vec2(fd, "offset"),
				"mirror": Vector2.ZERO,
				"angle": int(fd.get("angle", 0)),
			}
			if fd.has("mirror"):
				var mv = fd["mirror"]
				if mv is Dictionary:
					entry["mirror"] = Vector2(
						1.0 if bool(mv.get("x", false)) else 0.0,
						1.0 if bool(mv.get("y", false)) else 0.0)
			n.texture_layout[face] = entry
	if d.has("children"):
		var arr: Array = d["children"]
		for c in arr:
			if c is Dictionary:
				var child := from_dict(c)
				if child != null:
					n.children.append(child)
	return n


# ---------------------------------------------------------------------------
# UV helpers
# ---------------------------------------------------------------------------

## Returns the UV rectangle in pixels for a face: {"offset": Vector2, "size": Vector2}.
## The rectangle already includes the face size and mirror/angle transforms,
## expressed as axis-aligned bounds (min corner + size). Used by mesh_gen.
func face_uv_rect(face_name: String, face_sz: Vector2) -> Dictionary:
	var data: Dictionary = texture_layout.get(face_name, {})
	var offset: Vector2 = data.get("offset", Vector2.ZERO)
	var angle := int(data.get("angle", 0))
	var mirror: Vector2 = data.get("mirror", Vector2.ZERO)
	var w := face_sz.x
	var h := face_sz.y
	# Rotated rect (width/height swapped for 90/270).
	var rotated := angle == 90 or angle == 270
	var rw: float = h if rotated else w
	var rh: float = w if rotated else h
	var out := {
		"offset": offset,
		"size": Vector2(rw, rh),
		"angle": angle,
		"mirror": mirror,
	}
	return out


## Build a default (auto) texture layout for a box of the given size, in px.
func generate_default_box_layout() -> void:
	texture_layout = {}
	var sx := maxf(size.x, 0.001)
	var sy := maxf(size.y, 0.001)
	var sz := maxf(size.z, 0.001)
	# Strip layout: front, back, right, left, then top/bottom above the strip.
	texture_layout["front"] = {"offset": Vector2(sz, sz), "mirror": Vector2.ZERO, "angle": 0}
	texture_layout["back"] = {"offset": Vector2(sz + sx, sz), "mirror": Vector2.ZERO, "angle": 0}
	texture_layout["right"] = {"offset": Vector2(sz + sx + sx, sz), "mirror": Vector2.ZERO, "angle": 0}
	texture_layout["left"] = {"offset": Vector2(sz + sx + sx + sz, sz), "mirror": Vector2.ZERO, "angle": 0}
	texture_layout["top"] = {"offset": Vector2(sz + sx + sx, 0), "mirror": Vector2.ZERO, "angle": 0}
	texture_layout["bottom"] = {"offset": Vector2(sz + sx + sx, sz + sy), "mirror": Vector2.ZERO, "angle": 0}


func generate_default_quad_layout() -> void:
	texture_layout = {
		"front": {"offset": Vector2.ZERO, "mirror": Vector2.ZERO, "angle": 0},
	}


## Standard face size in px for a given face of the box.
func face_size(face_name: String) -> Vector2:
	var sx := maxf(size.x, 0.001)
	var sy := maxf(size.y, 0.001)
	var sz := maxf(size.z, 0.001)
	match face_name:
		"front", "back":
			return Vector2(sx, sy)
		"left", "right":
			return Vector2(sz, sy)
		"top", "bottom":
			return Vector2(sx, sz)
	return Vector2(sx, sy)
