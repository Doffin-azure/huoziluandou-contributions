extends Control
## Capture the actual Godot scene and check the spatial study in isolation.
const STUDY = preload("res://src/tools/expedition_courtyard_study.gd")
var passed := 0
var failed := 0
var output := ""


func _ready() -> void:
	output = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-17-courtyard")
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().create_timer(150).timeout.connect(func(): push_error("庭院样板截图超时"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 10) -> void:
	for i in count: await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(message)


func _shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(output.path_join(filename))==OK,"保存实机截图 "+filename)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920,1080)
	var before := GameState.rng.state
	var previous: Expedition = GameState.expedition
	var study := STUDY.new()
	add_child(study)
	study.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(16)
	study.chrome.visible = false
	_check(study.layout_errors.is_empty(),"建筑与通行空间："+str(study.layout_errors))
	_check(study.surveyed.size()==4 and study.pond_tiles.size()==48,"四件主建筑与8×6连续地形构建完成")
	_check(study.surveyed[0].node.open_floor_passage,"月洞门使用无门槛的通行开口")
	var seams_match := true
	for z in 6:
		for x in 8:
			var tile: Node3D = study.pond_tiles[z*8+x]
			for n in 13:
				var t := float(n)/12
				if x<7: seams_match = seams_match and is_equal_approx(tile._value(Vector2(1,t)),study.pond_tiles[z*8+x+1]._value(Vector2(0,t)))
				if z<5: seams_match = seams_match and is_equal_approx(tile._value(Vector2(t,1)),study.pond_tiles[(z+1)*8+x]._value(Vector2(t,0)))
	_check(seams_match,"所有相邻地形模块在共边采样处使用相同岸线值")
	for entry in study.surveyed:
		print("[CourtyardBounds] ",entry.label," body=",entry.body," roof=",entry.canopy)
	await _shot("01-courtyard-overview-1920.png")
	study.set_mode(1)
	await _frames()
	await _shot("02-clearance-plan-1920.png")
	study.set_mode(2)
	await _frames()
	await _shot("03-entrance-1920.png")
	study.set_mode(0)
	study._yaw = -22
	study._pitch = 39
	study._apply_camera()
	await _frames()
	await _shot("04-courtyard-reverse-1920.png")
	study.set_mode(0)
	get_window().size = Vector2i(1280,720)
	await _frames(12)
	await _shot("05-courtyard-overview-1280.png")
	study.chrome.visible = true
	await _frames()
	await _shot("06-courtyard-workbench-1280.png")
	_check(GameState.rng.state==before and GameState.expedition==previous,"样板未消耗玩法随机数或更改远征状态")
	print("[CourtyardStudy] PASS=%d FAIL=%d" % [passed,failed])
	get_tree().quit(1 if failed else 0)
