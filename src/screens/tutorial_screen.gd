extends ScreenBase
## A disposable lesson: only local combatants/cards, never GameState.start_new_run.
const LESSONS := [
	["单字也能出招", "点左上角的「击」，再点「出字」。\n先看预览；确认后这枚字才会消耗。"],
	["把相邻的字连成词", "连接「击 → 破」，再点「出字」。\n可逐字点选或滑动，只连上下左右。"],
	["看意图，先防守", "木人将在回合结束时攻击 6 点。\n连接「防 → 御」并出字来防守。"],
	["结束回合", "点「结束回合」，观察木人攻击与生命变化。\n临时格挡先抵挡伤害，敌方行动后清除；下一回合会补字。"],
	["练习完成", "已学会出招与防守！\n冒险中点敌人切换目标，点说明查看效果。\n主菜单可随时重进教程。"]
]
const PATHS := [[Vector2i(0, 0)], [Vector2i(1, 1), Vector2i(2, 1)], [Vector2i(1, 2), Vector2i(2, 2)]]
var battle: BattleState
var step := 0
var _board_view: BoardView
var _header: HBoxContainer
var _progress: Label
var _exit_btn: Button
var _guide: ScrollContainer
var _guide_column: VBoxContainer
var _heading: Label
var _instruction: Label
var _status: Label
var _preview: Label
var _feedback: Label
var _actions: HBoxContainer
var _confirm_btn: Button
var _clear_btn: Button
var _end_btn: Button
var _replay_btn: Button
var _modal_count := 0
var _pause_overlay: ChoiceOverlay
var _back_quit_before := true
var _owns_back := false


func build(root: Control) -> void:
	_back_quit_before = get_tree().quit_on_go_back
	get_tree().quit_on_go_back = false
	_owns_back = true
	_create_practice()
	_header = HBoxContainer.new()
	root.add_child(_header)
	_progress = JourneyStyle.label("")
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_progress)
	_exit_btn = JourneyStyle.button("退出练习", _leave)
	_header.add_child(_exit_btn)
	_board_view = BoardView.new()
	_board_view.require_confirmation = true
	_board_view.setup(battle.board)
	root.add_child(_board_view)
	_board_view.selection_changed.connect(_selection_changed)
	_board_view.commit.connect(_commit)
	_guide = ScrollContainer.new()
	_guide.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_guide)
	_guide_column = VBoxContainer.new()
	_guide_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guide.add_child(_guide_column)
	_heading = _label("", "Heading")
	_instruction = _label("")
	_preview = _label("", "", JourneyStyle.GOLD)
	_feedback = _label("", "", JourneyStyle.GOLD)
	_status = _label("")
	_actions = HBoxContainer.new()
	root.add_child(_actions)
	_clear_btn = _action("清空选择", _board_view.clear_selection)
	_confirm_btn = _action("出字", func(): _commit(_board_view.path.duplicate()))
	_confirm_btn.theme_type_variation = "PrimaryButton"
	_end_btn = _action("结束回合", _end_turn)
	_end_btn.theme_type_variation = "PrimaryButton"
	_replay_btn = _action("再练一次", _restart)
	resized.connect(_layout)
	_refresh()
	_layout.call_deferred()


func _create_practice() -> void:
	# start() copies relics and increments the adventure battle sequence; do not use it.
	battle = BattleState.new(Database.rules)
	battle.rng.seed = 20261018
	battle.visual_rng.seed = 18
	battle.player = Combatant.new("玩家", 30, true)
	battle.player.heat_capacity = Database.rules.heat_capacity
	var data := EnemyData.new()
	data.name = "练习木人"
	data.max_hp = 40
	var move := EnemyMoveData.new()
	move.damage = 6
	data.moves.append(move)
	var enemy := Combatant.new(data.name, data.max_hp, false)
	enemy.enemy_data = data
	battle.enemies.append(enemy)
	for entry in [[Vector2i(0, 0), "击"], [Vector2i(1, 1), "击"], [Vector2i(2, 1), "破"], [Vector2i(1, 2), "防"], [Vector2i(2, 2), "御"]]:
		battle.board.set_xy(entry[0], CharInstance.new(Database.char_by_glyph[entry[1]]))
	for glyph in ["击", "防", "御", "破"]:
		battle.bag.append(CharInstance.new(Database.char_by_glyph[glyph]))
	battle.begin_player_turn(false)


func _label(text: String, variation := "", color := JourneyStyle.TEXT) -> Label:
	var label := JourneyStyle.label(text, variation, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide_column.add_child(label)
	return label


func _action(text: String, callback: Callable) -> Button:
	var button := JourneyStyle.button(text, callback)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_child(button)
	return button


func _layout() -> void:
	if _header == null or size.y < 1: return
	var unit := JourneyStyle.touch_scale(self)
	var pad := 8 * unit
	var row := 48 * unit
	_header.position = Vector2(pad, pad)
	_header.size = Vector2(size.x - pad * 2, row)
	_exit_btn.custom_minimum_size.y = row
	var body_top := pad * 2 + row
	var body_height := size.y - body_top - row - pad * 2
	var side := minf(body_height, size.x * 0.47 - pad * 2)
	_board_view.position = Vector2(pad, body_top + (body_height - side) * 0.5)
	_board_view.size = Vector2.ONE * side
	_guide.position = Vector2(side + pad * 2, body_top)
	_guide.size = Vector2(size.x - side - pad * 3, body_height)
	_guide_column.add_theme_constant_override("separation", int(8 * unit))
	_heading.add_theme_font_size_override("font_size", int(26 * unit))
	_progress.add_theme_font_size_override("font_size", int(20 * unit))
	for label in [_instruction, _status, _preview, _feedback]:
		label.add_theme_font_size_override("font_size", int(18 * unit))
	_status.add_theme_font_size_override("font_size", int(16 * unit))
	_actions.position = Vector2(pad, size.y - row - pad)
	_actions.size = Vector2(size.x - pad * 2, row)
	_actions.add_theme_constant_override("separation", int(8 * unit))
	for button in [_confirm_btn, _clear_btn, _end_btn, _replay_btn]:
		button.custom_minimum_size.y = row
		button.add_theme_font_size_override("font_size", int(19 * unit))
	_exit_btn.add_theme_font_size_override("font_size", int(19 * unit))


func _refresh() -> void:
	_progress.text = "新手教程 · %d / 4 · 第 %d 回合" % [step + 1, battle.turn] if step < 4 else "新手教程 · 已完成"
	_heading.text = LESSONS[step][0]
	_instruction.text = LESSONS[step][1]
	var enemy: Combatant = battle.enemies[0]
	_status.text = "你：生命 %d / %d · 临时格挡 %d\n木人：生命 %d / %d · 意图：攻击 6" % [battle.player.hp, battle.player.max_hp, battle.player.block, enemy.hp, enemy.max_hp]
	_status.visible = step < 4
	_feedback.visible = not _feedback.text.is_empty()
	_board_view.set_interactable(step < 3 and _modal_count == 0)
	_clear_btn.visible = step < 3
	_confirm_btn.visible = step < 3
	_end_btn.visible = step == 3
	_replay_btn.visible = step == 4
	_exit_btn.text = "返回主菜单" if step == 4 else "退出练习"
	_selection_changed(_board_view.path, [], null)
	_highlight()
	_guide.scroll_vertical = 0


func _highlight() -> void:
	for tile in _board_view.tiles:
		tile.set_dimmed(step < 3 and not PATHS[step].has(tile.grid_pos))


func _selection_changed(path: Array, _glyphs: Array, _word: WordData) -> void:
	if _confirm_btn == null: return
	_preview.visible = step < 3 and not path.is_empty()
	_confirm_btn.disabled = path.is_empty() or _modal_count > 0 or step >= 3
	_clear_btn.disabled = path.is_empty() or _modal_count > 0
	if path.is_empty():
		_preview.text = "选中后在这里预览效果" if step < 3 else ""
		return
	var glyphs := battle.board.glyphs_of(path)
	# A new choice replaces the previous success/error message with its preview.
	_feedback.hide()
	var word := Database.get_word_by_glyphs(glyphs) if glyphs.size() > 1 else null
	var effect := word.description if word != null else battle.board.get_xy(path[0]).data.description if glyphs.size() == 1 else "尚未组成有效词语"
	_preview.text = "已选「%s」\n%s" % ["".join(glyphs), effect]


func _commit(path: Array) -> void:
	if step >= 3 or _modal_count > 0: return
	if path != PATHS[step]:
		_feedback.text = "这一步请%s。点「清空选择」可重试，不会消耗字。" % ["只选左上角的「击」", "按「击 → 破」的顺序连接亮起的两字", "按「防 → 御」的顺序连接亮起的两字"][step]
		_feedback.show()
		_guide.scroll_vertical = 0
		return
	var hp_before: int = battle.enemies[0].hp
	var result := battle.try_play(path, {"target_index": 0})
	if not result.ok:
		_feedback.text = result.reason
		_feedback.show()
		return
	_feedback.text = "成功！获得 %d 点临时格挡。" % battle.player.block if step == 2 else "木人生命 -%d；用字进入弃字堆。" % (hp_before - battle.enemies[0].hp)
	step += 1
	_board_view.clear_selection()
	_board_view.rebuild(true)
	_refresh()


func _end_turn() -> void:
	if step != 3 or _modal_count > 0: return
	var before := battle.player.hp
	battle.end_player_turn()
	step = 4
	_feedback.text = "木人的 6 点攻击被挡住！生命 %d → %d。\n剩余临时格挡已清除，新回合已补字。" % [before, battle.player.hp]
	_board_view.rebuild(true)
	_refresh()


func _restart() -> void:
	if _modal_count > 0: return
	step = 0
	_create_practice()
	_board_view.setup(battle.board)
	_board_view.clear_selection()
	_board_view.rebuild()
	_feedback.text = ""
	_refresh()


func _leave() -> void:
	if _modal_count == 0: goto("res://src/screens/title_screen.gd")


func open_practice_menu() -> void:
	if _modal_count > 0: return
	var overlay := ChoiceOverlay.new()
	_pause_overlay = overlay
	overlay.setup({"title": "练习暂停", "body": "练习进度仅在本次有效，冒险自动存档不受影响。", "dismissible": true, "cancel_index": 0,
		"options": [{"text": "继续练习", "primary": true}, {"text": "重新练习"}, {"text": "退出练习"}]})
	# ChoiceOverlay invokes actions before freeing itself. Defer until input unlocks.
	overlay.chose.connect(func(index):
		if index == 1: _restart.call_deferred()
		elif index == 2: _leave.call_deferred())
	_modal_count += 1
	_board_view.set_interactable(false)
	_exit_btn.disabled = true
	_end_btn.disabled = true
	_replay_btn.disabled = true
	_selection_changed(_board_view.path, [], null)
	overlay.tree_exited.connect(func():
		_modal_count = 0
		if not is_queued_for_deletion():
			_exit_btn.disabled = false
			_end_btn.disabled = false
			_replay_btn.disabled = false
			_refresh())
	add_child(overlay)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("end_turn") and not event.is_echo() and step == 3 and _modal_count == 0:
		_end_turn()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		_handle_back.call_deferred()


func _handle_back() -> void:
	if Router.current != self or is_queued_for_deletion(): return
	if is_instance_valid(_pause_overlay) and _pause_overlay.is_inside_tree():
		_pause_overlay._on_choose(0)
	elif not _board_view.path.is_empty():
		_board_view.clear_selection()
	else:
		open_practice_menu()


func _exit_tree() -> void:
	if _owns_back: get_tree().quit_on_go_back = _back_quit_before
