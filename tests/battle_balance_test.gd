extends "res://tests/monster_regression.gd"

func _ready() -> void:
	check(Database.warnings.is_empty(), "默认全战斗配置无警告")
	check(BattleBalance.validate(BattleBalance.payload).is_empty(), "运行时完整契约通过")
	var bad := BattleBalance.payload.duplicate(true)
	bad.tables["单字数值"][0][3] = "7"
	check(not BattleBalance.validate(bad).is_empty(), "拒绝文字数值")
	bad = BattleBalance.payload.duplicate(true)
	bad.tables["单字数值"].append(bad.tables["单字数值"][0])
	check(not BattleBalance.validate(bad).is_empty(), "拒绝重复ID")
	bad = BattleBalance.payload.duplicate(true)
	bad.tables["单字数值"].remove_at(0)
	check(not BattleBalance.validate(bad).is_empty(), "拒绝缺行")
	bad = BattleBalance.payload.duplicate(true)
	bad.tables["战斗规则"][0][3] = -1
	check(not BattleBalance.validate(bad).is_empty(), "拒绝越界")
	var original := BattleBalance.config_path
	var tuned_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--config="): tuned_path = arg.trim_prefix("--config=")
	if not tuned_path.is_empty():
		BattleBalance.config_path = tuned_path
		Database.reload()
		check(Database.warnings.is_empty(), "Excel导入文件完整应用")
		check(Database.get_character_by_glyph("击").solo_effects[0].amount == 9, "单字Excel伤害进入资源")
		check(Database.get_word_by_glyphs_string("击破").effects[0].amount == 17, "词组Excel伤害进入资源")
		check(Database.get_word_by_glyphs_string("击破").describe().contains("17"), "词组说明同步当前17伤害")
		check(load("res://resources/characters/ji.tres").solo_effects[0].amount != 9, "不改写原始缓存资源")
		var b := make("paper_shell")
		b.enemies[0].block = 0; b.enemies[0].hp = 1000; b.enemies[0].max_hp = 1000
		var c := put(b, "击", 0)
		var hp: int = b.enemies[0].hp
		b.try_play([Vector2i.ZERO])
		check(hp - b.enemies[0].hp == 9, "真实单打造成9伤害")
		hp = b.enemies[0].hp
		play(b, "击破")
		check(hp - b.enemies[0].hp == 17, "真实组词造成17伤害")
		play(b, "防御")
		check(b.player.block == 13, "护盾数值也可调整")
		for i in b.board.cells.size(): b.board.cells[i] = null
		c = put(b, "放", 0)
		b.player.energy = 2
		hp = b.enemies[0].hp
		b.try_play([Vector2i.ZERO], {"release_energy": true})
		check(hp - b.enemies[0].hp == 11 and b.player.energy == 0, "硬编码放释放伤害和费用改为11/2")
		c = put(b, "击", 0)
		c.gilded = true
		var gold := GameState.gold
		b.try_play([Vector2i.ZERO])
		check(GameState.gold == gold + 3, "镀金收益来自Excel的3金币")
		b.enemies[0].add_status("vulnerable", 1)
		c = put(b, "击", 0)
		hp = b.enemies[0].hp
		b.try_play([Vector2i.ZERO])
		check(hp - b.enemies[0].hp == 18, "小数倍率2.0参与真实伤害")
		check(Database.get_status("regen").decay_per_turn == 2, "状态衰减读取Excel")
		check(Database.rules.player_max_hp == 80 and Database.rules.turn_draw == 5, "生命与补字规则读取Excel")
		GameState.start_new_run("v03")
		check(GameState.player_hp == 80 and GameState.deck_size() == 14, "新开局实际生命80、字袋14枚")
		b = make("paper_shell")
		b.relics.assign(["barrier"])
		b.player.block = 0
		Relics.on_battle_start(b)
		check(b.player.block == 23 and Relics.desc_of("barrier").contains("23"), "遗物结算与说明均采用23临挡")
		check(Database.get_enemy("furnace_beast").max_hp == 77, "同份Excel怪物生命77")
		b = make("furnace_beast", "heat6")
		check(intent(b).damage == 14 and intent(b).hits == 2, "怪物伤害14×2同样导入")
		check(Database.get_pollution("rush").hp_loss_on_play == 4, "污染扣血读取同份Excel")
		Database.reload()
		check(Database.get_character_by_glyph("击").solo_effects[0].amount == 9, "重载不重复叠加修改")
		BattleBalance.config_path = original
		Database.reload()
		check(Database.get_character_by_glyph("击").solo_effects[0].amount != 9 and BattleBalance.i("gild_gold", 1) == 1, "恢复默认重新读取，无残留调参")
	print("[battle_balance_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-failures, failures, checks])
	get_tree().quit(1 if failures else 0)
