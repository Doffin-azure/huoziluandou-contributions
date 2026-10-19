extends Control
## Native shape, shared edge and cutaway checks plus production previews.
const LAB = preload("res://src/tools/expedition_pond_shape_lab.gd")
const SHAPE = preload("res://src/map/expedition_pond_shape_tile.gd")
var _pass := 0
var _fail := 0
var _out := ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-17-garden/godot-water-shape-study")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(120).timeout.connect(func(): push_error("局部水岸预览超时"); get_tree().quit(1))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok: _pass += 1
	else:
		_fail += 1
		push_error(message)


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(file))==OK,"水岸截图 "+file)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920,1080)
	var initial_rng := GameState.rng.state
	var initial_expedition: Expedition = GameState.expedition
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(16)
	lab.chrome.visible = false
	_check(lab.ponds[0].get_child_count()==9,"不规则池塘由九片实际格子拼成")
	var cells: Dictionary = {}
	var coverage := true
	for tile in lab.ponds[0].get_children():
		cells[tile.get_meta("cell")] = tile
		coverage = coverage and absf(tile.land_area+tile.rim_area+tile.water_area-4)<.00001
	_check(coverage,"水面、石岸与石地恰好覆盖每格，未留孔或重复铺面")
	var seams := true
	var smooth := true
	for cell: Vector2i in cells:
		for direction: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN]:
			if not cells.has(cell+direction): continue
			var a: Node3D = cells[cell]
			var b: Node3D = cells[cell+direction]
			for i in 33:
				var t := i/32.0
				var uv_a := Vector2(1,t) if direction.x else Vector2(t,1)
				var uv_b := Vector2(0,t) if direction.x else Vector2(t,0)
				seams = seams and absf(a._value(uv_a)-b._value(uv_b))<.000001
				var step := Vector2(direction)*.0001
				var da: float = (a._value(uv_a+step)-a._value(uv_a-step))/.0002
				var db: float = (b._value(uv_b+step)-b._value(uv_b-step))/.0002
				smooth = smooth and absf(da-db)<.001
	_check(seams,"相邻格的共边采样及水岸交点一致")
	_check(smooth,"相邻格的岸线切向连续")
	await _shot("01-irregular-3x3-1920.png")
	lab.grid_toggle.button_pressed = true
	await _frames()
	await _shot("02-irregular-grid-1920.png")
	lab.grid_toggle.button_pressed = false
	for mode_index in range(1,6):
		lab.set_mode(mode_index)
		await _frames()
		if mode_index==1:
			var pure: Node3D = lab.ponds[0].get_child(0)
			var tiny: Node3D = lab.ponds[1].get_child(0)
			var half: Node3D = lab.ponds[4].get_child(0)
			_check(is_equal_approx(pure.water_area,4) and pure.get_node_or_null("LotusPlants")==null,"纯水模块没有莲叶或其他植物")
			_check(tiny.water_area/4<.06 and tiny.water_area/4>.01,"左上水片占格面积约百分之几，余下都是石地")
			_check(absf(half.water_area-2)<.00001,"对角半片水面精确占半格")
		await _shot("0%d-water-mode-%d-1920.png" % [mode_index+2,mode_index])
		if mode_index in [2,3]:
			lab.grid_toggle.button_pressed = true
			await _frames()
			await _shot("0%d-water-mode-%d-grid-1920.png" % [mode_index+2,mode_index])
			lab.grid_toggle.button_pressed = false
	# Exercise all corner topologies, including the two saddle patterns.
	var topology_ok := true
	for mask in 16:
		var tile := SHAPE.new()
		var corners := Vector4(-1,-1,-1,-1)
		for c in 4:
			if mask & (1<<c): corners[c] = 1
		tile.corner_values = corners
		lab.contents.add_child(tile)
		tile.setup(lab.style)
		topology_ok = topology_ok and absf(tile.water_area+tile.land_area+tile.rim_area-4)<.00001
		tile.queue_free()
	_check(topology_ok,"十六种角点组合均完整覆盖格子，包括分离水面与石岛")
	lab.set_mode(0)
	get_window().size = Vector2i(1280,720)
	await _frames()
	await _shot("08-irregular-1280.png")
	lab.chrome.visible = true
	await _frames()
	var panel: Control = lab.chrome.get_child(1)
	_check(panel.get_global_rect().end.x<=lab.size.x and panel.get_global_rect().end.y<=lab.size.y,"1280×720工具条可见")
	await _shot("09-water-workbench-1280.png")
	lab.chrome.visible = false
	lab.set_mode(4)
	lab.warm_toggle.button_pressed = true
	await _frames()
	await _shot("10-garden-warm-light-1280.png")
	lab.queue_free()
	await _frames()
	for file in ["pond_clear","pond_open_water","pond_corner_small","pond_corner_broad","pond_half","pond_half_curve","pond_diagonal_half","pond_inlet"]:
		var asset: Node3D = load("res://assets/expedition/lotus/%s.tscn" % file).instantiate()
		add_child(asset)
		await _frames(2)
		_check(asset.water!=null and asset.footprint==Vector2(2,2),"预制模块可独立实例化 "+file)
		asset.queue_free()
	await _frames()
	_check(GameState.rng.state==initial_rng and GameState.expedition==initial_expedition,"美术样板未改变远征或玩法随机状态")
	print("[PondShapeLab] PASS=%d FAIL=%d" % [_pass,_fail])
	get_tree().quit(1 if _fail else 0)
