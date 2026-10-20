extends Control
const RUN = preload("res://src/expedition/room_run_state.gd")
const RESULT := "res://src/screens/run_result_screen.gd"
var checks := 0
var failures := 0
var ended := 0
var storage := ""

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame

func wait_result() -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while Router.current_path != RESULT and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	await frames()
	check(Router.current_path == RESULT, "final boss goes directly to unified settlement")

func fresh() -> void:
	Achievements.suspend_run()
	Achievements.profile = {"version":1,"unlocked":{"first_word":{"time":1,"unread":false,"run_id":"older"}},"lifetime":{},"best":{},"sessions":{}}
	GameState.start_new_run("v03")

func _ready() -> void:
	get_window().size = Vector2i(1280,720)
	GameState.set_meta("courtyard_preview", false)
	Settings.reduced_motion = true
	Achievements.test_enabled = true
	Achievements.autosave = false
	storage = "user://unified-result-test-%d.json" % Time.get_ticks_usec()
	Achievements.storage_path = storage
	Router.host = self
	EventBus.run_ended.connect(func(_won): ended += 1)
	for mode in ["classic", "courtyard", "expedition"]:
		fresh()
		var args := {}
		var run: RefCounted
		var ex: Expedition
		if mode == "courtyard":
			run = RUN.new(); run.reset({"seed":17,"layout":"node_graph"}); run._load_act(3)
			run.current_room = run.graph.boss; run.node = run.battle_node(); run.phase = "encounter"; run.begin_live_battle()
			args = {"room_run":true,"node":run.node}
		elif mode == "expedition":
			ex = Expedition.start(17); ex.load_act(3)
			ex.fight = {"kind":"boss","k":ex.boss,"name":"终局首领"}
			args = {"expedition":true,"node":ex.battle_node()}
		else:
			GameState.act_index = 3; GameState.node_index = 8
			args = {"node":Database.get_act(3).nodes[7]}
		Achievements.start_run(mode)
		GameState.gild_character(GameState.deck[0])
		check(Achievements.run_unlocks().any(func(definition): return definition.id == "first_gild"), "current run records earned achievements")
		Router.goto("res://src/screens/battle_screen.gd", args)
		await frames()
		var screen: Control = Router.current
		var size_before := GameState.deck_size()
		var ended_before := ended
		for enemy: Combatant in screen.battle.enemies: enemy.hp = 0
		screen.battle.turn = 5
		screen._check_battle_over()
		await wait_result()
		screen = Router.current
		check(bool(screen.result.victory) and int(screen.result.act) == 3 and int(screen.result.turn) == 5, mode + " victory is captured by the same result screen")
		check(GameState.deck_size() == size_before, mode + " final boss does not award a selectable glyph")
		check(Music.current != "defeat", "victory avoids defeat music")
		if run != null:
			check(run.phase == "victory" and run.reward_options.is_empty() and run.resolved.has(run.graph.boss) and run.contents[run.graph.boss].get("battle_relics", []).is_empty(), "main final boss is terminal with no pending reward")
		if ex != null: check(ex.over and ex.won and ex.panels.is_empty(), "legacy final boss has no reward or act-end picker")
		var ids: Array = screen.result.achievements.map(func(definition): return definition.id)
		check(ids.has("first_clear") and ids.has("first_gild") and not ids.has("first_word"), "settlement shows run unlocks including the completion unlock, excluding older achievements")
		check(screen.find_child("Achievement_first_clear", true, false) != null, "settlement renders the completion achievement card")
		check(Achievements.progress("first_clear") == 1 and ended == ended_before + 1, "completion and run-end notification happen exactly once")
		screen._open_achievements(); await frames()
		check(screen._return_button.disabled, "achievement viewer locks return action")
		for child in screen.get_children():
			if child is AchievementOverlay: child._close()
		await frames()
		check(not screen._return_button.disabled, "closing achievements restores result controls")
		if mode == "courtyard" and OS.get_cmdline_user_args().has("--capture"):
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_png("/tmp/huozi-victory-achievements.png")
		var captured: Dictionary = screen.result.duplicate(true)
		Router.goto(RESULT, {"victory":true}); await frames()
		check(Router.current.result == captured and Achievements.progress("first_clear") == 1 and ended == ended_before + 1, "reopening results preserves snapshot without duplicate achievements")
		Router.current._return_button.pressed.emit(); await frames()
		check(Router.current_path.ends_with("/title_screen.gd") and GameState.deck_size() == size_before, "victory confirmation returns to menu without restarting")
	# Failure uses the same achievement section and never grants completion credit.
	fresh(); Achievements.start_run("courtyard")
	GameState.gild_character(GameState.deck[0]); GameState.player_hp = 0
	Router.goto(RESULT); await frames()
	check(not Router.current.result.victory and Router.current.result.achievements.any(func(definition): return definition.id == "first_gild") and not Achievements.is_unlocked("first_clear"), "failure also displays current-run achievements without a clear reward")
	# Old final-boss reward saves are migrated to terminal victory, not shown a picker.
	var run = RUN.new(); run.reset({"seed":29,"layout":"node_graph"}); run._load_act(3)
	Achievements.start_run("courtyard")
	run.current_room = run.graph.boss; run.phase = "reward"
	run.reward_options = [Database.get_character_by_glyph("火")]
	var path := "user://unified-final-boss-test.tres"
	check(run.save_run(path) == OK, "legacy pending-final-reward snapshot saves")
	GameState.set_meta("courtyard_preview", true)
	var restored = RUN.restore(path)
	check(restored != null and restored.phase == "victory" and restored.reward_options.is_empty(), "old pending final-boss reward migrates to victory")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Router.current.queue_free(); Router.current = null; Router.host = null
	await frames()
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(storage + suffix))
	print("[unified_result_test] PASS=%d FAIL=%d" % [checks-failures, failures])
	get_tree().quit(1 if failures else 0)
