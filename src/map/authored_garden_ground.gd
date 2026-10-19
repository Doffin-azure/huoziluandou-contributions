extends RefCounted
## One batched land surface, one shoreline and one paving surface for the site.
const PLAN = preload("res://src/expedition/authored_garden_plan.gd")


static func build(parent: Node3D, layout: RefCounted, style: ExpeditionFlatStyle, soil: Material, paving: Material, cooperative := false) -> void:
	var land := SurfaceTool.new(); land.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bank := SurfaceTool.new(); bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bounds: Rect2 = PLAN.rect(layout.site.bounds)
	var step := .5
	var values := {}
	var deadline := Time.get_ticks_usec()+4000
	for x in range(floori(bounds.position.x/step),ceili(bounds.end.x/step)+1):
		for z in range(floori(bounds.position.y/step),ceili(bounds.end.y/step)+1):
			var p := Vector2(x,z)*step
			values[Vector2i(x,z)] = PLAN.water_distance(p,layout.site)
		if cooperative and Time.get_ticks_usec()>deadline:
			await parent.get_tree().process_frame; deadline = Time.get_ticks_usec()+4000
	for x in range(floori(bounds.position.x/step),ceili(bounds.end.x/step)):
		for z in range(floori(bounds.position.y/step),ceili(bounds.end.y/step)):
			var corners: Array = []
			for delta in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.ONE,Vector2i.DOWN]:
				var key: Vector2i = Vector2i(x,z)+delta; var p := Vector2(key)*step
				corners.append(Vector3(p.x,values[key],p.y))
			for indices in [[0,1,2],[0,2,3]]:
				var clipped := _dry([corners[indices[0]],corners[indices[1]],corners[indices[2]]])
				for i in range(1,clipped.size()-1):
					_triangle(land,_flat(clipped[0],-.025),_flat(clipped[i],-.025),_flat(clipped[i+1],-.025))
		if cooperative and Time.get_ticks_usec()>deadline:
			await parent.get_tree().process_frame; deadline = Time.get_ticks_usec()+4000
	var polygon := PLAN.polygon(layout.site.pond_polygon)
	for i in polygon.size():
		var a := polygon[i]; var b := polygon[(i+1)%polygon.size()]
		var at := Vector3(a.x,-.025,a.y); var to := Vector3(b.x,-.025,b.y)
		_triangle(bank,at,to,to-Vector3.UP*.70)
		_triangle(bank,at,to-Vector3.UP*.70,at-Vector3.UP*.70)
	_mesh(parent,land.commit(),soil,"UnifiedGardenLand")
	_mesh(parent,bank.commit(),style.face_material("stone"),"ContinuousRecessedBank")
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tile: float = layout.walk_step
	# Quarter-grid cells are centers, not their bottom-left corners. Coalesce
	# adjacent cells into strips so this is one mesh, not thousands of tiles.
	var rows := {}
	for cell: Vector2i in layout.cells:
		if not rows.has(cell.y): rows[cell.y] = []
		rows[cell.y].append(cell.x)
	for z: int in rows:
		rows[z].sort(); var first: int = rows[z][0]; var last := first
		for x: int in rows[z].slice(1)+[rows[z][-1]+2]:
			if x==last+1: last = x; continue
			var a := Vector3(layout.grid_origin.x+first*tile-tile*.5,0,layout.grid_origin.y+z*tile-tile*.5)
			var b := Vector3(layout.grid_origin.x+last*tile+tile*.5,0,layout.grid_origin.y+z*tile+tile*.5)
			_triangle(surface,a,Vector3(b.x,0,a.z),b)
			_triangle(surface,a,b,Vector3(a.x,0,b.z))
			first = x; last = x
	_mesh(parent,surface.commit(),paving,"SharedPavedFloor")


static func _dry(points: Array) -> Array:
	var result: Array = []
	for i in points.size():
		var a: Vector3 = points[i]; var b: Vector3 = points[(i+1)%points.size()]
		if a.y<=0: result.append(a)
		if (a.y<=0)!=(b.y<=0): result.append(a.lerp(b,a.y/(a.y-b.y)))
	return result


static func _flat(p: Vector3, y: float) -> Vector3: return Vector3(p.x,y,p.z)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.length_squared()<.1: return
	if absf(normal.y)>.5 and normal.y<0: normal = -normal
	for p in [a,b,c]: surface.set_normal(normal); surface.add_vertex(p)


static func _mesh(parent: Node3D, mesh: ArrayMesh, material: Material, title: String) -> void:
	var instance := MeshInstance3D.new(); instance.name = title; instance.mesh = mesh; instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
