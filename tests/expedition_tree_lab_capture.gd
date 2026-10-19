extends Node
const LAB = preload("res://src/tools/expedition_tree_lab.gd")
const CONTEXT = preload("res://src/tools/expedition_atmosphere_lab.gd")
var _capture := false
var _out := ""
var _fail := 0


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-16-mochi/godot-pine-study")
	if _capture: DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(60).timeout.connect(func(): push_error("古树小样超时"); get_tree().quit(1))
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
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"保存树的实机图失败："+name)


func _dark_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x,y)
			if color.r<.085 and color.g<.14 and color.b<.16: count += 1
	return count


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var rng_before := GameState.rng.state
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(12)
	await _shot("01-tree-closeup-1280.png")
	var outlined := 0
	if _capture: outlined = _dark_pixels(lab.viewport.get_texture().get_image())
	lab.contour_toggle.button_pressed = false
	await _frames()
	await _shot("02-without-contour-1280.png")
	if _capture: _check(outlined>_dark_pixels(lab.viewport.get_texture().get_image())+600,"实机外轮廓应形成可见深墨笔线")
	lab.contour_toggle.button_pressed = true
	lab.line_slider.value = 2.7
	await _frames()
	await _shot("03-stronger-ink-1280.png")
	lab.palette.tree_outline_pixels = LAB.PALETTE.tree_outline_pixels
	lab._view_size = 4.8
	lab._apply_camera()
	await _frames()
	await _shot("04-tree-small-1280.png")
	var source_color: Color = LAB.PALETTE.tree_leaf
	lab._pickers["tree_leaf"].color_changed.emit(Color("405c4b"))
	_check(LAB.PALETTE.tree_leaf==source_color,"单树调色不覆盖项目预设")
	lab.queue_free()
	await _frames()
	var context := CONTEXT.new()
	add_child(context)
	context.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(12)
	_check(context.surroundings.tree.contour.visible,"碑院复用同一棵有描线的树")
	await _shot("05-tree-in-courtyard-1280.png")
	for index in 9:
		var point: Vector2 = context.camera.unproject_position(Vector3(index%3+.5,0,index/3+.5))
		_check(context.pick_cell(point)==index,"树的精细化不影响地图格拾取")
	get_window().size = Vector2i(1920,1080)
	await _frames(8)
	await _shot("06-tree-in-courtyard-1920.png")
	_check(GameState.rng.state==rng_before,"树的生成与调色不消耗玩法随机数")
	context.queue_free()
	await _frames()
	print("[TreeLab] FAIL %d" % _fail)
	get_tree().quit(0 if _fail==0 else 1)
