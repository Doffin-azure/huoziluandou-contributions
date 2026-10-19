extends Node3D
## Crooked underworld pine: weathered trunk, sparse needles and tapered ink.
const DRAWING = preload("res://src/map/expedition_tree_drawing.gd")
const INK_SHADER = preload("res://src/shaders/expedition_tree_ink.gdshader")
const UNIT := .006
const ORIGIN := Vector2(180,388)
var palette: ExpeditionFlatPalette
var art: Node3D
var contour: Node3D
var details: Node3D
var fills: Node3D
var _style: ExpeditionFlatStyle
var _camera: Camera3D
var _inks: Dictionary = {}
var _tokens: RegEx
var _initialized := false


func setup(painter: ExpeditionFlatStyle, camera: Camera3D) -> void:
	if _initialized: return
	_initialized = true
	_style = painter
	palette = painter.palette
	_camera = camera
	_root_stone()
	art = Node3D.new()
	art.name = "TreeDrawing"
	add_child(art)
	fills = Node3D.new()
	fills.name = "ColorPlanes"
	art.add_child(fills)
	contour = Node3D.new()
	contour.name = "OuterInk"
	art.add_child(contour)
	details = Node3D.new()
	details.name = "InteriorInk"
	art.add_child(details)
	_tokens = RegEx.new()
	_tokens.compile("[MLCQZ]|-?(?:[0-9]*\\.)?[0-9]+")
	for shape: Dictionary in DRAWING.SHAPES:
		var points := _path(shape.d)
		_fill(points,float(shape.z),str(shape.role))
		if float(shape.get("ink",0))>0:
			_stroke(points,float(shape.z)+.0015,float(shape.ink),true,contour)
	for stroke: Dictionary in DRAWING.STROKES:
		_stroke(_path(stroke.d),float(stroke.z),float(stroke.weight),false,details)
	for fan: Array in DRAWING.NEEDLE_FANS:
		var root := Vector2(fan[0],fan[1])
		for index in 5:
			var angle: float = float(fan[2])+(index-2)*.22
			var length: float = float(fan[3])*(1.0-absf(index-2)*.10)
			var tip := root+Vector2(cos(angle),sin(angle))*length
			_stroke(PackedVector2Array([root,root.lerp(tip,.48)+Vector2(-1,-.5),tip]),.058,.17,false,details)
	sync_camera()
	palette.changed.connect(refresh_palette)
	refresh_palette()


func _exit_tree() -> void:
	if palette != null and palette.changed.is_connected(refresh_palette): palette.changed.disconnect(refresh_palette)


func sync_camera() -> void:
	# A fixed foot point and camera-facing painted planes, as with the other cutout actors.
	if art!=null and _camera!=null: art.global_basis = _camera.global_basis


func _point(value: Vector2, depth: float) -> Vector3:
	return Vector3((value.x-ORIGIN.x)*UNIT,(ORIGIN.y-value.y)*UNIT,depth)


func _root_stone() -> void:
	var ring := [Vector3(-.41,.01,-.15),Vector3(-.20,.045,-.31),Vector3(.12,.035,-.27),Vector3(.34,.02,-.05),Vector3(.22,.005,.20),Vector3(-.18,.01,.25),Vector3(-.40,.01,.10)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in ring.size():
		var a: Vector3 = ring[index]
		var b: Vector3 = ring[(index+1)%ring.size()]
		var low_a := Vector3(a.x*.92,-.12,a.z*.92)
		var low_b := Vector3(b.x*.92,-.12,b.z*.92)
		var normal := Vector3(a.x+b.x,0,a.z+b.z).normalized()
		for tri in [[Vector3(-.04,.052,-.02),a,b,Vector3.UP],[a,low_a,low_b,normal],[a,low_b,b,normal]]:
			var vertices := [tri[0],tri[2],tri[1]] if (tri[1]-tri[0]).cross(tri[2]-tri[0]).dot(tri[3])>0 else [tri[0],tri[1],tri[2]]
			for vertex: Vector3 in vertices:
				surface.set_normal(tri[3])
				surface.add_vertex(vertex)
	_style.mesh(self,surface.commit(),Vector3(0,-.025,0),"architecture",.5)


func _path(data: String) -> PackedVector2Array:
	var values := PackedStringArray()
	for result: RegExMatch in _tokens.search_all(data): values.append(result.get_string())
	var points := PackedVector2Array()
	var cursor := Vector2.ZERO
	var first := Vector2.ZERO
	var index := 0
	while index<values.size():
		var command := values[index]
		index += 1
		if command=="Z":
			if not cursor.is_equal_approx(first): points.append(first)
			continue
		var count: int = {"M":2,"L":2,"C":6,"Q":4}.get(command,0)
		assert(count>0 and index+count<=values.size(),"Invalid tree drawing path")
		var p := Vector2(float(values[index]),float(values[index+1]))
		if command in ["M","L"]:
			cursor = p
			points.append(p)
			if command=="M": first = p
		elif command=="C":
			var control_b := Vector2(float(values[index+2]),float(values[index+3]))
			var target := Vector2(float(values[index+4]),float(values[index+5]))
			for n in range(1,11): points.append(cursor.bezier_interpolate(p,control_b,target,n/10.0))
			cursor = target
		elif command=="Q":
			var target := Vector2(float(values[index+2]),float(values[index+3]))
			for n in range(1,11):
				var t := n/10.0
				points.append(lerp(cursor.lerp(p,t),p.lerp(target,t),t))
			cursor = target
		index += count
	return points


func _fill(points: PackedVector2Array, depth: float, role: String) -> void:
	var polygon := points.duplicate()
	if polygon[0].is_equal_approx(polygon[-1]): polygon.resize(polygon.size()-1)
	var indices := Geometry2D.triangulate_polygon(polygon)
	assert(not indices.is_empty(),"Tree color shape must form a simple closed polygon")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(0,indices.size(),3):
		var a := _point(polygon[indices[n]],depth)
		var b := _point(polygon[indices[n+1]],depth)
		var c := _point(polygon[indices[n+2]],depth)
		var tri := [a,c,b] if (b-a).cross(c-a).z>0 else [a,b,c]
		for vertex: Vector3 in tri:
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(vertex)
	var node := MeshInstance3D.new()
	node.name = role
	node.mesh = surface.commit()
	node.material_override = _style.face_material(role)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fills.add_child(node)


func _stroke(points: PackedVector2Array, depth: float, weight: float, closed: bool, parent: Node3D) -> void:
	var count := points.size()-1 if closed else points.size()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(count if closed else count-1):
		var next := (index+1)%count
		for corner: Vector2i in [Vector2i(index,-1),Vector2i(next,-1),Vector2i(next,1),Vector2i(index,-1),Vector2i(next,1),Vector2i(index,1)]:
			var n := corner.x
			var before := (n-1+count)%count if closed else maxi(0,n-1)
			var after := (n+1)%count if closed else mini(count-1,n+1)
			var direction := (_point(points[after],depth)-_point(points[before],depth)).normalized()
			var taper := 1.0 if closed else .12+.88*pow(sin(PI*n/float(count-1)),.38)
			surface.set_color(Color(taper,1,1,1))
			surface.set_normal(direction)
			surface.set_uv(Vector2(0,corner.y))
			surface.add_vertex(_point(points[n],depth))
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	if not _inks.has(weight):
		var material := ShaderMaterial.new()
		material.shader = INK_SHADER
		_inks[weight] = material
	node.material_override = _inks[weight]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)


func refresh_palette() -> void:
	for weight in _inks:
		_inks[weight].set_shader_parameter("ink_color",palette.tree_ink)
		_inks[weight].set_shader_parameter("half_width_pixels",palette.tree_outline_pixels*float(weight))
