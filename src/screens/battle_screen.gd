extends ScreenBase
signal presentation_step_finished
## 简洁活字 HUD + 独立表现队列。规则同步结算，动效逐次播放真实结果。
var battle: BattleState
var node: MapNodeData
var _board_view: BoardView
var _enemy_row: VBoxContainer
var _enemy_widgets: Array[EnemyView] = []
var _player_hp: StatBar
var _player_hp_caption: Label
var _player_hp_value: Label
var _menu_btn: Button
var _player_block: Label
var _player_status: Label
var _resource_label: Label
var _pile_label: Label
var _turn_label: Label
var _bubble: SpeechBubble
var _confirm_btn: Button
var _clear_btn: Button
var _end_btn: Button
var _log_box: VBoxContainer
var _log_scroll: ScrollContainer
var _log_overlay: Control
var _topbar: Control
var _player_panel: Control
var _preview_panel: Control
var _enemy_panel: ScrollContainer
var _enemy_paper: ArtPaper
var _footer: Control
var _hint: Label
var _selection_actions: HBoxContainer
var _effects: BattleEffects
var _target_index := 0
var _pending_path: Array = []
var _ready_action: Dictionary = {}   ## 待发动：已选好路径+目标，点「发动」才执行
var _recast_three_active := false    ## 再铸：正在选 3 个盘面字
var _recast_three_cells: Array = []
var _collect_own_active := false     ## 收心：正在选盘面牌回袋
var _collect_own_cells: Array = []
var _compound_picker_active := false ## 复合：正在选保留的临时字
var _current_word: WordData
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
var _busy := false
var _collecting := false
var _modal_count := 0
var _compact := false
var _events: Array[Dictionary] = []
var _feedback_watches: Array = []
var _confirm_motion: Tween
var _confirm_ink: ShaderMaterial
var _step_timer: Timer
var _exiting := false


func build(root: Control) -> void:
	_step_timer = Timer.new()
	_step_timer.one_shot = true
	_step_timer.timeout.connect(func(): presentation_step_finished.emit())
	add_child(_step_timer)
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
	battle.start(GameState.make_battle_deck(), enemy_datas, int(params.get("seed", -1)))
	_topbar = _build_topbar()
	root.add_child(_topbar)
	root.move_child(_player_panel, root.get_child_count() - 1)
	_preview_panel = _build_left()
	root.add_child(_preview_panel)
	_board_view = _build_center()
	root.add_child(_board_view)
	_enemy_panel = ScrollContainer.new()
	_enemy_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_enemy_row = Ink.vbox(16)
	_enemy_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_panel.add_child(_enemy_row)
	_enemy_paper = ArtPaper.new()
	_enemy_paper.tilt = 1.2
	root.add_child(_enemy_paper)
	root.add_child(_enemy_panel)
	root.move_child(_player_panel, _enemy_panel.get_index())
	_footer = _build_bottombar()
	root.add_child(_footer)
	_end_btn = Ink.button("结束回合")
	_end_btn.add_theme_font_size_override("font_size", 22)
	var end_style := StyleBoxFlat.new()
	end_style.bg_color = Palette.PANEL_DARK
	end_style.border_color = Palette.GOLD_DK
	end_style.set_border_width_all(1)
	end_style.set_corner_radius_all(4)
	end_style.set_content_margin_all(10)
	_end_btn.add_theme_stylebox_override("normal", end_style)
	_end_btn.add_theme_color_override("font_color", Palette.PAPER_WARM)
	_end_btn.pressed.connect(_on_end_turn)
	root.add_child(_end_btn)
	_log_overlay = _build_log_panel()
	root.add_child(_log_overlay)
	_log_overlay.hide()
	_effects = BattleEffects.new()
	root.add_child(_effects)
	EventBus.log_message.connect(_on_log)
	battle.enemy_acting.connect(_on_enemy_acting)
	_watch_combatant(battle.player)
	_refresh_all()
	for line in battle.log:
		_on_log(line)
	_bubble.set_idle(_preview_hint())
	resized.connect(_layout)
	_layout()
	_bind_table_print.call_deferred()
	_board_view.call_deferred("play_opening")
	_on_log("战斗开始：%s" % node.title)


func _exit_tree() -> void:
	_exiting = true
	_step_timer.stop()
	presentation_step_finished.emit()
	if EventBus.log_message.is_connected(_on_log):
		EventBus.log_message.disconnect(_on_log)
	for watch in _feedback_watches:
		if is_instance_valid(watch[0]) and watch[0].feedback.is_connected(watch[1]):
			watch[0].feedback.disconnect(watch[1])
	_feedback_watches.clear()
	_events.clear()


func _bind_table_print() -> void:
	if not is_instance_valid(Router.study_stage) or not Router.study_stage.shared_table_active():
		return
	var lighting := ShaderMaterial.new()
	lighting.shader = load("res://src/shaders/table_print.gdshader")
	lighting.set_shader_parameter("table_scene", Router.study_stage.viewport.get_texture())
	for panel in [_preview_panel, _enemy_panel]:
		_shade_print_nodes(panel, lighting)


func _shade_print_nodes(parent: Node, lighting: ShaderMaterial) -> void:
	if parent is Label or parent is RichTextLabel or parent is InkSpirit or parent is StatBar:
		parent.material = lighting
	for child in parent.get_children():
		_shade_print_nodes(child, lighting)


func _build_topbar() -> Control:
	var bar := Control.new()
	var surface := ArtPaper.new()
	surface.strip = true
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(surface)
	var title := Ink.label("活字战斗", "Heading")
	title.name = "Title"
	bar.add_child(title)
	_turn_label = Ink.label("回合 1", "Stat")
	bar.add_child(_turn_label)
	_resource_label = Ink.label("", "Muted")
	_resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_resource_label)
	var rule := Ink.hline()
	rule.name = "Rule"
	bar.add_child(rule)
	_menu_btn = Ink.button("菜单")
	_menu_btn.custom_minimum_size = Vector2(80, 48)
	_menu_btn.pressed.connect(_open_menu)
	bar.add_child(_menu_btn)
	_player_panel = Control.new()
	_player_hp_caption = Ink.label("玩家气血", "", Palette.INK)
	_player_hp_caption.add_theme_font_override("font", Ink.serif)
	_player_hp_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_player_panel.add_child(_player_hp_caption)
	_player_hp_value = Ink.label("", "", Palette.VERMILION_DK)
	_player_hp_value.add_theme_font_override("font", Ink.serif)
	_player_hp_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_player_panel.add_child(_player_hp_value)
	_player_hp = StatBar.new()
	_player_hp.show_text = false
	_player_panel.add_child(_player_hp)
	_player_block = Ink.label("", "Muted")
	_player_panel.add_child(_player_block)
	_player_status = Ink.caption("")
	_player_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_player_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_player_panel.add_child(_player_status)
	content.add_child(_player_panel)
	return bar


func _make_enemy_card(i: int, e: Combatant) -> EnemyView:
	var view := EnemyView.new()
	view.setup(i, e)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.clicked.connect(_on_enemy_clicked)
	_watch_combatant(e)
	return view


func _build_left() -> Control:
	var col := Control.new()
	var surface := ArtPaper.new()
	surface.tilt = -1.6
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_child(surface)
	_bubble = SpeechBubble.new()
	col.add_child(_bubble)
	_selection_actions = Ink.hbox(12)
	_confirm_btn = Ink.button("出字", true)
	_confirm_btn.custom_minimum_size = Vector2(128, 56)
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.add_theme_font_size_override("font_size", 28)
	_confirm_btn.disabled = true
	_confirm_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_confirm_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	_confirm_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_confirm_btn.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	var stamp := ColorRect.new()
	stamp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.show_behind_parent = true
	_confirm_ink = ShaderMaterial.new()
	_confirm_ink.shader = load("res://src/shaders/seal_button.gdshader")
	_confirm_ink.set_shader_parameter("seal_color", Palette.VERMILION)
	stamp.material = _confirm_ink
	_confirm_btn.add_child(stamp)
	_confirm_btn.mouse_entered.connect(func(): _confirm_ink.set_shader_parameter("hovered", true))
	_confirm_btn.mouse_exited.connect(func(): _confirm_ink.set_shader_parameter("hovered", false))
	_confirm_btn.button_down.connect(func(): _confirm_ink.set_shader_parameter("pressed", true))
	_confirm_btn.button_up.connect(func(): _confirm_ink.set_shader_parameter("pressed", false))
	_confirm_btn.pressed.connect(_on_primary)
	_selection_actions.add_child(_confirm_btn)
	_clear_btn = Ink.button("清除")
	var clear_style := StyleBoxFlat.new()
	clear_style.bg_color = Color(0, 0, 0, 0)
	clear_style.border_color = Color(Palette.INK_SOFT, 0.65)
	clear_style.set_border_width_all(1)
	clear_style.set_content_margin_all(10)
	_clear_btn.add_theme_stylebox_override("normal", clear_style)
	_clear_btn.add_theme_stylebox_override("disabled", clear_style)
	_clear_btn.custom_minimum_size = Vector2(72, 56)
	_clear_btn.pressed.connect(_on_clear_cancel)
	_selection_actions.add_child(_clear_btn)
	col.add_child(_selection_actions)
	return col


func _build_center() -> BoardView:
	var view := BoardView.new()
	view.setup(battle.board)
	view.commit.connect(_on_commit)
	view.selection_changed.connect(_on_selection_changed)
	view.tile_picked.connect(_on_tile_picked)
	view.pick_cancelled.connect(_on_pick_cancelled)
	return view


func _build_log_panel() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_toggle_log())
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := Ink.panel()
	panel.custom_minimum_size = Vector2(600, 420)
	center.add_child(panel)
	var col := Ink.vbox(12)
	panel.add_child(col)
	var head := Ink.hbox(10)
	head.add_child(Ink.h2("战报"))
	head.add_child(Ink.expander())
	var close := Ink.button("关闭")
	close.pressed.connect(_toggle_log)
	head.add_child(close)
	col.add_child(head)
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_log_scroll)
	_log_box = Ink.vbox(6)
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_scroll.add_child(_log_box)
	return overlay


func _build_bottombar() -> Control:
	var bar := Control.new()
	var surface := ArtPaper.new()
	surface.strip = true
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(surface)
	var line := Ink.hline()
	line.name = "Rule"
	bar.add_child(line)
	_hint = Ink.label("拖动连词 · 回车出字 · ESC 取消", "Muted")
	bar.add_child(_hint)
	_pile_label = Ink.label("", "Muted")
	bar.add_child(_pile_label)
	return bar


func _refresh_all(animate_board := false) -> void:
	_refresh_enemies()
	_refresh_player()
	_refresh_piles()
	_turn_label.text = "回合 %d" % battle.turn
	_board_view.rebuild(animate_board)
	_update_input()


func _refresh_enemies() -> void:
	if _enemy_widgets.size() != battle.enemies.size():
		for widget in _enemy_widgets:
			_enemy_row.remove_child(widget)
			widget.queue_free()
		_enemy_widgets.clear()
		for i in battle.enemies.size():
			var widget := _make_enemy_card(i, battle.enemies[i])
			_enemy_row.add_child(widget)
			_enemy_widgets.append(widget)
	for widget in _enemy_widgets:
		widget.refresh()
	_refresh_intents()
	if is_node_ready() or _end_btn != null:
		_layout()


func _refresh_intents() -> void:
	if _target_index >= battle.enemies.size() or not battle.enemies[_target_index].is_alive():
		var first := battle.first_alive_enemy()
		_target_index = battle.enemies.find(first) if first != null else 0
	for i in _enemy_widgets.size():
		_enemy_widgets[i].set_intent(battle.current_intent(battle.enemies[i]))
		_enemy_widgets[i].set_targeted(i == _target_index)


func _refresh_player() -> void:
	_show_player_hp(battle.player.hp, battle.player.max_hp)
	_player_block.text = "临挡 %d · 持久盾 %d" % [battle.player.block, battle.player.persistent_block]
	var resources: Array[String] = ["热度 %d / %d" % [battle.player.heat, battle.player.heat_capacity], "储能 %d" % battle.player.energy, "金币 %d" % GameState.gold]
	if battle.player.temp_funds > 0:
		resources.append("资金 %d" % battle.player.temp_funds)
	if battle.player.equity > 0:
		resources.append("股权 %d" % battle.player.equity)
	_resource_label.text = "    ".join(resources)
	var states: Array[String] = []
	for sid in battle.player.statuses:
		var sd: StatusData = Database.get_status(sid)
		states.append("%s %d" % [sd.name if sd != null else sid, battle.player.statuses[sid]])
	if GameState.permanent_damage_reduction > 0:
		states.append("减伤 %d" % GameState.permanent_damage_reduction)
	_player_status.text = " · ".join(states)
	_player_status.tooltip_text = _player_status.text


func _show_player_hp(hp: int, max_hp: int) -> void:
	_player_hp.setup_bar(hp, max_hp, Palette.HP)
	_player_hp_value.text = "%d / %d" % [hp, max_hp]


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
	if is_inside_tree() and is_instance_valid(_log_scroll):
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


# ---------------------------------------------------------------- 独立词效预览
func _on_selection_changed(path: Array, glyphs: Array, word: WordData) -> void:
	if glyphs.is_empty():
		_current_word = null
		_bubble.set_idle(_preview_hint())
		_update_input()
		return
	var word_changed := _current_word != word
	_current_word = word
	var text := ""
	for g in glyphs:
		text += str(g)
	_update_input()
	_bubble.set_context(_selection_context(path))
	if word != null and word_changed and not Settings.drag_release_play:
		_pop_confirm()

	if word == null:
		if glyphs.size() >= 2:
			_bubble.set_text("「%s」" % text, "不成词。调整路径后重试，不消耗字块。", SpeechBubble.State.ERROR)
		else:
			var cd: CharacterData = null
			var inst: CharInstance = battle.board.get_xy(path[0])
			if inst != null:
				cd = inst.data
			_bubble.set_text("「%s」" % text, "单字：%s" % (cd.description if cd != null else ""), SpeechBubble.State.PREVIEW)
		return
	if not word.implemented:
		_bubble.set_text("《%s》" % word.word, "效果待定。", SpeechBubble.State.PREVIEW)
		return
	var parts: Array = []
	for eff in word.effects:
		parts.append(eff.describe().replace("；", "\n"))
	var req := ""
	if word.requires_target != EffectData.Target.NONE:
		req = "　→ 需选目标"
	var body_text: String = "\n".join(parts) if not parts.is_empty() else word.effect_summary
	_bubble.set_text("《%s》" % word.word, "%s%s" % [body_text, req], SpeechBubble.State.PREVIEW)


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
	if _busy or _finished or _modal_count > 0 or not battle.enemies[index].is_alive():
		return
	_target_index = index
	_refresh_intents()
	_bubble.set_context(_selection_context(_board_view.path))


func _on_primary() -> void:
	if _finished or _busy:
		return
	if _collect_own_active:
		var cp := _pending_path
		_collect_own_active = false
		var cells := _collect_own_cells.duplicate()
		_collect_own_cells = []
		_board_view.end_pick()
		_on_commit(cp, {"cells": cells})
		return
	if not _ready_action.is_empty():
		var a := _ready_action
		_ready_action = {}
		_board_view.end_pick()
		_on_commit(a.path, a.target)
		return
	if _board_view.pick_mode != "":
		return
	# 合击·结阵：点「发动」时才把登记的词一起结算
	if battle.formation_mode and not battle.formation_queue.is_empty():
		battle.resolve_formation()
		_board_view.clear_selection()
		_refresh_all()
		if _handle_effect_requests():
			return
		_check_battle_over()
		return
	_on_commit(_board_view.path.duplicate())


## 选好路径+目标后进入「待发动」：不立即结算，可继续点别处改选，或点「发动」执行。
func _fill_ready(path: Array, target: Dictionary) -> void:
	_pending_path = []
	_ready_action = {"path": path, "target": target}
	_update_input()


func _on_clear_cancel() -> void:
	if _collect_own_active or _recast_three_active or not _ready_action.is_empty() or _board_view.pick_mode != "":
		_on_pick_cancelled()
		_board_view.end_pick()
		_update_input()
		return
	_board_view.clear_selection()


func _on_commit(path: Array, target: Dictionary = {}) -> void:
	if _finished or _compound_picker_active or _busy or (_modal_count > 0 and target.is_empty()):
		return
	if _board_view.pick_mode != "" and _ready_action.is_empty():
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
			"choose_three_tiles":
				_run_recast_three(path)
				return
			"choose_own_tiles":
				_run_collect_own(path)
				return
	if _choose_compound_copy(path, target):
		return
	var play_target := target.duplicate()
	var glyphs_before := battle.board.glyphs_of(path)
	var word_before: WordData = Database.get_word_by_glyphs(glyphs_before) if glyphs_before.size() >= 2 else null
	var needs_target := word_before != null and word_before.requires_target != EffectData.Target.NONE
	if glyphs_before.size() == 1 and not path.is_empty():
		var inst: CharInstance = battle.board.get_xy(path[0])
		needs_target = inst != null and inst.data != null and battle._solo_requires_target(inst.data) != EffectData.Target.NONE
	if not play_target.is_empty() or not needs_target:
		# 规则层索引针对存活列表；HUD 索引针对固定敌人列表。
		play_target["target_index"] = battle.alive_enemies().find(battle.enemies[_target_index]) if not battle.enemies.is_empty() else 0
	var old_resources := [battle.player.energy, battle.player.heat, GameState.gold]
	_events.clear()
	_collecting = true
	var result := battle.try_play(path, play_target)
	_collecting = false
	if not result.ok:
		if int(result.need_target) >= 0:
			_pending_path = path
			_request_target(int(result.need_target))
			return
		_board_view.flash_invalid()
		_on_log("✗ " + str(result.reason))
		_bubble.set_error(str(result.reason))
		return
	# 合击·结阵：本词只登记，不结算（点「发动」后一起结算）
	if result.get("queued", false):
		_ready_action = {}
		_board_view.end_pick()
		_board_view.clear_selection()
		_refresh_all(true)
		var queued_text := ""
		for g in result.glyphs:
			queued_text += str(g)
		_bubble.set_text("结阵登记：《%s》" % queued_text, "点「发动」与本回合其他词一起结算。", SpeechBubble.State.PREVIEW)
		return
	_set_busy(true)
	_ready_action = {}
	_board_view.end_pick()
	_board_view.release_selected(path)
	# 停息/停电等即时请求：在演出前即刻结算，保证逻辑与输入时机、动画开关无关
	if _handle_effect_requests():
		return
	if not await _wait_step(0.11 if not Settings.reduced_motion else 0.01):
		return
	var aim: Control = _player_panel
	for event in _events:
		if event.kind == "damage" or (event.kind == "shield" and int(event.get("gain", 0)) < 0):
			aim = _view_for(event.target)
			break
	var launch := Vector2.ZERO
	for cell in path:
		launch += _effects.point_of(_board_view.tiles[_board_view.board.from_xy(cell)])
	launch /= maxf(1.0, path.size())
	_effects.fly_word("".join(result.glyphs), launch, _effects.point_of(aim))
	if not await _wait_step(0.20 if not Settings.reduced_motion else 0.01):
		return
	if not await _replay_feedback():
		return
	_board_view.clear_selection()
	_refresh_all(true)
	_bubble.set_result(result.word, result.glyphs, result.messages)
	_bubble.set_context(_selection_context([]))
	_resource_feedback(old_resources)
	if result.word != null:
		_on_log("成词：%s" % result.word.word)
	_set_busy(false)

	if result.zero_effect:
		_on_log("（该字/词没有效果，仅消耗）")
	if _handle_effect_requests():
		return
	_check_battle_over()


## 处理「停息/停电」等需要立即结算的请求。返回 true 表示应中断后续演出/检查。
func _handle_effect_requests() -> bool:
	if battle.blackout_requested:
		battle.blackout_requested = false
		_show_blackout()
	if battle.end_turn_requested:
		battle.end_turn_requested = false
		_on_end_turn()
		return true
	return false


func _show_blackout() -> void:
	var ov := BlackoutOverlay.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.restored.connect(func(): _on_log("来电了。"))
	_mount_overlay(ov)


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
	if _collect_own_active:
		if battle.board.get_xy(pos) == null:
			return
		if _collect_own_cells.has(pos):
			_collect_own_cells.erase(pos)   # 再点已选格 = 取消该格
		else:
			_collect_own_cells.append(pos)
		_on_log("收心：已选 %d 枚（再点可取消），点「发动」结束" % _collect_own_cells.size())
		_update_input()
		return
	if _recast_three_active:
		var rc: CharInstance = battle.board.get_xy(pos)
		if rc == null:
			_on_log("再铸：请选有字的格子（%d/3）" % _recast_three_cells.size())
			return
		if _recast_three_cells.has(pos):
			_recast_three_cells.erase(pos)   # 再点已选格 = 取消该格
			_on_log("再铸：已选 %d/3" % _recast_three_cells.size())
			return
		_recast_three_cells.append(pos)
		if _recast_three_cells.size() >= 3:
			var rp := _pending_path
			_recast_three_active = false
			var cells := _recast_three_cells.duplicate()
			_recast_three_cells = []
			_board_view.end_pick()
			_fill_ready(rp, {"cells": cells})
		else:
			_on_log("再铸：已选 %d/3（再点可取消）" % _recast_three_cells.size())
			_update_input()
		return
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
		_fill_ready(mp, {"cell1": _merge_cell1, "cell2": pos, "merge_bag_uid": _merge_bag_uid, "merge_discard_uid": _merge_discard_uid})
		return
	if _pending_place_uid >= 0:
		var pp := _pending_path
		_pending_path = []
		var uidp := _pending_place_uid
		_pending_place_uid = -1
		_fill_ready(pp, {"tile": pos, "place_uid": uidp})
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
		_fill_ready(fp, {"tile": _fuse_first, "tile2": pos})
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
	_fill_ready(path, t)


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
	_mount_overlay(overlay)


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
	_ready_action = {}
	_recast_three_active = false
	_recast_three_cells = []
	_collect_own_active = false
	_collect_own_cells = []


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
	_mount_overlay(ov)


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


## 复合（next_compound）：让玩家选定要保留为临时字的盘面字，选定前不结算。
func _choose_compound_copy(path: Array, target: Dictionary) -> bool:
	if target.has("compound_uid") or not battle.has_ability("next_compound") or not battle.board.valid_path(path):
		return false
	var word := Database.get_word_by_glyphs(battle.board.glyphs_of(path))
	if word == null or word.length() < 3:
		return false
	var cards: Array = []
	var options: Array = []
	for pos in path:
		var inst: CharInstance = battle.board.get_xy(pos)
		if inst != null and not inst.pinned and inst.temporary_uses == 0:
			cards.append(inst)
			options.append({"text": "保留【%s】" % "".join(inst.glyph_list())})
	if cards.is_empty():
		return false
	_compound_picker_active = true
	var overlay := ChoiceOverlay.new()
	overlay.setup({"title": "复合：选择保留的临时字", "options": options})
	overlay.chose.connect(func(index):
		_compound_picker_active = false
		if index >= 0 and index < cards.size():
			var chosen := target.duplicate()
			chosen["compound_uid"] = cards[index].uid
			_on_commit(path, chosen))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mount_overlay(overlay)
	return true


func _run_recast_three(path: Array) -> void:
	_pending_path = path
	_recast_three_active = true
	_recast_three_cells = []
	_board_view.begin_pick("any", true)
	_on_log("再铸：选择 3 个盘面字（再点可取消）")
	_update_input()


func _run_collect_own(path: Array) -> void:
	_pending_path = path
	_collect_own_active = true
	_collect_own_cells = []
	_board_view.begin_pick("any", true)
	_on_log("收心：点选盘面字放回字袋（可 0 张，再点取消），点「发动」结束")
	_update_input()


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
	_mount_overlay(ov)


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
	_mount_overlay(overlay)


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
	_mount_overlay(overlay)


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
	_mount_overlay(overlay)


func _on_discard_chosen(index: int) -> void:
	var path := _pending_path
	_pending_path = []
	if path.is_empty():
		return
	_on_commit(path, {"discard_index": index})


func _on_end_turn() -> void:
	if _finished or _busy or _modal_count > 0:
		return
	if _board_view.pick_mode != "":
		_board_view.end_pick()
		_on_pick_cancelled()
	_board_view.clear_selection()
	_set_busy(true)
	_events.clear()
	_collecting = true
	battle.end_player_turn()
	_collecting = false
	if not await _replay_feedback():
		return
	_refresh_all(true)
	if not battle.is_over():
		_bubble.set_text("你的回合", "新字已落盘，继续连词。", SpeechBubble.State.IDLE)
		_bubble.set_context(_selection_context([]))
		_effects.number("回合 %d" % battle.turn, _effects.point_of(_board_view), Palette.INK_SOFT)
	_set_busy(false)
	_check_battle_over()


func _check_battle_over() -> void:
	if _finished:
		return
	if battle.is_over():
		_finished = true
		_update_input()
		var victory := battle.is_victory()
		GameState.player_hp = battle.player.hp
		EventBus.hp_changed.emit(GameState.player_hp, GameState.player_max_hp)
		if victory:
			GameState.add_captured(battle.captured_chars)
			if battle.player.equity > 0:
				GameState.add_gold(battle.player.equity)
				_on_log("投资本金返还：+%d 金币" % battle.player.equity)
			GameState.settle_victory_economy()
		if not await _wait_step(0.35):
			return
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
	_mount_overlay(overlay)


func _on_defeat_choice(index: int) -> void:
	if index == 0:
		GameState.start_new_run("v03")
		goto("res://src/screens/map_screen.gd")
	else:
		goto("res://src/screens/title_screen.gd")


func _preview_hint() -> String:
	if Settings.drag_release_play:
		return "拖动连线，松手即出字；也可按「出字」或回车确认。"
	return "拖动选择后松手保留；按「出字」或回车 / 空格确认，ESC 取消。"


func _pop_confirm() -> void:
	if _confirm_btn == null or _confirm_btn.disabled or Settings.reduced_motion:
		return
	if _confirm_motion != null:
		_confirm_motion.kill()
	_confirm_btn.pivot_offset = _confirm_btn.size * 0.5
	_confirm_motion = create_tween()
	_confirm_motion.tween_property(_confirm_btn, "scale", Vector2(1.025, 1.025), 0.06)
	_confirm_motion.tween_property(_confirm_btn, "scale", Vector2.ONE, 0.10)


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
	_mount_overlay(overlay)

func _layout() -> void:
	if _end_btn == null or size.x < 100:
		return
	var w := size.x
	var h := size.y
	_compact = bool(params.get("touch_layout", false)) or DisplayServer.is_touchscreen_available() or w / maxf(1.0, h) >= 1.95 or w < 1100
	var ui_scale := clampf(h / maxf(1, DisplayServer.window_get_size().y), 1.0, 1.85) if _compact else 1.0
	var margin := 24.0
	var top := 88.0 if not _compact else 66.0
	var footer := maxf(70.0, 48 * ui_scale + 22)
	var side := minf(h - top - footer - 30, w * 0.44)
	var column := (w - side) * 0.5 - margin * 2
	var board_x := (w - side) * 0.5
	_topbar.position = Vector2(margin, 12)
	_topbar.size = Vector2(w - margin * 2, top - 12)
	_topbar.get_node("Title").visible = not _compact
	_topbar.get_node("Title").position = Vector2(320, 0)
	_topbar.get_node("Title").size = Vector2(150, 36)
	_turn_label.position = Vector2(320 if not _compact else 8, 36 if not _compact else 4)
	_turn_label.size = Vector2(120, 32)
	var menu_width := 80 * ui_scale
	_menu_btn.position = Vector2(_topbar.size.x - menu_width, 0)
	_menu_btn.size = Vector2(menu_width, 48 * ui_scale)
	_menu_btn.custom_minimum_size = _menu_btn.size
	_menu_btn.add_theme_font_size_override("font_size", int(minf(34, 20 * ui_scale)))
	_resource_label.position = Vector2(490 if not _compact else 160, 18 if not _compact else 4)
	_resource_label.size = Vector2(_menu_btn.position.x - _resource_label.position.x - 18, 42)
	_resource_label.add_theme_font_size_override("font_size", int(minf(24, 15 * ui_scale)))
	_topbar.get_node("Rule").position = Vector2(0, top - 14)
	_topbar.get_node("Rule").size = Vector2(w - margin * 2, 1)
	_board_view.position = Vector2(board_x, top + 12)
	_board_view.size = Vector2(side, side)
	var right_x := board_x + side + margin
	if _compact:
		_player_panel.position = Vector2(margin, top + 12)
		_player_panel.size = Vector2(column, 76 * ui_scale)
		_enemy_panel.position = Vector2(margin, top + 28 + _player_panel.size.y)
		_enemy_panel.size = Vector2(column, side - _player_panel.size.y - 48 * ui_scale - 16)
		_preview_panel.position = Vector2(right_x, top + 12)
		_preview_panel.size = Vector2(column, side)
		_end_btn.position = Vector2(margin, top + side - 48 * ui_scale + 12)
		_end_btn.size = Vector2(column, 48 * ui_scale)
	else:
		_player_panel.position = Vector2(margin + 8, 12)
		_player_panel.size = Vector2(280, 76)
		_enemy_panel.position = Vector2(right_x, top + 12)
		_enemy_panel.size = Vector2(column, side)
		_preview_panel.position = Vector2(margin, top + 46)
		_preview_panel.size = Vector2(column, side - 48)
		_end_btn.position = Vector2(w - margin - 196, h - 60)
		_end_btn.size = Vector2(196, 48)
	_player_hp_caption.position = Vector2.ZERO
	_player_hp_caption.size = Vector2(110 * ui_scale, 42 * ui_scale)
	_player_hp_caption.add_theme_font_size_override("font_size", int(minf(28, 17 * ui_scale)))
	_player_hp_value.position = Vector2(110 * ui_scale, 0)
	_player_hp_value.size = Vector2(_player_panel.size.x - 110 * ui_scale, 44 * ui_scale)
	_player_hp_value.add_theme_font_size_override("font_size", int(minf(52, 32 * ui_scale)))
	_player_hp.position = Vector2(0, 44 * ui_scale)
	_player_hp.custom_minimum_size.y = 8
	_player_hp.size = Vector2(_player_panel.size.x, 8 * ui_scale)
	_player_block.position = Vector2(0, 54 * ui_scale)
	_player_block.size = Vector2(_player_panel.size.x, 22 * ui_scale)
	_player_block.add_theme_font_size_override("font_size", int(minf(24, 14 * ui_scale)))
	_player_status.position = Vector2(0, 76 * ui_scale)
	_player_status.size = Vector2(_player_panel.size.x, 26)
	_player_status.visible = not _player_status.text.is_empty()
	var action_h := 64.0 * ui_scale if _compact else 60.0
	_bubble.set_ui_scale(ui_scale, _compact)
	var paper_pad := 22.0 if _compact else 26.0
	var paper_height := _preview_panel.size.y
	_bubble.position = Vector2(paper_pad, paper_pad)
	_bubble.size = Vector2(column - paper_pad * 2, paper_height - action_h - paper_pad * 3)
	_selection_actions.position = Vector2(paper_pad, paper_height - action_h - paper_pad)
	_selection_actions.size = Vector2(column - paper_pad * 2, action_h)
	_confirm_btn.custom_minimum_size.y = action_h
	_clear_btn.custom_minimum_size.y = action_h
	_confirm_btn.add_theme_font_size_override("font_size", int((28 if _compact else 36) * ui_scale))
	_clear_btn.add_theme_font_size_override("font_size", int(18 * ui_scale))
	_end_btn.add_theme_font_size_override("font_size", int(22 * ui_scale))
	_footer.position = Vector2(margin, h - footer + 10)
	_footer.size = Vector2(w - margin * 2, footer - 10)
	_footer.get_node("Rule").size = Vector2(w - margin * 2, 1)
	_hint.visible = not _compact
	_hint.position = Vector2(8, 6)
	_hint.size = Vector2(w - 260, 22)
	_pile_label.position = Vector2(8, 30 if not _compact else 18)
	_pile_label.size = Vector2(w - 260 if not _compact else w - 64, 24)
	_pile_label.add_theme_font_size_override("font_size", int(minf(22, 15 * ui_scale)))
	_enemy_paper.position = _enemy_panel.position - Vector2(12, 8)
	_enemy_paper.size = _enemy_panel.size + Vector2(24, 16)
	if _compact:
		_enemy_paper.position = _player_panel.position - Vector2(12, 8)
		_enemy_paper.size.y = _enemy_panel.position.y + _enemy_panel.size.y + 8 - _enemy_paper.position.y
		_enemy_paper.tilt = 0.0
		_enemy_paper._place_sheet()
	else:
		_enemy_paper.tilt = 1.2
		_enemy_paper._place_sheet()
	_enemy_panel.position += Vector2(14, 8 if _compact else 16)
	_enemy_panel.size -= Vector2(28, 16 if _compact else 32)
	for widget in _enemy_widgets:
		widget.ui_scale = ui_scale
		widget.set_compact(_compact or _enemy_widgets.size() > 1)
		widget.custom_minimum_size.y = 118 * ui_scale if _compact or _enemy_widgets.size() > 1 else _enemy_panel.size.y
	_board_view._layout()


func _update_input() -> void:
	var locked := _busy or _finished or _modal_count > 0
	_board_view.set_interactable(not locked, false)
	if _collect_own_active:
		_confirm_btn.text = "发动（收心 %d）" % _collect_own_cells.size()
		_confirm_btn.disabled = locked
	elif not _ready_action.is_empty():
		_confirm_btn.text = "发动"
		_confirm_btn.disabled = locked
	elif _board_view.pick_mode != "":
		_confirm_btn.text = "发动"
		_confirm_btn.disabled = true
	else:
		_confirm_btn.text = "出字"
		_confirm_btn.disabled = locked or _board_view.path.is_empty()
	if _confirm_ink != null:
		_confirm_ink.set_shader_parameter("disabled", _confirm_btn.disabled)
	_clear_btn.disabled = locked or (_board_view.path.is_empty() and _ready_action.is_empty() and not _recast_three_active and not _collect_own_active and _board_view.pick_mode == "")
	_end_btn.disabled = locked
	_menu_btn.disabled = locked


func _set_busy(value: bool) -> void:
	_busy = value
	_update_input()


func _mount_overlay(overlay: Control) -> void:
	_modal_count += 1
	_update_input()
	overlay.tree_exited.connect(func():
		_modal_count = maxi(0, _modal_count - 1)
		if is_inside_tree():
			_update_input())
	add_child(overlay)


func _open_menu() -> void:
	if _busy:
		return
	PauseMenu.open()


func _toggle_log() -> void:
	if _busy:
		return
	_log_overlay.visible = not _log_overlay.visible
	_modal_count += 1 if _log_overlay.visible else -1
	_update_input()


func _selection_context(path: Array) -> String:
	var enemy: Combatant = battle.enemies[_target_index] if not battle.enemies.is_empty() else null
	var target := enemy.display_name if enemy != null and enemy.is_alive() else "无"
	var cost := _pollution_cost_text(path).strip_edges()
	return "目标：%s\n%s" % [target, "污染代价：无" if cost.is_empty() else cost]


func _watch_combatant(combatant: Combatant) -> void:
	for watch in _feedback_watches:
		if watch[0] == combatant:
			return
	var listener := _on_feedback.bind(combatant)
	combatant.feedback.connect(listener)
	_feedback_watches.append([combatant, listener])


func _on_feedback(event: Dictionary, target: Combatant) -> void:
	if not _collecting:
		return
	var captured := event.duplicate(true)
	captured["target"] = target
	_events.append(captured)


func _on_enemy_acting(enemy: Combatant, move: EnemyMoveData) -> void:
	if _collecting:
		_events.append({"kind": "enemy_action", "target": enemy, "move": move})


func _view_for(target: Combatant) -> Control:
	if target.is_player:
		return _player_panel
	var index := battle.enemies.find(target)
	return _enemy_widgets[index] if index >= 0 and index < _enemy_widgets.size() else _preview_panel


func _replay_feedback() -> bool:
	for event in _events:
		var view := _view_for(event.target)
		if event.kind == "enemy_action":
			if view is EnemyView:
				view.anticipate()
			var move: EnemyMoveData = event.move
			_bubble.set_text(event.target.display_name, move.title + " · " + move.intent_text(), SpeechBubble.State.PREVIEW)
			if not await _wait_step(0.12 if not Settings.reduced_motion else 0.04):
				return false
			continue
		var point := _effects.point_of(view)
		if view is EnemyView:
			view.apply_feedback(event)
			point = _effects.get_global_transform().affine_inverse() * view.impact_point()
		else:
			if event.has("hp"):
				_show_player_hp(int(event.hp), int(event.max_hp))
			if event.has("block"):
				_player_block.text = "临挡 %d · 持久盾 %d" % [event.block, event.persistent_block]
		match event.kind:
			"damage":
				var loss := int(event.hp_loss)
				var blocked := int(event.blocked)
				if loss > 0:
					_effects.number("−%d" % loss, point + Vector2(0, -26), Palette.VERMILION_DK)
					_effects.burst(point, false, loss >= 12 or int(event.hp) <= 0)
				if blocked > 0:
					_effects.number("格挡 %d" % blocked, point + Vector2(0, 14), Palette.BLOCK)
					_effects.burst(point, true)
				elif loss == 0:
					_effects.number("免疫", point, Palette.INK_SOFT)
			"shield":
				var gain := int(event.gain)
				_effects.number("护盾 +%d" % gain if gain > 0 else ("破盾" if int(event.block) == 0 else "拆盾 %d" % -gain), point, Palette.BLOCK if gain > 0 else Palette.GOLD_DK)
				_effects.burst(point, true)
			"heal":
				_effects.number("+%d" % int(event.gain), point, Palette.JADE)
		if not await _wait_step(0.16 if not Settings.reduced_motion else 0.045):
			return false
	_events.clear()
	return true


func _wait_step(duration: float) -> bool:
	if _exiting:
		return false
	_step_timer.start(duration)
	await presentation_step_finished
	return not _exiting


func _resource_feedback(before: Array) -> void:
	var after := [battle.player.energy, battle.player.heat, GameState.gold]
	var names := ["储能", "热度", "金币"]
	var parts: Array[String] = []
	for i in 3:
		var change := int(after[i]) - int(before[i])
		if change != 0:
			parts.append("%s %+d" % [names[i], change])
	if not parts.is_empty():
		_effects.number(" · ".join(parts), _effects.point_of(_resource_label) + Vector2(0, 28), Palette.GOLD_DK)


func _unhandled_input(event: InputEvent) -> void:
	if _log_overlay.visible and event.is_action_pressed("cancel_selection"):
		_toggle_log()
		get_viewport().set_input_as_handled()
	elif not event.is_echo() and event.is_action_pressed("end_turn"):
		_on_end_turn()
		get_viewport().set_input_as_handled()
