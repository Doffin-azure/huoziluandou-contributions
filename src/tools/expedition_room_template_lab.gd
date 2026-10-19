extends "res://src/tools/expedition_garden_lab.gd"
## The room workbench and live map instantiate the SAME production renderer.
const CATALOG = preload("res://src/expedition/room_template_catalog.gd")
const VISUAL = preload("res://src/map/garden_room_visual.gd")
const POND_TILE = preload("res://src/map/expedition_pond_shape_tile.gd")
const TRAVELER = preload("res://src/map/expedition_lantern_traveler.gd")
const SURVEY = preload("res://src/tools/garden_asset_bounds.gd")
var rooms: Array[Dictionary] = CATALOG.templates()
var room: Dictionary
var art: ExpeditionMapArt
var ground_paint: ShaderMaterial
var visual: Node3D
var walker: Node3D
var used_toggle: CheckButton
var alternate_toggle: CheckButton
var cutaway_toggle: CheckButton
var occupied: Array = []
var output := "res://docs/art-concepts/2026-10-17-refined-rooms"


func _ready() -> void:
	super._ready()
	if OS.get_cmdline_user_args().has("--capture"): _capture_rooms.call_deferred()


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
	ground_paint = POND_TILE.ground_material(Vector2.ZERO)
	annotation.set_script(load("res://src/tools/expedition_room_template_overlay.gd"))
	annotation.set("lab",self)


func _build_controls() -> void:
	super._build_controls()
	mode.clear()
	for sample in rooms: mode.add_item(sample.name)
	grid_toggle.text = "门位／通行带"
	var col: VBoxContainer = chrome.get_child(1).get_child(0)
	(col.get_child(1) as Label).text = "与随机地图共用房间渲染 · 完整墙院／开放水榭 · 左键转看／中键拖看／滚轮缩放"
	var row := Ink.hbox(14)
	col.add_child(row)
	used_toggle = CheckButton.new()
	used_toggle.text = "已清理／已使用"
	used_toggle.toggled.connect(_apply_room_state)
	row.add_child(used_toggle)
	alternate_toggle = CheckButton.new()
	alternate_toggle.text = "门位变体"
	alternate_toggle.toggled.connect(func(_on: bool): set_mode(current_mode))
	row.add_child(alternate_toggle)
	cutaway_toggle = CheckButton.new()
	cutaway_toggle.text = "局部遮挡透视"
	cutaway_toggle.toggled.connect(func(_on: bool): _apply_cutaway())
	row.add_child(cutaway_toggle)
	var top := Ink.button("俯视布置")
	top.pressed.connect(func(): _pitch = 78; _yaw = 0; grid_toggle.button_pressed = true; _apply_camera())
	row.add_child(top)
	var normal := Ink.button("恢复视角")
	normal.pressed.connect(func(): _pitch = 48; _yaw = 12; _apply_camera())
	row.add_child(normal)


func set_mode(index: int) -> void:
	current_mode = index
	mode.select(index)
	if alternate_toggle!=null:
		alternate_toggle.disabled = rooms[index].kind not in ["battle","treasure","rest","event"]
		if alternate_toggle.disabled: alternate_toggle.set_pressed_no_signal(false)
	room = CATALOG.with_variant(rooms[index],alternate_toggle!=null and alternate_toggle.button_pressed)
	CATALOG.apply_enclosure(room)
	room["route_id"] = room.id
	room["transform"] = Transform2D.IDENTITY
	title.text = "%02d  %s  ·  %d×%d" % [index+1,room.name,room.floor_size.x,room.floor_size.y]
	style.reset_geometry_tracking()
	for list in [assets,assemblies,trees,labels,occupied]: list.clear()
	if contents!=null:
		world.remove_child(contents)
		contents.queue_free()
	contents = Node3D.new()
	contents.name = str(room.id)
	world.add_child(contents)
	_water_context()
	visual = VISUAL.new()
	contents.add_child(visual)
	visual.build(room,style,camera,environment,ground_paint)
	art = visual.art
	assets.assign(visual.assets)
	assemblies.assign(visual.assemblies)
	trees.assign(visual.trees)
	occupied.assign(visual.occupied)
	walker = TRAVELER.new()
	walker.position = Vector3(room.stand.x,0,room.stand.y+.30)
	walker.scale = Vector3.ONE*.25
	walker.rotation_degrees.y = -20
	contents.add_child(walker)
	walker.setup(style)
	assets.append(walker)
	_look = Vector3(room.floor_size.x*.5,.50,room.floor_size.y*.5)
	_height = maxf(room.floor_size.y*.77+2.4,room.floor_size.x*.65)
	_yaw = 12
	_pitch = 48
	_apply_room_state(used_toggle!=null and used_toggle.button_pressed)
	_apply_camera()


func _water_context() -> void:
	var shape := PlaneMesh.new()
	shape.size = Vector2(room.floor_size)+Vector2.ONE*7
	var water := MeshInstance3D.new()
	water.mesh = shape
	water.position = Vector3(room.floor_size.x*.5,-.45,room.floor_size.y*.5)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://src/shaders/expedition_water.gdshader")
	paint.set_shader_parameter("fog_mask",_white())
	paint.set_shader_parameter("water_tint",Color("102b32"))
	water.material_override = paint
	contents.add_child(water)


func _apply_cutaway() -> void:
	if visual==null: return
	visual.update_occlusion(walker.global_position,camera,cutaway_toggle!=null and cutaway_toggle.button_pressed)
	style.refresh_outlines()


func _apply_room_state(used: bool) -> void:
	if visual!=null: visual.update_state(true,used,true)
	annotation.queue_redraw()


func _apply_camera() -> void:
	if camera==null: return
	var distance := _height/(2*tan(deg_to_rad(camera.fov*.5)))
	var pitch := deg_to_rad(_pitch)
	var yaw := deg_to_rad(_yaw)
	camera.position = _look+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(_look,Vector3.UP)
	if visual!=null:
		visual.sync_camera(camera)
		_apply_cutaway()
	style.refresh_outlines()
	annotation.queue_redraw()


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _capture_rooms() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1600,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await _frames(12)
	var catalog_json: Array = []
	for index in rooms.size():
		set_mode(index)
		await _frames(8)
		await RenderingServer.frame_post_draw
		var filename := "%02d-%s.png" % [index+1,room.kind]
		viewport.get_texture().get_image().save_png(output.path_join(filename))
		catalog_json.append(_json_ready(room))
		print("[RoomSample] ",filename," ",room.name," ",room.floor_size," ports=",room.ports.size())
	set_mode(3)
	alternate_toggle.button_pressed = true
	await _frames()
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("09-battle-four-doors.png"))
	grid_toggle.button_pressed = true
	_pitch = 78; _yaw = 0; _apply_camera()
	await _frames()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("10-ports-and-lanes.png"))
	alternate_toggle.button_pressed = false
	set_mode(6)
	used_toggle.button_pressed = true
	await _frames()
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("11-treasure-opened.png"))
	var file := FileAccess.open(output.path_join("room-templates.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog_json,"  "))
	print("[RoomSample] Finished eight authored rooms + one junction variant + doorway plan + used state.")
	get_tree().quit()


func _json_ready(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i: return [value.x,value.y]
	if value is Vector3: return [value.x,value.y,value.z]
	if value is Rect2: return [value.position.x,value.position.y,value.size.x,value.size.y]
	if value is Array: return value.map(_json_ready)
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = _json_ready(value[key])
		return result
	return value
