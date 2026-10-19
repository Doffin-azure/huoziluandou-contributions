extends Node
## 【础】事件字：单字打出后安放到任意空格，固定且不受重力影响。
const EFFECTS = preload("res://src/core/event_effects.gd")
var failures: Array = []
var checks := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)


func _ready() -> void:
	var catalog_event: Dictionary = EFFECTS.get_event("foundation_stone")
	check(not catalog_event.is_empty(), "础石事件在目录中")
	check(catalog_event.get("options", []).size() == 3, "础石事件有三个选项")

	GameState.start_new_run("v03")
	var size_before: int = GameState.deck_size()
	var earned: Dictionary = EFFECTS.resolve([{"type": "gain_character", "glyph": "础"}], GameState.rng)
	check(earned.ok and GameState.deck_size() == size_before + 1 and GameState.deck[-1].glyph() == "础", "事件奖励可以发放【础】")

	var board: Array = []
	for i in 16: board.append("础" if i == 0 else "")
	var battle := BattleHarness.new()
	battle.reset({"seed": 991, "board": board, "enemies": ["ink_spirit"]})
	var source := battle.battle.board.get_xy(Vector2i(0, 0))
	check(source != null and source.glyph() == "础", "础字进入盘面")
	var result: Dictionary = battle.apply({"type": "play", "path": [[0, 0]], "target": {"tile": [3, 3]}})
	check(result.ok, "础字可以打出：" + str(result.get("reason", "")))
	var placed := battle.battle.board.get_xy(Vector2i(3, 3))
	check(placed != null and placed.glyph() == "础" and placed.pinned, "础字落在指定格并固定")
	check(battle.battle.board.get_xy(Vector2i(0, 0)) == null, "原格已腾空")
	battle.battle.apply_gravity()
	var after := battle.battle.board.get_xy(Vector2i(3, 3))
	check(after == placed and after.pinned, "重力不会移动固定础字")
	print("[SpecialGlyph] checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
