extends PanelContainer
class_name CharCard
## 展示一枚实体字的卡片（奖励/商店/字袋界面都用它）。
## 想改卡面样式，只改这个文件。

signal clicked
signal hovered

var character: CharacterData
var compact := false
var selected := false

var _tile: Control
var _tile_rect: ColorRect
var _tile_glyph: Label
var _wood: ShaderMaterial
var _title: Label
var _desc: Label
var _tags: HBoxContainer
var _base_style: StyleBoxFlat


func setup(p_character: CharacterData, p_compact := false) -> void:
	character = p_character
	compact = p_compact


func _ready() -> void:
	theme_type_variation = "PanelCard"
	_base_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", _base_style)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not compact:
		custom_minimum_size = Vector2(196, 268)
	else:
		custom_minimum_size = Vector2(280, 74)
	_build()
	_apply()
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func(): hovered.emit())
	resized.connect(func(): pivot_offset = size * 0.5)


func _build() -> void:
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	add_child(pad)

	if compact:
		var row := Ink.hbox(12)
		pad.add_child(row)
		_tile = _make_tile(Vector2(52, 52), 30)
		row.add_child(_tile)
		var col := Ink.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_title = Ink.label("", "Subheading")
		_desc = Ink.caption("")
		_tags = Ink.hbox(4)
		col.add_child(_title)
		col.add_child(_desc)
		col.add_child(_tags)
		row.add_child(col)
	else:
		var col2 := Ink.vbox(8)
		pad.add_child(col2)
		var center := CenterContainer.new()
		_tile = _make_tile(Vector2(96, 96), 56)
		center.add_child(_tile)
		col2.add_child(center)
		_title = Ink.label("", "Subheading")
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col2.add_child(_title)
		_desc = Ink.caption("")
		_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col2.add_child(_desc)
		_tags = Ink.hbox(4)
		_tags.alignment = BoxContainer.ALIGNMENT_CENTER
		col2.add_child(_tags)


func _make_tile(tile_size: Vector2, font_size: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = tile_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tile_rect = ColorRect.new()
	_tile_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tile_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wood = Ink.make_wood_material()
	_wood.set_shader_parameter("tile_size", tile_size)
	_wood.set_shader_parameter("corner_radius", 8.0)
	_tile_rect.material = _wood
	holder.add_child(_tile_rect)
	_tile_glyph = Ink.label("", "", Palette.INK)
	_tile_glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tile_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tile_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tile_glyph.add_theme_font_size_override("font_size", font_size)
	_tile_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_tile_glyph)
	return holder


func _apply() -> void:
	if character == null:
		return
	_tile_glyph.text = character.glyph
	_title.text = character.glyph + ("  " + character.pinyin if not character.pinyin.is_empty() else "")
	_desc.text = character.description
	for c in _tags.get_children():
		c.queue_free()
	for tag in character.tags:
		var chip := Ink.label(Palette.tag_label(tag), "Muted")
		chip.add_theme_font_size_override("font_size", 13)
		chip.add_theme_color_override("font_color", Palette.INK_SOFT)
		_tags.add_child(chip)
	set_selected(selected)


func set_selected(value: bool) -> void:
	selected = value
	if not is_inside_tree():
		return
	var col := Palette.rarity_color(character.rarity if character else 0)
	var sb := _current_style()
	sb.border_color = Palette.GOLD if value else col
	sb.set_border_width_all(3 if value else 2)
	if value:
		sb.bg_color = Palette.PAPER_WARM


func _current_style() -> StyleBoxFlat:
	return _base_style


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit()
		accept_event()


func play_focus() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.06, 1.06), 0.08)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08)
