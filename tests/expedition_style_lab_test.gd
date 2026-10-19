extends Node
const LAB = preload("res://src/tools/expedition_style_lab.gd")
var _pass := 0
var _fail := 0
var _capture := false
var _out := ""


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-16-mochi/godot-flat-study")
	if _capture: DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(60).timeout.connect(func(): push_error("平涂样板检查超时"); get_tree().quit(1))
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
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"保存实机截图 " + name)


func _parallel(a: Vector2, b: Vector2) -> bool:
	return absf(a.cross(b)) / maxf(.00001,a.length()*b.length()) < .00001


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(15)
	_check(lab.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"默认相机与SVG小样使用平行投影")
	_check(lab.body_mesh.mesh is ArrayMesh and lab.lid_mesh.mesh is ArrayMesh,"箱体与箱盖为真实可复用3D网格")
	_check(lab.body_mesh.material_override.shader==ExpeditionFlatStyle.FACE_SHADER,"箱体使用统一面色着色器")
	var body_id := lab.body_mesh.mesh.get_instance_id()
	var hull: MeshInstance3D = lab.body_mesh.get_meta("flat_outline")
	_check(hull.mesh is ArrayMesh and hull.mesh.get_surface_count()>0 and hull.visible,"独立轮廓网格已生成")
	var camera := lab.camera
	var ground_x := camera.unproject_position(Vector3.RIGHT)-camera.unproject_position(Vector3.ZERO)
	var ground_z := camera.unproject_position(Vector3.BACK)-camera.unproject_position(Vector3.ZERO)
	for point in [Vector3(.56,0,.36),Vector3(1.55,0,1.52),Vector3(2.44,0,2.64)]:
		lab.chest.position = point
		var lid_x := camera.unproject_position(point+Vector3(.5,.485,.3))-camera.unproject_position(point+Vector3(-.5,.485,.3))
		var lid_z := camera.unproject_position(point+Vector3(.5,.485,.3))-camera.unproject_position(point+Vector3(.5,.485,-.3))
		_check(_parallel(ground_x,lid_x) and _parallel(ground_z,lid_z),"不同位置箱盖与地面两个方向始终平行")
	lab.reset_camera()
	var target := Vector3(.5,0,.5)
	var screen := lab.map_area.global_position + camera.unproject_position(target)
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = screen
		get_viewport().push_input(click)
	await _frames()
	_check(lab.chest.position.distance_to(Vector3(.56,0,.5))<.001,"实际视口左键命中地面并摆放字匣")
	lab._pickers["wood_top"].color_changed.emit(Color("9a785b"))
	_check(lab.palette.wood_top==Color("9a785b"),"原生拾色器修改配色资源")
	_check(lab.lid_mesh.material_override.get_shader_parameter("top_color")==Color("9a785b"),"调色即时更新材质")
	_check(lab.body_mesh.mesh.get_instance_id()==body_id,"调色保留已有几何")
	_check(LAB.DEFAULT_PALETTE.wood_top==Color("64836e"),"试调颜色不污染项目默认调色板")
	var saved := "user://flat_lab_test_palette.tres"
	_check(ResourceSaver.save(lab.palette,saved)==OK,"调色板可保存为Godot资源")
	var restored: Resource = ResourceLoader.load(saved,"",ResourceLoader.CACHE_MODE_IGNORE)
	_check(restored.wood_top==Color("9a785b"),"重载调色板保留颜色")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saved))
	lab.set_preset(0)
	lab.reset_camera()
	await _frames()
	await _shot("01-flat-chest-1280.png")
	lab.guide_toggle.button_pressed = true
	_check(lab.guides.visible,"原生对齐线开关生效")
	await _frames()
	await _shot("02-alignment-1280.png")
	lab.guide_toggle.button_pressed = false
	lab.style_toggle.button_pressed = false
	_check(lab.body_mesh.material_override is StandardMaterial3D and not hull.visible,"同一几何可以切换普通材质对照")
	await _frames()
	await _shot("03-ordinary-material-1280.png")
	lab.style_toggle.button_pressed = true
	lab.preset_select.select(1)
	lab.preset_select.item_selected.emit(1)
	_check(lab.palette.wood_top==LAB.ASH_PALETTE.wood_top,"配色预设切换")
	await _frames()
	await _shot("04-ash-palette-1280.png")
	lab.preset_select.select(0)
	lab.set_preset(0)
	lab.model_select.select(1)
	lab.model_select.item_selected.emit(1)
	_check(lab.gate.visible and not lab.chest.visible,"复用原地图闸门模型")
	var gate_mesh: MeshInstance3D = lab.gate.get_child(0)
	var gate_id := gate_mesh.mesh.get_instance_id()
	lab.style_toggle.button_pressed = false
	lab.style_toggle.button_pressed = true
	_check(gate_mesh.mesh.get_instance_id()==gate_id and gate_mesh.material_override is ShaderMaterial,"旧机关换画法时保持原模型")
	await _frames()
	await _shot("05-reused-gate-1280.png")
	lab.model_select.select(0)
	lab.show_model(0)
	lab.perspective_toggle.button_pressed = true
	await _frames()
	var foot_before := camera.unproject_position(Vector3(1.5,0,1.5))
	var top_before := camera.unproject_position(Vector3(1.5,.485,1.5))
	lab.pan_by(Vector2(50,0))
	var foot_delta := camera.unproject_position(Vector3(1.5,0,1.5))-foot_before
	var top_delta := camera.unproject_position(Vector3(1.5,.485,1.5))-top_before
	_check(camera.projection==Camera3D.PROJECTION_PERSPECTIVE and absf(foot_delta.x-top_delta.x)>.2,"轻透视拖看具有真实深度相对位移")
	lab.reset_camera()
	await _frames()
	await _shot("06-perspective-1280.png")
	lab.perspective_toggle.button_pressed = false
	get_window().size = Vector2i(1920,1080)
	await _frames(8)
	_check(lab.viewport.size.x==1920 and lab.map_area.size.y>700,"较大窗口正确调整地图视口")
	_check(is_equal_approx(hull.material_override.get_shader_parameter("width_pixels"),2.2),"缩放窗口保持描线像素宽度")
	await _shot("07-flat-chest-1920.png")
	lab.queue_free()
	await _frames()
	print("[FlatStyleLab] PASS %d / FAIL %d" % [_pass,_fail])
	get_tree().quit(0 if _fail==0 else 1)
