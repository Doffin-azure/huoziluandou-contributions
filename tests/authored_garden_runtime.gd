extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-18-authored-garden-runtime"
var failures: Array = []
var run: RefCounted


func check(value: bool, label: String) -> void:
	if not value: failures.append(label); push_error(label)


func _ready() -> void:
	get_window().size = Vector2i(1600,1000); await frames(2)
	add_child(load("res://scenes/main.tscn").instantiate())
	run = RUN.new(); run.reset({"seed":29,"layout":"authored_garden"}); run.autosave = false
	Router.goto(RUN.MAP_SCREEN); await frames(35)
	var screen: Control = Router.current
	var view: Control = screen.map_view
	check(view.authored_root!=null and view.room_roots.is_empty(),"whole garden replaces per-node room slabs")
	check(view.authored_root.houses.size()>18,"joined galleries and walk-through houses built")
	var before_safe: Rect2 = view.safe_area(); var before_distance: float = view._distance
	screen._toggle_inventory(); await frames(5)
	check(screen.inventory.visible and before_safe.is_equal_approx(view.safe_area()) and is_equal_approx(before_distance,view._distance),"inventory does not reframe the authored site")
	screen._set_inventory_open(false); await frames(4)
	await snap("01-playable-entry.png")
	view.show_overview(); await frames(4); await snap("06-route-atlas.png")
	var atlas = preload("res://src/map/garden_route_overview.gd")
	var transform: Transform2D = atlas.transform_for(run,atlas.map_area(view.safe_area()))
	for id: String in run.layout.rooms:
		check(atlas.pick(run,transform*run.layout.rooms[id].stand,view.safe_area())==id,"authored atlas picking: "+id)
	view.recenter(); await frames(20)
	if OS.get_cmdline_user_args().has("--overview"):
		await full_view(view)
		print("[AuthoredGardenRuntime] overview failures=",failures)
		get_tree().quit(0 if failures.is_empty() else 1); return
	check(view.walk_to_room("opening_1"),"start actual walking from gatehouse")
	await arrive(view)
	check(run.current_room=="opening_1" and run.phase=="encounter","walk through hall starts encounter")
	await frames(20); await snap("02-hall-encounter.png")
	screen._start_battle(); await frames(12)
	check(Router.current_path.ends_with("battle_screen.gd"),"live battle opens")
	if Router.current_path.ends_with("battle_screen.gd"):
		var battle = Router.current.battle
		for enemy in battle.enemies: battle.deal_damage(enemy,99999,true)
		Router.current._check_battle_over(); await frames(40)
		check(Router.current_path.ends_with("reward_screen.gd"),"ordinary live reward screen")
		if Router.current_path.ends_with("reward_screen.gd"): Router.current._on_skip(); await frames(20)
	check(Router.current_path.ends_with("room_map_screen.gd") and run.phase=="map","battle reward returns to fixed garden")
	view = Router.current.map_view
	check(view.walk_to_room("opening_2"),"start walking through corrected wall opening")
	await arrive(view); resolve(); Router.current.refresh(); await frames(8)
	var branch: Array = run.graph.groups[0].branches[0]
	for id: String in branch:
		check(view.walk_to_room(id),"real walk to "+id)
		await arrive(view)
		check(run.current_room==id,"arrive "+id)
		resolve(); Router.current.refresh(); await frames(8)
	await snap("03-pavilion-water-tail.png")
	check(view.walk_to_room("treasure_merge"),"walk over short water-mouth bridge")
	await arrive(view); await frames(15)
	check(run.phase=="reward" and Router.current_path.ends_with("reward_screen.gd"),"water pavilion opens treasure reward")
	if Router.current_path.ends_with("reward_screen.gd"): Router.current._on_skip(); await frames(20)
	view = Router.current.map_view
	for id: String in run.graph.groups[0].branches[1]: check(run.sealed.has(id),"opposite branch remains sealed")
	var foot: Vector3 = view.world_point(run.position)
	var pixel: Vector2 = view.viewport_point(view.screen_point(foot))
	var hit: Vector3 = preload("res://src/expedition/garden_asset_layout.gd").ray_surface(view._surface_patches,view.camera.project_ray_origin(pixel),view.camera.project_ray_normal(pixel))
	check(hit.distance_to(foot)<.02,"picking and world position agree after bridge and reward return")
	await snap("04-water-pavilion-return.png")
	await full_view(view)
	print("[AuthoredGardenRuntime] failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func resolve() -> void:
	match run.phase:
		"encounter": run.begin_live_battle(); run.finish_live_battle(true); run.apply({"type":"skip"})
		"rest": run.apply({"type":"leave_service"})


func full_view(view: Control) -> void:
	# Explicitly labelled inspection capture: show all architecture and water.
	view.set_safe_area(Rect2(Vector2(16,16),view.size-Vector2(32,84)))
	view._follow = false; view._look = Vector3(28,0,24); view._target = view._look
	var back: Vector3 = view._camera_back()
	var right := Vector3(back.z,0,-back.x).normalized(); var up := back.cross(right)
	var tan_v := tan(deg_to_rad(view.camera.fov*.5)); var tan_h: float = tan_v*view.size.x/view.size.y
	var distance := 10.0
	for x in [run.layout.bounds.position.x,run.layout.bounds.end.x]:
		for z in [run.layout.bounds.position.y,run.layout.bounds.end.y]:
			for y in [-.75,4.5]:
				var delta: Vector3 = Vector3(x,y,z)-view._look
				distance = maxf(distance,delta.dot(back)+absf(delta.dot(right))/(tan_h*.9))
				distance = maxf(distance,delta.dot(back)+absf(delta.dot(up))/(tan_v*view.safe_area().size.y/view.size.y*.9))
	view._distance = distance
	view.camera.far = 200; view._update_camera()
	view.authored_root.reveal_all = true
	view._overlay.visible = false
	view.authored_root.refresh(run,Vector2(47,43))
	var image := Image.create(2,2,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	view.ground.set_shader_parameter("fog_mask",texture); view.water_paint.set_shader_parameter("fog_mask",texture)
	view.authored_root.update_fog(texture,run.layout.bounds)
	Router.current.drawer.visible = false
	await frames(8); await snap("05-whole-garden-inspection.png")


func arrive(view: Control) -> void:
	for i in 1800:
		await get_tree().process_frame
		if not is_instance_valid(view) or not view._moving: return
	check(false,"walking frame limit")


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func snap(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(filename))
