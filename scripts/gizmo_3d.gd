# gizmo_3d.gd
# Orientation gizmo rendered in its own SubViewport.
# Displays X (red), Y (green), Z (blue) axes that rotate with the main camera,
# giving the user a constant world-orientation reference like Blender's corner gizmo.
class_name Gizmo3D
extends Node3D

# ── Config ────────────────────────────────────────────────────────────────────
const SHAFT_LEN  := 0.50
const SHAFT_R    := 0.028
const TIP_R      := 0.072
const TIP_LEN    := 0.16
const LBL_DIST   := 0.84

# Positive-axis colors (Blender convention)
const COLOR_X  := Color(0.92, 0.20, 0.20)
const COLOR_Y  := Color(0.22, 0.85, 0.22)
const COLOR_Z  := Color(0.18, 0.40, 0.95)
# Negative-axis colors (dimmer, shorter, no label)
const COLOR_XN := Color(0.50, 0.10, 0.10)
const COLOR_YN := Color(0.10, 0.48, 0.10)
const COLOR_ZN := Color(0.08, 0.20, 0.55)

# ── State ─────────────────────────────────────────────────────────────────────
var _cam_ctrl : CameraController = null


func _ready() -> void:
	# Positive axes — full arrow + label
	# rotation_degrees aligns local +Y with the world axis direction:
	#   +X : rotate -90° around Z  →  local +Y points to world +X
	#   +Y : no rotation           →  local +Y already points to world +Y
	#   +Z : rotate +90° around X  →  local +Y points to world +Z
	_build_arrow(Vector3(0,  0, -90), COLOR_X, "X")
	_build_arrow(Vector3(0,  0,   0), COLOR_Y, "Y")
	_build_arrow(Vector3(90, 0,   0), COLOR_Z, "Z")

	# Negative axes — short stub only, no label
	_build_stub(Vector3(  0,   0,  90), COLOR_XN)
	_build_stub(Vector3(180,   0,   0), COLOR_YN)
	_build_stub(Vector3(-90,   0,   0), COLOR_ZN)


# ── Public API ────────────────────────────────────────────────────────────────

## Call once from main.gd after 3D scene is ready.
func set_target_camera(cam_ctrl: CameraController) -> void:
	_cam_ctrl = cam_ctrl


# ── Update ────────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if _cam_ctrl == null:
		return
	var cam := _cam_ctrl.get_active_camera()
	if cam == null or not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	# Rotate the gizmo by the inverse of the camera's world rotation.
	# The gizmo's own camera is fixed at (0, 0, 3.2) looking at origin.
	# Applying the inverse rotation means the gizmo axes always reflect
	# which world direction each screen direction corresponds to.
	self.basis = cam.global_transform.basis.inverse()


# ── Builders ─────────────────────────────────────────────────────────────────

func _build_arrow(rot_deg: Vector3, color: Color, label_text: String) -> void:
	var root := Node3D.new()
	root.rotation_degrees = rot_deg
	add_child(root)

	# ── Shaft ─────────────────────────────────────────────────────────────────
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color
	smat.roughness    = 0.45
	smat.metallic     = 0.10

	var smesh := CylinderMesh.new()
	smesh.top_radius    = SHAFT_R
	smesh.bottom_radius = SHAFT_R
	smesh.height        = SHAFT_LEN
	smesh.material      = smat

	var sinst := MeshInstance3D.new()
	sinst.mesh     = smesh
	sinst.position = Vector3(0, SHAFT_LEN * 0.5, 0)
	root.add_child(sinst)

	# ── Tip (cone) ────────────────────────────────────────────────────────────
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = color.lightened(0.10)
	tmat.roughness    = 0.35
	tmat.metallic     = 0.15

	var tmesh := CylinderMesh.new()
	tmesh.top_radius    = 0.0
	tmesh.bottom_radius = TIP_R
	tmesh.height        = TIP_LEN
	tmesh.material      = tmat

	var tinst := MeshInstance3D.new()
	tinst.mesh     = tmesh
	tinst.position = Vector3(0, SHAFT_LEN + TIP_LEN * 0.5, 0)
	root.add_child(tinst)

	# ── Label ─────────────────────────────────────────────────────────────────
	var lbl := Label3D.new()
	lbl.text             = label_text
	lbl.font_size        = 68
	lbl.modulate         = color.lightened(0.15)
	lbl.billboard        = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test    = true
	lbl.double_sided     = true
	lbl.position         = Vector3(0, LBL_DIST, 0)
	lbl.pixel_size       = 0.0092
	lbl.outline_size     = 6
	lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.88)
	lbl.fixed_size       = true
	root.add_child(lbl)


func _build_stub(rot_deg: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.rotation_degrees = rot_deg
	add_child(root)

	var smat := StandardMaterial3D.new()
	smat.albedo_color = color
	smat.roughness    = 0.65

	var smesh := CylinderMesh.new()
	smesh.top_radius    = SHAFT_R * 0.75
	smesh.bottom_radius = SHAFT_R * 0.75
	smesh.height        = SHAFT_LEN * 0.42
	smesh.material      = smat

	var sinst := MeshInstance3D.new()
	sinst.mesh     = smesh
	sinst.position = Vector3(0, SHAFT_LEN * 0.42 * 0.5, 0)
	root.add_child(sinst)
