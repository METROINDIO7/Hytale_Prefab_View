# block_editor.gd
# Paint / Erase / Select tool with:
#   - Horizontal brush (XZ plane)
#   - Vertical X brush (YZ plane)
#   - Vertical Z brush (XY plane)
#   - Brush height for vertical modes
#   - 2D and 3D selections: rectangles, circles, boxes, cylinders, spheres, pyramids
#   - Solid, hollow or border modes with configurable thickness
class_name BlockEditor
extends Node

# ── Enums ─────────────────────────────────────────────────────────────────────
enum Tool       { SELECT, PAINT, ERASE, SHAPE_SELECT }
enum BrushPlane { HORIZONTAL, VERTICAL_X, VERTICAL_Z }
enum SelShape   { RECT, CIRCLE, BOX, CYLINDER, SPHERE, PYRAMID }
enum SelMode    { SOLID, HOLLOW, BORDER }
enum SelAction  { PAINT, ERASE }

# ── Public state ──────────────────────────────────────────────────────────────
var current_tool   : Tool       = Tool.SELECT
var current_block  : String     = "Rock_Sandstone_White_Brick"
var active_group   : String     = "Default"
var edit_y         : int        = 0
var brush_size     : int        = 1
var brush_plane    : BrushPlane = BrushPlane.HORIZONTAL
var brush_height   : int        = 1
var sel_shape      : SelShape   = SelShape.RECT
var sel_mode       : SelMode    = SelMode.SOLID
var sel_action     : SelAction  = SelAction.PAINT
var sel_fill       : bool       = true
var sel_border_thickness : int  = 1

signal action_performed()
signal preview_moved(grid_pos: Vector3i)

# ── References ────────────────────────────────────────────────────────────────
var _renderer    : BlockRenderer
var _cam_ctrl    : CameraController
var _vp_ctr      : SubViewportContainer
var _sub_vp      : SubViewport

# ── Internal state ────────────────────────────────────────────────────────────
var _is_pressing : bool       = false
var _stroke_changed : bool    = false
var _last_painted: Vector3i   = Vector3i(999999, 999999, 999999)

# Selection
var _sel_active  : bool       = false
var _sel_drag    : bool       = false
var _sel_start   : Vector3i   = Vector3i.ZERO
var _sel_end     : Vector3i   = Vector3i.ZERO

# Preview meshes
var _preview_root : Node3D
var _sel_preview  : MeshInstance3D
var _hover_preview: MeshInstance3D


# ── Setup ─────────────────────────────────────────────────────────────────────

func setup(
	renderer : BlockRenderer,
	cam_ctrl : CameraController,
	vp_ctr   : SubViewportContainer,
	sub_vp   : SubViewport,
	world    : Node3D
) -> void:
	_renderer  = renderer
	_cam_ctrl  = cam_ctrl
	_vp_ctr    = vp_ctr
	_sub_vp    = sub_vp
	_build_previews(world)


func _build_previews(world: Node3D) -> void:
	_preview_root = Node3D.new()
	_preview_root.name = "PreviewRoot"
	world.add_child(_preview_root)

	# Hover preview (yellow semi-transparent cube / slab)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(1.0, 0.9, 0.15, 0.40)
	hmat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var hbox := BoxMesh.new()
	hbox.size = Vector3.ONE * 1.03
	hbox.material = hmat
	_hover_preview = MeshInstance3D.new()
	_hover_preview.mesh = hbox
	_hover_preview.visible = false
	_preview_root.add_child(_hover_preview)

	# Selection preview (cyan wire-like box)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.2, 0.9, 1.0, 0.25)
	smat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.cull_mode    = BaseMaterial3D.CULL_DISABLED
	var sbox := BoxMesh.new()
	sbox.size = Vector3.ONE
	sbox.material = smat
	_sel_preview = MeshInstance3D.new()
	_sel_preview.mesh = sbox
	_sel_preview.visible = false
	_preview_root.add_child(_sel_preview)


# ── Input handlers (called from main.gd) ─────────────────────────────────────

func handle_hover(mouse_local: Vector2) -> void:
	match current_tool:
		Tool.PAINT, Tool.ERASE:
			var gpos := _ray_to_grid(mouse_local)
			_update_hover_preview(gpos)
			preview_moved.emit(gpos)
			if _is_pressing and gpos != _last_painted:
				_apply_brush(gpos)
				_last_painted = gpos
		Tool.SHAPE_SELECT:
			if _sel_drag:
				_sel_end = _ray_to_grid(mouse_local)
				_update_sel_preview()
			else:
				_hover_preview.visible = false
		_:
			_hover_preview.visible = false


func handle_press(mouse_local: Vector2) -> void:
	match current_tool:
		Tool.PAINT, Tool.ERASE:
			_begin_stroke()
			_last_painted = Vector3i(999999, 999999, 999999)
			var gpos := _ray_to_grid(mouse_local)
			_apply_brush(gpos)
			_last_painted = gpos
		Tool.SHAPE_SELECT:
			_sel_drag  = true
			_sel_start = _ray_to_grid(mouse_local)
			_sel_end   = _sel_start


func handle_release() -> void:
	if current_tool in [Tool.PAINT, Tool.ERASE] and (_is_pressing or _stroke_changed):
		_finish_stroke()
	if current_tool == Tool.SHAPE_SELECT and _sel_drag:
		_sel_drag   = false
		_sel_active = true
		_update_sel_preview()


func handle_exit() -> void:
	if current_tool in [Tool.PAINT, Tool.ERASE] and (_is_pressing or _stroke_changed):
		_finish_stroke()
	_sel_drag    = false
	_hover_preview.visible = false


# ── Public setters ────────────────────────────────────────────────────────────

func set_tool(t: Tool) -> void:
	current_tool = t
	_is_pressing = false
	_hover_preview.visible = false
	if t != Tool.SHAPE_SELECT:
		_sel_preview.visible = false
		_sel_active = false


func set_block_name(n: String) -> void: current_block = n.strip_edges()
func set_active_group(g: String) -> void: active_group = g
func set_y_level(y: int)        -> void: edit_y = y
func set_brush_size(s: int)     -> void: brush_size = clampi(s, 1, 9)
func set_brush_plane(p: BrushPlane) -> void: brush_plane = p
func set_brush_height(h: int)   -> void:
	brush_height = clampi(h, 1, 64)
	if _sel_active or _sel_drag:
		_update_sel_preview()
func set_sel_shape(s: SelShape) -> void:
	sel_shape = s
	if _sel_active or _sel_drag:
		_update_sel_preview()
func set_sel_mode(m: SelMode)   -> void:
	sel_mode = m
	sel_fill = (m == SelMode.SOLID)
	if _sel_active or _sel_drag:
		_update_sel_preview()
func set_sel_action(a: SelAction) -> void:
	sel_action = a
func set_sel_fill(f: bool)      -> void:
	sel_fill = f
	sel_mode = SelMode.SOLID if f else SelMode.HOLLOW
	if _sel_active or _sel_drag:
		_update_sel_preview()
func set_sel_border_thickness(t: int) -> void:
	sel_border_thickness = clampi(t, 1, 32)
	if _sel_active or _sel_drag:
		_update_sel_preview()


## Apply current block to the active selection, then clear it.
func apply_selection() -> void:
	if not _sel_active:
		return
	var positions := _get_selection_positions()
	var changed := false
	var erase_selection := (sel_action == SelAction.ERASE)
	_renderer.begin_bulk_edit()
	for pos in positions:
		if erase_selection:
			changed = _renderer.remove_block(pos) or changed
		else:
			changed = _renderer.add_block(pos, current_block, active_group) or changed
	_renderer.end_bulk_edit()
	if changed:
		action_performed.emit()
	clear_selection()


func clear_selection() -> void:
	_sel_active = false
	_sel_drag   = false
	_sel_preview.visible = false


# ── Internal brush/apply ──────────────────────────────────────────────────────

func _begin_stroke() -> void:
	_is_pressing = true
	_stroke_changed = false
	_renderer.begin_bulk_edit()


func _finish_stroke() -> void:
	var had_changes := _stroke_changed
	_is_pressing = false
	_stroke_changed = false
	_renderer.end_bulk_edit()
	if had_changes:
		action_performed.emit()


func _apply_brush(center: Vector3i) -> void:
	var positions := _get_brush_positions(center)
	var changed := false
	for pos in positions:
		match current_tool:
			Tool.PAINT:
				changed = _renderer.add_block(pos, current_block, active_group) or changed
			Tool.ERASE:
				changed = _renderer.remove_block(pos) or changed
	if changed:
		_stroke_changed = true


func _get_brush_positions(center: Vector3i) -> Array:
	@warning_ignore("integer_division")
	var half := brush_size / 2
	var result  : Array = []
	match brush_plane:
		BrushPlane.HORIZONTAL:
			for dx in range(-half, half+1):
				for dz in range(-half, half+1):
					result.append(Vector3i(center.x+dx, center.y, center.z+dz))
		BrushPlane.VERTICAL_X:
			# Paints on YZ plane (wall facing along X axis)
			for dz in range(-half, half+1):
				for dy in range(0, brush_height):
					result.append(Vector3i(center.x, center.y+dy, center.z+dz))
		BrushPlane.VERTICAL_Z:
			# Paints on XY plane (wall facing along Z axis)
			for dx in range(-half, half+1):
				for dy in range(0, brush_height):
					result.append(Vector3i(center.x+dx, center.y+dy, center.z))
	return result


func _get_selection_positions() -> Array:
	var mn := Vector3i(min(_sel_start.x, _sel_end.x), edit_y, min(_sel_start.z, _sel_end.z))
	var mx := Vector3i(max(_sel_start.x, _sel_end.x), edit_y, max(_sel_start.z, _sel_end.z))
	var height := maxi(1, brush_height)
	var result: Array = []

	match sel_shape:
		SelShape.RECT:
			_append_rect_positions(result, mn, mx)
		SelShape.CIRCLE:
			_append_circle_positions(result, mn, mx)
		SelShape.BOX:
			_append_box_positions(result, mn, mx, height)
		SelShape.CYLINDER:
			_append_cylinder_positions(result, mn, mx, height)
		SelShape.SPHERE:
			_append_sphere_positions(result, mn, mx, height)
		SelShape.PYRAMID:
			_append_pyramid_positions(result, mn, mx, height)

	return result


func _append_rect_positions(result: Array, mn: Vector3i, mx: Vector3i) -> void:
	for x in range(mn.x, mx.x + 1):
		for z in range(mn.z, mx.z + 1):
			if _matches_rect_outline(x, z, mn.x, mx.x, mn.z, mx.z):
				result.append(Vector3i(x, edit_y, z))


func _append_circle_positions(result: Array, mn: Vector3i, mx: Vector3i) -> void:
	var cx := (mn.x + mx.x) / 2.0
	var cz := (mn.z + mx.z) / 2.0
	var rx := maxf((mx.x - mn.x) / 2.0, 0.5)
	var rz := maxf((mx.z - mn.z) / 2.0, 0.5)
	var inner_rx := rx - float(sel_border_thickness)
	var inner_rz := rz - float(sel_border_thickness)
	
	for x in range(mn.x, mx.x + 1):
		for z in range(mn.z, mx.z + 1):
			var in_outer := _ellipse_contains(x, z, cx, cz, rx, rz)
			if not in_outer:
				continue
			if sel_mode == SelMode.SOLID:
				result.append(Vector3i(x, edit_y, z))
			elif inner_rx <= 0.0 or inner_rz <= 0.0 or not _ellipse_contains(x, z, cx, cz, inner_rx, inner_rz):
				result.append(Vector3i(x, edit_y, z))


func _append_box_positions(result: Array, mn: Vector3i, mx: Vector3i, height: int) -> void:
	var top_y := edit_y + height - 1
	for x in range(mn.x, mx.x + 1):
		for y in range(edit_y, top_y + 1):
			for z in range(mn.z, mx.z + 1):
				if _matches_box_mode(x, y, z, mn.x, mx.x, edit_y, top_y, mn.z, mx.z):
					result.append(Vector3i(x, y, z))


func _append_cylinder_positions(result: Array, mn: Vector3i, mx: Vector3i, height: int) -> void:
	var cx := (mn.x + mx.x) / 2.0
	var cz := (mn.z + mx.z) / 2.0
	var rx := maxf((mx.x - mn.x) / 2.0, 0.5)
	var rz := maxf((mx.z - mn.z) / 2.0, 0.5)
	var inner_rx := rx - float(sel_border_thickness)
	var inner_rz := rz - float(sel_border_thickness)
	var top_y := edit_y + height - 1
	
	for x in range(mn.x, mx.x + 1):
		for y in range(edit_y, top_y + 1):
			for z in range(mn.z, mx.z + 1):
				var in_outer := _ellipse_contains(x, z, cx, cz, rx, rz)
				if not in_outer:
					continue
				if sel_mode == SelMode.SOLID:
					result.append(Vector3i(x, y, z))
					continue
				
				var near_y := _is_near_edge(y, edit_y, top_y)
				var in_inner := inner_rx > 0.0 and inner_rz > 0.0 and _ellipse_contains(x, z, cx, cz, inner_rx, inner_rz)
				var on_wall := not in_inner
				if sel_mode == SelMode.HOLLOW:
					if on_wall or near_y:
						result.append(Vector3i(x, y, z))
				elif on_wall:
					result.append(Vector3i(x, y, z))


func _append_sphere_positions(result: Array, mn: Vector3i, mx: Vector3i, height: int) -> void:
	var top_y := edit_y + height - 1
	var cx := (mn.x + mx.x) / 2.0
	var cy := (edit_y + top_y) / 2.0
	var cz := (mn.z + mx.z) / 2.0
	var rx := maxf((mx.x - mn.x) / 2.0, 0.5)
	var ry := maxf((top_y - edit_y) / 2.0, 0.5)
	var rz := maxf((mx.z - mn.z) / 2.0, 0.5)
	
	for x in range(mn.x, mx.x + 1):
		for y in range(edit_y, top_y + 1):
			for z in range(mn.z, mx.z + 1):
				var outer := _ellipsoid_value(x, y, z, cx, cy, cz, rx, ry, rz)
				if outer > 1.0:
					continue
				if sel_mode == SelMode.SOLID:
					result.append(Vector3i(x, y, z))
					continue
				
				var inner_rx := rx - float(sel_border_thickness)
				var inner_ry := ry - float(sel_border_thickness)
				var inner_rz := rz - float(sel_border_thickness)
				if inner_rx <= 0.0 or inner_ry <= 0.0 or inner_rz <= 0.0:
					result.append(Vector3i(x, y, z))
					continue
				
				var inner := _ellipsoid_value(x, y, z, cx, cy, cz, inner_rx, inner_ry, inner_rz)
				if inner > 1.0:
					result.append(Vector3i(x, y, z))


func _append_pyramid_positions(result: Array, mn: Vector3i, mx: Vector3i, height: int) -> void:
	var total_levels := maxi(1, height)
	for level in range(total_levels):
		var t := float(level) / maxf(float(total_levels - 1), 1.0)
		var inset_x := int(round(t * float(mx.x - mn.x) * 0.5))
		var inset_z := int(round(t * float(mx.z - mn.z) * 0.5))
		var layer_min_x := mn.x + inset_x
		var layer_max_x := mx.x - inset_x
		var layer_min_z := mn.z + inset_z
		var layer_max_z := mx.z - inset_z
		var y := edit_y + level
		
		if layer_min_x > layer_max_x or layer_min_z > layer_max_z:
			var peak := Vector3i(roundi((mn.x + mx.x) * 0.5), y, roundi((mn.z + mx.z) * 0.5))
			result.append(peak)
			continue
		
		for x in range(layer_min_x, layer_max_x + 1):
			for z in range(layer_min_z, layer_max_z + 1):
				if sel_mode == SelMode.SOLID:
					result.append(Vector3i(x, y, z))
					continue
				var on_edge := _matches_rect_outline(x, z, layer_min_x, layer_max_x, layer_min_z, layer_max_z)
				if on_edge:
					result.append(Vector3i(x, y, z))


func _matches_rect_outline(x: int, z: int, min_x: int, max_x: int, min_z: int, max_z: int) -> bool:
	if sel_mode == SelMode.SOLID:
		return true
	return _is_near_edge(x, min_x, max_x) or _is_near_edge(z, min_z, max_z)


func _matches_box_mode(x: int, y: int, z: int, min_x: int, max_x: int, min_y: int, max_y: int, min_z: int, max_z: int) -> bool:
	if sel_mode == SelMode.SOLID:
		return true
	
	var near_x := _is_near_edge(x, min_x, max_x)
	var near_y := _is_near_edge(y, min_y, max_y)
	var near_z := _is_near_edge(z, min_z, max_z)
	
	if sel_mode == SelMode.HOLLOW:
		return near_x or near_y or near_z
	
	var edges_hit := int(near_x) + int(near_y) + int(near_z)
	return edges_hit >= 2


func _is_near_edge(value: int, min_value: int, max_value: int) -> bool:
	var thickness := clampi(sel_border_thickness, 1, maxi(max_value - min_value + 1, 1))
	return value - min_value < thickness or max_value - value < thickness


func _ellipse_contains(x: int, z: int, cx: float, cz: float, rx: float, rz: float) -> bool:
	var safe_rx := maxf(rx + 0.5, 0.5)
	var safe_rz := maxf(rz + 0.5, 0.5)
	var nx := (x - cx) / safe_rx
	var nz := (z - cz) / safe_rz
	return nx * nx + nz * nz <= 1.0


func _ellipsoid_value(x: int, y: int, z: int, cx: float, cy: float, cz: float, rx: float, ry: float, rz: float) -> float:
	var safe_rx := maxf(rx + 0.5, 0.5)
	var safe_ry := maxf(ry + 0.5, 0.5)
	var safe_rz := maxf(rz + 0.5, 0.5)
	var nx := (x - cx) / safe_rx
	var ny := (y - cy) / safe_ry
	var nz := (z - cz) / safe_rz
	return nx * nx + ny * ny + nz * nz


# ── Preview helpers ───────────────────────────────────────────────────────────

func _update_hover_preview(center: Vector3i) -> void:
	_hover_preview.visible = true
	var positions := _get_brush_positions(center)
	if positions.is_empty():
		return
	# Compute bounding box of brush
	var mn := positions[0] as Vector3i
	var mx := positions[0] as Vector3i
	for p in positions:
		if p.x < mn.x: mn.x = p.x
		if p.y < mn.y: mn.y = p.y
		if p.z < mn.z: mn.z = p.z
		if p.x > mx.x: mx.x = p.x
		if p.y > mx.y: mx.y = p.y
		if p.z > mx.z: mx.z = p.z
	var sz := Vector3(mx.x - mn.x + 1, mx.y - mn.y + 1, mx.z - mn.z + 1)
	var ct := (Vector3(mn) + Vector3(mx)) * 0.5
	_hover_preview.position = ct
	(_hover_preview.mesh as BoxMesh).size = sz + Vector3.ONE * 0.03


func _update_sel_preview() -> void:
	if not _sel_active and not _sel_drag:
		_sel_preview.visible = false
		return
	_sel_preview.visible = true
	var mn_xz := Vector2i(min(_sel_start.x, _sel_end.x), min(_sel_start.z, _sel_end.z))
	var mx_xz := Vector2i(max(_sel_start.x, _sel_end.x), max(_sel_start.z, _sel_end.z))
	var preview_height := 0.15
	if sel_shape in [SelShape.BOX, SelShape.CYLINDER, SelShape.SPHERE, SelShape.PYRAMID]:
		preview_height = float(maxi(1, brush_height))
	var sz := Vector3(mx_xz.x - mn_xz.x + 1, preview_height, mx_xz.y - mn_xz.y + 1)
	var center_y := float(edit_y)
	if preview_height > 0.2:
		center_y = float(edit_y) + (preview_height - 1.0) * 0.5
	var ct := Vector3((mn_xz.x + mx_xz.x) * 0.5, center_y, (mn_xz.y + mx_xz.y) * 0.5)
	_sel_preview.position = ct
	(_sel_preview.mesh as BoxMesh).size = sz


# ── Ray → grid ────────────────────────────────────────────────────────────────

func _ray_to_grid(mouse_local: Vector2) -> Vector3i:
	var cam: Camera3D = _cam_ctrl.get_active_camera() as Camera3D
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		return Vector3i(0, edit_y, 0)

	var ct_size := _vp_ctr.size
	var vp_size := Vector2(_sub_vp.size)
	if ct_size.x < 1.0 or ct_size.y < 1.0 or vp_size.x < 1.0 or vp_size.y < 1.0:
		return Vector3i(0, edit_y, 0)
	var vp_pos := mouse_local / ct_size * vp_size

	var ray_o : Vector3 = cam.project_ray_origin(vp_pos)
	var far_pt : Vector3 = cam.project_position(vp_pos, 1000.0)
	var ray_d : Vector3 = (far_pt - ray_o).normalized()

	match brush_plane:
		BrushPlane.HORIZONTAL:
			return _intersect_y_plane(ray_o, ray_d, float(edit_y) + 0.5)
		BrushPlane.VERTICAL_X:
			# Intersect with X = cursor.x plane — but we need to first get X from horizontal
			# We use horizontal intersection to find X, then paint in YZ
			var hp := _intersect_y_plane(ray_o, ray_d, float(edit_y) + 0.5)
			return hp
		BrushPlane.VERTICAL_Z:
			var hp := _intersect_y_plane(ray_o, ray_d, float(edit_y) + 0.5)
			return hp

	return _intersect_y_plane(ray_o, ray_d, float(edit_y) + 0.5)


func _intersect_y_plane(ray_o: Vector3, ray_d: Vector3, plane_y: float) -> Vector3i:
	if abs(ray_d.y) < 0.001:
		return Vector3i(roundi(ray_o.x), edit_y, roundi(ray_o.z))
	var t := (plane_y - ray_o.y) / ray_d.y
	if t < 0.01:
		var alt := float(edit_y) - 0.5
		t = (alt - ray_o.y) / ray_d.y
		t = maxf(t, 0.01)
	var hit := ray_o + ray_d * t
	return Vector3i(roundi(hit.x), edit_y, roundi(hit.z))
