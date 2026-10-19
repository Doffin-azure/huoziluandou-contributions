extends Node
## 战后奖励选两轮：第二轮围绕第一轮所选字出能组词的字；第一轮跳过拿金币不进第二轮。

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[reward_rounds_test] FAIL: " + message)


func _ready() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	Router.host = host
	var ex := Expedition.start(7)
	var tray_before := ex.tray.size() + GameState.deck_size()
	Router.goto("res://src/screens/reward_screen.gd", {"expedition": true, "count": 3})
	await get_tree().process_frame
	var screen: Control = Router.current
	check(screen._round == 1 and screen._options.size() == 3, "第一轮三选一")
	var first: CharacterData = screen._options[0]
	screen._on_pick(first)
	await get_tree().process_frame
	screen = Router.current
	check(Router.current_path.ends_with("reward_screen.gd") and screen._round == 2, "选完第一枚进入第二轮")
	check(screen._anchor == first.glyph and screen._options.size() == 3, "第二轮记住第一轮的字，仍是三选一")
	check(not screen._options.any(func(c): return c.glyph == first.glyph), "第二轮不重复给第一轮的字")
	print("[reward_rounds_test] 第一轮选【%s】，第二轮：%s" % [first.glyph, ", ".join(screen._options.map(func(c): return c.glyph + "（" + str(screen._links.get(c.glyph, "随机")) + "）"))])
	var related: Array = screen._options.filter(func(c): return screen._links.has(c.glyph))
	var partners := {}
	for w in Database.words.values():
		if w.glyphs.has(first.glyph):
			for g in w.glyphs:
				if g != first.glyph:
					partners[g] = true
	check(related.size() == mini(3, screen._links.size()), "能组词的字优先占满选项")
	check(related.all(func(c): return partners.has(c.glyph) and Database.words.values().any(func(w): return w.word == screen._links[c.glyph] and w.glyphs.has(first.glyph) and w.glyphs.has(c.glyph))), "关联字确实和第一枚同在一个词里")
	if not related.is_empty():
		check(screen._with_hint(related[0]).description.begins_with("与【%s】组" % first.glyph), "说明里写出组成的词")
	var gold := GameState.gold
	screen._on_skip()
	await get_tree().process_frame
	check(Router.current_path.ends_with("expedition_map_screen.gd") and GameState.gold == gold, "第二轮跳过直接离开，不再给金币")
	check(ex.tray.size() + GameState.deck_size() == tray_before + 1, "两轮共收下 1 枚（第二轮跳过）")

	Router.goto("res://src/screens/reward_screen.gd", {"expedition": true, "count": 3})
	await get_tree().process_frame
	gold = GameState.gold
	Router.current._on_skip()
	await get_tree().process_frame
	check(Router.current_path.ends_with("expedition_map_screen.gd") and GameState.gold == gold + Expedition.SKIP_GOLD, "第一轮跳过拿 %d 金币，回地图" % Expedition.SKIP_GOLD)

	Router.goto("res://src/screens/reward_screen.gd", {"expedition": true, "count": 3})
	await get_tree().process_frame
	var before := ex.tray.size() + GameState.deck_size()
	Router.current._on_pick(Router.current._options[0])
	await get_tree().process_frame
	Router.current._on_pick(Router.current._options[0])
	await get_tree().process_frame
	check(Router.current_path.ends_with("expedition_map_screen.gd") and ex.tray.size() + GameState.deck_size() == before + 2, "两轮都选，收下 2 枚后回地图")
	Router.current.queue_free()
	Music.stop()
	# 音频线程下一次混音才释放播放实例
	await get_tree().create_timer(0.3).timeout
	print("[reward_rounds_test] PASS=%d FAIL=%d TOTAL=%d" % [checks - failures, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
