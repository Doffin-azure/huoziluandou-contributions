extends Node
## 批量对局跑分（纯逻辑，无 UI）。用内置贪心 bot 跑固定种子的战斗，输出指标。
## 运行：godot --headless --path . res://src/tools/batch_test.tscn
## 结果写入 res://docs/batch_report.json

const SEEDS := 300
const MAX_TURNS := 40


func _ready() -> void:
	var decks := _decks()
	var matchups := _matchups()
	var report: Array = []
	print("=== 批量对局（每格 %d 种子，上限 %d 回合）===" % [SEEDS, MAX_TURNS])
	print("%-16s %-14s %7s %8s %8s %9s %8s" % ["字袋", "敌人", "胜率", "平均回合", "词/回合", "单字占比", "金币"])
	for deck in decks:
		for mu in matchups:
			var agg := _run_matchup(deck, mu)
			print("%-16s %-14s %6.1f%% %8.2f %8.2f %8.1f%% %8.1f" % [
				deck["name"], mu["name"], agg["win"] * 100.0, agg["turns"], agg["words_per_turn"],
				agg["single_ratio"] * 100.0, agg["gold"]])
			var row := {"deck": deck["name"], "enemy": mu["name"], "seeds": SEEDS}
			for k in agg.keys():
				row[k] = agg[k]
			report.append(row)
	var f := FileAccess.open("res://docs/batch_report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	print("\n已写入 res://docs/batch_report.json")
	get_tree().quit()


func _run_matchup(deck: Dictionary, mu: Dictionary) -> Dictionary:
	var wins := 0
	var turns := 0.0
	var words := 0.0
	var singles := 0.0
	var gold := 0.0
	var invalid := 0.0
	for s in SEEDS:
		var h := BattleHarness.new()
		h.reset({
			"seed": 1000 + s,
			"deck": deck["entries"],
			"enemies": mu["enemies"],
		})
		var guard := 0
		while not h.is_done() and guard < MAX_TURNS:
			guard += 1
			h.apply(_pick(h.legal_actions()))
		var sum := h.summary()
		if sum["victory"]:
			wins += 1
		turns += sum["turns"]
		words += sum["word_plays"]
		singles += sum["single_plays"]
		gold += sum["gold_earned"]
		invalid += sum["invalid_tries"]
	var n := float(SEEDS)
	var tot := words + singles
	return {
		"win": wins / n,
		"turns": turns / n,
		"words_per_turn": words / max(1.0, turns),
		"single_ratio": (singles / tot) if tot > 0.0 else 0.0,
		"gold": gold / n,
		"invalid_per_game": invalid / n,
	}


## 贪心策略：优先打分高的词，其次有效果的单字，否则结束回合。
func _pick(actions: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1
	for a in actions:
		if a.get("type") != "play" or a.get("word") == null:
			continue
		if int(a.get("score", 0)) > best_score:
			best = a
			best_score = int(a.get("score", 0))
	if not best.is_empty():
		return best
	for a in actions:
		if a.get("type") == "play" and a.get("word") == null and int(a.get("score", 0)) > 0:
			if int(a.get("score", 0)) > best_score:
				best = a
				best_score = int(a.get("score", 0))
	if not best.is_empty():
		return best
	return {"type": "end_turn"}


func _decks() -> Array:
	var v03: Array = []
	if Database.starter_decks.has("v03"):
		for e in Database.starter_decks["v03"].entries:
			v03.append({"glyph": e.character.glyph, "count": e.count})
	var mid := v03 + [{"glyph": "力", "count": 1}, {"glyph": "合", "count": 1},
		{"glyph": "护", "count": 1}, {"glyph": "盾", "count": 1}, {"glyph": "金", "count": 1}]
	var heat := [{"glyph": "热", "count": 3}, {"glyph": "火", "count": 2}, {"glyph": "过", "count": 2},
		{"glyph": "载", "count": 1}, {"glyph": "冷", "count": 1},
		{"glyph": "加", "count": 1}, {"glyph": "蓄", "count": 1}, {"glyph": "充", "count": 1}, {"glyph": "电", "count": 1}]
	return [
		{"name": "初始V03(12)", "entries": v03},
		{"name": "中期(17)", "entries": mid},
		{"name": "热系(14)", "entries": heat},
	]


func _matchups() -> Array:
	return [
		{"name": "墨灵(1-1)", "enemies": ["ink_spirit"]},
		{"name": "纸卫(1-2)", "enemies": ["paper_guard"]},
		{"name": "焦火(1-4)", "enemies": ["ember_imp"]},
		{"name": "字魔(1-8)", "enemies": ["boss_word_demon"]},
		{"name": "混铅海(3-8)", "enemies": ["boss_chaos_press"]},
	]
