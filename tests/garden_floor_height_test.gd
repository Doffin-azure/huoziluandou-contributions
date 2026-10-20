extends Control
## Native geometry, surface picking and walking regression for raised floors.
const ASSETS = preload("res://src/expedition/garden_asset_layout.gd")
const SURVEY = preload("res://src/tools/garden_asset_bounds.gd")
var passed := 0
var failed := 0
var output := "res://docs/art-concepts/2026-10-17-floor-joins"


func _ready() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	get_tree().create_timer(180).timeout.connect(func(): push_error("地台接地检查超时"); get_tree().quit(1))
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)


func _frames(count := 10) -> void:
	for i in count: await get_tree().process_frame


func _shot(filename: String) -> void:
	await _frames(8)
	RenderingServer.force_draw(false)
	_check(get_viewport().get_texture().get_image().save_png(output.path_join(filename))==OK,"实机截图："+filename)


## Probe the constructed triangles independently of the placement-height helper.
func _mesh_floor_height(root: Node3D, point: Vector3) -> float:
	var result := -INF
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("flat_outline_only") or not mesh.is_visible_in_tree(): continue
		for si in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(si)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices := PackedInt32Array() if arrays[Mesh.ARRAY_INDEX]==null else arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			var count := vertices.size() if indices.is_empty() else indices.size()
			for i in range(0,count,3):
				var a: Vector3 = mesh.global_transform*vertices[i if indices.is_empty() else indices[i]]
				var b: Vector3 = mesh.global_transform*vertices[i+1 if indices.is_empty() else indices[i+1]]
				var c: Vector3 = mesh.global_transform*vertices[i+2 if indices.is_empty() else indices[i+2]]
				var u := Vector2(b.x-a.x,b.z-a.z)
				var v := Vector2(c.x-a.x,c.z-a.z)
				var w := Vector2(point.x-a.x,point.z-a.z)
				var determinant := u.cross(v)
				if absf(determinant)<.0000001: continue
				var wb := w.cross(v)/determinant
				var wc := u.cross(w)/determinant
				if wb<-.00001 or wc<-.00001 or wb+wc>1.00001: continue
				var y := a.y+(b.y-a.y)*wb+(c.y-a.y)*wc
				# Ignore roofs and fixtures; inspect only the walking-surface band.
				if y<=ASSETS.DECK_Y+.003: result = maxf(result,y)
	return result


func _run() -> void:
	var ex := Expedition.start(9)
	ex.themes = ["墨池","熔铸坊","雷池"]
	ex.load_act(1)
	for k in MapGen.N: ex.explored[k] = true; ex.visible[k] = true
	var screen: Control = load("res://src/screens/expedition_map_screen.gd").new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(16)
	var view: ExpeditionMapView = screen._map_view
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_hover(-1)
	var random_before := [ex.rng.state,GameState.rng.state]
	print("[FloorJoins] seed=",ex.m.seed," kind=",ex.m.layout.kind)
	var entries: Array[Dictionary] = []
	for record in view._garden_scenery.records:
		if not str(record.root.name).begins_with("Generated_"): continue
		var root: Node3D = record.root
		var asset := str(root.name).trim_prefix("Generated_")
		# Tree crowns in planted beds deliberately extend beyond their solid base.
		if asset=="grave_bed": continue
		var entry: Dictionary = ex.m.layout.structures.filter(func(e): return e.asset==asset)[0]
		var measured := SURVEY.measure(root)
		entries.append(measured)
		_check(entry.clearance.grow(.005).encloses(SURVEY.rect(measured.visual)),"实际模型及石坡在登记占地内："+asset)
		if asset not in ["bridge","covered_walk"]: continue
		var surface_patches: Array[Dictionary] = []
		for patch in ASSETS.floor_patches(asset):
			patch["origin"] = entry.at; patch["basis"] = Basis(Vector3.UP,entry.turn)
			surface_patches.append(patch)
		for patch in surface_patches:
			var rect: Rect2 = patch.rect
			var slope: Vector2 = patch.gradient
			for t in [.1,.5,.9]:
				var local := rect.get_center()
				if slope.x!=0: local.x = lerpf(rect.position.x,rect.end.x,t)
				elif slope.y!=0: local.y = lerpf(rect.position.y,rect.end.y,t)
				var world: Vector3 = entry.at+patch.basis*Vector3(local.x,0,local.y)
				var expected := ASSETS.surface_height(surface_patches,world)
				_check(absf(_mesh_floor_height(root,world)-expected)<.0002,"真实网格与落脚高度相符："+asset+"/"+str(local))
				world.y = expected
				var screen_point := view.camera.unproject_position(world)*view.size/Vector2(view.viewport.size)
				_check(view.ground_at(screen_point).distance_to(world)<.0002,"坡面射线命中真实表面："+asset+"/"+str(t))
			var edge := rect.get_center()
			if slope.x!=0: edge.x = rect.end.x if slope.x<0 else rect.position.x
			elif slope.y!=0: edge.y = rect.end.y
			if slope!=Vector2.ZERO:
				var world: Vector3 = entry.at+patch.basis*Vector3(edge.x,0,edge.y)
				_check(absf(_mesh_floor_height(root,world))<.0002,"石坡外沿接回普通地面："+asset)
		for k in entry.walk:
			_check(is_equal_approx(view.surface_position(k).y,ASSETS.DECK_Y),"廊桥格心高于普通地面："+str(k))
	var conflicts := false
	for i in entries.size():
		for j in range(i+1,entries.size()): conflicts = conflicts or SURVEY.conflicts(entries[i],entries[j])
	_check(not conflicts,"扩大石坡后建筑之间没有实体穿插")
	# Reproduce the previous palette capture exactly, so both images are comparable.
	view.following = false; view.overview = false
	view._look_target = Vector3(7.4,0,3.8); view._look = view._look_target
	view._distance_target = 9.6; view._distance = 9.6
	view._apply_camera(); view._style.refresh_outlines()
	await _shot("01-pond-detail-1920.png")
	for dimensions in [Vector2i(1920,1080),Vector2i(1280,720)]:
		get_window().size = dimensions
		await _frames(8)
		view.show_overview(); view._look = view._look_target; view._distance = view._distance_target
		view._apply_camera()
		var aligned := true
		for k in MapGen.N: aligned = aligned and view.cell_at(view.cell_center(k))==k
		_check(aligned,"含廊桥的96格总览拾取："+str(dimensions))
		view.zoom_by(.75,view.cell_center(ex.pos)); view.pan_by(Vector2(75,22))
		view._look = view._look_target; view._distance = view._distance_target; view._apply_camera()
		aligned = true
		for k in MapGen.N:
			var p := view.cell_center(k)
			if Rect2(Vector2.ZERO,view.size).has_point(p): aligned = aligned and view.cell_at(p)==k
		_check(aligned,"缩放拖看后表面拾取："+str(dimensions))
	var bridge: Dictionary = ex.m.layout.structures.filter(func(e): return e.asset=="bridge")[0]
	var bridge_cell: int = bridge.walk[0]
	var from: Vector3 = bridge.at+Basis(Vector3.UP,bridge.turn)*Vector3(1.5,0,0)
	var to := view.surface_position(bridge_cell)
	var feet_correct := true
	var floor_roots: Array = view._garden_scenery.records.filter(func(r): return str(r.root.name) in ["Generated_bridge","Generated_covered_walk"])
	for i in 31:
		view._move_on_surface(i/30.0,view.player_actor,from,to)
		var actual := 0.0
		for floor_root in floor_roots: actual = maxf(actual,_mesh_floor_height(floor_root.root,view.player_actor.position))
		feet_correct = feet_correct and absf(actual-view.player_actor.position.y)<.0002
	_check(feet_correct,"跨越桥头时人物贴合真实石坡与桥面")
	# Exercise the real tween path and the gallery roof fade.
	ex.pos = bridge_cell; screen.refresh()
	await get_tree().create_timer(.3).timeout
	_check(view.player_actor.position.distance_to(view.surface_position(bridge_cell))<.0002,"实际移动动画最终站在桥面")
	get_window().size = Vector2i(1920,1080)
	view.following = false; view.overview = false
	view._look_target = Vector3(bridge.at.x,0,bridge.at.z-.35); view._look = view._look_target
	view._distance = 7.2; view._distance_target = 7.2
	view._apply_camera(); view._style.refresh_outlines()
	await _shot("02-bridge-feet-1920.png")
	var walk: Dictionary = ex.m.layout.structures.filter(func(e): return e.asset=="covered_walk")[0]
	ex.pos = walk.walk[0]; screen.refresh()
	await get_tree().create_timer(.3).timeout
	_check(view.player_actor.position.distance_to(view.surface_position(ex.pos))<.0002,"人物在游廊地板上，无陷地")
	view.following = false; view.overview = false
	view._look = walk.at+Vector3(0,0,.35); view._look_target = view._look
	view._distance = 7.2; view._distance_target = 7.2
	view._apply_camera(); view._style.refresh_outlines()
	await _shot("03-gallery-feet-1920.png")
	_check(random_before==[ex.rng.state,GameState.rng.state],"表面、相机与动画不消耗玩法随机数")
	_check(ASSETS.surface_patches({}).is_empty(),"旧地图维持原来的平面拾取")
	print("[FloorJoins] PASS=%d FAIL=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
