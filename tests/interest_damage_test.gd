extends "res://tests/monster_regression.gd"

func cast_interest(b: BattleState, target := 0) -> Dictionary:
	put(b, "利", 0)
	put(b, "息", 1)
	return b.try_play([Vector2i.ZERO, Vector2i.RIGHT], {"target_index": target})

func _ready() -> void:
	var word: WordData = Database.get_word_by_glyphs(["利", "息"])
	check(word.effects[0].is_attack(), "利息注册为攻击，不再作为金币收入")
	check(word.effects[0].amount == 10, "导入配置使用10%比例")
	for entry in [[0,0],[9,0],[10,1],[19,1],[29,2],[99,9],[100,10],[109,10],[999,99]]:
		var b := make("paper_shell")
		var enemy: Combatant = b.enemies[0]
		enemy.block = 0
		enemy.hp = 1000
		enemy.max_hp = 1000
		GameState.gold = entry[0]
		var before_rng := b.rng.state
		var preview := EffectDescriptions.word_text(word, b)
		check(preview.contains("%d基础伤害" % entry[1]) and GameState.gold == entry[0] and before_rng == b.rng.state, "预览按当前钱包计算且无副作用：%d" % entry[0])
		var result := cast_interest(b)
		check(result.ok and enemy.hp == 1000-entry[1], "真实出词向下取整：%d金币造成%d伤害" % [entry[0],entry[1]])
		check(GameState.gold == entry[0] and b.gold_earned == 0, "不扣金币也不再发金币")
	var b := make("paper_shell")
	b.enemies[0].block = 0
	b.enemies[0].hp = 1000
	b.enemies[0].max_hp = 1000
	GameState.gold = 19
	cast_interest(b)
	GameState.gold = 29
	cast_interest(b)
	check(b.enemies[0].hp == 997, "每次发动重新读取现有总金币，而非开场金币或本回合收入")
	b = make("paper_shell")
	b.enemies[0].block = 4
	b.enemies[0].hp = 1000
	GameState.gold = 100
	cast_interest(b)
	check(b.enemies[0].block == 0 and b.enemies[0].hp == 994, "伤害正常先抵消护盾")
	b = make("paper_shell")
	b.enemies[0].block = 0
	b.enemies[0].hp = 1000
	b.player.add_status("strength",2)
	GameState.gold = 100
	cast_interest(b)
	check(b.enemies[0].hp == 988, "金币决定基础伤害，正常参与攻击加成")
	b = make("paper_shell")
	var second := Combatant.new("第二目标",1000,false)
	second.enemy_data = Database.get_enemy("paper_shell")
	b.enemies.append(second)
	GameState.gold = 100
	var first_hp: int = b.enemies[0].hp
	cast_interest(b,1)
	check(second.hp == 990 and b.enemies[0].hp == first_hp, "只攻击选中的敌人")
	print("[interest_damage_test] checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures else 0)
