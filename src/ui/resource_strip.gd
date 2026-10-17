extends HBoxContainer
class_name ResourceStrip
## 资源只常驻符号和数值；说明通过悬停/点击访问。
signal details_requested(title: String, body: String, scroll_body: bool)
signal activated(id: String)
var entries: Array = []
var _items: Dictionary = {}
var _scale := 1.0
var _dense := false
var _signature := ""


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	_rebuild()


func set_entries(value: Array) -> void:
	entries = value
	_rebuild()


func set_ui_scale(value: float, dense := false) -> void:
	_scale = value
	_dense = dense
	_rebuild()


func item_for(id: String) -> Control:
	return _items.get(id, self)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	var signature := str(entries) + str(_scale) + str(_dense)
	if signature == _signature:
		return
	_signature = signature
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_items.clear()
	add_theme_constant_override("separation", int((8 if _dense else 16) * _scale))
	for entry in entries:
		var button := Ink.button("")
		button.name = str(entry.id)
		button.custom_minimum_size.y = (24 if _dense else 48) * _scale
		button.tooltip_text = str(entry.title) + "\n" + str(entry.description)
		var normal := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", normal)
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(Palette.INK, 0.05)
		hover.set_corner_radius_all(3)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		add_child(button)
		_items[entry.id] = button
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", int(6 * _scale))
		button.add_child(row)
		var icon := BattleSymbol.new()
		icon.symbol = str(entry.id)
		icon.ink = BattleSymbol.color_for(str(entry.id))
		icon.custom_minimum_size = Vector2.ONE * (20 if _dense else 28) * _scale
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if entry.id == "heat":
			icon.level = float(entry.value) / maxf(1, float(entry.capacity))
		row.add_child(icon)
		var value := Ink.label(str(entry.value) + (" / %d" % entry.capacity if entry.has("capacity") else ""), "", Palette.INK)
		value.add_theme_font_size_override("font_size", int((15 if _dense else 22) * _scale))
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(value)
		button.custom_minimum_size.x = row.get_combined_minimum_size().x + 8 * _scale
		if entry.get("action", false):
			button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, 48 * _scale)
		button.resized.connect(func():
			row.position = (button.size - row.get_combined_minimum_size()) * 0.5
			row.size = row.get_combined_minimum_size())
		button.pressed.connect(_show_entry.bind(entry))


func _show_entry(entry: Dictionary) -> void:
	if entry.get("action", false):
		activated.emit(str(entry.id))
		return
	details_requested.emit(str(entry.title), str(entry.description), true)
