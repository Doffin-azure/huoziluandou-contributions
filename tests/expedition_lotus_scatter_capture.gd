extends Control
## Native art preview: reproducible variation, water clearance, and legacy tiles.
const LAB = preload("res://src/tools/expedition_lotus_lab.gd")
var _pass := 0
var _fail := 0
var _out := ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-17-garden/godot-lotus-scatter-study")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(120).timeout.connect(func(): push_error("小莲叶预览超时"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if ok: _pass += 1
	else:
		_fail += 1
		push_error(message)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(file))==OK,"小叶截图 "+file)


func _snapshot(lab: Control) -> String:
	var result: Array = []
	for layer in lab.leaf_layers: result.append(layer.leaf_specs.duplicate(true))
	return var_to_str(result)


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
	lab.set_mode(8)
	await _frames()
	var radii: Array[float] = []
	var positions: Dictionary = {}
	var counts: Dictionary = {}
	var no_overlap := true
	for layer in lab.leaf_layers:
		counts[layer.leaf_specs.size()] = true
		positions[var_to_str(layer.leaf_specs)] = true
		for i in layer.leaf_specs.size():
			var leaf: Dictionary = layer.leaf_specs[i]
			radii.append(leaf.radius)
			for j in i:
				var other: Dictionary = layer.leaf_specs[j]
				no_overlap = no_overlap and leaf.at.distance_to(other.at)>(leaf.radius+other.radius)*1.09
	_check(lab.leaf_layers.size()==9 and radii.size()>=20,"九格小叶样板生成足够的分散小叶")
	radii.sort()
	_check(radii[-1]/radii[0]>2 and positions.size()==9 and counts.size()>1,"小叶大小、位置与数量有变化，九格不重复同一布局")
	_check(no_overlap,"叶片不重复堆在同一位置")
	var before := _snapshot(lab)
	lab.set_mode(8)
	_check(_snapshot(lab)==before,"同一种子重建时布局完全一致")
	lab.seed_picker.value = 8056
	_check(_snapshot(lab)!=before,"更换种子会改变布局")
	lab.seed_picker.value = 137
	_check(_snapshot(lab)==before,"改回原种子恢复原布局")
	await _frames()
	await _shot("01-loose-leaves-3x3-1920.png")
	lab.set_mode(9)
	await _frames()
	await _shot("02-loose-cluster-mixed-1920.png")
	lab.set_mode(10)
	await _frames()
	var layer: Node3D = lab.leaf_layers[0]
	var on_water := true
	for leaf in layer.leaf_specs:
		on_water = on_water and layer.water_test.call(leaf.at)
		for i in 12:
			on_water = on_water and layer.water_test.call(leaf.at+Vector2.from_angle(TAU*i/12.0)*leaf.radius*1.14)
	_check(on_water and layer.leaf_specs.size()>=14,"不规则池岸中的叶片及外缘均在水内，避开石地")
	await _shot("03-irregular-small-leaves-1920.png")
	lab.grid_toggle.button_pressed = true
	await _frames()
	await _shot("04-irregular-small-leaves-grid-1920.png")
	lab.grid_toggle.button_pressed = false
	lab.seed_picker.value = 8056
	await _frames()
	await _shot("05-irregular-another-seed-1920.png")
	lab.seed_picker.value = 137
	get_window().size = Vector2i(1280,720)
	await _frames()
	await _shot("06-irregular-small-leaves-1280.png")
	lab.chrome.visible = true
	await _frames()
	var panel: Control = lab.chrome.get_child(1)
	_check(panel.get_global_rect().end.x<=lab.size.x and panel.get_global_rect().end.y<=lab.size.y,"1280×720可操作布局种子与换组按钮")
	await _shot("07-lotus-seed-workbench-1280.png")
	lab.chrome.visible = false
	lab.set_mode(0)
	await _frames()
	await _shot("08-existing-lotus-varied-1280.png")
	lab.set_mode(5)
	var stone_foliage: Node3D = lab.leaf_layers[0]
	var clear_of_stone := true
	for leaf in stone_foliage.leaf_specs:
		clear_of_stone = clear_of_stone and not Rect2(-.52,-.46,1.04,.92).grow(leaf.radius*1.14).has_point(leaf.at)
	_check(clear_of_stone,"踏石与刻字保持留空")
	lab.queue_free()
	await _frames()
	for file in ["lotus_scattered_leaves","lotus_small_cluster","lotus_tiny_leaves"]:
		var asset: Node3D = load("res://assets/expedition/lotus/%s.tscn" % file).instantiate()
		add_child(asset)
		await _frames(2)
		_check(asset.water!=null and asset.foliage.leaf_specs.size()>0,"新预制场景独立生成 "+file)
		asset.queue_free()
	await _frames()
	_check(GameState.rng.state==initial_rng and GameState.expedition==initial_expedition,"叶片布局不影响玩法随机数与远征状态")
	print("[LotusScatterLab] PASS=%d FAIL=%d" % [_pass,_fail])
	get_tree().quit(1 if _fail else 0)
