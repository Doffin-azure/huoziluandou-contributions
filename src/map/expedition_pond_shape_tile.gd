extends "res://src/map/expedition_garden_asset_base.gd"
## Plant-free pond patches. A shared scalar lattice cuts both stone and water;
## neighbouring tiles evaluate the same edge, including fractional crossings.
const PITCH := 2.0
const RIM_FIELD := -.11
@export var corner_values := Vector4(.38,-1,-1,-1) # NW, NE, SE, SW; positive = water.
@export_range(-1,1,.01) var bend := 0.0
@export_range(8,32,1) var subdivisions := 16
@export_range(.12,.80,.02) var water_depth := .24
@export var bank_depth := .80
var surface_sampler: Callable
var include_water := true
var include_ink := true
var _sample_cache: Dictionary = {}
@export_flags("North","East","South","West") var cutaway_edges := 15
@export var water_colors: ExpeditionLotusPalette = preload("res://assets/expedition/lotus/lotus_night.tres")
var water: MeshInstance3D
var land: MeshInstance3D
var rim: MeshInstance3D
var water_area := 0.0
var land_area := 0.0
var rim_area := 0.0
var shore_paths: Array[PackedVector2Array] = []
var _control := PackedFloat64Array() # Optional 4x4 shared lattice neighbourhood.
var _segments: Array = []
var _water_paint: ShaderMaterial


func _build() -> void:
	name = "PartialPondTile"
	footprint = Vector2.ONE*PITCH
	map_scale = .5
	set_meta("tile_pitch",PITCH)
	set_meta("water_height",-water_depth)
	set_meta("decorative_only",true)
	var dry := _surface()
	var lip := _surface()
	var wet := _surface()
	var walls := _surface()
	var cut := _surface()
	for y in subdivisions:
		for x in subdivisions:
			var a := _sample_vertex(x,y)
			var b := _sample_vertex(x+1,y)
			var c := _sample_vertex(x+1,y+1)
			var d := _sample_vertex(x,y+1)
			# Alternate diagonals to avoid a visible preferred direction in curves.
			var triangles := [[a,b,c],[a,c,d]] if (x+y)%2==0 else [[a,b,d],[b,c,d]]
			for triangle in triangles:
				land_area += _cap(dry,_clip(triangle,RIM_FIELD,false),0)
				rim_area += _cap(lip,_clip(_clip(triangle,RIM_FIELD,true),0,false),0)
				water_area += _cap(wet,_clip(triangle,0,true),-water_depth)
				_shore(triangle,walls)
	_build_cutaway(cut)
	if land_area>.000001:
		land = _plain_mesh(dry,"ClippedStoneGround")
		var at := global_position
		land.material_override = ground_material(Vector2(.5-fposmod(at.x,1),.5-fposmod(at.z,1)))
	if rim_area>.000001:
		rim = _plain_mesh(lip,"FlushStoneShore")
		rim.material_override = style.face_material("stone")
	if water_area>.000001 and include_water:
		water = _plain_mesh(wet,"PlantFreeWater")
		_water_paint = ShaderMaterial.new()
		_water_paint.shader = preload("res://src/shaders/expedition_lotus_water.gdshader")
		water.material_override = _water_paint
	if not _segments.is_empty():
		var wall := _plain_mesh(walls,"RecessedShoreWall")
		wall.material_override = style.face_material("stone")
		_join_shore_paths()
		for path in shore_paths if include_ink else []:
			var stroke: Array[Vector3] = []
			for p in path: stroke.append(Vector3(p.x,.003,p.y))
			ink(stroke,.38)
	if cutaway_edges!=0:
		var side := _plain_mesh(cut,"TileSectionOnly")
		side.material_override = style.face_material("architecture")
	water_colors.changed.connect(_refresh_water)
	_refresh_water()
	var sockets: Array[Vector3] = []
	for path in shore_paths:
		for p in [path[0],path[-1]]:
			if is_equal_approx(absf(p.x),1) or is_equal_approx(absf(p.y),1):
				sockets.append(Vector3(p.x,0,p.y))
	set_meta("connections",sockets)


func _exit_tree() -> void:
	if water_colors!=null and water_colors.changed.is_connected(_refresh_water): water_colors.changed.disconnect(_refresh_water)
	super._exit_tree()


func _refresh_water() -> void:
	if _water_paint==null: return
	_water_paint.set_shader_parameter("deep_color",water_colors.water_deep)
	_water_paint.set_shader_parameter("light_color",water_colors.water_light)


static func ground_material(grid_offset := Vector2(.5,.5)) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://src/shaders/expedition_ground.gdshader")
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var white := ImageTexture.create_from_image(image)
	paint.set_shader_parameter("fog_mask",white)
	paint.set_shader_parameter("land_mask",white)
	paint.set_shader_parameter("stone_grid_offset",grid_offset)
	return paint


func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


func _plain_mesh(surface: SurfaceTool, label: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = surface.commit()
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part


func _sample_vertex(x: int, y: int) -> Vector3:
	var key := Vector2i(x,y)
	if _sample_cache.has(key): return _sample_cache[key]
	var uv := Vector2(float(x),float(y))/subdivisions
	var point := Vector3(uv.x*2-1,_value(uv),uv.y*2-1)
	_sample_cache[key] = point
	return point


func contains_water(point: Vector2) -> bool:
	return absf(point.x)<=1.000001 and absf(point.y)<=1.000001 and _value((point+Vector2.ONE)*.5)>.02


static func _cubic(a: float, b: float, c: float, d: float, t: float) -> float:
	return b+.5*t*(c-a+t*(2*a-5*b+4*c-d+t*(3*(b-c)+d-a)))


func _value(uv: Vector2) -> float:
	if surface_sampler.is_valid(): return surface_sampler.call(uv)
	if _control.size()==16:
		var rows := PackedFloat64Array()
		for y in 4:
			rows.append(_cubic(_control[y*4],_control[y*4+1],_control[y*4+2],_control[y*4+3],uv.x))
		# Bicubic interpolation gives matching tangents as well as edge positions.
		return _cubic(rows[0],rows[1],rows[2],rows[3],uv.y)
	return lerpf(lerpf(corner_values.x,corner_values.y,uv.x),lerpf(corner_values.w,corner_values.z,uv.x),uv.y)+bend*sin(PI*uv.x)*sin(PI*uv.y)


func _clip(polygon: Array, threshold: float, keep_above: bool) -> Array:
	var result: Array = []
	if polygon.is_empty(): return result
	var a: Vector3 = polygon[-1]
	var a_inside := a.y>=threshold if keep_above else a.y<=threshold
	for b: Vector3 in polygon:
		var b_inside := b.y>=threshold if keep_above else b.y<=threshold
		if a_inside!=b_inside:
			_append_unique(result,a.lerp(b,(threshold-a.y)/(b.y-a.y)))
		if b_inside: _append_unique(result,b)
		a = b
		a_inside = b_inside
	if result.size()>1 and result[0].distance_squared_to(result[-1])<.000000000001: result.pop_back()
	return result


func _append_unique(points: Array, p: Vector3) -> void:
	if points.is_empty() or points[-1].distance_squared_to(p)>.000000000001: points.append(p)


func _cap(surface: SurfaceTool, points: Array, height: float) -> float:
	var area := 0.0
	for i in range(1,points.size()-1):
		var a := Vector3(points[0].x,height,points[0].z)
		var b := Vector3(points[i].x,height,points[i].z)
		var c := Vector3(points[i+1].x,height,points[i+1].z)
		var part := (b-a).cross(c-a).length()*.5
		if part<.000000001: continue
		_triangle(surface,a,b,c,Vector3.UP)
		area += part
	return area


func _shore(triangle: Array, surface: SurfaceTool) -> void:
	var low := minf(triangle[0].y,minf(triangle[1].y,triangle[2].y))
	var high := maxf(triangle[0].y,maxf(triangle[1].y,triangle[2].y))
	if low>=0 or high<0: return
	var ends: Array[Vector2] = []
	for i in 3:
		var a: Vector3 = triangle[i]
		var b: Vector3 = triangle[(i+1)%3]
		var hit: Vector3
		if is_zero_approx(a.y): hit = a
		elif (a.y<0 and b.y>0) or (a.y>0 and b.y<0): hit = a.lerp(b,-a.y/(b.y-a.y))
		else: continue
		var p := Vector2(hit.x,hit.z)
		var unique := true
		for end in ends:
			if end.distance_squared_to(p)<.000000000001: unique = false
		if unique: ends.append(p)
	if ends.size()!=2 or ends[0].distance_squared_to(ends[1])<.000000001: return
	_segments.append(ends)
	var a := Vector3(ends[0].x,0,ends[0].y)
	var b := Vector3(ends[1].x,0,ends[1].y)
	var mid := (ends[0]+ends[1])*.25+Vector2.ONE*.5
	var gradient := Vector2(_value(mid+Vector2(.001,0))-_value(mid-Vector2(.001,0)),_value(mid+Vector2(0,.001))-_value(mid-Vector2(0,.001))).normalized()
	var normal := Vector3(gradient.x,0,gradient.y)
	_quad(surface,[a,b,b+Vector3.DOWN*.14,a+Vector3.DOWN*.14],normal)
	_quad(surface,[a+Vector3.DOWN*.14,b+Vector3.DOWN*.14,b+Vector3.DOWN*bank_depth,a+Vector3.DOWN*bank_depth],normal)


func _build_cutaway(surface: SurfaceTool) -> void:
	# These are exposed sample sections, never shores between adjacent modules.
	for side in 4:
		if not (cutaway_edges & (1<<side)): continue
		for i in subdivisions:
			var a := _sample_vertex(i,0)
			var b := _sample_vertex(i+1,0)
			match side:
				1: a = _sample_vertex(subdivisions,i); b = _sample_vertex(subdivisions,i+1)
				2: a = _sample_vertex(subdivisions-i,subdivisions); b = _sample_vertex(subdivisions-i-1,subdivisions)
				3: a = _sample_vertex(0,subdivisions-i); b = _sample_vertex(0,subdivisions-i-1)
			var points := [a,b]
			if a.y*b.y<0: points.insert(1,a.lerp(b,-a.y/(b.y-a.y)))
			for n in range(points.size()-1):
				var p: Vector3 = points[n]
				var q: Vector3 = points[n+1]
				var top := -water_depth if (p.y+q.y)>0 else 0.0
				var normal := Vector3(q.z-p.z,0,p.x-q.x).normalized()
				_quad(surface,[Vector3(p.x,top,p.z),Vector3(q.x,top,q.z),Vector3(q.x,-.82,q.z),Vector3(p.x,-.82,p.z)],normal)


func _point_key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x*100000),roundi(p.y*100000))


func _join_shore_paths() -> void:
	var neighbours: Dictionary = {}
	var locations: Dictionary = {}
	var used: Dictionary = {}
	for i in _segments.size():
		for p: Vector2 in _segments[i]:
			var key := _point_key(p)
			if not neighbours.has(key): neighbours[key] = []
			neighbours[key].append(i)
			locations[key] = p
	var starts: Array = []
	for key in neighbours:
		if neighbours[key].size()==1: starts.append(key)
	starts.append_array(neighbours.keys())
	for start: Vector2i in starts:
		var path := PackedVector2Array([locations[start]])
		var cursor := start
		while true:
			var next := -1
			for candidate: int in neighbours[cursor]:
				if not used.has(candidate): next = candidate; break
			if next<0: break
			used[next] = true
			var segment: Array = _segments[next]
			cursor = _point_key(segment[1]) if _point_key(segment[0])==cursor else _point_key(segment[0])
			path.append(locations[cursor])
		if path.size()>1: shore_paths.append(path)


static func assemble(parent: Node3D, painter: ExpeditionFlatStyle, lattice: Dictionary, bounds: Rect2i, colors: ExpeditionLotusPalette, depth := .24) -> Node3D:
	var result := Node3D.new()
	result.name = "JoinedIrregularPond"
	parent.add_child(result)
	var source: Script = load("res://src/map/expedition_pond_shape_tile.gd")
	var directions := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var cell := Vector2i(x,y)
			var tile: Node3D = source.new()
			tile.position = Vector3(x*PITCH,0,y*PITCH)
			tile.water_colors = colors
			tile.water_depth = depth
			tile.cutaway_edges = 0
			for side in 4:
				if not bounds.has_point(cell+directions[side]): tile.cutaway_edges |= 1<<side
			for yy in range(-1,3):
				for xx in range(-1,3): tile._control.append(float(lattice.get(cell+Vector2i(xx,yy),-1.0)))
			tile.corner_values = Vector4(lattice.get(cell,-1),lattice.get(cell+Vector2i.RIGHT,-1),lattice.get(cell+Vector2i.ONE,-1),lattice.get(cell+Vector2i.DOWN,-1))
			tile.set_meta("cell",cell)
			result.add_child(tile)
			tile.setup(painter)
	result.set_meta("tile_count",bounds.size.x*bounds.size.y)
	return result
