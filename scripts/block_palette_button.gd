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
	text = nice_name
	tooltip_text = "%s\nID: %s\nCategory: %s" % [nice_name, get_block_id(), category]
	icon = block_icon
	flat = false
	clip_text = true
	custom_minimum_size = Vector2(150, 40)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	expand_icon = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_styles()


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
		"icon": block_icon,
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


func _apply_styles() -> void:
	var base := fallback_color
	var normal := StyleBoxFlat.new()
	normal.bg_color = base.darkened(0.45) if block_icon == null else Color(0.16, 0.16, 0.18, 1.0)
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
