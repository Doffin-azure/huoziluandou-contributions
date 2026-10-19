extends Control
## Independent garden production workbench. It never creates an Expedition.
const ARCH = preload("res://src/map/expedition_garden_architecture.gd")
const BOUNDARY = preload("res://src/map/expedition_garden_boundary.gd")
const TREE = preload("res://src/map/expedition_stylized_tree.gd")
const TITLES := ["冥府园林 · 合院组合","月洞门","碑纹照壁","双间游廊","平拱石桥","栏杆模块 · 直段／半段／立柱／端头／残损／转角","围墙模块 · 实墙／漏窗／立柱／端头／残墙／转角","拼接检查 · 闭合回折／围墙内外角／半段补齐"]
var palette: ExpeditionFlatPalette
var style: ExpeditionFlatStyle
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var contents: Node3D
var chrome: Control
var title: Label
var mode: OptionButton
var warm_toggle: CheckButton
var grid_toggle: CheckButton
var annotation: Control
var environment: Environment
var assets: Array[Node3D] = []
var assemblies: Array[Node3D] = []
var trees: Array[Node3D] = []
var labels: Array = []
var current_mode := 0
var _look := Vector3.ZERO
var _height := 5.3
var _yaw := 15.0
var _pitch := 42.0
var _dragging := false
var _panning := false


func _ready() -> void:
	palette = preload("res://assets/expedition/palettes/mochi_night.tres").duplicate(true)
	palette.outline_pixels = 1.8
	style = ExpeditionFlatStyle.new(palette)
	style.set_scene_lighting(true)
	theme = Ink.theme.duplicate()
	for type in ["Label","Heading"]:
		theme.set_color("font_color",type,Color("c8c2b1"))
	for color in ["font_color","font_hover_color","font_pressed_color"]:
		theme.set_color(color,"CheckButton",Color("363c39"))
	theme.set_color("font_color","Muted",Color("969d99"))
	_build_view()
	_build_controls()
	set_mode(0)
	resized.connect(_resize)
	_resize.call_deferred()


func _exit_tree() -> void:
	if style!=null: style.dispose()


func _build_view() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	world = Node3D.new()
	viewport.add_child(world)
	var settings := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b1015")
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = preload("res://assets/expedition/sky/mochi_night.svg")
	var sky := Sky.new()
	sky.sky_material = panorama
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = .11
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = .20
	environment.glow_hdr_threshold = 1.2
	settings.environment = environment
	world.add_child(settings)
	for entry in [[Color("dad5cc"),1.10,Vector3(-48,-32,0),true],[Color("a291bd"),.23,Vector3(-25,145,0),false],[Color("b5bfc4"),.12,Vector3(-22,25,0),false]]:
		var light := DirectionalLight3D.new()
		light.light_color = entry[0]
		light.light_energy = entry[1]
		light.rotation_degrees = entry[2]
		light.shadow_enabled = entry[3]
		light.directional_shadow_max_distance = 45
		light.shadow_bias = .03
		light.shadow_normal_bias = .65
		world.add_child(light)
	camera = Camera3D.new()
	camera.fov = 25
	camera.near = .05
	camera.far = 100
	camera.current = true
	world.add_child(camera)
	style.camera = camera
	annotation = Control.new()
	annotation.set_script(load("res://src/tools/expedition_garden_overlay.gd"))
	annotation.set("lab",self)
	annotation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	annotation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(annotation)


func _build_controls() -> void:
	chrome = Control.new()
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chrome)
	title = Ink.h2(TITLES[0])
	title.position = Vector2(24,18)
	title.add_theme_color_override("font_color",Color("c8c2b1"))
	chrome.add_child(title)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(20,-90)
	var paint := StyleBoxFlat.new()
	paint.bg_color = Color(.04,.055,.06,.94)
	paint.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel",paint)
	chrome.add_child(panel)
	var col := Ink.vbox(6)
	panel.add_child(col)
	var row := Ink.hbox(12)
	col.add_child(row)
	mode = OptionButton.new()
	for text in TITLES: mode.add_item(text)
	mode.item_selected.connect(set_mode)
	row.add_child(mode)
	warm_toggle = CheckButton.new()
	warm_toggle.text = "灯笼暖光"
	warm_toggle.set_pressed_no_signal(true)
	warm_toggle.toggled.connect(func(value: bool):
		for asset in assets: asset.set_lamps_enabled(value))
	row.add_child(warm_toggle)
	grid_toggle = CheckButton.new()
	grid_toggle.text = "拼接锚点"
	grid_toggle.toggled.connect(func(_value: bool): annotation.queue_redraw())
	row.add_child(grid_toggle)
	for entry in [["石材","stone_front"],["屋面","roof"],["铜绿","patina"]]:
		row.add_child(Ink.label(entry[0]))
		var picker := ColorPickerButton.new()
		picker.color = palette.get(entry[1])
		picker.custom_minimum_size = Vector2(28,26)
		var property: String = entry[1]
		picker.color_changed.connect(func(value: Color): palette.set(property,value))
		row.add_child(picker)
	col.add_child(Ink.caption("左键转看 · 中键拖看 · 滚轮缩放 · 独立模型预览／运行地图使用生成布局"))


func set_mode(index: int) -> void:
	current_mode = index
	mode.select(index)
	title.text = TITLES[index]
	style.reset_geometry_tracking()
	assets.clear()
	assemblies.clear()
	trees.clear()
	labels.clear()
	if contents!=null:
		world.remove_child(contents)
		contents.queue_free()
	contents = Node3D.new()
	contents.name = "GardenStudyOnly"
	world.add_child(contents)
	_yaw = 15
	_pitch = 42
	_look = Vector3(0,.30,0)
	_height = 5.4
	if index==0:
		_courtyard()
		_height = 6.5
		_look = Vector3(0,.20,.10)
	elif index<=4:
		_building(index-1,Vector3.ZERO)
		_height = [2.45,2.35,2.2,2.25][index-1]
		_look = Vector3(0,.57 if index<4 else .08,0)
		if index==3: _pitch = 30
		if index==4:
			_ground(Rect2(-3,-2,6,4),-.48)
			_water(Rect2(-.65,-2,1.3,4))
		else: _ground(Rect2(-3,-2,6,4))
	elif index in [5,6]:
		_module_sheet(index==6)
		_height = 5.3
		_look = Vector3(.15,.28,.25)
		_yaw = 5
	else:
		_join_study()
		_height = 5.6
		_look = Vector3(0,.15,0)
	_apply_camera()
	for asset in assets: asset.set_lamps_enabled(warm_toggle.button_pressed)


func _building(kind: int, at: Vector3, turn := 0.0) -> Node3D:
	var asset := ARCH.new()
	asset.building = kind
	asset.position = at
	asset.rotation.y = turn
	asset.scale = Vector3.ONE*.5
	contents.add_child(asset)
	asset.setup(style)
	assets.append(asset)
	return asset


func _piece(kind: int, parent: Node3D, at := Vector3.ZERO, turn := 0.0) -> Node3D:
	var asset := BOUNDARY.new()
	asset.piece = kind
	asset.position = at
	asset.rotation.y = turn
	parent.add_child(asset)
	asset.setup(style)
	assets.append(asset)
	return asset


func _path(points: Array[Vector3], wall := false, closed := false, windows := false) -> Node3D:
	var group := Node3D.new()
	group.scale = Vector3.ONE*.5
	contents.add_child(group)
	var production_points: Array[Vector3] = []
	for point in points: production_points.append(point*2)
	var result := BOUNDARY.assemble(group,style,production_points,wall,closed,windows)
	assemblies.append(result)
	return result


func _ground(rect: Rect2, y := 0.0) -> void:
	var shape := PlaneMesh.new()
	shape.size = rect.size
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = Vector3(rect.get_center().x,y,rect.get_center().y)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://src/shaders/expedition_ground.gdshader")
	paint.set_shader_parameter("fog_mask",_white())
	paint.set_shader_parameter("land_mask",_white())
	mesh.material_override = paint
	contents.add_child(mesh)
	var foundation := MeshInstance3D.new()
	foundation.mesh = TypeMeshes.beveled_box(Vector3(rect.size.x,.32,rect.size.y),.012)
	foundation.position = mesh.position-Vector3.UP*.162
	foundation.material_override = style.face_material("architecture")
	contents.add_child(foundation)


func _white() -> Texture2D:
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _water(rect: Rect2) -> void:
	var plane := PlaneMesh.new()
	plane.size = rect.size
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.position = Vector3(rect.get_center().x,-.25,rect.get_center().y)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://src/shaders/expedition_water.gdshader")
	paint.set_shader_parameter("fog_mask",_white())
	water.material_override = paint
	contents.add_child(water)


func _courtyard() -> void:
	_ground(Rect2(-4,-3.5,8,4.2))
	_ground(Rect2(-4,.7,3.28,2.8))
	_ground(Rect2(.72,.7,3.28,2.8))
	_water(Rect2(-.72,.7,1.44,2.8))
	_building(ARCH.Building.MOON_GATE,Vector3(0,0,-2.5))
	_building(ARCH.Building.SCREEN_WALL,Vector3(-1.65,0,-.50),-.09)
	_building(ARCH.Building.COVERED_WALK,Vector3(1.48,0,-.35),0)
	_building(ARCH.Building.STONE_BRIDGE,Vector3(0,0,1.72))
	_path([Vector3(-1,0,-2.5),Vector3(-3,0,-2.5),Vector3(-3,0,.5)],true,false,true)
	_path([Vector3(1,0,-2.5),Vector3(3,0,-2.5),Vector3(3,0,.5)],true,false,true)
	_path([Vector3(-2.5,0,.5),Vector3(-2.5,0,2.5),Vector3(-1.5,0,2.5)])
	_path([Vector3(2.5,0,.5),Vector3(2.5,0,2.5),Vector3(1.5,0,2.5)])
	for placement in [Vector3(-3.65,0,-1.25),Vector3(3.7,0,-1.5)]:
		var tree := TREE.new()
		tree.position = placement
		contents.add_child(tree)
		tree.setup(style,camera)
		tree.scale = Vector3.ONE*.85
		trees.append(tree)


func _module_sheet(wall: bool) -> void:
	_ground(Rect2(-4.9,-3.4,9.8,7.2))
	var kinds := [6,7,8,9,10,11] if wall else [0,1,2,3,4,5]
	var captions := ["实墙直段","八角漏窗","共享墙柱","收口端柱","残损墙体","直角转接"] if wall else ["栏杆直段","半段补齐","共享立柱","收口端柱","残损栏杆","直角转接"]
	for i in kinds.size():
		var root := Node3D.new()
		root.position = Vector3(-2.5+(i%3)*2.3,0,-1.25+(i/3)*2.2)
		root.scale = Vector3.ONE*.5
		contents.add_child(root)
		var offset := Vector3(-.7,0,0) if i in [0,1,4] else Vector3.ZERO
		_piece(kinds[i],root,offset)
		if i in [0,1,4]:
			_piece(BOUNDARY.Piece.WALL_POST if wall else BOUNDARY.Piece.RAIL_POST,root,offset)
			_piece(BOUNDARY.Piece.WALL_POST if wall else BOUNDARY.Piece.RAIL_POST,root,offset+Vector3(1 if kinds[i]==BOUNDARY.Piece.HALF_RAIL else 2,0,0))
		elif i==5:
			for endpoint in [Vector3(2,0,0),Vector3(0,0,2)]: _piece(BOUNDARY.Piece.WALL_END if wall else BOUNDARY.Piece.RAIL_END,root,endpoint)
		labels.append([root.position+Vector3(.2,1.25 if wall else .72,.15),captions[i],-14])


func _join_study() -> void:
	_ground(Rect2(-5,-3.8,10,7.6))
	_path([Vector3(-4,0,-2.5),Vector3(-1.5,0,-2.5),Vector3(-1.5,0,-.5),Vector3(-2.5,0,-.5),Vector3(-2.5,0,-1.5),Vector3(-4,0,-1.5)],false,true)
	_path([Vector3(.5,0,-2.5),Vector3(3.5,0,-2.5),Vector3(3.5,0,-.5),Vector3(2.5,0,-.5),Vector3(2.5,0,-1.5),Vector3(.5,0,-1.5)],true,true,true)
	_path([Vector3(-3.5,0,1.0),Vector3(-1.0,0,1.0),Vector3(-1.0,0,2.0)])
	_path([Vector3(.5,0,1.0),Vector3(3.5,0,1.0)],true,false,true)
	labels = [[Vector3(-2.7,0,.1),"栏杆闭合 · 半段＋内外转角"],[Vector3(2,0,.1),"围墙闭合 · 共享角柱"],[Vector3(-2.3,0,2.65),"开口端头 · 半段补齐"],[Vector3(2,0,2.05),"实墙与漏窗交替"]]


func _resize() -> void:
	if viewport==null: return
	viewport.size = Vector2i(maxi(32,int(size.x)),maxi(32,int(size.y)))
	_apply_camera()


func _apply_camera() -> void:
	var distance := _height/(2*tan(deg_to_rad(camera.fov*.5)))
	var pitch := deg_to_rad(_pitch)
	var yaw := deg_to_rad(_yaw)
	camera.position = _look+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(_look,Vector3.UP)
	for tree in trees: tree.sync_camera(); tree.scale = Vector3.ONE*.85
	style.refresh_outlines()
	annotation.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: _dragging = event.pressed
		elif event.button_index==MOUSE_BUTTON_MIDDLE: _panning = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_height = clampf(_height*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),1,12)
			_apply_camera()
	elif event is InputEventMouseMotion:
		if _dragging:
			_yaw -= event.relative.x*.35
			_pitch = clampf(_pitch+event.relative.y*.2,20,70)
		elif _panning:
			_look -= camera.global_basis.x*event.relative.x*_height/size.y
			_look += Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()*event.relative.y*_height/size.y
		else: return
		_apply_camera()
