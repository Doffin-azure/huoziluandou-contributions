extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const OUT := "res://docs/art-concepts/2026-10-17-bridge-kit"
func _ready() -> void:
	get_window().size = Vector2i(1600,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var host := Control.new(); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host); Router.host = host
	var run := RUN.new(); run.reset({"seed":17})
	Router.goto(RUN.MAP_SCREEN); await frames(18)
	var view: Control = Router.current.map_view
	print("[BridgeRuntime] ",view.bridge_network.get_meta("span_counts")," rail kits=",view.bridge_network.pieces.size())
	var first: Dictionary = view.bridge_network.features[0]
	var midpoint: Vector2 = first.start+first.direction*first.length*.5
	if not view.walk_to(run.layout.cell(midpoint)):
		push_error("Initial gallery must be reachable by actual walking"); get_tree().quit(1); return
	for i in 1000:
		await get_tree().process_frame
		if not view._moving: break
	view._distance = 11.5
	await frames(20); await capture("06-runtime-gallery")
	var faded := false
	for kit in view.bridge_network.instances.values():
		if kit.kind=="gallery" and kit.roof_faded: faded = true
	print("[BridgeRuntime] actual gallery walking and roof fade=",faded)
	if not faded: push_error("Gallery roof must fade above the player")
	for kind in ["arch","pier"]:
		var feature: Dictionary = view.bridge_network.features.filter(func(f): return f.kind==kind)[0]
		var source: String = feature.edge.split(">")[0]
		run.current_room = source; run.resolved[source] = true; run.visited_rooms[source] = true
		var center: Vector2 = feature.start+feature.direction*feature.length*.5
		run.position = run.layout.cell(center)
		Router.goto(RUN.MAP_SCREEN); await frames(18)
		view = Router.current.map_view; view._distance = 11.5
		await frames(12); await capture("07-runtime-arch" if kind=="arch" else "08-runtime-pier")
	var source := "opening_2"
	run.current_room = source; run.resolved[source] = true; run.visited_rooms[source] = true
	run.position = run.layout.rooms[source].stand_cell
	Router.goto(RUN.MAP_SCREEN); await frames(18)
	view = Router.current.map_view
	var port: Vector2 = run.layout.rooms[source].output.at
	view._follow = false; view._look = Vector3(port.x,.2,port.y-5); view._target = view._look; view._distance = 22
	view.bridge_network.refresh(Vector2(port.x,port.y-5),run)
	await frames(16); await capture("09-runtime-junction")
	print("[BridgeRuntime] Runtime gallery, arch, pier and junction captured")
	get_tree().quit(0 if faded else 1)

func frames(count: int) -> void:
	for i in count: await get_tree().process_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT.path_join(name+".png"))
