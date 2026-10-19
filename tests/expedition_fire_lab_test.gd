extends Node
const LAB = preload("res://src/tools/expedition_style_lab.gd")
var _pass := 0
var _fail := 0
var _capture := false
var _record := false
var _out := ""


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_record = OS.get_cmdline_user_args().has("--record")
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-16-mochi/godot-fire-study")
	if _capture: DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(90).timeout.connect(func(): push_error("火光样板检查超时"); get_tree().quit(1))
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	if value: _pass += 1
	else:
		_fail += 1
		push_error(message)


func _frames(count := 5) -> void:
	for i in count: await get_tree().process_frame


func _shot(name: String) -> void:
	if not _capture: return
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"保存火光实机图 " + name)


func _sample(lab: Control, point: Vector3) -> Color:
	var pixel: Vector2i = Vector2i(lab.camera.unproject_position(point))
	return lab.viewport.get_texture().get_image().get_pixelv(pixel)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var rng_before := GameState.rng.state
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(15)
	lab.flicker_toggle.button_pressed = false
	var fire: Node3D = lab.fire
	_check(fire._paints.size()==3 and fire.flame_root.visible,"三层曲线火焰已生成")
	_check(lab.environment.glow_enabled,"柔光在独立3D视口中启用")
	_check(lab.body_mesh.material_override.get_shader_parameter("fire_position")==fire.global_position+Vector3(0,.75,0),"受光位置使用共同世界坐标")
	_check(is_equal_approx(lab.body_mesh.material_override.get_shader_parameter("fire_energy"),1.0),"平涂材质接收局部火光")
	_check(lab.style.solid_material("slab_light") is ShaderMaterial,"地面色块也使用同一受光方式")
	var mesh_id: int = lab.body_mesh.mesh.get_instance_id()
	fire.update_at(.3)
	var pulse_before: float = fire.pulse
	fire.update_at(.8)
	_check(not is_equal_approx(pulse_before,fire.pulse) and absf(fire.pulse-1.0)<.11,"火焰与照明使用有界同步跳动")
	_check(is_equal_approx(fire._paints[0].get_shader_parameter("clock"),.8),"火焰形状动画时钟更新")
	_check(GameState.rng.state==rng_before,"火焰动画不消耗玩法随机数")
	_check(lab.body_mesh.mesh.get_instance_id()==mesh_id,"火光变化不重建箱体")
	lab._pickers["fire_light"].color_changed.emit(Color("ffb15e"))
	_check(lab.body_mesh.material_override.get_shader_parameter("fire_color")==Color("ffb15e"),"拾色器实时修改环境受光颜色")
	lab._fire_energy_slider.value = .6
	_check(is_equal_approx(lab.body_mesh.material_override.get_shader_parameter("fire_energy"),.6),"照明强度可调整")
	lab._fire_radius_slider.value = 1.8
	_check(is_equal_approx(lab.body_mesh.material_override.get_shader_parameter("fire_radius"),1.8),"受光范围可调整")
	var path := "user://fire_lab_test_palette.tres"
	_check(ResourceSaver.save(lab.palette,path)==OK,"火光配色可保存")
	var restored: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
	_check(restored.fire_light==Color("ffb15e") and is_equal_approx(restored.fire_energy,.6),"火光配色与强度可重载")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	lab.set_preset(0)
	fire.update_at(0.0)
	await _frames()
	await _shot("01-fire-lit-1280.png")
	var lit := Color.BLACK
	if _capture: lit = _sample(lab,Vector3(1.2,.25,1.81))
	var fire_position: Vector3 = lab.body_mesh.material_override.get_shader_parameter("fire_position")
	lab.pan_by(Vector2(30,10))
	_check(lab.body_mesh.material_override.get_shader_parameter("fire_position")==fire_position,"拖动镜头不改变世界中的光源位置")
	lab.reset_camera()
	lab.fire_toggle.button_pressed = false
	_check(not fire.flame_root.visible and is_zero_approx(fire.light.light_energy),"熄火同步关闭火焰与普通材质点光源")
	_check(is_zero_approx(lab.body_mesh.material_override.get_shader_parameter("fire_energy")),"熄火恢复平涂原色")
	_check(not lab.environment.glow_enabled,"熄火关闭柔光")
	await _frames()
	await _shot("02-fire-off-1280.png")
	if _capture:
		var unlit := _sample(lab,Vector3(1.2,.25,1.81))
		_check(lit.r>unlit.r+.04,"实机箱体表面确实收到暖光")
	lab.fire_toggle.button_pressed = true
	lab.glow_toggle.button_pressed = false
	_check(not lab.environment.glow_enabled and lab.body_mesh.material_override.get_shader_parameter("fire_energy")>0.0,"柔光与环境受光可以独立切换")
	await _frames()
	await _shot("03-without-bloom-1280.png")
	lab.glow_toggle.button_pressed = true
	var vertices: PackedVector3Array = lab._cast_shadow.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var clipped := true
	for vertex in vertices:
		var point: Vector3 = lab._cast_shadow.to_global(vertex)
		clipped = clipped and point.x>=-.001 and point.x<=3.001 and point.z>=-.001 and point.z<=3.001
	_check(clipped,"火光投影限定在地面范围内")
	lab.preset_select.select(1)
	lab.preset_select.item_selected.emit(1)
	await _frames()
	await _shot("04-fire-ash-1280.png")
	if _record:
		lab.preset_select.select(0)
		lab.set_preset(0)
		lab.flicker_toggle.button_pressed = true
		fire.set_process(false)
		var frames := OS.get_environment("TEMP").path_join("huozi-fire-study-frames")
		DirAccess.make_dir_recursive_absolute(frames)
		for frame in 120:
			lab.fire_toggle.button_pressed = not (frame>=50 and frame<70)
			fire.update_at(frame/20.0)
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png(frames.path_join("%04d.png" % frame))
			if result!=OK: _check(false,"保存火光演示帧失败"); break
		print("[FireStyleLab] frames: " + frames)
	get_window().size = Vector2i(1920,1080)
	lab.preset_select.select(0)
	lab.set_preset(0)
	await _frames(8)
	await _shot("05-fire-1920.png")
	lab.queue_free()
	await _frames()
	print("[FireStyleLab] PASS %d / FAIL %d" % [_pass,_fail])
	get_tree().quit(0 if _fail==0 else 1)
