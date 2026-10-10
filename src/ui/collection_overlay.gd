extends Control
class_name CollectionOverlay
## 通用浏览浮层：字库图鉴 / 当前字袋 / 选字。cfg 见 setup()。

signal closed
signal picked(item)

var cfg: Dictionary = {}
var _grid: GridContainer
var _tab_bar: HBoxContainer
var _mode := "chars"
var _word_grid: GridContainer
var _scroll: ScrollContainer
var _counts: Dictionary = {}


func setup(p_cfg: Dictionary) -> void:
	cfg = p_cfg


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_counts = cfg.get("counts", {})
	_build()
	_show_tab("chars")


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 60)
	frame.add_theme_constant_override("margin_right", 60)
	frame.add_theme_constant_override("margin_top", 40)
	frame.add_theme_constant_override("margin_bottom", 40)
	add_child(frame)

	var panel := Ink.panel("PanelCard")
	frame.add_child(panel)

	var pad := Ink.margin(18)
	panel.add_child(pad)
	var col := Ink.vbox(10)
	pad.add_child(col)

	var head := Ink.hbox(12)
	col.add_child(head)
	var title := Ink.h2(cfg.get("title", "字库图鉴"))
	head.add_child(title)
	if not str(cfg.get("subtitle", "")).is_empty():
		var st := Ink.label(str(cfg["subtitle"]), "Muted")
		st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(st)
	head.add_child(Ink.expander())
	var close := Ink.button("关闭")
	close.theme_type_variation = "GhostButton"
	close.custom_minimum_size = Vector2(90, 36)
	close.pressed.connect(_close)
	head.add_child(close)

	_tab_bar = Ink.hbox(8)
	col.add_child(_tab_bar)
	_add_tab("实体字", "chars")
	if not (cfg.get("words", []) as Array).is_empty():
		_add_tab("词", "words")

	col.add_child(Ink.hline())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(wrap)

	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	wrap.add_child(_grid)

	_word_grid = GridContainer.new()
	_word_grid.columns = 4
	_word_grid.add_theme_constant_override("h_separation", 10)
	_word_grid.add_theme_constant_override("v_separation", 10)
	_word_grid.visible = false
	wrap.add_child(_word_grid)

	_populate_chars()
	_populate_words()


func _add_tab(text: String, mode: String) -> void:
	var b := Ink.button(text)
	b.custom_minimum_size = Vector2(110, 36)
	b.pressed.connect(func(): _show_tab(mode))
	_tab_bar.add_child(b)


func _show_tab(mode: String) -> void:
	_mode = mode
	_grid.visible = mode == "chars"
	_word_grid.visible = mode == "words"


func _populate_chars() -> void:
	var list: Array = cfg.get("characters", [])
	if list.is_empty():
		# 默认展示全部字库（排除污染物）
		for c in Database.characters.values():
			if not c.is_pollution and not c.pending_design and not c.tags.has("enemy"):
				list.append(c)
		list.sort_custom(func(a, b): return a.rarity < b.rarity)
	for ch in list:
		var card := CharCard.new()
		card.setup(ch)
		var cnt := int(_counts.get(ch.id, 0))
		if cnt > 0:
			# 若来自字袋，把份数显示在描述里
			var wrapped: CharacterData = ch.duplicate()
			wrapped.description = "×%d  " % cnt + ch.description
			card.setup(wrapped)
		card.clicked.connect(_on_card_clicked.bind(ch))
		_grid.add_child(card)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _on_card_clicked(ch: CharacterData) -> void:
	picked.emit(ch)
	if cfg.get("pick_on_click", false):
		_close()


func _populate_words() -> void:
	var words: Array = cfg.get("words", [])
	if words.is_empty():
		words = Database.words.values()
	words.sort_custom(func(a, b): return a.id < b.id)
	for w in words:
		var holder := Ink.card()
		holder.custom_minimum_size = Vector2(268, 0)
		var inner := Ink.vbox(4)
		holder.add_child(inner)
		var top := Ink.hbox(8)
		inner.add_child(top)
		var t := Ink.label(w.glyph_string(), "Subheading", Palette.rarity_color(3 if w.priority.begins_with("P1") else 2))
		top.add_child(t)
		top.add_child(Ink.expander())
		if w.implemented:
			top.add_child(Ink.label("已实现", "Muted", Palette.JADE))
		else:
			top.add_child(Ink.label("待定", "Muted", Palette.INK_FAINT))
		var meta := Ink.label("[%s] %s%s" % [w.group, w.priority, "　P25已接入" if w.p25_implemented else ""], "Muted")
		meta.add_theme_font_size_override("font_size", 12)
		inner.add_child(meta)
		var d := Ink.caption(w.effect_summary if not w.effect_summary.is_empty() else w.description)
		d.add_theme_font_size_override("font_size", 13)
		inner.add_child(d)
		_word_grid.add_child(holder)


func _close() -> void:
	closed.emit()
	queue_free()
