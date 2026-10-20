extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-18-furnished-rooms"
var failures: Array = []
var run: RefCounted


func check(value: bool, label: String) -> void:
	if not value: failures.append(label); push_error(label)


func _ready() -> void:
	get_window().size = Vector2i(1600,1000)
	var main: Control = load("res://scenes/main.tscn").instantiate(); add_child(main)
	run = RUN.new(); run.reset({"seed":17}); run.autosave = false
	Router.goto(RUN.MAP_SCREEN); await frames(15)
	var view: Control = Router.current.map_view
	for visual in view.room_roots.values():
		if not visual.revealed:
			for item in visual.occupied:
				if not str(item.label).begins_with("门"): check(not item.root.visible,"unexplored interior hidden")
	snap("12-runtime-start.png")
	# Stage real seeded rooms, then use the ordinary walking API inside the rest court.
	run._arrive("last_rest"); run.position = run.layout.rooms.last_rest.stand_cell
	Router.goto(RUN.MAP_SCREEN); await frames(15); snap("13-runtime-rest.png")
	view = Router.current.map_view
	run.phase = "map"
	var room: Dictionary = run.layout.rooms.last_rest
	var at: Vector2 = room.transform*Vector2(1.30,1.35)
	check(view.walk_to(run.layout.nearest(at,"last_rest")),"new pavilion is reachable")
	for i in 300:
		await get_tree().process_frame
		if not view._moving: break
	check(view.walker.position.y>.10 and view.walker.position.y<.13,"feet follow the raised pavilion floor")
	var visual: Node3D = view.room_roots.last_rest
	visual.update_occlusion(view.walker.global_position,view.camera)
	check(visual.occluders.any(func(item): return item.roof and item.faded),"new pavilion roof fades above the player")
	snap("14-runtime-pavilion-walk.png")
	var shop_id := ""
	for id: String in run.graph.rooms:
		if run.graph.rooms[id].kind=="shop": shop_id = id; break
	check(not shop_id.is_empty(),"seed has shop")
	if not shop_id.is_empty():
		run._arrive(shop_id); run.position = run.layout.rooms[shop_id].stand_cell
		Router.goto(RUN.MAP_SCREEN); await frames(15); snap("15-runtime-shop.png")
	run._arrive("boss"); run.position = run.layout.rooms.boss.stand_cell
	Router.goto(RUN.MAP_SCREEN); await frames(15); snap("16-runtime-boss.png")
	print("[RoomInteriorsRuntime] raised pavilion walking, roof fade, unexplored props hidden; failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func snap(filename: String) -> void:
	RenderingServer.force_draw(false)
	check(get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(filename))==OK,"capture "+filename)
