extends "res://src/tools/expedition_lotus_lab.gd"
## Unplanted, fractional water tiles; independent of the expedition map.
const SHAPE = preload("res://src/map/expedition_pond_shape_tile.gd")
const SHAPE_TITLES := ["无荷叶 · 不规则3×3水岸","格内水面 · 六种模块","四格共角 · 小片水面拼接","半格水岸 · 横向连续拼接","无荷叶池塘 · 园林组合","左上小水片 · 单格近看"]


func _build_controls() -> void:
	super._build_controls()
	mode.clear()
	for text in SHAPE_TITLES: mode.add_item(text)
	var col: VBoxContainer = chrome.get_child(1).get_child(0)
	var color_row: HBoxContainer = col.get_child(1)
	for i in 4:
		var unused := color_row.get_child(0)
		color_row.remove_child(unused)
		unused.queue_free()
	# Terrain shapes are authored, so only keep the water colour in this row.
	while color_row.get_child_count()>2:
		var unused := color_row.get_child(2)
		color_row.remove_child(unused)
		unused.queue_free()
	(col.get_child(2) as Label).text = "左键转看 · 中键拖看 · 滚轮缩放 · 岸线可穿过格内／共边连续 · 独立样板"


func set_mode(index: int) -> void:
	current_mode = index
	mode.select(index)
	title.text = SHAPE_TITLES[index]
	style.reset_geometry_tracking()
	assets.clear()
	assemblies.clear()
	trees.clear()
	ponds.clear()
	labels.clear()
	if contents!=null:
		world.remove_child(contents)
		contents.queue_free()
	contents = Node3D.new()
	contents.name = "UnplantedWaterStudyOnly"
	world.add_child(contents)
	_yaw = 8
	_pitch = 52
	_look = Vector3(0,-.08,0)
	_height = 3.1
	match index:
		0:
			var lattice: Dictionary = {}
			var values := [[-1,-1,-1,-1],[-1,1.7,.30,-1],[-1,1.0,-.7,-1],[-1,-1,-1,-1]]
			for y in 4:
				for x in 4: lattice[Vector2i(x-1,y-1)] = values[y][x]
			_join(lattice,Rect2i(-1,-1,3,3))
			_outside(Rect2i(-1,-1,3,3),2)
			_look = Vector3(-.18,-.10,-.12)
		1:
			var presets := [Vector4.ONE,Vector4(.38,-1,-1,-1),Vector4(1.4,-1,-1,-1),Vector4(1,1,-1,-1),Vector4(1,0,-1,0),Vector4(-1,1,1,1)]
			for i in presets.size():
				var at := Vector3(-1.6+(i%3)*1.6,0,-.95+(i/3)*1.9)
				_single(presets[i],at,.28 if i==3 else 0)
				labels.append([at+Vector3(0,0,.70),["纯水／开放拼接","左上极小水片","偏角水面","半格弧岸","对角半片","反向内湾"][i],18])
			_height = 3.7
			_look.z = .13
			_yaw = 0
		2:
			_join({Vector2i.ZERO:.65},Rect2i(-1,-1,2,2),Vector3(.5,0,.5))
			_height = 2.4
			_pitch = 60
			_yaw = 0
		3:
			var lattice: Dictionary = {}
			for y in range(-2,4):
				for x in range(-3,4): lattice[Vector2i(x,y)] = .5-float(y)+.18*sin(float(x)*1.3)
			_join(lattice,Rect2i(-2,-1,4,3),Vector3(.5,0,-.5))
			_height = 3.4
			_look.y = -.12
			_yaw = 0
		4:
			var lattice: Dictionary = {}
			for y in range(-4,5):
				for x in range(-5,6):
					var p := Vector2(x-.5,y-.5)
					var basin := 1.0-Vector2((p.x+.4)/2.15,(p.y+.2)/1.42).length()
					var lobe := 1.0-Vector2((p.x-1.1)/.95,(p.y+.35)/.73).length()
					lattice[Vector2i(x,y)] = maxf(basin,lobe)*2.5
			_join(lattice,Rect2i(-3,-2,6,4))
			_outside(Rect2i(-3,-2,6,4),4)
			_building(ARCH.Building.MOON_GATE,Vector3(-1.9,0,-2.9))
			_building(ARCH.Building.SCREEN_WALL,Vector3(1.2,0,-2.7))
			_path([Vector3(-3,0,1.75),Vector3(-3,0,2.75),Vector3(.0,0,2.75)])
			_path([Vector3(1.5,0,2.75),Vector3(3,0,2.75),Vector3(3,0,1.75)])
			_height = 7.1
			_look = Vector3(-.1,.08,-.05)
			_pitch = 48
			_yaw = 12
		5:
			_single(Vector4(.38,-1,-1,-1),Vector3.ZERO)
			_height = 1.5
			_pitch = 58
			_yaw = 0
	_apply_camera()
	for asset in assets: asset.set_lamps_enabled(warm_toggle.button_pressed)
	comparison_light.visible = warm_toggle.button_pressed


func _single(values: Vector4, at: Vector3, curve := 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE*.5
	holder.position = at
	contents.add_child(holder)
	var tile := SHAPE.new()
	tile.corner_values = values
	tile.bend = curve
	tile.water_colors = lotus_palette
	holder.add_child(tile)
	tile.setup(style)
	ponds.append(holder)
	return tile


func _join(lattice: Dictionary, bounds: Rect2i, at := Vector3.ZERO) -> Node3D:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE*.5
	holder.position = at
	contents.add_child(holder)
	var pond := SHAPE.assemble(holder,style,lattice,bounds,lotus_palette)
	ponds.append(pond)
	return pond


func _outside(bounds: Rect2i, radius: int) -> void:
	for y in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			if not bounds.has_point(Vector2i(x,y)): _ground(Rect2(x-.5,y-.5,1,1),0)


func _ground(rect: Rect2, y := 0.0) -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = rect.size
	mesh.mesh = plane
	mesh.position = Vector3(rect.get_center().x,y,rect.get_center().y)
	mesh.material_override = SHAPE.ground_material()
	contents.add_child(mesh)
	var base := MeshInstance3D.new()
	base.mesh = TypeMeshes.beveled_box(Vector3(rect.size.x,.32,rect.size.y),.01)
	base.position = mesh.position-Vector3.UP*.162
	base.material_override = style.face_material("architecture")
	contents.add_child(base)
