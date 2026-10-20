extends "res://src/tools/garden_cluster_lab.gd"


func _ready() -> void:
	super._ready()
	output = "res://docs/art-concepts/2026-10-18-whole-garden"


func _build_controls() -> void:
	super._build_controls()
	mode.set_item_text(0,"整园 · 所有节点与全部分叉")
	var column: VBoxContainer = chrome.get_child(1).get_child(0)
	(column.get_child(1) as Label).text = "全图联合排布 · 同一通行与门位数据 · 全揭示检查视图，游戏仍使用迷雾"


func set_mode(index: int) -> void:
	super.set_mode(index)
	title.text = "整园 · %d 庭／三处分叉／全部实际连线" % run.graph.rooms.size() if index==0 else "庭内莲池与实际院门"
	if index!=0: return
	_fit_whole_view()


func _fit_whole_view() -> void:
	camera.far = 400.0
	var back := (camera.position-_look).normalized()
	var right := Vector3(back.z,0,-back.x).normalized(); var up := back.cross(right)
	var tan_v := tan(deg_to_rad(camera.fov*.5))
	var tan_h := tan_v*float(viewport.size.x)/maxi(1,viewport.size.y)
	var fit := 8.0
	for x in [cluster.bounds.position.x,cluster.bounds.end.x]:
		for z in [cluster.bounds.position.y,cluster.bounds.end.y]:
			for y in [-.75,3.0]:
				var offset := Vector3(x,y,z)-_look
				fit = maxf(fit,offset.dot(back)+absf(offset.dot(right))/(tan_h*.88))
				fit = maxf(fit,offset.dot(back)+absf(offset.dot(up))/(tan_v*.88))
	_height = fit*2*tan_v; _apply_camera()
	print("[WholeGardenCamera] distance=",fit," far=",camera.far," look=",_look)


func _capture() -> void:
	get_window().content_scale_size = Vector2i.ZERO; get_window().size = Vector2i(1600,1100)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await _frames(8); _fit_whole_view(); await _frames(5); _snap("04-native-whole-garden.png")
	grid_toggle.button_pressed = true; await _frames(3); _snap("05-native-all-paths.png",true)
	grid_toggle.button_pressed = false; set_mode(1); await _frames(5); _snap("06-native-court-detail.png")
	print("[WholeGardenNative] rooms=",run.graph.rooms.size()," corridors=",run.layout.corridors.size()," bounds=",cluster.bounds)
	get_tree().quit()
