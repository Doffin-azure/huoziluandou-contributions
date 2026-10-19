extends Node
const LAB = preload("res://src/tools/expedition_shrine_lab.gd")
var _out := ""
var _fail := 0


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-16-mochi/godot-lighting-study")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(90).timeout.connect(func(): push_error("光影样板超时"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _check(value: bool, message: String) -> void:
	if not value:
		_fail += 1
		push_error(message)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"保存光影实机图失败："+name)


func _changed_pixels(before: Image, after: Image) -> int:
	var count := 0
	for y in range(0,before.get_height(),4):
		for x in range(0,before.get_width(),4):
			var a := before.get_pixel(x,y)
			var b := after.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.015: count += 1
	return count


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var rng_before := GameState.rng.state
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(30)
	_check(lab.style.scene_lighting,"新样板启用实际灯光材质")
	_check(lab.main_light.shadow_enabled and lab.lamp_light.shadow_enabled,"主光与龛内灯有实时投影")
	_check(not lab.shrine.get_node("PaintedGroundShadow").visible,"实际投影不叠加旧固定阴影")
	var roof_id: int = lab.shrine.roof.mesh.get_instance_id()
	await _shot("01-lighting-close-1280.png")
	lab.mode.select(1)
	lab.mode.item_selected.emit(1)
	await _frames()
	await _shot("02-lighting-pine-1280.png")
	var fully_lit: Image = lab.viewport.get_texture().get_image()
	lab.light_toggle.button_pressed = false
	await _frames()
	_check(not lab.lamp_light.visible,"熄灯同时关闭真实局部灯")
	await _shot("03-lantern-off-1280.png")
	_check(_changed_pixels(fully_lit,lab.viewport.get_texture().get_image())>20,"熄灯实际改变地图像素，非仅改变控件")
	lab.light_toggle.button_pressed = true
	lab.rim_toggle.button_pressed = false
	await _frames()
	await _shot("04-rim-off-1280.png")
	_check(_changed_pixels(fully_lit,lab.viewport.get_texture().get_image())>30,"冷色灯实际改变模型受光")
	lab.rim_toggle.button_pressed = true
	lab.sky_toggle.button_pressed = false
	await _frames()
	await _shot("05-sky-off-1280.png")
	lab.sky_toggle.button_pressed = true
	lab.lighting_toggle.button_pressed = false
	await _frames()
	_check(not lab.style.scene_lighting and not lab._lights.visible,"旧版对照关闭新受光")
	_check(lab.shrine.get_node("PaintedGroundShadow").visible,"旧版对照恢复绘制阴影")
	await _shot("06-previous-colors-1280.png")
	lab.lighting_toggle.button_pressed = true
	await _frames()
	_check(lab.shrine.roof.mesh.get_instance_id()==roof_id,"切换光照不替换模型")
	get_window().size = Vector2i(1920,1080)
	await _frames(12)
	await _shot("07-lighting-pine-1920.png")
	get_window().size = Vector2i(1280,720)
	lab.mode.select(0)
	lab.mode.item_selected.emit(0)
	lab._yaw = 80
	lab._apply_camera()
	await _frames()
	await _shot("08-lighting-side-1280.png")
	lab._yaw = 155
	lab._apply_camera()
	await _frames()
	await _shot("09-lighting-back-1280.png")
	_check(GameState.rng.state==rng_before,"配色、天空与灯光不消耗玩法随机数")
	lab.queue_free()
	await _frames()
	print("[LightingLab] FAIL %d"%_fail)
	get_tree().quit(0 if _fail==0 else 1)
