# main.gd — Hytale Prefab Viewer
# All nodes live in main.tscn; this script wires signals and drives logic.
extends Control

# ═══ Scene nodes via %UniqueName ══════════════════════════════════════════════
@onready var _vp_ctr        : SubViewportContainer = %ViewportContainer
@onready var _sub_vp        : SubViewport           = %SubViewport
@onready var _world         : Node3D                = %WorldRoot
@onready var _renderer      : BlockRenderer         = %BlockRenderer
@onready var _cam_ctrl      : CameraController      = %CameraController
@onready var _editor        : BlockEditor           = %BlockEditor
@onready var _ref_mgr       : ReferenceImageManager = %RefManager
@onready var _overlay_ctr   : Control               = %OverlayContainer
@onready var _edit_overlay  : Control               = %EditOverlay

# Left panel
@onready var _btn_nav       : Button   = %BtnNav
@onready var _btn_paint     : Button   = %BtnPaint
@onready var _btn_erase     : Button   = %BtnErase
@onready var _btn_select    : Button   = %BtnSelect
@onready var _block_input   : LineEdit = %BlockNameEdit
@onready var _btn_copy_block: Button   = %BtnDuplicateBlock
@onready var _brush_btn1    : Button   = %BrushBtn1
@onready var _brush_btn3    : Button   = %BrushBtn3
@onready var _brush_btn5    : Button   = %BrushBtn5
@onready var _brush_btn7    : Button   = %BrushBtn7
@onready var _btn_dir_h     : Button   = %BtnDirH
@onready var _btn_dir_x     : Button   = %BtnDirX
@onready var _btn_dir_z     : Button   = %BtnDirZ
@onready var _height_spin   : SpinBox  = %BrushHeightSpin
@onready var _y_spin        : SpinBox  = %YLevelSpin
@onready var _btn_sel_rect  : Button   = %BtnSelRect
@onready var _btn_sel_circle: Button   = %BtnSelCircle
@onready var _sel_fill_chk  : CheckBox = %SelFillCheck
@onready var _sel_apply_btn : Button   = %SelApplyBtn
@onready var _sel_clear_btn : Button   = %SelClearBtn
@onready var _block_ct_lbl  : Label    = %BlockCountLbl
@onready var _type_ct_lbl   : Label    = %TypeCountLbl
@onready var _bounds_lbl    : Label    = %BoundsLbl
@onready var _coord_lbl     : Label    = %CoordLbl

# Bottom palette (NEW: TabContainer + Search)
@onready var _palette_tabs      : TabContainer  = %PaletteTabs
@onready var _palette_search    : LineEdit      = %PaletteSearch
@onready var _palette_btn       : Button        = %PaletteCollapseBtn
@onready var _bottom_panel      : PanelContainer= %BottomPanel

# Right panel
@warning_ignore("unused_private_class_variable")
@onready var _right_tabs    : TabContainer  = %RightTabs
@onready var _grp_select    : OptionButton  = %ActiveGroupSelect
@onready var _grp_add_btn   : Button        = %GrpAddBtn
@onready var _grp_rem_btn   : Button        = %GrpRemBtn
@onready var _grp_show_all  : Button        = %GrpShowAll
@onready var _grp_hide_all  : Button        = %GrpHideAll
@onready var _groups_vbox   : VBoxContainer = %GroupsVBox
@onready var _cam_selector  : OptionButton  = %CamSelector
@onready var _cam_add_btn   : Button        = %CamAddBtn
@onready var _cam_rem_btn   : Button        = %CamRemBtn
@onready var _cam_repo_btn  : Button        = %CamRepoBtn
@onready var _cameras_vbox  : VBoxContainer = %CamerasVBox
@onready var _load_img_btn  : Button        = %LoadImgBtn
@onready var _opacity_pct   : Label         = %OpacityPctLbl
@onready var _opacity_slider: HSlider       = %OpacitySlider
@onready var _scale_pct     : Label         = %ScalePctLbl
@onready var _scale_slider  : HSlider       = %ScaleSlider

@onready var _status_lbl    : Label         = %StatusLabel



# ═══ File dialogs ══════════════════════════════════════════════════════════════
var _dlg_import  : FileDialog
var _dlg_export  : FileDialog
var _dlg_save    : FileDialog
var _dlg_open    : FileDialog
var _dlg_img     : FileDialog



# ═══ Runtime state ═════════════════════════════════════════════════════════════
var _cam_counter  : int    = 0
var _sel_entry    : ReferenceImageManager.RefEntry = null
var _active_tool  : BlockEditor.Tool = BlockEditor.Tool.SELECT
var _bottom_open  : bool   = true
var _grid_mesh    : MeshInstance3D

const BLOCK_BUTTON_SCENE := preload("res://scenes/block_palette_button.tscn")

# ═══ BLOCK PALETTE ═══════════════════════════════════════════════════════════
# La paleta real ahora se carga desde `res://data/generated_block_palette.json`.
# Este diccionario queda vacío como fallback legacy.
const BLOCK_PALETTE : Dictionary = {}

# Store all palette buttons for search filtering
var _palette_buttons : Array = []

# Copy block mode
var _copy_block_mode : bool = false


# ── UNDO/REDO SYSTEM ──────────────────────────────────────────────────────────
var _undo_stack : Array = []
var _redo_stack : Array = []
var _last_block_state : Dictionary = {}
const MAX_UNDO_STEPS := 50

# ── OCCLUSION CULLING ─────────────────────────────────────────────────────────
var _occlusion_enabled : bool = true
var _cull_distance     : float = 100.0  # Bloques más allá de esto no se renderizan
const CHUNK_SIZE       : int = 16

# ── GIZMO ─────────────────────────────────────────────────────────────────────
@onready var _axis_gizmo  = %AxisGizmo  

var _sel_shape_pick  : OptionButton = null
var _sel_mode_pick   : OptionButton = null
var _sel_action_pick : OptionButton = null
var _sel_border_spin : SpinBox = null




# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	# Force include resources

	
	_build_3d_scene()
	_build_palette()
	_build_menus()
	_init_dialogs()
	_ensure_selection_controls()
	_connect_signals()
	_refresh_groups()
	_rebuild_cam_list()
	
	# ── Setup Gizmo ───────────────────────────────────────────────────────────
	if _axis_gizmo:
		_axis_gizmo.setup(_cam_ctrl)
	
	get_tree().get_root().files_dropped.connect(_on_files_dropped)
	_status("Ready — load a .prefab.json or drag one here.")
	
	
	var view_pm := %MenuBar.get_node("View") as PopupMenu
	if view_pm:
		view_pm.about_to_popup.connect(func():
			_refresh_view_menu_checks(view_pm)
		)
	
	_sync_undo_baseline(true)




# ═════════════════════════════════════════════════════════════════════════════
#  MENUS - Corregir "New Project" para limpiar cámaras
# ═════════════════════════════════════════════════════════════════════════════

func _on_file_menu(id: int) -> void:
	match id:
		10:  # New Project
			_renderer.clear_all()
			_refresh_groups()
			_clear_all_cameras()  # ✅ NUEVO: Limpiar cámaras
			_sync_undo_baseline(true)
			_status("New project.")
		11: _dlg_open.popup_centered(Vector2i(900,620))
		12: _dlg_save.popup_centered(Vector2i(900,620))
		13: _dlg_import.popup_centered(Vector2i(900,620))
		14:
			if _renderer.get_block_count() == 0:
				_status("⚠ No blocks to export.")
			else:
				_dlg_export.popup_centered(Vector2i(900,620))


# ═════════════════════════════════════════════════════════════════════════════
#  CAMERA RESTORATION - Corregido
# ═════════════════════════════════════════════════════════════════════════════

func _clear_all_cameras() -> void:
	# Limpiar todas las cámaras de referencia
	for cam in _cam_ctrl.get_ref_cameras():
		var entry := _ref_mgr.get_entry_for_camera(cam)
		if entry: _ref_mgr.remove_entry(entry)
		_cam_ctrl.remove_reference_camera(cam)
	
	# Limpiar UI
	for c in _cameras_vbox.get_children(): 
		c.queue_free()
	_cam_selector.clear()
	_cam_selector.add_item("🎥 Aerial (Free Nav)", 0)
	
	# Resetear estado
	_cam_counter = 0
	_sel_entry = null
	_cam_ctrl.switch_to_aerial()


func _restore_cameras(data: Dictionary) -> void:
	_clear_all_cameras()

	if data.has("cameras"):
		for cam_data in data["cameras"]:
			var cname : String = cam_data.get("name", "Camera_00")
			var cam   := _cam_ctrl.add_reference_camera(cname, false)
			# Restore saved transform AND sync internal cam state so
			# switch_to_ref_camera() won't overwrite it with the default.
			if cam_data.has("position"):
				var saved_t := ProjectManager.array_to_cam_transform(
					cam_data["position"] as Array
				)
				_cam_ctrl.initialize_ref_camera_from_saved(cam, saved_t)

			var num := int(cname.split("_")[-1]) if "_" in cname else 0
			if num > _cam_counter:
				_cam_counter = num

	_rebuild_cam_list()

func _restore_ref_images(data: Dictionary) -> void:
	if not data.has("ref_images"):
		return

	for img_data in data["ref_images"]:
		var cam_name : String = img_data.get("cam", "")
		var cam := _find_camera_by_name(cam_name)
		if cam == null:
			continue

		var entry := _ref_mgr.get_entry_for_camera(cam)
		if entry == null:
			entry = _ref_mgr.add_entry(cam, cam_name)

		# Restore metadata first
		entry.opacity   = img_data.get("opacity", 0.5)
		entry.scale_val = img_data.get("scale",   1.0)

		# Only mark as having an image when the file actually exists
		var img_path : String = img_data.get("path", "")
		if not img_path.is_empty() and FileAccess.file_exists(img_path):
			_ref_mgr.load_image_for(entry, img_path)
			_ref_mgr.set_opacity(entry, entry.opacity)
			_ref_mgr.set_scale(entry, entry.scale_val)
		else:
			entry.image_path = img_path
			entry.has_image  = false

	# Always hide every overlay here; _restore_state / camera-change logic
	# will make the correct one visible for the active ref camera.
	_ref_mgr.hide_all()
	_rebuild_cam_list()

func _restore_state(state: Dictionary) -> void:
	# Restaurar panel inferior
	var bottom_was_open := _bottom_open
	_bottom_open = state.get("bottom_open", true)
	if bottom_was_open != _bottom_open:
		_toggle_bottom()
	
	# Restaurar herramienta activa
	var tool = state.get("active_tool", BlockEditor.Tool.SELECT)
	_set_tool(tool)
	
	# Restaurar contador de cámaras
	_cam_counter = state.get("cam_counter", 0)
	
	# Restaurar cámara activa
	var active_name = state.get("active_camera", "aerial")
	if active_name == "aerial":
		_cam_ctrl.switch_to_aerial()
		_sel_entry = null
	else:
		var cam := _find_camera_by_name(active_name)
		if cam:
			_cam_ctrl.switch_to_ref_camera(cam)
			var entry := _ref_mgr.get_entry_for_camera(cam)
			if entry:
				_pick_cam(cam, entry)


func _find_camera_by_name(Name: String) -> Camera3D:
	for cam in _cam_ctrl.get_ref_cameras():
		if cam.name == Name:
			return cam
	return null







# ═════════════════════════════════════════════════════════════════════════════
#  CAMERAS PANEL
# ═════════════════════════════════════════════════════════════════════════════

func _on_add_cam() -> void:
	_cam_counter += 1
	var cname := "Camera_%02d" % _cam_counter
	var cam   := _cam_ctrl.add_reference_camera(cname, true)
	var entry := _ref_mgr.add_entry(cam, cname)
	_add_cam_row(cname, cam, entry)
	_rebuild_cam_list()  # ✅ Reconstruir lista completa
	_status("Camera '%s' added at current aerial pose." % cname)


func _add_cam_row(cname: String, cam: Camera3D, entry: ReferenceImageManager.RefEntry) -> void:
	var hb := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = cname
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 11)
	hb.add_child(lbl)
	var sel := Button.new()
	sel.text = "Use"
	sel.custom_minimum_size = Vector2(38, 0)
	sel.pressed.connect(func(): _pick_cam(cam, entry))
	hb.add_child(sel)
	_cameras_vbox.add_child(hb)


@warning_ignore("unused_parameter")
func _pick_cam(cam: Camera3D, entry: ReferenceImageManager.RefEntry) -> void:
	_sel_entry = entry
	_opacity_slider.value = entry.opacity
	_opacity_pct.text = "%d%%" % int(entry.opacity * 100)
	_scale_slider.value = entry.scale_val
	_scale_pct.text = "%d%%" % int(entry.scale_val * 100)
	_status("Selected: '%s'." % entry.cam_name)


func _on_remove_cam() -> void:
	if _sel_entry == null:
		_status("⚠ Select a camera from the list first."); return
	var cname := _sel_entry.cam_name
	var cam   := _sel_entry.camera
	_ref_mgr.remove_entry(_sel_entry)
	_cam_ctrl.remove_reference_camera(cam)
	_sel_entry = null
	_rebuild_cam_list()  # ✅ Reconstruir después de eliminar
	_status("Camera '%s' removed." % cname)


func _on_repo_cam() -> void:
	if _sel_entry == null:
		_status("⚠ Select a camera from the list first."); return
	_cam_ctrl.reposition_to_aerial(_sel_entry.camera)
	_status("'%s' repositioned to current aerial view." % _sel_entry.cam_name)


func _rebuild_cam_list() -> void:
	# ✅ Limpiar lista actual
	for c in _cameras_vbox.get_children(): 
		c.queue_free()
	_cam_selector.clear()
	
	# ✅ SIEMPRE agregar cámara aérea como primera opción (índice 0)
	_cam_selector.add_item("🎥 Aerial (Free Nav)", 0)
	
	# Agregar cámaras de referencia
	for e in _ref_mgr.get_all_entries():
		_add_cam_row(e.cam_name, e.camera, e)
		_cam_selector.add_item("📷 " + e.cam_name)


func _on_cam_selected(index: int) -> void:
	if index == 0:
		# ✅ Cámara aérea libre
		_cam_ctrl.switch_to_aerial()
		_sel_entry = null
		_status("Switched to Aerial Camera (Free Navigation)")
	else:
		# ✅ Cámara de referencia
		var entries := _ref_mgr.get_all_entries()
		var ei := index - 1
		if ei >= 0 and ei < entries.size():
			_cam_ctrl.switch_to_ref_camera(entries[ei].camera)
			_pick_cam(entries[ei].camera, entries[ei])


func _on_cam_changed(cname: String) -> void:
	if cname == "aerial":
		_ref_mgr.hide_all()
	else:
		for e in _ref_mgr.get_all_entries():
			if e.cam_name == cname:
				_ref_mgr.show_for_camera(e.camera)
				return
		_ref_mgr.hide_all()


func _on_load_img() -> void:
	if _sel_entry == null:
		# Auto-select first cam if only one exists
		var entries := _ref_mgr.get_all_entries()
		if entries.size() == 1:
			_pick_cam(entries[0].camera, entries[0])
		else:
			_status("⚠ Select a camera first."); return
	_dlg_img.popup_centered(Vector2i(900, 620))


func _on_img_selected(path: String) -> void:
	if _sel_entry == null:
		_status("⚠ Select a ref camera before loading an image."); return
	var ok := _ref_mgr.load_image_for(_sel_entry, path)
	if ok:
		if _cam_ctrl.get_active_camera() == _sel_entry.camera:
			_ref_mgr.show_for_camera(_sel_entry.camera)
	else:
		_status("❌ Failed to load image.")


func _on_opacity_changed(v: float) -> void:
	_opacity_pct.text = "%d%%" % int(v * 100)
	if _sel_entry: _ref_mgr.set_opacity(_sel_entry, v)


func _on_scale_changed(v: float) -> void:
	_scale_pct.text = "%d%%" % int(v * 100)
	if _sel_entry:
		_ref_mgr.set_scale(_sel_entry, v)
		_overlay_ctr.queue_redraw()





# ═════════════════════════════════════════════════════════════════════════════
#  3-D world bootstrapping
# ═════════════════════════════════════════════════════════════════════════════

func _build_3d_scene() -> void:
	_editor.setup(_renderer, _cam_ctrl, _vp_ctr, _sub_vp, _world)
	_ref_mgr.setup(_overlay_ctr)
	_setup_grid()


func _setup_grid() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	const H := 50
	for i in range(-H, H+1):
		var fi := float(i)
		st.set_color(Color(0.85,0.25,0.25,0.9) if i==0 else Color(0.28,0.30,0.35,0.5))
		st.add_vertex(Vector3(fi,0,-H)); st.add_vertex(Vector3(fi,0,H))
		st.set_color(Color(0.25,0.45,0.85,0.9) if i==0 else Color(0.28,0.30,0.35,0.5))
		st.add_vertex(Vector3(-H,0,fi)); st.add_vertex(Vector3(H,0,fi))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grid_mesh = MeshInstance3D.new()
	_grid_mesh.mesh = st.commit()
	_grid_mesh.set_surface_override_material(0, mat)
	_world.add_child(_grid_mesh)


# ═════════════════════════════════════════════════════════════════════════════
#  PALETTE (TabContainer with search) - CON FALLBACK
# ═════════════════════════════════════════════════════════════════════════════

func _build_palette() -> void:
	_palette_buttons.clear()
	
	# ⚠️ FALLBACK: Crear nodos si no existen en la escena
	if _palette_tabs == null:
		_create_palette_nodes()
	
	for child in _palette_tabs.get_children():
		child.queue_free()
	
	BlockCatalog.reload()
	var palette_map = BlockCatalog.get_palette_map(BLOCK_PALETTE)
	
	# Create tab for each category
	for cat_name in palette_map.keys():
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, 180)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(grid)
		
		_palette_tabs.add_child(scroll)
		var tab_idx := _palette_tabs.get_tab_count() - 1
		_palette_tabs.set_tab_title(tab_idx, String(cat_name))
		
		for bname in palette_map[cat_name]:
			var btn := _create_block_button(String(bname), String(cat_name))
			grid.add_child(btn)
			_palette_buttons.append(btn)


# Crea los nodos de la paleta programáticamente si no existen
func _create_palette_nodes() -> void:
	# Create search box
	var search := LineEdit.new()
	search.name = "PaletteSearch"
	search.placeholder_text = "🔍 Search blocks..."
	search.custom_minimum_size = Vector2(0, 30)
	_bottom_panel.get_node("BottomVBox").add_child(search)
	_palette_search = search
	
	# Create scroll container
	var scroll := ScrollContainer.new()
	scroll.name = "PaletteScroll"
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_bottom_panel.get_node("BottomVBox").add_child(scroll)
	
	# Create tab container
	var tabs := TabContainer.new()
	tabs.name = "PaletteTabs"
	scroll.add_child(tabs)
	_palette_tabs = tabs
	
	# Connect search signal
	search.text_changed.connect(_filter_palette)

func _create_block_button(bname: String, category: String = "") -> Button:
	var btn: Button = null
	var custom_scene := BlockCatalog.get_scene_for(bname)
	
	if custom_scene != null:
		btn = custom_scene.instantiate() as Button
	else:
		var fallback_btn := BLOCK_BUTTON_SCENE.instantiate() as BlockPaletteButton
		fallback_btn.configure_fallback(bname, category, _renderer.get_preview_color(bname))
		btn = fallback_btn
	
	if btn == null:
		btn = Button.new()
		btn.text = bname.replace("_", " ")
		btn.tooltip_text = bname
		btn.custom_minimum_size = Vector2(140, 28)
	
	if btn is BlockPaletteButton:
		(btn as BlockPaletteButton).refresh_visuals()
	
	btn.set_meta("block_name", bname)
	btn.pressed.connect(_on_palette_button_pressed.bind(btn))
	return btn


func _on_palette_button_pressed(btn: Button) -> void:
	var bname := btn.get_meta("block_name") as String
	_pick_palette_block(bname)


# Search filter function
func _filter_palette(search_text: String) -> void:
	var query := search_text.to_lower().strip_edges()
	
	for btn in _palette_buttons:
		var matches := true
		if btn is BlockPaletteButton:
			matches = (btn as BlockPaletteButton).matches_query(query)
		else:
			var bname := btn.get_meta("block_name") as String
			matches = query.is_empty() or bname.to_lower().contains(query)
		btn.visible = matches
	
	# Optionally switch to first tab with visible buttons
	if not query.is_empty():
		for i in range(_palette_tabs.get_tab_count()):
			var tab := _palette_tabs.get_child(i)
			if tab is ScrollContainer:
				var grid := tab.get_child(0)
				if grid is GridContainer:
					for btn in grid.get_children():
						if btn.visible:
							_palette_tabs.current_tab = i
							return


# ═════════════════════════════════════════════════════════════════════════════
#  SELECTION UI ENHANCEMENTS
# ═════════════════════════════════════════════════════════════════════════════

func _ensure_selection_controls() -> void:
	var left_vbox := get_node_or_null("RootVBox/WorkHBox/LeftPanel/LeftScroll/LM/LeftVBox") as VBoxContainer
	if left_vbox == null:
		return
	
	_btn_sel_rect.text = "Rect"
	_btn_sel_circle.text = "Circle"
	_sel_fill_chk.visible = false
	
	var insert_at := left_vbox.get_children().find(_sel_fill_chk)
	if insert_at < 0:
		insert_at = left_vbox.get_child_count()
	
	var shape_row := left_vbox.get_node_or_null("SelShapeAdvancedRow") as HBoxContainer
	if shape_row == null:
		shape_row = HBoxContainer.new()
		shape_row.name = "SelShapeAdvancedRow"
		shape_row.add_theme_constant_override("separation", 6)
		
		var shape_lbl := Label.new()
		shape_lbl.text = "Shape"
		shape_row.add_child(shape_lbl)
		
		_sel_shape_pick = OptionButton.new()
		_sel_shape_pick.name = "SelShapeOption"
		_sel_shape_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sel_shape_pick.add_item("Rectangle", BlockEditor.SelShape.RECT)
		_sel_shape_pick.add_item("Circle", BlockEditor.SelShape.CIRCLE)
		_sel_shape_pick.add_item("Box / Cube", BlockEditor.SelShape.BOX)
		_sel_shape_pick.add_item("Cylinder", BlockEditor.SelShape.CYLINDER)
		_sel_shape_pick.add_item("Sphere", BlockEditor.SelShape.SPHERE)
		_sel_shape_pick.add_item("Pyramid", BlockEditor.SelShape.PYRAMID)
		shape_row.add_child(_sel_shape_pick)
		
		left_vbox.add_child(shape_row)
		left_vbox.move_child(shape_row, mini(insert_at + 1, left_vbox.get_child_count() - 1))
	else:
		_sel_shape_pick = shape_row.get_node_or_null("SelShapeOption") as OptionButton
	
	if _sel_shape_pick:
		_sel_shape_pick.clear()
		_sel_shape_pick.add_item("Rectangle", BlockEditor.SelShape.RECT)
		_sel_shape_pick.add_item("Circle", BlockEditor.SelShape.CIRCLE)
		_sel_shape_pick.add_item("Box / Cube", BlockEditor.SelShape.BOX)
		_sel_shape_pick.add_item("Cylinder", BlockEditor.SelShape.CYLINDER)
		_sel_shape_pick.add_item("Sphere", BlockEditor.SelShape.SPHERE)
		_sel_shape_pick.add_item("Pyramid", BlockEditor.SelShape.PYRAMID)
	
	var mode_row := left_vbox.get_node_or_null("SelModeRow") as HBoxContainer
	if mode_row == null:
		mode_row = HBoxContainer.new()
		mode_row.name = "SelModeRow"
		mode_row.add_theme_constant_override("separation", 6)
		
		var mode_lbl := Label.new()
		mode_lbl.text = "Mode"
		mode_row.add_child(mode_lbl)
		
		_sel_mode_pick = OptionButton.new()
		_sel_mode_pick.name = "SelModeOption"
		_sel_mode_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sel_mode_pick.add_item("Filled", BlockEditor.SelMode.SOLID)
		_sel_mode_pick.add_item("Hollow", BlockEditor.SelMode.HOLLOW)
		_sel_mode_pick.add_item("Border", BlockEditor.SelMode.BORDER)
		mode_row.add_child(_sel_mode_pick)
		
		left_vbox.add_child(mode_row)
		left_vbox.move_child(mode_row, mini(insert_at + 2, left_vbox.get_child_count() - 1))
	else:
		_sel_mode_pick = mode_row.get_node_or_null("SelModeOption") as OptionButton
	
	if _sel_mode_pick:
		_sel_mode_pick.clear()
		_sel_mode_pick.add_item("Filled", BlockEditor.SelMode.SOLID)
		_sel_mode_pick.add_item("Hollow", BlockEditor.SelMode.HOLLOW)
		_sel_mode_pick.add_item("Border", BlockEditor.SelMode.BORDER)
	
	var action_row := left_vbox.get_node_or_null("SelActionRow") as HBoxContainer
	if action_row == null:
		action_row = HBoxContainer.new()
		action_row.name = "SelActionRow"
		action_row.add_theme_constant_override("separation", 6)
		
		var action_lbl := Label.new()
		action_lbl.text = "Action"
		action_row.add_child(action_lbl)
		
		_sel_action_pick = OptionButton.new()
		_sel_action_pick.name = "SelActionOption"
		_sel_action_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(_sel_action_pick)
		
		left_vbox.add_child(action_row)
		left_vbox.move_child(action_row, mini(insert_at + 3, left_vbox.get_child_count() - 1))
	else:
		_sel_action_pick = action_row.get_node_or_null("SelActionOption") as OptionButton
	
	if _sel_action_pick:
		_sel_action_pick.clear()
		_sel_action_pick.add_item("Place Blocks", BlockEditor.SelAction.PAINT)
		_sel_action_pick.add_item("Erase Blocks", BlockEditor.SelAction.ERASE)
	
	var border_row := left_vbox.get_node_or_null("SelBorderRow") as HBoxContainer
	if border_row == null:
		border_row = HBoxContainer.new()
		border_row.name = "SelBorderRow"
		border_row.add_theme_constant_override("separation", 6)
		
		var border_lbl := Label.new()
		border_lbl.text = "Border"
		border_row.add_child(border_lbl)
		
		_sel_border_spin = SpinBox.new()
		_sel_border_spin.name = "SelBorderSpin"
		_sel_border_spin.min_value = 1
		_sel_border_spin.max_value = 16
		_sel_border_spin.step = 1
		_sel_border_spin.value = 1
		_sel_border_spin.custom_minimum_size = Vector2(80, 0)
		border_row.add_child(_sel_border_spin)
		
		left_vbox.add_child(border_row)
		left_vbox.move_child(border_row, mini(insert_at + 4, left_vbox.get_child_count() - 1))
	else:
		_sel_border_spin = border_row.get_node_or_null("SelBorderSpin") as SpinBox
	
	if _sel_shape_pick:
		_sel_shape_pick.select(int(_editor.sel_shape))
	if _sel_mode_pick:
		_sel_mode_pick.select(int(_editor.sel_mode))
	if _sel_action_pick:
		_sel_action_pick.select(int(_editor.sel_action))
	if _sel_border_spin:
		_sel_border_spin.value = _editor.sel_border_thickness
	_refresh_selection_ui()


func _select_selection_shape(shape: int) -> void:
	_editor.set_sel_shape(shape)
	_btn_sel_rect.button_pressed = (shape == BlockEditor.SelShape.RECT)
	_btn_sel_circle.button_pressed = (shape == BlockEditor.SelShape.CIRCLE)
	if _sel_shape_pick and _sel_shape_pick.selected != int(shape):
		_sel_shape_pick.select(int(shape))


func _set_selection_mode(mode: int) -> void:
	_editor.set_sel_mode(mode)
	if _sel_mode_pick and _sel_mode_pick.selected != int(mode):
		_sel_mode_pick.select(int(mode))
	_refresh_selection_ui()


func _set_selection_action(action: int) -> void:
	_editor.set_sel_action(action)
	if _sel_action_pick and _sel_action_pick.selected != int(action):
		_sel_action_pick.select(int(action))
	_sel_apply_btn.text = "Apply Selection (Erase)" if action == BlockEditor.SelAction.ERASE else "Apply Selection (Place)"


func _refresh_selection_ui() -> void:
	if _sel_border_spin and is_instance_valid(_sel_border_spin):
		var show_border := true
		if _sel_mode_pick:
			show_border = _sel_mode_pick.selected != int(BlockEditor.SelMode.SOLID)
		_sel_border_spin.get_parent().visible = show_border
	if _sel_action_pick and _sel_action_pick.selected < 0:
		_sel_action_pick.select(int(_editor.sel_action))
	_set_selection_action(_sel_action_pick.selected if _sel_action_pick else int(_editor.sel_action))


# ═════════════════════════════════════════════════════════════════════════════
#  MENUS
# ═════════════════════════════════════════════════════════════════════════════

func _build_menus() -> void:
	var file_pm := %MenuBar.get_node("File") as PopupMenu
	file_pm.add_item("New Project",    10)
	file_pm.add_item("Open Project…",  11)
	file_pm.add_item("Save Project…",  12)
	file_pm.add_separator()
	file_pm.add_item("Import Prefab…", 13)
	file_pm.add_item("Export Prefab…", 14)
	file_pm.id_pressed.connect(_on_file_menu)

	var view_pm := %MenuBar.get_node("View") as PopupMenu
	view_pm.add_check_item("Show Grid",            20)
	view_pm.set_item_checked(0, true)
	view_pm.add_separator()
	view_pm.add_check_item("Tools Panel (left)",   21)
	view_pm.set_item_checked(2, true)
	view_pm.add_check_item("Groups/Cameras (right)",22)
	view_pm.set_item_checked(3, true)
	view_pm.add_check_item("Palette (bottom)",     23)
	view_pm.set_item_checked(4, true)
	view_pm.add_separator()
	view_pm.add_item("Center View",   24)
	view_pm.add_item("Reset Camera",  25)
	view_pm.add_check_item("Occlusion Culling",  26)  
	view_pm.set_item_checked(6, _occlusion_enabled)
	view_pm.id_pressed.connect(_on_view_menu)
	view_pm.add_check_item("Show Axis Gizmo", 27)  
	view_pm.set_item_checked(7, true)

	var help_pm := %MenuBar.get_node("Help") as PopupMenu
	help_pm.add_item("Controls",  30)
	help_pm.add_item("About",     31)
	help_pm.id_pressed.connect(_on_help_menu)


# ═════════════════════════════════════════════════════════════════════════════
#  SIGNAL CONNECTIONS
# ═════════════════════════════════════════════════════════════════════════════

func _connect_signals() -> void:
	# Mode buttons
	_btn_nav.pressed.connect(func(): _set_tool(BlockEditor.Tool.SELECT))
	_btn_paint.pressed.connect(func():
		_set_selection_action(BlockEditor.SelAction.PAINT)
		_set_tool(BlockEditor.Tool.PAINT)
	)
	_btn_erase.pressed.connect(func():
		_set_selection_action(BlockEditor.SelAction.ERASE)
		_set_tool(BlockEditor.Tool.ERASE)
	)
	_btn_select.pressed.connect(func(): _set_tool(BlockEditor.Tool.SHAPE_SELECT))

	# Block name
	_block_input.text_changed.connect(func(t): _editor.set_block_name(t))
	_btn_copy_block.pressed.connect(_on_copy_block)

	# Brush sizes
	_brush_btn1.pressed.connect(func(): _set_brush(1))
	_brush_btn3.pressed.connect(func(): _set_brush(3))
	_brush_btn5.pressed.connect(func(): _set_brush(5))
	_brush_btn7.pressed.connect(func(): _set_brush(7))

	# Brush direction
	_btn_dir_h.pressed.connect(func(): _set_brush_plane(BlockEditor.BrushPlane.HORIZONTAL))
	_btn_dir_x.pressed.connect(func(): _set_brush_plane(BlockEditor.BrushPlane.VERTICAL_X))
	_btn_dir_z.pressed.connect(func(): _set_brush_plane(BlockEditor.BrushPlane.VERTICAL_Z))

	# Height + Y level
	_height_spin.value_changed.connect(func(v): _editor.set_brush_height(int(v)))
	_y_spin.value_changed.connect(func(v): _editor.set_y_level(int(v)))

	# Selection shape
	_btn_sel_rect.pressed.connect(func():
		_select_selection_shape(BlockEditor.SelShape.RECT)
	)
	_btn_sel_circle.pressed.connect(func():
		_select_selection_shape(BlockEditor.SelShape.CIRCLE)
	)
	_sel_fill_chk.toggled.connect(func(v):
		if _sel_mode_pick == null:
			_editor.set_sel_fill(v)
		else:
			_set_selection_mode(BlockEditor.SelMode.SOLID if v else BlockEditor.SelMode.HOLLOW)
	)
	if _sel_shape_pick:
		_sel_shape_pick.item_selected.connect(func(index):
			_select_selection_shape(index)
		)
	if _sel_mode_pick:
		_sel_mode_pick.item_selected.connect(func(index):
			_set_selection_mode(index)
		)
	if _sel_action_pick:
		_sel_action_pick.item_selected.connect(func(index):
			_set_selection_action(index)
		)
	if _sel_border_spin:
		_sel_border_spin.value_changed.connect(func(v):
			_editor.set_sel_border_thickness(int(v))
		)
	_sel_apply_btn.pressed.connect(func(): _editor.apply_selection(); _status("Selection applied."))
	_sel_clear_btn.pressed.connect(func(): _editor.clear_selection(); _status("Selection cleared."))

	# Palette collapse & search
	_palette_btn.pressed.connect(func(): _toggle_bottom())
	_palette_search.text_changed.connect(_filter_palette)

	# Groups tab
	_grp_add_btn.pressed.connect(_on_add_group)
	_grp_rem_btn.pressed.connect(_on_remove_group)
	_grp_show_all.pressed.connect(func(): _renderer.show_all_groups(); _refresh_groups())
	_grp_hide_all.pressed.connect(func(): _renderer.hide_all_groups(); _refresh_groups())
	_grp_select.item_selected.connect(_on_active_group_changed)

	# Cameras tab
	_cam_add_btn.pressed.connect(_on_add_cam)
	_cam_rem_btn.pressed.connect(_on_remove_cam)
	_cam_repo_btn.pressed.connect(_on_repo_cam)
	_cam_selector.item_selected.connect(_on_cam_selected)
	_load_img_btn.pressed.connect(_on_load_img)
	_opacity_slider.value_changed.connect(_on_opacity_changed)
	_scale_slider.value_changed.connect(_on_scale_changed)

	# Renderer
	_renderer.blocks_changed.connect(_on_blocks_changed)

	# Camera
	_cam_ctrl.camera_changed.connect(_on_cam_changed)

	# Editor signals
	_editor.action_performed.connect(func(): pass)
	_editor.preview_moved.connect(func(gp: Vector3i):
		_coord_lbl.text = "Cursor  X%d  Y%d  Z%d" % [gp.x, gp.y, gp.z]
	)

	# Viewport input
	_edit_overlay.gui_input.connect(_on_vp_input)
	_edit_overlay.mouse_exited.connect(func(): _editor.handle_exit())
	
	
	 # Editor signals
	_editor.action_performed.connect(_on_editor_action)
	_editor.preview_moved.connect(func(gp: Vector3i):
		_coord_lbl.text = "Cursor  X%d  Y%d  Z%d" % [gp.x, gp.y, gp.z]
	)
	
	
	
	# ── UNDO/REDO HOTKEYS ─────────────────────────────────────────────────────
	var shortcut_undo := Shortcut.new()
	var key_undo := InputEventKey.new()
	key_undo.keycode = KEY_Z
	key_undo.ctrl_pressed = true
	shortcut_undo.events = [key_undo]
	
	var shortcut_redo := Shortcut.new()
	var key_redo := InputEventKey.new()
	key_redo.keycode = KEY_Y
	key_redo.ctrl_pressed = true
	shortcut_redo.events = [key_redo]
	
	# También Ctrl+Shift+Z para redo (alternativo)
	var shortcut_redo2 := Shortcut.new()
	var key_redo2 := InputEventKey.new()
	key_redo2.keycode = KEY_Z
	key_redo2.ctrl_pressed = true
	key_redo2.shift_pressed = true
	shortcut_redo2.events = [key_redo2]


# ═════════════════════════════════════════════════════════════════════════════
#  UNDO/REDO SYSTEM
# ═════════════════════════════════════════════════════════════════════════════

func _capture_block_state() -> Dictionary:
	var groups_data := {}
	for gn in _renderer.get_group_names():
		var gd: BlockRenderer.GroupData = _renderer.get_group_data(gn)
		if gd == null:
			continue
		groups_data[gn] = {
			"blocks": gd.blocks.duplicate(true),
			"visible": gd.node.visible,
			"label": gd.label
		}
	return {"groups": groups_data}


func _sync_undo_baseline(clear_history: bool = false) -> void:
	_last_block_state = _capture_block_state()
	if clear_history:
		_undo_stack.clear()
		_redo_stack.clear()


func _get_undo_action_name() -> String:
	match _active_tool:
		BlockEditor.Tool.PAINT:
			return "Paint"
		BlockEditor.Tool.ERASE:
			return "Erase"
		BlockEditor.Tool.SHAPE_SELECT:
			return "Selection"
		_:
			return "Edit"


func _on_editor_action() -> void:
	var current_state := _capture_block_state()
	if current_state == _last_block_state:
		return
	
	_push_undo(_get_undo_action_name(), _last_block_state, current_state)
	_last_block_state = current_state


func _push_undo(action: String, before: Dictionary, after: Dictionary) -> void:
	_undo_stack.append({
		"action": action,
		"before": before.duplicate(true),
		"after": after.duplicate(true)
	})
	
	# Limitar tamaño del stack
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	
	# Limpiar redo stack cuando hay nueva acción
	_redo_stack.clear()
	
	_status("Action: %s (Undo: %d)" % [action, _undo_stack.size()])


func _do_undo() -> void:
	if _undo_stack.is_empty():
		_status("⚠ Nothing to undo.")
		return
	
	var action = _undo_stack.pop_back()
	_redo_stack.append(action)
	
	# Restaurar estado "before"
	_restore_block_state(action["before"])
	_last_block_state = action["before"].duplicate(true)
	_status("↩ Undo: %s" % action["action"])


func _do_redo() -> void:
	if _redo_stack.is_empty():
		_status("⚠ Nothing to redo.")
		return
	
	var action = _redo_stack.pop_back()
	_undo_stack.append(action)
	
	# Restaurar estado "after"
	_restore_block_state(action["after"])
	_last_block_state = action["after"].duplicate(true)
	_status("↪ Redo: %s" % action["action"])


func _restore_block_state(state: Dictionary) -> void:
	# Limpiar todos los bloques actuales
	_renderer.clear_all()
	
	# Restaurar estado guardado
	if state.has("groups"):
		for gn in state["groups"]:
			var gdata = state["groups"][gn]
			_renderer.create_group(gn)
			for k in gdata.get("blocks", {}):
				var p = k.split(",")
				if p.size() == 3:
					_renderer.add_block(
						Vector3i(int(p[0]), int(p[1]), int(p[2])),
						gdata["blocks"][k],
						gn
					)
			_renderer.set_group_visible(gn, gdata.get("visible", true))
	
	_renderer.rebuild_all()
	_refresh_groups()
	_update_occlusion_culling()


# En las funciones donde se modifican bloques, agregar tracking:

func _on_blocks_changed(total: int, unique_types: int) -> void:
	_block_ct_lbl.text = str(total)
	_type_ct_lbl.text  = str(unique_types)
	var sz: Vector3 = _renderer.get_bounds().get("size", Vector3.ZERO)
	if sz != Vector3.ZERO:
		_bounds_lbl.text = "%d × %d × %d" % [int(sz.x), int(sz.y), int(sz.z)]
	_refresh_groups()
	_update_occlusion_culling()  # ✅ Actualizar culling cuando cambian bloques







func _input(event: InputEvent) -> void:
	# Manejar atajos de teclado para undo/redo
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and event.ctrl_pressed and not event.shift_pressed:
			_do_undo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y and event.ctrl_pressed:
			_do_redo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z and event.ctrl_pressed and event.shift_pressed:
			_do_redo()
			get_viewport().set_input_as_handled()




# ═════════════════════════════════════════════════════════════════════════════
#  VIEWPORT INPUT ROUTING
# ═════════════════════════════════════════════════════════════════════════════

func _on_vp_input(event: InputEvent) -> void:
	var ct_size  := _vp_ctr.size
	var vp_size  := Vector2(_sub_vp.size)
	var mouse_vp := Vector2.ZERO
	if ct_size.x > 0.0 and ct_size.y > 0.0 and event is InputEventMouse:
		mouse_vp = (event as InputEventMouse).position / ct_size * vp_size

	# Handle copy block mode
	if _copy_block_mode and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Get the grid position where user clicked
			var gpos := _editor._ray_to_grid(mb.position)
			# Get the block at that position
			var block_name := _renderer.get_block_at(gpos)
			if block_name.is_empty():
				_status("❌ No block at that position")
			else:
				# Copy the block name to the input field
				_block_input.text = block_name
				_editor.set_block_name(block_name)
				_status("✅ Block copied: '%s'" % block_name)
			# Exit copy block mode
			_copy_block_mode = false
			_btn_copy_block.button_pressed = false
			get_viewport().set_input_as_handled()
			return

	match _active_tool:
		BlockEditor.Tool.SELECT:
			_cam_ctrl.process_event(event, mouse_vp)

		BlockEditor.Tool.PAINT, BlockEditor.Tool.ERASE, BlockEditor.Tool.SHAPE_SELECT:
			if event is InputEventMouseMotion:
				_editor.handle_hover((event as InputEventMouseMotion).position)
			elif event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT:
					if mb.pressed: _editor.handle_press(mb.position)
					else:          _editor.handle_release()
			# Forward scroll/pan/orbit to camera even in edit modes
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
									   MOUSE_BUTTON_MIDDLE,   MOUSE_BUTTON_RIGHT]:
					_cam_ctrl.process_event(event, mouse_vp)
			elif event is InputEventMouseMotion:
				var mm := event as InputEventMouseMotion
				if mm.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT):
					_cam_ctrl.process_event(event, mouse_vp)


# ═════════════════════════════════════════════════════════════════════════════
#  DRAG & DROP
# ═════════════════════════════════════════════════════════════════════════════

func _on_files_dropped(files: PackedStringArray) -> void:
	for path in files:
		var ext := path.get_extension().to_lower()
		if ext == "json":
			var data := ProjectManager.load_file(path)
			if data.get("format","") == "hpv_project":
				_apply_project(data)
			else:
				_do_import(path)
			return
		elif ext in ["png","jpg","jpeg","webp"]:
			_on_img_selected(path)
			return
	_status("⚠ Unrecognized file type.")


# ═════════════════════════════════════════════════════════════════════════════
#  DIALOGS
# ═════════════════════════════════════════════════════════════════════════════

func _init_dialogs() -> void:
	_dlg_import = _make_dlg(FileDialog.FILE_MODE_OPEN_FILE,
		["*.json"], "Import Prefab", _on_import_selected)
	_dlg_export = _make_dlg(FileDialog.FILE_MODE_SAVE_FILE,
		["*.json"], "Export Prefab", _on_export_selected)
	_dlg_export.current_file = "my_structure.prefab.json"
	_dlg_save   = _make_dlg(FileDialog.FILE_MODE_SAVE_FILE,
		["*.json"], "Save Project", _on_save_selected)
	_dlg_save.current_file = "my_project.hvproj.json"
	_dlg_open   = _make_dlg(FileDialog.FILE_MODE_OPEN_FILE,
		["*.json"], "Open Project", _on_open_selected)
	_dlg_img    = _make_dlg(FileDialog.FILE_MODE_OPEN_FILE,
		["*.png","*.jpg,*.jpeg","*.webp"], "Load Reference Image", _on_img_selected)


func _make_dlg(mode:int, filters:Array, title:String, cb:Callable) -> FileDialog:
	var d := FileDialog.new()
	@warning_ignore("int_as_enum_without_cast")
	d.file_mode = mode
	d.access    = FileDialog.ACCESS_FILESYSTEM
	d.filters   = PackedStringArray(filters)
	d.title     = title
	d.file_selected.connect(cb)
	add_child(d)
	return d


# ═════════════════════════════════════════════════════════════════════════════
#  MENUS
# ═════════════════════════════════════════════════════════════════════════════

func _on_view_menu(id: int) -> void:
	var view_pm := %MenuBar.get_node("View") as PopupMenu
	if not view_pm:
		return
	
	match id:
		20:  # Show Grid
			if _grid_mesh:
				_grid_mesh.visible = !_grid_mesh.visible
		
		21:  # Tools Panel (left)
			var lp = get_node_or_null("RootVBox/WorkHBox/LeftPanel") as Control
			if lp:
				lp.visible = !lp.visible
		
		22:  # Groups/Cameras (right)
			var rp = get_node_or_null("RootVBox/WorkHBox/RightPanel") as Control
			if rp:
				rp.visible = !rp.visible
		
		23:  # Palette (bottom)
			_toggle_bottom()
		
		
		24:  # Occlusion Culling
			_occlusion_enabled = !_occlusion_enabled
			_update_occlusion_culling()
			_status("Occlusion Culling: %s" % ("ON" if _occlusion_enabled else "OFF"))
		
		25:  # Show Axis Gizmo
			if _axis_gizmo:
				_axis_gizmo.visible = !_axis_gizmo.visible
			_status("Axis Gizmo: %s" % ("ON" if _axis_gizmo.visible else "OFF"))
		
		26:  # Center View
			_cam_ctrl.focus_on(_renderer.get_center())
			_status("View centered.")
			return   # No necesita refrescar checks
		
		27:  # Reset Camera
			_cam_ctrl.focus_on(Vector3.ZERO)
			_status("Camera reset.")
			return
		
		
	
	# ← IMPORTANTE: Siempre refrescar los checks después de cualquier cambio
	_refresh_view_menu_checks(view_pm)


# Función auxiliar para actualizar todos los checks visuales del menú
func _refresh_view_menu_checks(view_pm: PopupMenu) -> void:
	if not view_pm:
		return
	
	# Actualizar estado visual de cada ítem check
	view_pm.set_item_checked(0, _grid_mesh.visible if _grid_mesh else false)      # Show Grid
	
	var lp = get_node_or_null("RootVBox/WorkHBox/LeftPanel") as Control
	view_pm.set_item_checked(2, lp.visible if lp else true)                       # Tools Panel (left)
	
	var rp = get_node_or_null("RootVBox/WorkHBox/RightPanel") as Control
	view_pm.set_item_checked(3, rp.visible if rp else true)                       # Right Panel
	
	view_pm.set_item_checked(4, _bottom_open)                                     # Palette (bottom)
	
	view_pm.set_item_checked(6, _occlusion_enabled)                               # Occlusion Culling  ← CORREGIDO
	
	if _axis_gizmo:
		view_pm.set_item_checked(7, _axis_gizmo.visible)                          # Show Axis Gizmo  ← CORREGIDO
	else:
		view_pm.set_item_checked(7, false)

func _on_help_menu(id: int) -> void:
	match id:
		30: _show_controls_dlg()
		31: _show_about_dlg()


func _show_controls_dlg() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Controls & Shortcuts"
	dialog.min_size = Vector2i(700, 540)
	dialog.ok_button_text = "Close"
	
	# Scroll container
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2i(680, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.custom_minimum_size = Vector2i(660, 0)
	rtl.add_theme_font_size_override("normal_font_size", 15)
	rtl.add_theme_constant_override("line_separation", 8)
	
	rtl.text = """
[center][font_size=19][b]Controls & Shortcuts[/b][/font_size][/center]

[color=#ffcc77]─── Camera Navigation (Works in all camera modes) ───[/color]
• [b]W A S D[/b] or [b]Arrow Keys[/b] → Move camera (XZ plane)
• [b]Q[/b] / [b]E[/b] → Move camera up / down (Y axis)
• [b]Mouse Wheel[/b] → Zoom In / Out
• [b]Middle Mouse Button + Drag[/b] → Pan camera
• [b]Right Mouse Button + Drag[/b] → Orbit camera

[color=#ffcc77]─── Tool Modes ───[/color]
• [b]Navigate[/b] → Free camera movement only
• [b]Paint[/b] → Left click to place blocks
• [b]Erase[/b] → Left click to remove blocks
• [b]Select[/b] → Drag to define area → then click Apply

[color=#ffcc77]─── Keyboard Shortcuts ───[/color]
• [b]Ctrl + Z[/b] → Undo last action
• [b]Ctrl + Y[/b] or [b]Ctrl + Shift + Z[/b] → Redo
• [b]H[/b] → Horizontal brush plane (XZ)
• [b]X[/b] → Vertical brush plane facing X (uses Height)
• [b]Z[/b] → Vertical brush plane facing Z (uses Height)

[color=#ffcc77]─── Selection Tool ───[/color]
• Switch to [b]Select[/b] mode
• Drag to define the base area of the shape
• Use [b]Shape[/b] to choose Rectangle, Circle, Box, Cylinder, Sphere or Pyramid
• Use [b]Mode[/b] to choose Filled, Hollow or Border
• Use [b]Action[/b] to place or erase the selected blocks
• [b]Brush Height[/b] controls the height of 3D shapes
• [b]Border[/b] controls shell / outline thickness
• Press [b]Apply[/b] to execute the selection

[color=#ffcc77]─── Groups & Cameras ───[/color]
• Right panel → [b]Groups[/b] tab: Organize your blocks
• Right panel → [b]Cameras[/b] tab: Save viewpoints with reference images
• Click [b]Use[/b] to switch to that camera
• Click [b]Repos.[/b] to copy current view to selected camera

[color=#ffcc77]─── View Options ───[/color]
• Top-right corner → [b]Axis Gizmo[/b] (shows camera orientation)
• Menu [b]View[/b] → Toggle "Show Axis Gizmo", Grid, Panels, etc.

[color=#88ffaa]Tip:[/color] Mouse Wheel, Middle Mouse and Right Mouse always control the camera, even while in Paint or Erase mode.
"""

	vbox.add_child(rtl)
	scroll.add_child(vbox)
	dialog.add_child(scroll)
	
	add_child(dialog)
	dialog.popup_centered()
	
	# Clean up when closed
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _show_about_dlg() -> void:
	var d := AcceptDialog.new()
	d.title = "About"
	d.dialog_text = (
		"Hytale Prefab Viewer\n"
		+"Scale-accurate structure planning tool.\n\n"
		+"Not affiliated with Hypixel Studios or Hytale."
	)
	add_child(d)
	d.popup_centered()
	d.confirmed.connect(d.queue_free)


# ═════════════════════════════════════════════════════════════════════════════
#  IMPORT / EXPORT / SAVE / LOAD
# ═════════════════════════════════════════════════════════════════════════════

# ═════════════════════════════════════════════════════════════════════════════
#  IMPORT / EXPORT / SAVE / LOAD
# ═════════════════════════════════════════════════════════════════════════════

func _on_save_selected(path: String) -> void:
	if not path.ends_with(".json"): path += ".json"
	
	# ── Serialize groups ──────────────────────────────────────────────────────
	var groups_data := {}  # ✅ Agregado 'var'
	for gn in _renderer.get_group_names():
		var gd: BlockRenderer.GroupData = _renderer.get_group_data(gn)
		groups_data[gn] = {
			"blocks":  gd.blocks.duplicate(),
			"visible": gd.node.visible,
			"label":   gd.label
		}
	
	# ── Serialize cameras ─────────────────────────────────────────────────────
	var cams_data := []  # ✅ Agregado 'var'
	for cam in _cam_ctrl.get_ref_cameras():
		cams_data.append({
			"name":     cam.name,
			"position": ProjectManager.cam_transform_to_array(cam.global_transform)
		})
	
	# ── Serialize reference images ────────────────────────────────────────────
	var imgs_data := []  # ✅ Agregado 'var'
	for e in _ref_mgr.get_all_entries():
		imgs_data.append({
			"cam":       e.cam_name,
			"path":      e.image_path,
			"opacity":   e.opacity,
			"scale":     e.scale_val,
			"has_image": e.has_image
		})
	
	# ── Serialize app state ───────────────────────────────────────────────────
	var state_data := {}  # ✅ Agregado 'var'
	@warning_ignore("incompatible_ternary")
	state_data["active_camera"] = _cam_ctrl.get_active_camera().name if _cam_ctrl.get_active_camera() else "aerial"
	state_data["bottom_open"]   = _bottom_open
	state_data["active_tool"]   = int(_active_tool)
	state_data["cam_counter"]   = _cam_counter
	
	# ── Save all data ─────────────────────────────────────────────────────────
	var err = ProjectManager.save(path, groups_data, cams_data, imgs_data, state_data)
	if err == OK:
		_status("✅ Saved: %s (%d blocks, %d cameras)" % [path.get_file(), _renderer.get_block_count(), cams_data.size()])
	else:
		_status("❌ Save error %d" % err)


func _on_open_selected(path: String) -> void:
	_status("Opening: %s …" % path.get_file())
	var data := ProjectManager.load_file(path)  # ✅ Agregado 'var'
	if data.is_empty():
		_do_import(path)
		return
	_apply_project(data)
	_status("✅ Opened: %s" % path.get_file())


func _apply_project(data: Dictionary) -> void:  # ✅ Agregado tipo de parámetro
	_renderer.clear_all()
	
	# ── Restore groups ────────────────────────────────────────────────────────
	if data.has("groups"):
		for gn in data["groups"]:
			var gdata = data["groups"][gn]
			_renderer.create_group(gn)
			for k in gdata.get("blocks", {}):
				var p = k.split(",")
				if p.size() == 3:
					_renderer.add_block(Vector3i(int(p[0]), int(p[1]), int(p[2])), gdata["blocks"][k], gn)
			_renderer.set_group_visible(gn, gdata.get("visible", true))
			_renderer.rename_group_label(gn, gdata.get("label", ""))
	elif data.has("blocks"):  # legacy flat format
		for k in data["blocks"]:
			var p = k.split(",")
			if p.size() == 3:
				_renderer.add_block(Vector3i(int(p[0]), int(p[1]), int(p[2])), data["blocks"][k])
	
	_renderer.rebuild_all()
	_refresh_groups()
	_cam_ctrl.focus_on(_renderer.get_center())
	
	# ── Restore cameras ───────────────────────────────────────────────────────
	_restore_cameras(data)
	
	# ── Restore reference images ──────────────────────────────────────────────
	_restore_ref_images(data)
	
	# ── Restore app state ─────────────────────────────────────────────────────
	if data.has("state"):
		_restore_state(data["state"])
	
	_sync_undo_baseline(true)




func _on_import_selected(path: String) -> void: _do_import(path)

func _do_import(path: String) -> void:
	_status("Loading: %s …" % path.get_file())
	var data := PrefabLoader.load_from_file(path)
	if data.is_empty():
		_status("❌ Failed to parse."); return
	_renderer.load_from_prefab(data)
	_cam_ctrl.focus_on(_renderer.get_center())
	_refresh_groups()
	_sync_undo_baseline(true)
	_status("✅ Imported: %s" % path.get_file())


func _on_export_selected(path: String) -> void:
	if not path.ends_with(".json"): path += ".json"
	var err := PrefabExporter.export_to_file(_renderer.get_all_blocks(), path)
	if err == OK:
		_status("✅ Exported: %s (%d blocks)" % [path.get_file(), _renderer.get_block_count()])
	else:
		_status("❌ Export error %d" % err)



# ═════════════════════════════════════════════════════════════════════════════
#  GROUPS PANEL
# ═════════════════════════════════════════════════════════════════════════════

func _refresh_groups() -> void:
	for c in _groups_vbox.get_children():
		c.queue_free()
	_grp_select.clear()

	var names := _renderer.get_group_names()
	for gn in names:
		var gd: BlockRenderer.GroupData = _renderer.get_group_data(gn)
		_grp_select.add_item(gn)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_groups_vbox.add_child(row)

		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(14, 14)
		sw.color = gd.color
		row.add_child(sw)

		var eye := CheckBox.new()
		eye.button_pressed = gd.node.visible
		eye.custom_minimum_size = Vector2(20, 0)
		var cap = gn
		eye.toggled.connect(func(v):
			_renderer.set_group_visible(cap, v)
			_sync_undo_baseline()
		)
		row.add_child(eye)

		var label_text = gd.label if gd.label != "" else gn
		var lbl := Label.new()
		lbl.text = "%s (%d)" % [label_text, gd.blocks.size()]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)

		var ren := Button.new()
		ren.text = "✏"
		ren.custom_minimum_size = Vector2(26, 0)
		ren.pressed.connect(func(): _rename_group(cap))
		row.add_child(ren)

	var cur_grp := _editor.active_group
	var idx := names.find(cur_grp)
	if idx >= 0:
		_grp_select.selected = idx
	elif not names.is_empty():
		_grp_select.selected = 0
		_editor.set_active_group(names[0])


func _on_add_group() -> void:
	var d := ConfirmationDialog.new()
	d.title = "New Group"
	var le := LineEdit.new()
	le.placeholder_text = "Group name…"
	d.add_child(le)
	d.min_size = Vector2i(300, 110)
	add_child(d)
	d.popup_centered()
	d.confirmed.connect(func():
		var n := le.text.strip_edges()
		if n == "": n = "Group_%d" % (_renderer.get_group_names().size() + 1)
		_renderer.create_group(n)
		_editor.set_active_group(n)
		_refresh_groups()
		_sync_undo_baseline()
		_status("Group '%s' created." % n)
		d.queue_free()
	)
	d.canceled.connect(d.queue_free)


func _on_remove_group() -> void:
	var sel_idx := _grp_select.selected
	var names   := _renderer.get_group_names()
	if sel_idx < 0 or sel_idx >= names.size():
		_status("⚠ Select a group first."); return
	var gn = names[sel_idx]
	if gn == "Default":
		_status("⚠ Cannot remove the Default group."); return
	_renderer.remove_group(gn)
	_editor.set_active_group("Default")
	_refresh_groups()
	_sync_undo_baseline()
	_status("Group '%s' removed (blocks moved to Default)." % gn)


func _on_active_group_changed(index: int) -> void:
	var names := _renderer.get_group_names()
	if index >= 0 and index < names.size():
		_editor.set_active_group(names[index])


func _rename_group(gn: String) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Rename Group Label"
	var le := LineEdit.new()
	le.text = _renderer.get_group_data(gn).label
	le.placeholder_text = "Display label (empty = use ID)…"
	d.add_child(le)
	d.min_size = Vector2i(320, 110)
	add_child(d)
	d.popup_centered()
	d.confirmed.connect(func():
		_renderer.rename_group_label(gn, le.text.strip_edges())
		_refresh_groups()
		_sync_undo_baseline()
		d.queue_free()
	)
	d.canceled.connect(d.queue_free)




# ═════════════════════════════════════════════════════════════════════════════
#  TOOLS
# ═════════════════════════════════════════════════════════════════════════════

func _set_tool(t: BlockEditor.Tool) -> void:
	_active_tool = t
	_editor.set_tool(t)
	_btn_nav.button_pressed    = (t == BlockEditor.Tool.SELECT)
	_btn_paint.button_pressed  = (t == BlockEditor.Tool.PAINT)
	_btn_erase.button_pressed  = (t == BlockEditor.Tool.ERASE)
	_btn_select.button_pressed = (t == BlockEditor.Tool.SHAPE_SELECT)
	match t:
		BlockEditor.Tool.SELECT:       _status("Navigate — orbit/pan/zoom freely")
		BlockEditor.Tool.PAINT:        _status("Paint — click to place blocks")
		BlockEditor.Tool.ERASE:        _status("Erase — click to remove blocks")
		BlockEditor.Tool.SHAPE_SELECT: _status("Select — drag a 2D/3D shape, adjust mode/height, then Apply")


func _pick_palette_block(bname: String) -> void:
	_block_input.text = bname
	_editor.set_block_name(bname)
	if _active_tool == BlockEditor.Tool.SELECT:
		_set_tool(BlockEditor.Tool.PAINT)
	_status("Block: %s" % bname)


func _set_brush(Size: int) -> void:
	_editor.set_brush_size(Size)
	_brush_btn1.button_pressed = (Size == 1)
	_brush_btn3.button_pressed = (Size == 3)
	_brush_btn5.button_pressed = (Size == 5)
	_brush_btn7.button_pressed = (Size == 7)


func _set_brush_plane(p: BlockEditor.BrushPlane) -> void:
	_editor.set_brush_plane(p)
	_btn_dir_h.button_pressed = (p == BlockEditor.BrushPlane.HORIZONTAL)
	_btn_dir_x.button_pressed = (p == BlockEditor.BrushPlane.VERTICAL_X)
	_btn_dir_z.button_pressed = (p == BlockEditor.BrushPlane.VERTICAL_Z)
	match p:
		BlockEditor.BrushPlane.HORIZONTAL: _status("Brush: Horizontal (XZ plane)")
		BlockEditor.BrushPlane.VERTICAL_X: _status("Brush: Vertical facing X — uses Height setting")
		BlockEditor.BrushPlane.VERTICAL_Z: _status("Brush: Vertical facing Z — uses Height setting")


# ═════════════════════════════════════════════════════════════════════════════
#  MISC
# ═════════════════════════════════════════════════════════════════════════════


func _toggle_bottom() -> void:
	_bottom_open = !_bottom_open
	var scroll  : Control = _bottom_panel.get_node("BottomVBox/PaletteScroll")
	var sep_node: Control = _bottom_panel.get_node("BottomVBox/PalHdrSep")
	scroll.visible   = _bottom_open
	sep_node.visible = _bottom_open
	_bottom_panel.custom_minimum_size.y = 220 if _bottom_open else 30
	_palette_btn.text = "▾" if _bottom_open else "▸"


func _status(msg: String) -> void:
	if _status_lbl: _status_lbl.text = "  " + msg



# ═════════════════════════════════════════════════════════════════════════════
#  OCCLUSION CULLING SYSTEM
# ═════════════════════════════════════════════════════════════════════════════

func _update_occlusion_culling() -> void:
	if not _occlusion_enabled:
		# Mostrar todos los grupos
		for gn in _renderer.get_group_names():
			_renderer.set_group_visible(gn, true)
		return
	
	var cam_pos := _cam_ctrl.get_active_camera().global_position
	var chunks_to_show : Array = []
	
	# Calcular chunks visibles desde la cámara
	var cam_chunk := Vector3i(
		int(cam_pos.x / CHUNK_SIZE),
		int(cam_pos.y / CHUNK_SIZE),
		int(cam_pos.z / CHUNK_SIZE)
	)
	
	# Calcular radio de chunks a renderizar
	var chunk_radius := int(ceil(_cull_distance / CHUNK_SIZE))
	
	# Marcar chunks visibles
	for x in range(-chunk_radius, chunk_radius + 1):
		for y in range(-chunk_radius, chunk_radius + 1):
			for z in range(-chunk_radius, chunk_radius + 1):
				var chunk_pos := cam_chunk + Vector3i(x, y, z)
				chunks_to_show.append(chunk_pos)
	
	# Actualizar visibilidad de grupos basado en chunks
	# (Esto es simplificado - idealmente cada grupo tendría info de sus bounds)
	var bounds := _renderer.get_bounds()
	if bounds.is_empty():
		return
	
	# Si los bounds están dentro del rango visible, mostrar todo
	var center = bounds.get("center", Vector3.ZERO)
	var dist := cam_pos.distance_to(center)
	
	if dist > _cull_distance:
		# Ocultar grupos lejanos (optimización básica)
		for gn in _renderer.get_group_names():
			var gd := _renderer.get_group_data(gn)
			if gd:
				# Verificar si algún bloque del grupo está en rango
				var any_visible := false
				for k in gd.blocks:
					var p = k.split(",")
					var block_pos := Vector3(int(p[0]), int(p[1]), int(p[2]))
					if cam_pos.distance_to(block_pos) < _cull_distance:
						any_visible = true
						break
				gd.node.visible = any_visible
	else:
		# Todo visible
		for gn in _renderer.get_group_names():
			_renderer.set_group_visible(gn, true)


# ═════════════════════════════════════════════════════════════════════════════
# BLOCK COPY/DUPLICATE
# ═════════════════════════════════════════════════════════════════════════════

func _on_copy_block() -> void:
	if _copy_block_mode:
		# Cancel copy mode
		_copy_block_mode = false
		_btn_copy_block.button_pressed = false
		_status("Copy block mode cancelled")
	else:
		# Enter copy block mode
		_copy_block_mode = true
		_btn_copy_block.button_pressed = true
		_status("📋 Copy block mode: Click on a block in the scene to copy it")



@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	# Actualizar oclusión culling periódicamente (cada 0.5 segundos)
	# Para no hacerlo en cada frame
	var time := Time.get_ticks_msec()
	if time % 500 < 20:  # Ejecutar aprox cada 500ms
		_update_occlusion_culling()
