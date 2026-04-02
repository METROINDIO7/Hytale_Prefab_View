@tool
class_name BlockPaletteButton
extends Button

@export var block_id: String = ""
@export var display_name: String = ""
@export var category: String = "Custom"
@export var search_tags: PackedStringArray = []

@export_group("Preview Assets")
@export var block_icon: Texture2D
@export var custom_mesh: Mesh
@export var albedo_texture: Texture2D
@export var fallback_color: Color = Color(0.72, 0.72, 0.72, 1.0)

const ICON_FOLDERS := ["res://2d/Icons"]
const DEFAULT_ICON_PATH := "res://2d/Icons/ItemsGenerated/Build_Black_Cube.png"
const ICON_PATHS: PackedStringArray = []
const MATCH_IGNORED_TOKENS := {
	"block": true,
	"blocks": true,
	"item": true,
	"items": true,
	"generated": true,
	"stage": true,
	"eternal": true,
	"large": true,
	"small": true,
	"medium": true,
	"flat": true,
	"half": true,
	"stairs": true,
	"roof": true,
	"vertical": true,
	"horizontal": true,
	"corner": true,
	"left": true,
	"right": true,
	"middle": true,
	"full": true,
	"ceiling": true,
	"wall": true,
	"shallow": true,
	"steep": true,
	"hollow": true,
	"piece": true,
	"pile": true,
}
const TOKEN_ALIASES := {
	"grey": ["gray"],
	"gray": ["grey"],
	"armor": ["armour"],
	"armour": ["armor"],
	"poison": ["poisoned"],
	"poisoned": ["poison"],
	"veggie": ["vegetable"],
	"vegetable": ["veggie"],
	"kebab": ["skewer"],
	"skewer": ["kebab"],
	"bookshelf": ["bookcase"],
	"bookcase": ["bookshelf"],
	"portal": ["gateway"],
	"gateway": ["portal"],
}
const ICON_OVERRIDES := {
	"Alchemy_Cauldron": "res://2d/Icons/ItemsGenerated/Deco_Cauldron.png",
	"Alchemy_Cauldron_Big": "res://2d/Icons/ItemsGenerated/Deco_Cauldron_Big.png",
	"Arcade_Machine": "res://2d/Icons/ItemsGenerated/Arcade_Machine.png",
	"Barrier": DEFAULT_ICON_PATH,
	"Block_Spawner_Block_Large": "res://2d/Icons/ItemsGenerated/Block_Spawner_Block.png",
	"Fluid_Fire": "res://2d/Icons/ItemsGenerated/Fluid_Lava.png",
	"Forgotten_Temple_Portal_Enter": "res://2d/Icons/ItemsGenerated/Portal_Device.png",
	"Forgotten_Temple_Portal_Exit": "res://2d/Icons/ItemsGenerated/Portal_Return.png",
	"Hub_Portal_Default": "res://2d/Icons/ItemsGenerated/Portal_Device.png",
	"Hub_Portal_Flat": "res://2d/Icons/ItemsGenerated/Portal_Device.png",
	"Hub_Portal_Zone3_Taiga1": "res://2d/Icons/ItemsGenerated/Portal_Device.png",
	"Instance_Gateway": "res://2d/Icons/ItemsGenerated/Portal_Device.png",
	"Launchpad": "res://2d/Icons/ItemsGenerated/Teleporter.png",
	"Leave_Instance": "res://2d/Icons/ItemsGenerated/Portal_Return.png",
}

static var _icon_index_ready := false
static var _icon_candidates: Array = []
static var _icon_paths_by_stem: Dictionary = {}
static var _resolved_icon_paths: Dictionary = {}


func _ready() -> void:
	refresh_visuals()


func _get_configuration_warning() -> String:
	if block_id.strip_edges().is_empty():
		return "Assign a `block_id` to use this block in the palette and renderer."
	return ""


func configure_fallback(id: String, cat: String, color: Color) -> void:
	block_id = id.strip_edges()
	if display_name.strip_edges().is_empty():
		display_name = _prettify_name(block_id)
	if cat.strip_edges() != "":
		category = cat
	fallback_color = color
	refresh_visuals()


func refresh_visuals() -> void:
	var nice_name := get_display_name()
	var resolved_icon := _get_effective_icon()
	text = nice_name
	tooltip_text = "%s\nID: %s\nCategory: %s" % [nice_name, get_block_id(), category]
	icon = resolved_icon
	flat = false
	clip_text = true
	custom_minimum_size = Vector2(150, 40)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	expand_icon = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_styles(resolved_icon)


func get_block_id() -> String:
	return block_id.strip_edges()


func get_display_name() -> String:
	if not display_name.strip_edges().is_empty():
		return display_name.strip_edges()
	return _prettify_name(block_id)


func get_block_data() -> Dictionary:
	return {
		"block_id": get_block_id(),
		"display_name": get_display_name(),
		"category": category,
		"icon": _get_effective_icon(),
		"custom_mesh": custom_mesh,
		"albedo_texture": albedo_texture,
		"fallback_color": fallback_color,
		"search_tags": search_tags,
	}


func matches_query(query: String) -> bool:
	var q := query.strip_edges().to_lower()
	if q.is_empty():
		return true
	
	var haystacks := [
		get_block_id().to_lower(),
		get_display_name().to_lower(),
		category.to_lower(),
	]
	for tag in search_tags:
		haystacks.append(String(tag).to_lower())
	
	for item in haystacks:
		if item.contains(q):
			return true
	return false


func _get_effective_icon() -> Texture2D:
	if block_icon != null:
		var existing_path := block_icon.resource_path
		if existing_path.is_empty() or ResourceLoader.exists(existing_path):
			return block_icon
	
	var resolved_path := _resolve_icon_path()
	if resolved_path.is_empty():
		return null
	return load(resolved_path) as Texture2D


func _resolve_icon_path() -> String:
	var cache_key := get_block_id()
	if cache_key.is_empty():
		cache_key = get_display_name()
	
	if ICON_OVERRIDES.has(cache_key):
		return String(ICON_OVERRIDES[cache_key])
	if _resolved_icon_paths.has(cache_key):
		return String(_resolved_icon_paths[cache_key])
	
	_ensure_icon_index()
	var resolved_path := _find_icon_from_name_variants()
	if resolved_path.is_empty():
		resolved_path = _find_best_icon_by_tokens()
	if resolved_path.is_empty():
		resolved_path = DEFAULT_ICON_PATH
	
	_resolved_icon_paths[cache_key] = resolved_path
	return resolved_path


func _find_icon_from_name_variants() -> String:
	for candidate in _build_name_candidates():
		var key := String(candidate).to_lower()
		if _icon_paths_by_stem.has(key):
			return String(_icon_paths_by_stem[key])
	return ""


func _build_name_candidates() -> Array:
	var raw_tokens: Array = get_block_id().split("_", false)
	if raw_tokens.is_empty():
		raw_tokens = get_display_name().replace(" ", "_").split("_", false)
	
	var cleaned: Array = []
	for token in raw_tokens:
		var token_text := String(token)
		if not MATCH_IGNORED_TOKENS.has(token_text.to_lower()):
			cleaned.append(token_text)
	
	var candidates: Array = []
	_append_candidate(candidates, raw_tokens)
	_append_candidate(candidates, cleaned)
	for i in range(cleaned.size()):
		var cleaned_variant := cleaned.duplicate()
		cleaned_variant.remove_at(i)
		_append_candidate(candidates, cleaned_variant)
	for i in range(raw_tokens.size()):
		if MATCH_IGNORED_TOKENS.has(String(raw_tokens[i]).to_lower()):
			var raw_variant := raw_tokens.duplicate()
			raw_variant.remove_at(i)
			_append_candidate(candidates, raw_variant)
	return candidates


func _find_best_icon_by_tokens() -> String:
	var token_weights := _build_token_weights()
	var best_score := -999999.0
	var best_path := ""
	var normalized_id := get_block_id().to_lower()
	var normalized_name := get_display_name().to_lower().replace(" ", "_")
	var category_lc := category.to_lower()
	
	for entry in _icon_candidates:
		var score := _score_icon_candidate(token_weights, entry, normalized_id, normalized_name, category_lc)
		if score > best_score:
			best_score = score
			best_path = String(entry.get("path", ""))
	return best_path


func _build_token_weights() -> Dictionary:
	var weights := {}
	_add_token_weights(weights, get_block_id(), 5.0)
	_add_token_weights(weights, get_display_name(), 4.0)
	_add_token_weights(weights, category, 2.5)
	for tag in search_tags:
		_add_token_weights(weights, String(tag), 3.0)
	return weights


static func _ensure_icon_index() -> void:
	if _icon_index_ready:
		return
	_icon_index_ready = true
	_icon_candidates.clear()
	_icon_paths_by_stem.clear()
	_populate_icon_candidates()


static func _populate_icon_candidates() -> void:
	var paths: Array = []
	if not ICON_PATHS.is_empty():
		paths.assign(ICON_PATHS)
	else:
		var file := FileAccess.open("res://icon_paths.json", FileAccess.READ)
		if file:
			var json = JSON.parse_string(file.get_as_text())
			if json is Array:
				paths.assign(json)
			file.close()
	for path in paths:
		var stem := String(path).get_file().get_basename()
		var token_list := _tokenize_text(stem + " " + String(path))
		_icon_candidates.append({
			"path": path,
			"stem": stem,
			"tokens": token_list,
		})
		if not _icon_paths_by_stem.has(stem) or String(path).contains("/ItemsGenerated/"):
			_icon_paths_by_stem[stem] = path


static func _append_candidate(candidates: Array, tokens: Array) -> void:
	var parts: Array[String] = []
	for token in tokens:
		var clean := String(token).strip_edges()
		if clean != "":
			parts.append(clean)
	var stem: String = "_".join(parts)
	if stem != "" and not candidates.has(stem):
		candidates.append(stem)


static func _add_token_weights(target: Dictionary, source_text: String, weight: float) -> void:
	for token in _tokenize_text(source_text):
		target[token] = max(float(target.get(token, 0.0)), weight)


static func _tokenize_text(source_text: String) -> PackedStringArray:
	var normalized := source_text.to_lower()
	for separator in ["_", "-", ".", "/", "\\"]:
		normalized = normalized.replace(separator, " ")
	
	var tokens := PackedStringArray()
	for raw_token in normalized.split(" ", false):
		var token := String(raw_token).strip_edges()
		if token.is_empty() or MATCH_IGNORED_TOKENS.has(token):
			continue
		if not tokens.has(token):
			tokens.append(token)
		var aliases: Array = TOKEN_ALIASES.get(token, [])
		for alias in aliases:
			if not tokens.has(alias):
				tokens.append(alias)
	return tokens


static func _score_icon_candidate(token_weights: Dictionary, entry: Dictionary, normalized_id: String, normalized_name: String, category_lc: String) -> float:
	var path := String(entry.get("path", ""))
	var stem := String(entry.get("stem", ""))
	var tokens := entry.get("tokens", PackedStringArray()) as PackedStringArray
	if path.is_empty():
		return -999999.0
	
	var score := 0.0
	var match_count := 0
	for key in token_weights.keys():
		var token := String(key)
		if tokens.has(token):
			score += float(token_weights[key])
			match_count += 1
	
	if stem == normalized_id:
		score += 40.0
	elif stem == normalized_name:
		score += 18.0
	if not category_lc.is_empty() and tokens.has(category_lc):
		score += 2.5
	if path.contains("/ItemsGenerated/"):
		score += 0.5
	if match_count == 0:
		score -= 10.0
	score -= float(max(tokens.size() - match_count, 0)) * 0.15
	return score


func _apply_styles(resolved_icon: Texture2D = null) -> void:
	var base := fallback_color
	var normal := StyleBoxFlat.new()
	normal.bg_color = base.darkened(0.45) if resolved_icon == null else Color(0.16, 0.16, 0.18, 1.0)
	normal.border_color = base.lightened(0.10)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_right = 6
	normal.corner_radius_bottom_left = 6

	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.10)
	hover.border_color = base.lightened(0.25)

	var Pressed := normal.duplicate()
	Pressed.bg_color = base.darkened(0.25)
	Pressed.border_color = base.lightened(0.35)

	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", Pressed)
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_font_size_override("font_size", 10)


func _prettify_name(raw_name: String) -> String:
	return raw_name.replace("_", " ").strip_edges()
