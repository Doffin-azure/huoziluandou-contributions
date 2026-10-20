extends Control
class_name StatusStrip
## 汉字状态方牌：单字、右下角层数；溢出以 +数量 方牌打开完整说明。
signal details_requested(title: String, body: String, scroll_body: bool)
var entries: Array = []
var _ui_scale := 1.0
var _signature := ""
var _buttons: Array[Button] = []
var _items: Dictionary = {}


func _ready() -> void:
	add_to_group("effect_help_avoid")
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_rebuild)
	_rebuild()


func set_entries(value: Array) -> void:
	entries = value
	_rebuild()


func set_ui_scale(value: float) -> void:
	_ui_scale = value
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var cell := 36.0 * _ui_scale
	var gap := 4.0 * _ui_scale
	var capacity := maxi(1, int((size.x + gap) / (cell + gap)))
	var signature := str(entries) + str(capacity) + str(_ui_scale) + Palette.STYLE_ID
	if signature == _signature:
		return
	_signature = signature
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_items.clear()
	var shown := mini(entries.size(), capacity if entries.size() <= capacity else maxi(0, capacity - 1))
	for index in shown:
		var entry: Dictionary = entries[index]
		var glyph := str(entry.get("glyph", "状")).left(1)
		if glyph.is_empty(): glyph = "状"
		var color: Color = entry.get("color", Palette.GOLD)
		color = color.lerp(Palette.PAPER_WARM, 0.52)
		var button := _badge(str(entry.id), glyph, cell, gap, color)
		button.tooltip_text = "%s · %d %s\n%s" % [entry.name, entry.stacks, entry.get("unit", "层"), entry.description]
		button.pressed.connect(_show_entry.bind(entry))
		var count := _label(str(entry.stacks), "Stacks", Palette.PAPER_WARM, 12)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.add_theme_color_override("font_shadow_color", Palette.INK)
		count.add_theme_constant_override("shadow_offset_x", maxi(1, roundi(_ui_scale)))
		count.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(_ui_scale)))
		# Keep exact multi-digit counts inside the tile, without widening the row.
		var face := count.get_theme_font("font")
		var font_size := count.get_theme_font_size("font_size")
		while font_size > maxi(8, int(8 * _ui_scale)) and face.get_string_size(count.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > cell - 4 * _ui_scale:
			font_size -= 1
		count.add_theme_font_size_override("font_size", font_size)
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.offset_left = 2 * _ui_scale
		count.offset_right = -2 * _ui_scale
		button.add_child(count)
	if entries.size() > shown:
		var hidden := entries.size() - shown
		var more := _badge("more", "+%d" % hidden, cell, gap, Palette.INK_SOFT, true)
		more.tooltip_text = "另有 %d 项，查看全部状态与能力" % hidden
		more.pressed.connect(_show_details)


func _label(value: String, node_name: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.add_theme_font_override("font", Ink.sans)
	label.add_theme_font_size_override("font_size", int(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	return label


func _badge(id: String, glyph: String, cell: float, gap: float, color: Color, more := false) -> Button:
	var button := Ink.button("")
	button.name = "Status_" + id.replace(":", "_")
	button.custom_minimum_size = Vector2.ONE * cell
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.PAPER_WARM if more else Palette.PANEL_DARK
	style.border_color = Palette.BORDER_SOFT.lightened(0.12)
	style.set_border_width_all(maxi(1, roundi(1.5 * _ui_scale)))
	style.set_corner_radius_all(maxi(2, roundi(5 * _ui_scale)))
	style.set_content_margin_all(0)
	button.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Palette.PAPER if more else Palette.WOOD
	hover.border_color = Palette.GOLD.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = style.duplicate()
	pressed.bg_color = Palette.PAPER_DARK if more else Palette.WOOD_DARK
	button.add_theme_stylebox_override("pressed", pressed)
	var focus: StyleBoxFlat = style.duplicate()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Palette.PAPER
	focus.set_border_width_all(maxi(2, roundi(2 * _ui_scale)))
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("disabled", style)
	# A single fixed row; text and counts never stretch the reserved HUD area.
	button.position = Vector2(_buttons.size() * (cell + gap), 0)
	add_child(button)
	button.size = Vector2.ONE * cell
	var label := _label(glyph, "Glyph", color, 14 if more else 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_top = (-1 if more else -3) * _ui_scale
	label.offset_bottom = label.offset_top
	button.add_child(label)
	_buttons.append(button)
	_items[id] = button
	return button


func item_for(id: String) -> Control:
	return _items.get(id, _items.get("more", self))


func anchor_for(id: String) -> Vector2:
	var item := item_for(id)
	if item != self:
		return item.get_global_rect().get_center()
	# 新增或已经耗尽的状态仍在状态栏起点反馈，不飞到气血或空栏中央。
	return global_position + Vector2.ONE * 18 * _ui_scale


func _show_entry(entry: Dictionary) -> void:
	details_requested.emit("%s · %d %s" % [entry.name, entry.stacks, entry.get("unit", "层")], str(entry.description), true)


func _show_details() -> void:
	var lines: Array[String] = []
	for entry in entries:
		lines.append("【%s】%d %s\n%s" % [entry.name, entry.stacks, entry.get("unit", "层"), entry.description])
	details_requested.emit("状态与能力", "\n\n".join(lines), true)
