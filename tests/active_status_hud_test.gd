extends Control
var _screen: Control
var _pass := 0
var _fail := 0
var _capture := false
const RESOURCE_IDS := ["block", "persistent_block", "heat", "energy"]
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


func _shot(name: String) -> void:
	if not _capture: return
	await _frames(4)
	RenderingServer.force_draw(false)
	_ok(get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % name) == OK, "原生截图 " + name)


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames(12)
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
	var strip: StatusStrip = _screen._player_status
	for index in 16: battle.board.cells[index] = CharInstance.new(Database.get_character_by_glyph(GRID[index]))
	_screen._refresh_all()
	await _frames()
	_ok(strip.entries.is_empty() and strip._buttons.is_empty() and not strip.visible, "开场零资源不显示图标、角标或空栏")
	_ok(_screen._player_hp_value.visible and _screen._player_hp_value.text == "60 / 60", "气血始终醒目显示")
	_ok(_screen._enemy_widgets[0]._status.entries.is_empty(), "敌方也不显示零护盾")
	await _shot("active-status-empty")
	battle.player.block = 1
	battle.player.persistent_block = 6
	battle.player.heat = 3
	battle.player.energy = 2
	battle.next_draw_penalty = -1
	battle.enable_ability("longword_draw", 1)
	_screen._refresh_all()
	await _frames()
	_ok(strip.entries.slice(0, 4).map(func(item): return item.id) == RESOURCE_IDS, "两种防御、热度、储能固定顺序并入同一状态栏")
	for id in RESOURCE_IDS:
		var button: Control = strip.item_for(id)
		_ok(button != strip and button.get_child_count() == 2 and button.get_child(0) is BattleSymbol, "%s 有独立图形与数量角标，1 点也显示" % id)
		_ok(button.tooltip_text.contains("点") and not button.tooltip_text.contains("层"), "%s 的实际单位和说明保留" % id)
	_ok(strip.item_for("heat").tooltip_text.contains("热容 10") and is_equal_approx(strip.item_for("heat").get_child(0).level, 0.3), "热容移入详情，火焰刻度保留")
	_ok(strip.entries.any(func(item): return item.id == "draw_bonus_next" and item.stacks == 1) and strip.entries.any(func(item): return item.id == "ability:longword_draw"), "抽牌修正和无层数的持续能力仍按真实生效状态显示")
	_ok(not strip.get_global_rect().intersects(_screen._player_hp_value.get_global_rect()) and not strip.get_global_rect().intersects(_screen._gold_strip.get_global_rect()), "桌面统一状态栏不挤压气血和金币")
	await _shot("active-status-desktop")
	# 回放只读取盾值快照，不提前显示规则层最终的护盾。
	_screen._show_defense(0, 2)
	_ok(not strip.entries.any(func(item): return item.id == "block") and strip.entries.any(func(item): return item.id == "persistent_block" and item.stacks == 2) and battle.player.block == 1 and battle.player.persistent_block == 6, "逐步回放使用当时盾值，且不写回规则状态")
	_screen._refresh_all()
	battle.enemies[0].block = 4
	battle.enemies[0].persistent_block = 2
	_screen._refresh_all()
	_ok(_screen._enemy_widgets[0]._status.entries.size() == 2, "敌方两种护盾也只在获得后进入状态栏")
	_ok(not _screen._enemy_widgets[0]._status.entries[0].description.contains("清除"), "敌方护盾说明不套用玩家临挡的回合清除规则")
	get_window().size = Vector2i(844, 390)
	await _frames(12)
	_screen._layout()
	await _frames()
	var factor := float(get_window().size.y) / _screen.size.y
	for id in RESOURCE_IDS:
		_ok(strip.item_for(id) != strip and strip.item_for(id) != strip.item_for("more") and strip.item_for(id).size.y * factor >= 47.5, "手机 %s 始终可见且触控区域至少 48 像素" % id)
	_ok(strip.item_for("more") != strip and strip.entries.size() == 6, "手机多余能力折叠到更多，完整详情保留")
	_ok(strip.get_global_rect().end.y <= _screen._enemy_panel.get_global_rect().position.y, "手机状态栏与敌方信息分区")
	_ok(_screen._enemy_widgets[0]._intent.get_global_rect().end.y <= _screen._enemy_panel.get_global_rect().end.y + 1, "增加盾值图标后，敌方意图仍完整可见")
	await _shot("active-status-phone")
	battle.player.block = 0
	battle.player.persistent_block = 0
	battle.player.heat = 0
	battle.player.energy = 0
	battle.next_draw_penalty = 0
	battle.abilities.clear()
	_screen._refresh_all()
	await _frames()
	_ok(strip.entries.is_empty() and strip._buttons.is_empty() and not strip.visible, "耗尽、冷却与能力消失后清空状态图标")
	_ok(_screen._status_point("energy").is_finite() and not _screen._player_hp_value.get_global_rect().has_point(strip.anchor_for("energy")), "归零时资源动效仍落在状态栏，不错投气血")
	Router.goto("res://src/screens/title_screen.gd")
	await _frames()
	print("[active_status_hud_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
