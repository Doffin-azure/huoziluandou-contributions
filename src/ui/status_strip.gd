extends HBoxContainer
class_name StatusStrip
## 图形能力符号：只常驻图形和层数，名称与说明放进悬停/点击详情。
signal details_requested(title: String, body: String, scroll_body: bool)
var entries: Array = []
var _ui_scale := 1.0
var _signature := ""
var _buttons: Array[Button] = []
var _items: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 4)
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
	var capacity := maxi(1, int(size.x / (cell + 4)))
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
		var button := _badge(str(entry.id), cell, BattleSymbol.color_for(str(entry.id), int(entry.kind) == StatusData.Kind.DEBUFF))
		button.tooltip_text = "%s · %d %s\n%s" % [entry.name, entry.stacks, entry.get("unit", "层"), entry.description]
		button.pressed.connect(_show_entry.bind(entry))
		if entry.has("capacity"):
			button.get_child(0).level = clampf(float(entry.stacks) / maxf(1, entry.capacity), 0, 1)
		if int(entry.stacks) > 1 or entry.get("unit", "层") != "层":
			var badge := Panel.new()
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var paper := StyleBoxFlat.new()
			paper.bg_color = Palette.PAPER
			paper.set_corner_radius_all(int(6 * _ui_scale))
			badge.add_theme_stylebox_override("panel", paper)
			badge.size = Vector2(maxf(18, str(entry.stacks).length() * 7 + 6), 18) * _ui_scale
			badge.position = Vector2(cell - badge.size.x, -1 * _ui_scale)
			button.add_child(badge)
			var count := Ink.label(str(entry.stacks), "", Palette.INK)
			count.add_theme_font_size_override("font_size", int(13 * _ui_scale))
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			badge.add_child(count)
	if entries.size() > shown:
		var more := _badge("more", cell, Palette.INK_SOFT)
		more.tooltip_text = "查看全部状态与能力"
		more.pressed.connect(_show_details)


func _badge(symbol: String, cell: float, color: Color) -> Button:
	var illustrated := Palette.STYLE_ID == "taopunk"
	var icon_color := color
	if illustrated:
		icon_color = Color("e9debd")
		if color == Palette.VERMILION_DK: icon_color = Color("eca18d")
		elif color == Palette.GOLD_DK: icon_color = Color("dcc48e")
	var button := Ink.button("")
	button.custom_minimum_size = Vector2(cell, cell)
	button.add_theme_font_override("font", Ink.serif)
	button.add_theme_font_size_override("font_size", int(19 * _ui_scale))
	button.add_theme_color_override("font_color", icon_color)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("122b2d") if illustrated else Color.TRANSPARENT
	style.border_color = Color("7b795c") if illustrated else Color.TRANSPARENT
	if illustrated: style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(0)
	button.add_theme_stylebox_override("normal", style)
	if illustrated:
		var hover: StyleBoxFlat = style.duplicate()
		hover.bg_color = Color("274143")
		hover.border_color = Color("cbb987")
		button.add_theme_stylebox_override("hover", hover)
		var pressed: StyleBoxFlat = style.duplicate()
		pressed.bg_color = Color("0b1e20")
		button.add_theme_stylebox_override("pressed", pressed)
		var focus: StyleBoxFlat = style.duplicate()
		focus.bg_color = Color.TRANSPARENT
		focus.border_color = Color("e9debd")
		focus.set_border_width_all(2)
		button.add_theme_stylebox_override("focus", focus)
		button.add_theme_stylebox_override("disabled", style)
	add_child(button)
	var icon := BattleSymbol.new()
	icon.symbol = symbol
	icon.ink = icon_color
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = cell * 0.12
	icon.offset_top = cell * 0.12
	icon.offset_right = -cell * 0.12
	icon.offset_bottom = -cell * 0.12
	button.add_child(icon)
	_buttons.append(button)
	_items[symbol] = button
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
