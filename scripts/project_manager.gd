
class_name ProjectManager
extends RefCounted
const FORMAT_TAG := "hpv_project"
const FORMAT_VER := 3  # ← Actualizado a v3 (agrega estado)
static func save(
	path       : String,
	groups     : Dictionary,
	cameras    : Array,
	ref_images : Array,
	state      : Dictionary = {}  # ← NUEVO: estado de la aplicación
) -> Error:
	var data := {
		"format":     FORMAT_TAG,
		"version":    FORMAT_VER,
		"saved_at":   Time.get_datetime_string_from_system(),
		"groups":     groups,
		"cameras":    cameras,
		"ref_images": ref_images,
		"state":      state  # ← NUEVO
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[PM] Cannot write: " + path)
		return ERR_FILE_CANT_WRITE
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return OK
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		push_error("[PM] Parse error: " + path)
		return {}
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}

	# Validar formato
	if data.get("format", "") != FORMAT_TAG:
		return {}  # No es un archivo de proyecto (podría ser prefab)

	# Migración de versiones antiguas
	_migrate_data(data)

	return data
static func _migrate_data(data: Dictionary) -> void:
	var ver = data.get("version", 1)

	# v1 → v2: Agregar ref_images si no existe
	if ver < 2 and not data.has("ref_images"):
		data["ref_images"] = []

	# v2 → v3: Agregar state si no existe
	if ver < 3 and not data.has("state"):
		data["state"] = {}

	# Actualizar versión a la más reciente
	data["version"] = FORMAT_VER
static func cam_transform_to_array(t: Transform3D) -> Array:
	var b := t.basis
	return [
		b.x.x, b.x.y, b.x.z,
		b.y.x, b.y.y, b.y.z,
		b.z.x, b.z.y, b.z.z,
		t.origin.x, t.origin.y, t.origin.z
	]
static func array_to_cam_transform(arr: Array) -> Transform3D:
	if arr.size() < 12:
		return Transform3D.IDENTITY
	return Transform3D(
		Basis(
			Vector3(arr[0], arr[1], arr[2]),
			Vector3(arr[3], arr[4], arr[5]),
			Vector3(arr[6], arr[7], arr[8])
		),
		Vector3(arr[9], arr[10], arr[11])
	)
