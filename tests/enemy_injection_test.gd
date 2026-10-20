extends "res://tests/monster_regression.gd"

func injected(b: BattleState) -> Array:
	return b.board.cells.filter(func(c): return c != null and c.is_enemy_owned())

func reuse(b: BattleState, c: CharInstance, glyphs: String, char_index := 0) -> Dictionary:
	# 移动测试盘面中的同一敌方实体，绝不以普通己方字替换被测字。
	for i in b.board.cells.size(): b.board.cells[i] = null
	var path: Array = []
	for x in glyphs.length():
		if x == char_index: b.board.set_xy(Vector2i(x, 0), c)
		else: put(b, glyphs.substr(x, 1), x)
		path.append(Vector2i(x, 0))
	var result := b.try_play(path)
	check(result.ok, "实际敌方实体出词：" + glyphs)
	check(not b.bag.has(c) and not b.discard.has(c) and not b.board.cells.has(c), "敌方实体消耗后不混进字袋")
	return result

func _ready() -> void:
	var b := make("corrosion_beetle", "corrode")
	var mv := intent(b)
	check(mv.kind == EnemyMoveData.Kind.INJECT and mv.inject_glyph == "蚀", "注蚀预告为指定注字")
	var rng_before := b.rng.state
	intent(b); intent(b)
	check(b.rng.state == rng_before, "塞字预览不消耗随机数")
	b._enemy_act(b.enemies[0])
	check(injected(b).size() == 2, "墨蚀蠹注2蚀")
	var c: CharInstance = injected(b)[0]
	var hp := b.player.hp
	reuse(b, c, "心蚀", 1)
	check(b.player.hp == hp - 2 and b.enemies[0].status_stacks("heart_corrosion") > 0, "心蚀词效与刺痛同时生效")

	b = make("copy_master", "copy")
	EnemyMechanics.data(b.enemies[0]).last_word = Database.get_word_by_glyphs(["回", "流"])
	check(intent(b).inject_glyph == "重" and intent(b).pollution_id == "block", "拓空间类预告堵塞重")
	b._enemy_act(b.enemies[0])
	check(injected(b).size() == 1 and injected(b)[0].glyph() == "重", "拓实际落盘指定重")
	c = injected(b)[0]
	var enemy_hp: int = b.enemies[0].hp
	reuse(b, c, "重击")
	check(b.next_draw_penalty == 1 and b.enemies[0].hp < enemy_hp, "重击正常造成伤害并少补1字")

	b = make("furnace_beast")
	mv = intent(b)
	check(mv.inject_glyph == "热" and mv.inject_count == 1, "炉腹兽攻击预告含热")
	check(EnemyIntent.describe(mv, b.enemies[0]).size() == 2, "攻击与塞字双意图")
	b._enemy_act(b.enemies[0])
	check(injected(b).size() == 1 and injected(b)[0].glyph() == "热" and b.player.heat == 2, "炉腹兽攻击升热且注入灼热热")
	c = injected(b)[0]; hp = b.player.hp
	reuse(b, c, "热流")
	check(b.player.hp == hp - 1, "热流照常付灼热代价")

	b = make("nest_moth")
	mv = intent(b)
	check(mv.mechanic_action == "seed_nest" and mv.inject_glyph == "连", "结巢预告蔓生连")
	check(EnemyIntent.describe(mv, b.enemies[0]).size() == 2, "结巢护盾与塞字双意图")
	b.end_player_turn()
	check(injected(b).size() == 1 and b.enemies[0].block == 6, "真实回合结巢塞连并得盾")
	b.end_player_turn()
	check(injected(b).size() == 2, "经过完整玩家阶段后1变2")
	b.end_player_turn()
	check(injected(b).size() == 4, "子代下一次复制，2变4")
	b.end_player_turn()
	check(injected(b).size() == 4, "结巢重注与复制均服从同源上限4")
	check(injected(b).all(func(x): return x.glyph() == "连" and x.has_pollution("replicate")), "子代保留字形、敌有和蔓生")

	b = make("nest_moth")
	b._enemy_act(b.enemies[0])
	EnemyMechanics.replicate_glyphs(b)
	check(injected(b).size() == 1, "刚注入同回合不立即复制")
	b.begin_player_turn(false)
	EnemyMechanics.replicate_glyphs(b); EnemyMechanics.replicate_glyphs(b)
	check(injected(b).size() == 2, "同回合重复结算不会再复制")

	b = make("nest_moth")
	b._enemy_act(b.enemies[0]); c = injected(b)[0]
	c.clear_pollutions()
	b.begin_player_turn(false); EnemyMechanics.replicate_glyphs(b)
	check(injected(b).size() == 1, "净化阻止复制")
	check(c.is_enemy_owned() and c.glyph() == "连", "净化保留字形与敌方归属")

	b = make("nest_moth")
	b._enemy_act(b.enemies[0]); c = injected(b)[0]
	reuse(b, c, "连击")
	b.begin_player_turn(false); EnemyMechanics.replicate_glyphs(b)
	check(injected(b).is_empty(), "连击用掉蔓生实体后无复制")
	b = make("nest_moth")
	b._enemy_act(b.enemies[0]); c = injected(b)[0]
	check(b.try_play([EnemyMechanics.pos(b, c)]).ok, "蔓生连可以单打")
	b.begin_player_turn(false); EnemyMechanics.replicate_glyphs(b)
	check(injected(b).is_empty(), "单打后不复制")

	for id in ["corrosion_beetle", "copy_master", "nest_moth", "furnace_beast"]:
		b = make(id, "corrode" if id == "corrosion_beetle" else ("copy" if id == "copy_master" else ""))
		if id == "copy_master": EnemyMechanics.data(b.enemies[0]).last_word = Database.get_word_by_glyphs(["回", "流"])
		b.enable_ability("prevent_interference")
		b._enemy_act(b.enemies[0])
		check(injected(b).is_empty() and not b.has_ability("prevent_interference"), id + "防护阻止塞字")
		b = make(id, "corrode" if id == "corrosion_beetle" else ("copy" if id == "copy_master" else ""))
		if id == "copy_master": EnemyMechanics.data(b.enemies[0]).last_word = Database.get_word_by_glyphs(["回", "流"])
		for i in 16: put(b, "防", i % 4, i / 4)
		var original := b.board.cells.duplicate()
		b._enemy_act(b.enemies[0])
		check(b.board.cells == original, id + "满盘不覆盖")

	b = make("nest_moth"); b._enemy_act(b.enemies[0]); b.begin_player_turn(false)
	b.enable_ability("prevent_interference"); EnemyMechanics.replicate_glyphs(b)
	check(injected(b).size() == 1 and not b.has_ability("prevent_interference"), "防护抵消复制波")
	b.begin_player_turn(false); b.enable_ability("guard_inject", 1); EnemyMechanics.replicate_glyphs(b)
	check(injected(b).size() == 1 and not b.has_ability("guard_inject"), "护抵消复制")
	b.begin_player_turn(false); b.enable_ability("inject_bounty"); var gold := GameState.gold
	EnemyMechanics.replicate_glyphs(b)
	check(injected(b).size() == 2 and GameState.gold == gold + 2, "加收只按实际复制数给钱")
	b = make("corrosion_beetle", "corrode"); b.enable_ability("guard_inject", 1)
	b._enemy_act(b.enemies[0]); check(injected(b).size() == 1, "护削减2枚注蚀至1枚")
	b = make("furnace_beast"); b._enemy_act(b.enemies[0]); c = injected(b)[0]
	c.clear_pollutions(); hp = b.player.hp
	reuse(b, c, "热流"); check(b.player.hp == hp, "净化后组词免污染扣血")

	var pool: Array = []
	for act_no in [1,2,3]:
		for stage in Expedition.NORMAL_STAGES[act_no]: pool.append_array(stage)
		for stage in Expedition.ELITE_STAGES[act_no]: pool.append_array(stage)
	for id in ["corrosion_beetle", "copy_master", "nest_moth", "furnace_beast"]:
		check(pool.has(id), "远征可遇到塞字怪 " + id)
	print("[enemy_injection_test] PASS=%d FAIL=%d TOTAL=%d" % [checks - failures, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
