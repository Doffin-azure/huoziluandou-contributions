extends Control
class_name TileView
signal tile_pressed(pos: Vector2i)
signal tile_hovered(pos: Vector2i)

const TILE_SIZE := Vector2(88, 88)
var grid_pos := Vector2i.ZERO
var instance: CharInstance
var is_selected := false
var is_dimmed := false
var display_uid := -1
var display_key := ""
var art_badges: Array[String] = []
var art_tint := Color.WHITE
var motion_kind := ""
var _visual: Control
var _face: ColorRect
var _glyph: Label
var _sel_border: PanelContainer
var _status_row: HBoxContainer
var _uses_label: Label
var _order: Label
var _wood_mat: ShaderMaterial
var _motion: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false


func _ready() -> void:
	_build()
	Ink.board_font_changed.connect(_refresh_font)
	resized.connect(_resize_visual)
	_resize_visual()
	_refresh()


func _build() -> void:
	var slot := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PANEL_DARK.darkened(0.12)
	sb.border_color = Palette.WOOD_DARK.darkened(0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	slot.add_theme_stylebox_override("panel", sb)
	slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	_visual = Control.new()
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)
	_face = ColorRect.new()
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wood_mat = Ink.make_tile_material()
	_face.material = _wood_mat
	_visual.add_child(_face)
	_glyph = Ink.label("", "", Palette.INK)
	_glyph.add_theme_font_override("font", Ink.board_font)
	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_glyph)
	_status_row = Ink.hbox(2)
	_status_row.position = Vector2(5, 4)
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_status_row)
	_uses_label = Ink.label("", "", Palette.GOLD_DK)
	_uses_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_uses_label)
	_sel_border = PanelContainer.new()
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color.TRANSPARENT
	selected.set_corner_radius_all(5)
	selected.set_border_width_all(2)
	selected.border_color = Palette.VERMILION
	selected.shadow_size = 0
	_sel_border.add_theme_stylebox_override("panel", selected)
	_sel_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sel_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_sel_border)
	_order = Ink.label("", "", Palette.VERMILION_DK)
	_order.position = Vector2(6, 2)
	_order.add_theme_font_size_override("font_size", 14)
	_order.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_order)
	mouse_entered.connect(func(): tile_hovered.emit(grid_pos))
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tile_pressed.emit(grid_pos)
		accept_event()


func _resize_visual() -> void:
	if _wood_mat == null:
		return
	_wood_mat.set_shader_parameter("tile_size", size)
	_wood_mat.set_shader_parameter("corner_radius", 5.0)
	_glyph.add_theme_font_size_override("font_size", int(size.x * (0.34 if instance != null and instance.is_fused() else 0.57)))
	_uses_label.position = Vector2(size.x - 32, size.y - 27)
	_visual.pivot_offset = size * 0.5


func set_instance(inst: CharInstance) -> void:
	instance = inst
	motion_kind = ""
	display_uid = inst.uid if inst != null else -1
	if _visual == null:
		return
	_stop_motion()
	_visual.modulate = Color.WHITE
	_visual.scale = Vector2.ONE
	_visual.position = Vector2(0, -5 if is_selected and not Settings.reduced_motion else 0)
	_refresh()


func _refresh() -> void:
	if _glyph == null:
		return
	for c in _status_row.get_children():
		_status_row.remove_child(c)
		c.queue_free()
	_face.visible = instance != null
	_glyph.text = "" if instance == null else "".join(instance.glyph_list())
	_uses_label.visible = instance != null and instance.temporary_uses > 0
	_uses_label.text = "×%d" % (instance.temporary_uses + 1) if instance != null else ""
	display_key = ""
	if instance == null:
		_sel_border.hide()
		return
	_refresh_border()
	var tint := Color.WHITE
	if instance.owner == CharInstance.Owner.ENEMY:
		tint = Color(0.94, 0.76, 0.73)
	elif instance.owner == CharInstance.Owner.SELF_GENERATED:
		tint = Color(1.0, 0.86, 0.69)
	if instance.temporary:
		tint = Color(0.78, 0.90, 0.93)
	if instance.is_fused():
		tint = Color(0.85, 0.80, 0.92)
	Ink.tile_set_tint(_wood_mat, tint)
	art_tint = tint
	var badges: Array[String] = []
	if instance.gilded:
		badges.append("金")
	if instance.temporary:
		badges.append("临")
	if instance.word_only:
		badges.append("词")
	if instance.refined:
		badges.append("炼")
	if instance.pinned:
		badges.append("歇" if instance.pinned_exhausted else "固")
	for pid in instance.pollutions:
		var pd: PollutionData = Database.get_pollution(pid)
		if pd != null:
			badges.append(pd.glyph)
	for sid in instance.statuses:
		var sd: StatusData = Database.get_status(sid)
		if sd != null:
			badges.append(sd.glyph)
	for badge in badges:
		var chip := Ink.label(badge, "", Palette.VERMILION_DK)
		chip.add_theme_font_size_override("font_size", 13)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_status_row.add_child(chip)
	art_badges = badges
	display_key = _glyph.text + "|".join(badges) + str(instance.temporary_uses)
	_resize_visual()


func set_selected(value: bool, order := -1) -> void:
	var changed := is_selected != value
	is_selected = value
	if _sel_border == null:
		return
	_refresh_border()
	_order.visible = value and order >= 0
	_order.text = str(order + 1)
	_status_row.visible = not value
	if changed:
		motion_kind = "selection"
		_stop_motion()
		_visual.modulate.a = 1.0
		_visual.scale = Vector2.ONE
		_visual.position.x = 0
		var offset := -5.0 if value and not Settings.reduced_motion else 0.0
		_motion = create_tween()
		_motion.tween_property(_visual, "position:y", offset, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _refresh_border() -> void:
	if _sel_border == null: return
	_sel_border.visible = instance != null and (is_selected or instance.gilded)
	var style: StyleBoxFlat = _sel_border.get_theme_stylebox("panel").duplicate()
	style.border_color = Palette.VERMILION if is_selected else Palette.GOLD_DK
	_sel_border.add_theme_stylebox_override("panel", style)


func set_dimmed(value: bool) -> void:
	is_dimmed = value
	modulate = Color(0.65, 0.63, 0.60, 0.65) if value else Color.WHITE


func _stop_motion() -> void:
	if _motion != null:
		_motion.kill()


func shake() -> void:
	if Settings.reduced_motion:
		return
	_stop_motion()
	motion_kind = "shake"
	var base_y := -5.0 if is_selected else 0.0
	_visual.position = Vector2(0, base_y)
	_motion = create_tween()
	_motion.tween_property(_visual, "position:x", -3.0, 0.035)
	_motion.tween_property(_visual, "position:x", 3.0, 0.05)
	_motion.tween_property(_visual, "position:x", 0.0, 0.08)


func release(survives: bool) -> void:
	_stop_motion()
	motion_kind = "release"
	if Settings.reduced_motion:
		return
	_motion = create_tween().set_parallel(true)
	_motion.tween_property(_visual, "scale", Vector2(0.93, 0.93), 0.10)
	if not survives:
		_motion.tween_property(_visual, "modulate:a", 0.0, 0.10)


func enter(offset: Vector2, fresh: bool, delay: float) -> void:
	if Settings.reduced_motion or instance == null:
		return
	_stop_motion()
	motion_kind = "enter"
	_visual.position = offset
	_visual.modulate.a = 0.0 if fresh else 1.0
	_visual.scale = Vector2(0.92, 0.92) if fresh else Vector2.ONE
	_motion = create_tween().set_parallel(true)
	_motion.tween_property(_visual, "position", Vector2.ZERO, 0.18).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_visual, "scale", Vector2.ONE, 0.18).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_visual, "modulate:a", 1.0, 0.13).set_delay(delay)


func _refresh_font() -> void:
	_glyph.add_theme_font_override("font", Ink.board_font)
