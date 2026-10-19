extends RefCounted
## A continuous paved ribbon. Only exposed outer corners are clipped; shared
## edges have neither a seam wall nor a separate tile border. Navigation stays
## on the original four-way grid.
const DIRS := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
const CORNERS := [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(.5,.5),Vector2(-.5,.5)]


static func build(plan: RefCounted, cells: Array, bridge_cells := {}) -> Dictionary:
	var top := SurfaceTool.new(); top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := SurfaceTool.new(); sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := SurfaceTool.new(); rim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0; var rim_count := 0; var side_count := 0
	for cell: Vector2i in cells:
		var center := Vector2(cell)
		var corridor := str(plan.cells[cell]).is_empty()
		var polygon: Array[Vector2] = []
		for i in 4:
			var corner: Vector2 = CORNERS[i]
			var before: Vector2 = CORNERS[(i+3)%4]; var after: Vector2 = CORNERS[(i+1)%4]
			var convex: bool = corridor and not plan.cells.has(cell+DIRS[(i+3)%4]) and not plan.cells.has(cell+DIRS[i])
			if convex:
				polygon.append(center+corner+(before-corner).normalized()*.16)
				polygon.append(center+corner+(after-corner).normalized()*.16)
			else: polygon.append(center+corner)
		for i in polygon.size():
			var a := polygon[i]; var b := polygon[(i+1)%polygon.size()]
			_triangle(top,Vector3(center.x,0,center.y),Vector3(a.x,0,a.y),Vector3(b.x,0,b.y),Vector3.UP)
			var middle := (a+b)*.5; var outward := (middle-center).normalized()
			var neighbor := Vector2i((middle+outward*.08).round())
			if plan.cells.has(neighbor) and neighbor!=cell: continue
			# The actual bridge kit supplies the open underside, curbs and piers.
			# A solid slab here would hide those models behind a stone curtain.
			if bridge_cells.has(cell): continue
			# Room perimeters are already framed by their walls. Corridors get a
			# low continuous kerb, including the bevel at an exposed L corner.
			var normal := Vector3(outward.x,0,outward.y)
			_quad(sides,Vector3(a.x,0,a.y),Vector3(b.x,0,b.y),Vector3(b.x,-.36,b.y),Vector3(a.x,-.36,a.y),normal); side_count += 1
			if corridor:
				var inward := (center-middle).normalized()*.045
				_quad(rim,Vector3(a.x,.008,a.y),Vector3(b.x,.008,b.y),Vector3(b.x+inward.x,.008,b.y+inward.y),Vector3(a.x+inward.x,.008,a.y+inward.y),Vector3.UP); rim_count += 1
		count += 1
	return {"top":top.commit() if count>0 else null,"sides":sides.commit() if side_count>0 else null,"rim":rim.commit() if rim_count>0 else null}


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b-a).cross(c-a).dot(normal)>0:
		var temporary := b; b = c; c = temporary
	for point in [a,b,c]: surface.set_normal(normal); surface.add_vertex(point)


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_triangle(surface,a,b,c,normal); _triangle(surface,a,c,d,normal)
