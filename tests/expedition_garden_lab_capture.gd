extends Control
## Native screenshots and assembly validation; no game expedition is started.
const LAB = preload("res://src/tools/expedition_garden_lab.gd")
var _pass := 0
var _fail := 0
var _out := ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-17-garden/godot-garden-model-study")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(150).timeout.connect(func(): push_error("园林构件预览超时"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if ok: _pass += 1
	else:
		_fail += 1
		push_error(message)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"园林截图 "+name)


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
	_check(lab.assets.size()==4,"月洞门、照壁、游廊和石桥均完成建模")
	await _shot("01-garden-courtyard-1920.png")
	for i in range(1,5):
		lab.set_mode(i)
		await _frames()
		await _shot("0%d-building-%d-1920.png" % [i+1,i])
	lab.set_mode(1)
	lab._yaw = 155
	lab._apply_camera()
	await _frames()
	await _shot("06-moon-gate-back-1920.png")
	for i in range(5,8):
		lab.set_mode(i)
		await _frames()
		await _shot("0%d-modules-%d-1920.png" % [i+2,i])
	_check(lab.assemblies.size()==4,"闭合栏杆、闭合围墙、半段与直墙均有拼接样板")
	for i in lab.assemblies.size():
		var group: Node3D = lab.assemblies[i]
		var count: int = group.get_meta("segment_count")
		_check(group.get_meta("post_count")==count+(0 if i<2 else 1),"转角和直连共用立柱，没有重复柱：%d" % i)
		var connected := true
		var posts: Array = group.get_meta("post_positions")
		for child in group.get_children():
			for socket in child.get_meta("sockets",[]):
				var point: Vector3 = child.position+child.basis*socket
				var found := false
				for post: Vector3 in posts: found = found or post.distance_to(point)<.0001
				connected = connected and found
		_check(connected,"各段连接口与立柱精确重合：%d" % i)
	lab.grid_toggle.button_pressed = true
	await _frames()
	await _shot("10-join-sockets-1920.png")
	lab.grid_toggle.button_pressed = false
	lab.set_mode(6)
	lab._yaw = 152
	lab._apply_camera()
	await _frames()
	await _shot("11-walls-back-1920.png")
	lab.set_mode(0)
	get_window().size = Vector2i(1280,720)
	await _frames(12)
	await _shot("12-garden-courtyard-1280.png")
	lab.warm_toggle.button_pressed = false
	await _frames()
	await _shot("13-garden-moonlight-1280.png")
	lab.chrome.visible = true
	await _frames()
	_check(lab.chrome.get_child(1).get_global_rect().end.x<=lab.size.x,"1280宽下预览工具条不越界")
	await _shot("14-garden-workbench-1280.png")
	_check(GameState.rng.state==rng_before and GameState.expedition==expedition_before,"独立建模、配色、镜头和拼接未创建或修改远征")
	lab.queue_free()
	await _frames()
	for name in ["moon_gate","screen_wall","covered_walk","stone_bridge","rail_straight","rail_half","rail_post","rail_end","rail_broken","rail_corner","wall_straight","wall_window","wall_post","wall_end","wall_broken","wall_corner"]:
		var prefab: PackedScene = load("res://assets/expedition/garden/"+name+".tscn")
		var instance: Node3D = prefab.instantiate()
		add_child(instance)
		await _frames(2)
		_check(instance.find_children("*","MeshInstance3D",true,false).size()>0,"独立场景可直接实例化："+name)
		instance.queue_free()
		await _frames(1)
	print("[GardenModelLab] PASS=%d FAIL=%d" % [_pass,_fail])
	get_tree().quit(1 if _fail else 0)
