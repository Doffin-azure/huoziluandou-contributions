extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-17-room-runtime"
var failures: Array = []
func _ready() -> void:
	get_window().size = Vector2i(1280,720)
	Settings.reduced_motion = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var host := Control.new(); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host); Router.host = host
	var run := RUN.new(); run.reset({"seed":17})
	Router.goto(RUN.MAP_SCREEN)
	await frames(24)
	await capture("01-start")
	if OS.get_cmdline_user_args().has("--still"):
		Router.current.map_view.show_overview(); await frames(50); await capture("00-initial-overview")
		print("[RoomRuntime] still capture completed")
		get_tree().quit(); return
	var screen: Control = Router.current
	screen.map_view.walk_to_room("opening_1")
	for i in 1400:
		await get_tree().process_frame
		if run.phase=="encounter": break
	if run.phase!="encounter": failures.append("walking arrival")
	await frames(12)
	await capture("02-encounter")
	screen._start_battle()
	await frames(24)
	if not Router.current_path.ends_with("battle_screen.gd"): failures.append("live battle entry")
	else:
		var battle = Router.current.battle
		await capture("03-battle")
		for enemy in battle.enemies: battle.deal_damage(enemy,99999,true)
		Router.current._check_battle_over()
		await frames(55)
		if not Router.current_path.ends_with("reward_screen.gd"): failures.append("live reward entry")
		else:
			await capture("04-reward")
			Router.current._on_skip()
			await frames(24)
			if run.phase!="map" or run.current_room!="opening_1" or not run.resolved.has("opening_1"): failures.append("battle return state")
			await capture("05-return")
	# Authoritative progression is shared with the headless interface; preview first fork.
	if run.phase=="map":
		run.enter_room("opening_2"); run.begin_live_battle(); run.finish_live_battle(true); run.apply({"type":"skip"})
		Router.goto(RUN.MAP_SCREEN)
		await frames(24)
		await capture("06-fork")
		Router.current.map_view.show_overview()
		await frames(50)
		await capture("07-overview")
	print("[RoomRuntime] failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))
