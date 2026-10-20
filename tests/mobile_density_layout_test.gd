extends Control
## Native layout regression, with explicit simulated Android density (not device performance).
var passed := 0
var failed := 0

func _ready() -> void:
	Settings.storage_path = "user://mobile_density_layout_test-settings.cfg"
	_run.call_deferred()

func frames(n := 8) -> void:
	for i in n: await get_tree().process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS ", message)
	else:
		failed += 1
		push_error(message)

func page(name: String) -> Control:
	GameState.start_new_run("v03")
	GameState.gold = 80
	GameState.rng.seed = 20261016
	if name == "expedition_map": Expedition.start(20261016)
	Router.goto("res://src/screens/%s_screen.gd" % name)
	await frames()
	return Router.current

func visible_rect(c: Control) -> Rect2:
	var rect := c.get_global_rect()
	var parent := c.get_parent()
	while parent != null:
		if parent is Control and parent.clip_contents:
			rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	return rect

func _run() -> void:
	var previous_motion := Settings.reduced_motion
	Settings.reduced_motion = true
	Router.host = self
	for profile in [[2436,1120,480], [1600,720,320], [2400,1080,440], [3200,1440,560], [1280,720,320]]:
		get_window().size = Vector2i(profile[0],profile[1])
		BattleTouchLayout.test_dpi = profile[2]
		await frames()
		var screen := await page("map")
		var unit := JourneyStyle.touch_scale(screen)
		check(screen._route_scroll.size.y >= screen.size.y * 0.72, "route retains 72%% height at %s" % str(profile))
		check(screen._node_views.all(func(c): return c.size.x >= 44 * unit and c.size.y >= 44 * unit), "route nodes retain touch targets")
		check(screen._node_views.all(func(c): return c.get_rect().position.y >= 0 and c.get_rect().end.y <= screen._canvas.size.y), "route node captions remain inside route")
		GameState.node_index = screen._node_views.size()
		screen._layout()
		await frames()
		check(visible_rect(screen._node_views[-1]).size.x >= 44 * unit, "late route focuses the current node")
		screen = await page("rest")
		var buttons := screen.find_children("*", "Button", true, false)
		for button in buttons:
			if button.text.begins_with("选择"):
				check(visible_rect(button).size.y >= 47 * unit, "rest action visible without scrolling: " + button.text)
		screen = await page("custom_deck")
		var glyph: CharacterData = screen._pool[0]
		screen._add(glyph.glyph)
		screen._remove_mode = true
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		screen._on_tile_input(tap, glyph)
		check(screen._total() == 0, "touch removal needs no right mouse button")
		screen = await page("expedition_map")
		check(screen._map_scroll.size.y >= screen.size.y * 0.65, "expedition retains 65% map height")
		check(screen._map_scroll.size.x > screen._mobile_tabs.size.x, "map has priority over inspector width")
		var current := screen._map_grid.get_child(screen.ex.pos) as Control
		check(visible_rect(current).size.y >= 47 * unit, "current expedition cell visible")
		var rng_state := GameState.rng.state
		var steps: int = screen.ex.t
		for tab in ["字阵", "战报", "整备", "行旅"]:
			screen._mobile_tabs.show_tab(tab)
			await frames(2)
		screen._mobile_tabs.show_tab("整备")
		await frames()
		check(screen._relic_label.size.y >= screen._relic_label.get_theme_font_size("font_size"), "relic summary has a readable line height")
		check(screen.ex.t == steps and GameState.rng.state == rng_state, "tabs preserve steps and RNG")
		screen._open_guide()
		await frames()
		var overlays := screen.find_children("*", "Control", false, false).filter(func(c): return c is ChoiceOverlay)
		check(overlays.size() == 1 and overlays[0].cfg.body.contains("被追上") and overlays[0].cfg.body.contains("「封」"), "touch guide retains chase and ambush rules")
		if not overlays.is_empty():
			var close_buttons: Array = overlays[0].find_children("*", "Button", true, false)
			check(not close_buttons.is_empty() and visible_rect(close_buttons[0]).size.y >= 47 * unit, "guide close action visible before scrolling")
			overlays[0]._on_choose(0)
		await frames()
		check(screen.ex.t == steps and GameState.rng.state == rng_state, "reading guide preserves gameplay state")
	BattleTouchLayout.test_dpi = 0
	Settings.reduced_motion = previous_motion
	print("DENSITY LAYOUT: ", passed, " passed, ", failed, " failed")
	get_tree().quit(1 if failed else 0)
