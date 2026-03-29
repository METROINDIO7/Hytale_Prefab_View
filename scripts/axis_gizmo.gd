# axis_gizmo.gd
class_name AxisGizmo
extends TextureRect

# ==================== COLORES ====================
const COL_X := Color(1.0, 0.25, 0.25)
const COL_Y := Color(0.25, 1.0, 0.25)
const COL_Z := Color(0.25, 0.5, 1.0)

const BG_COL := Color(0.12, 0.12, 0.15, 0.65)     # Más transparente
const RING_COL := Color(0.45, 0.45, 0.50, 0.55)   # Más transparente
const SHADOW_COL := Color(0.0, 0.0, 0.0, 0.25)

# ==================== CONFIGURACIÓN ====================
const SIZE := Vector2(64, 64)
const CENTER := Vector2(32, 32)
const RADIUS := 23.0
const AXIS_WIDTH := 3.0
const TIP_RADIUS := 4.5
const LABEL_OFFSET := 11.0
const LABEL_SIZE := 12

var _cam_ctrl: CameraController = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = SIZE
	size = SIZE
	
	# Anclaje en esquina superior derecha
	anchors_preset = PRESET_TOP_RIGHT
	offset_left = -SIZE.x - 10
	offset_top = 10
	offset_right = -10
	offset_bottom = SIZE.y + 10
	
	clip_contents = false
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP
	
	z_index = 100
	visible = true
	
	print("[AxisGizmo] ✅ Listo - Tamaño reducido: ", SIZE)


func setup(cam_ctrl: CameraController) -> void:
	_cam_ctrl = cam_ctrl


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Fondo semitransparente
	draw_circle(CENTER, RADIUS + 8, BG_COL)
	draw_arc(CENTER, RADIUS + 8, 0, TAU, 48, RING_COL, 2.0, true)
	
	if _cam_ctrl == null:
		_draw_error_text("NO CTRL", Color.YELLOW)
		return
	
	var cam := _cam_ctrl.get_active_camera()
	if cam == null or not is_instance_valid(cam):
		_draw_error_text("NO CAM", Color.ORANGE)
		return
	
	var basis := cam.global_transform.basis
	var inv_basis := basis.inverse()
	
	var axes := [
		{"dir": Vector3.RIGHT,   "col": COL_X, "lbl": "X"},
		{"dir": Vector3.UP,      "col": COL_Y, "lbl": "Y"},
		{"dir": Vector3.FORWARD, "col": COL_Z, "lbl": "Z"},
	]
	
	for ax in axes:
		var local_dir: Vector3 = inv_basis * ax["dir"]
		var screen_dir := Vector2(local_dir.x, -local_dir.y).normalized()
		
		if screen_dir.length_squared() < 0.0001:
			screen_dir = Vector2.RIGHT
		
		var tip: Vector2 = CENTER + screen_dir * RADIUS
		
		# Opacidad según si el eje mira hacia la cámara
		var dot_to_camera := local_dir.z
		var alpha = clamp(0.45 + (1.0 + dot_to_camera) * 0.55, 0.4, 1.0)
		var thickness := AXIS_WIDTH * (0.75 if dot_to_camera > 0.5 else 1.0)
		
		var final_col: Color = ax["col"]
		final_col.a = alpha
		
		# Sombra suave
		draw_line(CENTER + Vector2(1, 1), tip + Vector2(1, 1), SHADOW_COL, thickness + 1.5, true)
		
		# Línea del eje
		draw_line(CENTER, tip, final_col, thickness, true)
		
		# Punta del eje
		draw_circle(tip, TIP_RADIUS, final_col)
		
		# Etiqueta
		var lbl_pos := tip + screen_dir * LABEL_OFFSET
		
		draw_string(ThemeDB.fallback_font, lbl_pos, ax["lbl"],
			HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_SIZE, final_col.lightened(0.3))


func _draw_error_text(text: String, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(8, 28), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
