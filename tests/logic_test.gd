extends Node
## 白盒逻辑测试（无渲染，可重复运行）。
##   godot --headless --script res://tests/logic_test.gd
## 覆盖 V0.2 的关键规则：临挡/持久盾、污染代价、过热入袋、重合守恒、回原位换字、反击、敌方注入。

var _pass := 0
var _fail := 0


func _ready() -> void:
	_run()


func _run() -> void:
	_test_defense_block()
	_test_persistent_shield()
	_test_pollution_rush()
	_test_heat_overflow()
	_test_merge_duplicates()
	_test_replace_self()
	_test_counter()
	_test_enemy_inject()
	_test_break_shield()
	_test_equity_cycle()
	_test_energy_heat_conversions()
	_test_scaling_attacks()
	_test_cold_snap()
	_test_ceasefire()
	_test_ignite()
	_test_repeat_zero()
	_test_mint()
	_test_buyback()
	_test_gravity_always()
	_test_temp_funds_payment()
	_test_transform_board()
	_test_split_grow()
	_test_empower()
	_test_cremate()
	_test_fuse()
	_test_refine_layer()
	_test_vigor()
	_test_jingjin()
	_test_jingzhu()
	_test_jingfen()
	_test_formation()
	_test_blast_preconsume()
	_test_blackout()
	_test_charge_overheat()
	_test_recast()
	_test_recast_copy()
	_test_repeat_last()
	_test_reverse_line()
	_test_merge_flow()
	_test_hard_stop()
	_test_repeat_word()
	_test_fireproof()
	_test_blastproof()
	_test_joint_funding()
	_test_profit_share()
	_test_suspend()
	_test_refine_remove()
	_test_direction_words()
	_test_edge_batch1()
	_test_edge_batch2()
	print("\n[logic_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit()


func _ok(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ✓ ", label)
	else:
		_fail += 1
		print("  ✗ ", label)


func _battle() -> BattleState:
	var b := BattleState.new(Database.rules)
	b.start([], [])
	b.player.hp = 60
	# 清空开局随机盘（用空字袋后应为空）
	for i in b.board.cells.size():
		b.board.cells[i] = null
	return b


func _place(b: BattleState, x: int, y: int, glyph: String, owner := CharInstance.Owner.PLAYER) -> CharInstance:
	var cd: CharacterData = Database.get_character_by_glyph(glyph)
	var inst := CharInstance.new(cd)
	inst.owner = owner
	b.board.set_cell(x, y, inst)
	return inst


func _find(b: BattleState, glyph: String) -> Vector2i:
	for i in b.board.cells.size():
		var c: CharInstance = b.board.cells[i]
		if c != null and c.glyph() == glyph:
			return b.board.to_xy(i)
	return Vector2i(-1, -1)


func _test_defense_block() -> void:
	print("[防御] 10 临挡")
	var b := _battle()
	_place(b, 0, 0, "防")
	_place(b, 1, 0, "御")
	var r := b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(r.ok and b.player.block == 10, "防御 获得 10 临挡")


func _test_persistent_shield() -> void:
	print("[护盾] 6 持久盾，敌行动后保留")
	var b := _battle()
	_place(b, 0, 0, "护")
	_place(b, 1, 0, "盾")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.player.persistent_block == 6, "护盾 获得 6 持久盾")
	b.end_player_turn()
	_ok(b.player.persistent_block == 6, "敌行动后持久盾仍为 6")


func _test_pollution_rush() -> void:
	print("[污染·刺痛] 打出失 2 血且敌方字消失")
	var b := _battle()
	var inst := _place(b, 0, 0, "蚀", CharInstance.Owner.ENEMY)
	inst.add_pollution("rush")
	var hp0 := b.player.hp
	var r := b.try_play([Vector2i(0, 0)])
	_ok(r.ok and b.player.hp == hp0 - 2, "刺痛失去 2 生命")
	_ok(b.board.get_cell(0, 0) == null and not b.discard.has(inst), "敌方字被消耗后未进弃字堆")


func _test_heat_overflow() -> void:
	print("[过热] 溢出向字袋塞灼热【热】")
	var b := _battle()
	b.player.heat_capacity = 5
	b.add_heat(8)
	var scorch := 0
	for c in b.bag:
		if c.glyph() == "热" and c.has_pollution("scorch"):
			scorch += 1
	_ok(scorch == 3, "溢出 3 点生成 3 枚灼热【热】")


func _test_merge_duplicates() -> void:
	print("[重合] 保留 1 实体 + 3 临时层，其余回袋")
	var b := _battle()
	_place(b, 0, 0, "重")
	_place(b, 1, 0, "合")
	var anchor := _place(b, 0, 1, "击")
	_place(b, 1, 1, "击")
	_place(b, 2, 2, "击")
	_place(b, 3, 3, "击")
	var r := b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(0, 1)})
	var ji_count := 0
	for c in b.board.cells:
		if c != null and c.glyph() == "击":
			ji_count += 1
	_ok(r.ok and anchor.temporary_uses == 3, "重合：临时层 = 3（4 次总使用）")
	_ok(ji_count == 1, "盘面只剩 1 枚【击】")


func _test_replace_self() -> void:
	print("[回] 原位随机换字")
	var b := _battle()
	_place(b, 0, 0, "回")
	var cd: CharacterData = Database.get_character_by_glyph("击")
	b.bag.append(CharInstance.new(cd))
	var r := b.try_play([Vector2i(0, 0)])
	_ok(r.ok and b.board.get_cell(0, 0) != null and b.board.get_cell(0, 0).glyph() != "回",
		"原位被换成另一枚字（无需选目标）")


func _test_counter() -> void:
	print("[反击] 延迟结算剩余临挡转伤害")
	var b := _battle()
	b.enemies.clear()
	var ed: EnemyData = Database.get_enemy("ink_spirit")
	var e := Combatant.new(ed.name, ed.max_hp, false)
	e.enemy_data = ed
	e.move_index = 0
	b.enemies.append(e)
	_place(b, 0, 0, "反")
	_place(b, 1, 0, "击")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	var hp_before := e.hp
	b.end_player_turn()
	_ok(e.hp < hp_before, "反击在敌行动后造成伤害（%d -> %d）" % [hp_before, e.hp])


func _test_enemy_inject() -> void:
	print("[敌方注入] 生成敌方所有权的污染字")
	var b := _battle()
	b.inject_enemy_glyphs(1, "rush")
	var found := false
	for c in b.board.cells:
		if c != null and c.is_enemy_owned() and c.has_pollution("rush"):
			found = true
	_ok(found, "注入了一个敌方刺痛字")


func _test_break_shield() -> void:
	print("[击破] 拆盾效率翻倍")
	var b := _battle()
	b.enemies.clear()
	var ed: EnemyData = Database.get_enemy("ink_spirit")
	var e := Combatant.new(ed.name, ed.max_hp, false)
	e.enemy_data = ed
	e.block = 20
	b.enemies.append(e)
	_place(b, 0, 0, "击")
	_place(b, 1, 0, "破")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(e.block < 20, "击破对护盾造成翻倍削减（剩余 %d）" % e.block)


func _add_enemy(b: BattleState, hp := 200, block := 0) -> Combatant:
	var ed: EnemyData = Database.get_enemy("ink_spirit")
	var e := Combatant.new(ed.name, hp, false)
	e.enemy_data = ed
	e.block = block
	b.enemies.append(e)
	return e


func _test_equity_cycle() -> void:
	print("[投资/复利/利息/炼金] 股权闭环")
	var b := _battle()
	var g0 := GameState.gold
	GameState.gold = 100
	_place(b, 0, 0, "复")
	_place(b, 1, 0, "利")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_place(b, 0, 1, "投")
	_place(b, 1, 1, "资")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	_ok(b.player.equity == 4, "投资 3 + 复利 1 = 4 股权（当前 %d）" % b.player.equity)
	_ok(GameState.gold == 97, "锁定 3 金币（当前 %d）" % GameState.gold)
	_place(b, 0, 2, "利")
	_place(b, 1, 2, "息")
	b.try_play([Vector2i(0, 2), Vector2i(1, 2)])
	_ok(b.player.equity == 3 and GameState.gold == 99, "利息：-1 股权 +2 金币")
	_place(b, 0, 3, "炼")
	_place(b, 1, 3, "金")
	b.try_play([Vector2i(0, 3), Vector2i(1, 3)])
	_ok(b.player.equity == 0 and GameState.gold == 108, "炼金：3 股权换 9 金币")
	GameState.gold = g0


func _test_energy_heat_conversions() -> void:
	print("[蓄放] 储能/热度互转")
	var b := _battle()
	b.player.heat = 6
	_place(b, 0, 0, "热")
	_place(b, 1, 0, "能")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.player.energy == 6 and b.player.heat == 0, "热能：热度 6 → 储能 6")
	_place(b, 0, 1, "蓄")
	_place(b, 1, 1, "力")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	_ok(b.player.energy == 0 and b.ability_value("next_energy_bonus") == 12, "蓄力：6 储能 → 下击 +12")
	b.player.heat = 5
	_place(b, 0, 2, "热")
	_place(b, 1, 2, "力")
	b.try_play([Vector2i(0, 2), Vector2i(1, 2)])
	_ok(b.player.heat == 0 and b.player.status_stacks("next_bonus") == 10, "热力：热度 5 → 下击 +10")


func _test_scaling_attacks() -> void:
	print("[电击/火力] 资源缩放伤害")
	var b := _battle()
	var e := _add_enemy(b, 200)
	b.player.energy = 3
	_place(b, 0, 0, "电")
	_place(b, 1, 0, "击")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(e.hp == 200 - 12, "电击：6 + 2×3储能 = 12 伤（实际 %d）" % (200 - e.hp))
	b.enemies.clear()
	var e2 := _add_enemy(b, 200)
	b.player.heat = 3
	_place(b, 0, 1, "火")
	_place(b, 1, 1, "力")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	_ok(e2.hp == 200 - 12, "火力：6 + 2×3热度 = 12 伤（实际 %d）" % (200 - e2.hp))


func _test_cold_snap() -> void:
	print("[爆冷] 按上回合失血缩放")
	var b := _battle()
	var e := _add_enemy(b, 200)
	b.damage_taken_last_turn = 5
	_place(b, 0, 0, "爆")
	_place(b, 1, 0, "冷")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(200 - e.hp == 14, "爆冷：4 + 2×5 = 14 伤（实际 %d）" % (200 - e.hp))


func _test_ceasefire() -> void:
	print("[停火] 无伤则免敌方攻击")
	var b := _battle()
	_add_enemy(b, 200)
	_place(b, 0, 0, "停")
	_place(b, 1, 0, "火")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	var hp0 := b.player.hp
	b.end_player_turn()
	_ok(b.player.hp == hp0, "停火后本回合未造成敌伤，免疫攻击（HP %d→%d）" % [hp0, b.player.hp])


func _test_ignite() -> void:
	print("[放火] 持续灼烧")
	var b := _battle()
	var e := _add_enemy(b, 200)
	b.player.heat = 2
	_place(b, 0, 0, "放")
	_place(b, 1, 0, "火")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	var before := e.hp
	b.end_player_turn()
	_ok(e.hp == before - 5, "放火：3+2热度 = 5 灼烧伤（实际 %d）" % (before - e.hp))


func _test_repeat_zero() -> void:
	print("[反复] 首次无效果单字原位补字")
	var b := _battle()
	_place(b, 0, 0, "反")
	_place(b, 1, 0, "复")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	var cd: CharacterData = Database.get_character_by_glyph("洗")
	b.bag.append(CharInstance.new(cd))
	_place(b, 2, 2, "洗")
	b.try_play([Vector2i(2, 2)])
	_ok(b.board.get_cell(2, 2) != null, "反复：原格被补回一枚新字")


func _test_mint() -> void:
	print("[铸币] 金币 + 临时币")
	var b := _battle()
	var g0 := GameState.gold
	GameState.gold = 10
	_place(b, 0, 0, "铸")
	_place(b, 1, 0, "币")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(GameState.gold == 12, "铸币：+2 金币（当前 %d）" % GameState.gold)
	var has_coin := false
	for c in b.board.cells:
		if c != null and c.glyph() == "币":
			has_coin = true
	_ok(has_coin, "原格生成临时【币】")
	GameState.gold = g0


func _test_buyback() -> void:
	print("[回购] 付金币回收本回合消耗字")
	var b := _battle()
	var g0 := GameState.gold
	GameState.gold = 10
	b.bag.append(CharInstance.new(Database.get_character_by_glyph("击")))
	_place(b, 0, 0, "洗")
	b.try_play([Vector2i(0, 0)])
	var bag_before := b.bag.size()
	_place(b, 0, 1, "回")
	_place(b, 1, 1, "购")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)], {"discard_index": 0})
	_ok(GameState.gold == 7 and b.bag.size() == bag_before + 1, "回购：-3 金币，字回袋顶")
	GameState.gold = g0


func _test_gravity_always() -> void:
	print("[重力] 本战每次出字后全盘下落")
	var b := _battle()
	_place(b, 0, 0, "重")
	_place(b, 1, 0, "力")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.has_ability("gravity_always"), "重力：已启用持续下落")
	_place(b, 0, 0, "洗")
	_place(b, 3, 3, "击")
	b.try_play([Vector2i(3, 3)])
	_ok(b.board.get_cell(0, 3) != null, "后续出字后，列顶字块被重力压到底行")


func _test_transform_board() -> void:
	print("[转化] 揭示 5 选 1，定点改造")
	var b := _battle()
	for g in ["击", "防", "回", "反", "破"]:
		b.bag.append(CharInstance.new(Database.get_character_by_glyph(g)))
	_place(b, 0, 0, "转")
	_place(b, 1, 0, "化")
	var revealed := b.reveal_from_bag(5)
	_ok(revealed.size() == 5, "揭示 5 枚实体字")
	var chosen: CharInstance = revealed[0]
	_place(b, 3, 3, "洗")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(3, 3), "transform_uid": chosen.uid})
	var at: CharInstance = b.board.get_cell(3, 3)
	_ok(at != null and at.uid == chosen.uid, "指定格的【洗】被定向改为【%s】" % (at.glyph() if at != null else "?"))
	_ok(b.bag.size() == 4, "未选的 4 枚回字袋（当前 %d）" % b.bag.size())


func _test_split_grow() -> void:
	print("[分化] 删除一字，周围生长可组词的临时字")
	var b := _battle()
	_place(b, 1, 1, "洗")            # 待删除的填充字
	_place(b, 0, 0, "防")            # 紧邻两个生长格，用于验证“可组词”
	_place(b, 0, 3, "分")            # 打出【分化】
	_place(b, 1, 3, "化")
	var r := b.try_play([Vector2i(0, 3), Vector2i(1, 3)], {"tile": Vector2i(1, 1)})
	_ok(r.ok and b.board.get_cell(1, 1) == null, "选定的字被删除")
	var temp_count := 0
	for c in b.board.cells:
		if c != null and c.temporary:
			temp_count += 1
	_ok(temp_count >= 1, "周围生长出 %d 枚临时字" % temp_count)
	# 验证：紧邻【防】的临时字能与它组成合法词
	var good := 0
	for sc in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		var inst: CharInstance = b.board.get_xy(sc)
		if inst == null or not inst.temporary:
			continue
		if Database.get_word_by_glyphs([inst.glyph(), "防"]) != null or Database.get_word_by_glyphs(["防", inst.glyph()]) != null:
			good += 1
	_ok(good >= 1, "生成的临时字能与相邻的【防】组词")
	# 临时字打出即消耗，不进弃字堆（选一个不需选目标的字）
	var play_cell := Vector2i(-1, -1)
	var play_inst: CharInstance = null
	for i in b.board.cells.size():
		var c2: CharInstance = b.board.cells[i]
		if c2 != null and c2.temporary and not _needs_target_solo(c2.data):
			play_cell = b.board.to_xy(i)
			play_inst = c2
			break
	if play_inst != null:
		var pr := b.try_play([play_cell])
		_ok(pr.ok and not b.discard.has(play_inst), "临时字打出即消耗，不进弃字堆")


func _needs_target_solo(cd: CharacterData) -> bool:
	if cd == null:
		return false
	if cd.solo_handler in ["replace_self", "cleanse_adjacent"]:
		return true
	for e in cd.solo_effects:
		if e.target in [EffectData.Target.BOARD_TILE, EffectData.Target.BOARD_2X2, EffectData.Target.EMPTY_TILE, EffectData.Target.DISCARD_GLYPH, EffectData.Target.ENEMY_GLYPH]:
			return true
	return false


func _test_empower() -> void:
	print("[强化] 被强化的字参与成词时额外触发单字效果")
	var b := _battle()
	_place(b, 0, 0, "强")
	_place(b, 1, 0, "化")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"empower_glyph": "防"})
	_ok(b.empowered_glyphs.has("防"), "强化对【防】生效")
	_place(b, 0, 1, "防")
	_place(b, 1, 1, "御")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	_ok(b.player.block == 14, "防御(10) + 防单字(4) = 14（实际 %d）" % b.player.block)


func _test_cremate() -> void:
	print("[火化] 原地变成骨灰（彩蛋）")
	var b := _battle()
	_place(b, 0, 0, "火")
	_place(b, 1, 0, "化")
	var r := b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	var a: CharInstance = b.board.get_cell(0, 0)
	var c: CharInstance = b.board.get_cell(1, 0)
	_ok(a != null and a.glyph() == "骨" and a.temporary, "【火】原地变成临时【骨】")
	_ok(c != null and c.glyph() == "灰" and c.temporary, "【化】原地变成临时【灰】")
	var any_flavor := false
	for line in EffectHandlersActions.CREMATE_FLAVOR:
		for m in r.messages:
			if str(m).contains(line):
				any_flavor = true
	_ok(any_flavor, "火化带上随机台词")


func _test_fuse() -> void:
	print("[化合] 融合两张相邻牌为一格，不拆散")
	var b := _battle()
	_place(b, 0, 0, "合")
	_place(b, 1, 0, "化")
	_place(b, 0, 1, "击")
	_place(b, 1, 1, "破")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(0, 1), "tile2": Vector2i(1, 1)})
	var fused: CharInstance = b.board.get_cell(0, 1)
	_ok(fused != null and fused.is_fused(), "两张牌被融合成一格")
	_ok(b.board.get_cell(1, 1) == null, "第二格被清空")
	_ok(b.board.glyphs_of([Vector2i(0, 1)]) == ["击", "破"], "融合格贡献字形序列 [击,破]")
	_add_enemy(b, 200)
	var r := b.try_play([Vector2i(0, 1)])
	_ok(r.ok and r.word != null and r.word.word == "击破", "融合格单独打出成词【击破】")
	var found := false
	for cc in b.discard:
		if cc.is_fused() and cc.glyph_list() == ["击", "破"]:
			found = true
	_ok(found, "弃字堆里仍是同一个融合单位（未拆散）")


func _test_refine_layer() -> void:
	print("[精炼] 两个相同字一直重合")
	var b := _battle()
	_place(b, 0, 0, "精")
	_place(b, 1, 0, "炼")
	var a := _place(b, 0, 1, "击")
	_place(b, 2, 2, "击")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(0, 1), "tile2": Vector2i(2, 2)})
	_ok(a.temporary_uses == 1 and b.board.get_cell(2, 2) == null, "两张【击】重合为一格（可重复使用）")
	var in_bag := false
	for c in b.bag:
		if c.glyph() == "击":
			in_bag = true
	_ok(in_bag, "另一张【击】回到字袋")


func _test_vigor() -> void:
	print("[精力] 不同多字词累计下回合补字")
	var b := _battle()
	_place(b, 0, 0, "精")
	_place(b, 1, 0, "力")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.has_ability("vigor"), "精力生效")
	_ok(b.ability_value("vigor_next") >= 1, "已累计下回合补字 +%d" % b.ability_value("vigor_next"))


func _test_jingjin() -> void:
	print("[精金] 永久镀金 + 每词 1 金币")
	var g0 := GameState.gold
	GameState.gold = 50
	var saved := GameState.deck.duplicate()
	GameState.deck.clear()
	GameState.deck.append(CharInstance.new(Database.get_character_by_glyph("击")))
	var b := _battle()
	_place(b, 0, 0, "精")
	_place(b, 1, 0, "金")
	_place(b, 0, 1, "击")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"gild_glyph": "击"})
	var gilded := 0
	for inst in GameState.deck:
		if inst.glyph() == "击" and inst.gilded:
			gilded += 1
	_ok(gilded >= 1, "字袋中的【击】被镀金")
	var bh: CharInstance = b.board.get_cell(0, 1)
	_ok(bh != null and bh.gilded, "盘面上的【击】也被镀金")
	_add_enemy(b, 200)
	_place(b, 1, 1, "破")
	var gg := GameState.gold
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	_ok(GameState.gold == gg + 1, "镀金【击】参与多字词 +1 金币（%d→%d）" % [gg, GameState.gold])
	GameState.gold = g0
	GameState.deck = saved


func _test_jingzhu() -> void:
	print("[精铸] 弃字堆取字放进空格")
	var g0 := GameState.gold
	GameState.gold = 30
	var b := _battle()
	var stuck := CharInstance.new(Database.get_character_by_glyph("击"))
	b.discard.append(stuck)
	_place(b, 0, 0, "精")
	_place(b, 1, 0, "铸")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(3, 3), "place_uid": stuck.uid})
	_ok(b.board.get_cell(3, 3) == stuck, "把弃字堆的【击】放进指定空格")
	_ok(GameState.gold == 27, "支付 3 金币（当前 %d）" % GameState.gold)
	GameState.gold = g0


func _test_jingfen() -> void:
	print("[精分] 敌我攻击都打自己")
	var b := _battle()
	_add_enemy(b, 200)
	_place(b, 0, 0, "精")
	_place(b, 1, 0, "分")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.has_ability("split_mind"), "精分生效")
	var hp0 := b.player.hp
	_place(b, 0, 1, "击")
	_place(b, 1, 1, "破")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	_ok(b.player.hp < hp0, "玩家攻击打向自己（HP %d→%d）" % [hp0, b.player.hp])
	var e: Combatant = b.enemies[0]
	var ehp := e.hp
	b.end_player_turn()
	_ok(e.hp < ehp, "敌人攻击打向自己（HP %d→%d）" % [ehp, e.hp])


func _test_formation() -> void:
	print("[合击] 结阵：登记不结算、共享【击】、发动统一结算")
	var b := _battle()
	var e := _add_enemy(b, 200)
	_place(b, 0, 0, "合")
	_place(b, 1, 0, "击")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.formation_mode, "打出【合击】进入结阵")
	_ok(b.formation_queue.size() == 1 and b.board.get_cell(0, 0) != null, "【合击】自己也进队列且未消耗")
	_place(b, 0, 1, "反")
	var shared := _place(b, 1, 1, "击")
	_place(b, 2, 1, "破")
	var r1 := b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	var r2 := b.try_play([Vector2i(1, 1), Vector2i(2, 1)])
	_ok(r1.ok and r1.get("queued", false), "反击已登记（不结算）")
	_ok(r2.ok and r2.get("queued", false), "击破复用同一枚【击】并登记")
	var r3 := b.try_play([Vector2i(1, 1), Vector2i(2, 1)])
	_ok(not r3.ok, "已锁定的非【击】字不能再用（%s）" % str(r3.reason))
	_ok(e.hp == 200, "登记期间敌人未受伤")
	_ok(b.formation_queue.size() == 3, "队列共 3 个词（含合击）")
	_ok(b.board.get_xy(Vector2i(1, 1)) == shared, "登记期间字未被消耗")
	b.resolve_formation()
	_ok(200 - e.hp == 8, "发动后【击破】立即结算（伤害 %d）" % (200 - e.hp))
	_ok(not b.formation_mode and b.formation_queue.is_empty(), "结阵结束")


func _test_blast_preconsume() -> void:
	print("[爆破] 先摧毁再消耗：自己的字也计入摧毁")
	var b := _battle()
	var e := _add_enemy(b, 100)
	_place(b, 0, 0, "爆")
	_place(b, 1, 0, "破")
	var r := b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(0, 0)})
	_ok(r.ok, "爆破可打出")
	_ok(100 - e.hp == 8, "自己的 2 字也计入摧毁（伤害 %d）" % (100 - e.hp))
	_ok(b.board.get_xy(Vector2i(0, 0)) == null and b.board.get_xy(Vector2i(1, 0)) == null, "爆破后两格为空")
	_ok(b.consumed_this_turn.size() >= 2, "被摧毁的字进入本回合消耗名录（%d）" % b.consumed_this_turn.size())


func _test_direction_words() -> void:
	print("[方向] 左/右/左右/左转/右转/左击/右击")
	# 左：整行向左循环
	var b := _battle()
	_place(b, 0, 0, "击")
	_place(b, 1, 0, "防")
	_place(b, 2, 0, "回")
	_place(b, 3, 0, "反")
	_place(b, 0, 3, "左")
	var r := b.try_play([Vector2i(0, 3)], {"row": 0, "tile": Vector2i(0, 0)})
	_ok(r.ok, "左 可单字打出")
	_ok(_find(b, "击") == Vector2i(3, 0) and _find(b, "防") == Vector2i(0, 0), "整行向左循环一格")
	# 右：整行向右循环
	var b2 := _battle()
	_place(b2, 0, 1, "击")
	_place(b2, 1, 1, "防")
	_place(b2, 2, 1, "回")
	_place(b2, 3, 1, "反")
	_place(b2, 0, 3, "右")
	var r2 := b2.try_play([Vector2i(0, 3)], {"row": 1, "tile": Vector2i(0, 1)})
	_ok(r2.ok and _find(b2, "击") == Vector2i(1, 1) and _find(b2, "反") == Vector2i(0, 1), "整行向右循环一格")
	# 左右：同行两格交换
	var b3 := _battle()
	_place(b3, 0, 0, "左")
	_place(b3, 1, 0, "右")
	_place(b3, 2, 1, "击")
	_place(b3, 3, 1, "防")
	var r3 := b3.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(2, 1), "tile2": Vector2i(3, 1)})
	_ok(r3.ok and _find(b3, "击") == Vector2i(3, 1) and _find(b3, "防") == Vector2i(2, 1), "同行两格交换位置")
	# 左转：3×3 逆时针
	var b4 := _battle()
	_place(b4, 0, 0, "击")
	_place(b4, 2, 0, "防")
	_place(b4, 2, 2, "回")
	_place(b4, 0, 2, "反")
	_place(b4, 3, 0, "左")
	_place(b4, 3, 1, "转")
	var r4 := b4.try_play([Vector2i(3, 0), Vector2i(3, 1)], {"tile": Vector2i(0, 0)})
	_ok(r4.ok and _find(b4, "击") == Vector2i(0, 2) and _find(b4, "防") == Vector2i(0, 0), "3×3 逆时针旋转 90°")
	# 右转：3×3 顺时针
	var b5 := _battle()
	_place(b5, 0, 0, "击")
	_place(b5, 2, 0, "防")
	_place(b5, 2, 2, "回")
	_place(b5, 0, 2, "反")
	_place(b5, 3, 0, "右")
	_place(b5, 3, 1, "转")
	var r5 := b5.try_play([Vector2i(3, 0), Vector2i(3, 1)], {"tile": Vector2i(0, 0)})
	_ok(r5.ok and _find(b5, "击") == Vector2i(2, 0) and _find(b5, "反") == Vector2i(0, 0), "3×3 顺时针旋转 90°")
	# 左击：6 伤 + 行位移
	var b6 := _battle()
	var e6 := _add_enemy(b6, 100)
	_place(b6, 0, 0, "左")
	_place(b6, 1, 0, "击")
	_place(b6, 0, 3, "防")
	_place(b6, 2, 3, "反")
	var r6 := b6.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"row": 3, "tile": Vector2i(0, 3)})
	_ok(r6.ok and 100 - e6.hp == 6, "左击 造成 6 伤")
	_ok(_find(b6, "防") == Vector2i(3, 3), "左击 后再整行向左移动")


func _test_edge_batch1() -> void:
	print("[加边·第一批] 转速/能力/电能/蓄热/过冷/急转/急流/火急/收复")
	# 转速
	var b := _battle()
	_place(b, 3, 0, "转")
	_place(b, 3, 1, "速")
	_place(b, 0, 0, "击")
	_place(b, 1, 0, "防")
	_place(b, 0, 1, "回")
	_place(b, 1, 1, "反")
	var r := b.try_play([Vector2i(3, 0), Vector2i(3, 1)], {"tile": Vector2i(0, 0)})
	_ok(r.ok and b.repeat_rotate_count == 1, "转速：打出即旋转 1 次")
	b.do_repeat_rotate()
	b.do_repeat_rotate()
	_ok(b.repeat_rotate_count == 3 and b.player.heat == 2, "转速：连续 3 次，热度 +2")
	b.end_repeat_rotate()
	_ok(b.repeat_rotate_count == 0, "转速：结束后清零")
	# 能力
	var b2 := _battle()
	b2.enable_ability("longword_draw", 1)
	b2.bag.append(CharInstance.new(Database.get_character_by_glyph("币")))
	_place(b2, 0, 0, "防")
	_place(b2, 1, 0, "御")
	_place(b2, 2, 0, "力")
	var r2 := b2.try_play([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	_ok(r2.ok and b2.bag.is_empty() and b2.board.fill_count() == 1, "能力：3 字词额外补 1 字")
	# 电能
	var b3 := _battle()
	b3.enable_ability("electric_material", 1)
	b3.add_energy(4)
	b3.spend_energy(2)
	var has_dian := false
	for c in b3.board.cells:
		if c != null and c.glyph() == "电":
			has_dian = true
	_ok(has_dian and b3.player.energy == 2, "电能：消耗 2 储能生成临时【电】")
	# 蓄热
	var b4 := _battle()
	b4.enable_ability("heat_to_energy", 1)
	b4.player.heat = 3
	b4.end_player_turn()
	_ok(b4.player.heat == 1 and b4.player.energy >= 2, "蓄热：回合结束热度 -2 → 2 储能")
	# 过冷
	var b5 := _battle()
	_place(b5, 0, 0, "过")
	_place(b5, 1, 0, "冷")
	b5.player.heat = 5
	var r5 := b5.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(r5.ok and b5.player.heat == 0, "过冷：清空热度")
	b5.add_heat(3)
	_ok(b5.player.heat == 0 and b5.player.persistent_block >= 6, "过冷：下次热度转 6 持久盾")
	# 急转
	var b6 := _battle()
	_place(b6, 0, 0, "急")
	_place(b6, 1, 0, "转")
	_place(b6, 2, 1, "击")
	_place(b6, 3, 2, "防")
	var r6 := b6.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(2, 1), "tile2": Vector2i(3, 2)})
	_ok(r6.ok and b6.board.get_xy(Vector2i(2, 1)).glyph() == "防" and b6.board.get_xy(Vector2i(3, 2)).glyph() == "击", "急转：任意两格交换")
	_ok(b6.player.heat == 2, "急转：热度 +2")
	# 急流
	var b7 := _battle()
	_place(b7, 0, 0, "急")
	_place(b7, 1, 0, "流")
	_place(b7, 0, 1, "击")
	_place(b7, 1, 1, "防")
	b7.bag.append(CharInstance.new(Database.get_character_by_glyph("回")))
	b7.bag.append(CharInstance.new(Database.get_character_by_glyph("反")))
	var r7 := b7.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"row": 1})
	_ok(r7.ok and b7.board.get_xy(Vector2i(0, 1)) != null and b7.board.get_xy(Vector2i(1, 1)) != null, "急流：原位置补回")
	# 火急
	var b8 := _battle()
	_place(b8, 0, 0, "火")
	_place(b8, 1, 0, "急")
	b8.bag.append(CharInstance.new(Database.get_character_by_glyph("击")))
	b8.bag.append(CharInstance.new(Database.get_character_by_glyph("防")))
	var rev := b8.reveal_from_bag(2)
	var r8 := b8.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"cell1": Vector2i(0, 2), "cell2": Vector2i(1, 2)})
	_ok(rev.size() == 2 and r8.ok and b8.board.get_xy(Vector2i(0, 2)) != null and b8.board.get_xy(Vector2i(1, 2)) != null, "火急：2 枚落入指定空格")
	_ok(b8.player.heat == 2, "火急：热度 +2")
	# 收复
	var b9 := _battle()
	_place(b9, 0, 0, "收")
	_place(b9, 1, 0, "复")
	var u := CharInstance.new(Database.get_character_by_glyph("击"))
	b9.discard.append(u)
	var r9 := b9.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"places": [[u.uid, Vector2i(2, 2)]]})
	_ok(r9.ok and b9.board.get_xy(Vector2i(2, 2)) != null and b9.board.get_xy(Vector2i(2, 2)).uid == u.uid, "收复：从弃字堆放回盘面")


func _test_edge_batch2() -> void:
	print("[加边·第二批] 流速/火速/加急/蓄冷/冷热/超能/超能力/收回/收放/收息/加收/电力/电热/火电/火热/复电/流火")
	# 流速
	var b := _battle()
	_place(b, 0, 0, "流")
	_place(b, 1, 0, "速")
	var r := b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"row": 1})
	_ok(r.ok and b.flow_row == 1, "流速：选定第 1 行")
	_place(b, 2, 1, "击")
	_place(b, 3, 1, "破")
	b.bag.append(CharInstance.new(Database.get_character_by_glyph("回")))
	b.bag.append(CharInstance.new(Database.get_character_by_glyph("反")))
	b.try_play([Vector2i(2, 1), Vector2i(3, 1)])
	_ok(b.board.get_xy(Vector2i(2, 1)) != null and b.board.get_xy(Vector2i(3, 1)) != null, "流速：该行腾出的空格补回")
	# 火速
	var b2 := _battle()
	_place(b2, 0, 0, "火")
	_place(b2, 1, 0, "速")
	for i in 6:
		b2.bag.append(CharInstance.new(Database.get_character_by_glyph("防")))
	var r2 := b2.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(r2.ok and b2.board.fill_count() >= 6 and b2.player.heat >= 6, "火速：补字并升温")
	# 加急
	var b3 := _battle()
	_place(b3, 0, 0, "加")
	_place(b3, 1, 0, "急")
	b3.bag.append(CharInstance.new(Database.get_character_by_glyph("击")))
	b3.bag.append(CharInstance.new(Database.get_character_by_glyph("防")))
	b3.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b3.board.fill_count() == 2, "加急：立即补 2 字")
	# 蓄冷
	var b4 := _battle()
	_place(b4, 0, 0, "蓄")
	_place(b4, 1, 0, "冷")
	b4.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	b4.player.heat_capacity = 3
	b4.player.heat = 3
	var bag0 := b4.bag.size()
	b4.add_heat(2)
	_ok(b4.has_ability("overheat_shield") == false and b4.bag.size() == bag0, "蓄冷：抵消过热污染")
	# 冷热
	var b5 := _battle()
	_place(b5, 0, 0, "冷")
	_place(b5, 1, 0, "热")
	b5.player.heat = 3
	b5.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b5.player.heat == 0 and b5.player.persistent_block == 6, "冷热：热度→6 持久盾")
	# 超能
	var b6 := _battle()
	_place(b6, 0, 0, "超")
	_place(b6, 1, 0, "能")
	b6.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	b6.add_energy(3)
	_place(b6, 0, 0, "防")
	_place(b6, 1, 0, "御")
	_place(b6, 2, 0, "力")
	var r6 := b6.try_play([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	_ok(r6.ok and b6.board.get_xy(Vector2i(0, 0)) != null and b6.board.get_xy(Vector2i(1, 0)) != null, "超能：保留临时复制层")
	# 超能力
	var b7 := _battle()
	_place(b7, 0, 0, "超")
	_place(b7, 1, 0, "能")
	_place(b7, 2, 0, "力")
	b7.try_play([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	_ok(b7.ability_value("double_next", 0) == 1, "超能力：标记下一次双倍")
	_place(b7, 0, 3, "击")
	_place(b7, 1, 3, "破")
	b7.try_play([Vector2i(0, 3), Vector2i(1, 3)])
	_ok(b7.ability_value("double_next", 0) == 0, "超能力：触发后清除")
	# 收回
	var b8 := _battle()
	_place(b8, 0, 0, "收")
	_place(b8, 1, 0, "回")
	var ba := _place(b8, 2, 2, "击")
	var dd := CharInstance.new(Database.get_character_by_glyph("防"))
	b8.discard.append(dd)
	b8.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(2, 2), "place_uid": dd.uid})
	_ok(b8.board.get_xy(Vector2i(2, 2)).glyph() == "防" and b8.bag.has(ba), "收回：盘面字回袋顶、弃字补入原格")
	# 收放
	var b9 := _battle()
	_place(b9, 0, 0, "收")
	_place(b9, 1, 0, "放")
	var mv := _place(b9, 2, 2, "击")
	b9.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(2, 2), "tile2": Vector2i(0, 3)})
	_ok(b9.board.get_xy(Vector2i(0, 3)) == mv and b9.board.get_xy(Vector2i(2, 2)) == null, "收放：移动到空格")
	# 收息
	var b10 := _battle()
	_place(b10, 0, 0, "收")
	_place(b10, 1, 0, "息")
	b10.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	var g0 := GameState.gold
	GameState.gold = 10
	EffectUtil.pay(b10, 3)
	_ok(b10.player.persistent_block >= 3, "收息：花金币附等额持久盾")
	GameState.gold = g0
	# 加收
	var b11 := _battle()
	_place(b11, 0, 0, "加")
	_place(b11, 1, 0, "收")
	b11.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	var g1 := GameState.gold
	var inj := b11.inject_enemy_glyphs(2, "rush")
	_ok(inj >= 1 and GameState.gold > g1, "加收：敌人注入获得金币")
	GameState.gold = g1
	# 电力
	var b12 := _battle()
	_place(b12, 0, 0, "电")
	_place(b12, 1, 0, "力")
	b12.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	for i in b12.board.cells.size():
		b12.board.cells[i] = null
	_place(b12, 0, 3, "左")
	_place(b12, 0, 0, "击")
	_place(b12, 1, 0, "防")
	_place(b12, 2, 0, "回")
	_place(b12, 3, 0, "反")
	b12.add_energy(1)
	b12.try_play([Vector2i(0, 3)], {"row": 0})
	_ok(b12.board.get_xy(Vector2i(2, 0)) != null and b12.board.get_xy(Vector2i(2, 0)).glyph() == "击", "电力：额外位移一次")
	# 电热
	var b13 := _battle()
	_place(b13, 0, 0, "电")
	_place(b13, 1, 0, "热")
	b13.add_energy(3)
	b13.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b13.player.energy == 0 and b13.player.heat == 3 and b13.player.block >= 9, "电热：储能→热度+临挡")
	# 火电
	var b14 := _battle()
	_place(b14, 0, 0, "火")
	_place(b14, 1, 0, "电")
	b14.player.heat = 4
	var e14 := _add_enemy(b14, 100)
	b14.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b14.player.heat == 0 and b14.player.energy == 2 and 100 - e14.hp == 5, "火电：热度→储能+5 伤")
	# 火热
	var b15 := _battle()
	_place(b15, 0, 0, "火")
	_place(b15, 1, 0, "热")
	b15.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	b15.player.heat_capacity = 3
	b15.player.heat = 3
	var e15 := _add_enemy(b15, 100)
	b15.add_heat(2)
	_ok(100 - e15.hp == 10, "火热：2 枚污染【热】造成 10 伤")
	# 复电
	var b16 := _battle()
	_place(b16, 0, 0, "复")
	_place(b16, 1, 0, "电")
	b16.last_energy_spent = 4
	b16.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b16.player.energy == 2, "复电：恢复一半储能")
	# 流火
	var b17 := _battle()
	_place(b17, 0, 0, "流")
	_place(b17, 1, 0, "火")
	_place(b17, 2, 2, "热")
	b17.player.heat = 5
	b17.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b17.board.get_xy(Vector2i(2, 2)) == null and b17.player.heat == 3, "流火：洗回【热】并冷却 2")


func _test_blackout() -> void:
	print("[停电] 彩蛋：请求黑屏 + 开灯已登记")
	var b := _battle()
	_place(b, 0, 0, "停")
	_place(b, 1, 0, "电")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.blackout_requested, "停电触发了黑屏请求")
	_ok(Database.get_word_by_glyphs(["开", "灯"]) != null, "【开灯】已登记为彩蛋词")


func _test_charge_overheat() -> void:
	print("[充电过热] 8储能+8热度+每次出字补位")
	var b := _battle()
	for i in 16:
		b.bag.append(CharInstance.new(Database.get_character_by_glyph("击")))
	_place(b, 0, 0, "充")
	_place(b, 1, 0, "电")
	_place(b, 2, 0, "过")
	_place(b, 3, 0, "热")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])
	_ok(b.player.energy == 8 and b.player.heat == 8, "获得 8 储能 + 8 热度（储 %d 热 %d）" % [b.player.energy, b.player.heat])
	_ok(b.has_ability("auto_refill"), "持续能力：每次出字后补位")
	_ok(b.board.free_count() == 0, "本场出字后盘面立即补满（剩余空格 %d）" % b.board.free_count())


func _test_recast() -> void:
	print("[重铸] 整盘重新替换")
	var b := _battle()
	for i in 16:
		b.bag.append(CharInstance.new(Database.get_character_by_glyph("击")))
	_place(b, 0, 0, "重")
	_place(b, 1, 0, "铸")
	_place(b, 2, 2, "洗")
	_place(b, 0, 3, "防")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.board.fill_count() == 2, "盘面剩余 2 枚字被重新填充（当前 %d）" % b.board.fill_count())
	var all_player := true
	for c in b.board.cells:
		if c != null and not c.is_player_owned():
			all_player = false
	_ok(all_player, "重铸后的字都是己方字")


func _test_recast_copy() -> void:
	print("[再铸] 弃字堆的临时复制进空格")
	var b := _battle()
	var src := CharInstance.new(Database.get_character_by_glyph("击"))
	b.discard.append(src)
	_place(b, 0, 0, "再")
	_place(b, 1, 0, "铸")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"tile": Vector2i(3, 3), "place_uid": src.uid})
	var at: CharInstance = b.board.get_cell(3, 3)
	_ok(at != null and at.glyph() == "击" and at.temporary and at.uid != src.uid, "生成了【击】的临时复制并放入指定格")
	_ok(b.discard.has(src), "原牌仍留在弃字堆")


func _test_repeat_last() -> void:
	print("[再] 单字重复上一个字的最后一个字")
	var b := _battle()
	_place(b, 0, 0, "击")
	b.try_play([Vector2i(0, 0)])
	_place(b, 1, 0, "再")
	b.try_play([Vector2i(1, 0)])
	var at: CharInstance = b.board.get_cell(1, 0)
	_ok(at != null and at.glyph() == "击" and at.temporary, "【再】原位生成【击】的临时复制")


func _test_reverse_line() -> void:
	print("[反转] 倒转一行/一列")
	var b := _battle()
	_place(b, 0, 0, "击")
	_place(b, 3, 0, "防")
	_place(b, 0, 1, "反")
	_place(b, 1, 1, "转")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)], {"row": 0})
	var a0: CharInstance = b.board.get_cell(0, 0)
	var a3: CharInstance = b.board.get_cell(3, 0)
	_ok(a0 != null and a0.glyph() == "防" and a3 != null and a3.glyph() == "击", "第 1 行整体倒转")
	# 列
	_place(b, 0, 2, "反")
	_place(b, 1, 2, "转")
	_place(b, 2, 0, "连")
	_place(b, 2, 3, "流")
	b.try_play([Vector2i(0, 2), Vector2i(1, 2)], {"col": 2})
	var c0: CharInstance = b.board.get_cell(2, 0)
	var c3: CharInstance = b.board.get_cell(2, 3)
	_ok(c0 != null and c0.glyph() == "流" and c3 != null and c3.glyph() == "连", "第 3 列整体倒转")


func _test_merge_flow() -> void:
	print("[合流] 字袋+弃字堆放入相邻空格")
	var b := _battle()
	var bag_card := CharInstance.new(Database.get_character_by_glyph("击"))
	b.bag.append(bag_card)
	var disc_card := CharInstance.new(Database.get_character_by_glyph("防"))
	b.discard.append(disc_card)
	_place(b, 0, 0, "合")
	_place(b, 1, 0, "流")
	var rev := b.reveal_from_bag(1)
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"cell1": Vector2i(0, 2), "cell2": Vector2i(1, 2), "merge_bag_uid": rev[0].uid, "merge_discard_uid": disc_card.uid})
	var p1: CharInstance = b.board.get_cell(0, 2)
	var p2: CharInstance = b.board.get_cell(1, 2)
	_ok(p1 != null and p1.glyph() == "击" and p2 != null and p2.glyph() == "防", "两枚字放入相邻空格（顺序可控）")
	_ok(not b.discard.has(disc_card), "弃字堆的那枚被移出")


func _test_hard_stop() -> void:
	print("[急停] 清热+移除灼热字+结束出字")
	var b := _battle()
	b.player.heat_capacity = 5
	b.add_heat(8)
	var scorch_before := 0
	for c in b.bag:
		if c.glyph() == "热" and c.has_pollution("scorch"):
			scorch_before += 1
	_place(b, 0, 0, "急")
	_place(b, 1, 0, "停")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	var scorch_after := 0
	for c in b.bag:
		if c.glyph() == "热" and c.has_pollution("scorch"):
			scorch_after += 1
	_ok(b.player.heat == 0, "清空热度")
	_ok(scorch_before > 0 and scorch_after == 0, "移除未打出的灼热【热】（%d→%d）" % [scorch_before, scorch_after])
	_ok(b.end_turn_requested, "请求立即结束出字阶段")


func _test_repeat_word() -> void:
	print("[重复] 每回合第一次多字词再执行一次")
	var b := _battle()
	var e := _add_enemy(b, 200)
	_place(b, 0, 0, "重")
	_place(b, 1, 0, "复")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.has_ability("repeat"), "重复已开启")
	b.begin_player_turn(false)
	_ok(b.repeat_armed, "新回合已武装（第一次多字词）")
	_place(b, 0, 1, "击")
	_place(b, 1, 1, "破")
	var hp0 := e.hp
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	_ok(hp0 - e.hp == 16, "【击破】(8伤) 即时效果被执行两次 = 16（实际 %d）" % (hp0 - e.hp))
	_ok(not b.repeat_armed, "本回合不再重复")


func _test_fireproof() -> void:
	print("[防火] 灼热【热】不再扣血")
	var b := _battle()
	_place(b, 0, 0, "防")
	_place(b, 1, 0, "火")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.has_ability("fireproof"), "防火生效")
	var hot := CharInstance.new(Database.get_character_by_glyph("热"))
	hot.add_pollution("scorch")
	b.board.set_cell(2, 2, hot)
	var hp0 := b.player.hp
	b.try_play([Vector2i(2, 2)])
	_ok(b.player.hp == hp0, "打出灼热【热】不再扣血（HP %d→%d）" % [hp0, b.player.hp])


func _test_blastproof() -> void:
	print("[防爆] 被摧毁的己方字回袋并给持久盾")
	var b := _battle()
	_place(b, 0, 0, "防")
	_place(b, 1, 0, "爆")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.has_ability("blastproof"), "防爆生效")
	var tile := CharInstance.new(Database.get_character_by_glyph("击"))
	b.board.set_cell(2, 2, tile)
	var shield0 := b.player.persistent_block
	b.destroy_2x2(Vector2i(2, 2))
	_ok(b.bag.has(tile), "被摧毁的【击】回到字袋而非弃字堆")
	_ok(b.player.persistent_block == shield0 + 1, "救回 1 枚 +1 持久盾（当前 %d）" % b.player.persistent_block)


func _test_joint_funding() -> void:
	print("[合资] 2 储能抵 1 金币")
	var b := _battle()
	var g0 := GameState.gold
	GameState.gold = 1
	_place(b, 0, 0, "合")
	_place(b, 1, 0, "资")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.has_ability("joint_funding"), "合资生效")
	b.player.energy = 10
	_add_enemy(b, 200)
	_place(b, 0, 1, "投")
	_place(b, 1, 1, "币")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	_ok(b.player.energy == 4 and GameState.gold == 1, "用 6 储能抵 3 金币（储 %d 金 %d）" % [b.player.energy, GameState.gold])
	GameState.gold = g0


func _test_profit_share() -> void:
	print("[分利] 获得金币同时获得等量储能")
	var b := _battle()
	var g0 := GameState.gold
	GameState.gold = 0
	_place(b, 0, 0, "分")
	_place(b, 1, 0, "利")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.has_ability("profit_share"), "分利生效")
	b.player.energy = 0
	b.earn_gold(5)
	_ok(b.player.energy == 5, "获得 5 金币 → 储能 +5（当前 %d）" % b.player.energy)
	GameState.gold = g0


func _test_suspend() -> void:
	print("[停息] 热度换持久盾并结束出字")
	var b := _battle()
	_place(b, 0, 0, "停")
	_place(b, 1, 0, "息")
	b.player.heat = 4
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.player.heat == 0 and b.player.persistent_block == 8, "热度 4 → 持久盾 8")
	_ok(b.end_turn_requested, "请求立即结束出字阶段")


func _test_refine_remove() -> void:
	print("[炼化] 降热+金币+移出一张牌")
	var b := _battle()
	var g0 := GameState.gold
	GameState.gold = 10
	b.player.heat = 5
	b.bag.append(CharInstance.new(Database.get_character_by_glyph("洗")))
	_place(b, 0, 0, "炼")
	_place(b, 1, 0, "化")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)], {"remove_glyph": "洗"})
	_ok(b.player.heat == 2 and GameState.gold == 14, "热度 -3、金币 +4（热 %d 金 %d）" % [b.player.heat, GameState.gold])
	var still := false
	for c in b.bag:
		if c.glyph() == "洗":
			still = true
	_ok(not still and b.removed_this_battle.size() == 1, "指定的【洗】被移出本场循环")
	GameState.gold = g0


func _test_temp_funds_payment() -> void:
	print("[资金→投币] 临时资金优先支付")
	var b := _battle()
	var e := _add_enemy(b, 200)
	var g0 := GameState.gold
	GameState.gold = 50
	_place(b, 0, 0, "资")
	_place(b, 1, 0, "金")
	b.try_play([Vector2i(0, 0), Vector2i(1, 0)])
	_ok(b.player.temp_funds == 3, "资金：获得 3 临时资金（当前 %d）" % b.player.temp_funds)
	_place(b, 0, 1, "投")
	_place(b, 1, 1, "币")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)])
	_ok(b.player.temp_funds == 0 and GameState.gold == 50, "投币：先花临时资金，金币不变")
	_ok(200 - e.hp == 15, "投币：支付 3 × 5 = 15 伤（实际 %d）" % (200 - e.hp))
	GameState.gold = g0
