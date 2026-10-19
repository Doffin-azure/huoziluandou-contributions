extends "res://tests/monster_regression.gd"
## 甲流：对所有敌人造成3点伤害，并使目标获得1层易伤；在图鉴和奖励提示里正常可见。

func _ready() -> void:
	var w: WordData = Database.get_word_by_glyphs(["甲", "流"])
	check(w != null and w.word == "甲流" and w.implemented, "甲流已入词库")
	var rules: BattleRules = Database.rules.duplicate()
	rules.opening_draw = 0
	rules.turn_draw = 0
	GameState.player_max_hp = 1000
	GameState.player_hp = 1000
	GameState.relics.clear()
	var b := BattleState.new(rules)
	b.start([], [Database.get_enemy("ink_spirit"), Database.get_enemy("paper_guard")], 121)
	for e in b.enemies:
		e.block = 0
		e.hp = 100
		e.max_hp = 100
	play(b, "甲流")
	check(b.enemies.all(func(e): return e.hp == 97), "所有敌人各受3点伤害")
	var marked: Array = b.enemies.filter(func(e): return e.status_stacks("vulnerable") == 1)
	check(marked.size() == 1, "只有目标获得1层易伤")
	check(w.describe().contains("所有敌人") and w.describe().contains("易伤"), "说明写清群伤和易伤")
	print("[jialiu_word_test] PASS=%d FAIL=%d TOTAL=%d" % [checks - failures, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
