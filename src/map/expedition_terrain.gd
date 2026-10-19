extends Node3D
class_name ExpeditionTerrain
## The logical grid supplies topology only. Top faces share world UVs; shores are
## connected contours with rounded convex/concave corners and extruded walls.
const WATER_Y := -0.32
const BOTTOM_Y := -0.58
const ROUNDING := 0.13
const MARGIN := 3
const GARDEN_LAYOUT = preload("res://src/expedition/garden_layout.gd")
static var _garden_mesh_cache: Dictionary = {}
var ground_material: ShaderMaterial
var water_material: ShaderMaterial
var fog_texture: ImageTexture
var sight_cover: MeshInstance3D
var sight_material: ShaderMaterial
var loops: Array[PackedVector2Array] = []
var shore_segments := 0
var land_cells := 0
var _map: Dictionary
var _materials: ExpeditionMapProps
var _field_cache: Dictionary = {}


func build(map: Dictionary, materials: ExpeditionMapProps) -> void:
	var began := Time.get_ticks_msec()
	_map = map
	_materials = materials
	var image := Image.create(MapGen.W, MapGen.H, false, Image.FORMAT_RG8)
	image.fill(Color.BLACK)
	fog_texture = ImageTexture.create_from_image(image)
	ground_material = ShaderMaterial.new()
	ground_material.shader = load("res://src/shaders/expedition_ground.gdshader")
	ground_material.set_shader_parameter("fog_mask", fog_texture)
	ground_material.set_shader_parameter("clip_vision_bounds",true)
	ground_material.set_shader_parameter("outer_fade",map.has("layout"))
	var land_image := Image.create(MapGen.W+MARGIN*2,MapGen.H+MARGIN*2,false,Image.FORMAT_R8)
	for r in range(-MARGIN,MapGen.H+MARGIN):
		for c in range(-MARGIN,MapGen.W+MARGIN): land_image.set_pixel(c+MARGIN,r+MARGIN,Color.WHITE if land_at(r,c) else Color.BLACK)
	ground_material.set_shader_parameter("land_mask",ImageTexture.create_from_image(land_image))
	ground_material.set_shader_parameter("theme_tint", {"墨池": Color.WHITE, "熔铸坊": Color(1.10,0.91,0.84), "潮汐渠": Color(0.91,1.02,1.06), "雷池": Color(1.0,0.95,1.07)}.get(map.tn, Color.WHITE))
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://src/shaders/expedition_water.gdshader")
	water_material.set_shader_parameter("fog_mask", fog_texture)
	water_material.set_shader_parameter("clip_vision_bounds",true)
	if map.has("layout"):
		water_material.set_shader_parameter("water_tint",materials.map_art.style.palette.water)
		water_material.set_shader_parameter("outer_fade",true)
	if map.has("layout"): _build_garden_surface()
	else:
		_build_top()
		_build_shores()
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(38, 32)
	water.mesh = plane
	water.position = Vector3(6,float(map.layout.water_height) if map.has("layout") else WATER_Y,4)
	water.material_override = water_material
	add_child(water)
	# Continuous opaque cover is the information boundary. The native volume
	# above it only supplies the moving ink-cloud edge, not the reveal rules.
	sight_cover = MeshInstance3D.new()
	sight_cover.name = "UnexploredSightCover"
	var cover := PlaneMesh.new()
	cover.size = Vector2(38,32)
	sight_cover.mesh = cover
	sight_cover.position = Vector3(6,.065,4)
	sight_cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sight_material = ShaderMaterial.new()
	sight_material.shader = preload("res://src/shaders/expedition_sight_veil.gdshader")
	sight_material.set_shader_parameter("fog_mask",fog_texture)
	sight_material.set_shader_parameter("clip_vision_bounds",true)
	sight_cover.material_override = sight_material
	add_child(sight_cover)
	set_meta("build_msec",Time.get_ticks_msec()-began)


func update_fog(ex: Expedition) -> void:
	var image := Image.create(MapGen.W, MapGen.H, false, Image.FORMAT_RG8)
	for k in MapGen.N:
		var rc := MapGen.rc(k)
		image.set_pixel(rc.y, rc.x, Color(1.0 if ex.explored.has(k) else 0.0, 1.0 if ex.visible.has(k) else 0.0, 0))
	fog_texture.update(image)


func land_at(r: int, c: int) -> bool:
	if _map.has("layout"):
		return GARDEN_LAYOUT.base_at(_map,r,c)!=1
	if MapGen.inb(r, c):
		return _map.ink[MapGen.kk(r, c)] == 0
	if r < -MARGIN or r >= MapGen.H + MARGIN or c < -MARGIN or c >= MapGen.W + MARGIN:
		return false
	# The scenery continues beyond the logical rectangle; no visible board border.
	var nearest := Vector2i(clampi(r, 0, MapGen.H - 1), clampi(c, 0, MapGen.W - 1))
	if abs(r - nearest.x) + abs(c - nearest.y) <= 1:
		return _map.ink[MapGen.kk(nearest.x, nearest.y)] == 0
	return sin(c * 0.85 + r * 0.57) + cos(r * 1.21 - c * 0.27) > -0.55


func _garden_field(point: Vector2) -> float:
	var key := Vector2i(roundi(point.x*100000),roundi(point.y*100000))
	if not _field_cache.has(key): _field_cache[key] = GARDEN_LAYOUT.water_field(_map,point)
	return float(_field_cache[key])


func _build_garden_surface() -> void:
	var cache_key := hash([_map.seed,_map.ink,_map.layout])
	var shore := ShaderMaterial.new()
	shore.shader = preload("res://src/shaders/expedition_shore.gdshader")
	shore.set_shader_parameter("fog_mask",fog_texture)
	shore.set_shader_parameter("clip_vision_bounds",true)
	shore.set_shader_parameter("water_level",float(_map.layout.water_height))
	shore.set_shader_parameter("stone_color",_materials.map_art.style.palette.stone_side)
	shore.set_shader_parameter("outer_fade",true)
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://src/shaders/expedition_tree_ink.gdshader")
	ink.set_shader_parameter("ink_color",_materials.map_art.style.palette.ink)
	ink.set_shader_parameter("half_width_pixels",.65)
	if _garden_mesh_cache.has(cache_key):
		set_meta("garden_cache_hit",true)
		var cached: Dictionary = _garden_mesh_cache[cache_key]
		for i in 3: _add_baked_mesh(cached.meshes[i],[ground_material,shore,ink][i],["ContinuousStone","ShoreWalls","ContinuousShoreInk"][i])
		loops = cached.loops
		shore_segments = cached.shore_segments
		land_cells = cached.land_cells
		return
	set_meta("garden_cache_hit",false)
	var source: Script = load("res://src/map/expedition_pond_shape_tile.gd")
	var top := SurfaceTool.new()
	var walls := SurfaceTool.new()
	var lines := SurfaceTool.new()
	for surface in [top,walls,lines]: surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(-MARGIN,MapGen.H+MARGIN):
		for c in range(-MARGIN,MapGen.W+MARGIN):
			var center := Vector2(c+.5,r+.5)
			var minimum := 100.0
			var maximum := -100.0
			for dy in 3:
				for dx in 3:
					var value := _garden_field(center+Vector2(dx*.5-.5,dy*.5-.5))
					minimum = minf(minimum,value)
					maximum = maxf(maximum,value)
			if maximum<-.11:
				_polygon(top,PackedVector2Array([Vector2(c,r),Vector2(c+1,r),Vector2(c+1,r+1),Vector2(c,r+1)]))
				land_cells += 1
				continue
			if minimum>0: continue
			var tile: Node3D = source.new()
			tile.position = Vector3(center.x,0,center.y)
			tile.scale = Vector3.ONE*.5
			tile.cutaway_edges = 0
			tile.water_depth = -float(_map.layout.water_height)*2
			tile.bank_depth = 1.16
			tile.subdivisions = 12
			tile.include_water = false
			tile.include_ink = false
			tile.surface_sampler = func(uv: Vector2): return _garden_field(center+uv-Vector2.ONE*.5)
			add_child(tile)
			tile.setup(_materials.map_art.style)
			for mesh in [tile.land,tile.rim]:
				if mesh!=null: _append_geometry(top,mesh.mesh,tile.transform)
			var wall: MeshInstance3D = tile.get_node_or_null("RecessedShoreWall")
			if wall!=null: _append_geometry(walls,wall.mesh,tile.transform)
			for path: PackedVector2Array in tile.shore_paths:
				var world_path := PackedVector2Array()
				for point in path: world_path.append(center+point*.5)
				loops.append(world_path)
				for i in range(world_path.size()-1):
					shore_segments += 1
					for corner: Vector2i in [Vector2i(i,-1),Vector2i(i+1,-1),Vector2i(i+1,1),Vector2i(i,-1),Vector2i(i+1,1),Vector2i(i,1)]:
						var j := corner.x
						var tangent := world_path[mini(world_path.size()-1,j+1)]-world_path[maxi(0,j-1)]
						lines.set_normal(Vector3(tangent.x,0,tangent.y).normalized())
						lines.set_color(Color.WHITE)
						lines.set_uv(Vector2(0,corner.y))
						lines.add_vertex(Vector3(world_path[j].x,.003,world_path[j].y))
			remove_child(tile)
			tile.free()
	var meshes := [top.commit(),walls.commit(),lines.commit()]
	for i in 3: _add_baked_mesh(meshes[i],[ground_material,shore,ink][i],["ContinuousStone","ShoreWalls","ContinuousShoreInk"][i])
	if _garden_mesh_cache.size()>=8: _garden_mesh_cache.erase(_garden_mesh_cache.keys()[0])
	_garden_mesh_cache[cache_key] = {"meshes":meshes,"loops":loops,"shore_segments":shore_segments,"land_cells":land_cells}
	_field_cache.clear()


func _add_baked_mesh(mesh: Mesh, material: Material, label: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	if label!="ContinuousStone": instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _append_geometry(surface: SurfaceTool, mesh: Mesh, transform_value: Transform3D) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in vertices.size():
		surface.set_normal((transform_value.basis*normals[i]).normalized())
		surface.set_uv(Vector2.ZERO)
		surface.add_vertex(transform_value*vertices[i])


func _build_top() -> void:
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(-MARGIN, MapGen.H + MARGIN):
		for c in range(-MARGIN, MapGen.W + MARGIN):
			if land_at(r, c):
				land_cells += 1
				var polygon := PackedVector2Array()
				var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
				for i in 4:
					var corner: Vector2 = corners[i] + Vector2(c, r)
					var dx := -1 if i in [0, 3] else 1
					var dz := -1 if i in [0, 1] else 1
					if not land_at(r, c + dx) and not land_at(r + dz, c):
						var previous: Vector2 = (corners[i] - corners[posmod(i - 1, 4)]).normalized()
						var following: Vector2 = (corners[(i + 1) % 4] - corners[i]).normalized()
						_append_curve(polygon, corner - previous * ROUNDING, corner, corner + following * ROUNDING)
					else:
						polygon.append(corner)
				_polygon(top, polygon)
			else:
				# Fill the tiny concave corner beside three land cells. These vertices
				# match the same quadratic curve used by the boundary wall exactly.
				for dx in [-1, 1]:
					for dz in [-1, 1]:
						if land_at(r, c + dx) and land_at(r + dz, c) and land_at(r + dz, c + dx):
							var corner := Vector2(c + (1 if dx > 0 else 0), r + (1 if dz > 0 else 0))
							var fill := PackedVector2Array([corner])
							_append_curve(fill, corner - Vector2(dx * ROUNDING, 0), corner, corner - Vector2(0, dz * ROUNDING))
							_polygon(top, fill)
	_add_mesh(top, ground_material, "ContinuousStone")


static func _append_curve(points: PackedVector2Array, a: Vector2, control: Vector2, b: Vector2) -> void:
	for j in 5:
		var t := float(j) / 4.0
		points.append(a.lerp(control, t).lerp(control.lerp(b, t), t))


static func _polygon(surface: SurfaceTool, polygon: PackedVector2Array) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0, indices.size(), 3):
		var a := polygon[indices[i]]
		var b := polygon[indices[i + 1]]
		var c := polygon[indices[i + 2]]
		triangle(surface, Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(c.x, 0, c.y), Vector3.UP)


static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, uv_a := Vector2.ZERO, uv_b := Vector2.ZERO, uv_c := Vector2.ZERO) -> void:
	var vertices := [a, b, c]
	var uvs := [uv_a, uv_b, uv_c]
	if (b-a).cross(c-a).dot(normal) > 0:
		vertices = [a, c, b]
		uvs = [uv_a, uv_c, uv_b]
	for j in 3:
		surface.set_normal(normal)
		surface.set_uv(uvs[j])
		surface.add_vertex(vertices[j])


func _build_shores() -> void:
	var edges: Dictionary = {}
	for r in range(-MARGIN, MapGen.H + MARGIN):
		for c in range(-MARGIN, MapGen.W + MARGIN):
			if not land_at(r, c):
				continue
			var p := Vector2i(c, r)
			if not land_at(r - 1, c): _edge(edges, p, p + Vector2i.RIGHT)
			if not land_at(r, c + 1): _edge(edges, p + Vector2i.RIGHT, p + Vector2i.ONE)
			if not land_at(r + 1, c): _edge(edges, p + Vector2i.ONE, p + Vector2i.DOWN)
			if not land_at(r, c - 1): _edge(edges, p + Vector2i.DOWN, p)
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var caps := SurfaceTool.new()
	caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	while not edges.is_empty():
		var start: Vector2i = edges.keys()[0]
		var current := start
		var direction := Vector2i.RIGHT
		var contour := PackedVector2Array()
		for guard in 2000:
			contour.append(Vector2(current))
			var choices: Array = edges.get(current, [])
			if choices.is_empty(): break
			var best: Vector2i = choices[0]
			var score := -100.0
			for choice: Vector2i in choices:
				var d := choice - current
				var turn := float(direction.x * d.y - direction.y * d.x) * 2.0 + float(direction.x*d.x + direction.y*d.y)
				if turn > score:
					score = turn
					best = choice
			choices.erase(best)
			if choices.is_empty(): edges.erase(current)
			direction = best - current
			current = best
			if current == start: break
		if contour.size() < 3: continue
		var smooth := PackedVector2Array()
		for i in contour.size():
			var corner := contour[i]
			var incoming := (corner - contour[posmod(i - 1, contour.size())]).normalized()
			var outgoing := (contour[(i + 1) % contour.size()] - corner).normalized()
			if absf(incoming.cross(outgoing)) < 0.01:
				smooth.append(corner)
			else:
				_append_curve(smooth, corner - incoming * ROUNDING, corner, corner + outgoing * ROUNDING)
		loops.append(smooth)
		var distance := 0.0
		for i in smooth.size():
			var a := smooth[i]
			var b := smooth[(i + 1) % smooth.size()]
			var length := a.distance_to(b)
			var d := (b-a).normalized()
			var inward := Vector2(-d.y, d.x)
			var normal := Vector3(d.y, 0, -d.x)
			var at := Vector3(a.x, 0, a.y)
			var bt := Vector3(b.x, 0, b.y)
			var ab := at + Vector3(0, BOTTOM_Y, 0)
			var bb := bt + Vector3(0, BOTTOM_Y, 0)
			triangle(walls, at, bt, bb, normal, Vector2(distance, 0), Vector2(distance + length, 0), Vector2(distance + length, 1))
			triangle(walls, at, bb, ab, normal, Vector2(distance, 0), Vector2(distance + length, 1), Vector2(distance, 1))
			var ai := at + Vector3(inward.x * 0.055, 0.013, inward.y * 0.055)
			var bi := bt + Vector3(inward.x * 0.055, 0.013, inward.y * 0.055)
			at.y = 0.013
			bt.y = 0.013
			triangle(caps, at, bt, bi, Vector3.UP)
			triangle(caps, at, bi, ai, Vector3.UP)
			distance += length
			shore_segments += 1
	var wall_material := ShaderMaterial.new()
	wall_material.shader = preload("res://src/shaders/expedition_shore.gdshader")
	wall_material.set_shader_parameter("clip_vision_bounds",true)
	var cap_material: ShaderMaterial = wall_material.duplicate()
	cap_material.set_shader_parameter("stone_color",Color("3a403e"))
	for material in [wall_material, cap_material]:
		material.set_shader_parameter("fog_mask", fog_texture)
	_add_mesh(walls, wall_material, "ShoreWalls")
	_add_mesh(caps, cap_material, "JoinedShoreCaps")


static func _edge(edges: Dictionary, a: Vector2i, b: Vector2i) -> void:
	if not edges.has(a): edges[a] = []
	edges[a].append(b)


func _add_mesh(surface: SurfaceTool, material: Material, mesh_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = surface.commit()
	instance.material_override = material
	add_child(instance)
