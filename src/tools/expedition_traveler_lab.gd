extends "res://src/tools/expedition_garden_lab.gd"
## Independent character review. No replacement of the current map player.
const TRAVELER = preload("res://src/map/expedition_lantern_traveler.gd")
const TRAVELER_PALETTE = preload("res://assets/expedition/characters/lantern_traveler_palette.tres")
const VIEWS := ["持灯行者 · 三面样模","持灯行者 · 体积与轮廓","持灯行者 · 地图比例","持灯行者 · 夜色与提灯"]
var costume: Resource
var characters: Array[Node3D] = []
var idle_toggle: CheckButton


func _ready() -> void:
	costume = TRAVELER_PALETTE.duplicate(true)
	super._ready()


func _build_controls() -> void:
	chrome = Control.new()
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chrome)
	title = Ink.h2(VIEWS[0])
	title.position = Vector2(24,18)
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
	for caption in VIEWS: mode.add_item(caption)
	mode.item_selected.connect(set_mode)
	row.add_child(mode)
	warm_toggle = CheckButton.new()
	warm_toggle.text = "提灯光"
	warm_toggle.set_pressed_no_signal(true)
	warm_toggle.toggled.connect(func(value: bool):
		for character in characters: character.set_lamps_enabled(value))
	row.add_child(warm_toggle)
	idle_toggle = CheckButton.new()
	idle_toggle.text = "待机"
	idle_toggle.toggled.connect(func(value: bool):
		for character in characters: character.idle_enabled = value)
	row.add_child(idle_toggle)
	grid_toggle = CheckButton.new()
	grid_toggle.visible = false
	row.add_child(grid_toggle)
	for entry in [["衣色","coat"],["朱砂","scarf"],["旧金","gold"]]:
		row.add_child(Ink.label(entry[0]))
		var picker := ColorPickerButton.new()
		picker.color = costume.get(entry[1])
		picker.custom_minimum_size = Vector2(28,26)
		var property: String = entry[1]
		picker.color_changed.connect(func(value: Color): costume.set(property,value))
		row.add_child(picker)
	col.add_child(Ink.caption("左键转看 · 中键拖看 · 滚轮缩放 · 原生低模／可改色／受真实光照 · 独立样模"))


func set_mode(index: int) -> void:
	current_mode = index
	mode.select(index)
	title.text = VIEWS[index]
	style.reset_geometry_tracking()
	characters.clear()
	assets.clear()
	assemblies.clear()
	trees.clear()
	labels.clear()
	if contents!=null:
		world.remove_child(contents)
		contents.queue_free()
	contents = Node3D.new()
	contents.name = "TravelerStudyOnly"
	world.add_child(contents)
	_yaw = 15
	_pitch = 20
	_look = Vector3(0,.78,0)
	_height = 2.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	environment.ambient_light_energy = .11
	for child in world.get_children():
		if child is DirectionalLight3D and child.shadow_enabled: child.light_energy = 1.10
	if index==0:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_height = 2.4
		_yaw = 0
		_pitch = 4
		_look.y = .74
		for i in 3:
			_character(Vector3((i-1)*1.42,0,0),[0.0,90.0,180.0][i])
			labels.append([Vector3((i-1)*1.42,-.12,.05),["正面","侧面","背面"][i],0])
		_studio_ground()
	elif index==1:
		_character(Vector3.ZERO,-8)
		_yaw = 23
		_pitch = 15
		_height = 1.83
		_studio_ground()
	else:
		_ground(Rect2(-3.5,-3,7,6))
		_building(ARCH.Building.MOON_GATE,Vector3(0,0,-1.65))
		_building(ARCH.Building.SCREEN_WALL,Vector3(-1.6,0,-.35),.2)
		_path([Vector3(1.3,0,-1.6),Vector3(2.3,0,-1.6),Vector3(2.3,0,1.4)])
		_character(Vector3(.0,0,.35),-15)
		var tomb := preload("res://src/map/expedition_tombstone.gd").new()
		tomb.position = Vector3(-1.3,0,.95)
		contents.add_child(tomb)
		tomb.setup(style)
		tomb.scale = Vector3.ONE*.5
		assets.append(tomb)
		_height = 3.9
		_pitch = 51
		_yaw = 15
		_look = Vector3(0,.17,0)
		if index==3:
			_height = 2.45
			_look = Vector3(-.10,.5,.28)
			environment.ambient_light_energy = .045
			for child in world.get_children():
				if child is DirectionalLight3D and child.shadow_enabled: child.light_energy = .30
	_apply_camera()


func _character(at: Vector3, turn: float) -> Node3D:
	var character := TRAVELER.new()
	character.costume_palette = costume
	character.position = at
	character.rotation_degrees.y = turn
	character.scale = Vector3.ONE*.43
	contents.add_child(character)
	character.setup(style)
	character.set_lamps_enabled(warm_toggle.button_pressed)
	character.idle_enabled = idle_toggle.button_pressed
	characters.append(character)
	return character


func _studio_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = plane
	floor_mesh.position.y = -.012
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("353d40")
	paint.roughness = 1
	floor_mesh.material_override = paint
	contents.add_child(floor_mesh)


func _apply_camera() -> void:
	if camera!=null and camera.projection==Camera3D.PROJECTION_ORTHOGONAL: camera.size = _height*1.06
	super._apply_camera()
