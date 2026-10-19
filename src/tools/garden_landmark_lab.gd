extends "res://src/tools/expedition_garden_lab.gd"
## New ornaments beside the current native garden assets, at the actual world scale.
const KIT = preload("res://src/map/garden_landmark_kit.gd")
const POND = preload("res://src/map/expedition_pond_shape_tile.gd")
const WALKER = preload("res://src/map/expedition_lantern_traveler.gd")
const LOTUS = preload("res://src/map/expedition_lotus_tile.gd")
const NAMES := ["四柱方亭 · 坐槛／回纹梁枋","六角凉亭 · 攒尖瓦顶／石桌凳","低矮假山 · 偏峰／前低后高","洞石假山 · 立峰／真实穿洞","二层小阁 · 双层挑檐／窗格／阳台","园林组合 · 同一光照与实际比例"]
var roof_toggle: CheckButton
var ground_material: ShaderMaterial
var landmarks: Array[Node3D] = []
var output := "res://docs/art-concepts/2026-10-18-garden-landmarks"


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--capture"): _capture.call_deferred()


func _build_view() -> void:
	super._build_view()
	environment.background_color = palette.background
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("345358")
	environment.ambient_light_energy = .20
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	var lights := world.find_children("*","DirectionalLight3D",false,false)
	for i in lights.size():
		lights[i].light_color = [Color("fff1d9"),Color("83a1b4"),Color("c6b18e")][i]
		lights[i].light_energy = [.82,.18,.06][i]
	ground_material = POND.ground_material(Vector2.ZERO)
	annotation.set_script(load("res://src/tools/garden_landmark_overlay.gd"))
	annotation.set("lab",self)


func _build_controls() -> void:
	super._build_controls()
	mode.clear()
	for text in NAMES: mode.add_item(text)
	grid_toggle.text = "落脚与占地"
	var column: VBoxContainer = chrome.get_child(1).get_child(0)
	(column.get_child(1) as Label).text = "原生园林资产 · 同一色板与光照 · 左键转看／中键拖看／滚轮缩放 · 本页为独立样板"
	roof_toggle = CheckButton.new()
	roof_toggle.text = "屋顶透视"
	roof_toggle.toggled.connect(func(value: bool):
		for landmark in landmarks: landmark.set_roofs_faded(value))
	(column.get_child(0) as HBoxContainer).add_child(roof_toggle)


func set_mode(index: int) -> void:
	current_mode = index; mode.select(index); title.text = NAMES[index]
	style.reset_geometry_tracking()
	for list in [assets,assemblies,trees,labels,landmarks]: list.clear()
	if contents!=null:
		world.remove_child(contents); contents.queue_free()
	contents = Node3D.new(); world.add_child(contents)
	_water_context()
	if index<5:
		_floor(Rect2(-2.15,-2.0,5.35,4.40))
		_landmark(index,Vector3.ZERO)
		_traveler(Vector3(2.32,0,.87))
		_look = Vector3(.25,[.92,1.02,.52,.85,1.47][index],.05)
		_height = [4.75,4.90,3.45,4.10,6.05][index]
	else:
		_composition()
		_look = Vector3(.2,.85,0)
		_height = 10.6
	_yaw = 23; _pitch = 36
	if roof_toggle!=null: roof_toggle.disabled = index in [2,3]
	_apply_camera()
	for asset in assets: asset.set_lamps_enabled(warm_toggle.button_pressed)


func _landmark(kind: int, at: Vector3, turn := 0.0) -> Node3D:
	var item := KIT.new()
	item.kind = kind
	item.position = at
	item.rotation.y = turn
	contents.add_child(item)
	item.setup(style)
	item.set_roofs_faded(roof_toggle!=null and roof_toggle.button_pressed)
	assets.append(item); landmarks.append(item)
	return item


func _traveler(at: Vector3) -> void:
	var walker := WALKER.new()
	walker.scale = Vector3.ONE*.25
	walker.position = at
	walker.rotation_degrees.y = -15
	contents.add_child(walker); walker.setup(style)
	assets.append(walker)


func _floor(rect: Rect2) -> void:
	var plane := PlaneMesh.new(); plane.size = rect.size
	var floor_mesh := MeshInstance3D.new(); floor_mesh.mesh = plane
	floor_mesh.material_override = ground_material
	floor_mesh.position = Vector3(rect.get_center().x,-.006,rect.get_center().y)
	contents.add_child(floor_mesh)
	style.mesh(contents,TypeMeshes.beveled_box(Vector3(rect.size.x,.40,rect.size.y),.009),Vector3(rect.get_center().x,-.212,rect.get_center().y),"architecture",.7)


func _water_context() -> void:
	var plane := PlaneMesh.new(); plane.size = Vector2.ONE*200
	var water := MeshInstance3D.new(); water.mesh = plane
	water.position.y = -.45
	var paint := ShaderMaterial.new(); paint.shader = preload("res://src/shaders/expedition_water.gdshader")
	paint.set_shader_parameter("fog_mask",_white())
	paint.set_shader_parameter("water_tint",Color("102b32"))
	water.material_override = paint; contents.add_child(water)


func _composition() -> void:
	_floor(Rect2(-6.5,-4.5,13,9))
	_landmark(KIT.Kind.SMALL_LOFT,Vector3(-3.25,0,-1.80))
	_landmark(KIT.Kind.SQUARE_PAVILION,Vector3(.85,0,-1.80))
	_landmark(KIT.Kind.HEX_PAVILION,Vector3(4.50,0,0))
	_landmark(KIT.Kind.LOW_ROCKERY,Vector3(-2.85,0,1.80))
	_landmark(KIT.Kind.HOLLOW_ROCKERY,Vector3(1.0,0,2.05))
	_traveler(Vector3(-.25,0,3.45))
	var wall_holder := Node3D.new(); wall_holder.scale = Vector3.ONE*.5
	contents.add_child(wall_holder)
	var wall := BOUNDARY.assemble(wall_holder,style,[Vector3(-13,0,9),Vector3(-13,0,-9),Vector3(13,0,-9)],true,false,true)
	assemblies.append(wall)
	for part in wall.get_children(): assets.append(part)
	for at in [Vector3(4.4,0,5.0),Vector3(-4.5,0,5.05)]:
		var lotus := LOTUS.new(); lotus.plants_only = true; lotus.plant = LOTUS.Plant.BLOOM
		lotus.water_height = -.90; lotus.scale = Vector3.ONE*.5; lotus.position = at
		contents.add_child(lotus); lotus.setup(style); assets.append(lotus)


func _apply_camera() -> void:
	if camera==null: return
	var distance := _height/(2*tan(deg_to_rad(camera.fov*.5)))
	var pitch := deg_to_rad(_pitch); var yaw := deg_to_rad(_yaw)
	camera.position = _look+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(_look,Vector3.UP)
	style.refresh_outlines()
	annotation.queue_redraw()


func _capture() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1600,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await _frames(15)
	for index in 6:
		set_mode(index); await _frames(8); await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output.path_join("%02d-%s.png" % [index+1,["square","hex","low-rockery","hollow-rockery","loft","composition"][index]]))
		print("[GardenLandmarks] ",NAMES[index]," roots=",landmarks.size())
	set_mode(4); roof_toggle.button_pressed = true
	await _frames(8); await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("07-loft-roofs-faded.png"))
	roof_toggle.button_pressed = false; _pitch = 52; _apply_camera()
	await _frames(8); await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("08-loft-map-angle.png"))
	grid_toggle.button_pressed = true
	await _frames(4); await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("09-footprints.png"))
	print("[GardenLandmarks] Five native assets, one garden assembly, roof fade and map-angle previews complete")
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame
