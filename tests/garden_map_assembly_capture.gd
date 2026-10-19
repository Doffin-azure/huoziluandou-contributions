extends Control
var _out := ""
var _pass := 0
var _fail := 0


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-17-garden/godot-generated-garden")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(180).timeout.connect(func(): push_error("园林组装超时"); get_tree().quit(1))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok: _pass += 1
	else: _fail += 1; push_error(message)


func _frames(n := 12) -> void:
	for i in n: await get_tree().process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(file))==OK,"园林实机截图 "+file)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920,1080)
	var ex := Expedition.start(1234)
	ex.m = MapGen.generate(11,"墨池")
	ex.pos = ex.m.start
	ex.boss = ex.m.lair
	ex.explored.clear()
	ex.update_vision()
	var screen: Control = load("res://src/screens/expedition_map_screen.gd").new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames()
	var view: ExpeditionMapView = screen._map_view
	_check(view._garden_scenery!=null and ex.m.has("layout"),"实际远征已接入生成园林")
	print("[GardenBake] first=",view.terrain.get_meta("build_msec"),"ms")
	var duplicate := ExpeditionTerrain.new()
	duplicate.build(ex.m,view._factory)
	_check(duplicate.get_meta("garden_cache_hit",false) and duplicate.get_node("ContinuousStone").mesh==view.terrain.get_node("ContinuousStone").mesh,"返回同图复用烘焙网格")
	print("[GardenBake] cached=",duplicate.get_meta("build_msec"),"ms")
	duplicate.free()
	await _shot("01-actual-start-fog-1920.png")
	var next := -1
	for k: int in MapGen.nbrs(ex.pos):
		if ex.can_step(k) and not ex.m.node.has(k) and not ex.m.mech.has(k) and not ex.m.terr.has(k): next = k; break
	if next>=0:
		var time_before := ex.t
		var click_at := view.global_position+view.cell_center(next)
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.position = click_at
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			get_viewport().push_input(event)
		await get_tree().create_timer(.3).timeout
		_check(ex.pos==next and ex.t==time_before+1,"生成园林中点击实际前进一步")
	for seed_value in [11,83,310]:
		ex.m = MapGen.generate(seed_value,"墨池")
		ex.pos = ex.m.start
		ex.boss = ex.m.lair
		ex.taken.clear()
		ex.used.clear()
		ex.t = 0
		ex.stir = null
		ex.rise = null
		ex.acc = 0.0
		for k in MapGen.N: ex.explored[k] = true; ex.visible[k] = true
		screen.refresh()
		view.show_overview()
		view._look = view._look_target
		view._distance = view._distance_target
		view._apply_camera()
		await _frames()
		await _shot("02-overview-seed-%d-1920.png" % seed_value)
		var aligned := true
		for k in MapGen.N: aligned = aligned and view.cell_at(view.cell_center(k))==k
		_check(aligned,"园林总览格子投影一致 "+str(seed_value))
		if seed_value==11:
			var bridge: int = ex.m.layout.bridges.keys()[0]
			var bridge_entry: Dictionary = ex.m.layout.structures.filter(func(entry): return entry.asset=="bridge")[0]
			ex.pos = bridge_entry.reveal[0]
			screen.refresh()
			await get_tree().create_timer(.3).timeout
			view.following = false
			var point := view.global_position+view.cell_center(bridge)
			for pressed in [true,false]:
				var event := InputEventMouseButton.new()
				event.position = point
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				get_viewport().push_input(event)
			await get_tree().create_timer(.3).timeout
			_check(ex.pos==bridge,"点击桥面进入真正的跨水通行格")
			for k in MapGen.N: ex.visible[k] = true
			screen.refresh()
			view.following = false
			view.overview = false
			view._look = view.world_position(bridge)+Vector3(.7,0,.7)
			view._look_target = view._look
			view._distance = 9.2
			view._distance_target = 9.2
			view._apply_camera()
			await _frames()
			await _shot("03-pond-bridge-walk-1920.png")
			get_window().size = Vector2i(1280,720)
			await _frames()
			await _shot("04-pond-bridge-walk-1280.png")
			get_window().size = Vector2i(1920,1080)
			var walks: Array = ex.m.layout.structures.filter(func(entry): return entry.asset=="covered_walk")
			if not walks.is_empty():
				var inside: int = walks[0].walk[0]
				ex.pos = inside+(1 if absf(walks[0].turn)>.1 else MapGen.W)
				screen.refresh()
				await get_tree().create_timer(.3).timeout
				_check(ex.move(inside),"游廊入口能实际进入")
				screen.refresh()
				await get_tree().create_timer(.3).timeout
				view._update_occlusion()
				var root: Node3D = view._garden_scenery.get_node("Generated_covered_walk")
				var roof_faded := false
				for part in root.find_children("*","GeometryInstance3D",true,false):
					if part.has_meta("roof_occluder") and part.transparency>0: roof_faded = true
				_check(roof_faded,"走到廊下时屋顶淡化")
	ex.m = MapGen.generate(5,"熔铸坊")
	ex.pos = ex.m.start
	ex.boss = ex.m.lair
	for k in MapGen.N: ex.explored[k] = true; ex.visible[k] = true
	screen.refresh()
	view.show_overview()
	view._look = view._look_target
	view._distance = view._distance_target
	view._apply_camera()
	await _frames()
	await _shot("05-double-court-overview-1920.png")
	print("[GardenAssembly] PASS=%d FAIL=%d" % [_pass,_fail])
	get_tree().quit(1 if _fail else 0)
