extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const ATLAS = preload("res://src/map/garden_route_overview.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-19-garden-passages"
var failures: Array = []
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void: run_checks.call_deferred()


func run_checks() -> void:
	Engine.max_fps = 120; Settings.reduced_motion = true
	get_window().size = Vector2i(1280,720)
	var host := Control.new(); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(host); Router.host = host
	var reports: Array = []
	for seed_value in [29,67]:
		var run = RUN.new(); run.reset({"seed":seed_value,"layout":"compact_garden"}); run.autosave = false
		Router.goto(RUN.MAP_SCREEN)
		var deadline := Time.get_ticks_msec()+45000
		while Time.get_ticks_msec()<deadline:
			await get_tree().process_frame
			if Router.current.map_view.walker!=null and not Router.current.map_view._building: break
		var view: Control = Router.current.map_view
		check(not view._building and view.authored_root!=null,"production screen finishes regional assembly")
		if view._building or view.authored_root==null: get_tree().quit(1); return
		await frames(16)
		if OS.get_cmdline_user_args().has("--passage-only"):
			var feature: Dictionary = view.authored_root.passage_features.filter(func(f):return f.kind in ["covered","gallery"])[0]
			var middle: Vector2 = feature.start+feature.direction*float(feature.length)*.5
			run.position = feature.cells[feature.cells.size()/2]; view.refresh_run()
			view._follow = false; view._look = Vector3(middle.x,.5,middle.y); view._target = view._look
			await frames(80); await snap("seed-29-covered-passage.png")
			get_tree().quit(0); return
		check(not view._overview and not Router.current.drawer.visible,"new map opens the walkable garden with optional route planning")
		check(not view.authored_root.passage_features.is_empty(),"actual compact paths reuse approved bridge and gallery models")
		check(not view.authored_root.find_children("Passage_*","Node3D",true,false).is_empty(),"nearby bridge architecture is instantiated in the live map")
		check(view.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and is_equal_approx(view.camera.fov,20),"compact close view preserves shallow perspective and parallax")
		check(view.fog.get_width()==1 and view.fog.get_image().get_pixel(0,0)==Color.WHITE,"route map has no exploration fog")
		check(view.authored_root.terrain_root.get_child_count()==run.layout.compact.chunks.size(),"all terrain stays present independently of streamed props")
		var detail_counts: Dictionary = view.authored_root.get_meta("ground_detail_counts",{})
		check(int(detail_counts.get("grass",0))>0 and int(detail_counts.get("moss",0))>0,"planted plots receive deterministic grass and moss detail")
		check(int(detail_counts.get("corner_stones",0))>0,"paths and garden plots receive corner stone detail")
		var haunted_counts: Dictionary = view.authored_root.get_meta("haunted_prop_counts",{})
		check(int(haunted_counts.get("tombstone",0))>0 and int(haunted_counts.get("ghost_fire",0))>0,"garden route uses both tombstone and ghost-fire assets")
		var start_root: Node3D = view.authored_root._node_roots.get("start")
		check(start_root!=null and not start_root.find_children("*","Node3D",true,false).filter(func(n):return n.get_meta("garden_tombstone",false) or n.get_script()==preload("res://src/map/expedition_stylized_fire.gd")).is_empty(),"entrance court visibly instantiates a tombstone or ghost-fire scenic node")
		var transform: Transform2D = ATLAS.transform_for(run,ATLAS.map_area(view.overview_area()))
		for id: String in run.graph.rooms:
			check(ATLAS.pick(run,transform*run.layout.rooms[id].stand,view.overview_area())==id,"full atlas picks actual footprint "+id)
		check(ATLAS.known_rooms(run).size()==55,"all node types can inform route planning")
		var first: String = run.next_rooms()[0]
		view.show_overview(); await frames(3)
		transform = ATLAS.transform_for(run,ATLAS.map_area(view.overview_area()))
		view._tap(transform*run.layout.rooms[first].stand); await frames(3)
		check(run.planned_route==[first] and not view._moving and run.current_room=="start","node click previews without committing or moving")
		var second: String = run.plan_choices()[0]
		view._tap(transform*run.layout.rooms[second].stand); await frames(3)
		check(run.planned_route==[first,second] and not view._moving,"future node click extends the preview")
		await snap("seed-%d-overview.png" % seed_value)
		view.recenter(); await frames(35); await snap("seed-%d-entry.png" % seed_value)
		var idle_samples: Array[float] = []
		for i in 40:
			var began := Time.get_ticks_usec(); await get_tree().process_frame
			idle_samples.append((Time.get_ticks_usec()-began)/1000.0)
		var hero_pixels: float = view.screen_point(view.walker.position).distance_to(view.screen_point(view.walker.position+Vector3.UP*1.37))
		check(hero_pixels>65,"walker stays legible at 720p")
		var passage: Dictionary = run.layout.compact.corridors.filter(func(edge):return edge.from=="start")[0]
		var outside: Vector2i = passage.floor.filter(func(cell):return str(run.layout.compact.cells[cell]).is_empty())[0]
		Router.current._select_exit(first); await frames(3)
		check(not view._moving and not view._overview and view.selected_exit==first and not run.travel.departed,"exit sign previews the physical branch without forcing the atlas or committing")
		check(Router.current.drawer.visible and view._preview_path.size()>1,"exit preview shows real walking path and continuation information")
		await snap("seed-%d-exit.png" % seed_value)
		Router.current.map_view.preview_exit(""); Router.current.refresh(); await frames(2)
		view._tap(view.screen_point(Vector3(outside.x,0,outside.y))); await frames(2)
		check(view._moving and not view._overview,"clicking corridor tiles walks through the actual garden without a node-selection screen")
		deadline = Time.get_ticks_msec()+10000
		while view._moving and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		check(run.position==outside and run.travel.departed,"physical doorway crossing closes the return direction")
		view.recenter(); await frames(2)
		if OS.get_cmdline_user_args().has("--still"): get_tree().quit(0 if failures.is_empty() else 1); return
		Router.current._walk_exit(first)
		check(view._moving and not view._overview,"physical exit confirmation begins four-way tile movement")
		deadline = Time.get_ticks_msec()+20000
		var walking_samples: Array[float] = []
		while Time.get_ticks_msec()<deadline:
			var began := Time.get_ticks_usec()
			await get_tree().process_frame
			walking_samples.append((Time.get_ticks_usec()-began)/1000.0)
			if not view._moving: break
		check(run.current_room==first and run.phase=="encounter","crossing threshold starts live encounter")
		check(run.planned_route==[second],"arrival consumes just one planned encounter")
		check(not view.walk_to_room("start"),"live UI cannot walk back to start")
		await snap("seed-%d-encounter.png" % seed_value)
		var identity: int = view.get_instance_id(); var look: Vector3 = view._look; var zoom: float = view._distance
		Router.current._start_battle(); await frames(8)
		check(Router.current_path.ends_with("battle_screen.gd") and not view._active,"existing battle screen receives compact encounter and suspends map")
		if not Router.current_path.ends_with("battle_screen.gd"): get_tree().quit(1); return
		var battle = Router.current.battle
		for enemy in battle.enemies: battle.deal_damage(enemy,99999,true)
		Router.current._check_battle_over(); await frames(45)
		check(Router.current_path.ends_with("reward_screen.gd"),"battle victory opens existing reward screen")
		if not Router.current_path.ends_with("reward_screen.gd"): get_tree().quit(1); return
		await snap("seed-%d-reward.png" % seed_value)
		var chosen: String = Router.current._options[0].glyph
		var chosen_count := int(GameState.glyph_counts().get(chosen,0))
		Router.current._accept_pick(); await frames(20)
		check(Router.current_path==RUN.MAP_SCREEN and int(GameState.glyph_counts().get(chosen,0))==chosen_count+1,"claim adds chosen glyph to deck and restores map")
		view = Router.current.map_view
		check(view.get_instance_id()==identity and view.profile.build_count==1,"reward return reuses world without rebuilding")
		check(view._look.is_equal_approx(look) and is_equal_approx(view._distance,zoom),"reward return keeps camera unchanged")
		check(not view._overview and run.planned_route==[second],"reward returns directly to the courtyard and keeps the future route available")
		check(not run.enter_room("start").ok,"return remains closed after reward settlement")
		await snap("seed-%d-return.png" % seed_value)
		Router.current._toggle_inventory(); await frames(3)
		check(view._interaction_blocked and is_equal_approx(view._distance,zoom),"inventory overlays world without reframing or click-through")
		Router.current._set_inventory_open(false)
		view.recenter(); await frames(4)
		var remote: Vector2 = run.layout.rooms.boss.stand
		view._follow = false; view._look = Vector3(remote.x,0,remote.y); view._target = view._look
		await frames(35)
		check(view.authored_root._center==preload("res://src/expedition/garden_blockout_plan.gd").chunk_at(remote),"dragged camera streams its own region independently of player")
		view.recenter(); await frames(40)
		check(view.authored_root._center==preload("res://src/expedition/garden_blockout_plan.gd").chunk_at(run.layout.point(run.position)),"recenter restores streaming around walker")
		if seed_value==29:
			var corner := corridor_corner(run.layout.compact)
			view._follow = false; view._look = Vector3(corner.x,.45,corner.y); view._target = view._look
			view._zoom = 1.1; view._update_framing(); await frames(50)
			await snap("seed-29-corner.png"); view.recenter(); await frames(35)
			var feature: Dictionary = view.authored_root.passage_features.filter(func(f):return f.kind in ["covered","gallery"])[0]
			var middle: Vector2 = feature.start+feature.direction*float(feature.length)*.5
			var saved_position: Vector2i = run.position
			# A camera fixture for the actual assembled bridge, after the travel
			# and return-flow assertions above have completed normally.
			run.position = feature.cells[feature.cells.size()/2]
			view.walker.position = view.world_point(run.position)
			view._follow = false; view._look = Vector3(middle.x,.5,middle.y); view._target = view._look
			view.refresh_run(); await frames(70); await snap("seed-29-covered-passage.png")
			run.position = saved_position; view.refresh_run(); view.recenter(); await frames(35)
		reports.append({"seed":seed_value,"profile":view.profile.duplicate(true),"idle_frame_ms":frame_summary(idle_samples),"walking_frame_ms":frame_summary(walking_samples),"memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"draw_calls":RenderingServer.viewport_get_render_info(view.viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"loaded_regions":view.authored_root.chunks.size(),"cache_limit":view.authored_root.CACHE_LIMIT})
		check(view.authored_root.chunks.size()<=49,"regional mesh retention is bounded")
		if seed_value==29:
			# Three-act node progression is checked separately. Here skip to the
			# act boundary to exercise a second world on the same cached screen.
			run.phase = "act_end"; run.apply({"type":"next_act"}); Router.current.refresh()
			deadline = Time.get_ticks_msec()+45000
			while Time.get_ticks_msec()<deadline:
				await get_tree().process_frame
				if not view._building and view._loaded_act==2: break
			check(view._loaded_act==2 and view.profile.build_count==2,"act change builds its new layout once")
			check(run.enter_room(run.next_rooms()[0]).ok,"second-act first encounter is reachable")
			Router.current.refresh(); await frames(6)
			Router.current._start_battle(); await frames(8)
			check(Router.courtyard_cache_size()==1,"second-act battle retains the rebuilt map")
			battle = Router.current.battle
			for enemy in battle.enemies: battle.deal_damage(enemy,99999,true)
			Router.current._check_battle_over(); await frames(45)
			if Router.current_path.ends_with("reward_screen.gd"): Router.current._on_skip()
			await frames(20)
			check(Router.current_path==RUN.MAP_SCREEN and Router.current.map_view.get_instance_id()==identity and Router.current.map_view.profile.build_count==2,"second-act reward also reuses the existing world")
	for resolution in [Vector2i(1920,1080),Vector2i(844,390)]:
		get_window().size = resolution; await frames(5)
		var view: Control = Router.current.map_view; var point: Vector3 = view.world_point(view.run.position)
		check(view._ground_at(view.screen_point(point)).distance_to(point)<.01,"resizing preserves grid picking")
		view._zoom = 1.35; view._update_framing(); view._update_camera()
		check(view._ground_at(view.screen_point(point)).distance_to(point)<.01,"zoom preserves perspective grid picking")
		view._set_overview(true); await frames(4)
		check(not view.overview_area().intersects(Router.current.drawer.get_rect()),"planner uses space beside its controls")
		await snap("planning-%dx%d.png" % [resolution.x,resolution.y])
	var report := {"checks":checks,"failures":failures,"seeds":reports,"renderer":RenderingServer.get_current_rendering_method(),"android_device_tested":false}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("runtime-checks.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  "))
	print("[CompactRuntime] ",report); get_tree().quit(0 if failures.is_empty() else 1)


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func frame_summary(samples: Array[float]) -> Dictionary:
	if samples.is_empty(): return {}
	samples.sort()
	return {"median":samples[samples.size()/2],"p95":samples[mini(samples.size()-1,floori(samples.size()*.95))],"max":samples[-1]}


func corridor_corner(plan: RefCounted) -> Vector2:
	for edge: Dictionary in plan.corridors:
		var route: Array = edge.floor
		for i in range(1,route.size()-1):
			if not str(plan.cells[route[i]]).is_empty(): continue
			if route[i]-route[i-1]!=route[i+1]-route[i]: return Vector2(route[i])
	return Vector2(plan.nodes.start.at)


func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(name))
