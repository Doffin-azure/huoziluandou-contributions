extends Control
var _screen: Control
var _pass := 0
var _fail := 0
var _capture := false
const RESOURCE_IDS := ["heat", "energy"]
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
	await _shot("health-defense-empty")
	battle.player.block = 1
	battle.player.persistent_block = 6
	battle.player.heat = 3
	battle.player.energy = 2
	battle.next_draw_penalty = -1
	battle.enable_ability("longword_draw", 1)
	_screen._refresh_all()
	await _frames()
	_ok(strip.entries.slice(0, 2).map(func(item): return item.id) == RESOURCE_IDS and not strip.entries.any(func(item): return item.id in ["block", "persistent_block"]), "状态栏只保留热度、储能和能力，两种盾值不混入 Buff")
	for id in RESOURCE_IDS:
		var button: Control = strip.item_for(id)
		_ok(button != strip and button.get_child_count() == 2 and button.get_child(0) is BattleSymbol, "%s 有独立图形与数量角标，1 点也显示" % id)
		_ok(button.tooltip_text.contains("点") and not button.tooltip_text.contains("层"), "%s 的实际单位和说明保留" % id)
	_ok(strip.item_for("heat").tooltip_text.contains("热容 10") and is_equal_approx(strip.item_for("heat").get_child(0).level, 0.3), "热容移入详情，火焰刻度保留")
	_ok(strip.entries.any(func(item): return item.id == "draw_bonus_next" and item.stacks == 1) and strip.entries.any(func(item): return item.id == "ability:longword_draw"), "抽牌修正和无层数的持续能力仍按真实生效状态显示")
	_ok(not strip.get_global_rect().intersects(_screen._player_hp_value.get_global_rect()) and not strip.get_global_rect().intersects(_screen._gold_strip.get_global_rect()), "桌面统一状态栏不挤压气血和铜钱")
	var defense: DefenseDisplay = _screen._player_defense
	_ok(defense.badge_for("block").value == 1 and defense.badge_for("persistent_block").value == 6 and defense.badge_for("persistent_block").persistent, "两种盾值各有血条盾牌，持久盾用双边盾形区分")
	_ok(absf(defense.get_global_rect().get_center().y - _screen._player_hp.get_global_rect().get_center().y) < 1 and defense.get_global_rect().end.x >= _screen._player_hp.get_global_rect().position.x, "盾牌贴住血条左端，并与血条垂直居中")
	_ok(not defense.get_global_rect().intersects(_screen._player_hp_value.get_global_rect()) and not defense.get_global_rect().intersects(strip.get_global_rect()), "盾值不会覆盖生命数字或能力栏")
	defense.badge_for("persistent_block").pressed.emit()
	await _frames()
	_ok(_screen._modal_count == 1 and not _screen._board_view._interactable, "点击血条盾牌可看说明，浮层阻断字盘")
	for child in _screen.get_children():
		if child is ChoiceOverlay: child._on_choose(0)
	await _frames()
	await _shot("health-defense-desktop")
	# 回放只读取盾值快照，不提前显示规则层最终的护盾。
	_screen._show_defense(0, 2)
	_ok(not defense.badge_for("block").visible and defense.badge_for("persistent_block").value == 2 and battle.player.block == 1 and battle.player.persistent_block == 6, "血条逐步回放使用当时盾值，且不写回规则状态")
	_screen._refresh_all()
	battle.enemies[0].block = 4
	battle.enemies[0].persistent_block = 2
	_screen._refresh_all()
	var enemy: EnemyView = _screen._enemy_widgets[0]
	_ok(enemy._status.entries.is_empty() and enemy._defense.block == 4 and enemy._defense.persistent_block == 2, "敌方两种护盾同样独立贴在血条上，不混入能力")
	_ok(not enemy._defense.badge_for("block").tooltip_text.contains("清除"), "敌方护盾说明不套用玩家临挡的回合清除规则")
	enemy.apply_feedback({"block": 0, "persistent_block": 1})
	_ok(not enemy._defense.badge_for("block").visible and enemy._defense.persistent_block == 1 and battle.enemies[0].block == 4, "敌方受击盾值逐步减少，不提前显示最终结果或改写规则")
	battle.enable_ability("counter", 2)
	battle.enable_ability("energy_idle", 1)
	_screen._refresh_all()
	get_window().size = Vector2i(844, 390)
	await _frames(12)
	_screen._layout()
	await _frames()
	var factor := float(get_window().size.y) / _screen.size.y
	for id in RESOURCE_IDS:
		_ok(strip.item_for(id) != strip and strip.item_for(id) != strip.item_for("more") and strip.item_for(id).size.y * factor >= 47.5, "手机 %s 始终可见且触控区域至少 48 像素" % id)
	for id in ["block", "persistent_block"]:
		_ok(defense.badge_for(id).size.y * factor >= 47.5 and not defense.badge_for(id).get_global_rect().intersects(_screen._player_hp_value.get_global_rect()), "手机 %s 盾牌可点击区域至少 48 像素，不挤压生命数值" % id)
	_ok(strip.item_for("more") != strip and strip.entries.size() == 6, "手机多余能力折叠到更多，完整详情保留")
	_ok(not strip.get_global_rect().intersects(_screen._enemy_panel.get_global_rect()), "手机状态栏不与敌方信息重叠")
	_ok(_screen._enemy_widgets[0]._intent.get_global_rect().end.y <= _screen._enemy_panel.get_global_rect().end.y + 1, "增加盾值图标后，敌方意图仍完整可见")
	battle.player.block = 128
	battle.player.persistent_block = 256
	_screen._refresh_all()
	await _frames()
	_ok(defense.badge_for("block").value == 128 and defense.badge_for("persistent_block").value == 256 and not defense.get_global_rect().intersects(_screen._player_hp_value.get_global_rect()), "两种三位数盾值分别留在盾内，手机气血不被遮挡")
	await _shot("health-defense-phone")
	battle.player.block = 0
	battle.player.persistent_block = 0
	battle.player.heat = 0
	battle.player.energy = 0
	battle.next_draw_penalty = 0
	battle.abilities.clear()
	_screen._refresh_all()
	await _frames()
	_ok(strip.entries.is_empty() and strip._buttons.is_empty() and not strip.visible, "耗尽、冷却与能力消失后清空状态图标")
	_ok(not defense.visible and not defense.badge_for("block").visible and not defense.badge_for("persistent_block").visible, "两种盾归零后血条端点清空，不显示零盾或残留按钮")
	_ok(_screen._status_point("energy").is_finite() and not _screen._player_hp_value.get_global_rect().has_point(strip.anchor_for("energy")), "归零时资源动效仍落在状态栏，不错投气血")
	Router.goto("res://src/screens/title_screen.gd")
	await _frames()
	print("[active_status_hud_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
