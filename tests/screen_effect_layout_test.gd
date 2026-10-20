extends Control
## Real title / battle flow: a gravity shake must preserve the current layout.
var checks := 0
var failures := 0


func _ready() -> void:
	SaveManager.enabled = false
	GameState.set_meta("courtyard_preview", true)
	Settings.reduced_motion = true
	Engine.max_fps = 240
	_run.call_deferred()


func frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)


func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture"): return
	await frames(2)
	RenderingServer.force_draw(false)
	var target := "res://shots/screen-effect-layout"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
	get_viewport().get_texture().get_image().save_png(target.path_join(name+".png"))


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	var main := preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(16)
	var title: Control = Router.current
	check(title.inventory_bar==null, "fresh title does not display empty run inventory")
	check(title.content.position.is_equal_approx(Vector2.ZERO) and title.content.size.is_equal_approx(title.size), "title has no reserved inventory strip")
	await shot("title-fixed")
	GameState.start_new_run("v03")
	Router.goto("res://src/screens/battle_screen.gd")
	await frames(12)
	var screen: Control = Router.current
	var origin: Vector2 = screen.content.position
	var original_size: Vector2 = screen.content.size
	check(screen.inventory_bar==null and origin.is_equal_approx(Vector2.ZERO) and original_size.is_equal_approx(screen.size), "battle has no shared inventory controls or reserved strip")
	var effects: BattleEffects = screen._effects
	# Advance the shake explicitly so a slow render frame cannot consume it first.
	effects.set_process(false)
	# Reproduce through the real single-character play, not only a fake shake.
	screen.battle.bag.clear()
	screen.battle.discard.clear()
	for i in screen.battle.board.cells.size(): screen.battle.board.cells[i] = null
	screen.battle.board.set_xy(Vector2i.ZERO, CharInstance.new(Database.get_character_by_glyph("重")))
	screen.battle.board.set_xy(Vector2i(1, 0), CharInstance.new(Database.get_character_by_glyph("击")))
	screen._refresh_all()
	screen._board_view.path = [Vector2i.ZERO]
	screen._board_view._sync_selection()
	Settings.reduced_motion = false
	screen._on_primary()
	var deadline := Time.get_ticks_msec()+5000
	while screen._busy and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	var fallen: CharInstance = screen.battle.board.get_xy(Vector2i(1, 3))
	check(not screen._busy and fallen!=null and fallen.glyph()=="击" and effects._impact_strength>0, "playing 重 moves the glyph down and reaches the gravity impact hook")
	effects._process(.025)
	check(screen.content.position.distance_to(origin)>.01, "shake moves the battlefield")
	effects._process(.5)
	check(screen.content.position.is_equal_approx(origin) and screen.content.size.is_equal_approx(original_size), "重 restores the current rest pose and size")
	await shot("battle-after-gravity")
	for i in 6:
		effects.table_impact(7)
		effects._process(.025)
	effects._process(.5)
	check(screen.content.position.is_equal_approx(origin) and screen.content.size.is_equal_approx(original_size), "overlapping impacts do not accumulate layout drift")
	for resolution in [Vector2i(1600, 720), Vector2i(844, 390)]:
		effects.table_impact(7)
		effects._process(.025)
		get_window().size = resolution
		await frames(12)
		var new_origin: Vector2 = screen.content.position
		var new_size: Vector2 = screen.content.size
		check(new_origin.is_equal_approx(Vector2.ZERO) and new_size.is_equal_approx(screen.size), "resize preserves the full content area at "+str(resolution))
		effects._process(.025)
		effects._process(.5)
		check(screen.content.position.is_equal_approx(new_origin) and screen.content.size.is_equal_approx(new_size), "impact respects the new rest pose at "+str(resolution))
	await shot("battle-after-phone-resize")
	origin = screen.content.position
	effects.table_impact(7)
	effects._process(.025)
	Settings.reduced_motion = true
	effects._process(.01)
	check(effects._impact_strength==0 and screen.content.position.is_equal_approx(origin), "disabling motion restores the current pose")
	Settings.reduced_motion = false
	var stage_origin: Vector2 = Router.study_stage.position
	effects.table_impact(7)
	effects._process(.025)
	Router.goto("res://src/screens/title_screen.gd")
	await frames()
	check(Router.study_stage.position.is_equal_approx(stage_origin), "exiting during impact restores the shared background")
	check(Router.current==title and title.inventory_bar==null and title.content.position.is_equal_approx(Vector2.ZERO), "cached title stays free of run inventory after battle")
	Settings.reduced_motion = true
	main.queue_free()
	await frames()
	print("[screen_effect_layout_test] CHECKS=%d FAIL=%d" % [checks, failures])
	get_tree().quit(0 if failures==0 else 1)
