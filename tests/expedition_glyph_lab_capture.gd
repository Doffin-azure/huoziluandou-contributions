extends Node
## Native capture plus a few integration checks for floor projection and rule timing.
const LAB = preload("res://src/tools/expedition_glyph_lab.gd")
var _fail := 0
var _capture := false
var _out := ""


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-16-mochi/godot-glyph-study")
	if _capture: DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(60).timeout.connect(func(): push_error("字砖小样超时"); get_tree().quit(1))
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
	for mark: Node3D in lab.inscriptions:
		_check(mark.face.billboard==BaseMaterial3D.BILLBOARD_DISABLED and mark.face.global_basis.z.dot(Vector3.UP)>.999,"字面必须贴地，不随镜头转向")
		_check(not mark.face.no_depth_test,"刻字保留遮挡关系")
	lab.props_toggle.button_pressed = false
	await _frames()
	await _shot("01-inlaid-glyphs-1280.png")
	lab.props_toggle.button_pressed = true
	await _frames()
	await _shot("02-props-low-tide-1280.png")
	lab._look += Vector3(.15,0,.08)
	lab._view_size = 3.10
	lab._apply_camera()
	await _frames()
	for index in 9:
		var point: Vector2 = lab.camera.unproject_position(Vector3(index%3+.5,0,index/3+.5))
		_check(lab.pick_cell(point)==index,"拖看缩放后点击应命中原字格")
	lab._look = Vector3(1.5,0,1.5)
	lab._view_size = 3.35
	lab._apply_camera()
	var low_level: float = lab._water.position.y
	lab.set_tick(4)
	_check(lab._water.position.y>low_level,"探索步数使浅渠水位上升")
	await _frames()
	_check(lab.tick==4,"帧时间不能推进涨退潮规则")
	await _shot("03-high-tide-1280.png")
	lab.alias_toggle.button_pressed = true
	_check(lab.inscriptions[7].glyph=="渡" and lab.inscriptions[2].glyph=="灼" and lab.inscriptions[4].glyph=="镇" and MapGen.THEMES["潮汐渠"].mech[1].g=="潮","候选换字只作用于小样")
	await _frames()
	await _shot("04-ferry-candidate-1280.png")
	lab.used_toggle.button_pressed = true
	_check(lab.inscriptions[0].spent and lab.inscriptions[6].spent and not lab.inscriptions[1].spent,"纸为重复生效地块，消耗预览不得把它关掉")
	_check(not lab._flow_arrows.visible and lab._spent_marks.visible,"用尽同时改变方向标与局部形状")
	await _frames()
	await _shot("05-spent-1280.png")
	lab.used_toggle.button_pressed = false
	lab.alias_toggle.button_pressed = false
	lab.set_tick(8)
	_check(is_equal_approx(lab._water.position.y,low_level),"沿用现有4开4关周期")
	_check(GameState.rng.state==rng_before,"小样操作不消耗玩法随机数")
	get_window().size = Vector2i(1920,1080)
	await _frames(8)
	await _shot("06-glyphs-1920.png")
	lab.queue_free()
	await _frames()
	print("[InlaidGlyphLab] FAIL %d" % _fail)
	get_tree().quit(0 if _fail==0 else 1)
