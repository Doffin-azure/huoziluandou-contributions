extends Control
## 遗物第二批：清单里剩下的条目逐件验证默认规则。
## 空铅盒、留字蜡、朱砂印泥、补字鬼手、裂墨瓶、褪墨、乱文骨骰已由主分支实现，测试在 relic_test。

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
	_test_names()
	_test_chain()
	_test_question()
	_test_moon()
	_test_slot_palindrome()
	_test_binding()
	_test_glyph_relics()
	_test_death()
	_test_midas()
	_test_monkey()
	_test_proof()
	await _test_flows()
	GameState.relics.clear()
	GameState.relic_binds.clear()
	GameState.relic_counters.clear()
	GameState.revive_charges = 0
	GameState.expedition = null
	await get_tree().create_timer(0.3).timeout
	print("[relic_batch2_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


# ---------------------------------------------------------------- 工具
func _reset(relics: Array = []) -> void:
	GameState.start_new_run("v03")
	GameState.player_max_hp = 60
	GameState.player_hp = 60
	for r in relics:
		GameState.relics.append(r)


func _enemy_data(dmg := 5, hp := 200) -> EnemyData:
	var ed := EnemyData.new()
	ed.name = "relic_dummy"
	ed.max_hp = hp
	var mv := EnemyMoveData.new()
	mv.kind = EnemyMoveData.Kind.ATTACK
	mv.damage = dmg
	ed.moves.append(mv)
	return ed


func _battle(relics: Array = [], deck: Array = [], opening := 0, turn_draw := 0, dmg := 5) -> BattleState:
	_reset(relics)
	var rules: BattleRules = Database.rules.duplicate()
	rules.opening_draw = opening
	rules.turn_draw = turn_draw
	var b := BattleState.new(rules)
	b.start(deck, [_enemy_data(dmg)], 7)
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


func _deck(glyphs: String) -> Array:
	var out: Array = []
	for g in glyphs:
		out.append(_inst(g))
	return out


func _count(b: BattleState, g: String) -> int:
	return b.board.cells.filter(func(c): return c != null and c.glyph() == g).size()


func _logged(b: BattleState, text: String) -> bool:
	return b.log.any(func(line): return str(line).contains(text))


# ---------------------------------------------------------------- 名字
func _test_names() -> void:
	var names: Array = Relics.DEFS.values().map(func(d): return d[0])
	var unique := {}
	for n in names:
		unique[n] = true
	_ok(unique.size() == Relics.DEFS.size(), "%d 件遗物，名字不重复" % Relics.DEFS.size())
	var words := {}
	for w in Database.words.values():
		words[w.word] = true
	_ok(not names.any(func(n): return words.has(n) or Expedition.SEALS.has(n)), "遗物名不和词、印章重名")
	_ok(Relics.DEFS.keys().all(func(id): return Relics.TIER.has(id)), "每件遗物都有档次")
	_ok(["连字环", "问字签", "月字模", "金字碑", "许愿笺", "判官笔", "生死簿"].all(func(n): return names.has(n)), "新遗物以字为主题命名")


# ---------------------------------------------------------------- 消消乐
func _test_chain() -> void:
	var b := _battle(["chain"])
	_clear_board(b)
	_place(b, Vector2i(0, 3), "击")
	_place(b, Vector2i(1, 3), "破")
	_place(b, Vector2i(3, 0), "防")
	var hp: int = b.enemies[0].hp
	Relics.run_chain(b)
	_ok(b.enemies[0].hp < hp and _logged(b, "自动打出【击破】"), "连字环：开局自动打出已连成的【击破】")
	_ok(b.board.get_cell(3, 3) != null and b.board.get_cell(3, 3).glyph() == "防", "连字环：出字后全盘下落")
	_clear_board(b)
	_place(b, Vector2i(0, 3), "死")
	_place(b, Vector2i(1, 3), "亡")
	Relics.run_chain(b)
	_ok(b.player.is_alive() and _count(b, "死") == 1, "连字环：不会自动打出【死亡】")
	var no := _battle([])
	_clear_board(no)
	_place(no, Vector2i(0, 3), "击")
	_place(no, Vector2i(1, 3), "破")
	Relics.run_chain(no)
	_ok(_count(no, "击") == 1, "没有连字环时不自动出词")


# ---------------------------------------------------------------- 问字签
func _test_question() -> void:
	var b := _battle(["question"], _deck("击防"), 2)
	_ok(b.question_choices.size() == 3, "问字签：开局给出 3 枚候选")
	var pick: String = b.question_choices[0]
	var before := _count(b, pick)
	_ok(not b.take_question("不在候选里"), "问字签：不在候选里的字不能拿")
	_ok(b.take_question(pick) and _count(b, pick) == before + 1 and b.question_choices.is_empty(), "问字签：选中的字落到盘上，只能选一次")
	var placed: Array = b.board.cells.filter(func(c): return c != null and c.glyph() == pick and c.temporary)
	_ok(not placed.is_empty() and b.temp_chars.has(placed[0]), "问字签：落下的是本场临时字")


# ---------------------------------------------------------------- 月
func _test_moon() -> void:
	var b := _battle(["moon"], _deck("击击防防"), 4, 0, 0)
	_ok(_count(b, "月") == 1 and b.moon_uid >= 0, "月字模：开局盘上有一枚临时【月】")
	var moon := Relics.moon_pos(b)
	_clear_board(b)
	b.board.set_xy(Vector2i(0, 0), b.temp_chars.filter(func(c): return c.uid == b.moon_uid)[0])
	_place(b, Vector2i(3, 3), "防")
	_place(b, Vector2i(3, 0), "击")
	b.try_play([Vector2i(3, 0)])
	_ok(b.board.get_cell(3, 3) == null, "月字模：出字后其他字向【月】聚拢")
	b.end_player_turn()
	_ok(_count(b, "月") == 0 and b.moon_uid == -1, "月字模：下回合消失")
	var b2 := _battle(["moon"], [], 0, 0, 0)
	_clear_board(b2)
	_place(b2, Vector2i(1, 1), "月")
	_place(b2, Vector2i(3, 3), "防")
	_ok(b2.try_play([Vector2i(1, 1)]).ok and b2.board.get_cell(3, 3) == null, "月字模：打出【月】也会聚拢一次（%s）" % str(moon))


# ---------------------------------------------------------------- 叠字钱 / 反字模
func _test_slot_palindrome() -> void:
	var b := _battle(["slot"])
	var plain: BattleState
	var gold := GameState.gold
	var r := _play_word(b, "击击击")
	_ok(r.ok and GameState.gold == gold + 50 and _count(b, "击") == 0, "叠字钱：三连相同字拿 50 金币，三枚都消耗")
	plain = _battle([])
	_ok(not _play_word(plain, "击击击").ok, "没有叠字钱时三连相同字不成词")

	b = _battle(["palindrome"])
	var hp: int = b.enemies[0].hp
	r = _play_word(b, "破击")
	_ok(r.ok and r.word != null and r.word.word == "击破" and b.enemies[0].hp < hp, "反字模：倒着连【破击】发动【击破】")
	plain = _battle([])
	_ok(not _play_word(plain, "破击").ok, "没有反字模时倒连不成词")


# ---------------------------------------------------------------- 装订线
func _test_binding() -> void:
	var b := _battle(["binding"])
	_clear_board(b)
	_place(b, Vector2i(3, 1), "击")
	_place(b, Vector2i(0, 1), "破")
	_ok(b.board.wrap_rows and b.try_play([Vector2i(3, 1), Vector2i(0, 1)]).ok, "串字绳：最右和最左两格相邻，可以跨边连词")
	var plain := _battle([])
	_clear_board(plain)
	_place(plain, Vector2i(3, 1), "击")
	_place(plain, Vector2i(0, 1), "破")
	_ok(not plain.try_play([Vector2i(3, 1), Vector2i(0, 1)]).ok, "没有串字绳时不能跨边")
	_clear_board(b)
	_place(b, Vector2i(3, 1), "击")
	_place(b, Vector2i(0, 2), "破")
	_ok(not b.try_play([Vector2i(3, 1), Vector2i(0, 2)]).ok, "串字绳：只连同一行")


# ---------------------------------------------------------------- 战外挑字：泥金笔 / 复字拓片
func _test_glyph_relics() -> void:
	_reset()
	GameState.deck.assign(_deck("击击防"))
	GameState.add_relic("goldleaf")
	var ji := Database.get_character_by_glyph("击").id
	_ok(Relics.apply_pick("goldleaf", ji) and Relics.apply_pick("goldleaf", ji), "泥金笔：两枚【击】镀金")
	_ok(GameState.deck.filter(func(c): return c.gilded).size() == 2 and not Relics.apply_pick("goldleaf", ji), "泥金笔：已镀金的不再算候选")
	GameState.add_relic("rubbing")
	var n := GameState.deck_size()
	_ok(Relics.apply_pick("rubbing", ji) and GameState.deck_size() == n + 1 and GameState.deck.back().gilded, "复字拓片：复制一枚字，保留镀金")
	_ok(GameState.deck.back().uid != GameState.deck[0].uid, "复字拓片：复制出来的是新实体")


# ---------------------------------------------------------------- 死 / 亡 / 死亡 / 反死亡
func _test_death() -> void:
	_ok(BattleBalance.warning.is_empty() and BattleBalance.i("judge_brush_vulnerable", -1) > 0 and BattleBalance.i("ruin_revive_percent", -1) > 0, "战斗数值表接入判官笔/生死簿参数（warning=%s）" % BattleBalance.warning)
	_reset()
	GameState.add_relic("death")
	GameState.add_relic("ruin")
	_ok(GameState.deck.any(func(c): return c.glyph() == "死") and GameState.deck.any(func(c): return c.glyph() == "亡"), "判官笔、生死簿：拾取时得到【死】【亡】")
	var si := Database.get_character_by_glyph("死")
	var wang := Database.get_character_by_glyph("亡")
	_ok(si.is_pollution and wang.is_pollution and si.solo_effects.is_empty() and wang.solo_effects.is_empty(), "【死】【亡】记为污染字且没有单字效果")

	# 单打无收益，只腾出空格
	var b := _battle(["death"], [], 0, 0)
	var hp: int = b.enemies[0].hp
	_clear_board(b)
	_place(b, Vector2i.ZERO, "死")
	var solo := b.try_play([Vector2i.ZERO])
	_ok(solo.ok and b.enemies[0].hp == hp and b.board.get_xy(Vector2i.ZERO) == null, "【死】单打无效果，只腾出空格")

	# 判官笔：敌人首次跌破半血追加 4 层易伤，每个敌人每场一次
	b = _battle(["death"], [], 0, 0)
	var e: Combatant = b.enemies[0]
	b.deal_damage(e, 101, true)
	var brush_stacks := BattleBalance.i("judge_brush_vulnerable", 4)
	_ok(e.hp == 99 and e.status_stacks("vulnerable") == brush_stacks, "判官笔：跌破半血追加 %d 层易伤（hp %d，当前 %d 层）" % [brush_stacks, e.hp, e.status_stacks("vulnerable")])
	b.deal_damage(e, 1, true)
	_ok(e.status_stacks("vulnerable") == brush_stacks, "判官笔：每个敌人每场只触发一次")
	b = _battle([], [], 0, 0)
	b.deal_damage(b.enemies[0], 101, true)
	_ok(b.enemies[0].status_stacks("vulnerable") == 0, "没有判官笔时不会触发半血易伤")

	# 生死簿：倒下时以 20% 最大生命复活，每场一次
	b = _battle(["ruin"], [], 0, 0)
	b.player.take_damage(999)
	var ruin_percent := BattleBalance.i("ruin_revive_percent", 20)
	var expect := int(round(b.player.max_hp * ruin_percent / 100.0))
	var revived := not b.is_over()
	_ok(revived and b.player.hp == expect, "生死簿：倒下时以 20%% 气血复活（%d／%d）" % [b.player.hp, b.player.max_hp])
	b.player.take_damage(999)
	_ok(b.is_over() and not b.is_victory(), "生死簿：每场只救一次")

	# 生死簿优先消耗，保留本局反死亡的满血复活
	b = _battle(["ruin"], [], 0, 0)
	GameState.revive_charges = 1
	b.player.take_damage(999)
	b.is_over()
	_ok(b.player.hp == expect and GameState.revive_charges == 1, "生死簿优先于反死亡，保留本局复活次数")
	b.player.take_damage(999)
	b.is_over()
	_ok(b.player.hp == b.player.max_hp and GameState.revive_charges == 0, "第二次倒下才消耗反死亡的满血复活")
	GameState.revive_charges = 0

	# 彩蛋词本身的流程（不带生死簿）
	b = _battle([], [], 0, 0)
	GameState.revive_charges = 0
	var r := _play_word(b, "反死亡", 1)
	_ok(r.ok and GameState.revive_charges == 1, "【反死亡】：本局获得一次复活")
	_play_word(b, "反死亡", 2)
	_ok(GameState.revive_charges == 1, "【反死亡】：一局只给一次")
	_play_word(b, "死亡", 3)
	_ok(not b.is_over() and b.player.hp == b.player.max_hp and GameState.revive_charges == 0, "【死亡】：有复活机会时满血站起")
	_play_word(b, "死亡", 3)
	_ok(b.is_over() and not b.is_victory(), "【死亡】：没有复活机会就死")


# ---------------------------------------------------------------- 迈达斯之手
func _test_midas() -> void:
	_reset()
	GameState.deck.assign(_deck("击防"))
	GameState.add_relic("midas")
	_ok(GameState.deck.all(func(c): return c.gilded), "金字碑：现有字全部镀金")
	GameState.add_character(Database.get_character_by_glyph("破"))
	_ok(GameState.deck.back().gilded, "金字碑：之后拿到的字也镀金")
	var b := BattleState.new(Database.rules.duplicate())
	b.start([], [_enemy_data()], 3)
	b.earn_gold(19)
	_ok(b.player.is_alive(), "金字碑：19 金币还活着")
	b.earn_gold(1)
	_ok(not b.player.is_alive() and b.is_over(), "金字碑：一场赚满 20 金币化为金像")


# ---------------------------------------------------------------- 猴爪
func _test_monkey() -> void:
	_reset(["monkey"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	_ok(Relics.wish_options(rng).size() == 3, "许愿笺：从 4 个愿望里展示 3 个")
	_ok(Relics.grant_wish("endless_guard") and GameState.player_max_hp == 1 and GameState.player_hp == 1, "固若金汤：生命上限变为 1")
	_ok(not Relics.grant_wish("endless_life"), "许愿笺：一件只能许一次")
	var b := BattleState.new(Database.rules.duplicate())
	b.start([], [_enemy_data()], 3)
	_ok(b.player.persistent_block == 118, "固若金汤：开局持久盾 = 2 × 失去的上限（2 × 59）")

	_reset(["monkey"])
	GameState.deck.assign(_deck("击防破"))
	var fang := Database.get_character_by_glyph("防").id
	_ok(Relics.grant_wish("endless_glyph", fang) and GameState.deck.all(func(c): return c.glyph() == "防"), "千字同文：字袋全部变成【防】")
	GameState.add_character(Database.get_character_by_glyph("击"))
	_ok(GameState.deck.back().glyph() == "防", "千字同文：之后拿到的字也变成【防】")
	b = BattleState.new(Database.rules.duplicate())
	b.start(GameState.make_battle_deck(), [_enemy_data()], 3)
	_ok(GameState.deck.all(func(c): return c.temporary_uses == 2), "千字同文：每场额外使用 +2")

	_reset(["monkey"])
	Relics.grant_wish("endless_life")
	b = BattleState.new(Database.rules.duplicate())
	b.start([], [_enemy_data()], 3)
	_ok(not b.player.is_alive(), "生生不息：满血时 99 点溢出全部反噬")
	_reset(["monkey", "amber"])
	Relics.grant_wish("endless_life")
	b = BattleState.new(Database.rules.duplicate())
	b.start([], [_enemy_data()], 3)
	_ok(b.player.is_alive() and b.player.persistent_block >= 99, "生生不息 + 朱砂印泥：溢出先转成持久盾")

	_reset(["monkey"])
	_ok(Relics.grant_wish("endless_gold") and GameState.has_relic("midas"), "点石成金：得到金字碑")
	_reset(["monkey", "midas"])
	rng.seed = 9
	_ok(not Relics.wish_options(rng).has("endless_gold"), "已有金字碑时不出「点石成金」")


# ---------------------------------------------------------------- 校勘尺
func _test_proof() -> void:
	var b: BattleState
	b = _battle(["proof"], _deck("防防防"))
	_clear_board(b)
	for x in 2:
		_place(b, Vector2i(x, 0), "击").add_pollution("scorch")
	var before := b.board.cells.filter(func(c): return c != null).size()
	b.cleanse_board()
	_ok(b.board.cells.filter(func(c): return c != null).size() == before + 1, "校勘尺：净化 2 枚污染字，补 1 字")


# ---------------------------------------------------------------- 拾取流程（经典 + 远征）
func _test_flows() -> void:
	var host := Control.new()
	add_child(host)
	_reset()
	GameState.deck.assign(_deck("击防"))
	var got := {"id": "-"}
	RelicRewardFlow.grant(host, "monkey", func(id): got.id = id)
	await get_tree().process_frame
	var choice: ChoiceOverlay = host.get_children().filter(func(c): return c is ChoiceOverlay).front()
	_ok(choice != null and choice.cfg.options.size() == 3, "经典模式：许愿笺弹出三个愿望")
	var at: int = choice.cfg.options.find_custom(func(o): return o.text.contains("固若金汤"))
	if at < 0:
		at = choice.cfg.options.find_custom(func(o): return not o.text.contains("千字同文"))
	choice._on_choose(at)
	await get_tree().process_frame
	_ok(got.id == "monkey" and GameState.relic_counters.has("monkey"), "经典模式：选完愿望就许下")

	_reset()
	GameState.deck.assign(_deck("击防"))
	RelicRewardFlow.grant(host, "goldleaf", func(id): got.id = id)
	for i in 2:
		await get_tree().process_frame
		var picker: CollectionOverlay = host.get_children().filter(func(c): return c is CollectionOverlay and c.is_inside_tree() and not c.is_queued_for_deletion()).back()
		picker._close()
	await get_tree().process_frame
	_ok(got.id == "goldleaf" and GameState.deck.all(func(c): return c.gilded), "经典模式：泥金笔关窗也会随机挑满两枚")

	_reset()
	var ex := Expedition.start(5)
	GameState.deck.assign(_deck("击防防"))
	ex._grant_relic("goldleaf", "测试")
	_ok(ex.top_panel().get("kind", "") == "relic_pick", "远征：泥金笔弹出挑字面板")
	ex.pick_relic(Database.get_character_by_glyph("防").id)
	ex.pick_relic(Database.get_character_by_glyph("防").id)
	_ok(ex.top_panel().get("kind", "") != "relic_pick" and GameState.deck.filter(func(c): return c.gilded).size() == 2, "远征：挑满两枚后面板关闭")
	_ok(Relics.normal_pool().all(func(id): return ex.loot_relic_pool("大").has(id) or GameState.has_relic(id)), "远征：大赏遗物池包含全部普通遗物")
	_ok(Relics.roll_choices([], GameState.rng, 99).size() == Relics.normal_pool().size() and Relics.normal_pool().has("monkey"), "经典：商店 / 精英 / 首领 / 事件的候选覆盖全部普通遗物，含第二批")
	ex._grant_relic("monkey", "测试")
	var wish_panel := ex.top_panel()
	_ok(wish_panel.get("kind", "") == "relic_wish" and wish_panel.options.size() == 3, "远征：许愿笺弹出三个愿望")
	var pick: int = wish_panel.options.find("endless_glyph")
	if pick >= 0:
		_ok(not ex.choose_wish(pick), "远征：千字同文没挑字不能许")
	var other: int = 0 if wish_panel.options[0] != "endless_glyph" else 1
	_ok(ex.choose_wish(other) and ex.top_panel().get("kind", "") != "relic_wish", "远征：许愿后面板关闭")
	GameState.relic_counters["monkey"] = {"wish": "endless_glyph", "glyph": Database.get_character_by_glyph("防").id}
	var before_gain := GameState.deck_size()
	ex.gain_glyph("击", "测试")
	_ok(GameState.deck_size() == before_gain + 1 and GameState.deck[-1].glyph() == "防", "远征：新字直接入字袋，仍遵循千字同文")
	GameState.expedition = null
	host.queue_free()
