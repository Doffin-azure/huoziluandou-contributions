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


func build(root: Control) -> void:
	if GameState.player_hp <= 0 or GameState.run_complete():
		goto.call_deferred("res://src/screens/run_result_screen.gd")
		return
	act = Database.get_act(GameState.act_index)
	if act == null:
		# 没有幕数据时给一个占位
		act = ActData.new()

	var main := JourneyStyle.page(root)

	main.add_child(_build_header())

	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = false
	main.add_child(_canvas)
	_canvas.resized.connect(_layout)

	_path = MapPath.new()
	_path.set_anchors_preset(Control.PRESET_FULL_RECT)
	_path.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_path)

	main.add_child(_build_footer())
	_build_nodes()
	_layout()


func _build_header() -> Control:
	var row := Ink.hbox(18)

	var hp_wrap := Ink.vbox(2)
	hp_wrap.custom_minimum_size.x = 190
	hp_wrap.add_child(Ink.label("气血", "Muted"))
	var bar := StatBar.new()
	bar.setup_bar(GameState.player_hp, GameState.player_max_hp, JourneyStyle.RED)
	hp_wrap.add_child(bar)
	row.add_child(hp_wrap)

	var gold := Ink.label("❖ %d" % GameState.gold, "Stat", JourneyStyle.GOLD)
	_gold_label = gold
	row.add_child(gold)

	var deck_btn := Ink.button("字袋 (%d)" % GameState.deck_size())
	deck_btn.custom_minimum_size = Vector2(120, 48 * JourneyStyle.touch_scale(self))
	deck_btn.pressed.connect(_open_deck)
	row.add_child(deck_btn)
	_deck_btn = deck_btn

	var menu_btn := Ink.button("菜单")
	menu_btn.custom_minimum_size = Vector2(76, 48 * JourneyStyle.touch_scale(self))
	menu_btn.theme_type_variation = "GhostButton"
	menu_btn.pressed.connect(func(): PauseMenu.open())
	row.add_child(menu_btn)

	_hp_bar = bar
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.hp_changed.connect(_on_hp_changed)
	EventBus.deck_changed.connect(_on_deck_changed)
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


func _build_footer() -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(10)
	panel.add_child(pad)
	var row := Ink.hbox(12)
	pad.add_child(row)
	var hint := Ink.label("朱砂标记为当前节点 · 沿途择字，抵达首领", "Muted")
	row.add_child(hint)
	row.add_child(Ink.expander())
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
		nv.pressed.connect(_on_node_pressed.bind(i, node))
		_canvas.add_child(nv)
		_node_views.append(nv)
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
	var margin := 90.0
	var pts: Array = []
	for i in n:
		var t: float = float(i) / float(max(1, n - 1))
		var x: float = lerpf(margin, w - margin, t)
		var y: float = h * 0.5 + sin(t * PI * 1.55 - 0.35) * (h * 0.26)
		pts.append(Vector2(x, y))
		var nv: MapNodeView = _node_views[i]
		nv.position = Vector2(x - nv.custom_minimum_size.x * 0.5, y - nv.custom_minimum_size.y * 0.5)
	_path.set_path(pts, GameState.node_index - 1)


func _on_node_pressed(index: int, node: MapNodeData) -> void:
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
			goto("res://src/screens/battle_screen.gd", {"node": node})
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
		"title": "字袋", "instances": GameState.deck,
		"subtitle": "%d 枚实体字" % GameState.deck_size(),
		"characters": chars,
		"counts": counts,
	})
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
