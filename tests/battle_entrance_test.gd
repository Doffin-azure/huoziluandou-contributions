extends Control

const FOLDER := "res://docs/qa/battle-entrance-2026-10-18/"
var passed := 0
var failed := 0
var _motion := false
var _recording := false
var _record_folder := ""
var _record_times: Array = []
var _last_record := -1000


func _ready() -> void:
	Settings.storage_path = "user://battle_entrance_test-settings.cfg"
	_motion = Settings.reduced_motion
	if "--record" in OS.get_cmdline_user_args():
		_record_folder = OS.get_cache_dir().path_join("huozi-entrance-%d" % Time.get_ticks_usec())
		DirAccess.make_dir_recursive_absolute(_record_folder)
		RenderingServer.frame_post_draw.connect(_record_frame)
	get_tree().create_timer(60).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()


func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame


func check(value: bool, text: String) -> void:
	if value: passed += 1; print("PASS ", text)
	else: failed += 1; push_error(text)


func _open(node: MapNodeData = null, extra: Dictionary = {}) -> Control:
	var params := {"seed": 7}
	if node != null: params.node = node
	params.merge(extra, true)
	Router.goto("res://src/screens/battle_screen.gd", params)
	return Router.current


func _run() -> void:
	SaveManager.enabled = false
	Router.host = self
	Settings.reduced_motion = false
	GameState.start_new_run()
	GameState.first_run_tutorial = true
	_recording = not _record_folder.is_empty()
	var screen := await _open(null, {"first_run_tutorial": true})
	var entrance: BattleEntrance = screen._entrance
	check(is_instance_valid(entrance) and screen._busy and not screen._board_view._interactable, "fresh fight starts entrance and locks board immediately")
	check(screen._end_btn.disabled and screen._menu_btn.disabled, "turn and pause buttons are locked during entrance")
	var before := _snapshot(screen)
	await frames()
	var event := InputEventAction.new()
	event.action = "end_turn"
	event.pressed = true
	Input.parse_input_event(event)
	var touch := InputEventScreenTouch.new()
	touch.position = get_viewport().get_final_transform() * screen._board_view.get_global_rect().get_center()
	touch.pressed = true
	Input.parse_input_event(touch)
	touch = touch.duplicate()
	touch.pressed = false
	Input.parse_input_event(touch)
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await frames()
	check(_snapshot(screen) == before and screen._board_view.path.is_empty(), "touch and turn hotkey cannot mutate combat behind transition")
	check(not is_instance_valid(PauseMenu._instance), "escape does not open pause behind transition")
	await get_tree().create_timer(1.1).timeout
	_recording = false
	if not _record_folder.is_empty():
		var file := FileAccess.open(_record_folder.path_join("times.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(_record_times))
		print("RECORD_FOLDER ", _record_folder)
	check(not is_instance_valid(entrance) and screen._entrance == null and not screen._busy and screen._board_view._interactable, "entrance finishes within 1.1 seconds and restores input")
	check(_snapshot(screen) == before, "entrance leaves board, health, turn and combat RNG unchanged")
	check(screen._first_run_tutorial and screen._tutorial_step == 0 and screen._bubble._effect_text.contains("第一局引导"), "inline tutorial is ready after entrance without advancing its step")
	var checkpoint: Dictionary = screen.save_checkpoint()
	check(checkpoint.screen.get("battle") == screen.battle, "stable fight can checkpoint after transition")
	Router.goto("res://src/screens/battle_screen.gd", {"_saved_screen": checkpoint.screen})
	await frames()
	screen = Router.current
	check(screen._entrance == null and not screen._busy and screen.battle == checkpoint.screen.battle, "resume skips entrance and restores saved fight")
	Settings.reduced_motion = true
	screen = await _open()
	await frames()
	check(screen._entrance == null and not screen._busy and screen._board_view._interactable, "reduced motion opens battle immediately")
	Settings.reduced_motion = false
	screen = await _open()
	entrance = screen._entrance
	Settings.reduced_motion = true
	Settings.changed.emit()
	await frames()
	check(not is_instance_valid(entrance) and not screen._busy, "changing reduced motion during entrance releases the input lock")
	Settings.reduced_motion = false
	screen = await _open()
	var old: WeakRef = weakref(screen._entrance)
	Router.goto("res://src/screens/glyph_graph_screen.gd")
	await get_tree().create_timer(1.1).timeout
	check(old.get_ref() == null and Router.current_path.ends_with("glyph_graph_screen.gd"), "leaving mid-entrance frees tween without changing the next route")
	await _routes()
	await _profiles()
	Settings.reduced_motion = _motion
	BattleTouchLayout.test_dpi = 0
	print("[battle_entrance_test] PASS=%d FAIL=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)


func _snapshot(screen: Control) -> Array:
	return [screen.battle.turn, screen.battle.player.hp, screen.battle.enemies.map(func(enemy): return enemy.hp), screen.battle.board.cells.map(func(cell): return cell.uid if cell != null else -1), screen.battle.rng.state]


func _record_frame() -> void:
	var now := Time.get_ticks_msec()
	if not _recording or now - _last_record < 33: return
	_last_record = now
	var picture := get_viewport().get_texture().get_image()
	picture.resize(960, int(960.0 * picture.get_height() / picture.get_width()), Image.INTERPOLATE_LANCZOS)
	picture.save_png(_record_folder.path_join("%03d.png" % _record_times.size()))
	_record_times.append(now)


func _routes() -> void:
	GameState.start_new_run()
	Router.goto("res://src/screens/map_screen.gd")
	await frames()
	var map = Router.current
	var node: MapNodeData = Database.get_act(GameState.act_index).nodes[0]
	map._enter_node(0, node)
	check(Router.current._entrance != null and Router.current.node == node, "normal map combat uses entrance")
	Router.goto("res://src/screens/map_screen.gd")
	await frames()
	map = Router.current
	map._on_fork_choice(0, node)
	check(Router.current._entrance.inscription == "精英临阵", "elite fork uses elite inscription")
	var ex := Expedition.start(77)
	ex.fight = {"kind":"boss", "k":ex.boss, "name":"测试首领", "g":ex.m.TH.boss, "caught":false, "debuff":""}
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await frames()
	Router.current._start_battle()
	check(Router.current._expedition and Router.current._entrance.inscription == "首领现身", "expedition boss enters through same animation with boss inscription")
	Router.goto("res://src/screens/map_screen.gd")
	await frames()


func _profiles() -> void:
	for p in [[1280,720,0], [1280,720,320], [2400,1080,440], [3440,1440,0]]:
		get_window().size = Vector2i(p[0],p[1])
		BattleTouchLayout.test_dpi = p[2]
		await frames()
		var node := MapNodeData.new()
		node.title = "墨影深处 · 狭路相逢"
		node.enemies = [Database.get_enemy("ink_spirit")]
		var screen := await _open(node)
		var entrance: BattleEntrance = screen._entrance
		entrance._tween.pause()
		await frames()
		var tag := "%dx%d-%ddpi" % [p[0],p[1],p[2]]
		check(entrance.get_global_rect() == screen.get_global_rect(), tag + " entrance covers entire viewport")
		for phase in [["stamp",0.34],["settled",0.53],["reveal",0.76]]:
			entrance._advance(phase[1])
			await shot(tag + "-" + phase[0])
		entrance.finish()
		entrance.finish()
		await frames()
		check(not screen._busy and screen._board_view._interactable, tag + " repeated finish is harmless and controls unlock")
		await shot(tag + "-ready")


func shot(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	await frames(2)
	RenderingServer.force_draw(false)
	check(get_viewport().get_texture().get_image().save_png(FOLDER + name + ".png") == OK, "archive " + name)
