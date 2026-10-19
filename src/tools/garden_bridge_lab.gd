extends "res://src/tools/expedition_garden_lab.gd"
## Native bridge production workbench, sharing the same kits as the runtime network.
const KIT = preload("res://src/map/garden_bridge_kit.gd")
const PLAN = preload("res://src/expedition/garden_bridge_plan.gd")
const POND = preload("res://src/map/expedition_pond_shape_tile.gd")
const WALKER = preload("res://src/map/expedition_lantern_traveler.gd")
const NAMES := ["石拱桥 · 分券拱石／起伏桥面","廊桥 · 通长瓦顶／梁架／花格","石柱桥 · 六棱石墩／托梁／栏柱","连廊 · 侧坐槛／长檐／开敞花格"]
const KINDS := ["arch","covered","pier","gallery"]
const LENGTHS := [6.0,8.0,6.0,7.0]
var roof_toggle: CheckButton
var kit: Node3D
var ground_material: ShaderMaterial
var output := "res://docs/art-concepts/2026-10-17-bridge-kit"


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--capture"): _capture.call_deferred()


func _build_view() -> void:
	super._build_view()
	environment.background_color = palette.background
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("345358"); environment.ambient_light_energy = .20
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR; environment.tonemap_exposure = 1
	var lights := world.find_children("*","DirectionalLight3D",false,false)
	for i in lights.size():
		lights[i].light_color = [Color("fff1d9"),Color("83a1b4"),Color("c6b18e")][i]
		lights[i].light_energy = [.82,.18,.06][i]
	camera.fov = 30
	ground_material = POND.ground_material(Vector2.ZERO)


func _build_controls() -> void:
	super._build_controls()
	mode.clear()
	for text in NAMES: mode.add_item(text)
	grid_toggle.text = "接点／通行净宽"
	var column: VBoxContainer = chrome.get_child(1).get_child(0)
	(column.get_child(1) as Label).text = "运行地图共用资产 · 左键转看／中键拖看／滚轮缩放 · 表面与行者使用同一桥面高度"
	roof_toggle = CheckButton.new(); roof_toggle.text = "屋顶剖透"
	roof_toggle.toggled.connect(func(value): kit.set_roof_faded(value))
	(column.get_child(0) as HBoxContainer).add_child(roof_toggle)


func set_mode(index: int) -> void:
	current_mode = index; mode.select(index); title.text = NAMES[index]
	style.reset_geometry_tracking()
	assets.clear(); assemblies.clear(); trees.clear(); labels.clear()
	if contents!=null: world.remove_child(contents); contents.queue_free()
	contents = Node3D.new(); world.add_child(contents)
	var length: float = LENGTHS[index]
	_water(Rect2(-length*.5-3,-3.6,length+6,7.2))
	for side in [-1.0,1.0]:
		var x: float = side*(length*.5+1.0)
		var floor := MeshInstance3D.new(); var shape := PlaneMesh.new(); shape.size = Vector2(2,2.7)
		floor.mesh = shape; floor.material_override = ground_material; floor.position = Vector3(x,0,0); contents.add_child(floor)
		style.mesh(contents,TypeMeshes.beveled_box(Vector3(2,.74,2.7),.008),Vector3(x,-.376,0),"architecture",.65)
	kit = KIT.new(); kit.kind = KINDS[index]; kit.span_length = length; kit.ground_material = ground_material
	kit.position = Vector3(-length*.5,0,0); contents.add_child(kit); kit.setup(style); assets.append(kit)
	kit.set_roof_faded(roof_toggle!=null and roof_toggle.button_pressed)
	var walker := WALKER.new(); walker.scale = Vector3.ONE*.25
	walker.position = Vector3(-.5,PLAN.elevation(KINDS[index],length*.5-.5,length),.03)
	walker.rotation_degrees.y = -30; contents.add_child(walker); walker.setup(style); assets.append(walker)
	_look = Vector3(0,.43,0); _height = [5.3,6.4,5.3,6.0][index]
	_yaw = 9; _pitch = 33
	roof_toggle.disabled = index not in [1,3]
	_apply_camera()
	for asset in assets: asset.set_lamps_enabled(warm_toggle.button_pressed)


func _water(rect: Rect2) -> void:
	var surface := MeshInstance3D.new(); var shape := PlaneMesh.new(); shape.size = rect.size
	surface.mesh = shape; surface.position = Vector3(rect.get_center().x,PLAN.WATER_Y,rect.get_center().y)
	var paint := ShaderMaterial.new(); paint.shader = preload("res://src/shaders/expedition_water.gdshader")
	var white := Image.create(1,1,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE)
	paint.set_shader_parameter("fog_mask",ImageTexture.create_from_image(white)); paint.set_shader_parameter("water_tint",Color("102b32"))
	surface.material_override = paint; contents.add_child(surface)


func _apply_camera() -> void:
	if camera==null: return
	var distance := _height/(2*tan(deg_to_rad(camera.fov*.5)))
	var pitch := deg_to_rad(_pitch); var yaw := deg_to_rad(_yaw)
	camera.position = _look+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(_look,Vector3.UP); style.refresh_outlines()
	annotation.queue_redraw()


func _capture() -> void:
	get_window().size = Vector2i(1600,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await _frames(15)
	for index in KINDS.size():
		set_mode(index); await _frames(6); await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output.path_join("%02d-%s.png" % [index+1,KINDS[index]]))
	set_mode(1); roof_toggle.button_pressed = true; await _frames(6); await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("05-covered-cutaway.png"))
	print("[BridgeKit] Four native bridge/gallery samples and roof cutaway captured")
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame
