extends Control
const SURVEY = preload("res://src/tools/garden_asset_bounds.gd")
var passed := 0
var failed := 0
var output := ""


func _ready() -> void:
	output = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-17-garden-v2")
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().create_timer(180).timeout.connect(func(): push_error("庭院随机地图捕获超时"); get_tree().quit(1))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(message)


func _frames(count := 10) -> void:
	for i in count: await get_tree().process_frame


func _shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(output.path_join(filename))==OK,filename)


func _geometry(view: ExpeditionMapView, ex: Expedition) -> void:
	var entries: Array[Dictionary] = []
	var envelopes_match := true
	for record in view._garden_scenery.records:
		if not record.root.name.begins_with("Generated_") or record.root.name=="Generated_grave_bed": continue
		var measure := SURVEY.measure(record.root)
		measure["label"] = str(record.root.name)
		entries.append(measure)
		var planned: Dictionary = ex.m.layout.structures.filter(func(e): return "Generated_"+str(e.asset)==str(record.root.name))[0]
		envelopes_match = envelopes_match and planned.clearance.grow(.005).encloses(SURVEY.rect(measure.visual))
	for k in ex.m.node:
		if ex.m.node[k].t not in ["起","休","市","谜","巢"]: continue
		var measure := SURVEY.measure(view._cell_nodes[k])
		measure["label"] = str(ex.m.node[k].t)+"/"+str(k)
		entries.append(measure)
		var planned: Dictionary = ex.m.layout.occupancy.filter(func(e): return e.get("entry",-1)==k)[0]
		envelopes_match = envelopes_match and planned.clearance.grow(.005).encloses(SURVEY.rect(measure.visual))
	_check(envelopes_match,"生成占地覆盖真实模型，改模型不会悄悄越出避让范围")
	var conflict := false
	for i in entries.size():
		for j in range(i+1,entries.size()):
			if SURVEY.conflicts(entries[i],entries[j]):
				print("[NativeConflict] ",entries[i].label," / ",entries[j].label)
				conflict = true
	_check(not conflict,"原生建筑分件包围盒无穿插："+ex.m.layout.kind)
	var walls: Array = view._garden_scenery.records.filter(func(r): return r.root.get_meta("courtyard_wall",false))
	_check(walls.size()>0,"连接内墙已实例化并按段接入迷雾")
	var rest: int = ex.m.node.keys().filter(func(k): return ex.m.node[k].t=="休")[0]
	var root: Node3D = view._cell_nodes[rest]
	var hit: Vector2 = view.camera.unproject_position(root.position+root.get_meta("pick_offset")+Vector3.UP*.50)
	_check(view.pick_cell(hit)==rest,"点亭身映射到入口，偏移后的模型命中一致")
	var hidden: Node3D = walls[0].root
	ex.explored.clear()
	ex.visible.clear()
	view._garden_scenery.sync(ex)
	_check(not hidden.visible,"未探索内墙隐藏")
	for k in MapGen.N: ex.explored[k] = true; ex.visible[k] = true
	view._garden_scenery.sync(ex)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920,1080)
	var ex := Expedition.start(1234)
	var screen: Control = load("res://src/screens/expedition_map_screen.gd").new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(12)
	var view: ExpeditionMapView = screen._map_view
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE # Captures should not retain a pointer tooltip.
	view.set_hover(-1)
	var shapes := {}
	for requested in [9,11,5]:
		ex.m = MapGen.generate(requested,"墨池")
		_check(ex.m.get("generation_version","")=="garden_v2","真实远征使用新布局 "+str(requested))
		ex.pos = ex.m.start
		ex.boss = ex.m.lair
		ex.taken.clear()
		ex.used.clear()
		ex.t = 0
		ex.stir = null
		ex.rise = null
		ex.acc = 0
		ex.explored.clear()
		ex.visible.clear()
		for k in MapGen.N: ex.explored[k] = true; ex.visible[k] = true
		var random_before := [ex.rng.state,GameState.rng.state]
		screen.refresh()
		view.show_overview()
		view._look = view._look_target
		view._distance = view._distance_target
		view._apply_camera()
		view._style.refresh_outlines()
		await _frames(12)
		_check(random_before==[ex.rng.state,GameState.rng.state],"生成素材与镜头不消耗玩法随机数")
		print("[CourtyardRuntime] requested=",requested," seed=",ex.m.seed," ",ex.m.layout.kind," tries=",ex.m.tries)
		print("[FacilityPositions] ",ex.m.node.keys().filter(func(k): return ex.m.node[k].t in ["休","市","谜","巢"]).map(func(k): return [ex.m.node[k].t,k,ex.m.node[k].get("body_cell",-1)]))
		shapes[ex.m.layout.kind] = true
		_geometry(view,ex)
		await _frames()
		await _shot("01-overview-seed-%d-1920.png" % requested)
		var aligned := true
		for k in MapGen.N: aligned = aligned and view.cell_at(view.cell_center(k))==k
		_check(aligned,"缩放总览中的96格命中保持一致")
		if requested==11:
			view.following = false
			view.overview = false
			view._look_target = Vector3(7.8,0,3.5)
			view._look = view._look_target
			view._distance_target = 8.8
			view._distance = 8.8
			view._apply_camera()
			await _frames()
			await _shot("02-pond-gallery-pavilion-1920.png")
			view._look_target = Vector3(3.2,0,5.5)
			view._look = view._look_target
			view._apply_camera()
			await _frames()
			await _shot("03-attached-gate-walls-1920.png")
			get_window().size = Vector2i(1280,720)
			view.show_overview()
			view._look = view._look_target
			view._distance = view._distance_target
			view._apply_camera()
			await _frames(12)
			await _shot("04-overview-1280.png")
			get_window().size = Vector2i(1920,1080)
	_check(shapes.size()==3,"三类池塘均在实际随机地图中出现")
	print("[CourtyardRuntime] PASS=%d FAIL=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
