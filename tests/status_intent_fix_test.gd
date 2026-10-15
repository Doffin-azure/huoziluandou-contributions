extends Control
var _screen: Control
var _pass := 0
var _fail := 0
var _capture := false
const GRID := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_run.call_deferred()


func _ok(condition: bool, description: String) -> void:
	if condition:
		_pass += 1
		print("  ✓ ", description)
	else:
		_fail += 1
		push_error(description)


func _frames(count := 6) -> void:
	for index in count: await get_tree().process_frame


func _idle() -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while _screen._busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	_ok(not _screen._busy, "结算后恢复输入")


func _shot(name: String) -> void:
	if not _capture: return
	await _frames(4)
	RenderingServer.force_draw(false)
	_ok(get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % name) == OK, "保存原生渲染 " + name)


func _coverage() -> void:
	var ids: Dictionary = {}
	var pattern := RegEx.new()
	pattern.compile('(?:enable_ability|simple_ability)\\([^\\n]*?"([a-z_]+)"|abilities\\["([a-z_]+)"\\]')
	for file in ["effect_handlers", "effect_handlers_actions", "battle_state"]:
		for match_result in pattern.search_all(FileAccess.get_file_as_string("res://src/core/%s.gd" % file)):
			var id: String = match_result.get_string(1) if not match_result.get_string(1).is_empty() else match_result.get_string(2)
			if not id.begins_with("_"): ids[id] = true
	_ok(ids.size() > 35, "能力覆盖取自实际效果处理器，包含动态写入的标记")
	var probe := BattleState.new(Database.rules)
	probe.player = Combatant.new("测试", 60, true)
	for id in ids:
		if id in StatusDisplay.ABILITY_PARAMETERS: continue
		probe.abilities.clear()
		probe.enable_ability(id, 2)
		var expected := "heart_layers" if id == "heart_power" else "ability:" + str(id)
		var found := StatusDisplay.collect(probe.player, probe).filter(func(item): return item.id == expected)
		_ok(StatusDisplay.ABILITY_NAMES.has(id) and found.size() == 1 and BattleSymbol.SPECS.has(expected.trim_prefix("ability:")) and not found[0].description.is_empty(), "能力 %s 有唯一状态条目、图形与说明" % id)
	for data in Database.statuses.values():
		probe.player.statuses.clear()
		probe.player.add_status(data.id, 2)
		var found := StatusDisplay.collect(probe.player).filter(func(item): return item.id == data.id)
		_ok(found.size() == 1 and BattleSymbol.SPECS.has(data.id), "词库状态 %s 已覆盖" % data.name)
	probe.player.statuses.clear()
	probe.abilities.clear()
	probe.enable_ability("next_rapid", 3)
	probe.enable_ability("next_rapid_heat", 2)
	probe.enable_ability("next_overfire", 1)
	probe.enable_ability("next_overfire_per", 4)
	var entries := StatusDisplay.collect(probe.player, probe)
	_ok(entries.size() == 2 and entries.any(func(item): return item.description.contains("升温 2")) and entries.any(func(item): return item.description.contains("× 4")), "升温与伤害参数并入主能力详情，不冒充额外能力")
	probe.next_draw_penalty = -2
	entries = StatusDisplay.collect(probe.player, probe)
	_ok(entries[0].id == "draw_bonus_next" and entries[0].stacks == 2 and entries[0].unit == "字", "下回合多抽优先显示，并准确显示字数")
	probe.next_draw_penalty = 1
	entries = StatusDisplay.collect(probe.player, probe)
	_ok(entries[0].id == "draw_penalty" and not entries.any(func(item): return item.id == "draw_bonus_next"), "抽牌增减抵消后只保留真实净修正")
	probe.next_draw_penalty = 0
	probe.manual_draw_pending = 2
	_ok(StatusDisplay.collect(probe.player, probe).any(func(item): return item.id == "manual_draw_pending" and item.stacks == 2), "待选抽牌同样显示数量")


func _find_tooltip(node: Node) -> Label:
	if node is Label and node.theme_type_variation == "TooltipLabel" and node.text.contains("下回合多抽"): return node
	for child in node.get_children(true):
		var found := _find_tooltip(child)
		if found != null: return found
	return null


func _intent_layout(view: EnemyView) -> void:
	var factor := float(get_window().size.y) / _screen.size.y
	_ok(view._intent.size.y * factor >= 63.9, "意图拥有独立的显眼区域，至少 64 屏幕像素高")
	_ok(not view._intent.get_global_rect().intersects(view._status.get_global_rect()) and view._intent.position.y < view._status.position.y, "意图与敌方状态图标分行，并放在状态之前")
	_ok(view._intent._row.get_child(0).get_child(1).get_theme_font_size("font_size") * factor >= 35.5, "意图关键数值放大到约 36 屏幕像素")
	_ok(view._intent.get_global_rect().end.y <= _screen._enemy_panel.get_global_rect().end.y + 1, "单敌意图无需滚动即可看见")


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().gui_embed_subwindows = true
	await _frames(12)
	_coverage()
	GameState.start_new_run("v03")
	if _capture:
		var stage := StudyStage.new()
		add_child(stage)
		Router.study_stage = stage
	Router.host = self
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 7})
	await _frames(10)
	_screen = Router.current
	var battle: BattleState = _screen.battle
	for index in 16: battle.board.cells[index] = CharInstance.new(Database.get_character_by_glyph(GRID[index]))
	battle.bag.clear()
	for index in 12: battle.bag.append(CharInstance.new(Database.get_character_by_glyph("击")))
	_screen._refresh_all()
	_screen._board_view.path = [Vector2i(3, 0)]
	_screen._board_view._sync_selection()
	_screen._on_primary()
	await _idle()
	var entries: Array = _screen._player_status.entries
	_ok(battle.next_draw_penalty == -1 and entries.any(func(item): return item.id == "draw_bonus_next" and item.stacks == 1), "真实打出流后，出现下回合多抽 1 字图标")
	var button: Button = _screen._player_status._buttons[0]
	_ok(button.tooltip_text.contains("1 字") and not button.tooltip_text.contains("1 层"), "抽牌的悬停说明以字为单位")
	var hint: Control = button._make_custom_tooltip(button.tooltip_text)
	add_child(hint)
	var style: StyleBoxFlat = Ink.theme.get_stylebox("panel", "TooltipPanel")
	_ok(style.bg_color.a == 1.0 and style.bg_color == Color(Palette.PAPER, 1.0) and hint.get_theme_color("font_color") == Palette.INK, "提示框使用不透明纸底、墨字，无桌面透色")
	hint.queue_free()
	battle.enemies[0].add_status("strength", 1)
	_screen._refresh_all()
	await _frames()
	var view: EnemyView = _screen._enemy_widgets[0]
	_intent_layout(view)
	await _shot("status-intent-desktop")
	if _capture:
		var motion := InputEventMouseMotion.new()
		motion.position = button.get_global_rect().get_center()
		Input.parse_input_event(motion)
		await get_tree().create_timer(0.85).timeout
		var tip := _find_tooltip(get_tree().root)
		_ok(tip != null and tip.get_theme_color("font_color") == Palette.INK, "真实鼠标悬停显示可读的抽牌说明")
		await _shot("status-intent-hover")
		motion = InputEventMouseMotion.new()
		motion.position = Vector2(12, 600)
		Input.parse_input_event(motion)
		await _frames()
	for x in 4: battle.board.clear_xy(Vector2i(x, 3))
	var before: int = battle.bag.size()
	_screen._on_end_turn()
	await _idle()
	_ok(before - battle.bag.size() == battle.rules.turn_draw + 1 and battle.next_draw_penalty == 0 and not _screen._player_status.entries.any(func(item): return item.id == "draw_bonus_next"), "进入下回合实际多抽 1 字后，图标随修正清除")
	battle.next_draw_penalty = -1
	_screen._refresh_all()
	get_window().size = Vector2i(844, 390)
	await _frames(12)
	_screen._layout()
	await _frames()
	_intent_layout(view)
	await _shot("status-intent-phone")
	Router.goto("res://src/screens/title_screen.gd")
	await _frames()
	_ok(not is_instance_valid(view), "退出战斗释放意图与提示入口")
	print("[status_intent_fix_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
