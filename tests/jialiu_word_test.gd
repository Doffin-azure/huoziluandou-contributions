extends Node
## 甲流：对所有敌人造成3点伤害，并使目标获得1层易伤。

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[jialiu_word_test] FAIL: " + message)


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
	for x in 2:
		b.board.set_xy(Vector2i(x, 0), CharInstance.new(Database.get_character_by_glyph("甲流"[x])))
	check(b.try_play([Vector2i(0, 0), Vector2i(1, 0)]).ok, "真实出词成功：甲流")
	check(b.enemies.all(func(e): return e.hp == 97), "所有敌人各受3点伤害")
	var marked: Array = b.enemies.filter(func(e): return e.status_stacks("vulnerable") == 1)
	check(marked.size() == 1, "只有目标获得1层易伤")
	check(w.describe().contains("所有敌人") and w.describe().contains("易伤"), "说明写清群伤和易伤")
	print("[jialiu_word_test] PASS=%d FAIL=%d TOTAL=%d" % [checks - failures, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
