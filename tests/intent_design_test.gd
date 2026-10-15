extends Control
var _screen: Control
var _pass := 0
var _fail := 0
var _capture := false


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


func _frames(count := 4) -> void:
	for index in count: await get_tree().process_frame


func _shot(name: String) -> void:
	if not _capture: return
	await _frames()
	RenderingServer.force_draw(false)
	_ok(get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % name) == OK, "保存原生渲染 " + name)


func _labels(node: Node) -> Array:
	var result: Array = []
	if node is Label: result.append(node.text)
	for child in node.get_children(): result.append_array(_labels(child))
	return result


func _close() -> void:
	for child in _screen.get_children():
		if child is ChoiceOverlay: child._on_choose(0)
		elif child is PauseOverlay: child._close()
	await _frames()


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
	await _frames(8)
	_screen = Router.current
	var battle: BattleState = _screen.battle
	var unit: Combatant = battle.enemies[0]
	var view: EnemyView = _screen._enemy_widgets[0]
	var rng_before: int = battle.rng.state
	var hp_before: int = battle.player.hp
	var index_before: int = unit.move_index
	var physical := float(get_window().size.y) / get_viewport_rect().size.y
	_ok(view._intent.size.y * physical >= 47.9, "电脑意图整行提供至少 48 像素点击区域")
	_ok(_labels(view._intent) == ["6"] and view._intent.text.is_empty(), "攻击意图常驻只有数值，没有招式名称和攻击文案")
	unit.add_status("strength", 3)
	var multi := EnemyMoveData.new()
	multi.kind = EnemyMoveData.Kind.MULTI
	multi.title = "连击"
	multi.damage = 4
	multi.hits = 3
	view.set_intent(multi)
	await _frames()
	_ok(_labels(view._intent) == ["7 × 3"], "多段意图计入实际力量，并保留每段伤害与次数")
	_ok(view._intent.tooltip_text.contains("共 3 次") and view._intent.tooltip_text.contains("尚未扣除玩家防御"), "详情明确攻击次数及伤害口径")
	var combo := EnemyMoveData.new()
	combo.kind = EnemyMoveData.Kind.ATTACK_BLOCK
	combo.damage = 7
	combo.block = 5
	view.set_intent(combo)
	await _frames()
	_ok(_labels(view._intent) == ["7", "5"] and view._intent.entries.size() == 2, "攻击加防御保留两个实际结果，不给该规则额外添加力量")
	for data in Database.enemies.values():
		for move in data.moves:
			var entries := EnemyIntent.describe(move, unit)
			_ok(not entries.is_empty() and entries.all(func(entry): return BattleSymbol.SPECS.has(entry.symbol)), "%s / %s 意图拥有已定义图形" % [data.name, move.title])
	var buff := EnemyMoveData.new()
	buff.kind = EnemyMoveData.Kind.BUFF
	buff.status_id = "strength"
	buff.status_stacks = 2
	view.set_intent(buff)
	_ok(view._intent.tooltip_text.contains("敌人获得【力量】2 层"), "增益详情明确接收对象和层数")
	var debuff := EnemyMoveData.new()
	debuff.kind = EnemyMoveData.Kind.DEBUFF
	debuff.status_id = "vulnerable"
	debuff.status_stacks = 1
	view.set_intent(debuff)
	_ok(view._intent.tooltip_text.contains("玩家获得【易伤】1 层"), "减益详情明确玩家收到的状态")
	var inject := EnemyMoveData.new()
	inject.kind = EnemyMoveData.Kind.INJECT
	inject.inject_count = 2
	inject.pollution_id = "rush"
	view.set_intent(inject)
	_ok(view._intent.entries[0].symbol == "intent_inject" and view._intent.tooltip_text.contains("污染"), "塞字意图使用字块加墨滴，污染说明保留在详情")
	var special := EnemyMoveData.new()
	special.kind = EnemyMoveData.Kind.SPECIAL
	special.heal = 5
	view.set_intent(special)
	_ok(_labels(view._intent) == [""], "未实现特殊行为不伪造治疗数值")
	view.set_intent(multi)
	var old_target: int = _screen._target_index
	var clicks := [0]
	view.clicked.connect(func(_index): clicks[0] += 1)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = view._intent.get_global_rect().get_center()
	Input.parse_input_event(press)
	await _frames(1)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await _frames()
	_ok(_screen._modal_count == 1 and not _screen._board_view._interactable and _screen._target_index == old_target and clicks[0] == 0, "真实点击意图打开说明并锁住字盘，不触发目标选择")
	await _close()
	_ok(_screen._modal_count == 0 and _screen._board_view._interactable, "关闭意图详情恢复输入")
	_screen._set_busy(true)
	view._intent.pressed.emit()
	await _frames()
	_ok(_screen._modal_count == 0, "演出期间不会插入意图浮层")
	_screen._set_busy(false)
	_screen._open_menu()
	view._intent.pressed.emit()
	_ok(_screen._modal_count == 1, "菜单打开时不叠加意图说明")
	await _close()
	_ok(_screen._modal_count == 0, "关闭菜单后完整释放浮层锁")
	unit.hp = 0
	view.refresh(false)
	_ok(not view._intent.visible and view._intent.entries.is_empty(), "死亡敌人隐藏意图和点击入口")
	unit.hp = unit.max_hp
	view._visual.modulate.a = 1.0
	unit.statuses.clear()
	var glyphs := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]
	for index in 16:
		battle.board.cells[index] = CharInstance.new(Database.get_character_by_glyph(glyphs[index]))
	battle.player.heat = 4
	battle.player.energy = 3
	battle.enable_ability("counter", 3)
	battle.enable_ability("manual_draw", 1)
	battle.enable_ability("next_heat_to_block", 1)
	battle.player.add_status("poison", 2)
	_screen._refresh_all()
	_screen._board_view.path = [Vector2i.ZERO, Vector2i(1, 0)]
	_screen._board_view._sync_selection()
	await _frames()
	var allowed := [Palette.INK, Palette.VERMILION_DK, Palette.GOLD_DK]
	_ok(_screen._player_status._buttons.all(func(button): return button.get_child(0).ink in allowed), "能力仅使用墨黑、朱砂或旧金，层数不依靠多种颜色区分")
	_ok(Database.characters.values().all(func(data): return GlyphVfxProfile.for_glyph(data.glyph).color in allowed), "出字图标与粒子沿用相同三色")
	_ok(battle.rng.state == rng_before and battle.player.hp == hp_before and unit.move_index == index_before, "意图查看不影响随机数、生命或行动索引")
	await _shot("ink-symbol-battle-desktop")
	if _capture: await _gallery(unit)
	get_window().size = Vector2i(844, 390)
	await _frames(12)
	_screen._layout()
	await _frames(6)
	physical = float(get_window().size.y) / get_viewport_rect().size.y
	_ok(view._intent.size.y * physical >= 47.9, "手机意图整行保持至少 48 屏幕像素点击区域")
	view.set_intent(combo)
	await _frames()
	_ok(view._intent.get_global_rect().end.y <= _screen._enemy_panel.get_global_rect().end.y + 1, "单敌手机意图完整露出，无需滚动才能看见")
	_ok(view._intent._row.size.x * view._intent._row.scale.x <= view._intent.size.x + 1, "手机组合意图完整显示，未越出敌人列")
	view._intent.pressed.emit()
	await _frames()
	_ok(_screen._modal_count == 1, "手机可点开意图详情")
	await _shot("ink-intent-phone-details")
	await _close()
	await _shot("ink-symbol-battle-phone")
	Router.goto("res://src/screens/title_screen.gd")
	await _frames(8)
	_ok(not is_instance_valid(view), "退出战斗释放意图控件")
	print("[intent_design_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _gallery(unit: Combatant) -> void:
	var page := Control.new()
	page.z_index = 100
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var backdrop := ColorRect.new()
	backdrop.color = Palette.PAPER
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(backdrop)
	var title := Ink.h2("墨印构型 · 三色图标与怪物意图")
	title.position = Vector2(44, 22)
	page.add_child(title)
	var names := ["气血", "热度", "储能", "金币", "临挡", "持久盾", "攻击", "拆盾", "字袋", "补字", "净化", "重力", "回转", "反击", "蓄能", "过冷"]
	var ids := ["health", "heat", "energy", "gold", "block", "persistent_block", "hit", "fracture", "bag", "manual_draw", "cleanse", "gravity_always", "rotate", "counter", "energy_idle", "next_heat_to_block"]
	for index in ids.size():
		var cell := Vector2(index % 8, index / 8) * Vector2(148, 130) + Vector2(44, 94)
		var icon := BattleSymbol.new()
		icon.symbol = ids[index]
		icon.ink = BattleSymbol.color_for(ids[index])
		icon.position = cell + Vector2(28, 0)
		icon.size = Vector2.ONE * 60
		page.add_child(icon)
		var label := Ink.label(names[index])
		label.position = cell + Vector2(18, 74)
		page.add_child(label)
	for index in 8:
		var move := EnemyMoveData.new()
		move.kind = index as EnemyMoveData.Kind
		move.damage = 6
		move.block = 5
		move.hits = 3
		move.status_id = "strength" if index == 3 else "vulnerable"
		move.status_stacks = 2
		move.inject_count = 2
		var cell := Vector2(index % 4, index / 4) * Vector2(296, 140) + Vector2(44, 390)
		var label := Ink.label(["攻击", "防御", "攻防", "增益", "减益", "多段", "塞字", "特殊"][index])
		label.position = cell
		page.add_child(label)
		var intent := EnemyIntent.new()
		page.add_child(intent)
		intent.set_move(move, unit)
		intent.position = cell + Vector2(0, 36)
		intent.size = Vector2(250, 64)
		intent.set_ui_scale(1.35)
	await _shot("ink-symbol-intent-gallery")
	page.queue_free()
	await _frames()
