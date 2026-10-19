extends Node
const SAMPLE = preload("res://src/tools/garden_blockout_sample.tscn")
const OUTPUT := "res://docs/art-concepts/2026-10-18-garden-compact"
var failures: Array = []
var checks := 0
var reports: Array = []
var view: Control


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void: run_checks.call_deferred()


func run_checks() -> void:
	get_window().size = Vector2i(1560,720) if OS.get_cmdline_user_args().has("--mobile-map") else Vector2i(1280,720)
	view = SAMPLE.instantiate(); add_child(view); await frames(3); await ready_chunks()
	var identity: int = view.get_instance_id()
	for seed_value in [17,29,67]:
		view.select_seed(seed_value); await ready_chunks(); await frames(3)
		for factor in [.75,1.0,1.3]:
			view.zoom = factor; view._camera()
			for delta in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1)]:
				var c: Vector2i = view.position_cell+delta
				var ray: Vector3 = view.ground_at(view.project(Vector3(c.x,0,c.y)))
				check(Vector2(ray.x,ray.z).distance_to(Vector2(c))<.005,"projection and picking agree after zoom")
		view.zoom = 1; view._camera()
		view.set_overview(true); await frames(2)
		check(view._atlas_hits.size()==55,"all stop footprints can be picked in overview")
		check(view.status.text.contains("全园 55 个候选节点") and not view.status.text.contains("允许回头"),"overview explains total alternatives and forward travel")
		view.focus_compound(); await frames(2)
		check(view.status.text.contains("本庭院 %d 节点 / 全园 55 节点" % view._atlas_hits.size()),"focused compound count is distinct from whole garden")
		view.set_overview(true); await frames(2)
		check(view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"overview stops 3D viewport rendering")
		await snap("runtime-%d-plan.png" % seed_value)
		view.set_overview(false)
		var first: String = view.travel.next_nodes[0]
		var path: Array = view.travel.path(view.position_cell,view.plan.nodes[first].at)
		var target: Vector2i = path[mini(9,path.size()-1)]
		check(view.walk_to(target),"actual click-walk can leave rotated start gate")
		var movement_deadline := Time.get_ticks_msec()+6000
		while Time.get_ticks_msec()<movement_deadline:
			await get_tree().process_frame
			if not view.moving: break
		check(view.position_cell==target and view.walker.position.is_equal_approx(Vector3(target.x,0,target.y)),"walk stops exactly at a tile center")
		check(not view.walk_to(view.plan.nodes.boss.at),"click cannot skip the intermediate decisions")
		if view.travel.departed or view.travel.current_node!="start":
			check(not view.walk_to(view.plan.nodes.start.at),"actual sample refuses a return to the start room")
		await ready_chunks(); await snap("runtime-%d-walk.png" % seed_value)
		if view.position_cell!=view.plan.nodes[first].at:
			check(view.walk_to(view.plan.nodes[first].at),"forward walk continues through independent entry gate")
			movement_deadline = Time.get_ticks_msec()+12000
			while Time.get_ticks_msec()<movement_deadline:
				await get_tree().process_frame
				if not view.moving: break
		check(view.travel.current_node==first and view.position_cell==view.plan.nodes[first].at,"arrival advances the encounter exactly once")
		check(not view.walk_to(view.plan.nodes.start.at),"arrival keeps the previous node closed")
		check(view.door_visual!=null and view.door_visual.get_child_count()==1,"dynamic door mesh follows the same progression state")
		view.notice = ""; view.focus_compound(); await frames(2)
		await snap("runtime-%d-forward.png" % seed_value)
		view.set_overview(false)
		# Stream across every stop without simulating encounters. This exercises
		# real chunk allocation/eviction, while the full floor routes are tested
		# independently across 768 generated plans.
		for node: Dictionary in view.plan.nodes.values():
			view._stream(node.at); await ready_chunks()
			check(view.roots.size()<=view.CACHE_LIMIT,"regional mesh cache stays bounded")
			check(view.wanted.size()<=25,"only local 5x5 chunk window is active")
		var close: Dictionary = view.plan.nodes.values()[27]
		view.position_cell = close.at; view.walker.position = Vector3(close.at.x,0,close.at.y)
		view.look = view.walker.position; view.target = view.look; view._stream(close.at); view._camera(); await ready_chunks()
		view.show_roofs = true; view._update_roofs(); await frames(3)
		for root in view.roots.values():
			for roof in root.get_meta("roof_items",[]):
				if roof.rect.grow(.6).has_point(Vector2(close.at)): check(not roof.node.visible,"roof proxy leaves walker readable inside footprint")
		await snap("runtime-%d-court.png" % seed_value)
		view.show_roofs = false; view._update_roofs()
		var look: Vector3 = view.look
		var before: Vector2i = view.position_cell
		var touch := InputEventScreenTouch.new(); touch.index = 0; touch.pressed = true; touch.position = Vector2(500,350); view._gui_input(touch)
		var drag := InputEventScreenDrag.new(); drag.index = 0; drag.position = Vector2(550,375); drag.relative = Vector2(50,25); view._gui_input(drag)
		touch.pressed = false; touch.position = drag.position; view._gui_input(touch)
		await frames(15)
		check(not view.follow and not view.moving and view.position_cell==before and not view.look.is_equal_approx(look),"touch drag changes camera without walking")
		view.recenter(); await frames(40)
		RenderingServer.viewport_set_measure_render_time(view.viewport.get_viewport_rid(),true)
		var timings: Array = []; var last := Time.get_ticks_usec()
		for i in 60:
			await get_tree().process_frame
			var now := Time.get_ticks_usec(); timings.append((now-last)/1000.0); last = now
		timings.sort()
		var report: Dictionary = view.metrics(); report["frame_p95_ms"] = timings[57]
		report["draw_calls"] = RenderingServer.viewport_get_render_info(view.viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		report["memory_bytes"] = Performance.get_monitor(Performance.MEMORY_STATIC)
		report["render_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(view.viewport.get_viewport_rid())
		report["render_gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(view.viewport.get_viewport_rid())
		reports.append(report)
		check(view.get_instance_id()==identity,"switching seeds reuses sample screen")
		check(view.max_cached<=49 and view.roots.size()<view.plan.chunks.size(),"traversing whole garden never keeps the full garden mesh")
		if view.mobile_quality: check(view.viewport.size.y<=720,"mobile map resolution is capped independently of UI")
		print("[BlockoutRuntimeSeed] ",report)
	# Ensure actual window resizing keeps camera projection and integer picking.
	for resolution in [Vector2i(1920,1080),Vector2i(844,390)]:
		get_window().size = resolution; await frames(5)
		var point: Vector2i = view.position_cell
		var hit: Vector3 = view.ground_at(view.project(Vector3(point.x,0,point.y)))
		check(Vector2(hit.x,hit.z).distance_to(Vector2(point))<.005,"window resize keeps picking aligned")
		check(Rect2(Vector2.ZERO,view.size).encloses(Rect2(view.controls.position,view.controls.size*view.controls.scale)),"controls stay inside landscape viewport")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("mobile-blockout.json" if view.mobile_quality else "desktop-blockout.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"android_device_tested":false,"geometry_only":true,"checks":checks,"failures":failures,"seeds":reports},"  "))
	print("[GardenBlockoutRuntime] checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func ready_chunks() -> void:
	for i in 100:
		await get_tree().process_frame
		if view.ready_chunks(): return
	check(false,"chunk queue completes")


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func snap(filename: String) -> void:
	if not OS.get_cmdline_user_args().has("--record-blockout"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(("mobile-" if view.mobile_quality else "")+filename))
