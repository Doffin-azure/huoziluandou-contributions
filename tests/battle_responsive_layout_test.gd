extends Control
## Compare real controls before/after status changes at desktop and Android densities.
const FOLDER := "res://docs/qa/battle-responsive-2026-10-18"
const GRID := ["流", "回", "击", "防", "击", "回", "重", "防", "御", "破", "击", "反", "加", "速", "充", "电"]
var passed := 0
var failed := 0
var capture := false
var baseline := false


func _ready() -> void:
	Settings.storage_path = "user://battle_responsive_layout_test-settings.cfg"
	capture = OS.get_cmdline_user_args().has("--capture")
	baseline = OS.get_cmdline_user_args().has("--before")
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()


func frames(n := 8) -> void:
	for i in n: await get_tree().process_frame


func check(value: bool, message: String) -> void:
	if value: passed += 1; print("PASS ", message)
	else: failed += 1; push_error(message)


func shot(tag: String) -> void:
	if not capture: return
	await frames()
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(FOLDER)
	get_viewport().get_texture().get_image().save_png(FOLDER.path_join(("before-" if baseline else "after-") + tag + ".png"))


func profile(dimensions: Vector2i, dpi: float) -> void:
	get_window().size = dimensions
	BattleTouchLayout.test_dpi = dpi
	await frames()
	GameState.start_new_run()
	GameState.rng.seed = 18
	var touch := dpi > 0
	var tag := "%dx%d-%ddpi" % [dimensions.x, dimensions.y, dpi]
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 7, "touch_layout": touch})
	await frames(14)
	var s := Router.current
	for i in GRID.size(): s.battle.board.cells[i] = CharInstance.new(Database.char_by_glyph[GRID[i]])
	s._refresh_all()
	await frames()
	var paper: Rect2 = s._preview_panel.get_global_rect()
	var board: Rect2 = s._board_view.get_global_rect()
	var enemy: Rect2 = s._enemy_paper.get_global_rect()
	var portrait: Rect2 = s._enemy_widgets[0]._portrait.get_global_rect()
	print("MEASURE ", tag, " viewport=", s.size, " board=", board, " paper=", paper)
	if not touch:
		check(board.size.y >= s.size.y * 0.70, tag + " desktop board occupies at least 70% of height")
		check(s._topbar.position.y <= s.size.y * 0.06, tag + " desktop header uses top of viewport")
		check(s._preview_panel.position.x <= s.size.x * 0.05, tag + " desktop paper uses left side of viewport")
	check(not paper.intersects(board), tag + " paper and board stay separate")
	await shot(tag + "-empty")
	# Actual solo play, not only assigning a mock status.
	s._board_view.path = [Vector2i(0, 0)]
	s._board_view._sync_selection()
	s._on_primary()
	for i in 180:
		await frames(1)
		if not s._busy: break
	check(not s._busy and s.battle.next_draw_penalty == -1, tag + " real solo play applies next-turn draw buff")
	await frames()
	check(s._preview_panel.get_global_rect().is_equal_approx(paper), tag + " first buff does not move or shrink paper")
	check(s._board_view.get_global_rect().is_equal_approx(board) and s._enemy_paper.get_global_rect().is_equal_approx(enemy), tag + " first buff does not shift board or enemy paper")
	check(s._enemy_widgets[0]._portrait.get_global_rect().is_equal_approx(portrait), tag + " player buff does not shift enemy portrait")
	await shot(tag + "-first-buff")
	s._on_end_turn()
	for i in 180:
		await frames(1)
		if not s._busy: break
	await frames()
	check(s.battle.turn == 2 and s.battle.next_draw_penalty == 0, tag + " real end turn expires draw buff")
	check(s._preview_panel.get_global_rect().is_equal_approx(paper), tag + " actual turn expiration keeps paper fixed")
	s.battle.player.heat = 3
	s.battle.player.energy = 2
	s.battle.player.block = 128
	s.battle.player.persistent_block = 256
	for ability in ["counter", "energy_idle", "longword_draw", "armor_plating", "repeat", "gravity_always", "flow", "vigor", "warm_heart", "strong_heart", "convert_block", "fireproof", "blastproof", "serial", "energy_regen", "prevent_interference"]:
		s.battle.enable_ability(ability, 2)
	s._refresh_all()
	await frames()
	check(s._preview_panel.get_global_rect().is_equal_approx(paper), tag + " many buffs do not shrink paper")
	var strip: StatusStrip = s._player_status
	check(not strip.get_global_rect().intersects(paper) and not strip.get_global_rect().intersects(board), tag + " status strip never covers paper or board")
	check(not strip.get_global_rect().intersects(s._player_hp_value.get_global_rect()) and not strip.get_global_rect().intersects(s._gold_strip.get_global_rect()), tag + " status strip does not cover HP or wallet")
	for button in strip._buttons:
		check(strip.get_global_rect().encloses(button.get_global_rect()), tag + " each status fits reserved row")
	check(strip.item_for("more") != strip, tag + " excessive buffs have a details entry")
	if touch:
		var unit := JourneyStyle.touch_scale(s)
		check(strip._buttons[0].size.y >= 48 * unit - 1 and s._end_btn.size.y >= 48 * unit - 1, tag + " phone keeps 48dp status and action targets")
	await shot(tag + "-many-buffs")
	s.battle.abilities.clear()
	s.battle.player.heat = 0
	s.battle.player.energy = 0
	s.battle.next_draw_penalty = 0
	s.battle.player.block = 0
	s.battle.player.persistent_block = 0
	s._refresh_all()
	await frames()
	check(s._preview_panel.get_global_rect().is_equal_approx(paper) and not strip.visible, tag + " removing all statuses leaves paper unchanged")
	for c in [s._preview_panel, s._board_view, s._enemy_panel, s._selection_actions, s._end_btn]:
		check(s.get_global_rect().encloses(c.get_global_rect()), tag + " main region fits viewport")
	# Long descriptions remain scrollable within the same paper, not a resize.
	s._bubble.set_text("防御", "\n".join(Array(["测试长词效：获得格挡，查看详细说明。", "测试长词效：下回合补字，查看详细说明。", "测试长词效：获得格挡，查看详细说明。", "测试长词效：下回合补字，查看详细说明。", "测试长词效：获得格挡，查看详细说明。", "测试长词效：下回合补字，查看详细说明。"])))
	await frames()
	check(s._preview_panel.get_global_rect().is_equal_approx(paper) and paper.encloses(s._bubble.get_global_rect()), tag + " long word descriptions stay within fixed scrollable paper")


func _run() -> void:
	Settings.reduced_motion = true
	Router.host = self
	for p in [[Vector2i(1280,720),0], [Vector2i(1920,1080),0], [Vector2i(2560,1440),0], [Vector2i(3200,1778),0], [Vector2i(3440,1440),0], [Vector2i(1280,720),320], [Vector2i(2400,1080),440]]:
		await profile(p[0], p[1])
	BattleTouchLayout.test_dpi = 0
	print("RESPONSIVE BATTLE: %d passed / %d failed" % [passed, failed])
	get_tree().quit(0 if baseline else 1 if failed else 0)
