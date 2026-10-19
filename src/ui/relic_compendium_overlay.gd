extends Control
class_name RelicCompendiumOverlay
## 遗物图鉴浮层：浏览全部遗物的名字、档次与效果（纯展示，不影响对局状态）。
## 数据全部来自 Relics.DEFS，新增遗物自动出现在图鉴里。

signal closed

const TIER_NAMES := {1: "常见", 2: "少见", 3: "稀有"}

var _grid: GridContainer
var _scroll: ScrollContainer


func _ready() -> void:
	JourneyStyle.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_scroll.resized.connect(_layout_columns)
	_layout_columns.call_deferred()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.07, 0.09, 0.88)
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
	head.add_child(Ink.h2("遗物图鉴"))
	var st := Ink.label("共 %d 件遗物" % Relics.DEFS.size(), "Muted")
	st.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(st)
	head.add_child(Ink.expander())
	var close := Ink.button("关闭")
	close.theme_type_variation = "GhostButton"
	close.custom_minimum_size = Vector2(90, 48 * JourneyStyle.touch_scale(self))
	close.pressed.connect(_close)
	head.add_child(close)

	col.add_child(Ink.hline())

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(wrap)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	wrap.add_child(_grid)

	_populate()


func _populate() -> void:
	var ids := Relics.DEFS.keys()
	ids.sort_custom(func(a, b):
		var ta := int(Relics.TIER.get(a, 2))
		var tb := int(Relics.TIER.get(b, 2))
		return ta < tb or (ta == tb and str(a) < str(b)))
	for id in ids:
		_grid.add_child(_card(str(id)))


func _card(id: String) -> Control:
	var holder := Ink.card()
	holder.custom_minimum_size = Vector2(268, 0)
	holder.set_meta("relic_id", id)
	var inner := Ink.vbox(4)
	holder.add_child(inner)
	var top := Ink.hbox(8)
	inner.add_child(top)
	top.add_child(Ink.label(Relics.name_of(id), "Subheading", JourneyStyle.GOLD))
	top.add_child(Ink.expander())
	var tier := Ink.label(_tier_text(id), "Muted")
	tier.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(tier)
	var d := EffectText.new()
	d.add_theme_font_size_override("normal_font_size", 17)
	d.set_effect_text(Relics.desc_of(id))
	inner.add_child(d)
	if Relics.needs_bind(id) or GameState.has_relic(id):
		var tags := Ink.hbox(6)
		if Relics.needs_bind(id):
			tags.add_child(Ink.label("需绑定一枚字", "Muted"))
		if GameState.has_relic(id):
			tags.add_child(Ink.label("持有中", "Subheading", JourneyStyle.GOLD))
		inner.add_child(tags)
	return holder


func _tier_text(id: String) -> String:
	var tier := int(Relics.TIER.get(id, 2))
	return "◆".repeat(tier) + " " + str(TIER_NAMES.get(tier, "少见"))


func _layout_columns() -> void:
	if _scroll == null: return
	var width := maxf(1, _scroll.size.x - 16)
	var factor := JourneyStyle.touch_scale(self)
	_grid.columns = maxi(1, int((width + 12) / (280 * factor + 12)))
	for item in _grid.get_children(): item.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _close() -> void:
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		_close()
		get_viewport().set_input_as_handled()
