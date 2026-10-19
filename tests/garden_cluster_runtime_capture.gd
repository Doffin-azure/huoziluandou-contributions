extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const SURFACE = preload("res://src/expedition/garden_asset_layout.gd")
var output := "res://docs/art-concepts/2026-10-18-cluster-runtime"
var failures: Array = []
var run: RefCounted


func check(value: bool, label: String) -> void:
	if not value: failures.append(label); push_error(label)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	get_window().size = Vector2i(1600,1000)
	var main: Control = load("res://scenes/main.tscn").instantiate(); add_child(main)
	run = RUN.new(); run.reset({"seed":29}); run.autosave = false
	for id in ["opening_1","opening_2"]:
		check(run.enter_room(id).ok,"reach forecourt "+id); resolve()
	Router.goto(RUN.MAP_SCREEN); await frames(25)
	var view: Control = Router.current.map_view
	var cluster: Dictionary = run.layout.clusters[0]
	check(view.cluster_roots.has(cluster.id),"live viewport instantiates the shared garden")
	for visual in view.room_roots.values():
		if not visual.revealed:
			for item in visual.occupied:
				if not str(item.label).begins_with("门"): check(not item.root.visible,"unexplored interior hidden")
	check(not view.walk_to(run.layout.cell(cluster.ponds[0].center)),"main pond cannot be clicked as a walkable route")
	snap("04-runtime-fork.png")
	var branch: Array = run.graph.groups[0].branches[1]
	for id: String in branch:
		check(view.walk_to_room(id),"start native walking to "+id)
		await arrive(view)
		check(run.current_room==id,"native walking reaches "+id)
		var point: Vector3 = view.world_point(run.position)
		var pixel: Vector2 = view.viewport_point(view.screen_point(point))
		var hit: Vector3 = SURFACE.ray_surface(view._surface_patches,view.camera.project_ray_origin(pixel),view.camera.project_ray_normal(pixel))
		check(hit.distance_to(point)<.02,"projection and picking agree at "+id)
		if not run.layout.rooms[id].get("ponds",[]).is_empty():
			await frames(20); snap("05-runtime-inner-pond.png")
		resolve(); Router.current.refresh(); await frames(10)
	var merge: String = run.graph.groups[0].merge
	check(view.walk_to_room(merge),"start walking to garden merge")
	await arrive(view)
	check(run.current_room==merge,"native walking reaches merge")
	check(run.phase=="reward","treasure opens the ordinary reward screen")
	resolve(); Router.goto(RUN.MAP_SCREEN); await frames(25)
	view = Router.current.map_view
	check(view.cluster_roots.has(cluster.id),"shared landscape survives returning from rewards")
	for id: String in run.graph.groups[0].branches[0]:
		check(run.sealed.has(id) and not run.walkable(run.layout.rooms[id].stand_cell),"discarded wing remains closed at merge")
	await frames(20); snap("06-runtime-merge.png")
	print("[GardenClusterRuntime] real walking / fog / water picking / merge seals; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func resolve() -> void:
	match run.phase:
		"encounter": run.begin_live_battle(); run.finish_live_battle(true); run.apply({"type":"skip"})
		"reward": run.apply({"type":"skip"})
		"event": run.apply({"type":"event","index":run.event_data.get("options",[]).size()-1})
		"rest": run.apply({"type":"leave_service"})


func arrive(view: Control) -> void:
	for i in 900:
		await get_tree().process_frame
		# The treasure arrival intentionally replaces the map with the reward screen.
		if not is_instance_valid(view):
			check(run.phase=="reward","viewport replacement is the reward transition")
			return
		if not view._moving: return
	check(false,"walking completes within the frame budget")


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func snap(filename: String) -> void:
	RenderingServer.force_draw(false)
	check(get_viewport().get_texture().get_image().save_png(output.path_join(filename))==OK,"capture "+filename)
