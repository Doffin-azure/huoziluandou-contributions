extends ScreenBase
## 战斗界面（HUD v2 / 参考「墨芯」概念）。
## 顶部：玩家条 · 回合 · 敌人条；左侧：鲸鱼气泡（预览/结果）+ 已选路径 + 资源；
## 中部：字盘；右侧：战报；底部：操作行。无效词弹 0.6s 反应。

var battle: BattleState
var node: MapNodeData
var _board_view: BoardView
var _enemy_row: HBoxContainer
var _enemy_widgets: Array = []
var _player_hp: StatBar
var _player_block: Label
var _player_status: HBoxContainer
var _resource_label: Label
var _pile_label: Label
var _turn_label: Label
var _bubble: SpeechBubble
var _path_bar: PathBar
var _preview_glyphs: Label
var _preview_effect: Label
var _confirm_btn: Button
var _reaction: ReactionOverlay
var _log_box: VBoxContainer
var _log_scroll: ScrollContainer
var _target_index := 0
var _pending_path: Array = []
var _current_word: WordData = null
var _transform_uid := -1
var _fuse_stage := 0
var _fuse_first := Vector2i(-1, -1)
var _pair_mode := "fuse"
var _pending_place_uid := -1
var _merge_active := false
var _merge_bag_uid := -1
var _merge_discard_uid := -1
var _merge_cell1 := Vector2i(-1, -1)
var _finished := false


func build(root: Control) -> void:
	node = params.get("node", null)
	if node == null:
		var act := Database.get_act(GameState.act_index)
		if act != null and GameState.node_index - 1 < act.nodes.size():
			node = act.nodes[GameState.node_index - 1]
	if node == null:
		node = MapNodeData.new()

	battle = BattleState.new(Database.rules)
	var enemy_datas: Array = node.enemies
	if enemy_datas.is_empty():
		enemy_datas = [Database.get_enemy("ink_spirit")]
	battle.start(GameState.make_battle_deck(), enemy_datas)

	var main := Ink.vbox(0)
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(main)
	main.add_child(_build_topbar())

	var middle := Ink.hbox(10)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(middle)
	middle.add_child(_build_left())
	middle.add_child(_build_center())
	middle.add_child(_build_log_panel())

	main.add_child(_build_bottombar())

	_reaction = ReactionOverlay.new()
	_reaction.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_reaction)

	EventBus.log_message.connect(_on_log)
	for line in battle.log:
		_on_log(line)
	_refresh_all()
	_on_log("战斗开始：%s" % node.title)


func _exit_tree() -> void:
	if EventBus.log_message.is_connected(_on_log):
		EventBus.log_message.disconnect(_on_log)


# ---------------------------------------------------------------- 顶部：玩家 / 回合 / 敌人
func _build_topbar() -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(6)
	panel.add_child(pad)
	var row := Ink.hbox(10)
	pad.add_child(row)

	# 玩家
	var pblock := Ink.hbox(8)
	var pseal := SealView.new()
	pseal.custom_minimum_size = Vector2(44, 44)
	pseal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pseal.setup("你", Palette.INK_SOFT, SealView.Shape.SQUARE, Palette.PAPER)
	pblock.add_child(pseal)
	var pcol := Ink.vbox(2)
	pcol.custom_minimum_size.x = 240
	pcol.add_child(Ink.label("玩家", "Subheading"))
	_player_hp = StatBar.new()
	pcol.add_child(_player_hp)
	_player_block = Ink.label("", "", Palette.BLOCK)
	pcol.add_child(_player_block)
	pblock.add_child(pcol)
	row.add_child(pblock)
	row.add_child(Ink.expander())

	# 回合
	var rv := Ink.vbox(0)
	_turn_label = Ink.label("回合 1", "Stat")
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(_turn_label)
	var rl := Ink.label("TURN", "Muted")
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(rl)
	row.add_child(rv)
	row.add_child(Ink.expander())

	# 敌人
	_enemy_row = Ink.hbox(10)
	_enemy_row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(_enemy_row)
	return panel


func _make_enemy_card(i: int, e: Combatant) -> Dictionary:
	var card := Ink.panel("PanelCard")
	card.custom_minimum_size = Vector2(236, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_on_enemy_clicked(i))
	var pad := Ink.margin(8)
	card.add_child(pad)
	var hrow := Ink.hbox(8)
	pad.add_child(hrow)

	var info := Ink.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := Ink.label(e.display_name, "Subheading")
	info.add_child(name)
	var hp := StatBar.new()
	info.add_child(hp)
	var intent := Ink.label("", "", Palette.VERMILION)
	intent.add_theme_font_size_override("font_size", 15)
	info.add_child(intent)
	hrow.add_child(info)

	var seal := SealView.new()
	seal.custom_minimum_size = Vector2(54, 54)
	seal.shape = SealView.Shape.CIRCLE
	hrow.add_child(seal)
	return {"card": card, "seal": seal, "hp": hp, "intent": intent}


# ---------------------------------------------------------------- 左侧：鲸鱼气泡 + 路径 + 资源
func _build_left() -> Control:
	var col := Ink.vbox(8)
	col.custom_minimum_size.x = 330
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var top := Ink.hbox(8)
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mascot := MascotView.new()
	mascot.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(mascot)
	_bubble = SpeechBubble.new()
	_bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bubble.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_child(_bubble)
	col.add_child(top)
	_preview_glyphs = _bubble.title
	_preview_effect = _bubble.body
	_bubble.call_deferred("set_idle", _preview_hint())

	_path_bar = PathBar.new()
	col.add_child(_path_bar)

	var rp := Ink.panel("PanelInset")
	var rpad := Ink.margin(10)
	rp.add_child(rpad)
	var rcol := Ink.vbox(4)
	rpad.add_child(rcol)
	_resource_label = Ink.label("", "Muted")
	_resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rcol.add_child(_resource_label)
	_player_status = Ink.hbox(8)
	rcol.add_child(_player_status)
	_pile_label = Ink.label("", "Muted")
	_pile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rcol.add_child(_pile_label)
	col.add_child(rp)
	return col


# ---------------------------------------------------------------- 中部：字盘
func _build_center() -> Control:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_view = BoardView.new()
	_board_view.setup(battle.board)
	_board_view.commit.connect(_on_commit)
	_board_view.selection_changed.connect(_on_selection_changed)
	_board_view.tile_picked.connect(_on_tile_picked)
	_board_view.pick_cancelled.connect(_on_pick_cancelled)
	center.add_child(_board_view)
	return center


# ---------------------------------------------------------------- 右侧：战报
func _build_log_panel() -> Control:
	var panel := Ink.panel("PanelCard")
	panel.custom_minimum_size = Vector2(206, 0)
	var pad := Ink.margin(8)
	panel.add_child(pad)
	var col := Ink.vbox(6)
	pad.add_child(col)
	col.add_child(Ink.h2("战报"))
	col.add_child(Ink.hline())
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_log_scroll)
	_log_box = Ink.vbox(4)
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_box)
	return panel


# ---------------------------------------------------------------- 底部：操作行
func _build_bottombar() -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(6)
	panel.add_child(pad)
	var row := Ink.hbox(8)
	pad.add_child(row)
	row.add_child(Ink.label("拖动连词　·　回车确认　·　ESC 取消", "Muted"))
	row.add_child(Ink.expander())

	_confirm_btn = Ink.button("出字", true)
	_confirm_btn.custom_minimum_size = Vector2(96, 42)
	_confirm_btn.disabled = true
	_confirm_btn.pressed.connect(func(): _on_commit(_board_view.path.duplicate()))
	row.add_child(_confirm_btn)

	var clear := Ink.button("清除")
	clear.custom_minimum_size = Vector2(72, 42)
	clear.pressed.connect(func(): _board_view.clear_selection())
	row.add_child(clear)

	var deck := Ink.button("字袋")
	deck.custom_minimum_size = Vector2(76, 42)
	deck.theme_type_variation = "GhostButton"
	deck.pressed.connect(_open_deck)
	row.add_child(deck)

	var set_btn := Ink.button("设置")
	set_btn.custom_minimum_size = Vector2(76, 42)
	set_btn.theme_type_variation = "GhostButton"
	set_btn.pressed.connect(_open_settings)
	row.add_child(set_btn)

	var end := Ink.button("结束回合")
	end.custom_minimum_size = Vector2(110, 42)
	end.pressed.connect(_on_end_turn)
	row.add_child(end)

	var menu := Ink.button("菜单")
	menu.custom_minimum_size = Vector2(76, 42)
	menu.theme_type_variation = "GhostButton"
	menu.pressed.connect(func(): PauseMenu.open())
	row.add_child(menu)
	return panel


# ---------------------------------------------------------------- 刷新
func _refresh_all() -> void:
	_refresh_enemies()
	_refresh_player()
	_refresh_piles()
	_turn_label.text = "回合 %d" % battle.turn
	_board_view.rebuild()


func _refresh_enemies() -> void:
	for w in _enemy_widgets:
		w["card"].queue_free()
	_enemy_widgets.clear()
	for i in battle.enemies.size():
		var e: Combatant = battle.enemies[i]
		var w := _make_enemy_card(i, e)
		_enemy_row.add_child(w["card"])
		_enemy_widgets.append(w)
	_refresh_intents()


func _refresh_intents() -> void:
	for i in battle.enemies.size():
		var e: Combatant = battle.enemies[i]
		var w: Dictionary = _enemy_widgets[i]
		var ed: EnemyData = e.enemy_data
		w["seal"].setup(ed.glyph if ed != null else "敌", ed.accent if ed != null else Palette.VERMILION, SealView.Shape.CIRCLE)
		w["hp"].setup_bar(e.hp, e.max_hp, Palette.HP)
		if e.is_alive():
			var mv: EnemyMoveData = battle.current_intent(e)
			w["intent"].text = ("⟶ " + mv.intent_text()) if mv != null else ""
		else:
			w["intent"].text = "（已倒下）"
		w["card"].modulate = Color(0.5, 0.48, 0.46, 0.75) if not e.is_alive() else Color.WHITE
		var targeted := i == _target_index and battle.alive_enemies().size() > 1
		w["card"].modulate = Color(1.0, 0.85, 0.6) if targeted else w["card"].modulate


func _refresh_player() -> void:
	_player_hp.setup_bar(battle.player.hp, battle.player.max_hp, Palette.HP)
	var block_txt := ""
	if battle.player.block > 0:
		block_txt += "临挡 %d　" % battle.player.block
	if battle.player.persistent_block > 0:
		block_txt += "持久盾 %d" % battle.player.persistent_block
	_player_block.text = block_txt
	var res: Array = []
	res.append("储能 %d" % battle.player.energy)
	res.append("热度 %d/%d" % [battle.player.heat, battle.player.heat_capacity])
	if battle.player.temp_funds > 0:
		res.append("临时资金 %d" % battle.player.temp_funds)
	if battle.player.equity > 0:
		res.append("股权 %d" % battle.player.equity)
	if battle.player.block > 0:
		res.append("临挡 %d" % battle.player.block)
	if battle.player.persistent_block > 0:
		res.append("持久盾 %d" % battle.player.persistent_block)
	res.append("金币 %d" % GameState.gold)
	_resource_label.text = "　".join(res)

	for c in _player_status.get_children():
		c.queue_free()
	if battle.player.statuses.is_empty() and GameState.permanent_damage_reduction <= 0:
		_player_status.add_child(Ink.label("（无状态）", "Muted"))
	for sid in battle.player.statuses.keys():
		var sd: StatusData = Database.get_status(sid)
		var txt: String = ("%s %s %d" % [sd.glyph, sd.name, battle.player.statuses[sid]]) if sd != null else ("%s %d" % [sid, battle.player.statuses[sid]])
		_player_status.add_child(Ink.label(txt))
	if GameState.permanent_damage_reduction > 0:
		_player_status.add_child(Ink.label("永久减伤 %d" % GameState.permanent_damage_reduction, "Muted"))


func _refresh_piles() -> void:
	if _pile_label == null:
		return
	_pile_label.text = "字袋 %d　·　弃字堆 %d　·　盘面 %d　·　本战金币 +%d" % [
		battle.bag.size(), battle.discard.size(), battle.board.fill_count(), battle.gold_earned]


func _on_log(text: String) -> void:
	if _log_box == null:
		return
	var l := Ink.label(text, "Muted")
	l.add_theme_font_size_override("font_size", 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_box.add_child(l)
	if _log_box.get_child_count() > 80:
		var first := _log_box.get_child(0)
		_log_box.remove_child(first)
		first.queue_free()
	await get_tree().process_frame
	if _log_scroll:
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


# ---------------------------------------------------------------- 预览（走气泡框）
func _on_selection_changed(path: Array, glyphs: Array, word: WordData) -> void:
	_path_bar.update(glyphs)
	if glyphs.is_empty():
		_current_word = null
		_bubble.set_idle(_preview_hint())
		_confirm_btn.disabled = true
		return
	_current_word = word
	var text := ""
	for g in glyphs:
		text += str(g)
	_confirm_btn.disabled = false
	if word != null and not Settings.drag_release_play:
		_pop_confirm()

	var costs := _pollution_cost_text(path)
	if word == null:
		if glyphs.size() >= 2:
			_bubble.set_text("「%s」" % text, "不成词。%s" % costs, SpeechBubble.State.ERROR)
		else:
			var cd: CharacterData = null
			var inst: CharInstance = battle.board.get_xy(path[0])
			if inst != null:
				cd = inst.data
			_bubble.set_text("「%s」" % text, "单字：%s%s" % [(cd.description if cd != null else ""), costs], SpeechBubble.State.PREVIEW)
		return
	if not word.implemented:
		_bubble.set_text("《%s》" % word.word, "效果待定。%s" % costs, SpeechBubble.State.PREVIEW)
		return
	var parts: Array = []
	for eff in word.effects:
		parts.append(eff.describe())
	var req := ""
	if word.requires_target != EffectData.Target.NONE:
		req = "　→ 需选目标"
	var body_text: String = " / ".join(parts) if not parts.is_empty() else word.effect_summary
	_bubble.set_text("《%s》" % word.word, "%s%s%s" % [body_text, req, costs], SpeechBubble.State.PREVIEW)


func _pollution_cost_text(path: Array) -> String:
	var names: Array = []
	for pos in path:
		var inst: CharInstance = battle.board.get_xy(pos)
		if inst == null:
			continue
		for pid in inst.pollutions:
			var pd: PollutionData = Database.get_pollution(pid)
			if pd != null and not names.has(pd.name):
				names.append(pd.name)
	if names.is_empty():
		return ""
	return "　⚠ 污染：" + "、".join(names)


# ---------------------------------------------------------------- 交互
func _on_enemy_clicked(index: int) -> void:
	_target_index = index
	_refresh_intents()


func _show_invalid_reaction() -> void:
	if _reaction != null:
		_reaction.show_invalid()


func _on_commit(path: Array, target: Dictionary = {}) -> void:
	if _finished:
		return
	if _board_view.pick_mode != "":
		return
	if target.is_empty() and _current_word != null and not _current_word.interaction.is_empty():
		match _current_word.interaction:
			"reveal_pick_board":
				_run_transform(path)
				return
			"choose_glyph_empower":
				_open_glyph_picker(path, "empower_glyph", GameState.glyph_counts(), "强化：选择一个字（本场额外触发单字效果）")
				return
			"choose_battle_card_remove":
				_open_glyph_picker(path, "remove_glyph", battle.battle_card_counts(), "炼化：选择一张牌移出本场战斗")
				return
			"choose_fuse_pair":
				_run_pair(path, "fuse")
				return
			"choose_same_pair":
				_run_pair(path, "same")
				return
			"choose_glyph_gild":
				_open_glyph_picker(path, "gild_glyph", GameState.glyph_counts(), "精金：选择要永久镀金的字")
				return
			"choose_discard_place":
				_open_discard_place(path)
				return
			"choose_line":
				_run_line_pick(path)
				return
			"choose_merge_flow":
				_run_merge_flow(path)
				return
	var result := battle.try_play(path, target)
	if not result.ok:
		if int(result.need_target) >= 0:
			_pending_path = path
			_request_target(int(result.need_target))
			return
		_board_view.flash_invalid()
		var glyphs: Array = result.get("glyphs", [])
		if glyphs.size() >= 2 and result.get("word") == null:
			# 无效词：弹 0.6s 反应
			_show_invalid_reaction()
		_on_log("✗ " + str(result.reason))
		_bubble.set_error(str(result.reason))
		return
	_board_view.clear_selection()
	_refresh_all()
	_bubble.set_result(result.word, result.glyphs, result.messages)
	if result.word != null:
		_on_log("成词：%s" % result.word.word)
		_float_at_enemy("《%s》" % result.word.word, Palette.VERMILION_DK)
	else:
		_float_at_enemy("打出「%s」" % (result.glyphs[0] if not result.glyphs.is_empty() else ""), Palette.INK_SOFT)
	if result.zero_effect:
		_on_log("（该字/词没有效果，仅消耗）")
	if battle.blackout_requested:
		battle.blackout_requested = false
		_show_blackout()
	if battle.end_turn_requested:
		battle.end_turn_requested = false
		_on_end_turn()
		return
	_check_battle_over()


func _show_blackout() -> void:
	var ov := BlackoutOverlay.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.restored.connect(func(): _on_log("来电了。"))
	add_child(ov)


func _request_target(target_kind: int) -> void:
	_on_log("请选择目标")
	match target_kind:
		EffectData.Target.BOARD_2X2:
			_board_view.begin_pick("2x2")
		EffectData.Target.EMPTY_TILE:
			_board_view.begin_pick("empty")
		EffectData.Target.ENEMY_GLYPH:
			_board_view.begin_pick("enemy")
		EffectData.Target.BOARD_TILE:
			_board_view.begin_pick("any")
		EffectData.Target.DISCARD_GLYPH:
			_choose_discard()


func _on_tile_picked(pos: Vector2i) -> void:
	if _merge_active:
		if _merge_cell1 == Vector2i(-1, -1):
			_merge_cell1 = pos
			_board_view.begin_pick("empty")
			_on_log("合流：选择第二个相邻空格")
			return
		if not battle.board.is_adjacent(_merge_cell1, pos):
			_board_view.begin_pick("empty")
			_on_log("合流：第二个空格必须与第一个相邻")
			return
		var mp := _pending_path
		_pending_path = []
		_merge_active = false
		_on_commit(mp, {"cell1": _merge_cell1, "cell2": pos, "merge_bag_uid": _merge_bag_uid, "merge_discard_uid": _merge_discard_uid})
		return
	if _pending_place_uid >= 0:
		var pp := _pending_path
		_pending_path = []
		var uidp := _pending_place_uid
		_pending_place_uid = -1
		_on_commit(pp, {"tile": pos, "place_uid": uidp})
		return
	if _fuse_stage == 1:
		_fuse_first = pos
		_fuse_stage = 2
		_board_view.begin_pick("own")
		_on_log("再选第二张（%s）" % ("与它相邻" if _pair_mode == "fuse" else "与它相同"))
		return
	if _fuse_stage == 2:
		var ok := false
		if _pair_mode == "fuse":
			ok = battle.board.is_adjacent(_fuse_first, pos)
		else:
			var c1: CharInstance = battle.board.get_xy(_fuse_first)
			var c2: CharInstance = battle.board.get_xy(pos)
			ok = c2 != null and pos != _fuse_first and c1 != null and c2.glyph() == c1.glyph()
		if not ok:
			_board_view.begin_pick("own")
			_on_log("选择不合法，请重选第二张")
			return
		var fp := _pending_path
		_pending_path = []
		_fuse_stage = 0
		_on_commit(fp, {"tile": _fuse_first, "tile2": pos})
		return
	var path := _pending_path
	_pending_path = []
	if path.is_empty():
		return
	var t := {"tile": pos, "enemy_glyph": pos}
	if _transform_uid >= 0:
		t["transform_uid"] = _transform_uid
		t["chosen_uid"] = _transform_uid
	_transform_uid = -1
	_on_commit(path, t)


func _run_pair(path: Array, mode: String) -> void:
	_pending_path = path
	_pair_mode = mode
	_fuse_stage = 1
	_board_view.begin_pick("own")
	_on_log("选择第一张己方牌")


func _open_discard_place(path: Array) -> void:
	var list := battle.discard_instances()
	if list.is_empty():
		_on_log("精铸：弃字堆为空")
		return
	_pending_path = path
	var options: Array = []
	for d in list:
		options.append({"text": "【%s】" % d["glyph"]})
	var overlay := ChoiceOverlay.new()
	overlay.setup({"title": "精铸：选择弃字堆中的一枚己方字", "options": options})
	overlay.chose.connect(_on_discard_place_chosen.bind(list))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_discard_place_chosen(index: int, list: Array) -> void:
	if index < 0 or index >= list.size():
		_pending_path = []
		return
	_pending_place_uid = int(list[index]["uid"])
	_board_view.begin_pick("empty")
	_on_log("精铸：选择放置的空格")


func _on_pick_cancelled() -> void:
	if not battle.pending_reveal.is_empty():
		battle.return_pending_reveal()
	_pending_path = []
	_transform_uid = -1
	_fuse_stage = 0
	_pending_place_uid = -1
	_merge_active = false
	_merge_cell1 = Vector2i(-1, -1)


func _run_line_pick(path: Array) -> void:
	_pending_path = path
	var options: Array = []
	for i in 4:
		options.append({"text": "第 %d 行" % (i + 1)})
	for i in 4:
		options.append({"text": "第 %d 列" % (i + 1)})
	var ov := ChoiceOverlay.new()
	ov.setup({"title": "反转：选择一行或一列", "options": options})
	ov.chose.connect(_on_line_chosen)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)


func _on_line_chosen(index: int) -> void:
	var p := _pending_path
	_pending_path = []
	if index < 0 or index >= 8:
		return
	var t: Dictionary = {}
	if index < 4:
		t["row"] = index
	else:
		t["col"] = index - 4
	_on_commit(p, t)


func _run_merge_flow(path: Array) -> void:
	if not battle.has_adjacent_empty_pair():
		_on_log("合流：没有两个相邻空格，跳过")
		return
	var revealed := battle.reveal_from_bag(1)
	if revealed.is_empty():
		_on_log("合流：字袋为空")
		return
	_pending_path = path
	_merge_active = true
	_merge_bag_uid = revealed[0].uid
	_merge_discard_uid = -1
	_merge_cell1 = Vector2i(-1, -1)
	var list := battle.discard_instances()
	if list.is_empty():
		_on_log("合流：弃字堆为空")
		_abort_merge()
		return
	var options: Array = []
	for d in list:
		options.append({"text": "【%s】" % d["glyph"]})
	var ov := ChoiceOverlay.new()
	ov.setup({"title": "合流：从弃字堆指定 1 枚", "options": options})
	ov.chose.connect(_on_merge_discard_chosen.bind(list))
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)


func _on_merge_discard_chosen(index: int, list: Array) -> void:
	if index < 0 or index >= list.size():
		_abort_merge()
		return
	_merge_discard_uid = int(list[index]["uid"])
	_board_view.begin_pick("empty")
	_on_log("合流：选择第一个空格")


func _abort_merge() -> void:
	if not battle.pending_reveal.is_empty():
		battle.return_pending_reveal()
	_merge_active = false
	_merge_cell1 = Vector2i(-1, -1)
	_pending_path = []


# ---------------------------------------------------------------- 转化（揭示 5 选 1 再定点改造）
func _run_transform(path: Array) -> void:
	_pending_path = path
	var revealed := battle.reveal_from_bag(5)
	if revealed.is_empty():
		_pending_path = []
		_on_log("转化：字袋为空，无法揭示")
		return
	var options: Array = []
	for inst in revealed:
		options.append({"text": "【%s】" % inst.glyph()})
	options.append({"text": "取消（把揭示的字放回）"})
	var overlay := ChoiceOverlay.new()
	overlay.setup({"title": "转化：从揭示的 %d 枚中选择 1 枚" % revealed.size(), "options": options})
	overlay.chose.connect(_on_transform_chosen)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_transform_chosen(index: int) -> void:
	if index < 0 or index >= battle.pending_reveal.size():
		battle.return_pending_reveal()
		_pending_path = []
		return
	_transform_uid = battle.pending_reveal[index].uid
	_board_view.begin_pick("any")


func _open_glyph_picker(path: Array, key: String, glyph_counts: Dictionary, title: String) -> void:
	_pending_path = path
	var chars: Array = []
	var counts: Dictionary = {}
	for g in glyph_counts.keys():
		var cd: CharacterData = Database.get_character_by_glyph(g)
		if cd == null:
			continue
		chars.append(cd)
		counts[cd.id] = glyph_counts[g]
	if chars.is_empty():
		_pending_path = []
		_on_log("没有可选的牌")
		return
	var overlay := CollectionOverlay.new()
	overlay.setup({"title": title, "characters": chars, "counts": counts, "pick_on_click": true})
	overlay.picked.connect(_on_glyph_chosen.bind(key))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_glyph_chosen(cd: CharacterData, key: String) -> void:
	var path := _pending_path
	_pending_path = []
	if path.is_empty() or cd == null:
		return
	var t: Dictionary = {}
	t[key] = cd.glyph
	_on_commit(path, t)


func _choose_discard() -> void:
	var options: Array = []
	for inst in battle.consumed_this_turn:
		options.append({"text": "【%s】" % inst.glyph()})
	if options.is_empty():
		options.append({"text": "（本回合没有消耗过的字）", "disabled": true})
	var overlay := ChoiceOverlay.new()
	overlay.setup({"title": "回收：选择本回合消耗过的一枚字", "options": options})
	overlay.chose.connect(_on_discard_chosen)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_discard_chosen(index: int) -> void:
	var path := _pending_path
	_pending_path = []
	if path.is_empty():
		return
	_on_commit(path, {"discard_index": index})


func _on_end_turn() -> void:
	if _finished:
		return
	if _board_view.pick_mode != "":
		_board_view.end_pick()
		_pending_path = []
		_transform_uid = -1
		_fuse_stage = 0
		_pending_place_uid = -1
		if not battle.pending_reveal.is_empty():
			battle.return_pending_reveal()
	_board_view.clear_selection()
	battle.end_player_turn()
	_refresh_all()
	_check_battle_over()


func _check_battle_over() -> void:
	if _finished:
		return
	if battle.is_over():
		_finished = true
		var victory := battle.is_victory()
		GameState.player_hp = battle.player.hp
		EventBus.hp_changed.emit(GameState.player_hp, GameState.player_max_hp)
		if victory:
			GameState.add_captured(battle.captured_chars)
			if battle.player.equity > 0:
				GameState.add_gold(battle.player.equity)
				_on_log("投资本金返还：+%d 金币" % battle.player.equity)
			GameState.settle_victory_economy()
		await get_tree().create_timer(0.5).timeout
		if victory:
			goto("res://src/screens/reward_screen.gd", {"node": node})
		else:
			_show_defeat()


func _show_defeat() -> void:
	var overlay := ChoiceOverlay.new()
	overlay.setup({
		"title": "力竭",
		"body": "字散墨枯，盘面归于沉寂。冒险到此为止。",
		"options": [{"text": "重新开始", "primary": true}, {"text": "返回标题"}],
	})
	overlay.chose.connect(_on_defeat_choice)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_defeat_choice(index: int) -> void:
	if index == 0:
		GameState.start_new_run("v03")
		goto("res://src/screens/map_screen.gd")
	else:
		goto("res://src/screens/title_screen.gd")


func _float_at_enemy(text: String, color: Color) -> void:
	var pos := Vector2(get_viewport_rect().size.x * 0.5, 200)
	for i in battle.enemies.size():
		if battle.enemies[i].is_alive() and i < _enemy_widgets.size():
			var card: Control = _enemy_widgets[i]["card"]
			pos = card.global_position + Vector2(card.size.x * 0.5, 10)
			break
	_float_text(text, pos, color)


func _float_text(text: String, pos: Vector2, color: Color) -> void:
	var l := Ink.label(text, "", color)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.4))
	l.position = pos
	content.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 52, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.35)
	get_tree().create_timer(0.95).timeout.connect(l.queue_free)


func _preview_hint() -> String:
	if Settings.drag_release_play:
		return "拖动连线，松手即出字；也可按「出字」或回车确认。"
	return "拖动选择后松手保留；按「出字」或回车 / 空格确认，ESC 取消。"


func _pop_confirm() -> void:
	if _confirm_btn == null or not is_instance_valid(_confirm_btn) or _confirm_btn.disabled:
		return
	_confirm_btn.pivot_offset = _confirm_btn.size * 0.5
	var tw := create_tween()
	tw.tween_property(_confirm_btn, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(_confirm_btn, "scale", Vector2.ONE, 0.12)


func _open_settings() -> void:
	var ov := SettingsOverlay.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)


func _open_deck() -> void:
	var counts := GameState.glyph_counts()
	var chars: Array = []
	for id in counts.keys():
		var cd: CharacterData = Database.get_character(id)
		if cd != null:
			chars.append(cd)
	var overlay := CollectionOverlay.new()
	overlay.setup({
		"title": "字袋",
		"subtitle": "%d 枚实体字" % GameState.deck_size(),
		"characters": chars,
		"counts": counts,
		"words": Database.words.values(),
	})
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
