extends Control
var passed := 0
var failed := 0
var capture := false
var before := false
var folder := "res://docs/qa/touch-access-2026-10-18"


func _ready() -> void:
	Settings.storage_path = "user://touch_access_audit_test-settings.cfg"
	capture = OS.get_cmdline_user_args().has("--capture")
	before = OS.get_cmdline_user_args().has("--before")
	get_tree().create_timer(100).timeout.connect(func():
		push_error("touch audit timed out")
		get_tree().quit(1))
	_run.call_deferred()


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func check(value: bool, message: String) -> void:
	if value: passed += 1; print("PASS ", message)
	else: failed += 1; push_error(message)


func page(name: String) -> Control:
	GameState.start_new_run()
	GameState.rng.seed = 20261018
	GameState.gold = 100
	if name == "expedition_map": Expedition.start(42)
	Router.goto("res://src/screens/%s_screen.gd" % name)
	await frames(12)
	return Router.current


func shot(name: String) -> void:
	if not capture: return
	await frames(10)
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(folder)
	check(get_viewport().get_texture().get_image().save_png(folder.path_join(("before-" if before else "after-") + name + ".png")) == OK, "archive " + name)


func touch(point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = get_viewport().get_final_transform() * point
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)


func tap(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	touch(point, true)
	await frames(1)
	touch(point, false)
	await frames(3)


func overlay_on(screen: Control) -> ChoiceOverlay:
	for child in screen.get_children():
		if child is ChoiceOverlay and not child.is_queued_for_deletion(): return child
	return null


func cancel_overlay(screen: Control) -> void:
	var overlay := overlay_on(screen)
	if overlay != null:
		var event := InputEventAction.new()
		event.action = "cancel_selection"
		event.pressed = true
		overlay._unhandled_input(event)
	await frames()


func press_named(host: Node, text: String) -> bool:
	for button in host.find_children("*", "Button", true, false):
		if button.text == text:
			button.pressed.emit()
			return true
	return false


func audit_profile(profile: Array) -> void:
	get_window().size = Vector2i(profile[0], profile[1])
	BattleTouchLayout.test_dpi = profile[2]
	await frames()
	var tag := "%dx%d" % [profile[0], profile[1]]
	var screen := await page("custom_deck")
	var character: CharacterData = screen._pool[0]
	var tile: Control = screen._tiles[character.glyph]
	var point := tile.get_global_rect().get_center()
	touch(point, true)
	await frames(1)
	check(screen._total() == 0, tag + " finger down does not add glyph")
	touch(point, false)
	await frames()
	check(screen._total() == 1, tag + " native GUI tap adds once")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = tile.size * 0.5
	screen._on_tile_input(mouse, character)
	check(screen._total() == 1, "emulated mouse duplicate ignored")
	touch(point, true)
	for distance in [32, 64]:
		var drag := InputEventScreenDrag.new()
		drag.position = get_viewport().get_final_transform() * (point - Vector2(0, distance))
		drag.relative = Vector2(0, -32) * get_viewport().get_final_transform().get_scale()
		Input.parse_input_event(drag)
		await frames(2)
	touch(point, false)
	await frames()
	check(screen._total() == 1, "scroll gesture does not edit deck")
	# A scroll must actually move the list, not merely suppress a click.
	var scroll := screen._grid.get_parent().get_parent() as ScrollContainer
	check(scroll.scroll_vertical > 0, "drag over glyph reaches the scroll container")
	scroll.scroll_vertical = 0
	await frames()
	point = tile.get_global_rect().get_center()
	touch(point, true)
	touch(point, false, true)
	check(screen._total() == 1, "canceled finger does not edit deck")
	for button in screen.find_children("*", "Button", true, false):
		if button.text == "查看字效": await tap(button)
	check(screen._inspect_mode, "native tap enables glyph inspect mode")
	var rng_state := GameState.rng.state
	await tap(tile)
	var overlay := overlay_on(screen)
	check(overlay != null and character.description in str(overlay.cfg.body), "glyph effect readable by native tap")
	check(screen._total() == 1 and GameState.rng.state == rng_state, "reading glyph preserves deck and RNG")
	check(screen._start_btn.get_global_rect().end.x <= screen.size.x, "custom deck footer stays inside viewport")
	await shot("custom_deck-" + tag)
	touch(Vector2(5, 5), true)
	touch(Vector2(5, 5), false)
	await frames()
	check(overlay_on(screen) == null, "back dismisses glyph description")
	screen = await page("map")
	await tap(screen._node_views[0])
	overlay = overlay_on(screen)
	check(overlay != null and str(overlay.cfg.body).length() > 0, "native route tap previews node")
	await shot("map-" + tag)
	await cancel_overlay(screen)
	check(Router.current == screen and GameState.node_index == 1, "cancel route preview never enters node")
	screen._on_node_pressed(1, screen.act.nodes[1])
	overlay = overlay_on(screen)
	check(overlay != null and "尚未到达" in str(overlay.cfg.body), "future route node inspectable without entering")
	await cancel_overlay(screen)
	screen = await page("expedition_map")
	var ex = screen.ex
	var cell: Button
	for child in screen._map_grid.get_children():
		if not child.tooltip_text.is_empty() and not ex.can_step(child.get_index()):
			cell = child
			break
	check(cell != null, "expedition contains visible marker or beacon")
	var state := [ex.t, ex.pos, ex.ink, GameState.player_hp, GameState.rng.state]
	if cell != null:
		cell.pressed.emit()
		overlay = overlay_on(screen)
		check(overlay != null and cell.tooltip_text in str(overlay.cfg.body), "map tooltip available as touch details")
		await shot("expedition_map-" + tag)
		await cancel_overlay(screen)
	check(state == [ex.t, ex.pos, ex.ink, GameState.player_hp, GameState.rng.state], "map inspection preserves resources, time and RNG")
	screen._confirm_touch_action("使用超能力", "定住首领 6 步", func(): ex.use_power())
	await cancel_overlay(screen)
	check(state == [ex.t, ex.pos, ex.ink, GameState.player_hp, GameState.rng.state], "cancel power preview preserves turn and resources")
	var neighbor := -1
	for child in screen._map_grid.get_children():
		if ex.can_step(child.get_index()):
			neighbor = child.get_index()
			break
	check(neighbor >= 0, "expedition has walkable neighbor")
	if neighbor >= 0:
		screen._on_map_cell(neighbor, "测试机关：确认前不推进")
		await cancel_overlay(screen)
		check(ex.pos == state[1] and ex.t == state[0], "cancel marker movement does not spend a step")
		screen._on_map_cell(neighbor, "测试机关：确认前不推进")
		overlay_on(screen)._on_choose(0)
		await frames()
		check(ex.pos == neighbor and ex.t > state[0], "explicit confirmation moves exactly once")
	screen = await page("battle")
	GameState.relics = [Relics.DEFS.keys()[0]]
	screen.battle.relics = GameState.relics.duplicate()
	screen._refresh_all()
	var battle_state := [screen.battle.turn, screen.battle.rng.state, screen.battle.player.hp]
	PauseMenu.open()
	await frames()
	check(press_named(PauseMenu._instance, "战斗与遗物说明"), "battle guide has explicit menu entry")
	await frames(12)
	overlay = overlay_on(screen)
	check(overlay != null and Relics.text(GameState.relics[0]) in str(overlay.cfg.body), "battle relic effect readable after closing pause")
	await shot("battle-" + tag)
	await cancel_overlay(screen)
	check(screen._modal_count == 0 and battle_state == [screen.battle.turn, screen.battle.rng.state, screen.battle.player.hp], "battle guide releases lock without advancing battle")
	var label := EffectText.new()
	label.position = Vector2(10, 10)
	label.size = Vector2(200, 60)
	label.set_effect_text("反击")
	screen.add_child(label)
	label.meta_hover_started.emit("term:counter")
	check(label._cards.is_empty(), "touchscreen hover cannot open transient glossary")
	label.meta_clicked.emit("term:counter")
	await frames()
	label._hovered.clear()
	label._update_help(1.0, Vector2.ZERO)
	check(label._pinned and label._cards.size() == 1, "touch glossary stays open for reading")
	screen._board_view.clear_selection()
	var board_point := Vector2.ZERO
	for board_tile in screen._board_view.tiles:
		var candidate: Vector2 = board_tile.get_global_rect().get_center()
		if board_tile.instance != null and not label.contains_pointer(candidate):
			board_point = candidate
			break
	check(board_point != Vector2.ZERO, "board has a glyph outside glossary")
	touch(board_point, true)
	touch(board_point, false)
	await frames()
	check(label._cards.is_empty() and screen._board_view.path.is_empty(), "outside native tap closes glossary without selecting board")
	label.queue_free()
	for name in ["shop", "reward"]:
		screen = await page(name)
		var gold := GameState.gold
		var deck_size := GameState.deck_size()
		await tap(screen._cards[1])
		check(screen._selected == 1, name + " native tap updates detail panel")
		check(GameState.gold == gold and GameState.deck_size() == deck_size and not screen._busy, name + " preview does not buy or claim")
	screen = await page("glyph_graph")
	var graph: GlyphGraphView = screen._view
	var node: Dictionary = graph.nodes[0]
	var node_point: Vector2 = graph.get_global_transform() * graph.world_to_canvas(node.pos)
	touch(node_point, true)
	touch(node_point, false)
	await frames()
	check(graph.selected == node.glyph and screen._detail.get_child_count() > 0, "native graph tap opens node details")
	if is_instance_valid(screen._details_overlay):
		screen._details_overlay._on_choose(0)
		await frames()
	var collection := CollectionOverlay.new()
	collection.setup({"characters": [character], "pick_on_click": true})
	var picked: Array = []
	collection.picked.connect(func(value): picked.append(value))
	screen.add_child(collection)
	await frames()
	await tap(collection._grid.get_child(0))
	check(picked.size() == 1 and picked[0] == character, "native collection card tap picks exactly once")


func _run() -> void:
	# Enable ScrollContainer's touchscreen path on desktop/headless runners.
	Input.set_emulate_touch_from_mouse(true)
	Settings.reduced_motion = true
	Router.host = self
	get_window().size = Vector2i(1600, 720)
	BattleTouchLayout.test_dpi = 320
	await frames()
	if before:
		for name in ["custom_deck", "map", "expedition_map", "battle"]:
			var screen := await page(name)
			if name == "expedition_map": screen._mobile_tabs.show_tab("整备")
			if name == "battle":
				GameState.relics = [Relics.DEFS.keys()[0]]
				screen.battle.relics = GameState.relics.duplicate()
				screen._refresh_all()
				PauseMenu.open()
			await shot(name)
	else:
		for profile in [[1600, 720, 320], [2400, 1080, 440], [1280, 720, 320]]:
			await audit_profile(profile)
	BattleTouchLayout.test_dpi = 0
	Router.current.queue_free()
	await frames()
	Router.release_host(self)
	print("[touch_access_audit] PASS=%d FAIL=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
