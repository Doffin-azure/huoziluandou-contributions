extends Node
## Native visual review and integration checks; this fixture never advances a live run.
const LAB = preload("res://src/tools/expedition_atmosphere_lab.gd")
var _fail := 0
var _capture := false
var _out := ""


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-16-mochi/godot-atmosphere-study")
	if _capture: DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(90).timeout.connect(func(): push_error("外围建筑小样超时"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 5) -> void:
	for i in count: await get_tree().process_frame


func _check(value: bool, message: String) -> void:
	if not value:
		_fail += 1
		push_error(message)


func _shot(name: String) -> void:
	if not _capture: return
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"保存实机图失败："+name)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var rng_before := GameState.rng.state
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(12)
	var glyph_ids := []
	for mark: Node3D in lab.inscriptions: glyph_ids.append(mark.get_instance_id())
	await _shot("01-cool-courtyard-1280.png")
	lab.palette_select.select(1)
	lab.palette_select.item_selected.emit(1)
	_check(lab.palette.stone_top==lab.HALL.stone_top and lab.palette.mist==lab.HALL.mist,"配色选择同时更新石地与远雾")
	_check(lab.palette.architecture_front==lab.style.face_material("architecture").get_shader_parameter("front_color"),"外围建筑共用调色板")
	await _frames()
	await _shot("02-cinnabar-hall-1280.png")
	lab.palette_select.select(2)
	lab.palette_select.item_selected.emit(2)
	await _frames()
	await _shot("03-original-palette-1280.png")
	lab.palette_select.select(0)
	lab.palette_select.item_selected.emit(0)
	for index in 9: _check(lab.inscriptions[index].get_instance_id()==glyph_ids[index],"换配色不替换汉字或机关")
	lab.scenery_toggle.button_pressed = false
	_check(is_zero_approx(lab.style.face_material("stone").get_shader_parameter("fire_energy")),"隐藏外围灯具后关闭样板暖光")
	await _frames()
	await _shot("04-palette-only-1280.png")
	lab.scenery_toggle.button_pressed = true
	var near_world: Vector3 = lab.surroundings.near_anchor.global_position
	var far_world: Vector3 = lab.surroundings.far_anchor.global_position
	var near_before: Vector2 = lab.camera.unproject_position(near_world)
	var far_before: Vector2 = lab.camera.unproject_position(far_world)
	lab._look += Vector3(.25,0,0)
	lab._apply_camera()
	var near_after: Vector2 = lab.camera.unproject_position(near_world)
	var far_after: Vector2 = lab.camera.unproject_position(far_world)
	_check(near_after.distance_to(near_before)>far_after.distance_to(far_before)*1.10,"透视镜头拖动时近景与远景产生不同幅度的真实位移")
	for index in 9:
		var point: Vector2 = lab.camera.unproject_position(Vector3(index%3+.5,0,index/3+.5))
		_check(lab.pick_cell(point)==index,"装饰不改变机关落脚格的拾取")
	lab.reset_camera()
	lab.set_tick(4)
	await _frames()
	await _shot("05-high-tide-1280.png")
	_check(lab.tick==4 and lab._tide_warning.visible,"新增装饰保留原有机关周期")
	lab.set_tick(0)
	if _capture and OS.get_cmdline_user_args().has("--record"):
		var frames := OS.get_environment("TEMP").path_join("huozi-atmosphere-frames")
		DirAccess.make_dir_recursive_absolute(frames)
		for frame in 96:
			var phase := frame/95.0*TAU
			lab._look = Vector3(1.5,.28,1.25)+Vector3(sin(phase)*.35,0,sin(phase*.5)*.20)
			lab._view_size = 4.6+sin(phase)*.15
			lab._apply_camera()
			await RenderingServer.frame_post_draw
			_check(get_viewport().get_texture().get_image().save_png(frames.path_join("%04d.png"%frame))==OK,"保存视差实机帧")
		print("[AtmosphereLab] frames: "+frames)
		lab.reset_camera()
	get_window().size = Vector2i(1920,1080)
	await _frames(8)
	await _shot("06-cool-courtyard-1920.png")
	_check(GameState.rng.state==rng_before,"装饰、调色与镜头不消耗玩法随机数")
	_check(lab.DUSK.stone_top==lab.palette_source.stone_top,"预设资源保持原值")
	lab.queue_free()
	await _frames()
	print("[AtmosphereLab] FAIL %d" % _fail)
	get_tree().quit(0 if _fail==0 else 1)
