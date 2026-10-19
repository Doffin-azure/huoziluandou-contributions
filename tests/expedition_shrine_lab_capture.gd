extends Node
const LAB = preload("res://src/tools/expedition_shrine_lab.gd")
const CONTEXT = preload("res://src/tools/expedition_atmosphere_lab.gd")
var _capture := false
var _out := ""
var _fail := 0


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-16-mochi/godot-shrine-study")
	if _capture: DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(90).timeout.connect(func(): push_error("建筑小样超时"); get_tree().quit(1))
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
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"保存建筑实机图失败："+name)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var rng_before := GameState.rng.state
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(12)
	_check(lab.shrine.roof.mesh.get_aabb().size.z>1.0,"屋顶是有深度的实体网格")
	_check(lab.shrine.niche_frame.mesh.get_aabb().size.z>.09,"龛口框架有实际厚度")
	var roof_id: int = lab.shrine.roof.mesh.get_instance_id()
	await _shot("01-shrine-front-1280.png")
	lab._yaw = 80
	lab._apply_camera()
	await _frames()
	await _shot("02-shrine-side-1280.png")
	lab._yaw = 155
	lab._apply_camera()
	await _frames()
	await _shot("03-shrine-back-1280.png")
	_check(lab.shrine.roof.mesh.get_instance_id()==roof_id,"转动镜头不替换建筑几何")
	lab.mode.select(1)
	lab.mode.item_selected.emit(1)
	await _frames()
	await _shot("04-shrine-and-pine-1280.png")
	_check(lab.tree.visible and lab.tree.palette==lab.palette,"建筑与怪松共用调色板")
	lab.mode.select(0)
	lab.mode.item_selected.emit(0)
	lab.light_toggle.button_pressed = false
	await _frames()
	_check(is_zero_approx(lab.style.face_material("architecture").get_shader_parameter("fire_energy")),"熄灯关闭局部暖色受光")
	await _shot("05-lamp-off-1280.png")
	lab.light_toggle.button_pressed = true
	_check(lab.style.face_material("architecture").get_shader_parameter("fire_energy")>.0,"点灯同步恢复风格化受光")
	if _capture and OS.get_cmdline_user_args().has("--record"):
		var frames := OS.get_environment("TEMP").path_join("huozi-shrine-frames")
		DirAccess.make_dir_recursive_absolute(frames)
		for frame in 112:
			lab._yaw = 18+frame/111.0*360
			lab._apply_camera()
			await RenderingServer.frame_post_draw
			_check(get_viewport().get_texture().get_image().save_png(frames.path_join("%04d.png"%frame))==OK,"保存建筑转看实机帧")
		print("[ShrineLab] frames: "+frames)
	lab.queue_free()
	await _frames()
	var context := CONTEXT.new()
	add_child(context)
	context.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(12)
	await _shot("06-shrine-in-courtyard-1280.png")
	for index in 9:
		var point: Vector2 = context.camera.unproject_position(Vector3(index%3+.5,0,index/3+.5))
		_check(context.pick_cell(point)==index,"新建筑不改变字格拾取")
	get_window().size = Vector2i(1920,1080)
	await _frames(8)
	await _shot("07-shrine-in-courtyard-1920.png")
	_check(GameState.rng.state==rng_before,"建筑、转看和暖光不消耗玩法随机数")
	context.queue_free()
	await _frames()
	print("[ShrineLab] FAIL %d" % _fail)
	get_tree().quit(0 if _fail==0 else 1)
