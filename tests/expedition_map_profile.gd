extends Control
## Native, reproducible map diagnosis. Timings describe this local run only.
var _out := ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-17-map-performance")
	if OS.get_cmdline_user_args().has("--after"): _out = _out.path_join("after-edge" if OS.get_cmdline_user_args().has("--edge-vision") else "after")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(180).timeout.connect(func(): get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 12) -> void:
	for i in count: await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name))


func _summary(samples: Array) -> Dictionary:
	samples.sort()
	return {"median_ms":snappedf(samples[samples.size()/2],.01),"p95_ms":snappedf(samples[mini(samples.size()-1,floori(samples.size()*.95))],.01),"max_ms":snappedf(samples.back(),.01)}


func _sample(view: ExpeditionMapView, phase: String, moving := false) -> void:
	var frame: Array = []
	var cpu: Array = []
	var gpu: Array = []
	await _frames(20)
	var last := Time.get_ticks_usec()
	for i in 120:
		if moving: view.pan_by(Vector2(sin(i*.05)*1.5,cos(i*.04)*.5))
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame.append((now-last)/1000.0)
		last = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(view.viewport.get_viewport_rid()))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(view.viewport.get_viewport_rid()))
	print("[MapProfile] ",phase," frame=",_summary(frame)," render_cpu=",_summary(cpu)," gpu=",_summary(gpu)," draws=",RenderingServer.viewport_get_render_info(view.viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var ex := Expedition.start(12)
	if OS.get_cmdline_user_args().has("--edge-vision"):
		for r in range(2,MapGen.H-2):
			var k := MapGen.kk(r,MapGen.W-2)
			if ex.m.ink[k]==0:
				ex.pos = k
				break
		ex.explored.clear()
		ex.update_vision()
	var screen: Control = load("res://src/screens/expedition_map_screen.gd").new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(20)
	var view: ExpeditionMapView = screen._map_view
	if OS.get_cmdline_user_args().has("--edge-vision"):
		view.show_overview()
		view._look = view._look_target
		view._distance = view._distance_target
		view._apply_camera()
		await _frames(20)
	RenderingServer.viewport_set_measure_render_time(view.viewport.get_viewport_rid(),true)
	print("[MapProfile] meshes=",view._map_root.find_children("*","MeshInstance3D",true,false).size()," styled=",view._style._items.size())
	var outline: Array = []
	var occlusion: Array = []
	for i in 12:
		var began := Time.get_ticks_usec()
		view._style.refresh_outlines()
		outline.append((Time.get_ticks_usec()-began)/1000.0)
		began = Time.get_ticks_usec()
		view._update_occlusion()
		occlusion.append((Time.get_ticks_usec()-began)/1000.0)
		await get_tree().process_frame
	print("[MapProfile] outline=",_summary(outline)," occlusion=",_summary(occlusion))
	await _shot("01-current-fog.png")
	await _sample(view,"current-idle")
	await _sample(view,"current-pan",true)
	view.show_overview()
	view._look = view._look_target
	view._distance = view._distance_target
	view._apply_camera()
	await _frames(30)
	await _shot("05-overview-physical-fog.png")
	for light in view._world.get_children():
		if light is DirectionalLight3D: light.light_volumetric_fog_energy = 0
	await _frames(30)
	await _shot("02-no-directional-scatter.png")
	for light in view._map_root.find_children("*","Light3D",true,false): light.light_volumetric_fog_energy = 0
	view.environment.volumetric_fog_ambient_inject = 0
	await _frames(30)
	await _shot("03-no-light-scatter.png")
	await _sample(view,"no-scatter-idle")
	view.environment.volumetric_fog_enabled = false
	await _frames(20)
	await _shot("04-no-volume.png")
	await _sample(view,"no-volume-idle")
	print("[MapProfile] complete")
	get_tree().quit()
