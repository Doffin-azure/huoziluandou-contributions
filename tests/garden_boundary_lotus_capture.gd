extends Control
const BOUNDARY = preload("res://src/map/expedition_garden_boundary.gd")
const LOTUS = preload("res://src/map/expedition_lotus_tile.gd")
var _pass := 0
var _fail := 0
var _out := ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-17-garden/godot-closed-lotus-garden")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(180).timeout.connect(func(): push_error("Closed garden capture timed out"); get_tree().quit(1))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok: _pass += 1
	else:
		_fail += 1
		push_error(message)


func _frames(count := 10) -> void:
	for i in count: await get_tree().process_frame


func _shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(filename))==OK,filename)


func _settle(view: ExpeditionMapView) -> void:
	view._look = view._look_target
	view._distance = view._distance_target
	view._apply_camera()
	await _frames()


func _snapshot(ex: Expedition) -> String:
	return var_to_str([ex.rng.state,GameState.rng.state,ex.m,ex.pos,ex.t,ex.taken,ex.used])


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920,1080)
	var ex := Expedition.start(1234)
	ex.m = MapGen.generate(11,"墨池")
	ex.pos = ex.m.start
	ex.boss = ex.m.lair
	for k in MapGen.N: ex.explored[k] = true; ex.visible[k] = true
	var before := _snapshot(ex)
	var screen: Control = load("res://src/screens/expedition_map_screen.gd").new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(14)
	var view: ExpeditionMapView = screen._map_view
	var scenery: Node3D = view._garden_scenery
	var parts: Array = scenery.perimeter.assembly.get_children()
	_check(_snapshot(ex)==before,"Boundary and lotus do not change gameplay state or RNG")
	_check(scenery.perimeter.assembly.get_meta("closed") and scenery.perimeter.assembly.get_meta("segment_count")==2*(MapGen.W+MapGen.H),"Forty wall bays enclose all four sides")
	_check(scenery.perimeter.assembly.get_meta("post_count")==40,"Closed corners and straight joins share forty posts")
	var patterns := {}
	var border_cells := {}
	var edges_valid := true
	for record in scenery.perimeter.records:
		for k: int in record.cells: border_cells[k] = true
		var part: Node3D = record.root
		if part.piece==BOUNDARY.Piece.WINDOW_WALL: patterns[int(part.window_pattern)] = true
		if part.piece not in [BOUNDARY.Piece.WALL,BOUNDARY.Piece.WINDOW_WALL]: continue
		var a: Vector3 = part.to_global(Vector3.ZERO)
		var b: Vector3 = part.to_global(Vector3(2,0,0))
		edges_valid = edges_valid and is_equal_approx(a.distance_to(b),1.0)
		edges_valid = edges_valid and ((is_equal_approx(a.x,b.x) and (is_zero_approx(a.x) or is_equal_approx(a.x,MapGen.W))) or (is_equal_approx(a.z,b.z) and (is_zero_approx(a.z) or is_equal_approx(a.z,MapGen.H))))
	_check(edges_valid,"Every wall bay lies on an actual map boundary with one-cell pitch")
	_check(border_cells.size()==36 and patterns.size()==3,"All thirty-six boundary cells and three lattice patterns are covered")
	_check(scenery.flower_specs.size()>=2,"Runtime pond includes flower assets, not just scattered leaves")
	print("[RuntimeLotus] ",scenery.flower_specs.map(func(spec): return [spec.at,spec.kind]))
	var kinds := {}
	var plants_valid := true
	for spec in scenery.flower_specs:
		var node: Node3D = spec.node
		kinds[spec.kind] = true
		plants_valid = plants_valid and node.plants_only and node.water==null and node.bank_count==0
		plants_valid = plants_valid and scenery._water_disc_clear(spec.at,.30)
		plants_valid = plants_valid and is_equal_approx(node.foliage.water_height*.5,float(ex.m.layout.water_height))
		for petal in node.find_children("LotusPetal","MeshInstance3D",true,false):
			for vertex: Vector3 in petal.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var at: Vector3 = petal.to_global(vertex)
				plants_valid = plants_valid and scenery._open_water(Vector2(at.x,at.z))
	_check(plants_valid and kinds.has(LOTUS.Plant.BLOOM) and kinds.has(LOTUS.Plant.BUD),"Old bloom/bud geometry matches water level, avoids land/bridge and adds no duplicate banks")
	view.show_overview()
	await _settle(view)
	await _shot("01-closed-map-overview-1920.png")
	if not scenery.flower_specs.is_empty():
		var at: Vector2 = scenery.flower_specs[0].at
		view.following = false
		view.overview = false
		view._look_target = Vector3(at.x,.05,at.y)
		view._distance_target = 7.2
		await _settle(view)
		await _shot("02-runtime-lotus-close-1920.png")
		get_window().size = Vector2i(1280,720)
		await _frames()
		await _shot("03-runtime-lotus-1280.png")
		var flower: Node3D = scenery.flower_specs[0].node
		var k := MapGen.kk(floori(at.y),floori(at.x))
		ex.visible.erase(k)
		scenery.sync(ex)
		var petal: MeshInstance3D = flower.find_children("LotusPetal","MeshInstance3D",true,false)[0]
		_check(flower.visible and is_equal_approx(petal.material_override.get_shader_parameter("map_shade"),.48),"Explored lotus dims outside sight")
		ex.explored.erase(k)
		scenery.sync(ex)
		_check(not flower.visible,"Unexplored lotus is entirely hidden")
		for cell in MapGen.N: ex.explored[cell] = true; ex.visible[cell] = true
		scenery.sync(ex)
	var edge := -1
	for c in range(1,MapGen.W-1):
		var k := MapGen.kk(MapGen.H-1,c)
		if ex.m.ink[k]==0: edge = k; break
	_check(edge>=0,"A traversable near boundary cell remains available")
	if edge>=0:
		ex.pos = edge
		view.refresh(ex)
		view.recenter()
		view._look_target = view.world_position(edge)
		await _settle(view)
		view._update_occlusion()
		var faded := false
		var foundation_opaque := true
		for part in scenery.perimeter.assembly.get_children():
			for mesh in part.find_children("*","GeometryInstance3D",true,false):
				if mesh.name=="ContinuousBoundaryPlinth":
					foundation_opaque = foundation_opaque and is_zero_approx(mesh.transparency)
					foundation_opaque = foundation_opaque and mesh.to_global(Vector3(0,mesh.get_aabb().end.y,0)).y>.25
				elif mesh.transparency>0: faded = true
		_check(faded and foundation_opaque,"Near wall fades for the player while continuous foundation stays opaque")
		_check(view.cell_at(view.cell_center(edge))==edge,"Near-wall grid picking stays aligned")
		await _shot("04-near-boundary-fade-1280.png")
	var point := view.camera.unproject_position(Vector3(-.5,0,4.5))
	_check(view.cell_at(point)==-1,"Outside the enclosing wall cannot become a valid cell")
	ex.m = MapGen.generate_legacy(11,"墨池")
	ex.pos = ex.m.start
	ex.boss = ex.m.lair
	view.refresh(ex)
	await _frames()
	_check(view._garden_scenery.perimeter.assembly.get_meta("segment_count")==40,"Legacy/fallback maps also get a complete perimeter")
	screen.queue_free()
	await _frames(3)
	# Review all lattice motifs under the same production lighting.
	var lab: Control = load("res://src/tools/expedition_garden_lab.gd").new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(4)
	lab.style.reset_geometry_tracking()
	for child in lab.contents.get_children():
		lab.contents.remove_child(child)
		child.queue_free()
	lab.assets.clear()
	lab.trees.clear()
	lab.labels.clear()
	lab.chrome.visible = false
	lab._ground(Rect2(-3.5,-2.0,7,4))
	for n in 3:
		var wall := BOUNDARY.new()
		wall.piece = BOUNDARY.Piece.WINDOW_WALL
		wall.window_pattern = n
		wall.scale = Vector3.ONE*.65
		wall.position = Vector3((n-1)*1.65-.65,0,0)
		lab.contents.add_child(wall)
		wall.setup(lab.style)
		lab.labels.append([Vector3((n-1)*1.65,-.10,.25),["回纹","海棠","冰裂"][n],0])
	lab._yaw = 8
	lab._pitch = 15
	lab._look = Vector3(0,.56,0)
	lab._height = 3.1
	lab._apply_camera()
	get_window().size = Vector2i(1920,1080)
	await _frames()
	await _shot("05-garden-window-lattices-1920.png")
	lab.queue_free()
	await _frames(3)
	print("[ClosedLotusGarden] PASS=%d FAIL=%d" % [_pass,_fail])
	get_tree().quit(1 if _fail else 0)
