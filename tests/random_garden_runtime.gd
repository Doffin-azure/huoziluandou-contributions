extends Node
## Native viewport and UI integration; no player autosave is touched.
const RUN = preload("res://src/expedition/room_run_state.gd")
const ATLAS = preload("res://src/map/garden_route_overview.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-18-garden-optimization"
var failures: Array = []
var run: RefCounted
var measurements: Array = []


func check(value: bool, label: String) -> void:
	if not value: failures.append(label); push_error(label)


func _ready() -> void:
	Engine.max_fps = 120
	get_window().size = Vector2i(1560,720) if OS.get_cmdline_user_args().has("--mobile-map") else Vector2i(1600,1000); await frames(2)
	add_child(load("res://scenes/main.tscn").instantiate())
	for seed_value in [17,67]:
		run = RUN.new(); run.reset({"seed":seed_value,"layout":"random_garden"}); run.autosave = false
		print("[GardenGeneration] seed=",seed_value," time_ms=",run.generation_ms)
		check(run.generation_error.is_empty(),"native generated site")
		Router.goto(RUN.MAP_SCREEN); await map_ready(); await frames(12)
		var view: Control = Router.current.map_view
		check(view.authored_root!=null and view.room_roots.is_empty(),"random site uses continuous assembly")
		check(view.authored_root.get_meta("wall_post_count",0)>view.authored_root.get_meta("wall_edge_count",0),"every wall bay has joined posts")
		check(view.authored_root.get_meta("gallery_joint_count",0)>0,"joined gallery corner roofs")
		await test_touch(view)
		view.show_overview(); await frames(3)
		var transform: Transform2D = ATLAS.transform_for(run,ATLAS.map_area(view.safe_area()))
		for id: String in run.layout.rooms: check(ATLAS.pick(run,transform*run.layout.rooms[id].stand,view.safe_area())==id,"random atlas pick: "+id)
		await snap("seed-%d-atlas.png" % seed_value)
		view.recenter(); await frames(12)
		await snap("seed-%d-entry.png" % seed_value)
		await measure(view,seed_value,"local-entry")
		if seed_value==17 and not OS.get_cmdline_user_args().has("--inspect-only"):
			check(view.walk_to_room("opening_1"),"real walk through rotated gatehouse")
			var walking_samples := []; var walking_clock := Time.get_ticks_usec()
			for i in 1800:
				await get_tree().process_frame
				var now := Time.get_ticks_usec(); walking_samples.append((now-walking_clock)/1000.0); walking_clock = now
				if not view._moving: break
			walking_samples.sort()
			measurements.append({"seed":seed_value,"scenario":"walking-to-first-hall","frames":walking_samples.size(),"frame_median_ms":walking_samples[walking_samples.size()/2],"frame_p95_ms":walking_samples[floori(walking_samples.size()*.95)]})
			check(run.phase=="encounter" and run.current_room=="opening_1","arrival starts node gameplay")
			view._follow = false
			var map_identity: int = view.get_instance_id(); var saved_look: Vector3 = view._look; var saved_distance: float = view._distance
			Router.current._start_battle(); await frames(10)
			check(not view._active and view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"cached map sleeps during battle")
			check(Router.current_path.ends_with("battle_screen.gd"),"random battle opens live scene")
			if Router.current_path.ends_with("battle_screen.gd"):
				var battle = Router.current.battle
				for enemy in battle.enemies: battle.deal_damage(enemy,99999,true)
				Router.current._check_battle_over(); await frames(25)
			check(Router.current_path.ends_with("reward_screen.gd"),"random battle opens reward UI")
			if Router.current_path.ends_with("reward_screen.gd"): Router.current._on_skip(); await frames(15)
			check(Router.current_path.ends_with("room_map_screen.gd") and run.phase=="map","reward returns to same generated garden")
			view = Router.current.map_view
			check(view.get_instance_id()==map_identity and view.profile.build_count==1,"reward reuses map with no rebuild")
			check(view._look.is_equal_approx(saved_look) and is_equal_approx(view._distance,saved_distance),"reward preserves camera position and zoom")
			print("[GardenProfile] ",view.profile)
			check(run.enter_room("passage_event").get("ok",false),"shared first event stop")
			settle(); Router.current.refresh(); await frames(4)
			check(view.walk_to_room("opening_2"),"next generated door has real path")
			# Finish the walk with the same run steps; native animation already
			# checked above. The remaining checks focus on actual service widgets.
			view._route.clear(); view._moving = false
			check(run.enter_room("opening_2").get("ok",false),"second encounter")
			settle(); Router.current.refresh(); await frames(4)
			for g in 3:
				var preferred := 0
				for b in 2:
					if run.graph.groups[g].branches[b].any(func(id): return run.graph.rooms[id].kind in (["rest"] if g==0 else (["shop"] if g==1 else ["elite"]))): preferred = b
				var order: Array = run.graph.groups[g].branches[preferred].duplicate(); order.append(run.graph.groups[g].merge)
				if g<2: order.append("pond_event" if g==0 else "rear_event")
				for id: String in order:
					check(run.enter_room(id).get("ok",false),"generated node reachable: "+id)
					Router.current.refresh(); await frames(5)
					if run.phase in ["rest","shop","event"]:
						check(Router.current.drawer.visible and Router.current.choices_box.get_child_count()>2,"node action drawer: "+run.phase)
						await snap("node-%s.png" % run.phase)
					settle(); await frames(8)
					if Router.current_path.ends_with("room_map_screen.gd"): Router.current.refresh(); await frames(3)
			check(run.current_room=="last_rest" and run.phase=="map","services and branch seals reach last rest")
			view = Router.current.map_view
			view.recenter(); await frames(90)
			await snap("seed-%d-rear-court.png" % seed_value)
			await measure(view,seed_value,"local-rear-court")
			var safe: Rect2 = view.safe_area(); var distance: float = view._distance
			Router.current._toggle_inventory(); await frames(3)
			check(safe.is_equal_approx(view.safe_area()) and is_equal_approx(distance,view._distance),"inventory keeps generated camera stable")
			Router.current._set_inventory_open(false)
		await full_view(Router.current.map_view,seed_value)
		await measure(Router.current.map_view,seed_value,"whole-garden-stress")
	if OS.get_cmdline_user_args().has("--capture"):
		var report := FileAccess.open(OUTPUT.path_join("mobile-renderer.json" if OS.get_cmdline_user_args().has("--mobile-map") else "desktop-renderer.json"),FileAccess.WRITE)
		report.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"android_device_tested":false,"measurements":measurements,"failures":failures},"  "))
	print("[RandomGardenRuntime] failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func map_ready() -> void:
	for i in 3000:
		await get_tree().process_frame
		if Router.current!=null and Router.current.map_view.walker!=null and not Router.current.map_view._building: return
	check(false,"staged map assembly completed")


func test_touch(view: Control) -> void:
	var before: Vector2i = run.position
	var down := InputEventScreenTouch.new(); down.index = 0; down.pressed = true; down.position = Vector2(600,340)
	view._gui_input(down)
	var drag := InputEventScreenDrag.new(); drag.index = 0; drag.position = Vector2(650,370); drag.relative = Vector2(50,30)
	view._gui_input(drag)
	var up := InputEventScreenTouch.new(); up.index = 0; up.position = drag.position; up.pressed = false
	view._gui_input(up)
	check(run.position==before and not view._moving and not view._follow,"touch drag pans without moving the walker")
	var zoom: float = view._zoom
	for i in 2:
		var finger := InputEventScreenTouch.new(); finger.index = i; finger.pressed = true; finger.position = Vector2(500+i*200,340)
		view._gui_input(finger)
	var pinch := InputEventScreenDrag.new(); pinch.index = 1; pinch.position = Vector2(800,340); pinch.relative = Vector2(100,0); view._gui_input(pinch)
	for i in 2:
		var release := InputEventScreenTouch.new(); release.index = i; release.pressed = false; release.position = Vector2(500+i*300,340); view._gui_input(release)
	check(view._zoom<zoom and run.position==before and not view._moving,"two-finger pinch zooms without triggering a walk")
	view._zoom = zoom
	view.recenter(); await frames(90)
	var look: Vector3 = view._look
	var safe: Rect2 = view.safe_area(); var distance: float = view._distance
	Router.current._toggle_inventory(); await frames(4)
	check(look.distance_to(view._look)<.02 and safe.is_equal_approx(view.safe_area()) and is_equal_approx(distance,view._distance),"panel does not reframe camera")
	Router.current._set_inventory_open(false)


func measure(view: Control, seed_value: int, scenario: String) -> void:
	# The full-reveal view deliberately stresses the dense garden; this is a
	# desktop renderer measurement, not a claim about Android hardware.
	RenderingServer.viewport_set_measure_render_time(view.viewport.get_viewport_rid(),true)
	view.profile["stages"] = view.authored_root.timings.duplicate()
	var library = preload("res://src/map/garden_mesh_library.gd")
	view.profile["resource_load_ms"] = library.load_ms; view.profile["fallback_bake_ms"] = library.bake_ms; view.profile["fallback_bakes"] = library.misses
	var samples: Array = []; var last := Time.get_ticks_usec()
	for i in 120:
		await get_tree().process_frame
		var now := Time.get_ticks_usec(); samples.append((now-last)/1000.0); last = now
	samples.sort()
	measurements.append({"seed":seed_value,"scenario":scenario,"viewport_size":[view.viewport.size.x,view.viewport.size.y],"generation_ms":run.generation_ms,"profile":view.profile.duplicate(true),"frame_median_ms":samples[60],"frame_p95_ms":samples[114],"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(view.viewport.get_viewport_rid()),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(view.viewport.get_viewport_rid()),"draw_calls":RenderingServer.viewport_get_render_info(view.viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"wall_draw_groups":view.authored_root.scenery_batch.wall_groups,"batch_groups":view.authored_root.scenery_batch.groups.size(),"batch_instances":view.authored_root.scenery_batch.instance_total})
	print("[GardenMeasure] ",measurements[-1])


func settle() -> void:
	match run.phase:
		"encounter": run.begin_live_battle(); run.finish_live_battle(true); run.apply({"type":"skip"})
		"reward":
			if Router.current_path.ends_with("reward_screen.gd"): Router.current._on_skip()
			else: run.apply({"type":"skip"})
		"rest": run.apply({"type":"rest","kind":"heal"})
		"shop":
			GameState.gold = maxi(GameState.gold,30)
			run.apply(run.legal_actions()[0]); run.apply({"type":"shop_leave"})
		"event": run.apply(run.legal_actions()[-1])


func full_view(view: Control, seed_value: int) -> void:
	# Drain the service drawer's deferred layout before setting inspection framing.
	await frames(12)
	view.set_safe_area(Rect2(Vector2(16,16),view.size-Vector2(32,84)))
	var center: Vector2 = run.layout.bounds.get_center()
	view._follow = false; view._look = Vector3(center.x,0,center.y); view._target = view._look
	var back: Vector3 = view._camera_back(); var right := Vector3(back.z,0,-back.x).normalized(); var up := back.cross(right)
	var tan_v := tan(deg_to_rad(view.camera.fov*.5)); var tan_h: float = tan_v*view.size.x/view.size.y
	var distance := 10.0
	for x in [run.layout.bounds.position.x,run.layout.bounds.end.x]:
		for z in [run.layout.bounds.position.y,run.layout.bounds.end.y]:
			for y in [-.75,4.5]:
				var delta: Vector3 = Vector3(x,y,z)-view._look
				distance = maxf(distance,delta.dot(back)+absf(delta.dot(right))/(tan_h*.9))
				distance = maxf(distance,delta.dot(back)+absf(delta.dot(up))/(tan_v*view.safe_area().size.y/view.size.y*.9))
	view._distance = distance; view.camera.far = 250; view._update_camera()
	view.authored_root.reveal_all = true; view._overlay.visible = false
	view.authored_root.refresh(run,run.layout.point(run.position))
	var bitmap := Image.create(2,2,false,Image.FORMAT_RGBA8); bitmap.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(bitmap)
	view.ground.set_shader_parameter("fog_mask",texture); view.water_paint.set_shader_parameter("fog_mask",texture)
	view.authored_root.update_fog(texture,run.layout.bounds); Router.current.drawer.visible = false
	await frames(6)
	view._distance = distance; view._look = Vector3(center.x,0,center.y); view._target = view._look; view._update_camera()
	await snap("seed-%d-inspection.png" % seed_value)


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func snap(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(("mobile-" if OS.get_cmdline_user_args().has("--mobile-map") else "")+filename))
