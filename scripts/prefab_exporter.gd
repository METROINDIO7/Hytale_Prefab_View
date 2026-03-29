
class_name PrefabExporter
extends RefCounted
static func export_to_file(blocks: Dictionary, path: String,
		anchor := Vector3i.ZERO, version := 8, biv := 11) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return ERR_FILE_CANT_WRITE
	f.store_string(build_json(blocks, anchor, version, biv))
	f.close()
	return OK

static func build_json(blocks: Dictionary, anchor := Vector3i.ZERO,
		version := 8, biv := 11) -> String:

	if blocks.is_empty():
		return JSON.stringify({
			"version": version, "blockIdVersion": biv,
			"anchorX": 0, "anchorY": 0, "anchorZ": 0,
			"blocks": [], "fluids": []
		}, "\t")

	# ── Compute bounds ────────────────────────────────────────────────────────
	var min_x := INF;  var min_y := INF;  var min_z := INF
	var max_x := -INF; var max_y := -INF; var max_z := -INF
	for key in blocks:
		var p = key.split(",")
		var x := float(p[0]); var y := float(p[1]); var z := float(p[2])
		if x < min_x: min_x = x;  if y < min_y: min_y = y;  if z < min_z: min_z = z
		if x > max_x: max_x = x;  if y > max_y: max_y = y;  if z > max_z: max_z = z

	# ── Anchor: center on XZ, bottom on Y ────────────────────────────────────
	# Using vertical center causes the lower half to have negative Y, which
	# makes Hytale bury the structure underground.  Anchoring to min_y ensures
	# the lowest block sits at Y = 0 relative to the placement point.
	var use_anchor := anchor
	if anchor == Vector3i.ZERO:
		use_anchor = Vector3i(
			int((min_x + max_x) / 2.0),   # XZ centered
			int(min_y),                    # Y at bottom — no sinking
			int((min_z + max_z) / 2.0)
		)

	# ── Build block / fluid arrays ────────────────────────────────────────────
	var blk_arr : Array = []
	var flu_arr : Array = []
	for key in blocks:
		var p = key.split(",")
		var bx := int(p[0]); var by := int(p[1]); var bz := int(p[2])
		var ax := bx - use_anchor.x
		var ay := by - use_anchor.y   # now always >= 0
		var az := bz - use_anchor.z
		blk_arr.append({"x": ax, "y": ay, "z": az, "name": blocks[key]})
		flu_arr.append({"x": ax, "y": ay, "z": az, "name": "Empty", "level": 0})

	# ── Sort Y → X → Z ───────────────────────────────────────────────────────
	var _sort := func(a, b):
		if a["y"] != b["y"]: return a["y"] < b["y"]
		if a["x"] != b["x"]: return a["x"] < b["x"]
		return a["z"] < b["z"]
	blk_arr.sort_custom(_sort)
	flu_arr.sort_custom(_sort)

	return JSON.stringify({
		"version": version, "blockIdVersion": biv,
		"anchorX": use_anchor.x, "anchorY": use_anchor.y, "anchorZ": use_anchor.z,
		"blocks":  blk_arr, "fluids": flu_arr
	}, "\t")
