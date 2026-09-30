class_name SceneBuilder
extends RefCounted

## Builds a Godot scene from BlockyModelData + BlockyAnimData (for preview and
## GLB export), and converts AnimationPlayer animations into BlockyAnimData.

const SHAPE_NODE_NAME := "_Shape"


static func blocky_to_scene_units(v: Vector3) -> Vector3:
	return v / BlockySettings.current.block_size


static func scene_to_blocky_units(v: Vector3) -> Vector3:
	return v * BlockySettings.current.block_size


# ---------------------------------------------------------------------------
# Scene construction
# ---------------------------------------------------------------------------

static func build_scene(model: BlockyModelData, root_name: String = "BlockyModel") -> Node3D:
	var root := Node3D.new()
	root.name = root_name
	for n in model.nodes:
		var node := build_node(n)
		root.add_child(node)
	return root


static func build_node(data: BlockyNodeData) -> Node3D:
	return build_node_under(data, Vector3.ZERO)


## `parent_offset` is the parent node's shape offset (blocky units). Children of
## a node are positioned relative to the parent's mesh center (pivot + offset),
## which matches the blockymodel hierarchy semantics.
static func build_node_under(data: BlockyNodeData, parent_offset: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = data.name
	var t := Transform3D(Basis(data.orientation), blocky_to_scene_units(parent_offset + data.position))
	pivot.transform = t
	# Guardar pose de reposo para huesos con geometría (para reset al cambiar animación)
	if data.has_geometry():
		pivot.set_meta("rest_position", pivot.position)
		pivot.set_meta("rest_rotation", pivot.quaternion)
	if not data.has_geometry():
		pivot.visible = data.visible
	else:
		var shape := MeshInstance3D.new()
		shape.name = SHAPE_NODE_NAME
		if data.shape_type == "box":
			shape.mesh = MeshGen.make_box_mesh(data, BlockySettings.current.atlas_size)
		else:
			shape.mesh = MeshGen.make_quad_mesh(data, BlockySettings.current.atlas_size)
		shape.transform.origin = blocky_to_scene_units(data.shape_offset)
		shape.visible = data.visible
		shape.material_override = build_material(data)
		pivot.add_child(shape)
	for child in data.children:
		pivot.add_child(build_node_under(child, data.shape_offset))
	return pivot


static var _shared_material: StandardMaterial3D = null
static var _shared_material_atlas: Texture2D = null

## Todos los nodos comparten UNA sola instancia de material (un único atlas),
## igual que Blockbench, que trabaja con una sola textura. Así el GLB exportado
## lleva exactamente 1 material en lugar de uno por nodo.
static func build_material(_data: BlockyNodeData) -> StandardMaterial3D:
	if _shared_material == null or _shared_material_atlas != BlockySettings.current.atlas_texture:
		_shared_material = _make_material()
		_shared_material_atlas = BlockySettings.current.atlas_texture
	return _shared_material


static func _make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tex := BlockySettings.current.atlas_texture
	if tex != null:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_triplanar = false
		# Recorte por alpha: los píxeles transparentes del atlas no se pintan
		# (Blockbench/Blender usan cutout, no translucidez).
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	else:
		mat.albedo_color = Color(0.8, 0.8, 0.85)
	# Preview sin backface culling y sin iluminación direccional (unlit):
	# ninguna cara queda negra ni se oculta desde el interior; el atlas se ve
	# con su color exacto. El flag doubleSided se conserva en BlockyNodeData y
	# en el .blockymodel; el importador no depende del cull del material.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


# ---------------------------------------------------------------------------
# Animation construction (BlockyAnimData -> AnimationPlayer)
# ---------------------------------------------------------------------------

static func build_animation_player(anims: Array, root: Node = null) -> AnimationPlayer:
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	var name_paths := _collect_name_paths(root)
	for item in anims:
		if not (item is BlockyAnimData):
			continue
		var anim_data: BlockyAnimData = item
		var anim := build_animation(anim_data, name_paths, root)
		if anim == null:
			continue
		var a_name: String = anim_data.anim_name
		if a_name.is_empty():
			a_name = "Animation"
		lib.add_animation(a_name, anim)
	ap.add_animation_library("", lib)
	return ap


## Maps every node name to the list of full NodePaths (relative to `root`)
## where it appears, so animation tracks can resolve even with duplicated
## names or nested nodes. Only Node3D nodes are collected.
static func _collect_name_paths(root: Node) -> Dictionary:
	var out := {}
	if root == null:
		return out
	for c in root.get_children():
		_collect_name_paths_recursive(c, NodePath(c.name), out)
	return out


static func _collect_name_paths_recursive(node: Node, path: NodePath, out: Dictionary) -> void:
	if node is Node3D:
		if not out.has(node.name):
			out[node.name] = []
		(out[node.name] as Array).append(path)
	for c in node.get_children():
		_collect_name_paths_recursive(c, NodePath(str(path) + "/" + c.name), out)


## Picks the best target path for a channel. For shape channels the node must
## have a child `_Shape`; otherwise any Node3D with that name works. Returns an
## empty NodePath if nothing resolves.
## Resolves the target node path for a blockyanim node name. With duplicate
## names it prefers the occurrence that has a `_Shape` child (en Hytale los
## huesos suelen ser las cajas), so all channels of a node animate the same
## bone. Returns an empty NodePath when nothing resolves.
static func _resolve_node(candidates: Array, root: Node, need_shape: bool) -> NodePath:
	var any_existing := NodePath()
	for p in candidates:
		if root != null and root.get_node_or_null(p) == null:
			continue
		if any_existing == NodePath():
			any_existing = p
		if _has_shape(root, p):
			return p
	if need_shape:
		return NodePath()
	return any_existing


static func _has_shape(root: Node, p: NodePath) -> bool:
	return root != null and root.get_node_or_null(NodePath(str(p) + "/" + SHAPE_NODE_NAME)) != null


static func build_animation(data: BlockyAnimData, name_paths: Dictionary = {}, root: Node = null) -> Animation:
	if data.node_animations.is_empty():
		return null
	var anim := Animation.new()
	anim.length = float(data.duration) / float(BlockyAnimData.ANIM_FPS)
	anim.loop_mode = Animation.LOOP_NONE if data.hold_last_keyframe else Animation.LOOP_LINEAR

	for node_name in data.node_animations:
		var candidates: Array = name_paths.get(node_name, [])
		var channels: Dictionary = data.node_animations[node_name]
		var need_shape: bool = channels.has("shapeStretch") or channels.has("shapeVisible")
		var node_path := _resolve_node(candidates, root, need_shape)
		if node_path == NodePath():
			continue
		# En blockyanim los keyframes son RELATIVOS a la pose de reposo (el
		# preview de Blockbench restaura la pose y luego suma/compone el delta).
		# Horneamos valores absolutos = pose de reposo + delta, leídos del árbol.
		var rest_node := root.get_node_or_null(node_path) as Node3D if root != null else null
		var rest_pos := rest_node.position if rest_node != null else Vector3.ZERO
		var rest_rot := rest_node.quaternion if rest_node != null else Quaternion.IDENTITY
		for channel in channels:
			var kf_arr: Array = channels[channel]
			if kf_arr.is_empty():
				continue
			var track := -1
			match channel:
				"position":
					track = anim.add_track(Animation.TYPE_POSITION_3D)
					anim.track_set_path(track, node_path)
				"orientation":
					track = anim.add_track(Animation.TYPE_ROTATION_3D)
					anim.track_set_path(track, node_path)
				"shapeStretch":
					track = anim.add_track(Animation.TYPE_SCALE_3D)
					anim.track_set_path(track, NodePath(str(node_path) + "/" + SHAPE_NODE_NAME))
				"shapeVisible":
					track = anim.add_track(Animation.TYPE_VALUE)
					anim.track_set_path(track, NodePath(str(node_path) + "/" + SHAPE_NODE_NAME + ":visible"))
				_:
					continue
			var cubic := false
			for kf in kf_arr:
				var t := float(int(kf["time"])) / float(BlockyAnimData.ANIM_FPS)
				var delta = kf["delta"]
				if str(kf.get("interpolationType", "linear")) == "smooth":
					cubic = true
				var value
				if channel == "position":
					# Delta relativo a la pose de reposo (unidades de cuadrícula)
					# + posición estática del hueso.
					value = rest_pos + blocky_to_scene_units(delta as Vector3)
				elif channel == "orientation":
					# Rotación relativa: completa = reposo * delta.
					value = (rest_rot * (delta as Quaternion).normalized())
				elif channel == "shapeStretch":
					# shapeStretch es un multiplicador de escala sin dimensiones
					# (1 = tamaño normal), igual que cube.stretch en Blockbench.
					value = delta as Vector3
				else:
					value = delta
				anim.track_insert_key(track, t, value)
			anim.track_set_interpolation_type(
				track,
				Animation.INTERPOLATION_CUBIC if cubic else Animation.INTERPOLATION_LINEAR)
	return anim


# ---------------------------------------------------------------------------
# Reading animations out of a scene (used by the GLB importer)
# ---------------------------------------------------------------------------

static func find_animation_player(scene: Node) -> AnimationPlayer:
	if scene == null:
		return null
	if scene is AnimationPlayer:
		return scene
	for c in scene.get_children():
		var found := find_animation_player(c)
		if found != null:
			return found
	return null


static func read_animations_from_player(ap: AnimationPlayer) -> Array:
	var out: Array = []
	if ap == null:
		return out
	for a_name in ap.get_animation_list():
		out.append(BlockyAnimData.from_animation_player(ap, a_name))
	return out
