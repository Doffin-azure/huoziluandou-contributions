extends Control

const FOLDER := "res://docs/qa/recent-log-2026-10-19/"
var passed := 0
var failed := 0


func _ready() -> void:
	Settings.storage_path = "user://recent_log_test-settings.cfg"
	get_tree().create_timer(60).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()


func frames(count := 5) -> void:
	for i in count: await get_tree().process_frame


func check(value: bool, text: String) -> void:
	if value: passed += 1; print("PASS ", text)
	else: failed += 1; push_error(text)


func _within_budget(entries: Array) -> bool:
	var total := 0
	for text in entries:
		if text.length() > RecentLog.MAX_LINE_CHARS: return false
		total += text.length()
	return entries.size() <= RecentLog.MAX_ENTRIES and total <= RecentLog.MAX_TOTAL_CHARS


func _run() -> void:
	SaveManager.enabled = false
	Settings.reduced_motion = true
	var battle := BattleState.new(Database.rules)
	var ex := Expedition.new()
	for i in 10000:
		battle._log("战斗记录 %d" % i)
		ex._log("远征记录 %d" % i)
	check(_within_budget(battle.log) and battle.log.size() == 32 and battle.log[0] == "战斗记录 9968" and battle.log.back() == "战斗记录 9999", "10,000 battle entries keep only newest 32 in chronological order")
	check(_within_budget(ex.lines) and ex.lines.size() == 32 and ex.lines[0] == "远征记录 9999" and ex.lines.back() == "远征记录 9968", "10,000 expedition entries keep newest 32 in reverse order")
	for i in 100: battle._log("长".repeat(1000))
	check(_within_budget(battle.log) and battle.log.back().ends_with("…"), "line and total character budgets cap oversized histories")
	check(RecentLog.display_text(["格挡 +2", "格挡 +2", "格挡 +2", "伤害 5"]) == "格挡 +2 ×3\n伤害 5", "display collapses consecutive repeats without dropping distinct outcomes")
	check(RecentLog.line("  伤害\n5\r  ") == "伤害 5" and RecentLog.line("\n ").is_empty(), "log lines normalize whitespace and ignore blank input")
	await _codec()
	await _battle_ui()
	await _expedition_ui()
	BattleTouchLayout.test_dpi = 0
	print("[recent_log_test] PASS=%d FAIL=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)


func _codec() -> void:
	GameState.start_new_run()
	var battle := BattleState.new(Database.rules)
	battle.start(GameState.make_battle_deck(), [Database.get_enemy("ink_spirit")], 7)
	var ex := Expedition.start(77)
	for i in 200:
		battle.log.append("旧战斗 %d" % i)
		ex.lines.push_front("旧远征 %d" % i)
	var original_size := battle.log.size()
	var packed := SaveCodec.new().pack({"battle": battle, "expedition": ex})
	check(battle.log.size() == original_size and ex.lines.size() > 32, "encoding trims save copy without mutating active histories")
	var restored := SaveCodec.new().unpack(packed)
	check(_within_budget(restored.battle.log) and _within_budget(restored.expedition.lines), "new saves contain only bounded log data")
	# Emulate an old save with 5,000 records while preserving the existing schema.
	var legacy: Array = []
	for i in 5000: legacy.append("存档日志 %d" % i)
	for node in packed.nodes:
		if node.type == "battle": node.fields.log = {"array": legacy}
		if node.type == "expedition": node.fields.lines = {"array": legacy}
	restored = SaveCodec.new().unpack(packed)
	check(restored.battle.log.size() == 32 and restored.battle.log[0] == "存档日志 4968" and restored.battle.log.back() == "存档日志 4999", "old battle log is cropped before decoding to retain latest tail")
	check(restored.expedition.lines.size() == 32 and restored.expedition.lines[0] == "存档日志 0" and restored.expedition.lines.back() == "存档日志 31", "old expedition log retains latest head")
	check(restored.battle.player.hp == battle.player.hp and restored.battle.rng.state == battle.rng.state and restored.battle.board.cells.map(func(cell): return cell.uid if cell != null else -1) == battle.board.cells.map(func(cell): return cell.uid if cell != null else -1), "legacy restore preserves combat state, character identities and RNG")
	check(restored.expedition.run_seed == ex.run_seed and restored.expedition.rng.state == ex.rng.state and restored.expedition.pos == ex.pos, "legacy restore preserves exploration state and RNG")
	var old_bytes := var_to_bytes(packed).size()
	var new_bytes := var_to_bytes(SaveCodec.new().pack(restored)).size()
	print("SAVE_LOG_BUDGET legacy_bytes=", old_bytes, " bounded_bytes=", new_bytes)
	check(new_bytes < old_bytes, "resaved legacy graph removes excess history payload")


func _battle_ui() -> void:
	Router.host = self
	get_window().size = Vector2i(1280,720)
	BattleTouchLayout.test_dpi = 320
	GameState.start_new_run()
	Router.goto("res://src/screens/battle_screen.gd", {"seed":7})
	await frames()
	var screen = Router.current
	var rng_state: int = screen.battle.rng.state
	var began := Time.get_ticks_usec()
	for i in 10000: screen.battle._log("回合记录 %d：造成 5 伤害" % i)
	var elapsed := Time.get_ticks_usec() - began
	await frames()
	check(screen._log_box.get_child_count() == 0 and not screen._log_refresh_queued, "closed battle log creates zero text controls or pending refreshes after 10,000 events")
	check(_within_budget(screen._log_lines) and _within_budget(screen.battle.log), "both presentation and battle histories stay bounded")
	screen._toggle_log()
	await frames()
	check(screen._log_box.get_child_count() == 1 and screen._log_text.text.contains("9999") and not screen._log_text.text.contains("回合记录 0："), "opening shows newest entries in a single text control")
	var bar: VScrollBar = screen._log_scroll.get_v_scroll_bar()
	check(absf(bar.value - (bar.max_value - bar.page)) <= 1, "opening scrolls to latest entries after text wrapping has settled")
	check(screen.get_global_rect().encloses(screen._log_scroll.get_global_rect()), "high-density phone battle log fits screen")
	await shot("phone-battle-log")
	var label_id: int = screen._log_text.get_instance_id()
	for i in 500: screen.battle._log("格挡 +2")
	await frames()
	check(screen._log_box.get_child_count() == 1 and screen._log_text.get_instance_id() == label_id and screen._log_text.text == "格挡 +2 ×32", "open log batches a message burst into same control and collapses repetition")
	screen._toggle_log()
	var previous: String = screen._log_text.text
	for i in 200: screen._on_log("选择落点 %d" % i)
	await frames()
	check(screen._log_text.text == previous, "hidden battle history does not re-layout text")
	screen._toggle_log()
	await frames()
	check(screen._log_text.text.contains("选择落点 199") and screen._log_box.get_child_count() == 1, "reopening renders fresh history without accumulating controls")
	check(screen.battle.rng.state == rng_state and screen.battle.turn == 1, "logging and opening history never affect combat rules")
	print("LOG_STRESS 10000_closed_messages_us=", elapsed, " retained=", screen._log_lines.size(), " controls=", screen._log_box.get_child_count())
	screen._toggle_log()


func _expedition_ui() -> void:
	Expedition.start(77)
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await frames()
	var screen = Router.current
	check(screen._mobile and screen._log_box.get_child_count() == 0, "phone expedition does not build hidden log contents")
	for i in 500:
		screen.ex._log("远征记录 %d" % i)
		screen._refresh_log()
	await frames()
	check(screen._log_box.get_child_count() == 0 and _within_budget(screen.ex.lines), "hidden expedition log skips rebuilding during refresh")
	screen._mobile_tabs.show_tab("战报")
	await frames()
	check(screen._log_box.get_child_count() == 1 and screen._log_text.text.begins_with("远征记录 499"), "switching to expedition log renders newest-first into one control")
	await shot("phone-expedition-log")
	var label_id: int = screen._log_text.get_instance_id()
	for i in 50: screen._refresh_log()
	check(screen._log_box.get_child_count() == 1 and screen._log_text.get_instance_id() == label_id, "unchanged expedition refresh reuses text control")
	BattleTouchLayout.test_dpi = 0
	get_window().size = Vector2i(1920,1080)
	await frames()
	Router.goto("res://src/screens/battle_screen.gd", {"seed":7})
	await frames()
	Router.current._toggle_log()
	await frames()
	await shot("desktop-battle-log")


func shot(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	RenderingServer.force_draw(false)
	check(get_viewport().get_texture().get_image().save_png(FOLDER + name + ".png") == OK, "archive " + name)
