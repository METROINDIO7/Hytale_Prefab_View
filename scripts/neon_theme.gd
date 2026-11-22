extends RefCounted
## Neon UI theme builder. Applied once at startup from main.gd.

const BG        := Color(0.027, 0.039, 0.063)
const BG_SOFT   := Color(0.043, 0.063, 0.098)
const CARD      := Color(0.047, 0.070, 0.106, 0.72)
const INPUT     := Color(0.031, 0.047, 0.075)
const BORDER    := Color(0.070, 0.255, 0.310)
const BORDER_HI := Color(0.000, 0.760, 0.900)
const CYAN      := Color(0.000, 0.898, 1.000)
const CYAN_DIM  := Color(0.000, 0.520, 0.640)
const MAGENTA   := Color(1.000, 0.180, 0.650)
const GREEN     := Color(0.280, 1.000, 0.650)
const TEXT      := Color(0.820, 0.950, 1.000)
const TEXT_DIM  := Color(0.450, 0.610, 0.700)
const GLOW      := Color(0.000, 0.850, 1.000, 0.45)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12

	_theme_buttons(t)
	_theme_inputs(t)
	_theme_panels(t)
	_theme_tabs(t)
	_theme_menus(t)
	_theme_misc(t)
	_theme_variations(t)
	return t


static func _box(
	bg: Color,
	border: Color,
	radius: int = 6,
	border_w: int = 1,
	glow: Color = Color(0, 0, 0, 0),
	glow_size: int = 0
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_top = border_w
	sb.border_width_right = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	if glow.a > 0.0:
		sb.shadow_color = glow
		sb.shadow_size = glow_size
	return sb


static func _zero(sb: StyleBox) -> StyleBox:
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


static func _theme_buttons(t: Theme) -> void:
	t.set_stylebox("normal", "Button", _box(BG_SOFT, BORDER))
	t.set_stylebox("hover", "Button", _box(BG_SOFT.lightened(0.06), BORDER_HI, 6, 1, GLOW, 3))
	t.set_stylebox("pressed", "Button", _box(Color(0.0, 0.20, 0.26), CYAN, 6, 1, GLOW, 5))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), CYAN, 6, 1))
	t.set_stylebox("disabled", "Button", _box(Color(0.035, 0.047, 0.063, 0.7), Color(0.09, 0.14, 0.18, 0.7)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CYAN)
	t.set_color("font_hover_pressed_color", "Button", CYAN)
	t.set_color("font_focus_color", "Button", CYAN)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_font_size("font_size", "Button", 12)
	t.set_constant("h_separation", "Button", 6)

	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := t.get_stylebox(state, "Button")
		t.set_stylebox(state, "OptionButton", sb)
		t.set_stylebox(state + "_mirrored", "OptionButton", sb)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_hover_color", "OptionButton", Color.WHITE)
	t.set_color("font_pressed_color", "OptionButton", CYAN)
	t.set_color("font_focus_color", "OptionButton", CYAN)
	t.set_color("font_disabled_color", "OptionButton", TEXT_DIM)
	t.set_font_size("font_size", "OptionButton", 12)
	t.set_constant("arrow_margin", "OptionButton", 8)
	t.set_constant("modulate_arrow", "OptionButton", 1)


static func _theme_inputs(t: Theme) -> void:
	t.set_stylebox("normal", "LineEdit", _box(INPUT, BORDER))
	t.set_stylebox("focus", "LineEdit", _box(INPUT, CYAN, 6, 1, GLOW, 4))
	t.set_stylebox("read_only", "LineEdit", _box(BG, BORDER, 6, 1))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.33, 0.48, 0.56))
	t.set_color("caret_color", "LineEdit", CYAN)
	t.set_color("selection_color", "LineEdit", Color(0.0, 0.6, 0.75, 0.35))
	t.set_color("clear_button_color", "LineEdit", CYAN_DIM)
	t.set_color("clear_button_color_pressed", "LineEdit", CYAN)
	t.set_font_size("font_size", "LineEdit", 12)

	for state in ["up_background", "down_background"]:
		t.set_stylebox(state, "SpinBox", _zero(_box(BG_SOFT, BORDER, 5, 1)))
		t.set_stylebox(state + "_hovered", "SpinBox", _zero(_box(BG_SOFT.lightened(0.08), CYAN_DIM, 5, 1)))
		t.set_stylebox(state + "_pressed", "SpinBox", _zero(_box(Color(0.0, 0.22, 0.28), CYAN, 5, 1)))
		t.set_stylebox(state + "_disabled", "SpinBox", _zero(_box(BG, BORDER, 5, 1)))
	t.set_color("up_icon_modulate", "SpinBox", CYAN)
	t.set_color("down_icon_modulate", "SpinBox", CYAN)
	t.set_color("up_hover_icon_modulate", "SpinBox", Color.WHITE)
	t.set_color("down_hover_icon_modulate", "SpinBox", Color.WHITE)
	t.set_stylebox("field_and_buttons_separator", "SpinBox", _zero(_box(Color(0, 0, 0, 0), BORDER, 0, 0)))
	t.set_stylebox("up_down_buttons_separator", "SpinBox", _zero(_box(Color(0, 0, 0, 0), BORDER, 0, 0)))

	t.set_stylebox("slider", "HSlider", _zero(_box(INPUT, BORDER, 4, 1)))
	t.set_stylebox("grabber_area", "HSlider", _zero(_box(CYAN_DIM, CYAN_DIM, 4, 0)))
	t.set_stylebox("grabber_area_highlight", "HSlider", _zero(_box(CYAN, CYAN, 4, 0)))

	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", CYAN)
	t.set_color("font_focus_color", "CheckBox", CYAN)
	t.set_color("checkbox_checked_color", "CheckBox", CYAN)
	t.set_color("checkbox_unchecked_color", "CheckBox", BORDER_HI)
	t.set_font_size("font_size", "CheckBox", 12)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "CheckBox", empty)

	for state in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
		var bg := Color(0.04, 0.06, 0.09, 0.8) if state == "scroll" else BORDER
		if state == "grabber_highlight" or state == "grabber_pressed":
			bg = CYAN
		var sb := _zero(_box(bg, bg, 4, 0))
		t.set_stylebox(state, "VScrollBar", sb)
		t.set_stylebox(state, "HScrollBar", sb)


static func _theme_panels(t: Theme) -> void:
	var panel := _box(BG, BORDER, 10, 1)
	panel.content_margin_left = 0
	panel.content_margin_right = 0
	panel.content_margin_top = 0
	panel.content_margin_bottom = 0
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 8
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "TooltipPanel", _box(Color(0.02, 0.05, 0.08, 0.97), CYAN_DIM, 8, 1))
	t.set_stylebox("panel", "AcceptDialog", _box(BG, CYAN_DIM, 10, 1))
	t.set_stylebox("panel", "PopupMenu", _box(Color(0.025, 0.043, 0.063, 0.98), CYAN_DIM, 8, 1))
	t.set_stylebox("panel", "Window", _box(BG, CYAN_DIM, 10, 1))

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_color("font_color", "TooltipLabel", CYAN)
	t.set_font_size("font_size", "TooltipLabel", 12)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 13)

	t.set_stylebox("background", "ProgressBar", _box(INPUT, BORDER, 6, 1))
	t.set_stylebox("fill", "ProgressBar", _box(Color(0.0, 0.55, 0.70), CYAN, 6, 0, GLOW, 4))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_font_size("font_size", "ProgressBar", 12)


static func _theme_tabs(t: Theme) -> void:
	var panel := _box(BG, BORDER, 10, 1)
	panel.content_margin_left = 6
	panel.content_margin_right = 6
	panel.content_margin_top = 6
	panel.content_margin_bottom = 6
	t.set_stylebox("panel", "TabContainer", panel)

	var unselected := _box(Color(0.035, 0.055, 0.082, 0.9), BORDER, 6, 1)
	unselected.corner_radius_bottom_left = 0
	unselected.corner_radius_bottom_right = 0
	unselected.border_width_bottom = 0
	unselected.content_margin_left = 12
	unselected.content_margin_right = 12
	unselected.content_margin_top = 7
	unselected.content_margin_bottom = 7

	var hovered := _box(Color(0.055, 0.105, 0.145, 0.95), CYAN_DIM, 6, 1)
	hovered.corner_radius_bottom_left = 0
	hovered.corner_radius_bottom_right = 0
	hovered.border_width_bottom = 0
	hovered.content_margin_left = 12
	hovered.content_margin_right = 12
	hovered.content_margin_top = 7
	hovered.content_margin_bottom = 7

	var selected := _box(Color(0.020, 0.075, 0.098, 1.0), CYAN, 6, 1, GLOW, 3)
	selected.corner_radius_bottom_left = 0
	selected.corner_radius_bottom_right = 0
	selected.border_width_bottom = 2
	selected.content_margin_left = 12
	selected.content_margin_right = 12
	selected.content_margin_top = 7
	selected.content_margin_bottom = 7

	for ty in ["TabContainer", "TabBar"]:
		t.set_stylebox("tab_unselected", ty, unselected)
		t.set_stylebox("tab_hovered", ty, hovered)
		t.set_stylebox("tab_selected", ty, selected)
		t.set_stylebox("tab_disabled", ty, unselected)
		t.set_color("font_unselected_color", ty, TEXT_DIM)
		t.set_color("font_hovered_color", ty, TEXT)
		t.set_color("font_selected_color", ty, CYAN)
		t.set_color("font_disabled_color", ty, Color(0.25, 0.33, 0.38))
		t.set_font_size("font_size", ty, 12)


static func _theme_menus(t: Theme) -> void:
	var bar := _box(BG, Color(0.0, 0.55, 0.68, 0.35), 0, 0)
	bar.border_width_bottom = 1
	bar.content_margin_top = 2
	bar.content_margin_bottom = 2
	bar.content_margin_left = 8
	bar.content_margin_right = 8
	t.set_stylebox("normal", "MenuBar", bar)
	var bar_hover := _box(Color(0.0, 0.25, 0.32, 0.55), CYAN_DIM, 5, 1)
	bar_hover.content_margin_left = 8
	bar_hover.content_margin_right = 8
	bar_hover.content_margin_top = 2
	bar_hover.content_margin_bottom = 2
	t.set_stylebox("hover", "MenuBar", bar_hover)
	var bar_pressed := _box(Color(0.0, 0.30, 0.38, 0.75), CYAN, 5, 1)
	bar_pressed.content_margin_left = 8
	bar_pressed.content_margin_right = 8
	bar_pressed.content_margin_top = 2
	bar_pressed.content_margin_bottom = 2
	t.set_stylebox("pressed", "MenuBar", bar_pressed)
	t.set_color("font_color", "MenuBar", TEXT)
	t.set_color("font_hover_color", "MenuBar", Color.WHITE)
	t.set_color("font_pressed_color", "MenuBar", CYAN)
	t.set_font_size("font_size", "MenuBar", 12)

	t.set_stylebox("hover", "PopupMenu", _zero(_box(Color(0.0, 0.32, 0.40, 0.75), CYAN_DIM, 5, 1)))
	var sep := StyleBoxLine.new()
	sep.color = Color(0.0, 0.7, 0.85, 0.25)
	sep.thickness = 1
	t.set_stylebox("separator", "PopupMenu", sep)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color(0.28, 0.36, 0.42))
	t.set_color("font_accelerator_color", "PopupMenu", CYAN_DIM)
	t.set_color("font_separator_color", "PopupMenu", TEXT_DIM)
	t.set_font_size("font_size", "PopupMenu", 12)
	t.set_constant("v_separation", "PopupMenu", 6)
	t.set_constant("item_start_padding", "PopupMenu", 10)
	t.set_constant("item_end_padding", "PopupMenu", 10)


static func _theme_misc(t: Theme) -> void:
	var sep_line := StyleBoxLine.new()
	sep_line.color = Color(0.0, 0.65, 0.80, 0.18)
	sep_line.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep_line)
	t.set_stylebox("separator", "VSeparator", sep_line)
	t.set_constant("separation", "HSeparator", 8)
	t.set_constant("separation", "VSeparator", 8)

	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("h_separation", "GridContainer", 8)
	t.set_constant("v_separation", "GridContainer", 5)


static func _theme_variations(t: Theme) -> void:
	# Section header for the collapsible left-panel cards.
	t.set_type_variation("NeonHeader", "Button")
	var h_normal := _box(Color(0, 0, 0, 0), Color(0.0, 0.55, 0.67, 0.28), 5, 0)
	h_normal.border_width_left = 2
	h_normal.border_width_bottom = 1
	h_normal.content_margin_left = 8
	h_normal.content_margin_right = 8
	h_normal.content_margin_top = 5
	h_normal.content_margin_bottom = 5

	var h_hover := _box(Color(0.0, 0.45, 0.58, 0.16), CYAN_DIM, 5, 0)
	h_hover.border_width_left = 2
	h_hover.border_width_bottom = 1
	h_hover.content_margin_left = 8
	h_hover.content_margin_right = 8
	h_hover.content_margin_top = 5
	h_hover.content_margin_bottom = 5

	var h_pressed := _box(Color(0.0, 0.55, 0.68, 0.20), CYAN, 5, 0, GLOW, 3)
	h_pressed.border_width_left = 3
	h_pressed.border_width_bottom = 1
	h_pressed.content_margin_left = 8
	h_pressed.content_margin_right = 8
	h_pressed.content_margin_top = 5
	h_pressed.content_margin_bottom = 5

	t.set_stylebox("normal", "NeonHeader", h_normal)
	t.set_stylebox("hover", "NeonHeader", h_hover)
	t.set_stylebox("pressed", "NeonHeader", h_pressed)
	t.set_stylebox("focus", "NeonHeader", _box(Color(0, 0, 0, 0), CYAN, 5, 1))
	t.set_color("font_color", "NeonHeader", CYAN)
	t.set_color("font_hover_color", "NeonHeader", Color.WHITE)
	t.set_color("font_pressed_color", "NeonHeader", CYAN)
	t.set_font_size("font_size", "NeonHeader", 12)

	# Primary action buttons.
	t.set_type_variation("NeonPrimary", "Button")
	t.set_stylebox("normal", "NeonPrimary", _box(Color(0.0, 0.30, 0.38, 0.85), CYAN, 6, 1, GLOW, 4))
	t.set_stylebox("hover", "NeonPrimary", _box(Color(0.0, 0.40, 0.50, 0.95), CYAN, 6, 1, GLOW, 7))
	t.set_stylebox("pressed", "NeonPrimary", _box(Color(0.0, 0.18, 0.24, 1.0), CYAN, 6, 1))
	t.set_stylebox("focus", "NeonPrimary", _box(Color(0, 0, 0, 0), CYAN, 6, 1))
	t.set_color("font_color", "NeonPrimary", Color.WHITE)
	t.set_color("font_hover_color", "NeonPrimary", Color.WHITE)
	t.set_color("font_pressed_color", "NeonPrimary", CYAN)

	# Destructive / clear actions.
	t.set_type_variation("NeonDanger", "Button")
	t.set_stylebox("normal", "NeonDanger", _box(Color(0.10, 0.03, 0.07, 0.9), Color(0.55, 0.10, 0.32), 6, 1))
	t.set_stylebox("hover", "NeonDanger", _box(Color(0.20, 0.04, 0.12, 0.95), MAGENTA, 6, 1, Color(1.0, 0.18, 0.65, 0.35), 4))
	t.set_stylebox("pressed", "NeonDanger", _box(Color(0.28, 0.04, 0.15, 1.0), MAGENTA, 6, 1, Color(1.0, 0.18, 0.65, 0.45), 6))
	t.set_color("font_color", "NeonDanger", Color(1.0, 0.75, 0.88))
	t.set_color("font_hover_color", "NeonDanger", Color.WHITE)
	t.set_color("font_pressed_color", "NeonDanger", Color.WHITE)

	# Card container for collapsible sections.
	t.set_type_variation("NeonCard", "PanelContainer")
	var card := _box(CARD, Color(0.0, 0.50, 0.62, 0.22), 9, 1)
	card.content_margin_left = 5
	card.content_margin_right = 5
	card.content_margin_top = 3
	card.content_margin_bottom = 5
	t.set_stylebox("panel", "NeonCard", card)
