extends ScreenBase
## 独立的青铜字谱页；主题和背景只作用于此屏幕。

const PAPER := Color("efdfbb")
const MUTED := Color("a6b6aa")
const GOLD := Color("c2a366")
const BORDER := Color("536155")

var _view: GlyphGraphView
var _detail: VBoxContainer
var _stats: Label
var _zoom_label: Label
var _search: LineEdit
var _hint: Label
var _focus_button: Button
var _side: PanelContainer
var _scope := "all"
var _scope_buttons: Dictionary = {}
var _words: Array = []
var _word_cards: Array = []
var _built := false


func has_scene_background() -> bool:
	return true


func build(root: Control) -> void:
	theme = _graph_theme()
	var background := TextureRect.new()
	background.texture = load("res://assets/glyph_graph/ritual_courtyard.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.075, 0.08, 0.90)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var frame := Ink.margin(22)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(frame)
	var main := Ink.vbox(12)
	frame.add_child(main)
	main.add_child(_build_header())
	main.add_child(_build_filters())
	var body := Ink.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel(Color(0.035, 0.10, 0.11, 0.94), 0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(card)
	var graph := Ink.vbox(0)
	card.add_child(graph)
	var bar_pad := Ink.margin(12)
	graph.add_child(bar_pad)
	var bar := Ink.hbox(8)
	bar_pad.add_child(bar)
	_stats = _caption("")
	bar.add_child(_stats)
	bar.add_child(Ink.expander())
	bar.add_child(_button("−", func(): _view.zoom_at(1.0 / 1.2, _view.size * 0.5)))
	_zoom_label = _caption("100%")
	_zoom_label.custom_minimum_size.x = 48
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_zoom_label)
	bar.add_child(_button("＋", func(): _view.zoom_at(1.2, _view.size * 0.5)))
	bar.add_child(_button("总览", func(): _view.show_overview()))
	_view = GlyphGraphView.new()
	_view.custom_minimum_size = Vector2(180, 180)
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.node_selected.connect(_on_node_selected)
	_view.view_changed.connect(func(): _zoom_label.text = "%d%%" % roundi(_view.zoom * 100.0))
	graph.add_child(_view)
	_side = _build_side()
	body.add_child(_side)
	var foot := HFlowContainer.new()
	foot.add_theme_constant_override("h_separation", 20)
	main.add_child(foot)
	foot.add_child(_caption("滚轮缩放 · 拖动空白平移 · 拖动字块整理 · 点击字块查词"))
	foot.add_child(_caption("箭头表示组词顺序，例如：火 → 力 = 火力"))
	_built = true
	resized.connect(_layout)
	_layout()
	_refresh()


func _graph_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Ink.sans
	t.default_font_size = 17
	t.set_font("font", "Button", Ink.serif)
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color("ffe8b6"))
	t.set_color("font_pressed_color", "Button", Color("fff0c9"))
	t.set_color("font_disabled_color", "Button", Color("65786e"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := _panel(Color("254644") if state == "pressed" else Color("122e30"), 10)
		sb.border_color = GOLD if state in ["hover", "pressed", "focus"] else BORDER
		t.set_stylebox(state, "Button", sb)
	for entry in [["Heading", 25, PAPER], ["Muted", 14, MUTED], ["Stat", 22, GOLD], ["Title", 34, PAPER]]:
		t.set_type_variation(entry[0], "Label")
		t.set_font_size("font_size", entry[0], entry[1])
		t.set_font("font", entry[0], Ink.serif)
		t.set_color("font_color", entry[0], entry[2])
	t.set_font("normal_font", "RichTextLabel", Ink.sans)
	t.set_color("default_color", "RichTextLabel", PAPER)
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_stylebox("normal", "LineEdit", _panel(Color("0f282a"), 12))
	var focus := _panel(Color("173536"), 12)
	focus.border_color = GOLD
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_stylebox("scroll", "VScrollBar", _panel(Color("102a2c"), 3))
	t.set_stylebox("grabber", "VScrollBar", _panel(Color("68745e"), 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", _panel(GOLD, 3))
	return t


func _panel(color: Color, padding: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(padding)
	return sb


func _button(text: String, callback: Callable) -> Button:
	var b := Ink.button(text)
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size.y = 32
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(callback)
	return b


func _caption(text: String) -> Label:
	var label := Ink.caption(text)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _effect(text: String, word: WordData = null) -> EffectText:
	var label := EffectText.new()
	label.set_effect_text(text, 0, word)
	# 只替换本页生成的 BBCode 颜色；词条目标和全局浅色浮层保持原有协议。
	label.text = label.text.replace("[color=#%s]" % Palette.INDIGO.to_html(false), "[color=#a8cec2]")
	label.text = label.text.replace("[color=#%s]" % Palette.VERMILION_DK.to_html(false), "[color=#edac85]")
	return label


func _build_header() -> Control:
	var row := Ink.hbox(14)
	var seal := Ink.label("谱", "Title", GOLD)
	seal.custom_minimum_size = Vector2(46, 46)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(seal)
	var title := Ink.vbox(1)
	row.add_child(title)
	title.add_child(Ink.h2("字网图谱"))
	title.add_child(_caption("循字寻词 · 万字相连"))
	row.add_child(Ink.expander())
	row.add_child(_button("返回标题", func(): goto("res://src/screens/title_screen.gd")))
	return row


func _build_filters() -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var total := Database.words.size()
	var implemented := Database.words.values().filter(func(w): return w.implemented).size()
	var starter := _starter_glyphs()
	for entry in [["全部 %d 词" % total, "all"], ["已实现 %d 词" % implemented, "implemented"],
		["初始 %d 字" % starter.size(), "starter"]]:
		var scope: String = entry[1]
		var b := _button(entry[0], func(): _set_scope(scope))
		b.toggle_mode = true
		_scope_buttons[scope] = b
		flow.add_child(b)
	_focus_button = _button("只看相关", func(): pass)
	_focus_button.toggle_mode = true
	_focus_button.tooltip_text = "选中字后，只显示它与直接相连的字；再次点击恢复全图。"
	_focus_button.toggled.connect(func(enabled: bool): _view.set_focus_only(enabled))
	flow.add_child(_focus_button)
	_search = LineEdit.new()
	_search.placeholder_text = "输入字或词，回车定位"
	_search.custom_minimum_size = Vector2(220, 36)
	_search.clear_button_enabled = true
	_search.text_submitted.connect(_find)
	flow.add_child(_search)
	flow.add_child(_button("寻字", func(): _find(_search.text)))
	_hint = _caption("")
	flow.add_child(_hint)
	return flow


func _build_side() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel(Color(0.055, 0.13, 0.14, 0.97), 16))
	var col := Ink.vbox(12)
	panel.add_child(col)
	col.add_child(Ink.label("字 录", "Heading", GOLD))
	col.add_child(Ink.hline(Color("536155")))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_detail = Ink.vbox(12)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail)
	return panel


func _layout() -> void:
	if _side != null:
		_side.custom_minimum_size.x = clampf(size.x * 0.26, 250, 340)


func _starter_glyphs() -> Array:
	var glyphs: Array = []
	var starter: StarterDeckData = Database.starter_decks.get("v03")
	if starter != null:
		for entry in starter.entries:
			if entry.character != null and not glyphs.has(entry.character.glyph):
				glyphs.append(entry.character.glyph)
	return glyphs


func _set_scope(scope: String) -> void:
	_scope = scope
	if _built:
		_refresh()


func _refresh() -> void:
	var previous := _view.selected
	_words = Database.words.values()
	if _scope == "implemented":
		_words = _words.filter(func(w): return w.implemented)
	elif _scope == "starter":
		var starter := _starter_glyphs()
		_words = _words.filter(func(w): return w.glyphs.all(func(g): return starter.has(g)))
	_words.sort_custom(func(a, b): return a.word < b.word)
	for key in _scope_buttons:
		_scope_buttons[key].set_pressed_no_signal(key == _scope)
	_view.rebuild(_words)
	_stats.text = "%d 字  /  %d 词  /  %d 条关系" % [_view.nodes.size(), _words.size(), _view.edges.size()]
	_hint.text = ""
	if _view._index.has(previous):
		_view.select(previous)
	else:
		_show_idle()


func _clear_detail() -> void:
	_word_cards.clear()
	for c in _detail.get_children():
		# 立即移出布局，避免同一帧内连续选择撑大详情栏。
		_detail.remove_child(c)
		c.queue_free()
	var scroll := _detail.get_parent() as ScrollContainer
	scroll.scroll_vertical = 0


func _show_idle() -> void:
	_clear_detail()
	var intro := Ink.body("点选一枚字，查看它能连成的词与单字效果。")
	_detail.add_child(intro)
	_detail.add_child(Ink.caption("图中每一块都是字，连线保留词中的先后顺序。"))
	_detail.add_child(Ink.spacer(8))
	_detail.add_child(Ink.label("从这些字开始", "Subheading", GOLD))
	var popular := _view.nodes.duplicate()
	popular.sort_custom(func(a, b): return a.words > b.words if a.words != b.words else a.glyph < b.glyph)
	for nd in popular.slice(0, 5):
		var glyph: String = nd.glyph
		_detail.add_child(_button("%s    可组 %d 词" % [glyph, nd.words], func(): _view.select(glyph)))
	_detail.add_child(Ink.spacer(12))
	_detail.add_child(Ink.caption("选中字后，其直接相连的字与连线会亮起；开启「只看相关」可收起其余字。"))


func _on_node_selected(info: Dictionary) -> void:
	if info.is_empty():
		_show_idle()
		return
	_clear_detail()
	var glyph: String = info.glyph
	var row := Ink.hbox(12)
	_detail.add_child(row)
	var letter := Ink.label(glyph, "Title", info.color)
	letter.add_theme_font_size_override("font_size", 48)
	letter.custom_minimum_size.x = 58
	row.add_child(letter)
	var meta := Ink.vbox(4)
	row.add_child(meta)
	meta.add_child(Ink.label("可组 %d 词" % info.words, "Stat"))
	meta.add_child(_caption("前接 %d 字 · 后接 %d 字" % [info["in"], info.out]))
	var cd := Database.get_character_by_glyph(glyph)
	if cd != null:
		_detail.add_child(Ink.caption("单字效果"))
		var solo := _effect(cd.description)
		_detail.add_child(solo)
	_detail.add_child(Ink.hline(Color("536155")))
	_detail.add_child(Ink.label("相关词语", "Subheading", GOLD))
	for word in _words:
		if not word.glyphs.has(glyph):
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel(Color("122e30"), 10))
		_detail.add_child(panel)
		var col := Ink.vbox(5)
		panel.add_child(col)
		var name_row := Ink.hbox(6)
		col.add_child(name_row)
		var effect := _effect(EffectGlossary.brief(word) if word.implemented else "效果尚未实现。", word)
		var title := _button(word.word, func(): effect.open_entry("word:" + word.word))
		title.add_theme_color_override("font_color", GOLD)
		name_row.add_child(title)
		col.add_child(effect)
		_word_cards.append({"word": word, "effect": effect})
	_detail.add_child(Ink.hline(Color("536155")))
	_add_neighbors("后面可以接", info.out_list)
	_add_neighbors("前面可以接", info.in_list)


func _add_neighbors(title: String, glyphs: Array) -> void:
	if glyphs.is_empty():
		return
	_detail.add_child(Ink.caption(title))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	_detail.add_child(flow)
	for g in glyphs:
		var glyph := str(g)
		flow.add_child(_button(glyph, func(): _view.select(glyph)))


func _find(query: String) -> void:
	query = query.strip_edges()
	if query.is_empty():
		return
	if _view._index.has(query):
		_view.select(query, true)
		_hint.text = "已定位「%s」" % query
		return
	for word in _words:
		if word.word == query:
			_view.select(str(word.glyphs[0]), true)
			for card in _word_cards:
				if card.word == word:
					card.effect.open_entry("word:" + word.word)
			_hint.text = "已找到「%s」" % query
			return
	_hint.text = "当前范围没有「%s」" % query
