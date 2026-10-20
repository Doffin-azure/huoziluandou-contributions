extends ScreenBase
## 墨途远征地图（v0.3）：左边迷雾地图 + 日志，中间构筑说明 / 字匣，右边事件面板。
## 状态全在 GameState.expedition（Expedition），本界面只负责显示与转发操作。

const MAP_CELL := 40
const NODE_COLOR := {"起": "23434a", "大": "a24a37", "中": "90703e", "小": "77613e", "休": "315b59", "市": "81693d", "谜": "3e5960",
	"敌": "7a3934", "险": "8b3631", "巢": "a54136", "障": "424f4c"}
const NODE_TEXT := {"大": "赏", "中": "赏", "小": "赏", "险": "甲"}
const NODE_TIP := {"起": "起点", "大": "大赏：打开会立刻惊动首领", "中": "中赏", "小": "小赏", "休": "休息点：治疗 / 删字 / 修饰 三选一，耗 3 步",
	"市": "商店", "谜": "谜：风险换资源", "敌": "明敌：身边的散字被它看守", "险": "守口精英", "巢": "首领巢穴"}

var ex: Expedition
var _map_grid: GridContainer
var _tray_row: HFlowContainer
var _tray_actions: HBoxContainer
var _build_box: VBoxContainer
var _build_scroll: ScrollContainer
var _event_box: VBoxContainer
var _log_box: VBoxContainer
var _hp_bar: StatBar
var _title_label: Label
var _boss_label: Label
var _stat_label: Label
var _seal_label: Label
var _relic_label: Label
var _confront_btn: Button
var _sel := -1
var _forge_sel: Array = []
var _boss_bar: PanelContainer
var _boss_bar_label: Label
var _alert_open := false
var _boss_piece: PanelContainer
var _boss_glyph: Label
var _boss_badge: Label
var _path_layer: BossPath
var _boss_tween: Tween
var _boss_shown := -1
var _legend_box: Control
var _mobile := false
var _map_cell_size := MAP_CELL
var _map_scroll: ScrollContainer
var _log_panel: PanelContainer
var _mobile_tabs
const FOG := Color("142b33")
const WALL := Color("203b43")


func build(root: Control) -> void:
	ex = GameState.expedition
	if ex == null:
		ex = Expedition.start()
		Achievements.start_run("expedition")
	_mobile = JourneyStyle.touch_scale(self) > 1.1
	if _mobile:
		_map_cell_size = int(ceil(48 * JourneyStyle.touch_scale(self)))
	var main := Ink.vbox(10)
	var frame := Ink.margin(64 if is_instance_valid(Router.study_stage) and Router.study_stage.visible else 16)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(frame)
	frame.add_child(main)
	main.add_child(_build_header())
	var body := Ink.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)
	body.add_child(_build_left())
	var middle := _build_middle()
	var right := _build_event_column()
	if _mobile:
		_mobile_tabs = preload("res://src/ui/journey/journey_tabs.gd").new()
		_mobile_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(_mobile_tabs)
		_mobile_tabs.add_tab("行旅", right)
		_mobile_tabs.add_tab("构筑", middle)
		_mobile_tabs.add_tab("战报", _log_panel)
	else:
		body.add_child(middle)
		body.add_child(right)
	EventBus.gold_changed.connect(_on_stats_changed.unbind(1))
	EventBus.hp_changed.connect(_on_stats_changed.unbind(2))
	EventBus.deck_changed.connect(_on_stats_changed)
	refresh()


func _build_event_column() -> Control:
	var right := Ink.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_build_right())
	var legend_toggle := JourneyStyle.button("行旅图例", func(): _legend_box.visible = not _legend_box.visible)
	right.add_child(legend_toggle)
	_legend_box = _build_legend()
	_legend_box.custom_minimum_size.y = 220
	_legend_box.hide()
	right.add_child(_legend_box)
	return right


func _exit_tree() -> void:
	for sig in [EventBus.gold_changed, EventBus.hp_changed, EventBus.deck_changed]:
		for c in sig.get_connections():
			if c.callable.get_object() == self:
				sig.disconnect(c.callable)


func _act(callback: Callable) -> void:
	callback.call()
	refresh()


func _ghost(text: String, callback: Callable, primary := false) -> Button:
	var b := Ink.button(text, primary)
	if not primary:
		b.theme_type_variation = "GhostButton"
	b.pressed.connect(_act.bind(callback))
	return b


func _build_header() -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(10)
	panel.add_child(pad)
	var row := Ink.hbox(16)
	pad.add_child(row)
	var left := Ink.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label = Ink.h2("")
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_title_label)
	_boss_label = JourneyStyle.label("", "Muted", JourneyStyle.RED)
	_boss_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_boss_label)
	row.add_child(left)
	var hp_wrap := Ink.vbox(2)
	hp_wrap.custom_minimum_size.x = 170
	hp_wrap.add_child(Ink.label("气血", "Muted"))
	_hp_bar = StatBar.new()
	hp_wrap.add_child(_hp_bar)
	row.add_child(hp_wrap)
	var stats := Ink.vbox(2)
	_stat_label = JourneyStyle.label("")
	stats.add_child(_stat_label)
	_seal_label = JourneyStyle.label("", "", JourneyStyle.GOLD)
	stats.add_child(_seal_label)
	_relic_label = JourneyStyle.label("", "", JourneyStyle.GOLD)
	# 完整清单放在悬停描述中，避免遗物数量撑开顶栏。
	_relic_label.clip_text = true
	_relic_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_relic_label.mouse_filter = Control.MOUSE_FILTER_PASS
	stats.add_child(_relic_label)
	stats.add_child(_ghost("印章与遗物", _open_loadout))
	row.add_child(stats)
	_confront_btn = _ghost("迎战首领", func(): ex.confront())
	_confront_btn.tooltip_text = "首领在 2 步内时可以主动迎战，不吃位置减益"
	_confront_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_confront_btn)
	var deck := _ghost("字袋", _open_deck)
	deck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(deck)
	var home := JourneyStyle.button("菜单", func(): PauseMenu.open())
	home.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(home)
	return panel


func _build_left() -> Control:
	var col := Ink.vbox(8)
	_boss_bar = PanelContainer.new()
	_boss_bar_label = Ink.label("", "", Palette.PAPER)
	_boss_bar_label.add_theme_font_size_override("font_size", int(17 * JourneyStyle.touch_scale(self)))
	_boss_bar_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bar_pad := Ink.margin(6)
	bar_pad.add_child(_boss_bar_label)
	_boss_bar.add_child(bar_pad)
	col.add_child(_boss_bar)
	# 地图格 + 上面一层：首领棋子和它接下来要走的路
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(MapGen.W * (_map_cell_size + 2) - 2, MapGen.H * (_map_cell_size + 2) - 2)
	if _mobile:
		_map_scroll = ScrollContainer.new()
		_map_scroll.custom_minimum_size.x = stack.custom_minimum_size.x
		_map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_map_scroll.add_child(stack)
		col.add_child(_map_scroll)
	else:
		col.add_child(stack)
	_map_grid = GridContainer.new()
	_map_grid.columns = MapGen.W
	_map_grid.add_theme_constant_override("h_separation", 2)
	_map_grid.add_theme_constant_override("v_separation", 2)
	stack.add_child(_map_grid)
	_path_layer = BossPath.new()
	_path_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_path_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_path_layer)
	_boss_piece = _build_boss_piece()
	stack.add_child(_boss_piece)
	var log_panel := Ink.panel("PanelInset")
	_log_panel = log_panel
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_panel.add_child(scroll)
	_log_box = Ink.vbox(1)
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_log_box)
	if not _mobile: col.add_child(log_panel)
	return col


func _build_middle() -> Control:
	var panel := Ink.panel("PanelInset")
	var col := Ink.vbox(8)
	if _mobile:
		_build_scroll = ScrollContainer.new()
		_build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		panel.add_child(_build_scroll)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_build_scroll.add_child(col)
	else:
		panel.add_child(col)
	col.custom_minimum_size.x = 216
	col.add_child(Ink.h2("战斗构筑"))
	_build_box = Ink.vbox(6)
	col.add_child(_build_box)
	col.add_child(Ink.caption("字匣 · 选字后加入字袋"))
	_tray_row = HFlowContainer.new()
	_tray_row.add_theme_constant_override("h_separation", 4)
	_tray_row.add_theme_constant_override("v_separation", 4)
	col.add_child(_tray_row)
	_tray_actions = Ink.hbox(6)
	col.add_child(_tray_actions)
	return panel


func _build_right() -> Control:
	var panel := Ink.panel("PanelCard")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pad := Ink.margin(12)
	panel.add_child(pad)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pad.add_child(scroll)
	_event_box = Ink.vbox(8)
	_event_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_event_box)
	return panel


func _open_deck() -> void:
	var viewer := CollectionOverlay.new()
	var chars: Array = []
	var counts := GameState.glyph_counts()
	for id in counts:
		var cd: CharacterData = Database.get_character_by_glyph(id)
		if cd != null:
			chars.append(cd)
	viewer.setup({"title": "字袋", "instances": GameState.deck, "subtitle": "%d / %d 枚 · 战斗时从这里抽字" % [GameState.deck_size(), Expedition.DECK_CAP], "characters": chars, "counts": counts})
	viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(viewer)


# ---------------------------------------------------------------- 刷新
func refresh() -> void:
	_refresh_map()
	_refresh_build()
	_refresh_event()
	_refresh_log()
	_on_stats_changed()
	_refresh_boss_bar()
	_show_alert()
	_refresh_boss_piece()
	if _mobile: _focus_map_position.call_deferred()


func _focus_map_position() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or _map_grid.get_child_count() <= ex.pos: return
	_map_scroll.ensure_control_visible(_map_grid.get_child(ex.pos))


## 地图上方的首领提示条：沉睡 / 惊动倒计时 / 追击距离，颜色随危险程度变
func _refresh_boss_bar() -> void:
	var color := Palette.INK_SOFT
	var boss_name := ex.encounter_enemy("boss", ex.boss).name
	var text := "首领【%s】在巢穴里沉睡，没有在追你" % boss_name
	if ex.boss_down:
		color = Palette.JADE
		text = "首领【%s】已被击败 · 本层已封闭，请处理幕间结算" % boss_name
	elif ex.stir != null and not ex.awake():
		color = Palette.GOLD_DK
		text = "首领【%s】被惊动了！%d 步后起身追你" % [boss_name, int(ex.rise) - ex.t]
	elif ex.awake():
		var d := MapGen.bfs(ex.boss_mask(), ex.boss)[ex.pos]
		color = Palette.VERMILION if d > 3 else Palette.VERMILION_DK
		var go := "（被定住 %d 步）" % ex.stun if ex.stun > 0 else " · 下一步 %d%% 会动" % int(round(ex.move_chance() * 100))
		text = "首领【%s】正在追你 · 相距 %d 步%s · 地图上红色的【%s】" % [boss_name, d, go, ex.m.TH.boss]
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(0)
	_boss_bar.add_theme_stylebox_override("panel", sb)
	_boss_bar_label.text = text


## 首领惊动 / 起身时弹窗（一次一个，点「知道了」再弹下一个）
func _show_alert() -> void:
	if _alert_open or ex.alerts.is_empty():
		return
	var a: Array = ex.alerts.pop_front()
	_alert_open = true
	var overlay := ChoiceOverlay.new()
	overlay.setup({"title": a[0], "body": a[1], "options": [{"text": "知道了", "primary": true}]})
	overlay.chose.connect(func(_i): _alert_open = false; overlay.queue_free(); refresh())
	add_child(overlay)


func _on_stats_changed() -> void:
	if not is_instance_valid(_hp_bar):
		return
	_title_label.text = "墨途远征" if _mobile else "墨途远征 · 第 %d 幕 · %s" % [ex.act, ex.m.tn]
	_boss_label.text = "第 %d 幕 · %s · %d 步" % [ex.act, ex.m.tn, ex.t] if _mobile else "%s　·　第 %d 步" % [ex.boss_status(), ex.t]
	_hp_bar.setup_bar(GameState.player_hp, GameState.player_max_hp, JourneyStyle.RED)
	_stat_label.text = "墨 %d　❖ %d　字袋 %d/%d" % [ex.ink, GameState.gold, GameState.deck_size(), Expedition.DECK_CAP]
	_seal_label.text = "印章：" + ("、".join(ex.seals) if not ex.seals.is_empty() else "无")
	_seal_label.tooltip_text = "\n".join(ex.seals.map(func(s): return "%s：%s" % [s, Expedition.SEALS[s][0]]))
	_relic_label.text = "遗物：" + ("、".join(GameState.relics.slice(0, 2).map(func(r): return Relics.name_of(r))) + (" 等%d件" % GameState.relics.size() if GameState.relics.size() > 2 else "") if not GameState.relics.is_empty() else "无")
	_relic_label.tooltip_text = "\n".join(GameState.relics.map(func(r): return Relics.text(r) + _bind_note(r)))
	_confront_btn.text = "本层已结束" if ex.boss_down else "迎战首领"
	_confront_btn.tooltip_text = "本层已封闭，请在右侧完成印章选择和幕间结算" if ex.boss_down else "首领在 2 步内时可以主动迎战，不吃位置减益"
	_confront_btn.disabled = not ex.can_confront()


## 方格按钮：底色 / 字色 / 边框（宽 border_w）
func _cell(text: String, size: int, bg: Color, fg: Color, border: Color, border_w := 1) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", int(size * 0.48))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.lightened(0.08) if state == "hover" else bg
		sb.border_color = border
		sb.set_border_width_all(border_w)
		sb.set_corner_radius_all(0)
		b.add_theme_stylebox_override(state, sb)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(color_name, fg)
	return b


func _refresh_map() -> void:
	for child in _map_grid.get_children():
		child.queue_free()
	for k in MapGen.N:
		_map_grid.add_child(_map_cell(k))


func _map_cell(k: int) -> Button:
	var m: Dictionary = ex.m
	var seen: bool = ex.explored.has(k)
	var lit: bool = ex.visible.has(k)
	var bg := Palette.PAPER_DARK
	var fg := Palette.INK
	var text := ""
	var tip := ""
	if not seen:
		bg = FOG
		if ex.is_beacon(k):
			var tp: String = m.node[k].t
			text = "★"
			fg = Color(NODE_COLOR[tp]).lightened(0.4)
			tip = "隔着迷雾发光：" + NODE_TIP.get(tp, tp)
	elif m.ink[k] != 0:
		bg = WALL
	else:
		if m.pocket.has(k):
			bg = Color("efd9a8")
		var mc: Dictionary = ex.mech_at(k)
		var o: Dictionary = m.node.get(k, {})
		if not mc.is_empty():
			bg = Color("496564")
			fg = Palette.PAPER
			text = mc.g + ({Vector2i(0, 1): "→", Vector2i(1, 0): "↓", Vector2i(0, -1): "←", Vector2i(-1, 0): "↑"}.get(mc.get("dir", Vector2i.ZERO), ""))
			if mc.kind == "gate" and ex.gate_shut(k, ex.t):
				bg = bg.darkened(0.45)
				tip = "关着 · "
			elif mc.kind == "wire" and not ex.mover_live(k, ex.t):
				bg = bg.darkened(0.45)
				tip = "没电 · "
			tip += mc.desc
		elif m.obst.has(k):
			bg = Color(NODE_COLOR["障"])
			fg = Palette.PAPER
			text = "障"
			tip = "墨障：花 %d 墨冲开（墨不够以血冲开）" % Expedition.BARRIER_INK
		elif not o.is_empty() and o.t != "巢" and not (ex.taken.has(k) and o.t != "起"):
			bg = Color(NODE_COLOR[o.t])
			fg = Palette.PAPER
			text = NODE_TEXT.get(o.t, o.get("g", o.t))
			tip = NODE_TIP.get(o.t, "")
			if o.t in ["敌", "险"]:
				var kind := "elite" if o.t == "险" else "foe"
				var enemy := ex.encounter_enemy(kind, k)
				text = enemy.glyph
				tip = enemy.name + " · " + ex.stage_text(kind, k) + " · 生命%d\n" % enemy.max_hp + enemy.description + "\n" + ex.encounter_info({"kind": kind, "k": k}).rewards + "\n胜利后耗%d步" % Expedition.FIGHT_T
		elif o.get("t", "") == "巢":
			bg = Color(NODE_COLOR["巢"]).darkened(0.3)
			fg = Palette.PAPER
			text = "巢"
			tip = "首领巢穴：" + ex.encounter_enemy("boss", ex.boss).name
		elif m.glyph.has(k) and not ex.taken.has(k):
			bg = Color("e9d6ad")
			text = m.glyph[k]
			var gd: String = ex.guard_of(k)
			tip = "散字【%s】" % m.glyph[k] + ("：被%s看守" % gd if not gd.is_empty() else "：走过去就拾")
			if not gd.is_empty():
				fg = Palette.INK_FAINT
		elif m.get("wire_path", []).has(k):
			fg = Color(MapGen.MOVERS["雷池"].color)
			text = "·"
			tip = "导线从这里经过（只是连线，踩两头才会传送）"
		if ex.sealed(k) and (not o.is_empty() or m.glyph.has(k)) and not ex.taken.has(k):
			text = "封"
			fg = Palette.VERMILION
			tip = "被伏兵控制的奖励（伏兵就在这附近）"
		if ex.revealed_amb_at(k):
			text = "伏"
			fg = Palette.VERMILION
			tip = "伏兵在这里（走进它周围就会开战）"
		if not lit:
			bg = bg.lerp(Palette.PAPER_SHADE, 0.35)
	# 伏兵：交战中标「伏」，打赢后画 ✕（不受迷雾遮挡）
	var amb_i := ex.ambush_index_at(k)
	if amb_i >= 0 and ex.fight.get("kind", "") == "ambush" and int(ex.fight.amb) == amb_i:
		bg = Palette.VERMILION
		fg = Palette.PAPER
		text = "伏"
		tip = "伏兵从这里杀出来了！"
	elif amb_i >= 0 and ex.amb_done.has(amb_i):
		bg = Palette.PAPER_DARK
		fg = Palette.VERMILION_DK
		text = "✕"
		tip = "已击退的伏兵"
	var border := JourneyStyle.EDGE
	var bw := 1
	if ex.can_step(k):
		border = Palette.GOLD_DK
		bw = 3
	if ex.pos == k:
		border = Palette.VERMILION
		bw = 4
		if text.is_empty():
			text = "●"
			fg = Palette.VERMILION
	var b := _cell(text, _map_cell_size, bg, fg, border, bw)
	b.tooltip_text = tip
	b.disabled = ex.boss_down
	b.pressed.connect(_on_map_cell.bind(k))
	return b


func _on_map_cell(k: int) -> void:
	if ex.can_step(k):
		ex.move(k)
		_forge_sel.clear()
	refresh()


func _refresh_build() -> void:
	for child in _build_box.get_children(): child.queue_free()
	var texts: Array = [
		"第%d幕 · %s" % [ex.act, ["起步", "成型", "兑现"][ex.act - 1]],
		["基础应对 → 盘面练习 → 污染管理", "资源运转 → 费用调度 → 组合考验", "复合应对 → 循环稳定 → 终局考验"][ex.act - 1],
		"越深入，怪物机制越复杂。精英守着高价值奖励；前往深区前先补强字袋。",
		"字匣里的字可加入字袋，或在地图熔炉换字。中赏、大赏可选择遗物。",
		"组词在战斗的4×4字盘内完成，印章与遗物提供跨战成长。",
	]
	for text in texts:
		var label := Ink.caption(text)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 210
		_build_box.add_child(label)
	_refresh_tray()


func _refresh_tray() -> void:
	for child in _tray_row.get_children():
		child.queue_free()
	for child in _tray_actions.get_children():
		child.queue_free()
	if _sel >= ex.tray.size():
		_sel = -1
	var forging: bool = ex.top_panel().get("kind", "") == "forge"
	for i in ex.tray.size():
		var on: bool = (_sel == i) if not forging else _forge_sel.has(i)
		var b := _cell(ex.tray[i], _map_cell_size if _mobile else 38, Palette.VERMILION if on else Palette.SURFACE_RAISED, Palette.PAPER if on else Palette.INK, Palette.BORDER_SOFT)
		b.pressed.connect(_on_tray.bind(i))
		_tray_row.add_child(b)
	for i in range(ex.tray.size(), ex.tray_cap()):
		var empty := _cell("", _map_cell_size if _mobile else 38, Palette.PAPER_DARK, Palette.INK, Palette.BORDER_SOFT)
		empty.disabled = true
		_tray_row.add_child(empty)
	if _sel >= 0 and not ex.busy():
		var to_deck := _ghost("进字袋", func(): ex.tray_to_deck(_sel); _sel = -1)
		to_deck.disabled = GameState.deck_size() >= Expedition.DECK_CAP
		_tray_actions.add_child(to_deck)
		_tray_actions.add_child(_ghost("丢掉", func(): ex.discard(_sel); _sel = -1))


func _on_tray(i: int) -> void:
	if ex.top_panel().get("kind", "") == "forge":
		if _forge_sel.has(i):
			_forge_sel.erase(i)
		elif _forge_sel.size() < 2:
			_forge_sel.append(i)
	else:
		_sel = -1 if _sel == i else i
	refresh()


func _refresh_log() -> void:
	for child in _log_box.get_children():
		child.queue_free()
	for line in ex.lines:
		_log_box.add_child(Ink.caption(line))


# ---------------------------------------------------------------- 右侧事件面板
func _add(c: Control) -> Control:
	_event_box.add_child(c)
	return c


func _refresh_event() -> void:
	for child in _event_box.get_children():
		child.queue_free()
	if ex.over:
		_event_over()
		return
	if not ex.fight.is_empty():
		_event_fight()
		return
	var p := ex.top_panel()
	match p.get("kind", ""):
		"loot": _event_loot(p)
		"rest": _event_rest()
		"shop": _event_shop()
		"forge": _event_forge()
		"event": _event_mystery(p)
		"seal_swap": _event_seal_swap(p)
		"relic_bind": _event_relic_bind(p)
		"relic_pick": _event_relic_pick(p)
		"relic_wish": _event_relic_wish(p)
		"act_end": _event_act_end()
		_: _event_idle()


func _event_idle() -> void:
	_add(Ink.h2("探索"))
	_add(Ink.body("点脚边的金框格前进。迷雾里只看得见身边 %d 步；★ 是隔着迷雾发光的引导点（大赏、休息点、商店）。" % ex.vision()))
	_add(Ink.caption("首领被惊动后会沿最短路追来。战斗、休息都要花时间。被追上的位置会给首领战一个减益；主动迎战不吃减益。"))
	_add(Ink.caption("「封」：被伏兵控制的奖励，伏兵就在附近。走进它的领地就必须开战。"))
	if ex.tray.size() >= ex.tray_cap():
		_add(Ink.label("字匣满了：把字放进字袋、在熔炉换字，或丢掉。", "", Palette.VERMILION))


func _event_fight() -> void:
	var f: Dictionary = ex.fight
	var info := ex.encounter_info(f)
	var ed: EnemyData = info.enemy
	var category: String = {"ambush": "伏兵突袭", "foe": "普通战", "elite": "精英战", "boss": "首领战"}[f.kind]
	_add(Ink.h2(ed.name))
	_add(Ink.caption("%s · %s · 生命上限%d · 初始护盾%d" % [category, info.stage, info.hp, info.initial_block]))
	if f.kind == "ambush":
		_add(Ink.body("不能拒绝。敌人先手：" + info.first + "。"))
	elif f.kind == "boss" and not str(f.get("debuff", "")).is_empty():
		_add(Ink.body("位置减益：" + Expedition.DEBUFF_TEXT[f.debuff]))
	_add(_ghost("开战", _start_battle, true))
	_add(Ink.body(info.rewards))
	_add(Ink.caption(info.time))
	_add(Ink.caption("行动循环（基础值，任务和半血阶段会改变数值）：" + info.cycle))
	var mechanic := _add(Ink.caption(info.mechanic))
	mechanic.tooltip_text = info.mechanic
	var notes: Array[String] = []
	if f.kind == "boss":
		if ex.has_seal("朱笔"):
			notes.append("朱笔：首领当前生命和上限各−6，已计入上方生命。")
	if ex.has_seal("字印"): notes.append("字印：开场多抽1枚字。")
	if ex.has_seal("镇纸"): notes.append("镇纸：胜利后返还本场实际损失生命，最多4点。")
	for note in notes: _add(Ink.caption(note))


func _start_battle() -> void:
	goto("res://src/screens/battle_screen.gd", {"node": ex.battle_node(), "expedition": true})


func _event_loot(p: Dictionary) -> void:
	_add(Ink.h2({"大": "大赏", "中": "中赏", "小": "小赏"}[p.tier]))
	_add(Ink.caption("挑一样。字先进字匣（%d/%d），满了进字袋。" % [ex.tray.size(), ex.tray_cap()]))
	for i in p.options.size():
		var o: Dictionary = p.options[i]
		var title := ex.loot_text(o)
		if o.kind == "relic": title = "遗物「%s」" % Relics.name_of(o.relic)
		elif o.kind == "seal": title = "印章「%s」" % o.seal
		var b := _ghost(title, func(): ex.choose_loot(i), i == 0)
		b.tooltip_text = ex.loot_text(o)
		b.disabled = o.kind == "relic" and GameState.has_relic(o.relic)
		_add(b)
		if o.kind == "relic": _add(Ink.caption(Relics.desc_of(o.relic)))
		elif o.kind == "seal": _add(Ink.caption(Expedition.SEALS[o.seal][0]))


func _event_rest() -> void:
	_add(Ink.h2("休息点"))
	_add(Ink.body("三选一，耗 %d 步，首领照常逼近。" % Expedition.REST_T))
	_add(_ghost("治疗：气血 +%d" % ex.rest_heal_amount(), func(): ex.rest("heal"), true))
	_add(_ghost("删字：从字袋删掉 1 枚（含污染字）", func(): _pick_deck("删哪一枚？", func(id): ex.rest("remove", id))))
	_add(_ghost("修饰：1 枚字永久镀金", func(): _pick_deck("镀金哪一枚？", func(id): ex.rest("gild", id))))


func _event_shop() -> void:
	_add(Ink.h2("商店"))
	var offers: Array = ex.shop_offers() + ex.buyback_offers()
	var names := {"glyph": "买字【%s】", "buyback": "回购【%s】", "remove": "删字", "gild": "修饰（镀金）", "heal": "治疗 30%"}
	for i in offers.size():
		var o: Dictionary = offers[i]
		var label: String = ("遗物「%s」" % Relics.name_of(o.relic)) if o.kind == "relic" else (names[o.kind] % o.glyph if o.has("glyph") else names[o.kind])
		var cost := ex.price(o)
		var b: Button
		match o.kind:
			"remove":
				b = _ghost("%s　❖ %d" % [label, cost], func(): _pick_deck("删哪一枚？", func(id): ex.buy(i, id)))
			"gild":
				b = _ghost("%s　❖ %d" % [label, cost], func(): _pick_deck("镀金哪一枚？", func(id): ex.buy(i, id)))
			_:
				b = _ghost("%s　❖ %d" % [label, cost], func(): ex.buy(i))
		b.disabled = GameState.gold < cost or (o.kind == "relic" and GameState.has_relic(o.relic))
		_add(b)
		if o.has("glyph"):
			var character := Database.get_character_by_glyph(str(o.glyph))
			if character != null:
				var description := EffectText.new()
				description.add_theme_font_size_override("normal_font_size", 17)
				description.set_effect_text(EffectGlossary.character_hint(character))
				_add(description)
		if o.kind == "relic":
			RelicArt.apply_button(b, str(o.relic))
			var cap := Ink.caption(Relics.desc_of(o.relic))
			cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_add(cap)
	for id in GameState.relics.duplicate():
		var sell := _ghost("卖掉「%s」　❖ +%d" % [Relics.name_of(id), Relics.sell_price(id)], func(): ex.sell_relic(id))
		sell.tooltip_text = Relics.text(id)
		RelicArt.apply_button(sell, str(id))
		_add(sell)
	_add(Ink.caption("丢弃过的字可按半价回购。"))
	var refresh := _ghost("刷新货架　❖ %d" % ex.shop_refresh_cost(), func(): ex.refresh_shop())
	refresh.disabled = GameState.gold < ex.shop_refresh_cost()
	_add(refresh)
	_add(Ink.caption("刷新换一批字和遗物，服务保留。"))
	_add(_ghost("离开", func(): ex.leave_panel()))


func _event_forge() -> void:
	_add(Ink.h2("熔炉"))
	_add(Ink.body("在字匣里选两枚字，换一枚稀有字。每处熔炉只能用一次。"))
	var gs: Array = _forge_sel.map(func(i): return ex.tray[i])
	var b := _ghost("熔成稀有字" + "".join(gs.map(func(g): return "【%s】" % g)), func(): ex.forge(_forge_sel[0], _forge_sel[1]); _forge_sel.clear(), true)
	b.disabled = _forge_sel.size() != 2
	_add(b)
	_add(_ghost("不熔，走开", func(): ex.leave_panel(); _forge_sel.clear()))


func _event_mystery(p: Dictionary) -> void:
	var e: Dictionary = Expedition.EVENTS[int(p.event)]
	_add(Ink.h2("谜 · " + e.title))
	_add(Ink.body(e.text))
	_add(_ghost(e.a, func(): ex.choose_event(true), true))
	_add(_ghost(e.b, func(): ex.choose_event(false)))


func _event_seal_swap(p: Dictionary) -> void:
	_add(Ink.h2("印章满了"))
	_add(Ink.body("新印章「%s」：%s。一局最多带 %d 个。" % [p.seal, Expedition.SEALS[p.seal][0], Expedition.SEAL_CAP]))
	for i in ex.seals.size():
		_add(_ghost("丢掉「%s」换它" % ex.seals[i], func(): ex.swap_seal(i)))
	_add(_ghost("不要新印章", func(): ex.swap_seal(-1)))


func _event_relic_bind(p: Dictionary) -> void:
	_add(Ink.h2("「%s」选一枚字" % Relics.name_of(p.relic)))
	var desc := Ink.body(Relics.desc_of(p.relic) + "。")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(desc)
	_add(_ghost("从字袋里挑", func(): _pick_deck("「%s」绑哪一枚？" % Relics.name_of(p.relic), func(id): ex.bind_relic(id)), true))


func _event_relic_pick(p: Dictionary) -> void:
	var verb := "镀金" if Relics.pick_spec(p.relic)[0] == "gild" else "复制"
	_add(Ink.h2("「%s」%s一枚字（还剩 %d 枚）" % [Relics.name_of(p.relic), verb, int(p.left)]))
	var desc := Ink.body(Relics.desc_of(p.relic) + "。")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(desc)
	_add(_ghost("从字袋里挑", func(): _pick_deck("「%s」%s哪一枚？" % [Relics.name_of(p.relic), verb], func(id): ex.pick_relic(id)), true))


func _event_relic_wish(p: Dictionary) -> void:
	_add(Ink.h2(Relics.name_of("monkey") + " · 许一个愿"))
	_add(Ink.body("每个愿望都有代价，只能许一次。"))
	for i in p.options.size():
		var wish: String = p.options[i]
		var cb := func(): ex.choose_wish(i)
		if wish == "endless_glyph":
			cb = func(): _pick_deck("千字同文：字袋全部变成哪个字？", func(id): ex.choose_wish(i, id))
		_add(_ghost("「%s」" % Relics.WISHES[wish][0], cb, i == 0))
		var cap := Ink.caption(Relics.WISHES[wish][1])
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_add(cap)


## 绑定类遗物：被绑的字已不在字袋时提示
func _bind_note(id: String) -> String:
	if not Relics.needs_bind(id):
		return ""
	var inst := GameState.relic_bound_inst(id)
	return "（绑定【%s】）" % inst.glyph() if inst != null else "（绑定的字已不在字袋，暂不生效）"


func _event_act_end() -> void:
	_add(Ink.h2("第 %d 幕完成" % ex.act))
	_add(_ghost("进入第 %d 幕" % (ex.act + 1) if ex.act < 3 else "完成远征", func(): ex.next_act(), true))
	_add(Ink.body("本层已结束，未拿的奖励、商店和休息点不再可用。"))
	if ex.act < 3:
		var supply := ex.act_supply()
		_add(Ink.body("进入下一幕后补给：铜钱 +%d，气血最多 +%d，墨 +%d。" % [supply.gold, supply.heal, supply.ink]))
		_add(Ink.caption("补给仅发放一次。剩余的墨、字匣、字袋、印章和遗物带入下一幕。"))


func _event_over() -> void:
	goto.call_deferred("res://src/screens/run_result_screen.gd", {"victory":ex.won})


# ---------------------------------------------------------------- 首领棋子
## 一枚一直摆在地图上的棋子：睡着时暗红、蜷在巢穴；惊动后描金边、头顶倒计时；
## 追击时鲜红，逐格走向你，前方用虚点标出它接下来要走的路。
class BossPath extends Control:
	var points: Array = []      ## 像素中心点
	var color := Palette.VERMILION

	func _draw() -> void:
		for i in points.size():
			var a := 1.0 - float(i) / (points.size() + 1)
			draw_circle(points[i], 5.0, Color(color, 0.25 + 0.5 * a))
			if i > 0:
				draw_dashed_line(points[i - 1], points[i], Color(color, 0.35 * a), 2.0, 5.0)


func _cell_center(k: int) -> Vector2:
	var p := MapGen.rc(k)
	return Vector2(p.y * (_map_cell_size + 2) + _map_cell_size / 2.0, p.x * (_map_cell_size + 2) + _map_cell_size / 2.0)


func _cell_origin(k: int) -> Vector2:
	return _cell_center(k) - Vector2(_map_cell_size, _map_cell_size) / 2.0


func _build_boss_piece() -> PanelContainer:
	var piece := PanelContainer.new()
	piece.custom_minimum_size = Vector2(_map_cell_size, _map_cell_size)
	piece.size = Vector2(_map_cell_size, _map_cell_size)
	piece.mouse_filter = Control.MOUSE_FILTER_PASS
	piece.pivot_offset = Vector2(_map_cell_size, _map_cell_size) / 2.0
	_boss_glyph = Label.new()
	_boss_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_glyph.add_theme_font_size_override("font_size", int(24 * JourneyStyle.touch_scale(self)))
	_boss_glyph.add_theme_color_override("font_color", Palette.PAPER)
	piece.add_child(_boss_glyph)
	_boss_badge = Label.new()
	_boss_badge.add_theme_font_size_override("font_size", int(12 * JourneyStyle.touch_scale(self)))
	_boss_badge.add_theme_color_override("font_color", Palette.PAPER)
	_boss_badge.add_theme_color_override("font_outline_color", Palette.INK)
	_boss_badge.add_theme_constant_override("outline_size", 4)
	_boss_badge.position = Vector2(_map_cell_size - 14, -8)
	piece.add_child(_boss_badge)
	return piece


func _refresh_boss_piece() -> void:
	if not is_instance_valid(_boss_piece):
		return
	var awake := ex.awake()
	var stirred := ex.stir != null and not awake
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(_map_cell_size / 2)
	sb.bg_color = Palette.VERMILION if awake else Palette.VERMILION.darkened(0.45)
	sb.border_color = Palette.GOLD if stirred else (Palette.PAPER if awake else Palette.INK)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	_boss_piece.add_theme_stylebox_override("panel", sb)
	_boss_glyph.text = ex.m.TH.boss
	_boss_badge.text = ("z" if ex.stir == null else ("%d" % (int(ex.rise) - ex.t) if stirred else ("定" if ex.stun > 0 else "")))
	_boss_piece.tooltip_text = "首领【%s】· %s" % [ex.encounter_enemy("boss", ex.boss).name, ex.boss_status()]
	_boss_piece.modulate.a = 0.85 if ex.stir == null else 1.0
	# 一开始看不见：睡着时只有走到看得见它的地方才露面；惊动后一直显示
	_boss_piece.visible = ex.boss_revealed()
	# 逐格播放首领这一次走过的路
	var steps: Array = ex.boss_trail.duplicate()
	ex.boss_trail.clear()
	if _boss_tween != null and _boss_tween.is_valid():
		_boss_tween.kill()
	if _boss_shown < 0 or steps.is_empty() or not is_inside_tree():
		_boss_piece.position = _cell_origin(ex.boss)
	else:
		_boss_piece.position = _cell_origin(_boss_shown)
		_boss_tween = create_tween()
		for k in steps:
			_boss_tween.tween_property(_boss_piece, "position", _cell_origin(k), 0.16).set_trans(Tween.TRANS_QUAD)
		_boss_tween.tween_property(_boss_piece, "scale", Vector2(1.15, 1.15), 0.08)
		_boss_tween.tween_property(_boss_piece, "scale", Vector2.ONE, 0.08)
	_boss_shown = ex.boss
	# 前方的路
	_path_layer.points = ex.boss_path().map(func(k): return _cell_center(k))
	_path_layer.queue_redraw()


# ---------------------------------------------------------------- 图样说明（临时，给美术对照；美化后可整段删掉）
## 每一项：色块（实际用色 + 实际字）+ 名称 + 色值。改色只要改 NODE_COLOR / MapGen.THEMES / Palette，这里会跟着变。
func _build_legend() -> Control:
	var panel := Ink.panel("PanelInset")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var outer := Ink.vbox(4)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer)
	outer.add_child(JourneyStyle.label("行旅图例", "", JourneyStyle.GOLD))
	var col := GridContainer.new()
	col.columns = 2
	col.add_theme_constant_override("h_separation", 10)
	col.add_theme_constant_override("v_separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(col)
	var th: Dictionary = ex.m.TH
	var groups := [
		["地形", [
			["", FOG, Palette.PAPER, "迷雾（没去过）"],
			["", WALL, Palette.PAPER, "墨渍（墙，随主题变色）"],
			["", Palette.PAPER_DARK, Palette.INK, "空地"],
			["", Palette.PAPER_DARK.lerp(Palette.PAPER_SHADE, 0.35), Palette.INK, "去过但不在视野里"],
			["", Color("efd9a8"), Palette.INK, "奖励凹槽（死路）"],
			["障", Color(NODE_COLOR["障"]), Palette.PAPER, "墨障（花墨冲开）"],
		]],
		["节点", [
			["起", Color(NODE_COLOR["起"]), Palette.PAPER, "起点"],
			["赏", Color(NODE_COLOR["大"]), Palette.PAPER, "大赏"],
			["赏", Color(NODE_COLOR["中"]), Palette.PAPER, "中赏"],
			["赏", Color(NODE_COLOR["小"]), Palette.PAPER, "小赏"],
			["休", Color(NODE_COLOR["休"]), Palette.PAPER, "休息点"],
			["市", Color(NODE_COLOR["市"]), Palette.PAPER, "商店"],
			["谜", Color(NODE_COLOR["谜"]), Palette.PAPER, "谜"],
			["火", Color("e9d6ad"), Palette.INK, "散字（被看守时字变淡）"],
			["★", FOG, Color(NODE_COLOR["大"]).lightened(0.4), "引导点（隔着迷雾发光）"],
		]],
		["敌人", [
			[th.foes[0], Color(NODE_COLOR["敌"]), Palette.PAPER, "明敌（字 = 实际怪物字形）"],
			["甲", Color(NODE_COLOR["险"]), Palette.PAPER, "守口精英"],
			["封", Palette.PAPER_DARK, Palette.VERMILION, "被伏兵封住的奖励"],
			["伏", Palette.PAPER_DARK, Palette.VERMILION, "已知的伏兵位置"],
			["伏", Palette.VERMILION, Palette.PAPER, "伏兵交战中"],
			["✕", Palette.PAPER_DARK, Palette.VERMILION_DK, "已击退的伏兵"],
			["巢", Color(NODE_COLOR["巢"]).darkened(0.3), Palette.PAPER, "首领巢穴"],
			[th.boss, Palette.VERMILION.darkened(0.45), Palette.PAPER, "首领棋子 · 沉睡（黑边，角标 z）"],
			[th.boss, Palette.VERMILION.darkened(0.45), Palette.GOLD, "首领棋子 · 惊动（金边，角标倒计时）"],
			[th.boss, Palette.VERMILION, Palette.PAPER, "首领棋子 · 追击（白边，前方虚点 = 要走的路）"],
		]],
		["本幕机关 · " + ex.m.tn, (th.mech + ([MapGen.MOVERS[ex.m.tn]] if MapGen.MOVERS.has(ex.m.tn) else [])).map(func(mc): return [mc.g, Color("496564"), Palette.PAPER, mc.desc])],
		["玩家", [
			["●", Palette.PAPER_DARK, Palette.VERMILION, "你（朱红粗框）"],
			["", Palette.PAPER_DARK, Palette.GOLD_DK, "金框 = 下一步能走的格"],
		]],
	]
	for g in groups:
		if col.get_child_count() % 2 == 1:
			col.add_child(Control.new())
		col.add_child(Ink.label(g[0], "", JourneyStyle.MUTED))
		col.add_child(Control.new())
		for item in g[1]:
			col.add_child(_legend_row(item[0], item[1], item[2], item[3]))
	return panel


func _legend_row(glyph: String, bg: Color, fg: Color, desc: String) -> Control:
	var row := Ink.hbox(6)
	var chip := _cell(glyph, 24, bg, fg, fg if glyph.is_empty() else Palette.BORDER_SOFT, 2 if glyph.is_empty() else 1)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chip)
	chip.custom_minimum_size = Vector2(24, 24)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Ink.caption(desc)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 150
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


func _open_loadout() -> void:
	var overlay := ChoiceOverlay.new()
	overlay.setup({"title":"印章与遗物", "body":_seal_label.text + "\n" + _seal_label.tooltip_text + "\n\n" + "\n".join(GameState.relics.map(func(id): return Relics.text(id))), "relics":GameState.relics.duplicate(), "hud_details":true,"scroll_body":true,"dismissible":true,"options":[{"text":"返回整备","primary":true}]})
	add_child(overlay)


func _pick_deck(title: String, callback: Callable) -> void:
	var overlay := CollectionOverlay.new()
	overlay.setup({"title":title,"instances":GameState.deck,"counts":GameState.glyph_counts(),"pick_on_click":true})
	overlay.picked.connect(func(character: CharacterData):
		callback.call(character.id)
		refresh())
	add_child(overlay)
