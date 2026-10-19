extends Control
## Native tile-size, topology, palette and screenshot checks for the lotus set.
const LAB = preload("res://src/tools/expedition_lotus_lab.gd")
var _pass := 0
var _fail := 0
var _out := ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-17-garden/godot-lotus-tile-study")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(150).timeout.connect(func(): push_error("莲池格子预览超时"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _check(ok: bool, text: String) -> void:
	if ok: _pass += 1
	else:
		_fail += 1
		push_error(text)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"莲池截图 "+name)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920,1080)
	var rng_before := GameState.rng.state
	var expedition_before: Expedition = GameState.expedition
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(16)
	lab.chrome.visible = false
	var count := 0
	var height := true
	var one_grid := true
	var center := false
	for tile in lab.ponds[0].get_children():
		count += tile.bank_count
		height = height and is_equal_approx(tile.water.global_position.y,-.32)
		var box: AABB = tile.water.mesh.get_aabb()
		one_grid = one_grid and is_equal_approx(box.size.x*tile.global_basis.x.length(),1.0) and is_equal_approx(box.size.z*tile.global_basis.z.length(),1.0)
		if tile.get_meta("cell")==Vector2i.ZERO: center = tile.bank_count==0 and tile.island_corners==0
	_check(lab.ponds[0].get_child_count()==9 and one_grid,"3×3样板的每片水面精确占一格")
	_check(height and center and count==12,"九格水面同高，中央无围边，外围只生成十二段岸线")
	await _shot("01-lotus-3x3-1920.png")
	for i in range(1,8):
		lab.set_mode(i)
		await _frames()
		await _shot("0%d-lotus-mode-%d-1920.png" % [i+1,i])
		if i==5:
			var slab: Node3D = lab.ponds[0].get_child(0)
			var engraved := false
			for child in slab.get_children():
				if child.get_script()==ExpeditionMapArt.INLAY: engraved = child.floor_imprint and not child.face.visible
			_check(engraved,"踏石格沿用石材凹刻字，没有白色字面")
		elif i==6:
			var corners := 0
			var isolated := false
			var channel := false
			for tile in lab.ponds[0].get_children():
				corners += tile.island_corners
				if tile.get_meta("cell")==Vector2i(0,2): isolated = tile.bank_count==4 and is_equal_approx(_cap_area(tile),4.0-1.68*1.68)
				if tile.get_meta("cell")==Vector2i(1,0): channel = tile.bank_count==2
			_check(corners>=4,"石岛的对角陆地生成圆弧接角，补齐凹角")
			_check(isolated,"孤立水格四岸正确拼满，斜接岸帽无重复覆盖")
			_check(channel,"单格水道保留两岸和连续水面")
	lab.set_mode(0)
	lab.grid_toggle.button_pressed = true
	await _frames()
	await _shot("09-lotus-grid-1920.png")
	lab.grid_toggle.button_pressed = false
	get_window().size = Vector2i(1280,720)
	await _frames()
	await _shot("10-lotus-3x3-1280.png")
	lab.warm_toggle.button_pressed = true
	await _frames()
	await _shot("11-lotus-warm-light-1280.png")
	lab.chrome.visible = true
	await _frames()
	_check(lab.chrome.get_child(1).get_global_rect().end.x<=lab.size.x and lab.chrome.get_child(1).get_global_rect().end.y<=lab.size.y,"1280×720的独立预览工具条不越界")
	await _shot("12-lotus-workbench-1280.png")
	lab.chrome.visible = false
	lab.warm_toggle.button_pressed = false
	lab.set_mode(2)
	lab._pitch = 27
	lab._apply_camera()
	get_window().size = Vector2i(1920,1080)
	await _frames()
	await _shot("13-lotus-flower-side-1920.png")
	var flower: Node3D = lab.ponds[0].get_child(0)
	var initial: Color = lab.lotus_palette.petal_tip
	lab.lotus_palette.petal_tip = Color("9e8189")
	_check(flower._paints.petal.get_shader_parameter("tip_color")==lab.lotus_palette.petal_tip,"莲瓣颜色可以调整，不需重建模型")
	lab.lotus_palette.petal_tip = initial
	lab.queue_free()
	await _frames()
	for file in ["lotus_leaves","lotus_bud","lotus_bloom","lotus_withered","lotus_step","pond_interior","pond_edge","pond_corner","pond_inner_corner"]:
		var prefab: PackedScene = load("res://assets/expedition/lotus/"+file+".tscn")
		var node: Node3D = prefab.instantiate()
		add_child(node)
		await _frames(2)
		_check(node.water!=null and node.footprint==Vector2(2,2),"独立莲池场景可实例化："+file)
		node.queue_free()
		await _frames(1)
	_check(GameState.rng.state==rng_before and GameState.expedition==expedition_before,"格子建模、岸线、改色和实例化未改变远征或随机数")
	print("[LotusTileLab] PASS=%d FAIL=%d" % [_pass,_fail])
	get_tree().quit(1 if _fail else 0)


func _cap_area(tile: Node3D) -> float:
	var area := 0.0
	for mesh in tile.get_children():
		if not mesh is MeshInstance3D or not str(mesh.name).begins_with("ExposedBank"): continue
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0,vertices.size(),3):
			if vertices[i].y==0 and vertices[i+1].y==0 and vertices[i+2].y==0:
				area += (vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).length()*.5
	return area
