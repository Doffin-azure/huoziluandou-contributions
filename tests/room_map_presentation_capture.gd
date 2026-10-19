extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const ATLAS = preload("res://src/map/garden_route_overview.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-18-map-framing"
var failures: Array = []


func check(value: bool, label: String) -> void:
	if not value: failures.append(label); push_error(label)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	# Exercise the real entry scene, including the root canvas stretch behavior.
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var run := RUN.new()
	run.reset({"seed":17}); run.autosave = false
	var room_seeds := {}
	for id: String in run.graph.rooms: room_seeds[id] = run.graph.rooms[id].content_seed
	# Legacy saves have no spatial version and much wider coordinates.
	run.graph.erase("layout_version")
	for room: Dictionary in run.graph.rooms.values(): room.center *= 1.5
	GameState.gold = 67
	check(run.save_run("user://room-framing-legacy-test.tres")==OK,"legacy save written")
	var restored = RUN.restore("user://room-framing-legacy-test.tres")
	check(restored!=null,"legacy save migration")
	if restored!=null:
		run = restored; run.autosave = false
		check(run.graph.layout_version==4 and GameState.gold==67,"migration keeps gold and uses whole-site positions")
		for id: String in room_seeds: check(run.graph.rooms[id].content_seed==room_seeds[id],"content seed preserved")
		run._arrive("opening_1")
		run.position = run.layout.rooms.opening_1.stand_cell
	Router.goto(RUN.MAP_SCREEN)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		get_window().size = resolution
		await frames(65)
		verify_framing()
		await capture("01-local-1280" if resolution.x==1280 else "02-local-1920")
	var view: Control = Router.current.map_view
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true
	for i in 60: view._gui_input(wheel)
	check(is_equal_approx(view._zoom,1.4),"local zoom out is bounded")
	await frames(25)
	verify_framing()
	await capture("03-zoom-limit")
	view.recenter(); view.show_overview()
	await frames(15)
	verify_atlas()
	await capture("04-atlas-1920")
	get_window().size = Vector2i(800,1000)
	await frames(35)
	verify_atlas()
	await capture("05-atlas-portrait")
	view.recenter()
	await frames(60)
	verify_framing()
	await capture("06-local-portrait")
	print("[MapFraming] bounds=",run.layout.bounds," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func verify_framing() -> void:
	var screen: Control = Router.current
	var view: Control = screen.map_view
	check(view.room_roots.has(view.run.current_room),"current room models instantiated")
	if view.room_roots.has(view.run.current_room):
		check(view.room_roots[view.run.current_room].find_children("*","MeshInstance3D",true,false).size()>20,"room contains rendered architecture")
	var logical: Vector2 = get_viewport().get_visible_rect().size
	check(view.size.distance_to(logical)<2,"map fills logical window")
	var physical := Vector2(get_window().size)
	check(Vector2(view.viewport.size).distance_to(physical)<4,"3D renders at physical resolution")
	var room: Dictionary = view.run.layout.rooms[view.run.current_room]
	var projected := Rect2(view.screen_point(Vector3(room.bounds.position.x,0,room.bounds.position.y)),Vector2.ZERO)
	for x in [room.bounds.position.x,room.bounds.end.x]:
		for z in [room.bounds.position.y,room.bounds.end.y]:
			for y in [0.0,1.5]: projected = projected.expand(view.screen_point(Vector3(x,y,z)))
	check(view.safe_area().grow(8).encloses(projected),"court fits beside/before action panel")
	var foot: Vector3 = view.world_point(view.run.layout.rooms[view.run.current_room].stand_cell)
	var pixel: Vector2 = view.viewport_point(view.screen_point(foot))
	var hit: Vector3 = preload("res://src/expedition/garden_asset_layout.gd").ray_surface(view._surface_patches,view.camera.project_ray_origin(pixel),view.camera.project_ray_normal(pixel))
	check(hit.distance_to(foot)<.02,"projection and picking agree after physical scaling")
	print("[MapFraming] window=",get_window().size," logical=",logical," map=",view.size," render=",view.viewport.size," safe=",view.safe_area()," court=",projected," panel=",screen.drawer.size," camera=",view._distance)


func verify_atlas() -> void:
	var view: Control = Router.current.map_view
	var area: Rect2 = ATLAS.map_area(view.safe_area())
	var transform: Transform2D = ATLAS.transform_for(view.run,area)
	for id: String in view.run.graph.rooms:
		var point: Vector2 = transform*view.run.layout.rooms[id].bounds.get_center()
		check(area.grow(1).has_point(point),"atlas room fits: "+id)
		check(ATLAS.pick(view.run,point,view.safe_area())==id,"atlas picking: "+id)
	check(view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"atlas pauses detailed 3D rendering")


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))
