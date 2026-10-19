extends Node
const BOARD = preload("res://src/expedition/event_word_board.gd")
const RUN = preload("res://src/expedition/room_run_state.gd")
const EFFECTS = preload("res://src/core/event_effects.gd")
var checks := 0
var failures: Array = []


func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("  ✓ ", message)
	else:
		failures.append(message)
		push_error(message)


func _ready() -> void:
	for seed_value in [1, 2, 3, 17, 99]:
		var data: Dictionary = BOARD.generate(seed_value)
		check(data.get("glyphs", []).size() == 16, "字盘 4×4 seed=%d" % seed_value)
		check(data.get("words", []).size() == 3, "字盘保证 3 个目标词 seed=%d" % seed_value)
		var board := BoardState.new(4)
		var glyphs: Array = data.get("glyphs", [])
		for i in mini(glyphs.size(), board.cells.size()):
			var cd: CharacterData = Database.get_character_by_glyph(str(glyphs[i]))
			if cd != null:
				var inst := CharInstance.new(cd)
				board.cells[i] = inst
		for path in data.get("paths", []):
			check(board.valid_path(path), "目标词路径合法 seed=%d" % seed_value)
			var gs := board.glyphs_of(path)
			check(Database.get_word_by_glyphs(gs) != null, "目标词仍在词谱：%s" % "".join(gs))
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var run = RUN.new()
	run.reset({"seed": 17}); run.autosave = false
	run.phase = "event"; run.event_node = "start"
	run.event_data = EFFECTS.get_event("xuanji_board").duplicate(true)
	var started: Dictionary = run.apply({"type": "event", "index": 0})
	check(started.ok and run.phase == "event_board" and run.event_board.glyphs.size() == 16, "璇玑事件进入字盘")
	var left: Dictionary = run.apply({"type": "event_board_leave"})
	check(left.ok and run.phase == "map", "璇玑字盘可以直接收起离开")
	run.reset({"seed": 17}); run.autosave = false
	run.phase = "event_board"
	var sample := ["回", "击", "火", "山", "月", "风", "水", "云", "心", "明", "光", "影", "石", "门", "花", "木"]
	run.event_board = {"seed": 1, "glyphs": sample, "words": ["回击"], "paths": [[Vector2i(0,0), Vector2i(1,0)]]}
	var before: int = GameState.deck_size()
	var word_result: Dictionary = run.apply({"type": "event_word", "path": [Vector2i(0,0), Vector2i(1,0)]})
	check(word_result.ok and run.phase == "map", "璇玑字盘确认合法词后完成事件")
	check(GameState.deck_size() == before + 2 and GameState.deck.any(func(c): return c.glyph() == "回") and GameState.deck.any(func(c): return c.glyph() == "击"), "璇玑字盘按词发放不重复的字")
	var bad := run.apply({"type": "event_word", "path": [Vector2i(0,0), Vector2i(2,0)]})
	check(not bad.ok, "璇玑字盘拒绝未成词/不相邻路径")
	run.reset({"seed": 17}); run.autosave = false
	run.phase = "event_board"; run.event_board = BOARD.generate(17)
	var saved := run.save_run("user://xuanji-board-test.tres")
	var restored = RUN.restore("user://xuanji-board-test.tres")
	check(saved == OK and restored != null and restored.phase == "event_board" and restored.event_board.glyphs.size() == 16, "璇玑字盘可存档恢复")
	print("[XuanjiBoard] checks=%d failures=%d" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
