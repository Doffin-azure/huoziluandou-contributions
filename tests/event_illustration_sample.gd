extends Control
## One real event page, using saved riddles, with desktop and landscape captures.
const RUN = preload("res://src/expedition/room_run_state.gd")
const EVENTS = preload("res://src/core/event_effects.gd")
const RIDDLES = preload("res://src/data/lantern_riddles.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-19-event-art-sample"
var checks := 0
var failures := 0


func _ready() -> void:
	GameState.set_meta("courtyard_preview",true)
	Settings.reduced_motion = true
	get_window().size = Vector2i(1280,720)
	_run.call_deferred()


func _run() -> void:
	Router.host = self
	var run = RUN.start(29)
	var room := ""
	for id: String in run.graph.rooms:
		if run.graph.rooms[id].kind=="event": room = id; break
	run._arrive(room)
	run.event_data = RIDDLES.fill(EVENTS.get_event("lantern_riddle").duplicate(true),GameState.rng)
	run.event_node = "start"
	run.phase = "event"
	run._sync_content()
	var saved: Dictionary = run.event_data.duplicate(true)
	var before: int = GameState.rng.state
	Router.goto("res://src/screens/event_screen.gd",{"room_run":true})
	await frames()
	var screen: Control = Router.current
	check(screen._art.visible and screen._art.texture!=null,"catalog illustration loads in the real event page")
	check(screen._art.material is ShaderMaterial,"scene illustration uses presentation-only soft edges")
	check(run.event_data==saved and GameState.rng.state==before,"displaying art preserves saved riddles, rewards and gameplay RNG")
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(844,390)]:
		get_window().size = resolution
		await frames()
		check(not screen._art.get_global_rect().intersects(screen._copy.get_global_rect()),"art and text remain separate at "+str(resolution))
		check(screen._buttons.all(func(button): return button.size.y*float(resolution.y)/screen.size.y>=47.9),"choices retain physical touch targets")
		check(screen._leave_button.get_global_rect().end.y<=screen.get_global_rect().end.y,"leave action remains visible in landscape")
		check(screen._choice_labels.all(func(label):return not "铜钱" in label.text and not "气血" in label.text),"art page does not expose hidden riddle rewards")
		await capture("event-lantern-%dx%d.png" % [resolution.x,resolution.y])
	for id in ["ink_pool","broken_stele","old_bookshop"]:
		screen._event = EVENTS.node(EVENTS.get_event(id))
		screen._render_event()
		check(screen._art.texture.resource_path==EVENTS.get_event(id).illustration and screen._art.material==null,"existing ink illustration retains its own image and material: "+id)
	# Old saves may have the story and riddles but no illustration metadata.
	run.event_data.erase("illustration")
	run.event_data.erase("illustration_style")
	screen._event = run.current_event()
	screen._render_event()
	check(screen._art.visible and screen._art.material is ShaderMaterial,"old saved events acquire new catalog art without rerolling")
	check(GameState.rng.state==before,"old-save art fallback consumes no randomness")
	get_window().size = Vector2i(1280,720)
	await frames()
	screen._choose(0)
	screen._choose(0)
	await frames()
	check(run.resolved.has(room) and run.phase=="map","riddle selection settles once and returns to the route map")
	Music.stop()
	await get_tree().create_timer(.05).timeout
	print("[event_illustration_sample] PASS=%d FAIL=%d" % [checks-failures,failures])
	get_tree().quit(1 if failures else 0)


func frames() -> void:
	for i in 12: await get_tree().process_frame


func capture(filename: String) -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture"): return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(filename))


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
