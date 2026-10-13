extends Control
## 词效回归：实体守恒、回合/跨战边界、结阵联动和实际 HUD 多阶段交互。

## 固定数量防止脚本异常中断某个测试函数后得到假通过。
const EXPECTED_CHECKS := 86
var checks: Array = []

func _ready() -> void:
	_run_controls()
	_run_logic()
	_run_baojinbi()
	_run_boundaries()
	_run_final_boundaries()
	await _run_ui()
	await _run_ui_completion()
	var failures := 0
	if checks.size() != EXPECTED_CHECKS:
		failures += 1
		push_error("回归用例未完整执行：%d/%d" % [checks.size(), EXPECTED_CHECKS])
	for check in checks:
		if not check.passed:
			failures += 1
			push_error("[word_effect_regression] %s: %s" % [check.id, check.detail])
	print("[word_effect_regression] PASS=%d FAIL=%d" % [checks.size() - failures, failures])
	get_tree().quit(1 if failures > 0 else 0)

func _check(id: String, passed: bool, detail: String) -> void:
	checks.append({"id": id, "passed": passed, "detail": detail})

func _battle() -> BattleState:
	GameState.player_max_hp = 60
	GameState.player_hp = 60
	GameState.gold = 100
	GameState.permanent_damage_reduction = 0
	GameState.gold_growth_percent = 0
	GameState.reinvest_gold = 0
	GameState.deck.clear()
	var rules: BattleRules = Database.rules.duplicate()
	rules.opening_draw = 0
	rules.turn_draw = 0
	var b := BattleState.new(rules)
	b.start([], [], 7)
	_enemy(b)
	return b

func _enemy(b: BattleState) -> Combatant:
	var ed := EnemyData.new()
	ed.name = "audit_enemy"
	ed.max_hp = 200
	var move := EnemyMoveData.new()
	move.kind = EnemyMoveData.Kind.ATTACK
	move.damage = 5
	ed.moves.append(move)
	var e := Combatant.new("audit_enemy", 200)
	e.enemy_data = ed
	b.enemies.append(e)
	return e

func _place(b: BattleState, pos: Vector2i, glyph: String) -> CharInstance:
	var inst := CharInstance.new(Database.get_character_by_glyph(glyph))
	b.board.set_xy(pos, inst)
	return inst

func _word(b: BattleState, text: String, row: int = 0, target: Dictionary = {}) -> Dictionary:
	var path: Array = []
	for i in text.length():
		var pos := Vector2i(i, row)
		_place(b, pos, text[i])
		path.append(pos)
	var result := b.try_play(path, target)
	assert(result.ok, "Audit setup cannot play " + text + ": " + str(result.reason))
	return result

func _pad(b: BattleState) -> void:
	for i in 50:
		b.bag.append(CharInstance.new(Database.get_character_by_glyph("放")))

func _occurrences(b: BattleState, inst: CharInstance) -> int:
	var n := 0
	for arr in [b.bag, b.discard, b.board.cells, b.pending_reveal]:
		for c in arr:
			if c == inst:
				n += 1
	return n

func _run_baojinbi() -> void:
	var b := _battle()
	var e: Combatant = b.enemies[0]
	_place(b, Vector2i.ZERO, "爆")
	_place(b, Vector2i(1, 0), "金")
	_place(b, Vector2i(2, 0), "币")
	var hp0: int = e.hp
	var gold0: int = GameState.gold
	var r := b.try_play([Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)])
	_check("baojinbi_word", r.ok and r.word != null and r.word.word == "爆金币", "成词=%s" % (r.word.word if r.word != null else "无"))
	_check("baojinbi_multi_hit", hp0 - e.hp == 5, "5 段 1 伤后掉血=%d，预期 5" % (hp0 - e.hp))
	_check("baojinbi_status", e.status_stacks("gold_burst") == 1, "爆金层=%d，预期 1" % e.status_stacks("gold_burst"))
	_check("baojinbi_gold_per_hit", GameState.gold == gold0 + 5, "本词 5 段金币 %d→%d，预期 +5" % [gold0, GameState.gold])
	# 敌方有护甲/格挡时，攻击被吸收也照样给钱
	var gold1: int = GameState.gold
	e.add_block(50)
	var hp1: int = e.hp
	b.deal_damage(e, 1, true)
	_check("baojinbi_through_block", e.hp == hp1 and GameState.gold == gold1 + 1, "50 格挡下受击 HP %d→%d、金币 %d→%d（预期 HP 不变、金币 +1）" % [hp1, e.hp, gold1, GameState.gold])


func _run_logic() -> void:
	var b := _battle()
	var inst := _place(b, Vector2i.ZERO, "洗")
	b.try_play([Vector2i.ZERO])
	_word(b, "回收", 1, {"discard_index": 0})
	_check("recover_unique", _occurrences(b, inst) == 1, "回收后同一 uid 在字袋/弃字堆/盘面的出现次数=%d，预期1" % _occurrences(b, inst))

	b = _battle()
	inst = _place(b, Vector2i.ZERO, "洗")
	b.try_play([Vector2i.ZERO])
	_word(b, "回购", 1, {"discard_index": 0})
	_check("buyback_unique", _occurrences(b, inst) == 1, "回购后同一 uid 出现次数=%d，预期1" % _occurrences(b, inst))

	b = _battle()
	inst = _place(b, Vector2i.ZERO, "防")
	inst.temporary_uses = 1
	_place(b, Vector2i(1, 0), "御")
	b.try_play([Vector2i.ZERO, Vector2i(1, 0)])
	_word(b, "回放", 1)
	_check("replay_layer_unique", _occurrences(b, inst) == 1, "重合层参与防御后回放，同一实体出现次数=%d，预期1" % _occurrences(b, inst))

	b = _battle()
	_word(b, "复合")
	_word(b, "充放电", 1)
	var kept := 0
	for x in 3:
		if b.board.get_cell(x, 1) != null:
			kept += 1
	_check("compound_layer", kept == 1, "复合后打充放电，保留层数=%d，预期1" % kept)

	b = _battle()
	_word(b, "复合")
	_word(b, "防御", 1)
	_check("compound_shortword", b.has_ability("next_compound"), "复合被两字词防御提前消费，标记仍在=%s，预期true" % b.has_ability("next_compound"))

	b = _battle()
	_word(b, "流利")
	_place(b, Vector2i(0, 1), "防")
	_place(b, Vector2i(1, 2), "御")
	var r := b.try_play([Vector2i(0, 1), Vector2i(1, 2)])
	_check("diagonal", r.ok, "流利后斜连防御，ok=%s，reason=%s" % [r.ok, r.reason])

	b = _battle()
	_word(b, "过火")
	_word(b, "重击", 1)
	_check("overfire_damage", b.enemies[0].hp == 188, "热度2时过火→重击，实际伤害=%d，预期12；标记仍在=%s" % [200 - b.enemies[0].hp, b.has_ability("next_overfire")])

	b = _battle()
	_word(b, "防护")
	var injected := b.inject_enemy_glyphs(2, "rush")
	_check("prevent_interference", injected == 0, "防护后敌方注入2字，实际注入=%d，预期0" % injected)

	b = _battle()
	_pad(b)
	_word(b, "流转")
	_word(b, "防御", 1)
	var drawn := b.drawn_this_turn
	_word(b, "防御", 2)
	_check("flow_repeat", b.drawn_this_turn == drawn, "两种词已触发流转后重复防御，额外补字=%d，预期0" % (b.drawn_this_turn - drawn))

	b = _battle()
	_word(b, "加速")
	_word(b, "流转", 1)
	_word(b, "停火", 2)
	_word(b, "复利", 3)
	b.begin_player_turn(false)
	var leftover: Array = []
	for key in ["accel", "flow", "ceasefire", "compound_equity"]:
		if b.has_ability(key):
			leftover.append(key)
	_check("turn_lifetime", leftover.is_empty(), "下回合残留本回合能力=%s，预期空" % str(leftover))

	b = _battle()
	b.end_player_turn()
	var hp_lost := 60 - b.player.hp
	_word(b, "爆冷")
	_check("cold_snap_previous_turn", 200 - b.enemies[0].hp == 4 + hp_lost * 2, "敌方上回合实际扣血=%d，爆冷伤害=%d，预期%d" % [hp_lost, 200 - b.enemies[0].hp, 4 + hp_lost * 2])

	b = _battle()
	b.player.heat = 1
	b.drawn_this_turn = 3
	_word(b, "热流")
	_check("heat_flow_actual_heat", b.enemies[0].hp == 198, "当前热1、补字3时热流伤害=%d，预期2" % (200 - b.enemies[0].hp))

	b = _battle()
	b.player.hp = 40
	_word(b, "热心")
	b.add_heat(5)
	var hp_before := b.player.hp
	_word(b, "清热", 1)
	_check("warm_heart_all_cooling", b.player.hp == hp_before - 2, "热心+清热：降热2后的失血=%d，预期2" % (hp_before - b.player.hp))

	b = _battle()
	b.add_heat(b.player.heat_capacity + 3)
	var scorch_before := b.temp_chars.size()
	b.clear_heat()
	b.add_heat(b.player.heat_capacity + 3)
	_check("overflow_after_clear", b.temp_chars.size() - scorch_before == 3, "溢出3→清零→再次溢出3，新增灼热字=%d，预期3" % (b.temp_chars.size() - scorch_before))

	b = _battle()
	b.add_heat(b.player.heat_capacity)
	_word(b, "蓄冷")
	b.add_heat(3)
	scorch_before = b.temp_chars.size()
	b.add_heat(1)
	_check("overflow_after_shield", b.temp_chars.size() - scorch_before == 1, "蓄冷抵消溢出3后再升温1，新增灼热字=%d，预期1" % (b.temp_chars.size() - scorch_before))

	b = _battle()
	inst = _place(b, Vector2i(2, 2), "防")
	_word(b, "精铸", 0, {"tile": Vector2i(2, 2)})
	var b2 := BattleState.new(b.rules)
	b2.start([inst], [b.enemies[0].enemy_data], 7)
	_check("pin_battle_lifetime", not inst.pinned, "精铸固定字进入下一场战斗，pinned=%s，预期false" % inst.pinned)

	b = _battle()
	inst = _place(b, Vector2i(2, 2), "防")
	_word(b, "精铸", 0, {"tile": Vector2i(2, 2)})
	var chosen := CharInstance.new(Database.get_character_by_glyph("御"))
	b.bag.append(chosen)
	b.reveal_from_bag(1)
	_word(b, "转化", 1, {"tile": Vector2i(2, 2), "transform_uid": chosen.uid})
	_check("pin_transform", b.board.get_xy(Vector2i(2, 2)) == inst, "精铸后转化仍替换固定字，原字仍在=%s，预期true" % (b.board.get_xy(Vector2i(2, 2)) == inst))

	b = _battle()
	_word(b, "加速")
	_word(b, "合击", 1)
	_word(b, "防御", 2)
	var heat_before := b.player.heat
	b.resolve_formation()
	_check("formation_auto_abilities", b.player.heat - heat_before == 2, "结阵结算合击+防御，加速实际升温=%d，预期2" % (b.player.heat - heat_before))

	b = _battle()
	inst = _place(b, Vector2i(2, 2), "防")
	_word(b, "精铸", 0, {"tile": Vector2i(2, 2)})
	_word(b, "合击", 1)
	_place(b, Vector2i(3, 2), "御")
	b.try_play([Vector2i(2, 2), Vector2i(3, 2)])
	b.resolve_formation()
	_check("formation_pin", b.board.get_xy(Vector2i(2, 2)) == inst, "合击结阵消耗精铸固定字，原字仍在=%s，预期true" % (b.board.get_xy(Vector2i(2, 2)) == inst))

	b = _battle()
	_word(b, "强化", 0, {"empower_glyph": "防"})
	_place(b, Vector2i(0, 1), "防")
	b.try_play([Vector2i(0, 1)])
	_check("empower_solo", b.player.block == 8, "强化防后单字防，实际格挡=%d，预期8" % b.player.block)

	b = _battle()
	_enemy(b)
	_word(b, "放火", 0, {"target_index": 0})
	b.add_heat(5)
	_word(b, "放火", 1, {"target_index": 1})
	b.end_player_turn()
	_check("burn_per_enemy", b.enemies[0].hp == 197 and b.enemies[1].hp == 192, "两敌分别在热0/热5时被放火，灼烧伤害=%d/%d，预期3/8" % [200 - b.enemies[0].hp, 200 - b.enemies[1].hp])

	b = _battle()
	b.player.energy = 3
	b.player.add_status("strength", 2)
	_word(b, "放电")
	_check("discharge_segments", b.enemies[0].hp == 182, "储能3、强力2时放电，实际伤害=%d，按3段应18" % (200 - b.enemies[0].hp))

	b = _battle()
	_pad(b)
	_word(b, "超速")
	b.enemies[0].block = 8
	_word(b, "击破", 1)
	_check("double_draw_all_sources", b.drawn_this_turn == 2 and not b.has_ability("next_double_draw"), "超速后击破拆盾补字，实际补字=%d，翻倍标记仍在=%s；预期2/false" % [b.drawn_this_turn, b.has_ability("next_double_draw")])

	b = _battle()
	_word(b, "重击")
	_word(b, "防御", 1)
	_word(b, "连击", 2)
	_check("replay_attack_classification", b.enemies[0].hp == 188 and b.player.block == 10, "重击→防御→连击：总伤害=%d、格挡=%d；预期12/10" % [200 - b.enemies[0].hp, b.player.block])

	b = _battle()
	_word(b, "重复")
	b.begin_player_turn(false)
	var cap_before := b.player.heat_capacity
	_word(b, "重载", 1)
	_check("repeat_immediate_only", b.player.heat_capacity - cap_before == 3 and b.base_draw_penalty == 1, "重复触发重载：热容增加=%d，补字惩罚=%d；按只重演即时效果应3/1" % [b.player.heat_capacity - cap_before, b.base_draw_penalty])

	b = _battle()
	_word(b, "再投资")
	GameState.settle_victory_economy()
	_check("reinvest_next_battle", GameState.gold == 94 and GameState.reinvest_gold == 6, "再投资后当场胜利结算，金币=%d、待返本金=%d；按下一场返还应94/6" % [GameState.gold, GameState.reinvest_gold])

func _new_screen():
	GameState.start_new_run("v03")
	var encounter := MapNodeData.new()
	encounter.enemies.append(Database.get_enemy("ink_spirit"))
	var screen = load("res://src/screens/battle_screen.gd").new()
	screen.setup({"node": encounter, "seed": 7})
	add_child(screen)
	for i in 4:
		await get_tree().process_frame
	screen.battle.board.cells.fill(null)
	screen.battle.bag.clear()
	screen.battle.discard.clear()
	screen.battle.consumed_this_turn.clear()
	return screen

func _run_ui() -> void:
	var screen = await _new_screen()
	_place(screen.battle, Vector2i(0, 0), "再")
	_place(screen.battle, Vector2i(1, 0), "铸")
	_place(screen.battle, Vector2i(2, 1), "防")
	_place(screen.battle, Vector2i(2, 2), "御")
	_place(screen.battle, Vector2i(2, 3), "击")
	screen._board_view.rebuild()
	screen._current_word = Database.get_word_by_glyphs_string("再铸")
	screen._on_commit([Vector2i(0, 0), Vector2i(1, 0)])
	_check("ui_recast_deferred", screen.battle.board.get_cell(0, 0) != null and screen._board_view.pick_mode == "any", "再铸点击确认立即消耗词字，首字仍在=%s，pick_mode=%s；应true/any" % [screen.battle.board.get_cell(0, 0) != null, screen._board_view.pick_mode])
	screen.queue_free()
	for i in 4:
		await get_tree().process_frame

	screen = await _new_screen()
	_place(screen.battle, Vector2i(0, 0), "合")
	_place(screen.battle, Vector2i(1, 0), "流")
	screen.battle.bag.append(CharInstance.new(Database.get_character_by_glyph("防")))
	screen.battle.discard.append(CharInstance.new(Database.get_character_by_glyph("御")))
	screen._board_view.rebuild()
	screen._current_word = Database.get_word_by_glyphs_string("合流")
	screen._on_commit([Vector2i(0, 0), Vector2i(1, 0)])
	_check("ui_merge_deferred", screen.battle.board.get_cell(0, 0) != null and screen.battle.pending_reveal.size() == 1, "合流选择弃字前已消耗词字并归还揭示牌，首字仍在=%s，pending_reveal=%d；应true/1" % [screen.battle.board.get_cell(0, 0) != null, screen.battle.pending_reveal.size()])
	screen.queue_free()
	for i in 4:
		await get_tree().process_frame

func _run_controls() -> void:
	var b := _battle()
	_word(b, "防御")
	_check("control_defense", b.player.block == 10, "正常防御获得10格挡")
	b = _battle()
	_word(b, "充电")
	_check("control_charge", b.player.energy == 3, "正常充电获得3储能")
	b = _battle()
	b.add_heat(5)
	_place(b, Vector2i.ZERO, "冷")
	b.try_play([Vector2i.ZERO])
	_check("control_cool", b.player.heat == 3, "正常冷单字降热2")
	b = _battle()
	_word(b, "金币")
	_check("control_gold", GameState.gold == 103, "正常金币获得3金币")
	b = _battle()
	_word(b, "重击")
	_word(b, "连击", 1)
	_check("control_replay_attack", b.enemies[0].hp == 188, "没有其他词干扰时连击可正常重演重击")
	b = _battle()
	var inst := _place(b, Vector2i(2, 2), "防")
	_word(b, "精铸", 0, {"tile": Vector2i(2, 2)})
	_place(b, Vector2i(3, 2), "御")
	b.try_play([Vector2i(2, 2), Vector2i(3, 2)])
	_check("control_pin_normal_play", b.board.get_xy(Vector2i(2, 2)) == inst, "普通出词保护精铸固定字")


func _unique_circulation(b: BattleState) -> bool:
	var seen := {}
	for arr in [b.board.cells, b.bag, b.discard, b.pending_reveal]:
		for inst in arr:
			if inst == null:
				continue
			if seen.has(inst.uid):
				return false
			seen[inst.uid] = true
	return true

func _run_boundaries() -> void:
	var b := _battle()
	var original := _place(b, Vector2i.ZERO, "洗")
	b.try_play([Vector2i.ZERO])
	b.draw_one_to(Vector2i(3, 3))
	_word(b, "回购", 1, {"discard_uid": original.uid})
	_check("recover_stale_rejected", GameState.gold == 100 and _occurrences(b, original) == 1, "已抽回盘面的历史消耗字不能回购，也不能扣金币")

	b = _battle()
	original = _place(b, Vector2i.ZERO, "洗")
	b.try_play([Vector2i.ZERO])
	_word(b, "回收", 1, {"discard_uid": original.uid})
	b.draw_one_to(Vector2i(3, 3))
	_check("recover_draw_roundtrip", b.board.get_xy(Vector2i(3, 3)) == original and _unique_circulation(b), "回收后再抽取，实体身份唯一")

	b = _battle()
	_word(b, "防御")
	b.draw_one_to(Vector2i(3, 3))
	_word(b, "回放", 1)
	_check("replay_already_drawn", _unique_circulation(b), "原牌已抽回盘面时回放不能重复引用")

	b = _battle()
	var pinned := _place(b, Vector2i(2, 2), "防")
	var other := _place(b, Vector2i(3, 2), "御")
	_place(b, Vector2i(3, 3), "放")
	_word(b, "精铸", 0, {"tile": Vector2i(2, 2)})
	b.swap_cells(Vector2i(2, 2), Vector2i(3, 2))
	_check("pinned_swap", b.board.get_xy(Vector2i(2, 2)) == pinned and b.board.get_xy(Vector2i(3, 2)) == other, "交换不能移动固定字")
	_word(b, "分化", 1, {"tile": Vector2i(2, 2)})
	_check("pinned_split", b.board.get_xy(Vector2i(2, 2)) == pinned, "分化不能删除固定字")
	_word(b, "再铸", 1, {"cells": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(3, 3)]})
	_check("pinned_recast_three", b.board.get_xy(Vector2i(2, 2)) == pinned and b.board.get_xy(Vector2i(3, 2)) == other, "再铸包含固定字时原子拒绝")
	_word(b, "重铸")
	_check("pinned_recast_board", b.board.get_xy(Vector2i(2, 2)) == pinned, "重铸保留固定字原位")

	b = _battle()
	_pad(b)
	_word(b, "复合")
	b.player.energy = 3
	_place(b, Vector2i(0, 1), "充")
	var chosen := _place(b, Vector2i(1, 1), "放")
	_place(b, Vector2i(2, 1), "电")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)], {"compound_uid": chosen.uid})
	var copy := b.board.get_xy(Vector2i(1, 1))
	_check("compound_before_draw", copy != null and copy.temporary and copy.glyph() == "放" and copy.uid != chosen.uid, "复合保留选中的字，词效补字不能抢占它原格")

	b = _battle()
	_word(b, "流利")
	_place(b, Vector2i(0, 1), "防")
	_place(b, Vector2i(1, 2), "御")
	_place(b, Vector2i(2, 3), "力")
	var result := b.try_play([Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3)])
	_check("diagonal_budget", not result.ok and b.has_ability("next_diagonal"), "两次斜连被拒绝，非法路径不消费流利")
	b.try_play([Vector2i(0, 1), Vector2i(1, 2)])
	_place(b, Vector2i(0, 1), "防")
	_place(b, Vector2i(1, 2), "御")
	result = b.try_play([Vector2i(0, 1), Vector2i(1, 2)])
	_check("diagonal_consumed", not result.ok and b.board.diagonal_steps_allowed == 0, "有效词消费流利，下一条路径恢复四邻接")
	_place(b, Vector2i(1, 1), "御")
	result = b.try_play([Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 1)])
	_check("path_no_reuse", not result.ok, "同一路径不能重复使用一个实体格")

	b = _battle()
	_word(b, "停火")
	b.end_player_turn()
	var hp_before := b.player.hp
	b.end_player_turn()
	_check("ceasefire_expires", b.player.hp == hp_before - 5, "停火只能免疫发动回合，下一回合正常受伤")

	b = _battle()
	b.player.hp = 40
	_word(b, "热心")
	b.add_heat(5)
	b.bag.append(CharInstance.new(Database.get_character_by_glyph("资")))
	_word(b, "炼化", 1, {"remove_glyph": "资"})
	_check("warm_heart_refine", b.player.hp == 42 and b.player.heat == 2, "炼化降热3，热心同步扣3血")
	_word(b, "蓄热", 2)
	hp_before = b.player.hp
	b.end_player_turn()
	_check("warm_heart_turn_end", b.player.hp == hp_before - 7 and b.player.energy == 2, "蓄热降热2扣2血，再承受敌人5伤")

	b = _battle()
	_word(b, "放火")
	b.add_heat(4)
	_word(b, "放火", 1)
	b.end_player_turn()
	b.end_player_turn()
	_check("burn_refresh", b.enemies[0].hp == 186 and b.enemies[0].status_stacks("burn") == 0, "重复放火刷新为最近施放数值及两次行动，不覆盖其他敌人")

	b = _battle()
	_enemy(b)
	b.enemies[0].hp = 4
	b.player.energy = 3
	_word(b, "放电")
	_check("discharge_retarget", b.enemies[0].hp == 0 and b.enemies[1].hp == 192, "放电击杀目标后，剩余两段攻击另一存活敌人")
	b = _battle()
	b.player.energy = 3
	b.player.add_status("next_bonus", 2)
	_word(b, "放电")
	_check("discharge_next_bonus", b.enemies[0].hp == 182 and b.player.status_stacks("next_bonus") == 0, "加强按放电的三段分别+2，并整次攻击只消费一次")

	b = _battle()
	_pad(b)
	for i in 16:
		_place(b, b.board.to_xy(i), "放")
	_word(b, "超速")
	_word(b, "回流", 1)
	_check("double_draw_actual_heat", b.board.fill_count() == 16 and b.drawn_this_turn == 4 and b.player.heat == 0, "盘面仅四空格时超速额外落字为0，不虚增热度")
	b = _battle()
	_pad(b)
	_word(b, "超速")
	_place(b, Vector2i(0, 1), "回")
	b.try_play([Vector2i(0, 1)])
	_check("double_draw_fixed_cell", b.drawn_this_turn == 2 and b.player.heat == 1, "回的原格补字同样触发超速和真实补字统计")

	b = _battle()
	_word(b, "再投资")
	var second := BattleState.new(b.rules)
	second.start([], [b.enemies[0].enemy_data], 7)
	_word(second, "再投资")
	GameState.settle_victory_economy()
	_check("reinvest_mixed_due", GameState.gold == 100 and GameState.reinvest_gold == 6, "第二场只兑付第一场投资，新投资保留到第三场")
	GameState.settle_victory_economy()
	_check("reinvest_no_double_refund", GameState.gold == 100 and GameState.reinvest_gold == 6, "已兑付批次不能重复返还")
	var third := BattleState.new(b.rules)
	third.start([], [b.enemies[0].enemy_data], 7)
	GameState.settle_victory_economy()
	_check("reinvest_next_due", GameState.gold == 112 and GameState.reinvest_gold == 0, "第三场兑付第二场投资")

	b = _battle()
	_pad(b)
	_word(b, "防御")
	_word(b, "回击", 1)
	_check("non_attack_prerequisite", b.drawn_this_turn == 0, "防御不满足回击的此前即时攻击条件")

	b = _battle()
	_word(b, "合击")
	_word(b, "超载", 1)
	_word(b, "击破", 2)
	b.resolve_formation()
	_check("formation_next_extra", b.enemies[0].hp == 184 and b.player.status_stacks("next_extra") == 0, "结阵中的超载强化后续击破")
	_check("formation_last_snapshot", b.last_played_word.word == "击破" and b.last_played_consumed.size() == 2, "结阵也更新最近出词快照")

	b = _battle()
	_word(b, "重复")
	b.begin_player_turn(false)
	b.begin_formation()
	_word(b, "防御", 1)
	b.resolve_formation()
	_check("formation_repeat", b.player.block == 20 and not b.repeat_armed, "结阵复用重复的即时重演流程")

	b = _battle()
	_pad(b)
	b.flow_row = 1
	b.begin_formation()
	_place(b, Vector2i(0, 1), "左")
	var shared := _place(b, Vector2i(1, 1), "击")
	_place(b, Vector2i(2, 1), "破")
	b.try_play([Vector2i(0, 1), Vector2i(1, 1)], {"row": 0})
	b.try_play([Vector2i(1, 1), Vector2i(2, 1)])
	b.resolve_formation()
	_check("formation_refill_identity", b.board.get_xy(Vector2i(1, 1)) != null and b.board.get_xy(Vector2i(1, 1)).glyph() == "放" and b.discard.count(shared) == 1 and _unique_circulation(b), "共享击只消费一次，后续词不消耗已补回原格的新字")

	b = _battle()
	b.begin_formation()
	_word(b, "心力")
	_place(b, Vector2i(0, 1), "心")
	b.try_play([Vector2i(0, 1)])
	b.resolve_formation()
	_check("formation_heart_power", b.player.heart_power == 2, "结阵成词和单字都触发心力")

	b = _battle()
	b.begin_formation()
	var polluted := _place(b, Vector2i.ZERO, "击")
	polluted.temporary_uses = 1
	polluted.add_pollution("rush")
	_place(b, Vector2i(1, 0), "破")
	b.try_play([Vector2i.ZERO, Vector2i(1, 0)])
	hp_before = b.player.hp
	b.resolve_formation()
	_check("formation_layer_pollution", b.player.hp == hp_before - 2 and b.board.get_xy(Vector2i.ZERO) == polluted, "结阵使用临时层也结算污染，保留实体原格")

	b = _battle()
	_word(b, "加速")
	b.add_heat(5)
	_word(b, "停息", 1)
	_check("stop_no_post_acceleration", b.player.heat == 0 and b.end_turn_requested, "停息结束出字，不再被后置加速重新升温")

	var h := RunHarness.new()
	GameState.start_new_run("v03")
	GameState.gold = 100
	var encounter := MapNodeData.new()
	encounter.enemies.append(Database.get_enemy("ink_spirit"))
	h.node = encounter
	h._start_battle(encounter)
	_word(h.battle_h.battle, "再投资")
	h.battle_h.battle.enemies[0].hp = 0
	h._end_battle()
	_check("run_reinvest_current", GameState.gold == 94 and GameState.reinvest_gold == 6, "整局无头接口当前胜利不提前兑付投资")
	h._start_battle(encounter)
	h.battle_h.battle.enemies[0].hp = 0
	h._end_battle()
	_check("run_reinvest_persists", GameState.gold == 106 and GameState.reinvest_gold == 0, "整局无头接口下一场保留并兑付投资")

	b = _battle()
	var pool := ["放", "防", "盾", "冷"]
	for i in 30:
		b.bag.append(CharInstance.new(Database.get_character_by_glyph(pool[i % pool.size()])))
	var conserved := true
	for step in 100:
		if b.board.fill_count() == 0:
			b.draw_to_board(6)
		var pos := Vector2i(-1, -1)
		for i in b.board.cells.size():
			if b.board.cells[i] != null:
				pos = b.board.to_xy(i)
				break
		b.try_play([pos])
		if step % 10 == 9:
			b.end_player_turn()
		conserved = conserved and _unique_circulation(b) and b.board.fill_count() + b.bag.size() + b.discard.size() == 30
	_check("circulation_100_steps", conserved, "100次真实抽取、单字消耗、洗牌、回合切换保持30实体守恒")

func _choice(screen, title: String) -> ChoiceOverlay:
	for child in screen.get_children():
		if child is ChoiceOverlay and str(child.cfg.get("title", "")).begins_with(title):
			return child
	return null

func _dispose_screen(screen) -> void:
	screen.queue_free()
	for i in 4:
		await get_tree().process_frame

func _run_ui_completion() -> void:
	var screen = await _new_screen()
	_place(screen.battle, Vector2i(0, 0), "再")
	_place(screen.battle, Vector2i(1, 0), "铸")
	var originals: Array = []
	for y in 3:
		originals.append(_place(screen.battle, Vector2i(2, y + 1), "防"))
	screen._board_view.rebuild()
	screen._current_word = Database.get_word_by_glyphs_string("再铸")
	screen._on_commit([Vector2i(0, 0), Vector2i(1, 0)])
	for y in 3:
		screen._board_view._on_tile_pressed(Vector2i(2, y + 1))
	_check("ui_recast_ready", not screen._ready_action.is_empty() and screen.battle.board.get_cell(0, 0) != null, "再铸选满三字只准备操作，不提前消耗词字")
	screen._on_primary()
	var replaced := true
	for y in 3:
		var current: CharInstance = screen.battle.board.get_cell(2, y + 1)
		replaced = replaced and current != null and current.temporary and current.uid != originals[y].uid
	_check("ui_recast_complete", replaced and screen.battle.board.get_cell(0, 0) == null, "再铸发动后替换三字并消耗词字")
	await _dispose_screen(screen)

	screen = await _new_screen()
	_place(screen.battle, Vector2i(0, 0), "合")
	_place(screen.battle, Vector2i(1, 0), "流")
	var from_bag := CharInstance.new(Database.get_character_by_glyph("防"))
	var from_discard := CharInstance.new(Database.get_character_by_glyph("御"))
	screen.battle.bag.append(from_bag)
	screen.battle.discard.append(from_discard)
	screen._board_view.rebuild()
	screen._current_word = Database.get_word_by_glyphs_string("合流")
	screen._on_commit([Vector2i(0, 0), Vector2i(1, 0)])
	var overlay := _choice(screen, "合流")
	assert(overlay != null)
	overlay._on_choose(0)
	screen._board_view._on_tile_pressed(Vector2i(2, 2))
	screen._board_view._on_tile_pressed(Vector2i(3, 2))
	_check("ui_merge_ready", not screen._ready_action.is_empty() and screen.battle.board.get_cell(0, 0) != null, "合流选好弃字和两相邻落点才准备操作")
	screen._on_primary()
	_check("ui_merge_complete", screen.battle.board.get_cell(2, 2) == from_bag and screen.battle.board.get_cell(3, 2) == from_discard and _unique_circulation(screen.battle), "合流发动后按所选顺序落字，实体不重复")
	await _dispose_screen(screen)

	screen = await _new_screen()
	_place(screen.battle, Vector2i(0, 1), "充")
	_place(screen.battle, Vector2i(1, 1), "放")
	_place(screen.battle, Vector2i(2, 1), "电")
	screen.battle.enable_ability("next_compound", 1)
	screen._board_view.rebuild()
	screen._on_commit([Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)])
	overlay = _choice(screen, "复合")
	_check("ui_compound_choice", overlay != null and screen.battle.board.get_cell(0, 1) != null, "复合允许选保留字，选择前不消耗")
	assert(overlay != null)
	overlay._on_choose(1)
	var retained: CharInstance = screen.battle.board.get_cell(1, 1)
	_check("ui_compound_selected", retained != null and retained.temporary and retained.glyph() == "放", "复合保留用户选择的第二个字")
	await _dispose_screen(screen)

	screen = await _new_screen()
	_place(screen.battle, Vector2i.ZERO, "防")
	_place(screen.battle, Vector2i(1, 1), "御")
	screen.battle.enable_ability("next_diagonal", 1)
	screen._board_view.rebuild()
	screen._board_view._on_tile_pressed(Vector2i.ZERO)
	screen._board_view._on_tile_pressed(Vector2i(1, 1))
	_check("ui_diagonal_input", screen._board_view.path == [Vector2i.ZERO, Vector2i(1, 1)], "流利的点击输入与逻辑路径校验一致")
	await _dispose_screen(screen)

	screen = await _new_screen()
	screen.battle.begin_formation()
	screen.battle.add_heat(6)
	_place(screen.battle, Vector2i.ZERO, "停")
	_place(screen.battle, Vector2i(1, 0), "息")
	var turn_before: int = screen.battle.turn
	screen._board_view.rebuild()
	screen._on_commit([Vector2i.ZERO, Vector2i(1, 0)])
	screen._on_primary()
	_check("ui_formation_stop", screen.battle.turn == turn_before + 1 and not screen.battle.end_turn_requested, "结阵中的停息同样立即结束出字并执行敌人行动")
	await _dispose_screen(screen)

func _run_final_boundaries() -> void:
	var b := _battle()
	b.enable_ability("next_diagonal", 1)
	b.begin_formation()
	_place(b, Vector2i.ZERO, "防")
	_place(b, Vector2i(1, 1), "御")
	var first := b.try_play([Vector2i.ZERO, Vector2i(1, 1)])
	_place(b, Vector2i(2, 2), "放")
	_place(b, Vector2i(3, 3), "火")
	var second := b.try_play([Vector2i(2, 2), Vector2i(3, 3)])
	_check("formation_diagonal_reserved", first.ok and not second.ok, "一个流利标记不能供两个结阵词使用斜连")
	b.resolve_formation()

	b = _battle()
	_word(b, "急停")
	var card := _place(b, Vector2i(0, 1), "防")
	var result := b.try_play([Vector2i(0, 1)])
	_check("stopped_phase_rejects_play", not result.ok and b.board.get_xy(Vector2i(0, 1)) == card and b.player.block == 0, "纯逻辑接口也拒绝在急停后继续出字")

	b = _battle()
	_word(b, "强化", 0, {"empower_glyph": "清"})
	var polluted := _place(b, Vector2i(0, 2), "防")
	polluted.add_pollution("rush")
	_word(b, "清热", 1)
	_check("empower_targeted_solo", polluted.pollutions.is_empty(), "强化清参与清热时，额外单字效果按清原格净化相邻污染")

	b = _battle()
	_word(b, "强化", 0, {"empower_glyph": "破"})
	_place(b, Vector2i(2, 2), "击")
	_place(b, Vector2i(3, 2), "破")
	b.fuse_cards(Vector2i(2, 2), Vector2i(3, 2))
	b.try_play([Vector2i(2, 2)])
	_check("empower_fused_glyph", b.enemies[0].hp == 189, "融合击破也触发附带字破的强化：8+3伤")

	var h := BattleHarness.new()
	h.reset({"seed": 7, "deck": [], "opening_draw": 0, "turn_draw": 0})
	_place(h.battle, Vector2i.ZERO, "防")
	_place(h.battle, Vector2i(1, 1), "御")
	h.battle.enable_ability("next_diagonal", 1)
	var actions := h.legal_actions()
	_check("harness_diagonal_actions", actions.any(func(action): return action.get("word", "") == "防御"), "无头合法动作枚举包含流利允许的斜连词")

	b = _battle()
	var source := _place(b, Vector2i.ZERO, "回")
	_place(b, Vector2i(1, 0), "转")
	result = b.try_play([Vector2i.ZERO, Vector2i(1, 0)], {"target_index": 0})
	_check("target_kind_validation", not result.ok and result.need_target == EffectData.Target.BOARD_2X2 and b.board.get_xy(Vector2i.ZERO) == source, "敌人目标参数不能替代回转的区域目标")
