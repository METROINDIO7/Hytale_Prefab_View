class_name BlockyModelData
extends RefCounted

## Data model for Hytale `.blockymodel` files (v1.0.x).
## Units: positions/sizes/offsets are stored in "blocky pixels", where
## 1 block = BlockySettings.block_size pixels (32 for props, 64 for characters).

var lod: String = "auto"
var format: String = "prop"      # "prop" | "character"
var nodes: Array[BlockyNodeData] = []


func to_dict() -> Dictionary:
	var d := {"nodes": []}
	if not lod.is_empty():
		d["lod"] = lod
	if format != "":
		d["format"] = format
	var arr: Array = []
	for n in nodes:
		arr.append(n.to_dict())
	d["nodes"] = arr
	return d


static func from_dict(d: Dictionary) -> BlockyModelData:
	var m := BlockyModelData.new()
	if d.has("lod"):
		m.lod = str(d["lod"])
	if d.has("format"):
		m.format = str(d["format"])
	var arr: Array = d.get("nodes", [])
	for n in arr:
		if n is Dictionary:
			var node := BlockyNodeData.from_dict(n)
			if node != null:
				m.nodes.append(node)
	return m


func node_count() -> int:
	var total := 0
	for n in nodes:
		total += n.count_including_children()
	return total


func rebuild_ids() -> void:
	var counter := [1]
	for n in nodes:
		n.rebuild_ids(counter)


func collect_node_names() -> Array[String]:
	var out: Array[String] = []
	for n in nodes:
		n.collect_names(out)
	return out


func collect_nodes(out: Array = []) -> Array:
	for n in nodes:
		n.collect_nodes(out)
	return out
