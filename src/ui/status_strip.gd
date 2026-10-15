extends HBoxContainer
class_name StatusStrip
## 图形能力符号：只常驻图形和层数，名称与说明放进悬停/点击详情。
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
		var button := _badge(str(entry.id), cell, BattleSymbol.color_for(str(entry.id), int(entry.kind) == StatusData.Kind.DEBUFF))
		button.tooltip_text = "%s · %d %s\n%s" % [entry.name, entry.stacks, entry.get("unit", "层"), entry.description]
		button.pressed.connect(_show_entry.bind(entry))
		if int(entry.stacks) > 1 or entry.get("unit", "层") != "层":
			var badge := Panel.new()
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var paper := StyleBoxFlat.new()
			paper.bg_color = Palette.PAPER
			paper.set_corner_radius_all(int(6 * _ui_scale))
			badge.add_theme_stylebox_override("panel", paper)
			badge.size = Vector2(maxf(16, str(entry.stacks).length() * 6 + 6), 16) * _ui_scale
			badge.position = Vector2(cell - badge.size.x, -1 * _ui_scale)
			button.add_child(badge)
			var count := Ink.label(str(entry.stacks), "", Palette.INK)
			count.add_theme_font_size_override("font_size", int(11 * _ui_scale))
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
	var button := Ink.button("")
	button.custom_minimum_size = Vector2(cell, cell)
	button.add_theme_font_override("font", Ink.serif)
	button.add_theme_font_size_override("font_size", int(19 * _ui_scale))
	button.add_theme_color_override("font_color", color.darkened(0.18))
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color(Palette.INK_SOFT, 0.0)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(0)
	button.add_theme_stylebox_override("normal", style)
	add_child(button)
	var icon := BattleSymbol.new()
	icon.symbol = symbol
	icon.ink = color
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = cell * 0.12
	icon.offset_top = cell * 0.12
	icon.offset_right = -cell * 0.12
	icon.offset_bottom = -cell * 0.12
	button.add_child(icon)
	_buttons.append(button)
	return button


func _show_entry(entry: Dictionary) -> void:
	var host: Node = Router.current
	if host == null or not host.has_method("_mount_overlay") or bool(host.get("_busy")) or int(host.get("_modal_count")) > 0:
		return
	var overlay := ChoiceOverlay.new()
	overlay.setup({"title": "%s · %d %s" % [entry.name, entry.stacks, entry.get("unit", "层")], "body": entry.description, "hud_details": true, "scroll_body": true, "options": [{"text": "返回战斗", "primary": true}]})
	host._mount_overlay(overlay)


func _show_details() -> void:
	var host: Node = Router.current
	if host != null and host.has_method("_mount_overlay") and (bool(host.get("_busy")) or int(host.get("_modal_count")) > 0):
		return
	var overlay := ChoiceOverlay.new()
	var lines: Array[String] = []
	for entry in entries:
		lines.append("【%s】%d %s\n%s" % [entry.name, entry.stacks, entry.get("unit", "层"), entry.description])
	overlay.setup({"title": "状态与能力", "body": "\n\n".join(lines), "hud_details": true, "scroll_body": true, "options": [{"text": "返回战斗", "primary": true}]})
	if host != null and host.has_method("_mount_overlay"):
		host._mount_overlay(overlay)
	else:
		add_child(overlay)
