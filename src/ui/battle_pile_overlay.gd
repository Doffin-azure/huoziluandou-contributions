extends Control
class_name BattlePileOverlay
## 只读的战斗牌堆快照。按字形和可见状态归类，完全不读取或展示抽取顺序。

var title := ""
var groups: Array[Dictionary] = []
var total := 0
var _canvas: Control
var _scroll: ScrollContainer
var _grid: GridContainer
var _close_button: Button


func setup(p_title: String, instances: Array) -> void:
	title = p_title
	groups.clear()
	total = 0
	var grouped: Dictionary = {}
	for inst: CharInstance in instances:
		if inst == null or inst.data == null:
			continue
		var display: CharacterData = inst.data.duplicate()
		display.glyph = "·".join(inst.glyph_list())
		var notes: Array[String] = []
		for pid in inst.pollutions:
			var pollution: PollutionData = Database.get_pollution(pid)
			notes.append("污染：" + (pollution.name if pollution != null else pid))
		if inst.gilded: notes.append("镀金")
		if inst.is_fused(): notes.append("融合字")
		if inst.temporary: notes.append("临时字")
		if inst.upgrade_level > 0: notes.append("强化 +%d" % inst.upgrade_level)
		for modifier in inst.modifiers: notes.append(modifier)
		notes.sort()
		if not notes.is_empty(): display.description += "\n" + " · ".join(notes)
		# 不含 uid / 牌堆位置；相同字的不同污染、融合等状态独立展示。
		var key := display.glyph + "|" + display.id + "|" + display.description
		if not grouped.has(key): grouped[key] = {"character": display, "count": 0}
		grouped[key].count += 1
		total += 1
	var keys: Array = grouped.keys()
	keys.sort()
	for key in keys: groups.append(grouped[key])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.05, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close())
	add_child(dim)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	var margin := Ink.margin(16)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(margin)
	var panel := Ink.panel("PanelCard")
	margin.add_child(panel)
	var pad := Ink.margin(16)
	panel.add_child(pad)
	var column := Ink.vbox(10)
	pad.add_child(column)
	var head := Ink.hbox(12)
	column.add_child(head)
	head.add_child(Ink.h2(title))
	head.add_child(Ink.expander())
	_close_button = Ink.button("返回战斗")
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.add_theme_color_override("font_focus_color", Palette.INK)
	_close_button.custom_minimum_size = Vector2(112, 48)
	_close_button.pressed.connect(close)
	head.add_child(_close_button)
	column.add_child(Ink.label("共 %d 枚 · 同类合并展示 · 不代表抽取顺序" % total, "Muted"))
	column.add_child(Ink.hline())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_scroll.add_child(_grid)
	if groups.is_empty():
		_grid.add_child(Ink.label("%s中暂无字。" % title, "Muted"))
	for group in groups:
		var display: CharacterData = group.character.duplicate()
		display.description = "×%d  " % group.count + display.description
		var card := CharCard.new()
		card.setup(display, true)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(card)
		card.custom_minimum_size.x = 256
	_scroll.resized.connect(_layout_grid)
	resized.connect(_layout)
	_layout()
	_close_button.grab_focus()


func _layout() -> void:
	var unit := BattleTouchLayout.unit_for(size, get_window().size)
	_canvas.scale = Vector2.ONE * unit
	_canvas.size = size / unit
	_layout_grid()


func _layout_grid() -> void:
	_grid.columns = maxi(1, int((_scroll.size.x - 14 + 12) / (256 + 12)))


func close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		get_viewport().set_input_as_handled()
		close()
