extends ScreenBase
## 字网图谱界面：力导向布局 + 出度/入度详情。

var _view: GlyphGraphView
var _detail: VBoxContainer
var _stats: Label
var _scope := "all"
var _built := false
var _scope_buttons: Array[Button] = []


func build(root: Control) -> void:
	var main := JourneyStyle.page(root)
	main.add_child(_build_header())

	var body := Ink.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)

	var graph_card := Ink.panel("PanelCard")
	graph_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(graph_card)
	_view = GlyphGraphView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.clip_contents = true
	_view.node_selected.connect(_on_node_selected)
	graph_card.add_child(_view)
	_view.resized.connect(_on_view_resized)

	body.add_child(_build_side())
	_built = false


func _build_header() -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(8)
	panel.add_child(pad)
	var row := Ink.hbox(10)
	pad.add_child(row)
	row.add_child(Ink.h2("字网图谱"))

	row.add_child(Ink.spacer(10, false))
	_add_scope_btn(row, "全部字", "all")
	_add_scope_btn(row, "可用字", "implemented")
	_add_scope_btn(row, "初始字", "starter")
	row.add_child(Ink.expander())
	_stats = Ink.label("", "Muted")
	_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_stats)
	var back := Ink.button("返回标题")
	back.theme_type_variation = "GhostButton"
	back.custom_minimum_size = Vector2(110, 48 * JourneyStyle.touch_scale(self))
	back.pressed.connect(func(): goto("res://src/screens/title_screen.gd"))
	row.add_child(back)
	return panel


func _add_scope_btn(row: Control, text: String, scope: String) -> void:
	var b := Ink.button(text)
	b.set_meta("scope", scope)
	b.theme_type_variation = "PrimaryButton" if _scope == scope else "GhostButton"
	_scope_buttons.append(b)
	b.custom_minimum_size = Vector2(104, 48 * JourneyStyle.touch_scale(self))
	b.add_theme_font_size_override("font_size", int(15 * JourneyStyle.touch_scale(self)))
	b.pressed.connect(func(): _set_scope(scope))
	row.add_child(b)


func _build_side() -> Control:
	var panel := Ink.panel("PanelCard")
	panel.custom_minimum_size = Vector2(288, 0)
	var pad := Ink.margin(14)
	panel.add_child(pad)
	var col := Ink.vbox(10)
	pad.add_child(col)

	col.add_child(Ink.h2("度数详情"))
	col.add_child(Ink.hline())
	_detail = Ink.vbox(8)
	col.add_child(_detail)
	col.add_child(Ink.expander())
	col.add_child(Ink.hline())
	col.add_child(Ink.label("节点大小 = 总度（出+入）", "Muted"))
	col.add_child(Ink.label("颜色 = 所属体系", "Muted"))
	col.add_child(_legend())
	return panel


func _legend() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	var items := [
		["攻击", Color("944a3e")], ["防御", Color("43666b")],
		["流转", Color("577779")], ["储能", JourneyStyle.GOLD],
		["热度", JourneyStyle.RED], ["经济", Color("5b7c70")],
		["空间", Color("80734f")], ["敌方", JourneyStyle.EDGE],
	]
	for it in items:
		var row := Ink.hbox(5)
		var dot := ColorRect.new()
		dot.color = it[1]
		dot.custom_minimum_size = Vector2(12, 12)
		row.add_child(dot)
		row.add_child(Ink.label(it[0], "Muted"))
		grid.add_child(row)
	return grid


func _on_view_resized() -> void:
	if _view.size.x < 100.0:
		return
	if not _built:
		_built = true
		_refresh()
	else:
		_view._fit_to_canvas()
		_view.queue_redraw()


func _set_scope(scope: String) -> void:
	_scope = scope
	for button in _scope_buttons:
		button.theme_type_variation = "PrimaryButton" if button.get_meta("scope") == scope else "GhostButton"
	if _built:
		_refresh()


func _refresh() -> void:
	var words: Array = Database.words.values()
	var only: Array = []
	match _scope:
		"implemented":
			words = words.filter(func(w): return w.implemented)
		"starter":
			only = ["击", "防", "回", "反", "破", "重", "流", "连", "御"]
	_view.rebuild(words, only)
	_stats.text = "参与字 %d　·　有向边 %d" % [_view.nodes.size(), _view.edges.size()]
	for c in _detail.get_children():
		c.queue_free()
	_detail.add_child(Ink.label("点击左侧节点查看该字的出度/入度。", "Muted"))


func _on_node_selected(info: Dictionary) -> void:
	if info.is_empty():
		return
	for c in _detail.get_children():
		c.queue_free()
	var head := Ink.hbox(10)
	_detail.add_child(head)
	var seal := SealView.new()
	seal.custom_minimum_size = Vector2(56, 56)
	seal.setup(info["glyph"], info["color"], SealView.Shape.SQUARE, Palette.PAPER)
	head.add_child(seal)
	var hc := Ink.vbox(2)
	hc.add_child(Ink.label("【%s】" % info["glyph"], "Heading"))
	hc.add_child(Ink.label("出现于 %d 个词" % info["words"], "Muted"))
	head.add_child(hc)

	_detail.add_child(Ink.hline())
	_detail.add_child(_kv("出度（不同后续字）", str(info["out"])))
	_detail.add_child(_kv("入度（不同前置字）", str(info["in"])))
	_detail.add_child(_kv("总度", str(int(info["out"]) + int(info["in"]))))
	_detail.add_child(_kv("加权出 / 入", "%d / %d" % [info["wout"], info["win"]]))
	_detail.add_child(Ink.hline())
	_detail.add_child(_list_block("后续字（出）", info["out_list"]))
	_detail.add_child(_list_block("前置字（入）", info["in_list"]))


func _kv(k: String, v: String) -> Control:
	var row := Ink.hbox(6)
	row.add_child(Ink.label(k, "Muted"))
	row.add_child(Ink.expander())
	row.add_child(Ink.label(v, "Stat"))
	return row


func _list_block(title: String, items: Array) -> Control:
	var col := Ink.vbox(2)
	col.add_child(Ink.label(title, "Muted"))
	var text := "—" if items.is_empty() else "、".join(items)
	var l := Ink.body(text)
	l.add_theme_font_size_override("font_size", 15)
	col.add_child(l)
	return col
