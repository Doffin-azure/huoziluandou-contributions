extends Control
## 遗物第一批：逐件验证效果，再验证和原有体系（易伤、停火、伏兵先手、固定、复制层、回收、
## 重力能力、污染、远征印章 / 随机序列、镀金、实体守恒）的兼容。

var _pass := 0
var _fail := 0


func _ok(condition: bool, description: String) -> void:
	if condition:
		_pass += 1
		print("  ✓ ", description)
	else:
		_fail += 1
		push_error(description)


func _ready() -> void:
	_test_isolation()
	_test_pools()
	_test_press()
	_test_strike_breach()
	_test_opening_defense()
	_test_empty_case()
	_test_chaos_dice()
	_test_batch_two()
	_test_blitz()
	_test_gravity_order()
	_test_slab()
	_test_fertilizer()
	_test_clean()
	_test_skyfire()
	_test_out_of_battle()
	_test_expedition()
	_test_all_relics_smoke()
	_test_review_fixes()
	GameState.relics.clear()
	GameState.relic_binds.clear()
	GameState.relic_counters.clear()
	print("[relic_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


# ---------------------------------------------------------------- 池子
func _test_pools() -> void:
	_reset()
	var normal: Array = Relics.normal_pool()
	var event: Array = Relics.event_pool()
	_ok(event.size() == 3 and normal.size() == 22 and event.has("life_debt") and not normal.any(func(id): return event.has(id)), "普通池与事件池分离：%d / %d" % [normal.size(), event.size()])
	for id in event:
		_ok(Relics.is_event_relic(id) and not normal.has(id), "事件遗物不进入普通池：%s" % Relics.name_of(id))
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var rolled := {}
	for _i in 300:
		for id in Relics.roll_choices([], rng, 3):
			rolled[id] = true
	var leaked: Array = rolled.keys().filter(func(id): return event.has(id))
	_ok(leaked.is_empty(), "普通随机池 300 次不会滚出事件遗物 %s" % [leaked])
	var event_rolled := Relics.roll_event_choices([], rng, 3)
	_ok(event_rolled.size() == 3 and event_rolled.all(func(id): return event.has(id)), "事件随机池只会滚出事件遗物 %s" % [event_rolled])


# ---------------------------------------------------------------- 工具
func _reset(relics: Array = []) -> void:
	GameState.start_new_run("v03")
	GameState.player_max_hp = 60
	GameState.player_hp = 60
	for r in relics:
		GameState.relics.append(r)


func _rules(opening := 0, turn_draw := 0) -> BattleRules:
	var rules: BattleRules = Database.rules.duplicate()
	rules.opening_draw = opening
	rules.turn_draw = turn_draw
	return rules


func _enemy_data(dmg := 5, hp := 200) -> EnemyData:
	var ed := EnemyData.new()
	ed.name = "relic_dummy"
	ed.max_hp = hp
	var mv := EnemyMoveData.new()
	mv.kind = EnemyMoveData.Kind.ATTACK
	mv.damage = dmg
	ed.moves.append(mv)
	return ed


func _battle(relics: Array = [], deck: Array = [], enemies := 1, opening := 0, turn_draw := 0) -> BattleState:
	_reset(relics)
	var b := BattleState.new(_rules(opening, turn_draw))
	var eds: Array = []
	for i in enemies:
		eds.append(_enemy_data())
	b.start(deck, eds, 7)
	return b


func _inst(g: String) -> CharInstance:
	return CharInstance.new(Database.get_character_by_glyph(g))


func _place(b: BattleState, pos: Vector2i, g: String) -> CharInstance:
	var inst := _inst(g)
	b.board.set_xy(pos, inst)
	return inst


func _clear_board(b: BattleState) -> void:
	for i in b.board.cells.size():
		b.board.cells[i] = null


func _play_word(b: BattleState, text: String, row := 0) -> Dictionary:
	var path: Array = []
	for i in text.length():
		var p := Vector2i(i, row)
		_place(b, p, text[i])
		path.append(p)
	return b.try_play(path)


func _pos_of(b: BattleState, uid: int) -> Vector2i:
	for i in b.board.cells.size():
		var c: CharInstance = b.board.cells[i]
		if c != null and c.uid == uid:
			return Vector2i(i % b.board.size, i / b.board.size)
	return Vector2i(-1, -1)


func _count_glyph(b: BattleState, g: String) -> int:
	return b.board.cells.filter(func(c): return c != null and c.glyph() == g).size()


# ---------------------------------------------------------------- 没遗物时完全不变
func _test_isolation() -> void:
	var b := _battle([], [], 1, 10, 3)
	_ok(b.board.size == 4 and b.relics.is_empty() and b.player.block == 0 and b.player.energy == 0, "没有遗物：4×4、无格挡、无储能，和原规则一致")
	_ok(not b.enemies[0].statuses.has("vulnerable") and b.blitz_turn == 0 and b.breeders.is_empty() and b.slab_uid == -1, "没有遗物：不加易伤、不跳敌人行动、不繁殖、不绑石板")


# ---------------------------------------------------------------- 新的印刷版
func _test_press() -> void:
	var deck: Array = []
	for i in 30:
		deck.append(_inst("火"))
	var b := _battle(["press"], deck, 1, 10, 0)
	var filled := b.board.cells.filter(func(c): return c != null).size()
	_ok(b.board.size == 5 and b.board.cells.size() == 25, "新的印刷版：字盘 5×5")
	_ok(filled == 14, "新的印刷版：开局补 10 + 4 = 14 枚（%d）" % filled)
	# 字袋不够时不凭空生成
	var small: Array = []
	for i in 9:
		small.append(_inst("火"))
	b = _battle(["press"], small, 1, 10, 0)
	_ok(b.board.cells.filter(func(c): return c != null).size() == 9, "新的印刷版：字袋只有 9 枚时只补 9 枚，不凭空生成")
	# 普通回合补字不变
	b = _battle(["press"], deck.duplicate(), 1, 0, 3)
	_ok(b.board.cells.filter(func(c): return c != null).size() == 4, "新的印刷版：开局补字基数为 0 时也多补 4 枚")
	_clear_board(b)
	b.end_player_turn()
	_ok(b.board.cells.filter(func(c): return c != null).size() == 3, "新的印刷版：普通回合仍补 3 枚")
	# 5×5 上的原有重力 / 横移
	_clear_board(b)
	_place(b, Vector2i(4, 0), "火")
	b.apply_gravity()
	_ok(b.board.get_xy(Vector2i(4, 4)) != null, "新的印刷版：原有重力在 5×5 上落到第 5 行")
	b.apply_gravity_left()
	_ok(b.board.get_xy(Vector2i(0, 4)) != null, "新的印刷版：横向重力在 5×5 上压到最左")
	_reset()
	var plain := BattleState.new(_rules())
	plain.start([], [_enemy_data()], 7)
	_ok(plain.board.size == 4, "新的印刷版：失去遗物后下一场恢复 4×4")


# ---------------------------------------------------------------- 打击增强 / 破防
func _test_strike_breach() -> void:
	var b := _battle(["strike"])
	var e: Combatant = b.enemies[0]
	_place(b, Vector2i(0, 0), "击")
	b.try_play([Vector2i(0, 0)])
	_ok(e.hp == 200 - 6, "打击增强：单字【击】4 + 2 = 6（%d）" % (200 - e.hp))
	var hp := e.hp
	_place(b, Vector2i(1, 1), "破")
	b.try_play([Vector2i(1, 1)])
	_ok(hp - e.hp == 2, "打击增强：不带【击】的【破】不加（%d）" % (hp - e.hp))
	_ok(not b.strike_active, "打击增强：出字结束后标记复位")
	hp = e.hp
	var r := _play_word(b, "回击", 2)
	_ok(r.ok and hp - e.hp == int(Database.get_word_by_glyphs(["回", "击"]).effects[0].amount) + 2, "打击增强：词【回击】每段 +2（%d）" % (hp - e.hp))

	b = _battle(["breach"], [], 2)
	_ok(b.enemies.all(func(x): return x.status_stacks("vulnerable") == 2), "破防：开局所有敌人 2 层易伤")
	_place(b, Vector2i(0, 0), "击")
	b.try_play([Vector2i(0, 0)])
	_ok(b.enemies[0].hp == 200 - 6, "破防：易伤 ×1.5 照原规则向上取整（4 → 6）")
	b.end_player_turn()
	b.end_player_turn()
	_ok(b.enemies[0].status_stacks("vulnerable") == 0, "破防：敌方易伤每回合衰减 1 层，两回合后清空")

	b = _battle(["strike", "breach"])
	_place(b, Vector2i(0, 0), "击")
	b.try_play([Vector2i(0, 0)])
	_ok(b.enemies[0].hp == 200 - 9, "打击增强 + 破防：(4 + 2) × 1.5 = 9（%d）" % (200 - b.enemies[0].hp))


# ---------------------------------------------------------------- 屏障 / 小盾 / 充电宝
func _test_opening_defense() -> void:
	var b := _battle(["barrier", "buckler", "powerbank"])
	_ok(b.player.block == 10 and b.player.persistent_block == 4, "屏障 +10 临时格挡；小盾 +4 持久盾")
	_ok(b.player.energy == 4, "充电宝：开局 4 储能")
	b.end_player_turn()
	_ok(b.player.hp == 60 and b.player.block == 0 and b.player.persistent_block == 4, "第一回合敌人 5 伤被屏障吃掉，临挡到期；持久盾保留")
	b.end_player_turn()
	_ok(b.player.hp == 59 and b.player.persistent_block == 0, "第二回合：持久盾 4 抵 4，扣 1 血（%d）" % b.player.hp)
	# 远征开场护盾叠加（护盾 +4）
	_reset(["barrier"])
	var ex := Expedition.start(5)
	GameState.relics.append("barrier")
	ex.fight = {"kind": "foe", "k": 0, "g": "爆", "name": "明敌"}
	var s := BattleState.new(Database.rules)
	s.start(GameState.make_battle_deck(), [_enemy_data()], 7)
	ex.apply_battle_setup(s)
	_ok(s.player.block == 10, "远征屏障开场10，没有版面叠加（%d）" % s.player.block)
	# 伏兵先手：屏障能挡住开场突袭
	ex.fight = {"kind": "ambush", "k": 0, "amb": 0, "g": "伏", "name": "伏兵"}
	s = BattleState.new(Database.rules)
	s.start(GameState.make_battle_deck(), [_enemy_data(8)], 7)
	ex.apply_battle_setup(s)
	_ok(s.player.hp == GameState.player_hp and s.player.block == 2, "屏障：伏兵开场突袭 8 伤先被临挡吸收（剩 %d）" % s.player.block)
	GameState.expedition = null


# ---------------------------------------------------------------- 第二批
func _test_batch_two() -> void:
	# 血珀：溢出的治疗转持久盾
	var b := _battle(["amber"], [], 0)
	b.player.hp = 50
	_ok(b.heal_player(20) == 10 and b.player.hp == 60 and b.player.persistent_block == 10, "血珀：治疗 20，溢出的 10 转为持久盾（%d / %d）" % [b.player.hp, b.player.persistent_block])
	b.player.persistent_block = 0
	b.player.hp = 60
	b.heal_player(7)
	_ok(b.player.persistent_block == 7, "血珀：满血治疗全部转盾（%d）" % b.player.persistent_block)

	# 裂雷瓶：获得储能翻倍，回合结束清空
	b = _battle(["cracked_bottle"], [], 0)
	b.add_energy(3)
	_ok(b.player.energy == 6, "裂雷瓶：获得 3 储能变为 6（%d）" % b.player.energy)
	b.end_player_turn()
	_ok(b.player.energy == 0, "裂雷瓶：回合结束清空储能（%d）" % b.player.energy)

	# 将腐供果：开局随机一枚字换成本场临时副本，永久字不变
	_reset(["rotting_fruit"])
	var deck_before: int = GameState.deck.size()
	var permanent_uid: int = GameState.deck[0].uid
	b = _battle(["rotting_fruit"], GameState.make_battle_deck(), 0)
	var temps: Array = b.bag.filter(func(c): return c.temporary)
	_ok(temps.size() == 1 and GameState.deck.size() == deck_before, "将腐供果：开局一枚临时副本，永久字袋不变（%d）" % temps.size())
	_ok(GameState.deck.all(func(c): return not c.temporary), "将腐供果：不会把永久实体改成临时")

	# 留字蜡：5% 留场判定，固定种子下会命中但不会必然
	b = _battle(["stay_wax"], [], 0)
	b.rng.seed = 424242
	var wax_hits := 0
	for _i in 500:
		if Relics.stay_wax(b, _inst("火")):
			wax_hits += 1
	_ok(wax_hits > 0 and wax_hits < 100, "留字蜡：500 次判定命中 %d 次" % wax_hits)

	# 补字鬼手：前 3 枚实际打出的字补位
	b = _battle(["ghost_hand"], [], 0, 0, 0)
	_ok(b.magic_hand_left == 3, "补字鬼手：开局 3 次")
	_play_word(b, "回击")
	_ok(b.magic_hand_left == 1, "补字鬼手：打出 2 字后剩 1 次（%d）" % b.magic_hand_left)
	_play_word(b, "火")
	_ok(b.magic_hand_left == 0, "补字鬼手：第 3 枚后次数用尽（%d）" % b.magic_hand_left)


# ---------------------------------------------------------------- 乱文骨骰
func _test_chaos_dice() -> void:
	_reset()
	var before: int = GameState.deck.size()
	var old_uids: Array = GameState.deck.map(func(c): return c.uid)
	_ok(GameState.add_relic("chaos_dice"), "乱文骨骰可以拾取")
	_ok(GameState.deck.size() == before + 3, "乱文骨骰：字袋变为原数量 +3（%d → %d）" % [before, GameState.deck.size()])
	var old_left := old_uids.filter(func(uid): return GameState.deck.any(func(c): return c.uid == uid))
	_ok(old_left.is_empty(), "乱文骨骰：旧字实体全部被替换")
	_ok(GameState.deck.all(func(c): return c.data != null and not c.data.is_pollution and not c.data.tags.has("event")), "乱文骨骰：只生成普通字")


# ---------------------------------------------------------------- 空铅盒
func _test_empty_case() -> void:
	var b := _battle(["empty_case"], [], 0)
	_clear_board(b)
	Relics.on_player_turn_end(b)
	_ok(b.player.persistent_block == 8, "空铅盒：4 行全空 → 持久盾 +8（%d）" % b.player.persistent_block)
	var c := _battle(["empty_case"], [], 0)
	_clear_board(c)
	for x in c.board.size:
		_place(c, Vector2i(x, 0), "火")
	Relics.on_player_turn_end(c)
	_ok(c.player.persistent_block == 6, "空铅盒：只有 3 行全空 → 持久盾 +6（%d）" % c.player.persistent_block)


# ---------------------------------------------------------------- 闪电战
func _test_blitz() -> void:
	var b := _battle(["blitz"], [], 2)
	var m0: int = b.enemies[0].move_index
	b.end_player_turn()
	_ok(b.player.hp == 60 and b.turn == 2, "闪电战：两个敌人都跳过第一次行动，进入第 2 回合")
	_ok(b.enemies.all(func(x): return x.move_index == m0 + 1), "闪电战：招式顺延（和停火一样推进）")
	b.end_player_turn()
	_ok(b.player.hp == 50, "闪电战：第二回合起敌人正常行动（-10）")
	# 屏障只在第一回合有效，不因敌人跳过而延长
	b = _battle(["blitz", "barrier"])
	b.end_player_turn()
	_ok(b.player.block == 0 and b.player.hp == 60, "闪电战 + 屏障：临挡在跳过的那回合照常到期")
	b.end_player_turn()
	_ok(b.player.hp == 55, "闪电战 + 屏障：第二回合不再有屏障（-5）")
	# 与停火叠加：停火再跳一次
	b = _battle(["blitz"])
	b.enemy_skip_turns = 1
	b.end_player_turn()
	b.end_player_turn()
	_ok(b.player.hp == 60, "闪电战 + 停火：前两回合敌人都不行动")
	b.end_player_turn()
	_ok(b.player.hp == 55, "闪电战 + 停火：第三回合恢复")
	# 首领先手 / 伏兵突袭 不被闪电战抵消（它们是开场行动）
	b = _battle(["blitz"])
	b._enemy_act(b.enemies[0], true)
	_ok(b.player.hp == 55, "闪电战：不抵消开场突袭 / 首领先手")
	b.end_player_turn()
	_ok(b.player.hp == 55, "闪电战：之后第一回合结束照样跳过")


# ---------------------------------------------------------------- 重力：仓鼠轮 + 石板，按获得顺序
func _test_gravity_order() -> void:
	var b := _battle(["wheel"])
	_ok(b.wheel_step == 1, "仓鼠轮：第一回合开局也转一次（上）")
	_clear_board(b)
	_place(b, Vector2i(1, 1), "火")
	var seq: Array = []
	for i in 4:
		b.end_player_turn()
		for k in b.board.cells.size():
			if b.board.cells[k] != null:
				seq.append(Vector2i(k % 4, k / 4))
	_ok(seq == [Vector2i(1, 3), Vector2i(0, 3), Vector2i(3, 3), Vector2i(3, 0)], "仓鼠轮：下 → 左 → 右 → 上 轮流 %s" % [seq])
	# 固定字不被仓鼠轮带走
	_clear_board(b)
	var pin := _place(b, Vector2i(2, 1), "防")
	pin.pinned = true
	b.end_player_turn()
	_ok(b.board.get_xy(Vector2i(2, 1)) == pin, "仓鼠轮：固定的字原地不动（原有固定规则）")
	# 获得顺序：同一时点先结算的遗物会改变后一个看到的排布
	_reset(["slab", "wheel"])
	var d2: Array = [_inst("火")]
	GameState.deck = d2.duplicate()
	GameState.relic_binds["slab"] = d2[0].uid
	var s2 := BattleState.new(_rules())
	s2.start(d2.duplicate(), [_enemy_data()], 7)
	_clear_board(s2)
	s2.board.set_xy(Vector2i(1, 0), d2[0])
	_place(s2, Vector2i(0, 3), "防")
	s2.wheel_step = 2
	Relics.apply_gravity_relics(s2)
	var a := _pos_of(s2, d2[0].uid)
	_reset(["wheel", "slab"])
	GameState.deck = d2.duplicate()
	GameState.relic_binds["slab"] = d2[0].uid
	var s3 := BattleState.new(_rules())
	s3.start(d2.duplicate(), [_enemy_data()], 7)
	_clear_board(s3)
	s3.board.set_xy(Vector2i(1, 0), d2[0])
	_place(s3, Vector2i(0, 3), "防")
	s3.wheel_step = 2
	Relics.apply_gravity_relics(s3)
	var c := _pos_of(s3, d2[0].uid)
	# 石板先：(1,0) 落到 (1,3)，左压被 (0,3) 的【防】挡住 → (1,3)；仓鼠轮先：左压到 (0,0)，再落到 (0,2)
	_ok(a == Vector2i(1, 3) and c == Vector2i(0, 2), "获得顺序改变结果：石板先落再左压 %s；先左压再落 %s" % [a, c])


# ---------------------------------------------------------------- 沉重石板
func _slab_battle(extra: Array = []) -> Array:
	_reset(["slab"] + extra)
	var bound := _inst("击")
	GameState.deck = [bound]
	GameState.relic_binds["slab"] = bound.uid
	var b := BattleState.new(_rules())
	var eds: Array = [_enemy_data(0, 999)]
	b.start([bound], eds, 7)
	_clear_board(b)
	b.bag.erase(bound)
	b.board.set_xy(Vector2i(2, 0), bound)
	Relics.slab_fall(b)
	return [b, bound]


func _test_slab() -> void:
	var r := _slab_battle()
	var b: BattleState = r[0]
	var bound: CharInstance = r[1]
	_ok(b.slab_uid == bound.uid and b.slab_uses == 5, "沉重石板：绑定那一枚，本场额外 5 次")
	_ok(_pos_of(b, bound.uid) == Vector2i(2, 3), "沉重石板：在盘上始终落到最底")
	var used := 0
	for i in 10:
		var p := _pos_of(b, bound.uid)
		if p.x < 0:
			break
		if b.try_play([p]).ok:
			used += 1
	_ok(used == 6, "沉重石板：一共能用 6 次（1 + 额外 5）（%d）" % used)
	_ok(b.removed_this_battle.has(bound) and not b.discard.has(bound) and not b.bag.has(bound), "沉重石板：用尽后本场移出循环，不进弃字堆")
	b.ensure_bag()
	b.end_player_turn()
	_ok(_pos_of(b, bound.uid).x < 0, "沉重石板：洗袋、补字都拿不回来")
	_ok(GameState.deck.has(bound), "沉重石板：不是删字，永久字袋里还在")
	var nb := BattleState.new(_rules())
	nb.start([bound], [_enemy_data()], 7)
	_ok(nb.slab_uses == 5 and nb.bag.has(bound), "沉重石板：下一场恢复 5 次")
	# 别的石头落下来的高度不受影响：只有绑定那一枚受重力
	r = _slab_battle()
	b = r[0]
	var other := _place(b, Vector2i(0, 0), "火")
	b.end_player_turn()
	_ok(b.board.get_xy(Vector2i(0, 0)) == other, "沉重石板：只有绑定那一枚下落，别的字不动")
	# 固定：固定后不消耗石板次数，也不下落
	r = _slab_battle()
	b = r[0]
	bound = r[1]
	b.board.set_xy(Vector2i(2, 3), null)
	b.board.set_xy(Vector2i(2, 0), bound)
	bound.pinned = true
	Relics.slab_fall(b)
	_ok(_pos_of(b, bound.uid) == Vector2i(2, 0), "沉重石板 + 固定：固定优先，不下落")
	b.try_play([Vector2i(2, 0)])
	_ok(b.slab_uses == 5, "沉重石板 + 固定：固定那次不扣石板次数")
	bound.pinned = false
	# 复制层：先用复制层，再用石板次数
	r = _slab_battle()
	b = r[0]
	bound = r[1]
	bound.temporary_uses = 2
	var p0 := _pos_of(b, bound.uid)
	b.try_play([p0])
	b.try_play([_pos_of(b, bound.uid)])
	_ok(b.slab_uses == 5 and bound.temporary_uses == 0, "沉重石板 + 复制层：先扣复制层，石板次数不动（叠加）")
	b.try_play([_pos_of(b, bound.uid)])
	_ok(b.slab_uses == 4, "沉重石板 + 复制层：复制层用完才扣石板")
	# 绑定的字被删：遗物静默失效
	_reset(["slab"])
	GameState.relic_binds["slab"] = 999999
	var lost := BattleState.new(_rules(10, 3))
	lost.start(GameState.make_battle_deck(), [_enemy_data()], 7)
	_ok(lost.slab_uid == -1 and GameState.relic_bound_inst("slab") == null, "沉重石板：绑定的字已不在字袋 → 本场不生效，不报错")


# ---------------------------------------------------------------- 化肥
func _test_fertilizer() -> void:
	_reset(["fertilizer"])
	var src := _inst("火")
	src.gilded = true
	GameState.deck = [src]
	GameState.relic_binds["fertilizer"] = src.uid
	var b := BattleState.new(_rules())
	b.start([src], [_enemy_data(0)], 7)
	var copy: CharInstance = b.bag[0]
	_ok(copy != src and copy.temporary and b.breeders.has(copy.uid) and copy.gilded, "化肥：本场用临时副本（保留镀金），永久实体留在字袋")
	_ok(not b.bag.has(src) and GameState.deck.has(src), "化肥：永久实体不进本场循环，打完不会丢字")
	_clear_board(b)
	b.bag.erase(copy)
	b.board.set_xy(Vector2i(0, 0), copy)
	b.end_player_turn()
	_ok(_count_glyph(b, "火") == 3, "化肥：第 1 回合结束，母本向两个空邻格繁殖（%d）" % _count_glyph(b, "火"))
	var born: Array = b.board.cells.filter(func(c): return c != null and c != copy)
	_ok(born.all(func(c): return c.temporary and not c.gilded and b.temp_chars.has(c)), "化肥：复制体是临时字、不继承镀金、记在本场临时字里")
	b.end_player_turn()
	_ok(_count_glyph(b, "火") == 6, "化肥：第 2 回合新生的也繁殖（不当回合递归）（%d）" % _count_glyph(b, "火"))
	for i in 6:
		b.end_player_turn()
	_ok(_count_glyph(b, "火") == 16, "化肥：满盘后不覆盖")
	# 打出临时副本：不进弃字堆
	var p := Vector2i(0, 0)
	b.try_play([p])
	_ok(not b.discard.any(func(c): return c.temporary), "化肥：打出的临时字直接消失，不进弃字堆")
	# 原有的盘面清理 / 回收
	_ok(b.recoverable_consumed().is_empty(), "化肥：临时字不能被【收】类回收")
	# 全部用掉 → 繁殖停止
	_clear_board(b)
	b.end_player_turn()
	_ok(_count_glyph(b, "火") == 0, "化肥：本场全部用掉后不再繁殖")
	# 和石板绑同一枚：化肥让位
	_reset(["slab", "fertilizer"])
	var both := _inst("火")
	GameState.deck = [both]
	GameState.relic_binds = {"slab": both.uid, "fertilizer": both.uid}
	var b2 := BattleState.new(_rules())
	b2.start([both], [_enemy_data()], 7)
	_ok(b2.slab_uid == both.uid and b2.breeders.is_empty(), "化肥 + 石板绑同一枚：石板优先，化肥这场不生效")
	_ok(not GameState.bind_relic("fertilizer", both.id()) or GameState.relic_binds.fertilizer != GameState.relic_binds.slab, "绑定时不会把两件遗物绑到同一枚")


# ---------------------------------------------------------------- 光洁
func _test_clean() -> void:
	var deck: Array = []
	for i in 20:
		deck.append(_inst("火"))
	var b := _battle(["clean"], deck, 1, 0, 3)
	b.end_player_turn()
	_ok(b.board.cells.filter(func(c): return c != null).size() == 4, "光洁：盘面干净，补 3 + 1")
	var dirty := _place(b, Vector2i(3, 3), "火")
	dirty.add_pollution("ink")
	var before := b.board.cells.filter(func(c): return c != null).size()
	b.end_player_turn()
	_ok(b.board.cells.filter(func(c): return c != null).size() == before + 3, "光洁：有被污染的字，只补 3")
	dirty.clear_pollutions()
	before = b.board.cells.filter(func(c): return c != null).size()
	b.end_player_turn()
	_ok(b.board.cells.filter(func(c): return c != null).size() == before + 4, "光洁：净化后重新生效（看当前污染，不看历史）")
	_clear_board(b)
	_place(b, Vector2i(0, 0), "火").data = Database.get_character("pollution")
	before = 1
	b.end_player_turn()
	_ok(b.board.cells.filter(func(c): return c != null).size() == before + 3, "光洁：盘上有污染字（敌方注入）也算不干净")


# ---------------------------------------------------------------- 天火遗诏
func _test_skyfire() -> void:
	for has_relic in [false, true]:
		var b := _battle(["skyfire"] if has_relic else [])
		var e: Combatant = b.enemies[0]
		_place(b, Vector2i(3, 3), "热")
		b.player.heat = 5
		var r := _play_word(b, "流火")
		if has_relic:
			_ok(r.ok and e.hp == 150, "天火遗诏：流火追加 50 伤害（%d）" % (200 - e.hp))
			_ok(b.player.heat == 3 and b.bag.any(func(c): return c.glyph() == "热"), "天火遗诏：流火原效果保留（热回袋、热度 -2）")
		else:
			_ok(r.ok and e.hp == 200 and b.player.heat == 3, "没有天火遗诏：流火只洗热、降热")
	var b2 := _battle(["skyfire", "breach"])
	_play_word(b2, "流火")
	_ok(b2.enemies[0].hp == 200 - 75, "天火遗诏 + 破防：50 也吃易伤（75）")
	var b3 := _battle(["skyfire", "strike"])
	b3.player.add_status("strength", 3)
	_play_word(b3, "流火")
	_ok(b3.enemies[0].hp == 150, "天火遗诏：算法术伤害，不吃力量、打击增强")


# ---------------------------------------------------------------- 战外：好好睡 / 火人 / 发明蛋
func _test_out_of_battle() -> void:
	_reset()
	var ex := Expedition.start(3)
	var base := ex.rest_heal_amount()
	GameState.relics.append("sleep")
	_ok(ex.rest_heal_amount() == base + 20, "好好睡：远征休息点治疗 +20（%d → %d）" % [base, ex.rest_heal_amount()])
	ex.seals = ["蒲团"]
	_ok(ex.rest_heal_amount() == base * 2 + 20, "好好睡 + 蒲团：先翻倍再 +20")
	ex.seals = []
	GameState.expedition = null
	_reset()
	var n := GameState.deck_size()
	GameState.add_relic("fireman")
	_ok(GameState.deck_size() == n + 4 and GameState.glyph_counts().get("火", 0) >= 4, "余烬匣（主线）：字袋 +4 枚【火】")
	_reset()
	ex = Expedition.start(4)
	GameState.add_relic("fireman")
	_ok(ex.tray.count("火") == 4, "余烬匣（远征）：4 枚【火】先进字匣")
	ex.tray = ["一", "二", "三", "四", "五"]
	GameState.relics.clear()
	GameState.relic_counters.clear()
	var deck_n := GameState.deck_size()
	GameState.add_relic("fireman")
	_ok(ex.tray.size() == 6 and GameState.deck_size() == deck_n + 3, "余烬匣（远征）：字匣满了按原规则进字袋")
	GameState.expedition = null
	_reset(["egg"])
	n = GameState.deck_size()
	for i in 7:
		Relics.on_battle_won()
	_ok(GameState.deck_size() == n + 1, "发明蛋：赢 4 场给 1 枚字（7 场 = 1 枚）")
	Relics.on_battle_won()
	_ok(GameState.deck_size() == n + 2, "发明蛋：第 8 场再给 1 枚")
	_ok(not GameState.add_relic("egg"), "同一件遗物不能重复获得")


# ---------------------------------------------------------------- 远征接入：开赏遗物 + 商店 + 普通熔炉
func _test_expedition() -> void:
	_reset()
	var ex := Expedition.start(11)
	_ok(not ex.has_method("can_wish") and not ex.has_method("open_wish"), "许愿机入口与逻辑已删除")
	_ok(ex.loot_relic_pool("小").is_empty() and ex.loot_relic_pool("中").size() == 12 and ex.loot_relic_pool("大").size() == 15, "中赏12件、大赏15件遗物候选，小赏不投放")
	var clash: Array = Relics.DEFS.keys().filter(func(id): return Database.words.values().any(func(w): return w.word == Relics.name_of(id)) or Expedition.SEALS.has(Relics.name_of(id)))
	_ok(clash.is_empty(), "遗物名与战斗词、印章不冲突")
	# 奖励选择复用拾取与绑定流程。
	ex.panels = [{"kind":"loot","tier":"大","options":[{"kind":"relic","relic":"slab"}]}]
	ex.choose_loot(0)
	_ok(GameState.has_relic("slab") and ex.top_panel().get("kind", "") == "relic_bind", "开赏获得压字石后自动弹绑定")
	_ok(ex.bind_relic(GameState.deck[0].id()) and GameState.relic_bound_inst("slab") != null, "奖励遗物能绑定字袋实体")
	_ok(not ex.loot_relic_pool("大").has("slab"), "已拥有遗物不再进入奖励池")
	ex.m = MapGen.generate(17, "熔铸坊")
	for k in ex.m.mech:
		if ex.m.mech[k].g == "炉": ex.pos = k; break
	ex.tray = ["击","强","力"]
	ex.panels = [{"kind":"forge","k":ex.pos}]
	var before: Array = GameState.relics.duplicate()
	_ok(not ex.forge(0,0) and ex.tray.size() == 3, "熔炉重复选同一字不吞字")
	_ok(ex.forge(0,1) and GameState.relics == before and ex.tray.size() == 2, "原相关字现在仅换字，不合成遗物")
	ex.panels = [{"kind":"forge","k":ex.pos}]
	_ok(not ex.forge(0,1), "同一熔炉不能反复使用")
	GameState.expedition = null

	# 商店：每家一件遗物；买、卖半价；卖掉以后还能再得到
	_reset()
	ex = Expedition.start(11)
	ex.panels = [{"kind": "shop"}]
	var offers := ex.shop_offers()
	var shelf: Array = offers.filter(func(o): return o.kind == "relic")
	_ok(shelf.size() == 1 and offers.filter(func(o): return o.kind == "glyph").size() == 3, "商店：原来的货不变，另有一件遗物")
	var rid: String = shelf[0].relic
	var cost := ex.price(shelf[0])
	GameState.gold = cost - 1
	_ok(not ex.buy(offers.find(shelf[0])), "商店：钱不够买不了遗物")
	GameState.gold = cost + 10
	_ok(ex.buy(offers.find(shelf[0])) and GameState.has_relic(rid) and GameState.gold == 10, "商店：买下「%s」❖ %d" % [Relics.name_of(rid), cost])
	_ok(not ex.shop_offers().any(func(o): return o.kind == "relic"), "商店：买走后货架空了")
	if ex.top_panel().get("kind", "") == "relic_bind":
		ex.bind_relic(GameState.deck[0].id())
	var gold := GameState.gold
	_ok(ex.sell_relic(rid) and not GameState.has_relic(rid) and GameState.gold == gold + Relics.sell_price(rid), "商店：卖掉遗物拿一半价钱（❖ +%d）" % Relics.sell_price(rid))
	_ok(not GameState.relic_binds.has(rid), "卖掉后绑定一起清掉")
	_ok(ex.loot_relic_pool("大").has(rid), "卖掉的遗物以后还能从大赏获得")
	ex.panels.clear()
	_ok(not ex.sell_relic("strike"), "不在商店里不能卖")
	# 遗物货架不打乱原来商店的货
	_reset()
	var a1 := Expedition.start(21)
	a1.relic_rng.seed = 1
	var g1: Array = a1.shop_offers().filter(func(o): return o.kind != "relic")
	var st1 := a1.rng.state
	_reset()
	var a2 := Expedition.start(21)
	a2.relic_rng.seed = 999
	var g2: Array = a2.shop_offers().filter(func(o): return o.kind != "relic")
	_ok(g1 == g2 and st1 == a2.rng.state, "遗物随机数单独一条：不打乱商店的字和价钱")
	# 精英、首领回到原样：不给遗物
	_reset()
	ex = Expedition.start(11)
	ex.fight = {"kind": "elite", "k": 0, "g": "甲", "name": "守口精英"}
	ex.finish_battle(true)
	_ok(GameState.relics.is_empty() and not ex.panels.any(func(p): return str(p.kind).begins_with("relic")), "精英：只掉印章，不给遗物")
	ex.panels.clear()
	ex.fight = {"kind": "boss", "k": ex.boss, "name": "首领", "g": "墨", "caught": false, "debuff": ""}
	ex.finish_battle(true)
	_ok(ex.boss_down and ex.panels.any(func(p): return p.kind == "act_end"), "首领：不给遗物，自动封层结算")
	# 删掉绑定的字：提示失效，不报错
	_reset(["slab"])
	GameState.relic_binds["slab"] = GameState.deck[0].uid
	GameState.remove_by_uid(GameState.deck[0].uid)
	_ok(GameState.relic_bound_inst("slab") == null, "删掉绑定的字后遗物失效（界面会提示）")
	GameState.expedition = null


# ---------------------------------------------------------------- 全部遗物一起：守恒 + 稳定
func _test_all_relics_smoke() -> void:
	var all: Array = Relics.DEFS.keys()
	var ok_runs := 0
	for seed in [1, 2, 3, 4, 5]:
		_reset()
		for id in all:
			GameState.add_relic(id)
		GameState.bind_relic("slab", GameState.deck[0].id())
		GameState.bind_relic("fertilizer", GameState.deck[1].id())
		var deck_uids: Array = GameState.deck.map(func(c): return c.uid)
		var b := BattleState.new(Database.rules)
		b.start(GameState.make_battle_deck(), [_enemy_data(3, 500), _enemy_data(2, 500)], seed)
		var good := b.board.size == 5
		for t in 12:
			if b.is_over():
				break
			for i in b.board.cells.size():
				var c: CharInstance = b.board.cells[i]
				if c != null and c.data.solo_handler in ["damage", "block_temp", "heat"]:
					b.try_play([Vector2i(i % 5, i / 5)])
					break
			b.end_player_turn()
			# 守恒：每枚永久实体只在一处（字袋 / 弃字堆 / 盘面 / 本场移出）
			for uid in deck_uids:
				var where := 0
				for arr in [b.bag, b.discard, b.removed_this_battle]:
					where += arr.filter(func(x): return x.uid == uid).size()
				where += b.board.cells.filter(func(x): return x != null and x.uid == uid).size()
				var bred: bool = b.breeders.has(uid)
				var fruit: bool = b.fruit_uid == uid
				if where > 1 or (where == 0 and not bred and not fruit and GameState.relic_binds.get("fertilizer", -1) != uid):
					good = false
		if good:
			ok_runs += 1
	_ok(ok_runs == 5, "%d 件遗物同时持有：5 个种子各打 12 回合，不报错、永久实体守恒（%d/5）" % [Relics.DEFS.size(), ok_runs])


# ---------------------------------------------------------------- 审查修复
func _test_review_fixes() -> void:
	# 刑卒护指：【连击】重演不加 +2
	var hits: Array = []
	for has_strike in [false, true]:
		var b := _battle(["strike"] if has_strike else [])
		_play_word(b, "回击")
		var hp: int = b.enemies[0].hp
		_play_word(b, "连击", 1)
		hits.append(hp - b.enemies[0].hp)
	_ok(hits[0] == hits[1], "刑卒护指：【连击】重演不吃 +2（%d / %d）" % hits)
	# 孕字卵：用遗物随机数，不动远征主随机数
	_reset(["egg"])
	var ex := Expedition.start(41)
	GameState.relics.append("egg")
	GameState.relic_counters["egg"] = 3
	var st := ex.rng.state
	Relics.on_battle_won()
	_ok(ex.rng.state == st, "孕字卵：发字用遗物随机数，不改远征主随机数")
	GameState.expedition = null
	# 余烬匣：卖掉再拿不重复给火
	_reset()
	GameState.add_relic("fireman")
	var n := GameState.deck_size()
	GameState.remove_relic("fireman")
	GameState.add_relic("fireman")
	_ok(GameState.deck_size() == n, "余烬匣：卖掉再拿到，不再给 4 枚【火】")
	# 删字：同字形先删没被绑定的
	_reset(["slab"])
	var gid: String = GameState.deck[0].id()
	var copies: Array = GameState.deck.filter(func(c): return c.id() == gid)
	GameState.relic_binds["slab"] = copies[0].uid
	if copies.size() > 1:
		GameState.remove_character_id(gid)
		_ok(GameState.relic_bound_inst("slab") != null, "删字：同字形有多枚时先删没被绑定的，坠字石不失效")
	else:
		_ok(true, "（起始字袋第一枚没有重复，跳过）")
