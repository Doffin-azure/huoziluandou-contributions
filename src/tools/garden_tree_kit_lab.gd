extends "res://src/tools/garden_landmark_lab.gd"
## Native tree studies with the same lights, stone and buildings as the last batch.
const TREE_KIT = preload("res://src/map/garden_tree_kit.gd")
const TREE_NAMES := ["红枫 · 深朱砂叶／分层树冠","斜生红枫 · 偏冠／临水横枝","怪松 · 曲干／横枝／疏针","垂柳 · 临水枝／长短垂叶","枯槐 · 分叉枯枝／树洞","庭院组合 · 红枫与石木建筑"]
var canopy_toggle: CheckButton


func _ready() -> void:
	output = "res://docs/art-concepts/2026-10-18-garden-trees"
	super._ready()


func _build_controls() -> void:
	chrome = Control.new()
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(chrome)
	title = Ink.h2(TREE_NAMES[0]); title.position = Vector2(24,18); chrome.add_child(title)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(20,-90)
	var paint := StyleBoxFlat.new(); paint.bg_color = Color(.04,.055,.06,.94); paint.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel",paint); chrome.add_child(panel)
	var column := Ink.vbox(6); panel.add_child(column)
	var row := Ink.hbox(12); column.add_child(row)
	mode = OptionButton.new()
	for text in TREE_NAMES: mode.add_item(text)
	mode.item_selected.connect(set_mode); row.add_child(mode)
	warm_toggle = CheckButton.new(); warm_toggle.text = "庭院灯光"; warm_toggle.set_pressed_no_signal(true)
	warm_toggle.toggled.connect(func(value: bool):
		for asset in assets: asset.set_lamps_enabled(value))
	row.add_child(warm_toggle)
	grid_toggle = CheckButton.new(); grid_toggle.text = "根部占地"
	grid_toggle.toggled.connect(func(_value: bool): annotation.queue_redraw()); row.add_child(grid_toggle)
	canopy_toggle = CheckButton.new(); canopy_toggle.text = "树冠透视"
	canopy_toggle.toggled.connect(func(value: bool):
		for tree in landmarks: tree.set_canopy_faded(value))
	row.add_child(canopy_toggle)
	for entry in [["红叶","seal"],["松叶","tree_leaf"],["柳叶","tree_leaf_light"],["树皮","tree_bark"]]:
		row.add_child(Ink.label(entry[0]))
		var picker := ColorPickerButton.new(); picker.custom_minimum_size = Vector2(28,26)
		var property: String = entry[1]; picker.color = palette.get(property)
		picker.color_changed.connect(func(value: Color): palette.set(property,value)); row.add_child(picker)
	column.add_child(Ink.caption("左键转看 · 中键拖看 · 滚轮缩放 · 原生立体树木／共享色板／独立样板"))


func set_mode(index: int) -> void:
	current_mode = index; mode.select(index); title.text = TREE_NAMES[index]
	style.reset_geometry_tracking()
	for list in [assets,assemblies,trees,labels,landmarks]: list.clear()
	if contents!=null: world.remove_child(contents); contents.queue_free()
	contents = Node3D.new(); world.add_child(contents)
	_water_context()
	if index<5:
		_floor(Rect2(-3.1,-2.65,6.6,5.35))
		_tree(index,Vector3.ZERO)
		_traveler(Vector3(2.30,0,.85))
		_look = Vector3(.05,1.52,.0); _height = 5.65
		if index==1: _look.x = -.12
	else:
		_composition()
		_look = Vector3(0,.95,0); _height = 12.1
	_yaw = 18; _pitch = 32 if index<5 else 45
	canopy_toggle.disabled = index==4
	_apply_camera()


func _tree(index: int, at: Vector3, turn := 0.0) -> Node3D:
	var scene: PackedScene = load("res://assets/expedition/garden/%s.tscn" % ["red_maple","leaning_red_maple","crooked_pine","weeping_willow","bare_locust"][index])
	var tree: Node3D = scene.instantiate()
	tree.position = at; tree.rotation.y = turn
	contents.add_child(tree); tree.setup(style)
	tree.set_canopy_faded(canopy_toggle.button_pressed)
	assets.append(tree); landmarks.append(tree)
	return tree


func _building_landmark(kind: int, at: Vector3) -> void:
	var item := KIT.new(); item.kind = kind; item.position = at
	contents.add_child(item); item.setup(style); assets.append(item)
	item.set_lamps_enabled(warm_toggle.button_pressed)


func _composition() -> void:
	_floor(Rect2(-8,-5,16,10))
	_building_landmark(KIT.Kind.SMALL_LOFT,Vector3(-1.4,0,-3.05))
	_building_landmark(KIT.Kind.SQUARE_PAVILION,Vector3(2.35,0,-.65))
	_tree(0,Vector3(-5.05,0,.0),-.20)
	_tree(1,Vector3(-1.05,0,2.45),.05)
	_tree(2,Vector3(5.70,0,-2.90),.15)
	_tree(3,Vector3(5.60,0,2.90),-.4)
	_tree(4,Vector3(-5.65,0,-3.30),.12)
	_traveler(Vector3(1.40,0,3.75))
	var holder := Node3D.new(); holder.scale = Vector3.ONE*.5; contents.add_child(holder)
	var wall := BOUNDARY.assemble(holder,style,[Vector3(-16,0,10),Vector3(-16,0,-10),Vector3(16,0,-10)],true,false,true)
	assemblies.append(wall)
	for part in wall.get_children(): assets.append(part)
	for at in [Vector3(4.6,0,5.65),Vector3(6.1,0,5.75),Vector3(-5.4,0,5.6)]:
		var lotus := LOTUS.new(); lotus.plants_only = true; lotus.plant = LOTUS.Plant.BLOOM
		lotus.water_height = -.90; lotus.scale = Vector3.ONE*.5; lotus.position = at
		contents.add_child(lotus); lotus.setup(style); assets.append(lotus)


func _capture() -> void:
	get_window().content_scale_size = Vector2i.ZERO; get_window().size = Vector2i(1600,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await _frames(15)
	for index in 6:
		set_mode(index); await _frames(8); await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(output.path_join("%02d-%s.png" % [index+1,["red-maple","leaning-maple","crooked-pine","willow","bare-locust","composition"][index]]))
		print("[GardenTrees] ",TREE_NAMES[index]," trees=",landmarks.size())
	set_mode(0); _pitch = 52; _apply_camera()
	await _frames(8); await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("07-maple-map-angle.png"))
	canopy_toggle.button_pressed = true
	await _frames(8); await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join("08-maple-canopy-faded.png"))
	canopy_toggle.button_pressed = false; grid_toggle.button_pressed = true
	await _frames(4); await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("09-root-footprint.png"))
	print("[GardenTrees] Five native tree scenes, garden assembly and map-angle preview complete")
	get_tree().quit()
