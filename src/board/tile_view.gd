extends Control
class_name TileView
## 盘面上的一个“木活字”方块。纯代码绘制，改美术只需要改这里的数值/材质。

signal tile_pressed(pos: Vector2i)
signal tile_hovered(pos: Vector2i)

const TILE_SIZE := Vector2(76, 76)

var grid_pos := Vector2i.ZERO
var instance: CharInstance = null
var is_selected := false
var is_dimmed := false

var _visual: Control
var _face: ColorRect
var _glyph: Label
var _sel_border: PanelContainer
var _status_row: HBoxContainer
var _uses_label: Label
var _wood_mat: ShaderMaterial
var _base_offset := 0.0


func _init() -> void:
	custom_minimum_size = TILE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false


func _ready() -> void:
	_build()
	resized.connect(_update_shader_size)
	_update_shader_size()
	_refresh()


func _build() -> void:
	_visual = Control.new()
	_visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual)

	_face = ColorRect.new()
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wood_mat = Ink.make_tile_material()
	_face.material = _wood_mat
	_visual.add_child(_face)

	_glyph = Ink.label("", "", Palette.INK)
	_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph.add_theme_font_size_override("font_size", 42)
	_glyph.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.18))
	_glyph.add_theme_constant_override("shadow_offset_x", 0)
	_glyph.add_theme_constant_override("shadow_offset_y", 2)
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_glyph)

	# 角标：污染/状态
	_status_row = Ink.hbox(2)
	_status_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_row.position = Vector2(-58, 4)
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual.add_child(_status_row)

	# 临时层数
	_uses_label = Ink.label("", "", Palette.GOLD_DK)
	_uses_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_uses_label.position = Vector2(-30, -26)
	_uses_label.add_theme_font_size_override("font_size", 18)
	_uses_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uses_label.visible = false
	_visual.add_child(_uses_label)

	# 选中描边
	_sel_border = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_corner_radius_all(12 + Palette.CORNER_BONUS)
	sb.set_border_width_all(4)
	sb.border_color = Palette.VERMILION
	sb.shadow_color = Color(Palette.VERMILION.r, Palette.VERMILION.g, Palette.VERMILION.b, 0.5)
	sb.shadow_size = 10
	_sel_border.add_theme_stylebox_override("panel", sb)
	_sel_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sel_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sel_border.visible = false
	_visual.add_child(_sel_border)

	mouse_entered.connect(func(): tile_hovered.emit(grid_pos))
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tile_pressed.emit(grid_pos)
		accept_event()


func _update_shader_size() -> void:
	if _wood_mat == null:
		return
	_wood_mat.set_shader_parameter("tile_size", size)
	_wood_mat.set_shader_parameter("corner_radius", 12.0 + Palette.CORNER_BONUS)


func set_instance(inst: CharInstance) -> void:
	instance = inst
	_refresh()


func _refresh() -> void:
	if instance == null:
		_glyph.text = ""
		_face.visible = false
		_uses_label.visible = false
		for c in _status_row.get_children():
			c.queue_free()
		return
	_face.visible = true
	_glyph.text = instance.glyph()
	if instance.is_fused():
		_glyph.text = "".join(instance.glyph_list())
		_glyph.add_theme_font_size_override("font_size", 28)
	else:
		_glyph.add_theme_font_size_override("font_size", 42)
	var tint := Color.WHITE
	if instance.owner == CharInstance.Owner.ENEMY:
		tint = Color(0.82, 0.62, 0.62)
	elif instance.owner == CharInstance.Owner.SELF_GENERATED:
		tint = Color(1.0, 0.78, 0.5)
	if instance.temporary:
		tint = Color(0.6, 0.85, 0.94)
	if instance.is_fused():
		tint = Color(0.72, 0.66, 0.9)
	if _wood_mat != null:
		Ink.tile_set_tint(_wood_mat, tint)
	for c in _status_row.get_children():
		c.queue_free()
	if instance.temporary:
		var temp_chip := Ink.label("临", "", Color("2f6f88"))
		temp_chip.add_theme_font_size_override("font_size", 18)
		temp_chip.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.5))
		_status_row.add_child(temp_chip)
	for pid in instance.pollutions:
		var pd: PollutionData = Database.get_pollution(pid)
		if pd == null:
			continue
		var chip := Ink.label(pd.glyph, "", pd.color)
		chip.add_theme_font_size_override("font_size", 18)
		chip.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.5))
		_status_row.add_child(chip)
	for status_id in instance.statuses.keys():
		var sd: StatusData = Database.get_status(status_id)
		if sd == null:
			continue
		var chip2 := Ink.label(sd.glyph, "", sd.color)
		chip2.add_theme_font_size_override("font_size", 16)
		_status_row.add_child(chip2)
	_uses_label.visible = instance.temporary_uses > 0
	_uses_label.text = "×%d" % (instance.temporary_uses + 1)


func set_selected(value: bool) -> void:
	if is_selected == value:
		return
	is_selected = value
	_sel_border.visible = value
	var target := -8.0 if value else 0.0
	if _visual:
		var tw := create_tween()
		tw.tween_property(_visual, "position:y", target, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_dimmed(value: bool) -> void:
	is_dimmed = value
	modulate = Color(0.62, 0.6, 0.58, 0.85) if value else Color.WHITE


func shake() -> void:
	var tw := create_tween()
	var origin := _visual.position
	tw.tween_property(_visual, "position:x", origin.x - 6, 0.05)
	tw.tween_property(_visual, "position:x", origin.x + 6, 0.08)
	tw.tween_property(_visual, "position:x", origin.x, 0.06)
