extends CanvasLayer
## 全局队列，换场景不丢提示；不抢输入，不暂停战斗。
var pending: Array[String] = []
var current_id := ""
var card: PanelContainer
var remaining := 0.0

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS

func enqueue(id: String) -> void:
	if pending.has(id) or current_id == id: return
	pending.append(id)
	if card == null: _next()

func _next() -> void:
	if is_instance_valid(card): card.queue_free()
	card = null
	current_id = ""
	if pending.is_empty(): return
	current_id = pending.pop_front()
	var definition: Dictionary = Achievements.by_id.get(current_id, {})
	if definition.is_empty(): _next(); return
	card = PanelContainer.new()
	card.name = "AchievementUnlockedToast"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("123936")
	style.border_color = Color("b6ad7d")
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	row.add_child(AchievementArt.icon(definition, 60))
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 230
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	for item in [["玉符成就已解锁", 15, "afc69f"], [AchievementArt.title(definition), 23, "eadfbc"], [definition.description, 14, "c4cdb6"]]:
		var label := Label.new()
		label.text = str(item[0])
		label.add_theme_font_override("font", Ink.serif)
		label.add_theme_font_size_override("font_size", int(item[1]))
		label.add_theme_color_override("font_color", Color(item[2]))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(label)
	remaining = 4.5
	_position()

func _position() -> void:
	if card == null: return
	var bounds := get_viewport().get_visible_rect().size
	card.custom_minimum_size.x = minf(390, bounds.x - 24)
	card.reset_size()
	card.position = Vector2(bounds.x - card.size.x - 16, 16)

func _process(delta: float) -> void:
	if card == null: return
	_position()
	remaining -= delta
	if remaining <= 0: _next()
