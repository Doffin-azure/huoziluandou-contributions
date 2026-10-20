extends Control
## Current adventure has one deck: no tray, layout grid, or inventory overlay.
const RUN = preload("res://src/expedition/room_run_state.gd")
var failures: Array = []
var checks := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)


func _ready() -> void: run_checks.call_deferred()


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func run_checks() -> void:
	GameState.set_meta("courtyard_preview",true)
	Settings.reduced_motion = true
	Engine.max_fps = 120
	get_window().size = Vector2i(1280,720)
	Router.host = self
	var run: RefCounted = RUN.start(29)
	Router.goto(RUN.MAP_SCREEN)
	await frames()
	var screen: Control = Router.current
	check(not run.get_property_list().any(func(p):return p.name in ["tray","plate","active"]),"current run has no retired inventory fields")
	check(not screen.has_method("_open_inventory") and not screen.has_method("_refresh_inventory"),"map no longer creates a tray or plate overlay")
	for resolution in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(844,390)]:
		get_window().size = resolution
		await frames(12)
		var buttons := screen.find_children("*","Button",true,false)
		check(buttons.all(func(button):return not button.text.contains("字匣") and not button.text.contains("版面")),"map has no tray or plate controls at "+str(resolution))
		check(screen.get_global_rect().encloses(screen._stats.get_global_rect()),"stats fit the map header at "+str(resolution))
		var positions: Dictionary = screen.map_view.points.duplicate()
		var rng_before := GameState.rng.state
		var counts := GameState.glyph_counts()
		screen._open_deck(); await frames()
		var overlay: CollectionOverlay
		for child in screen.get_children():
			if child is CollectionOverlay and not child.is_queued_for_deletion(): overlay = child; break
		check(overlay!=null and overlay.cfg.counts==counts,"deck button still shows the actual combat deck")
		var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
		get_viewport().push_input(escape); await frames()
		check(not is_instance_valid(overlay) and screen.map_view.points==positions and GameState.rng.state==rng_before and GameState.glyph_counts()==counts,"closing the deck preserves map layout and gameplay state")
	check(PauseMenu._instance==null,"closing the deck does not also open pause")
	print("[InventoryUI] checks=",checks," failures=",failures.size())
	Music.stop()
	await frames(2)
	get_tree().quit(0 if failures.is_empty() else 1)
