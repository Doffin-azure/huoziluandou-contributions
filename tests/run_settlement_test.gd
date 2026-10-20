extends Control
const SLOT := "user://settlement_regression.save"
const FOLDER := "res://docs/qa/defeat-settlement-2026-10-18"
var passed := 0
var failed := 0
var ended := 0


func _ready() -> void:
	Settings.storage_path = "user://run_settlement_test-settings.cfg"
	get_tree().create_timer(45).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()


func check(value: bool, message: String) -> void:
	if value: passed += 1; print("PASS ", message)
	else: failed += 1; push_error(message)


func frames(n := 6) -> void:
	for i in n: await get_tree().process_frame


func _run() -> void:
	Settings.reduced_motion = true
	SaveManager.activate(SLOT)
	SaveManager.clear_run()
	Router.host = self
	var result := RunSettlement.calculate(3, 2, 75, 1, 20, 1)
	check(result.total == 1075 and result.rows.size() == 6, "six categories sum to 1075")
	check(RunSettlement.calculate(-4, -2, -1, -2, 999, -1).total == 300, "negative values contribute zero and gold is capped")
	check(RunSettlement.calculate(0, 0, 999, 0, 0).total == 150, "pressure score is bounded")
	EventBus.run_ended.connect(func(victory):
		if not victory: ended += 1)
	GameState.start_new_run()
	GameState.visited = {"1:1": true, "1:2": true}
	GameState.gold = 12
	GameState.relics = ["test"]
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 7})
	await frames()
	var battle_screen = Router.current
	battle_screen.battle.enemies[0].hp = 0
	battle_screen.battle.player.hp = 0
	battle_screen._check_battle_over()
	battle_screen._check_battle_over()
	await get_tree().create_timer(0.45).timeout
	await frames()
	check(Router.current_path.ends_with("/defeat_screen.gd"), "real battle defeat routes to settlement")
	check(ended == 1, "repeated battle completion emits one loss event")
	check(not SaveManager.has_save() and not FileAccess.file_exists(SLOT), "failure clears adventure save")
	var screen = Router.current
	check(screen._total == 360, "snapshot preserves progress, kill, pressure, relic and gold")
	check(screen._score_label.text == "360" and not screen._revealing, "reduced motion immediately shows final score")
	check(screen._row_lines.size() == 6 and screen._buttons.get_child_count() == 3, "all score lines and actions are mounted")
	screen._restart_button.pressed.emit()
	await frames()
	check(Router.current_path.ends_with("/map_screen.gd") and GameState.player_hp > 0 and GameState.visited.is_empty(), "classic restart resets the run")
	var ex := Expedition.start(77)
	ex.taken = {12: true, 14: true}
	ex.amb_done = {0: true}
	ex.boss_down = true
	ex.push_panel({"kind": "act_end"})
	ex.next_act()
	check(ex.act == 2 and GameState.visited.size() == 3, "expedition archives unique completed locations across acts")
	ex.taken[20] = true
	ex.fight = {"kind": "boss", "name": "测试首领"}
	var node := MapNodeData.new()
	node.type = MapNodeData.Type.BOSS
	node.title = "测试首领"
	var bs := BattleState.new(Database.rules)
	bs.start(GameState.make_battle_deck(), [Database.get_enemy("ink_spirit")], 7)
	bs.enemies[0].hp = bs.enemies[0].max_hp / 2
	var snapshot := RunSettlement.from_run(bs, node, ex)
	check(snapshot.rows[0].score == 400 and snapshot.rows[1].score == 500, "expedition retains previous act progress and boss milestone")
	check(snapshot.rows[3].score == 75, "half-damaged boss earns half of the 150 pressure points")
	ex.steps += 100
	check(RunSettlement.from_run(bs, node, ex).total == snapshot.total, "walking back and forth cannot increase settlement score")
	ex.finish_battle(false)
	check(ex.fight.is_empty() and snapshot.rows[3].score == 75, "snapshot survives clearing expedition encounter")
	bs.enemies[0].hp = bs.enemies[0].max_hp
	check(RunSettlement.from_run(bs, node, ex).rows[3].score == 0, "entering boss combat alone awards no pressure score")
	var fork := MapNodeData.new()
	fork.type = MapNodeData.Type.FORK
	bs.enemies[0].hp = bs.enemies[0].max_hp / 2
	check(RunSettlement.from_run(bs, fork, null, true).rows[3].score == 37, "elite fork receives elite pressure weight")
	var packed := SaveCodec.new().pack({"visited": GameState.visited})
	check(SaveCodec.new().unpack(packed).visited == GameState.visited, "archived expedition locations remain save compatible")
	Router.goto("res://src/screens/defeat_screen.gd", {"settlement": snapshot, "expedition": true})
	await frames()
	Router.current._restart_button.pressed.emit()
	await frames()
	check(Router.current_path.ends_with("/expedition_map_screen.gd") and GameState.expedition != ex and not GameState.expedition.over, "expedition restart enters a fresh expedition")
	var live_ex := GameState.expedition
	live_ex.fight = {"kind": "boss", "k": live_ex.boss, "name": "结算测试首领", "g": live_ex.m.TH.boss, "caught": false, "debuff": ""}
	Router.goto("res://src/screens/battle_screen.gd", {"node": live_ex.battle_node(), "expedition": true, "seed": 7})
	await frames()
	battle_screen = Router.current
	battle_screen.battle.player.hp = 0
	battle_screen.battle.enemies[0].hp = 0
	battle_screen._check_battle_over()
	await get_tree().create_timer(0.45).timeout
	await frames()
	check(Router.current_path.ends_with("/defeat_screen.gd") and live_ex.over and live_ex.fight.is_empty(), "real expedition defeat clears encounter and enters settlement")
	check(Router.current._rows[3].score == 150 and Router.current._expedition and not SaveManager.has_save(), "expedition snapshot survives finish_battle and retires save")
	for profile in [[Vector2i(960,432),160], [Vector2i(1280,720),0], [Vector2i(1280,720),320], [Vector2i(1920,1080),0], [Vector2i(2400,1080),440], [Vector2i(2532,1170),460], [Vector2i(3440,1440),0]]:
		await _profile(profile[0], profile[1], snapshot)
	BattleTouchLayout.test_dpi = 0
	Settings.reduced_motion = false
	Router.goto("res://src/screens/defeat_screen.gd", {"settlement": result})
	await frames()
	screen = Router.current
	check(screen._revealing, "normal motion begins an animated reveal")
	var samples: Array = []
	for i in 24:
		await get_tree().create_timer(0.10).timeout
		samples.append(int(screen._score_label.text))
	var monotonic := true
	for i in range(1, samples.size()): monotonic = monotonic and samples[i] >= samples[i - 1]
	check(monotonic and int(screen._score_label.text) == result.total and not screen._revealing, "score rises monotonically to the exact final total")
	Router.goto("res://src/screens/defeat_screen.gd", {"settlement": result})
	await frames()
	screen = Router.current
	screen._skip_button.pressed.emit()
	await get_tree().create_timer(0.25).timeout
	check(not screen._revealing and screen._score_label.text == str(result.total), "skip kills animation and fixes final score")
	check(screen._reveal_tween == null or not screen._reveal_tween.is_running(), "no tween continues after skip")
	screen._skip_button.pressed.emit()
	check(is_instance_valid(screen._rules_overlay), "completed animation offers readable scoring rules")
	screen._rules_overlay._on_choose(0)
	await frames()
	screen._title_button.pressed.emit()
	await frames()
	check(Router.current_path.ends_with("/title_screen.gd"), "return title action navigates correctly")
	SaveManager.clear_run()
	SaveManager.enabled = false
	print("[run_settlement_test] PASS=%d FAIL=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)


func _profile(dimensions: Vector2i, dpi: float, snapshot: Dictionary) -> void:
	get_window().size = dimensions
	BattleTouchLayout.test_dpi = dpi
	await frames()
	Router.goto("res://src/screens/defeat_screen.gd", {"settlement": snapshot})
	await frames(12)
	var screen = Router.current
	var tag := "%dx%d-%ddpi" % [dimensions.x, dimensions.y, dpi]
	print("LAYOUT ", tag, " screen=", screen.size, " page=", screen._page.get_global_rect(), " minimum=", screen._page.get_combined_minimum_size(), " body=", screen._body.get_combined_minimum_size(), " scroll=", screen._rows_scroll.get_combined_minimum_size())
	check(screen.get_global_rect().encloses(screen._page.get_global_rect()), tag + " settlement frame fits viewport")
	var rect: Rect2 = screen._page.get_global_rect()
	check(rect.encloses(screen._buttons.get_global_rect()), tag + " actions remain inside frame")
	for button in screen._buttons.get_children():
		check(rect.encloses(button.get_global_rect()) and button.size.y >= 48 * JourneyStyle.touch_scale(screen) - 1, tag + " action is visible and at least 48dp")
	check(not screen._rows_scroll.get_h_scroll_bar().visible, tag + " score details do not overflow horizontally")
	check(not screen._rows_scroll.get_v_scroll_bar().visible, tag + " six score lines fit without vertical scrolling")
	if OS.get_cmdline_user_args().has("--capture"):
		RenderingServer.force_draw(false)
		DirAccess.make_dir_recursive_absolute(FOLDER)
		check(get_viewport().get_texture().get_image().save_png(FOLDER.path_join(tag + ".png")) == OK, tag + " screenshot saved")
