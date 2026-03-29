# camera_controller.gd
# Navigation works for BOTH aerial and ref cameras.
# Ref cameras can have reference images attached.
class_name CameraController
extends Node3D

signal camera_changed(cam_name: String)

const MOVE_SPEED_BASE   := 12.0
const ORBIT_SENSITIVITY := 0.30
const PAN_SENSITIVITY   := 0.035
const ZOOM_SPEED        := 2.8
const VERTICAL_SPEED    := 10.0

var _pivot       : Node3D
var _aerial_cam  : Camera3D
var _ref_cameras : Array   = []
var _active_cam  : Camera3D

var _panning      : bool    = false
var _orbiting     : bool    = false
var _last_mouse   : Vector2 = Vector2.ZERO
var _cam_distance : float   = 22.0
var _pitch_deg    : float   = -52.0

# Track navigation state per camera
var _cam_states : Dictionary = {}  # cam_name → {position, rotation, distance, pitch}




func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.name = "AerialPivot"
	add_child(_pivot)

	_aerial_cam = Camera3D.new()
	_aerial_cam.name = "AerialCamera"
	_aerial_cam.fov  = 60.0
	_pivot.add_child(_aerial_cam)
	_apply_orbit()
	_aerial_cam.make_current()
	_active_cam = _aerial_cam
	
	# Initialize aerial camera state
	_cam_states["aerial"] = {
		"pivot_pos": Vector3.ZERO,
		"distance": _cam_distance,
		"pitch": _pitch_deg
	}

## Called after loading a project. Sets the camera transform AND syncs internal
## state so that switch_to_ref_camera() won't override it via _restore_cam_state().
func initialize_ref_camera_from_saved(cam: Camera3D, Transform: Transform3D) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	cam.global_transform = Transform
	# Extract pitch from the saved basis so orbit/rotation is preserved correctly
	var pitch_deg := Transform.basis.get_euler().x * (180.0 / PI)
	_cam_states[cam.name] = {
		"pivot_pos": Transform.origin,
		"distance":  _cam_distance,
		"pitch":     pitch_deg
	}





func _process(delta: float) -> void:
	# WASD + QE movement - applies to ACTIVE camera (aerial OR ref)
	var move_h := Vector2.ZERO
	var move_v := 0.0
	
	# Horizontal
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    move_h.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  move_h.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  move_h.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move_h.x += 1.0
	
	# Vertical (Q = Down, E = Up)
	if Input.is_key_pressed(KEY_Q):  move_v -= 1.0
	if Input.is_key_pressed(KEY_E):  move_v += 1.0
	
	# Apply movement to active camera
	if _active_cam == _aerial_cam:
		# Aerial camera uses pivot system
		if move_h != Vector2.ZERO:
			move_h = move_h.normalized()
			var speed := MOVE_SPEED_BASE * (1.0 + _cam_distance * 0.06)
			var bas := _pivot.global_transform.basis
			var right := Vector3(bas.x.x, 0.0, bas.x.z).normalized()
			var fwd := Vector3(-bas.z.x, 0.0, -bas.z.z).normalized()
			_pivot.global_position += (right * move_h.x + fwd * (-move_h.y)) * speed * delta
		
		if move_v != 0.0:
			var v_speed := VERTICAL_SPEED * (1.0 + _cam_distance * 0.06)
			_pivot.global_position.y += move_v * v_speed * delta
	else:
		# Ref camera moves directly
		if move_h != Vector2.ZERO or move_v != 0.0:
			move_h = move_h.normalized() if move_h != Vector2.ZERO else move_h
			var speed = MOVE_SPEED_BASE * (1.0 + _get_cam_state(_active_cam).distance * 0.06)
			var bas := _active_cam.global_transform.basis
			var right := Vector3(bas.x.x, 0.0, bas.x.z).normalized()
			var fwd := Vector3(-bas.z.x, 0.0, -bas.z.z).normalized()
			_active_cam.global_position += (right * move_h.x + fwd * (-move_h.y)) * speed * delta
			if move_v != 0.0:
				var v_speed = VERTICAL_SPEED * (1.0 + _get_cam_state(_active_cam).distance * 0.06)
				_active_cam.global_position.y += move_v * v_speed * delta


func process_event(event: InputEvent, _mouse_vp_pos: Vector2) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_MIDDLE:
				_panning = mb.pressed
				_last_mouse = mb.position
			MOUSE_BUTTON_RIGHT:
				_orbiting = mb.pressed
				_last_mouse = mb.position
			MOUSE_BUTTON_WHEEL_UP:   _zoom(-ZOOM_SPEED)
			MOUSE_BUTTON_WHEEL_DOWN: _zoom(ZOOM_SPEED)

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var delta := mm.position - _last_mouse
		_last_mouse = mm.position

		if _panning:
			var cam := _active_cam
			var state := _get_cam_state(cam)
			var bas := cam.global_transform.basis
			var right := Vector3(bas.x.x, 0.0, bas.x.z).normalized()
			var fwd := Vector3(-bas.z.x, 0.0, -bas.z.z).normalized()
			var Scale = PAN_SENSITIVITY * (state.distance * 0.08)
			cam.global_position -= right * delta.x * Scale
			cam.global_position -= fwd * delta.y * Scale
			
		elif _orbiting:
			var cam := _active_cam
			var state := _get_cam_state(cam)
			
			if cam == _aerial_cam:
				# Aerial uses pivot rotation
				_pivot.rotate_y(deg_to_rad(-delta.x * ORBIT_SENSITIVITY))
				state.pitch = clampf(state.pitch - delta.y * ORBIT_SENSITIVITY, -89.0, 15.0)
				_pitch_deg = state.pitch
				_apply_orbit()
			else:
				# Ref camera rotates in place
				cam.rotate_y(deg_to_rad(-delta.x * ORBIT_SENSITIVITY))
				state.pitch = clampf(state.pitch - delta.y * ORBIT_SENSITIVITY, -89.0, 15.0)
				cam.rotation_degrees.x = state.pitch


# ── Ref cameras ───────────────────────────────────────────────────────────────

func add_reference_camera(cam_name: String, copy_aerial: bool = true) -> Camera3D:
	var cam := Camera3D.new()
	cam.name = cam_name
	cam.fov = 60.0
	
	if copy_aerial:
		cam.global_transform = _aerial_cam.global_transform
	else:
		cam.position = Vector3(0, 10, 10)
	
	add_child(cam)
	_ref_cameras.append(cam)
	
	# Initialize state for this camera
	_cam_states[cam_name] = {
		"pivot_pos": cam.global_position,
		"distance": _cam_distance,
		"pitch": _pitch_deg
	}
	
	return cam


func remove_reference_camera(cam: Camera3D) -> void:
	_ref_cameras.erase(cam)
	_cam_states.erase(cam.name)
	if _active_cam == cam:
		switch_to_aerial()
	cam.queue_free()


func reposition_to_aerial(cam: Camera3D) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	cam.global_transform = _aerial_cam.global_transform
	# Update state
	_cam_states[cam.name] = {
		"pivot_pos": _pivot.global_position,
		"distance": _cam_distance,
		"pitch": _pitch_deg
	}


func switch_to_aerial() -> void:
	# Save ref camera state before switching
	if _active_cam != _aerial_cam:
		_save_cam_state(_active_cam)
	
	_aerial_cam.make_current()
	_active_cam = _aerial_cam
	
	# Restore aerial state
	_restore_cam_state(_aerial_cam)
	
	camera_changed.emit("aerial")


func switch_to_ref_camera(cam: Camera3D) -> void:
	if cam == null or not is_instance_valid(cam):
		return
	
	# Save current camera state before switching
	if _active_cam != null:
		_save_cam_state(_active_cam)
	
	cam.make_current()
	_active_cam = cam
	
	# Restore ref camera state
	_restore_cam_state(cam)
	
	camera_changed.emit(cam.name)


func focus_on(target: Vector3) -> void:
	if _active_cam == _aerial_cam:
		_pivot.global_position = Vector3(target.x, 0.0, target.z)
	else:
		_active_cam.global_position = Vector3(target.x, _active_cam.position.y, target.z)


func get_aerial_camera() -> Camera3D: return _aerial_cam
func get_ref_cameras() -> Array: return _ref_cameras
func get_active_camera() -> Camera3D: return _active_cam
func is_aerial_active() -> bool: return _active_cam == _aerial_cam


# ── Camera State Management ──────────────────────────────────────────────────

func _get_cam_state(cam: Camera3D) -> Dictionary:
	if not _cam_states.has(cam.name):
		_cam_states[cam.name] = {
			"pivot_pos": cam.global_position,
			"distance": _cam_distance,
			"pitch": _pitch_deg
		}
	return _cam_states[cam.name]


func _save_cam_state(cam: Camera3D) -> void:
	var state := _get_cam_state(cam)
	if cam == _aerial_cam:
		state.pivot_pos = _pivot.global_position
		state.distance = _cam_distance
		state.pitch = _pitch_deg
	else:
		state.pivot_pos = cam.global_position
		# Distance is approximated from position
		state.distance = _cam_distance
		state.pitch = cam.rotation_degrees.x


func _restore_cam_state(cam: Camera3D) -> void:
	var state := _get_cam_state(cam)
	if cam == _aerial_cam:
		_pivot.global_position = state.pivot_pos
		_cam_distance = state.distance
		_pitch_deg = state.pitch
		_apply_orbit()
	else:
		cam.global_position = state.pivot_pos
		_cam_distance = state.distance
		cam.rotation_degrees.x = state.pitch


# ── Internal ──────────────────────────────────────────────────────────────────

func _zoom(amount: float) -> void:
	_cam_distance = clampf(_cam_distance + amount, 2.0, 150.0)
	_apply_orbit()
	
	# Update state for active camera
	var state := _get_cam_state(_active_cam)
	state.distance = _cam_distance


func _apply_orbit() -> void:
	var pr := deg_to_rad(_pitch_deg)
	_aerial_cam.position = Vector3(0.0, -sin(pr) * _cam_distance, cos(pr) * _cam_distance)
	_aerial_cam.rotation_degrees = Vector3(_pitch_deg, 0.0, 0.0)
