extends "res://src/tools/expedition_garden_lab.gd"
## A hand-authored spatial sample. This deliberately does not rewrite MapGen.
const POND = preload("res://src/map/expedition_pond_shape_tile.gd")
const LOTUS = preload("res://src/map/expedition_lotus_tile.gd")
const LEAVES = preload("res://src/map/expedition_lotus_leaf_layer.gd")
const REST = preload("res://src/map/expedition_rest_pavilion.gd")
const TRAVELER = preload("res://src/map/expedition_lantern_traveler.gd")
const TOMB = preload("res://src/map/expedition_tombstone.gd")
const SURVEY = preload("res://src/tools/garden_asset_bounds.gd")
const VIEWS := ["荷池小院 · 手工布局样板","同一庭院 · 占地与通行检查","入口折景 · 近看"]
const ROUTE: Array[Vector3] = [Vector3(2,0,5.8),Vector3(2,0,4.6),Vector3(3.2,0,4.55),Vector3(3.2,0,2.8),Vector3(3.2,0,.90),Vector3(5.95,0,.90),Vector3(5.95,0,1.85),Vector3(7.25,0,1.85),Vector3(7.25,0,4.8),Vector3(5.0,0,5.25),Vector3(4.35,0,5.25),Vector3(4.35,0,4.6),Vector3(3.2,0,4.55)]
const SHORTCUT: Array[Vector3] = [Vector3(2,0,4.6),Vector3(.65,0,4.6),Vector3(.65,0,2.9),Vector3(3.2,0,2.8)]
var surveyed: Array[Dictionary] = []
var layout_errors: Array[String] = []
var wall_parts: Array[Node3D] = []
var pond_tiles: Array[Node3D] = []
var plants: Array[Node3D] = []
var grove: Array[Node3D] = []
var actor: Node3D


func _build_controls() -> void:
	super._build_controls()
	mode.clear()
	for caption in VIEWS: mode.add_item(caption)
	grid_toggle.text = "占地／净空"
	annotation.set_script(load("res://src/tools/expedition_courtyard_overlay.gd"))
	annotation.set("lab",self)
	var col: VBoxContainer = chrome.get_child(1).get_child(0)
	(col.get_child(1) as Label).text = "左键转看 · 中键拖看 · 滚轮缩放 · 手工小院样板／前墙剖低／未替换远征生成"


func set_mode(index: int) -> void:
	current_mode = index
	mode.select(index)
	title.text = VIEWS[index]
	grid_toggle.set_pressed_no_signal(index==1)
	style.reset_geometry_tracking()
	assets.clear()
	assemblies.clear()
	trees.clear()
	labels.clear()
	surveyed.clear()
	layout_errors.clear()
	wall_parts.clear()
	pond_tiles.clear()
	plants.clear()
	grove.clear()
	if contents!=null:
		world.remove_child(contents)
		contents.queue_free()
	contents = Node3D.new()
	contents.name = "HandAuthoredCourtyard"
	world.add_child(contents)
	_ground_and_pond()
	_enclosure()
	var gate := ARCH.new()
	gate.building = ARCH.Building.MOON_GATE
	gate.position = Vector3(2,0,5)
	gate.scale = Vector3.ONE*.5
	gate.open_floor_passage = true
	contents.add_child(gate)
	gate.setup(style)
	assets.append(gate)
	_register("月洞院门",gate)
	var screen := _building(ARCH.Building.SCREEN_WALL,Vector3(2,0,3.65))
	_register("折景照壁",screen)
	var walk := _building(ARCH.Building.COVERED_WALK,Vector3(4.75,-.085,.85))
	# In this arrangement the hanging lamps belong over the rear benches,
	# leaving the central aisle clear. Move complete fixtures, including lights.
	for light in walk._lamps:
		(light.get_parent() as Node3D).position.z = -.46
	_register("后侧游廊",walk)
	var pavilion := REST.new()
	pavilion.position = Vector3(6.85,0,1.0)
	pavilion.scale = Vector3.ONE*.72
	contents.add_child(pavilion)
	pavilion.setup(style)
	assets.append(pavilion)
	_register("临水息灯亭",pavilion)
	_garden_bed()
	_pond_plants()
	actor = TRAVELER.new()
	actor.position = Vector3(3.2,0,3.0)
	actor.rotation_degrees.y = -30
	actor.scale = Vector3.ONE*.25
	contents.add_child(actor)
	actor.setup(style)
	assets.append(actor)
	_validate()
	_look = Vector3(4,.25,3.1)
	_height = 6.35
	_yaw = 16
	_pitch = 44
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	if index==1:
		_yaw = 0
		_pitch = 76
		_height = 7.2
	elif index==2:
		_look = Vector3(2.8,.45,3.9)
		_height = 3.9
		_yaw = 12
		_pitch = 42
	_apply_camera()


func pond_field(point: Vector2) -> float:
	var a := 1.0-((point-Vector2(5.0,2.8))/Vector2(1.48,1.22)).length()
	var b := 1.0-((point-Vector2(5.5,3.75))/Vector2(1.02,.79)).length()
	var field := maxf(a,b)*.9
	# The hand-drawn NE bank leaves a dry approach in front of the pavilion.
	var approach := Geometry2D.get_closest_point_to_segment(point,Vector2(5.95,.90),Vector2(5.95,1.85))
	field = minf(field,(point.distance_to(approach)-.27)*2.0)
	approach = Geometry2D.get_closest_point_to_segment(point,Vector2(5.95,1.85),Vector2(7.25,1.85))
	return minf(field,(point.distance_to(approach)-.27)*2.0)


func _ground_and_pond() -> void:
	var colors := preload("res://assets/expedition/lotus/lotus_night.tres")
	for z in 6:
		for x in 8:
			var center := Vector2(x+.5,z+.5)
			var tile := POND.new()
			tile.position = Vector3(center.x,0,center.y)
			tile.scale = Vector3.ONE*.5
			tile.subdivisions = 12
			tile.water_depth = .36
			tile.water_colors = colors
			tile.cutaway_edges = (1 if z==0 else 0)|(2 if x==7 else 0)|(4 if z==5 else 0)|(8 if x==0 else 0)
			tile.surface_sampler = func(uv: Vector2): return pond_field(center+uv-Vector2.ONE*.5)
			contents.add_child(tile)
			tile.setup(style)
			pond_tiles.append(tile)
	var foundation := MeshInstance3D.new()
	foundation.mesh = TypeMeshes.beveled_box(Vector3(8.02,.20,6.02),.01)
	foundation.position = Vector3(4,-.51,3)
	foundation.material_override = style.face_material("architecture")
	contents.add_child(foundation)


func _wall_run(points: Array[Vector3], windows := true, join_ends: Array[Vector3] = []) -> void:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE*.5
	contents.add_child(holder)
	var source: Array[Vector3] = []
	for point in points: source.append(point*2)
	var group := BOUNDARY.assemble(holder,style,source,true,false,windows)
	assemblies.append(group)
	for part in group.get_children():
		var at: Vector3 = part.global_position
		if part.piece in [BOUNDARY.Piece.WALL_POST,BOUNDARY.Piece.WALL_END] and join_ends.any(func(p): return p.distance_to(at)<.01):
			group.remove_child(part)
			part.queue_free()
			continue
		part.set_meta("moon_gate_join",not join_ends.is_empty())
		wall_parts.append(part)
		assets.append(part)


func _enclosure() -> void:
	# A continuous three-sided garden wall. The near face is a low cutaway
	# for this design study, not an opening in the playable map boundary.
	_wall_run([Vector3(0,0,6),Vector3.ZERO,Vector3(8,0,0),Vector3(8,0,6)])
	for x in 8:
		var base := MeshInstance3D.new()
		base.mesh = TypeMeshes.beveled_box(Vector3(1,.28,.22),.008)
		base.position = Vector3(x+.5,.14,6)
		base.material_override = style.face_material("architecture")
		contents.add_child(base)
	# The moon gate is part of this dividing wall, not a free-standing prop.
	_wall_run([Vector3(0,0,5),Vector3(1,0,5)],false,[Vector3(1,0,5),Vector3(0,0,5)])
	_wall_run([Vector3(3,0,5),Vector3(4,0,5)],false,[Vector3(3,0,5)])
	for x in [1.0,3.0]:
		var seam := MeshInstance3D.new()
		seam.mesh = TypeMeshes.beveled_box(Vector3(.13,.88,.16),.004)
		seam.position = Vector3(x,.44,5)
		seam.material_override = style.face_material("stone")
		contents.add_child(seam)


func _register(caption: String, node: Node3D) -> void:
	var entry := SURVEY.measure(node)
	entry["label"] = caption
	entry["node"] = node
	surveyed.append(entry)


func _garden_bed() -> void:
	var polygon := PackedVector2Array([Vector2(.28,.35),Vector2(2.25,.35),Vector2(2.65,.85),Vector2(2.45,1.75),Vector2(1.85,2.5),Vector2(.28,2.60)])
	var shape := SurfaceTool.new()
	shape.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(polygon)
	for n in range(0,indices.size(),3):
		for index in [indices[n],indices[n+1],indices[n+2]]:
			shape.set_normal(Vector3.UP)
			shape.add_vertex(Vector3(polygon[index].x,.009,polygon[index].y))
	var bed := MeshInstance3D.new()
	bed.mesh = shape.commit()
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("30372f")
	paint.roughness = 1
	bed.material_override = paint
	contents.add_child(bed)
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var border := MeshInstance3D.new()
		border.mesh = TypeMeshes.beveled_box(Vector3(.055,.035,a.distance_to(b)),.008)
		border.position = Vector3((a.x+b.x)*.5,.016,(a.y+b.y)*.5)
		border.rotation.y = atan2(b.x-a.x,b.y-a.y)
		border.material_override = style.face_material("stone")
		contents.add_child(border)
	var tree := TREE.new()
	tree.position = Vector3(1.1,0,1.05)
	contents.add_child(tree)
	tree.setup(style,camera)
	tree.scale = Vector3.ONE*.72
	grove.append(tree)
	for n in 2:
		var grave := TOMB.new()
		grave.variant = n+1
		grave.position = Vector3(.90+n*.53,.01,2.08-n*.16)
		grave.rotation.y = -.20+n*.38
		grave.scale = Vector3.ONE*.27
		contents.add_child(grave)
		grave.setup(style)
		assets.append(grave)


func _pond_plants() -> void:
	for entry in [[Vector2(4.6,2.55),LOTUS.Plant.BLOOM],[Vector2(5.85,3.1),LOTUS.Plant.BUD],[Vector2(5.25,3.85),LOTUS.Plant.WITHERED]]:
		var at: Vector2 = entry[0]
		var plant := LOTUS.new()
		plant.plants_only = true
		plant.plant = entry[1]
		plant.position = Vector3(at.x,0,at.y)
		plant.scale = Vector3.ONE*.5
		plant.water_height = -.36
		plant.layout_seed = 701+plants.size()*113
		plant.water_test = func(local: Vector2): return pond_field(at+local*.5)>.025
		contents.add_child(plant)
		plant.setup(style)
		plants.append(plant)
	var leaves := LEAVES.new()
	leaves.position = Vector3(5,0,3)
	leaves.scale = Vector3.ONE*.5
	leaves.layout_seed = 941
	leaves.small_leaf_count = 18
	leaves.small_radius = Vector2(.08,.22)
	leaves.half_extent = Vector2(3,3)
	leaves.water_height = -.36
	leaves.water_test = func(local: Vector2): return pond_field(Vector2(5,3)+local*.5)>.025
	for at in [Vector2(4.6,2.55),Vector2(5.85,3.1),Vector2(5.25,3.85)]:
		leaves.keepouts.append(Rect2((at-Vector2(5,3))*2-Vector2.ONE*.5,Vector2.ONE))
	contents.add_child(leaves)
	leaves.setup(style)


func _validate() -> void:
	for i in surveyed.size():
		for j in range(i+1,surveyed.size()):
			if SURVEY.conflicts(surveyed[i],surveyed[j]): _layout_error(surveyed[i].label+" / "+surveyed[j].label)
	for entry in surveyed:
		for wall in wall_parts:
			if entry.label=="月洞院门" and wall.get_meta("moon_gate_join",false): continue # Explicit shared masonry joints.
			if SURVEY.conflicts(entry,SURVEY.measure(wall)): _layout_error(entry.label+" / 院墙")
	var obstacles: Array[Dictionary] = []
	for entry in surveyed:
		if entry.label!="月洞院门": obstacles.append(entry)
	for wall in wall_parts:
		var entry := SURVEY.measure(wall)
		entry["label"] = "院墙"
		obstacles.append(entry)
	for line in [ROUTE,SHORTCUT]:
		for n in range(line.size()-1):
			var steps := ceili(line[n].distance_to(line[n+1])/.05)
			for step in steps+1:
				var at: Vector3 = line[n].lerp(line[n+1],float(step)/steps)
				for side in 8:
					if pond_field(Vector2(at.x,at.z)+Vector2.from_angle(TAU*side/8.0)*.18)>-.03: _layout_error("通行带侵入水面")
				for entry in obstacles:
					for part in entry.parts:
						var box: AABB = part.bounds
						# The gallery floor is walkable; its columns and benches are not.
						if part.roof or box.end.y<=.12 or box.position.y>=.88: continue
						var closest := Vector2(clampf(at.x,box.position.x,box.end.x),clampf(at.z,box.position.z,box.end.z))
						if closest.distance_to(Vector2(at.x,at.z))<.18:
							var message: String = "通行带碰到"+entry.label
							if not layout_errors.has(message): print("[CourtyardClearance] ",message," at=",at," part=",box)
							_layout_error(message)
	set_meta("layout_error_count",layout_errors.size())


func _layout_error(message: String) -> void:
	if not layout_errors.has(message): layout_errors.append(message)


func _apply_camera() -> void:
	if camera==null: return
	var distance := _height/(2*tan(deg_to_rad(camera.fov*.5)))
	var pitch := deg_to_rad(_pitch)
	var yaw := deg_to_rad(_yaw)
	camera.position = _look+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(_look,Vector3.UP)
	for tree in grove:
		tree.sync_camera()
		tree.scale = Vector3.ONE*.72
	style.refresh_outlines()
	annotation.queue_redraw()
