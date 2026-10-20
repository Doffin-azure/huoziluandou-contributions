extends Control
## 遗物边界：真实手动补字时序、共享实体、指定目标、逐件存档续战。

var checks: Array = []


func _ok(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _inst(g: String) -> CharInstance:
	return CharInstance.new(Database.get_character_by_glyph(g))


func _battle(ids: Array, glyphs: Array = [], draw := 0) -> BattleState:
	GameState.relics = ids.duplicate()
	GameState.relic_binds = {}
	GameState.relic_counters = {}
	GameState.expedition = null
	GameState.player_hp = 60
	GameState.player_max_hp = 60
	GameState.permanent_damage_reduction = 0
	GameState.deck = []
	for g in glyphs:
		GameState.deck.append(_inst(g))
	if ids.has("slab") and not GameState.deck.is_empty():
		GameState.relic_binds.slab = GameState.deck[0].uid
	if ids.has("fertilizer") and not GameState.deck.is_empty():
		GameState.relic_binds.fertilizer = GameState.deck.back().uid
	var rules := BattleRules.new()
	rules.opening_draw = 0
	rules.turn_draw = draw
	rules.plays_per_turn = 0
	var enemy := EnemyData.new()
	enemy.name = "边界测试木桩"
	enemy.max_hp = 1000
	var move := EnemyMoveData.new()
	move.kind = EnemyMoveData.Kind.ATTACK
	move.damage = 5
	enemy.moves.append(move)
	var b := BattleState.new(rules)
	b.start(GameState.deck.duplicate(), [enemy, enemy], 17)
	return b


func _signature(b: BattleState) -> PackedByteArray:
	return var_to_bytes(SaveCodec.new().pack({"battle": b}))


func _manual_draw() -> void:
	var b := _battle(["clean"], ["火", "击", "防"], 1)
	b.enable_ability("manual_draw", 1)
	b.begin_player_turn(true)
	_ok(b.board.fill_count() == 0 and b.manual_draw_pending == 1, "净版布：定向选字前不抢先随机补字")
	b.place_manual_draw(["击"])
	_ok(b.board.fill_count() == 2 and b.drawn_this_turn == 2, "净版布：定向选字完成，干净盘面再补一枚")
	var before := _signature(b)
	b.place_manual_draw(["防"])
	_ok(_signature(b) == before, "重复完成手动补字不重复触发遗物")

	b = _battle(["clean"], ["火", "击", "防"], 1)
	for c in b.bag:
		if c.glyph() == "击": c.add_pollution("ink")
	b.enable_ability("manual_draw", 1)
	b.begin_player_turn(true)
	b.place_manual_draw(["击"])
	_ok(b.board.fill_count() == 1 and Relics.board_dirty(b), "净版布：选入污染字后不额外补字")

	b = _battle(["wheel"], ["火", "击", "防"], 2)
	b.enable_ability("manual_draw", 1)
	b.begin_player_turn(true)
	_ok(b.wheel_step == 1, "转轮架：等待定向选字时不提前转动")
	b.place_manual_draw(["击", "防"])
	_ok(b.wheel_step == 2 and b.board.cells.slice(0, 12).all(func(c): return c == null), "转轮架：定向补入两枚字后向下落底，且只转一次")

	for seed in 8:
		b = _battle(["slab"], ["击"], 1)
		b.enable_ability("manual_draw", 1)
		b.begin_player_turn(true)
		b.rng.seed = seed
		b.place_manual_draw(["击"])
		_ok(b.board.cells.slice(0, 12).all(func(c): return c == null) and b.board.fill_count() == 1, "压字石：手动补入的绑定字立即落底（种子%d）" % seed)

	b = _battle(["clean"], ["火"], 0)
	b.enable_ability("manual_draw", 1)
	b.begin_player_turn(true)
	_ok(b.manual_draw_pending == 0 and b.board.fill_count() == 1, "净版布：基础补字为零时仍能补一枚，不挂起选字")

	b = _battle(["clean"], [], 2)
	b.begin_player_turn(true)
	_ok(b.board.fill_count() == 0, "净版布：空字袋不凭空造字")


func _target_and_shared() -> void:
	var b := _battle(["skyfire", "breach"])
	b.enemies[1].add_persistent_block(10)
	b.player.add_status("strength", 20)
	b.board.set_cell(0, 0, _inst("流"))
	b.board.set_cell(1, 0, _inst("火"))
	var played := b.try_play([Vector2i.ZERO, Vector2i(1, 0)], {"target_index": 1})
	_ok(played.ok and b.enemies[0].hp == 1000 and b.enemies[1].hp == 935, "天火：命中指定目标，50×易伤减10盾=65，不吃20力量")

	b = _battle(["slab"], ["击"])
	var stone: CharInstance = b.bag.pop_back()
	b.board.set_cell(1, 1, stone)
	b.board.set_cell(0, 1, _inst("合"))
	b.board.set_cell(1, 0, _inst("回"))
	var first := b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	var second := b.try_play([Vector2i(1, 0), Vector2i(1, 1)])
	b.resolve_formation()
	_ok(first.ok and second.ok and b.slab_uses == 4, "压字石：合击结阵共享击，即使中途下落也只扣一次额外使用")
	_ok(b.board.get_cell(1, 3) == stone and not b.discard.has(stone), "压字石：结阵完成保留同一绑定实体，未复制或误弃")

	b = _battle(["strike"])
	b.board.set_cell(0, 0, _inst("击"))
	var effect := EffectData.new()
	effect.handler = "damage_multi"
	effect.amount = 3
	effect.args = {"hits": 3}
	var play := b._prepare_play([Vector2i.ZERO], {}, null, ["击"])
	play.effects = [effect]
	b._execute_prepared_play(play, {})
	_ok(b.enemies[0].hp == 985 and not b.strike_active, "刻刀：三段攻击每段3+2，共15伤，出字标记恢复")

	b = _battle(["fertilizer"], ["火"])
	GameState.relic_binds.fertilizer = -1
	var next := BattleState.new(b.rules)
	next.start(GameState.deck.duplicate(), [b.enemies[0].enemy_data], 17)
	_ok(next.breeders.is_empty() and not next.bag[0].temporary, "蔓生墨：绑定实体丢失时不污染其他永久字")

	b = _battle(["barrier", "buckler", "powerbank", "breach", "blitz"])
	b.end_player_turn()
	var next_battle := BattleState.new(b.rules)
	next_battle.start([], [b.enemies[0].enemy_data], 17)
	_ok(next_battle.player.block == 10 and next_battle.player.persistent_block == 4 and next_battle.player.energy == 4, "纸屏风/铜护板/蓄电瓶：下一场重新授予，不累计成20/8/8")
	_ok(next_battle.enemies[0].status_stacks("vulnerable") == 2 and next_battle.blitz_turn == 1, "蚀刻/急就章：下一场重新初始化易伤和跳行动标记")

	b = _battle(["press"], ["火"])
	GameState.remove_relic("press")
	_ok(b.board.size == 5, "对开版：本场移除遗物不破坏现有5×5棋盘")
	next = BattleState.new(b.rules)
	next.start(GameState.deck.duplicate(), [b.enemies[0].enemy_data], 17)
	_ok(next.board.size == 4, "对开版：移除后下一场恢复4×4")

	_battle(["sleep"])
	GameState.player_hp = 55
	var rest: Control = load("res://src/screens/rest_screen.gd").new()
	var amount: int = rest._heal_amount()
	GameState.heal(amount)
	_ok(amount == 38 and GameState.player_hp == 60, "安神香：主线休息18+20，实际治疗不超过生命上限")
	rest.free()


func _save_each() -> void:
	for id in Relics.DEFS:
		var b := _battle([id], ["击", "火", "防", "回", "击", "火"])
		b.draw_to_board(4)
		b.end_player_turn()
		GameState.relic_counters = {"egg": 3, "fireman_claimed": true}
		var graph := SaveCodec.new().pack({"battle": b, "deck": GameState.deck, "binds": GameState.relic_binds, "counters": GameState.relic_counters})
		var restored := SaveCodec.new().unpack(graph)
		_ok(not restored.is_empty() and _signature(restored.battle) == _signature(b) and restored.binds == GameState.relic_binds and restored.counters == GameState.relic_counters, "%s：存档恢复保留全部遗物运行态及绑定/计数" % Relics.name_of(id))
		if restored.is_empty(): continue
		var copy: BattleState = restored.battle
		b.end_player_turn()
		copy.end_player_turn()
		_ok(_signature(b) == _signature(copy), "%s：读档后下一回合与原战斗完全一致" % Relics.name_of(id))


func _ready() -> void:
	SaveManager.enabled = false
	_manual_draw()
	_target_and_shared()
	_save_each()
	var failures := checks.filter(func(c): return not c.ok).size()
	var expected_checks := 26 + 2 * Relics.DEFS.size()
	if checks.size() != expected_checks:
		failures += 1
		push_error("遗物边界用例未完整执行：%d/%d" % [checks.size(), expected_checks])
	print("[relic_edge_test] PASS=%d FAIL=%d TOTAL=%d" % [checks.size() - failures, failures, checks.size()])
	get_tree().quit(1 if failures else 0)
