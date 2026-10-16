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
	_test_press()
	_test_strike_breach()
	_test_opening_defense()
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
	_ok(b.enemies[0].status_stacks("vulnerable") == 2, "破防：敌方易伤和原规则一样不随回合衰减")

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
	ex.active = {"护盾": []}
	ex.fight = {"kind": "foe", "k": 0, "g": "爆", "name": "明敌"}
	var s := BattleState.new(Database.rules)
	s.start(GameState.make_battle_deck(), [_enemy_data()], 7)
	ex.apply_battle_setup(s)
	_ok(s.player.block == 14, "屏障 + 远征「护盾」：10 + 4 = 14 叠加（%d）" % s.player.block)
	# 伏兵先手：屏障能挡住开场突袭
	ex.fight = {"kind": "ambush", "k": 0, "amb": 0, "g": "伏", "name": "伏兵"}
	ex.active = {}
	s = BattleState.new(Database.rules)
	s.start(GameState.make_battle_deck(), [_enemy_data(8)], 7)
	ex.apply_battle_setup(s)
	_ok(s.player.hp == GameState.player_hp and s.player.block == 2, "屏障：伏兵开场突袭 8 伤先被临挡吸收（剩 %d）" % s.player.block)
	GameState.expedition = null


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


# ---------------------------------------------------------------- 天火
func _test_skyfire() -> void:
	for has_relic in [false, true]:
		var b := _battle(["skyfire"] if has_relic else [])
		var e: Combatant = b.enemies[0]
		_place(b, Vector2i(3, 3), "热")
		b.player.heat = 5
		var r := _play_word(b, "流火")
		if has_relic:
			_ok(r.ok and e.hp == 150, "天火：流火追加 50 伤害（%d）" % (200 - e.hp))
			_ok(b.player.heat == 3 and b.bag.any(func(c): return c.glyph() == "热"), "天火：流火原效果保留（热回袋、热度 -2）")
		else:
			_ok(r.ok and e.hp == 200 and b.player.heat == 3, "没有天火：流火只洗热、降热")
	var b2 := _battle(["skyfire", "breach"])
	_play_word(b2, "流火")
	_ok(b2.enemies[0].hp == 200 - 75, "天火 + 破防：50 也吃易伤（75）")
	var b3 := _battle(["skyfire", "strike"])
	b3.player.add_status("strength", 3)
	_play_word(b3, "流火")
	_ok(b3.enemies[0].hp == 150, "天火：算法术伤害，不吃力量、打击增强")


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
	_ok(GameState.deck_size() == n + 4 and GameState.glyph_counts().get("火", 0) >= 4, "火种（主线）：字袋 +4 枚【火】")
	_reset()
	ex = Expedition.start(4)
	GameState.add_relic("fireman")
	_ok(ex.tray.count("火") == 4, "火种（远征）：4 枚【火】先进字匣")
	ex.tray = ["一", "二", "三", "四", "五"]
	GameState.relics.clear()
	GameState.relic_counters.clear()
	var deck_n := GameState.deck_size()
	GameState.add_relic("fireman")
	_ok(ex.tray.size() == 6 and GameState.deck_size() == deck_n + 3, "火种（远征）：字匣满了按原规则进字袋")
	GameState.expedition = null
	_reset(["egg"])
	n = GameState.deck_size()
	for i in 7:
		Relics.on_battle_won()
	_ok(GameState.deck_size() == n + 1, "发明蛋：赢 4 场给 1 枚字（7 场 = 1 枚）")
	Relics.on_battle_won()
	_ok(GameState.deck_size() == n + 2, "发明蛋：第 8 场再给 1 枚")
	_ok(not GameState.add_relic("egg"), "同一件遗物不能重复获得")


# ---------------------------------------------------------------- 远征接入：熔炉许愿 + 商店
func _forge_with(ex: Expedition, gs: Array) -> String:
	var before: Array = GameState.relics.duplicate()
	ex.tray = gs.duplicate()
	ex.panels = [{"kind": "forge", "k": ex.pos}]
	ex.forge(0, 1, 2 if gs.size() > 2 else -1)
	for id in GameState.relics:
		if not before.has(id):
			return id
	return ""


func _test_expedition() -> void:
	# 名字、相关字：只用拿得到的字；每件至少和另一件共用一个字（合成表重叠）
	_reset()
	var ex := Expedition.start(11)
	var pool := {}
	for cd in ex.reward_pool():
		pool[cd.glyph] = true
	var bad: Array = []
	for id in Relics.AFFINITY:
		for g in Relics.AFFINITY[id]:
			if not pool.has(g):
				bad.append("%s:%s" % [id, g])
	_ok(bad.is_empty(), "相关字都在奖励字池里，地图上拿得到 %s" % [bad])
	var lonely: Array = Relics.AFFINITY.keys().filter(func(id): return not Relics.AFFINITY.keys().any(func(o): return o != id and Array(Relics.AFFINITY[id].split("")).any(func(g): return Relics.related(o, g))))
	_ok(lonely.is_empty(), "每件遗物的相关字都和别的遗物有重叠 %s" % [lonely])
	var clash: Array = Relics.DEFS.keys().filter(func(id): return Database.words.values().any(func(w): return w.word == Relics.name_of(id)) or Lexicon.WORDS.has(Relics.name_of(id)) or Expedition.SEALS.has(Relics.name_of(id)))
	_ok(clash.is_empty(), "遗物名不和战斗词、词谱词、印章重名 %s" % [clash])
	# 概率：相关字越多越高；不相关不出；已有的不再出
	var o0 := Relics.wish_chance(["冷", "冷"], [])
	var o1 := Relics.wish_chance(["击", "冷"], [])
	var o2 := Relics.wish_chance(["击", "强"], [])
	var o3 := Relics.wish_chance(["击", "强", "力"], [])
	_ok(o0 < o1 and o1 < o2 and o2 < o3 and o3 <= 0.91, "许愿：相关字 0→1→2→3 个，机会 %.2f → %.2f → %.2f → %.2f" % [o0, o1, o2, o3])
	_ok(Relics.wish_odds(["击", "强", "力"], [])[0].id == "strike", "许愿：击强力 最可能出「刻刀」")
	var fire: Array = Relics.wish_odds(["火", "热"], []).map(func(c): return c.id)
	_ok(fire.has("fireman") and fire.has("skyfire"), "许愿：【火】【热】同时关联「火种」「天火」（重叠）%s" % [fire])
	_ok(not Relics.wish_odds(["火", "热"], ["fireman"]).any(func(c): return c.id == "fireman"), "许愿：已经有的遗物不会再出")
	_ok(Relics.wish_odds(["冷", "冷"], []).is_empty(), "许愿：和遗物都不相关 → 只会熔成稀有字")
	# 真熔：同一种子可复现；熔出遗物就不再给稀有字
	var got := 0
	var glyph_out := 0
	for seed in 40:
		_reset()
		ex = Expedition.start(100 + seed)
		var deck_n := GameState.deck_size()
		var id := _forge_with(ex, ["击", "强", "力"])
		if not id.is_empty():
			got += 1
			if not Relics.AFFINITY[id].contains("击") and not Relics.AFFINITY[id].contains("强") and not Relics.AFFINITY[id].contains("力"):
				got = -999
			if ex.tray.size() + GameState.deck_size() - deck_n > (4 if id == "fireman" else 0):
				got = -999
		elif ex.tray.size() == 1:
			glyph_out += 1
	_ok(got >= 28 and got <= 40 and got + glyph_out == 40, "熔炉：投 3 个相关字，40 次里 %d 次出遗物（约 90%%），其余熔成稀有字" % got)
	got = 0
	for seed in 40:
		_reset()
		ex = Expedition.start(200 + seed)
		if not _forge_with(ex, ["冷", "冷"]).is_empty():
			got += 1
	_ok(got == 0, "熔炉：投不相关的字从不出遗物")
	_reset()
	ex = Expedition.start(5)
	var r1 := _forge_with(ex, ["火", "热", "炼"])
	_reset()
	ex = Expedition.start(5)
	_ok(_forge_with(ex, ["火", "热", "炼"]) == r1, "熔炉：同一种子结果一样（遗物用自己的随机数）")
	# 熔出绑定类 → 弹选字
	_reset()
	ex = Expedition.start(9)
	ex.tray = ["重", "载", "甲"]
	ex.panels = [{"kind": "forge", "k": ex.pos}]
	for i in 30:
		ex.relic_rng.seed = i
		GameState.relics.clear()
		ex.tray = ["重", "载", "甲"]
		ex.panels = [{"kind": "forge", "k": ex.pos}]
		ex.forge(0, 1, 2)
		if GameState.has_relic("slab"):
			break
	_ok(GameState.has_relic("slab") and ex.top_panel().get("kind", "") == "relic_bind", "熔出「压字石」：接着弹选字")
	_ok(ex.bind_relic(GameState.deck[0].id()) and GameState.relic_bound_inst("slab") != null, "绑在字袋里一枚实体上")
	# 熔炉的旧行为：选错参数不吞字
	ex.tray = ["火", "热"]
	ex.panels = [{"kind": "forge", "k": ex.pos}]
	_ok(not ex.forge(0, 0) and ex.tray.size() == 2, "熔炉：同一个字点两次不算")
	GameState.expedition = null

	# 随身许愿机：开局就有，每幕一次，任何地方都能开
	_reset()
	ex = Expedition.start(31)
	ex.tray = ["火"]
	_ok(not ex.can_wish(), "许愿机：字匣不到 2 个字时不能开")
	ex.tray = ["冷", "冷"]
	_ok(ex.can_wish() and ex.open_wish() and ex.top_panel().get("wish", false), "许愿机：开局就带着，地图上随时能打开")
	ex.leave_panel()
	_ok(ex.can_wish() and ex.tray.size() == 2, "许愿机：打开再关掉不算用掉，字也不少")
	ex.open_wish()
	_ok(ex.forge(0, 1) and ex.wish_used and not ex.can_wish(), "许愿机：许过一次，本幕不能再用")
	_ok(ex.tray.size() == 1, "许愿机：不相关的字照旧熔成一个稀有字")
	ex.tray = ["火", "热"]
	_ok(not ex.open_wish(), "许愿机：同一幕第二次打不开")
	ex.fight = {"kind": "foe", "k": 0, "g": "爆", "name": "明敌"}
	_ok(not ex.can_wish(), "许愿机：战斗、面板打开时不能用")
	ex.fight = {}
	ex.load_act(2)
	_ok(ex.can_wish(), "许愿机：进下一幕重新可用")
	var hits := 0
	for seed in 30:
		_reset()
		ex = Expedition.start(700 + seed)
		ex.tray = ["电", "充", "蓄"]
		ex.open_wish()
		ex.forge(0, 1, 2)
		if GameState.has_relic("powerbank"):
			hits += 1
	_ok(hits >= 12, "许愿机：投【电】【充】【蓄】，30 次里 %d 次熔出「蓄电瓶」（同熔炉概率）" % hits)
	_ok(not ex.used.has(-1) or ex.used.get(-1, 0) <= 1, "许愿机不占地图上熔炉的使用次数")
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
	_ok(Relics.wish_odds(Array(Relics.AFFINITY[rid].split("")), GameState.relics).any(func(c): return c.id == rid), "卖掉的遗物以后还能再熔出来")
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
	_ok(ex.boss_down and ex.top_panel().is_empty(), "首领：不给遗物，回地图继续探索")
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
				if where > 1 or (where == 0 and not bred and GameState.relic_binds.get("fertilizer", -1) != uid):
					good = false
		if good:
			ok_runs += 1
	_ok(ok_runs == 5, "15 件遗物同时持有：5 个种子各打 12 回合，不报错、永久实体守恒（%d/5）" % ok_runs)


# ---------------------------------------------------------------- 审查修复
func _test_review_fixes() -> void:
	# 刻刀：【连击】重演不加 +2
	var hits: Array = []
	for has_strike in [false, true]:
		var b := _battle(["strike"] if has_strike else [])
		_play_word(b, "回击")
		var hp: int = b.enemies[0].hp
		_play_word(b, "连击", 1)
		hits.append(hp - b.enemies[0].hp)
	_ok(hits[0] == hits[1], "刻刀：【连击】重演不吃 +2（%d / %d）" % hits)
	# 字种：用遗物随机数，不动远征主随机数
	_reset(["egg"])
	var ex := Expedition.start(41)
	GameState.relics.append("egg")
	GameState.relic_counters["egg"] = 3
	var st := ex.rng.state
	Relics.on_battle_won()
	_ok(ex.rng.state == st, "字种：发字用遗物随机数，不改远征主随机数")
	GameState.expedition = null
	# 火种：卖掉再拿不重复给火
	_reset()
	GameState.add_relic("fireman")
	var n := GameState.deck_size()
	GameState.remove_relic("fireman")
	GameState.add_relic("fireman")
	_ok(GameState.deck_size() == n, "火种：卖掉再拿到，不再给 4 枚【火】")
	# 删字：同字形先删没被绑定的
	_reset(["slab"])
	var gid: String = GameState.deck[0].id()
	var copies: Array = GameState.deck.filter(func(c): return c.id() == gid)
	GameState.relic_binds["slab"] = copies[0].uid
	if copies.size() > 1:
		GameState.remove_character_id(gid)
		_ok(GameState.relic_bound_inst("slab") != null, "删字：同字形有多枚时先删没被绑定的，压字石不失效")
	else:
		_ok(true, "（起始字袋第一枚没有重复，跳过）")
