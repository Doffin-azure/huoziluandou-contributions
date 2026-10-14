extends HBoxContainer
class_name StatusStrip
## 原生字印图标：层数常驻，悬停或点击显示完整说明；过多时收进同一详情页。
var entries: Array = []
var _ui_scale := 1.0
var _signature := ""
var _buttons: Array[Button] = []


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
	var signature := str(entries) + str(capacity) + str(_ui_scale)
	if signature == _signature:
		return
	_signature = signature
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	var shown := mini(entries.size(), capacity if entries.size() <= capacity else maxi(0, capacity - 1))
	for index in shown:
		var entry: Dictionary = entries[index]
		var button := _badge(str(entry.glyph), cell, entry.color)
		button.tooltip_text = "%s · %d 层\n%s" % [entry.name, entry.stacks, entry.description]
		button.pressed.connect(_show_details)
		if int(entry.stacks) > 1:
			var count := Ink.label(str(entry.stacks), "", Palette.INK)
			count.add_theme_font_size_override("font_size", int(11 * _ui_scale))
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			count.position = Vector2(cell * 0.66, cell * 0.51)
			button.add_child(count)
	if entries.size() > shown:
		var more := _badge("+%d" % (entries.size() - shown), cell, Palette.INK_SOFT)
		more.tooltip_text = "查看全部状态与能力"
		more.pressed.connect(_show_details)


func _badge(glyph: String, cell: float, color: Color) -> Button:
	var button := Ink.button(glyph)
	button.custom_minimum_size = Vector2(cell, cell)
	button.add_theme_font_override("font", Ink.serif)
	button.add_theme_font_size_override("font_size", int(19 * _ui_scale))
	button.add_theme_color_override("font_color", color.darkened(0.18))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.PAPER, 0.85)
	style.border_color = Color(Palette.INK_SOFT, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(0)
	button.add_theme_stylebox_override("normal", style)
	add_child(button)
	_buttons.append(button)
	return button


func _show_details() -> void:
	var host: Node = Router.current
	if host != null and host.has_method("_mount_overlay") and (bool(host.get("_busy")) or int(host.get("_modal_count")) > 0):
		return
	var overlay := ChoiceOverlay.new()
	var lines: Array[String] = []
	for entry in entries:
		lines.append("【%s】%d 层\n%s" % [entry.name, entry.stacks, entry.description])
	overlay.setup({"title": "状态与能力", "body": "\n\n".join(lines), "scroll_body": true, "options": [{"text": "返回战斗", "primary": true}]})
	if host != null and host.has_method("_mount_overlay"):
		host._mount_overlay(overlay)
	else:
		add_child(overlay)
