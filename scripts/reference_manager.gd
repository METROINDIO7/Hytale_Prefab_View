
class_name ReferenceImageManager
extends Node
class RefEntry:
	var camera       : Camera3D
	var cam_name     : String
	var texture_rect : TextureRect
	var opacity      : float   = 0.5
	var scale_val    : float   = 1.0
	var image_path   : String  = ""
	var has_image    : bool    = false
	var original_size: Vector2 = Vector2.ZERO
var _entries  : Array   = []
var _overlay  : Control
func setup(overlay_container: Control) -> void:
	_overlay = overlay_container
func add_entry(cam: Camera3D, cam_name: String) -> RefEntry:
	var entry := RefEntry.new()
	entry.camera   = cam
	entry.cam_name = cam_name
	var Tr := TextureRect.new()
	# Anchors fijos para ocupar todo el overlay
	Tr.anchor_left   = 0.0
	Tr.anchor_top    = 0.0
	Tr.anchor_right  = 1.0
	Tr.anchor_bottom = 1.0

	# Offsets a 0 para usar todo el espacio
	Tr.offset_left   = 0.0
	Tr.offset_top    = 0.0
	Tr.offset_right  = 0.0
	Tr.offset_bottom = 0.0

	# Stretch mode centrado
	Tr.stretch_mode     = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	Tr.modulate.a       = entry.opacity
	Tr.mouse_filter     = Control.MOUSE_FILTER_IGNORE
	Tr.visible          = false
	Tr.expand_mode      = TextureRect.EXPAND_IGNORE_SIZE

	if _overlay:
		_overlay.add_child(Tr)
	entry.texture_rect = Tr
	_entries.append(entry)
	return entry
func load_image_for(entry: RefEntry, path: String) -> bool:
	var img := Image.load_from_file(path)
	if img == null:
		push_error("[RefMgr] Cannot load image: " + path)
		return false
	var tex := ImageTexture.create_from_image(img)
	entry.texture_rect.texture = tex
	entry.image_path = path
	entry.has_image  = true
	entry.original_size = tex.get_size()
	entry.texture_rect.visible = true
	_apply_scale(entry)
	return true
func set_opacity(entry: RefEntry, v: float) -> void:
	entry.opacity = clampf(v, 0.0, 1.0)
	if entry.texture_rect:
		entry.texture_rect.modulate.a = entry.opacity
func set_scale(entry: RefEntry, s: float) -> void:
	entry.scale_val = clampf(s, 0.1, 4.0)
	_apply_scale(entry)
func _apply_scale(entry: RefEntry) -> void:
	if entry.texture_rect == null or entry.texture_rect.texture == null:
		return
	var tex := entry.texture_rect.texture
	if tex == null or entry.original_size == Vector2.ZERO:
		return

	# Calcular tamaño escalado basado en el tamaño original
	var scaled_size := entry.original_size * entry.scale_val
	entry.texture_rect.custom_minimum_size = scaled_size

	# Forzar actualización del layout (Godot 4)
	entry.texture_rect.queue_redraw()
func show_for_camera(active_cam: Camera3D) -> void:
	for e in _entries:
		if e.texture_rect:
			e.texture_rect.visible = (e.camera == active_cam and e.has_image)
func hide_all() -> void:
	for e in _entries:
		if e.texture_rect:
			e.texture_rect.visible = false
func remove_entry(entry: RefEntry) -> void:
	_entries.erase(entry)
	if entry.texture_rect and is_instance_valid(entry.texture_rect):
		entry.texture_rect.queue_free()
func get_entry_for_camera(cam: Camera3D) -> RefEntry:
	for e in _entries:
		if e.camera == cam:
			return e
	return null
func get_all_entries() -> Array:
	return _entries
func clear_all() -> void:
	for e in _entries:
		if e.texture_rect and is_instance_valid(e.texture_rect):
			e.texture_rect.queue_free()
	_entries.clear()
