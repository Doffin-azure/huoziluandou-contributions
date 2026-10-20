extends ScreenBase
## 幕地图：一条墨色手卷，节点为朱印。

var act: ActData
var _canvas: Control
var _path: MapPath
var _node_views: Array = []
var _header_status: HBoxContainer
var _gold_label: Label
var _hp_bar: StatBar
var _deck_btn: Button
var _mobile := false
var _route_scroll: ScrollContainer


func build(root: Control) -> void:
	act = Database.get_act(GameState.act_index)
	if act == null:
		# 没有幕数据时给一个占位
		act = ActData.new()

	_mobile = get_viewport_rect().size.x / JourneyStyle.touch_scale(self) < 1100
	var main := JourneyStyle.page(root)

	main.add_child(_build_header())

	var route_scroll := ScrollContainer.new()
	_route_scroll = route_scroll
	route_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(route_scroll)
	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = false
	route_scroll.add_child(_canvas)
	_canvas.resized.connect(_layout)

	_path = MapPath.new()
	_path.set_anchors_preset(Control.PRESET_FULL_RECT)
	_path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_path)

	if not _mobile: main.add_child(_build_footer())
	_build_nodes()
	_layout()


func _build_header() -> Control:
	var unit := JourneyStyle.touch_scale(self)
	# 顶部状态行必须保持一行；HFlow 在桌面窄宽度下会把气血、金币、字袋、菜单
	# 逐项换行，标题面板因此被撑成大块空白。
	var row: Container = Ink.hbox(int(10 * unit))
	if not _mobile:
		row.add_theme_constant_override("separation", 16)

	var hp_wrap := Ink.vbox(2)
	hp_wrap.custom_minimum_size.x = 90 * unit if _mobile else 190
	if not _mobile: hp_wrap.add_child(Ink.label("气血", "Muted"))
	var bar := StatBar.new()
	bar.setup_bar(GameState.player_hp, GameState.player_max_hp, JourneyStyle.RED)
	hp_wrap.add_child(bar)
	row.add_child(hp_wrap)

	var gold := Ink.label("❖ %d" % GameState.gold, "Stat", JourneyStyle.GOLD)
	if _mobile: gold.add_theme_font_size_override("font_size", int(16 * unit))
	_gold_label = gold
	row.add_child(gold)

	var deck_btn := Ink.button("字袋 (%d)" % GameState.deck_size())
	deck_btn.custom_minimum_size = Vector2(90 if _mobile else 120, 48) * unit
	deck_btn.pressed.connect(_open_deck)
	row.add_child(deck_btn)
	_deck_btn = deck_btn

	var menu_btn := Ink.button("菜单")
	menu_btn.custom_minimum_size = Vector2(56 if _mobile else 76, 48) * unit
	menu_btn.theme_type_variation = "GhostButton"
	menu_btn.pressed.connect(func(): PauseMenu.open())
	row.add_child(menu_btn)

	_hp_bar = bar
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.hp_changed.connect(_on_hp_changed)
	EventBus.deck_changed.connect(_on_deck_changed)
	if _mobile:
		var header := Ink.panel("PanelInset")
		header.add_theme_stylebox_override("panel", JourneyStyle.frame("inset", 8))
		var compact := Ink.hbox(int(8 * unit))
		header.add_child(compact)
		var titles := Ink.vbox(0)
		titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Ink.label(act.title, "Heading")
		title.add_theme_font_size_override("font_size", int(20 * unit))
		title.clip_text = true
		titles.add_child(title)
		var hint_text := "沿朱印前行 · 首战含基础引导" if GameState.first_run_tutorial else "沿朱印前行 · 点此查看路线说明"
		var hint := Ink.label(hint_text, "Muted")
		hint.add_theme_font_size_override("font_size", int(12 * unit))
		hint.clip_text = true
		titles.add_child(hint)
		titles.custom_minimum_size.y = 48 * unit
		titles.mouse_filter = Control.MOUSE_FILTER_STOP
		titles.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		titles.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_route_guide()
				titles.accept_event())
		compact.add_child(titles)
		compact.add_child(row)
		return header
	return JourneyStyle.heading(act.title, act.theme, row)


func _exit_tree() -> void:
	if EventBus.gold_changed.is_connected(_on_gold_changed):
		EventBus.gold_changed.disconnect(_on_gold_changed)
	if EventBus.hp_changed.is_connected(_on_hp_changed):
		EventBus.hp_changed.disconnect(_on_hp_changed)
	if EventBus.deck_changed.is_connected(_on_deck_changed):
		EventBus.deck_changed.disconnect(_on_deck_changed)


func _on_gold_changed(v: int) -> void:
	if is_instance_valid(_gold_label):
		_gold_label.text = "❖ %d" % v


func _on_hp_changed(hp: int, mx: int) -> void:
	if is_instance_valid(_hp_bar):
		_hp_bar.setup_bar(hp, mx, JourneyStyle.RED)


func _on_deck_changed() -> void:
	if is_instance_valid(_deck_btn):
		_deck_btn.text = "字袋 (%d)" % GameState.deck_size()


func _open_route_guide() -> void:
	var overlay := ChoiceOverlay.new()
	overlay.setup({"scroll_body": true, "hud_details": true, "title": act.title, "body": act.theme + "\n\n朱砂标记为当前节点。沿途择字，抵达首领；横向拖动可查看后续路线。", "options": [{"text": "返回路线", "primary": true}]})
	add_child(overlay)


func _build_footer() -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(10)
	panel.add_child(pad)
	var row := Ink.hbox(12)
	pad.add_child(row)
	var hint_text := "首战会边打边教基础操作 · 朱砂标记为当前节点" if GameState.first_run_tutorial else "朱砂标记为当前节点 · 沿途择字，抵达首领"
	var hint := Ink.label(hint_text, "Muted")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hint)
	var home := Ink.button("返回标题")
	home.theme_type_variation = "GhostButton"
	home.custom_minimum_size = Vector2(110, 48 * JourneyStyle.touch_scale(self))
	home.pressed.connect(func(): goto("res://src/screens/title_screen.gd"))
	row.add_child(home)
	return panel


func _build_nodes() -> void:
	for nv in _node_views:
		nv.queue_free()
	_node_views.clear()
	var nodes: Array = act.nodes
	for i in nodes.size():
		var node: MapNodeData = nodes[i]
		var nv := MapNodeView.new()
		nv.setup(node)
		if _mobile: nv.set_mobile_unit(JourneyStyle.touch_scale(self))
		nv.pressed.connect(_on_node_pressed.bind(i, node))
		_canvas.add_child(nv)
		_node_views.append(nv)
	_canvas.custom_minimum_size.x = maxf(0, _node_views.size() - 1) * (72 if _mobile else 112) * JourneyStyle.touch_scale(self) + (80 * JourneyStyle.touch_scale(self) if _mobile else 180)
	_refresh_states()


func _refresh_states() -> void:
	var nodes: Array = act.nodes
	for i in nodes.size():
		var nv: MapNodeView = _node_views[i]
		var order: int = nodes[i].order
		if order < GameState.node_index:
			nv.state = MapNodeView.State.COMPLETED
		elif order == GameState.node_index:
			nv.state = MapNodeView.State.AVAILABLE
		else:
			nv.state = MapNodeView.State.LOCKED
		nv.queue_redraw()


func _layout() -> void:
	if _canvas == null:
		return
	var w := _canvas.size.x
	var h := _canvas.size.y
	if w < 10 or h < 10:
		return
	var n: int = max(1, _node_views.size())
	var margin := 40 * JourneyStyle.touch_scale(self) if _mobile else 90.0
	var pts: Array = []
	for i in n:
		var t: float = float(i) / float(max(1, n - 1))
		var x: float = lerpf(margin, w - margin, t)
		var y: float = h * 0.5 + sin(t * PI * 1.55 - 0.35) * (h * 0.26)
		pts.append(Vector2(x, y))
		var nv: MapNodeView = _node_views[i]
		nv.position = Vector2(x - nv.custom_minimum_size.x * 0.5, y - nv.custom_minimum_size.y * 0.5)
	_path.set_path(pts, GameState.node_index - 1)
	if _mobile and _node_views.size() > 0:
		var current: Control = _node_views[clampi(GameState.node_index - 1, 0, _node_views.size() - 1)]
		_route_scroll.scroll_horizontal = int(maxf(0, current.position.x + current.size.x * 0.5 - _route_scroll.size.x * 0.5))


func _on_node_pressed(index: int, node: MapNodeData) -> void:
	if _mobile or node.order != GameState.node_index:
		var available := node.order == GameState.node_index
		var overlay := ChoiceOverlay.new()
		var body := node.description
		var enemies := node.select_enemies(GameState.battle_sequence * 997 + GameState.node_index)
		if not enemies.is_empty():
			body += "\n\n遭遇：" + "、".join(enemies.map(func(enemy): return "%s（气血 %d）" % [enemy.name, enemy.max_hp]))
		if not available: body += "\n\n" + ("此节点已完成。" if node.order < GameState.node_index else "尚未到达，需沿路线前进。")
		overlay.setup({"title": "%s · %s" % [node.type_label(), node.title], "body": body, "hud_details": true, "scroll_body": true, "dismissible": true, "cancel_index": 1 if available else 0, "options": [{"text": "进入节点", "primary": true}, {"text": "返回路线"}] if available else [{"text": "返回路线", "primary": true}]})
		overlay.chose.connect(func(choice):
			if available and choice == 0: _enter_node(index, node))
		add_child(overlay)
		return
	_enter_node(index, node)


func _enter_node(_index: int, node: MapNodeData) -> void:
	match node.type:
		MapNodeData.Type.SHOP:
			goto("res://src/screens/shop_screen.gd", {"node": node})
		MapNodeData.Type.REST:
			goto("res://src/screens/rest_screen.gd", {"node": node})
		MapNodeData.Type.EVENT:
			goto("res://src/screens/event_screen.gd", {"node": node})
		MapNodeData.Type.FORK:
			_show_fork(node)
		MapNodeData.Type.BATTLE, MapNodeData.Type.ELITE, MapNodeData.Type.BOSS:
			goto("res://src/screens/battle_screen.gd", {"node": node, "first_run_tutorial": GameState.first_run_tutorial})
		_:
			pass


func _show_fork(node: MapNodeData) -> void:
	var overlay := ChoiceOverlay.new()
	overlay.setup({
		"title": "岔路",
		"body": "眼前分出两条路：一条血气森森，一条静默无声。",
		"options": [
			{"text": "挑战精英（高收益）", "primary": true},
			{"text": "寻访事件（较安全）"},
			{"text": "再想想"},
		],
	})
	overlay.chose.connect(_on_fork_choice.bind(node))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_fork_choice(index: int, node: MapNodeData) -> void:
	if index == 0:
		goto("res://src/screens/battle_screen.gd", {"node": node, "elite": true})
	elif index == 1:
		goto("res://src/screens/event_screen.gd", {"node": node})


func _open_deck() -> void:
	var counts := GameState.glyph_counts()
	var chars: Array = []
	for id in counts.keys():
		var cd: CharacterData = Database.get_character_by_glyph(id)
		if cd != null:
			chars.append(cd)
	var overlay := CollectionOverlay.new()
	overlay.setup({
		"title": "字袋",
		"subtitle": "%d 枚实体字" % GameState.deck_size(),
		"characters": chars,
		"counts": counts,
	})
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
