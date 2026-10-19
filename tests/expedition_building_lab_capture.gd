extends Node
const LAB = preload("res://src/tools/expedition_building_lab.gd")
var _out := ""
var _fail := 0


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-16-mochi/godot-building-study")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			_out = ProjectSettings.globalize_path(argument.trim_prefix("--output-dir="))
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(90).timeout.connect(func(): push_error("建筑组小样超时"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 8) -> void:
	for n in count: await get_tree().process_frame


func _check(value: bool, message: String) -> void:
	if not value:
		_fail += 1
		push_error(message)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"保存建筑实机图失败："+name)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var rng_before := GameState.rng.state
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(24)
	_check(lab.buildings.size()==3,"三种建筑各使用独立组件")
	await _shot("01-three-buildings-1280.png")
	for index in 3:
		lab.mode.select(index)
		lab.mode.item_selected.emit(index)
		await _frames()
		await _shot("0%d-building-%d-1280.png"%[index+2,index])
	lab.state_toggle.button_pressed = true
	await _frames()
	_check(absf(lab.buildings[2].left_door.rotation.y)>1.0,"解封真实转动门扇")
	_check(not lab.buildings[2]._seal.visible,"解封移除中央封条")
	await _shot("05-gate-open-1280.png")
	lab.mode.select(1)
	lab.mode.item_selected.emit(1)
	await _frames()
	_check(lab.buildings[1]._shutters.visible and not lab.buildings[1]._wares.visible,"收摊关闭柜板并收起字模")
	await _shot("06-stall-closed-1280.png")
	lab.mode.select(0)
	lab.mode.item_selected.emit(0)
	await _frames()
	_check(lab.buildings[0]._rest_tag.visible and not lab.buildings[0]._lamps[0].visible,"已使用亭熄灯并挂歇牌")
	await _shot("07-rest-used-1280.png")
	lab.state_toggle.button_pressed = false
	lab.mode.select(3)
	lab.mode.item_selected.emit(3)
	get_window().size = Vector2i(1920,1080)
	await _frames(12)
	await _shot("08-three-buildings-1920.png")
	lab.mode.select(4)
	lab.mode.item_selected.emit(4)
	await _frames()
	await _shot("09-shrine-family-1920.png")
	lab.mode.select(2)
	lab.mode.item_selected.emit(2)
	lab._yaw = 85
	lab._apply_camera()
	await _frames()
	await _shot("10-gate-side-1920.png")
	lab.lighting_toggle.button_pressed = false
	await _frames()
	_check(not lab.buildings[2]._lamps[0].visible,"关闭实际受光也关闭设施原生灯")
	lab.lighting_toggle.button_pressed = true
	_check(GameState.rng.state==rng_before,"建筑、状态与灯光不消耗玩法随机数")
	lab.queue_free()
	await _frames()
	print("[BuildingLab] FAIL %d"%_fail)
	get_tree().quit(0 if _fail==0 else 1)
