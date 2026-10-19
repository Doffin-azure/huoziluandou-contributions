extends "res://src/tools/expedition_garden_lab.gd"
## Isolated one-grid lotus tiles under the existing garden lighting.
const LOTUS = preload("res://src/map/expedition_lotus_tile.gd")
const POND_SHAPE = preload("res://src/map/expedition_pond_shape_tile.gd")
const LEAF_LAYER = preload("res://src/map/expedition_lotus_leaf_layer.gd")
const LOTUS_TITLES := ["莲池格子 · 连续3×3样板","五种格子变化","盛莲近看","荷叶近看","残荷近看","刻字踏石近看","岸线拼接 · 内外角／单格水道／孤池","与园林构件同屏","零散小莲叶 · 连续3×3","小叶变化 · 疏散／小丛／大小混生","小莲叶 · 不规则池岸"]
var lotus_palette: ExpeditionLotusPalette
var ponds: Array[Node3D] = []
var comparison_light: OmniLight3D
var layout_seed := 137
var seed_picker: SpinBox
var leaf_layers: Array[Node3D] = []


func _build_view() -> void:
	super._build_view()
	annotation.set_script(load("res://src/tools/expedition_lotus_overlay.gd"))
	annotation.set("lab",self)
	comparison_light = OmniLight3D.new()
	comparison_light.position = Vector3(-1.0,.8,1.0)
	comparison_light.light_color = Color("ffbd78")
	comparison_light.light_energy = .6
	comparison_light.omni_range = 2.4
	world.add_child(comparison_light)


func _build_controls() -> void:
	super._build_controls()
	lotus_palette = preload("res://assets/expedition/lotus/lotus_night.tres").duplicate(true)
	mode.clear()
	for text in LOTUS_TITLES: mode.add_item(text)
	warm_toggle.text = "暖光对照"
	warm_toggle.toggled.connect(func(value: bool): comparison_light.visible = value)
	warm_toggle.button_pressed = false
	grid_toggle.text = "格子边界"
	var col: VBoxContainer = chrome.get_child(1).get_child(0)
	var row := Ink.hbox(12)
	col.add_child(row)
	col.move_child(row,1)
	for entry in [["荷叶","leaf_light"],["莲瓣","petal_tip"],["水色","water_deep"]]:
		row.add_child(Ink.label(entry[0]))
		var picker := ColorPickerButton.new()
		picker.color = lotus_palette.get(entry[1])
		picker.custom_minimum_size = Vector2(32,24)
		var property: String = entry[1]
		picker.color_changed.connect(func(value: Color): lotus_palette.set(property,value))
		row.add_child(picker)
	row.add_child(Ink.label("布局种子"))
	seed_picker = SpinBox.new()
	seed_picker.min_value = 0
	seed_picker.max_value = 2000000000
	seed_picker.value = layout_seed
	seed_picker.custom_minimum_size = Vector2(110,24)
	seed_picker.get_line_edit().add_theme_color_override("font_color",Color("363c39"))
	seed_picker.get_line_edit().add_theme_color_override("caret_color",Color("363c39"))
	seed_picker.value_changed.connect(func(value: float):
		layout_seed = int(value)
		set_mode(current_mode))
	row.add_child(seed_picker)
	var shuffle := Button.new()
	shuffle.text = "换一组"
	shuffle.pressed.connect(func(): seed_picker.value = posmod(layout_seed+7919,2000000001))
	row.add_child(shuffle)
	(col.get_child(2) as Label).text = "左键转看 · 中键拖看 · 滚轮缩放 · 独立预览／运行地图按种子复用组件"
	chrome.get_child(1).position.y = -180


func set_mode(index: int) -> void:
	current_mode = index
	mode.select(index)
	title.text = LOTUS_TITLES[index]
	style.reset_geometry_tracking()
	assets.clear()
	assemblies.clear()
	trees.clear()
	ponds.clear()
	leaf_layers.clear()
	labels.clear()
	if contents!=null:
		world.remove_child(contents)
		contents.queue_free()
	contents = Node3D.new()
	world.add_child(contents)
	_yaw = 12
	_pitch = 45
	_look = Vector3(0,-.10,0)
	_height = 3.5
	if index in [0,7]:
		var cells: Dictionary = {}
		var variants := [1,2,1,3,5,3,1,4,1]
		for i in 9: cells[Vector2i(i%3-1,i/3-1)] = variants[i]
		_put(cells)
		_surroundings(cells,3)
		if index==7:
			_building(ARCH.Building.MOON_GATE,Vector3(0,0,-2.6))
			_building(ARCH.Building.SCREEN_WALL,Vector3(-2.50,0,-.10),PI*.5)
			_building(ARCH.Building.COVERED_WALK,Vector3(2.45,0,0),PI*.5)
			_path([Vector3(-2,0,2),Vector3(-2,0,3),Vector3(2,0,3),Vector3(2,0,2)])
			_height = 6.4
			_look.y = .10
	elif index==1:
		for i in 5:
			var at := Vector3(-1.55+(i%3)*1.55,0,-.85+(i/3)*1.85)
			_put({Vector2i.ZERO:i+1},at)
			labels.append([at+Vector3(0,.10,-.65),["荷叶","含苞","盛莲","残荷","刻字踏石"][i],-12])
		_ground(Rect2(-3.5,-3,7,6),-.50)
		_height = 3.8
		_look = Vector3(0,-.10,.10)
	elif index<=5:
		var kind: int = [3,1,4,5][index-2]
		_put({Vector2i.ZERO:kind})
		_surroundings({Vector2i.ZERO:kind},2)
		_height = 1.4
		_look = Vector3(0,-.15,0)
		_pitch = 45
	elif index==6:
		var cells: Dictionary = {}
		# A ring leaves a real stone island, then a one-cell watercourse leads
		# to a separate basin. A final isolated cell checks all four banks.
		for y in range(-2,1):
			for x in range(-3,0):
				if x==-2 and y==-1: continue
				cells[Vector2i(x,y)] = 1 if posmod(x+y,3) else 3
		for cell in [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(2,-1),Vector2i(3,-1),Vector2i(3,0),Vector2i(0,2)]: cells[cell] = 2 if cell.x%2 else 1
		_put(cells)
		_surroundings(cells,4)
		_height = 4.7
		_look = Vector3(0,-.12,.0)
		labels = [[Vector3(-2,0,.8),"石岛内角／外角"],[Vector3(1,0,.8),"单格水道"],[Vector3(0,0,2.8),"独立小池"]]
	elif index==8:
		var cells: Dictionary = {}
		for y in range(-1,2):
			for x in range(-1,2): cells[Vector2i(x,y)] = LOTUS.Plant.SMALL_LEAVES
		_put(cells)
		_surroundings(cells,2)
		_height = 3.1
		_pitch = 54
	elif index==9:
		for i in 6:
			var at := Vector3(-1.55+(i%3)*1.55,0,-.85+(i/3)*1.85)
			_put({Vector2i.ZERO:[LOTUS.Plant.SMALL_LEAVES,LOTUS.Plant.SMALL_CLUSTER,LOTUS.Plant.LEAVES][i%3]},at,layout_seed+(i/3)*7919)
			labels.append([at+Vector3(0,.08,.70),["疏散小叶","几片小叶成丛","少量中叶＋小叶"][i%3],18])
		_height = 3.8
		_look.z = .1
		_pitch = 65
		_yaw = 0
	elif index==10:
		_irregular_leaf_pond()
	_apply_camera()
	for asset in assets: asset.set_lamps_enabled(warm_toggle.button_pressed)
	comparison_light.visible = warm_toggle.button_pressed


func _put(cells: Dictionary, at := Vector3.ZERO, seed_override := -1) -> Node3D:
	var holder := Node3D.new()
	holder.position = at
	holder.scale = Vector3.ONE*.5
	contents.add_child(holder)
	var pond := LOTUS.assemble(holder,style,cells,lotus_palette,layout_seed if seed_override<0 else seed_override)
	ponds.append(pond)
	for tile in pond.get_children():
		if tile.foliage!=null: leaf_layers.append(tile.foliage)
	return pond


func _irregular_leaf_pond() -> void:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE*.5
	contents.add_child(holder)
	var values := [[-1,-1,-1,-1],[-1,1.7,.30,-1],[-1,1.0,-.7,-1],[-1,-1,-1,-1]]
	var lattice: Dictionary = {}
	for y in 4:
		for x in 4: lattice[Vector2i(x-1,y-1)] = values[y][x]
	var pond := POND_SHAPE.assemble(holder,style,lattice,Rect2i(-1,-1,3,3),lotus_palette)
	ponds.append(pond)
	var cells: Dictionary = {}
	for tile in pond.get_children(): cells[tile.get_meta("cell")] = tile
	var foliage := LEAF_LAYER.new()
	foliage.layout_seed = layout_seed
	foliage.small_leaf_count = 23
	foliage.small_radius = Vector2(.065,.20)
	foliage.half_extent = Vector2(2.85,2.85)
	foliage.water_height = -.24
	foliage.lotus_colors = lotus_palette
	foliage.water_test = func(point: Vector2):
		var cell := Vector2i(floori((point.x+1)*.5),floori((point.y+1)*.5))
		return cells.has(cell) and cells[cell].contains_water(point-Vector2(cell)*2)
	holder.add_child(foliage)
	foliage.setup(style)
	leaf_layers.append(foliage)
	_height = 2.9
	_pitch = 52
	_yaw = 8
	_look = Vector3(-.18,-.10,-.12)


func _surroundings(cells: Dictionary, radius: int) -> void:
	for y in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			if not cells.has(Vector2i(x,y)): _ground(Rect2(x-.5,y-.5,1,1),-.003)


func _apply_camera() -> void:
	super._apply_camera()
	if annotation!=null: annotation.queue_redraw()
