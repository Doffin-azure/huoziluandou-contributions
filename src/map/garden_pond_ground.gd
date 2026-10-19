extends RefCounted
## Reuses the production pond transition mesh. Dry caps, flush rims and recessed
## banks all evaluate one shared field; no solid floor remains under the water.
const TILE = preload("res://src/map/expedition_pond_shape_tile.gd")
const FIELD = preload("res://src/expedition/garden_pond_field.gd")


static func build(parent: Node3D, bounds: Rect2, ponds: Array, style: ExpeditionFlatStyle, land_paint: Material, shore_paint: Material, base_y := 0.0) -> Node3D:
	var root := Node3D.new(); root.name = "ContinuousInnerPondGround"; root.position.y = base_y; parent.add_child(root)
	var flat := SurfaceTool.new(); flat.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flat_count := 0
	for z in ceili(bounds.size.y/2.0):
		for x in ceili(bounds.size.x/2.0):
			var start := bounds.position+Vector2(x,z)*2
			var extent := (bounds.end-start).min(Vector2.ONE*2)
			var center := start+extent*.5
			var near := ponds.any(func(pond): return Rect2(pond.center-pond.radius*1.22,pond.radius*2.44).intersects(Rect2(start,extent)))
			if not near:
				_quad(flat,Vector3(start.x,0,start.y),Vector3(start.x+extent.x,0,start.y),Vector3(start.x+extent.x,0,start.y+extent.y),Vector3(start.x,0,start.y+extent.y))
				flat_count += 1; continue
			var tile := TILE.new()
			tile.cutaway_edges = 0; tile.include_water = false; tile.include_ink = false
			tile.subdivisions = 12; tile.water_depth = .45+base_y; tile.bank_depth = .72
			tile.position = Vector3(center.x,0,center.y); tile.scale = Vector3(extent.x*.5,1,extent.y*.5)
			tile.surface_sampler = func(uv: Vector2): return FIELD.sample(ponds,start+uv*extent)
			root.add_child(tile); tile.setup(style)
			if tile.land!=null: tile.land.material_override = land_paint
			if tile.rim!=null: tile.rim.material_override = shore_paint
			for mesh: MeshInstance3D in tile.find_children("*","MeshInstance3D",true,false):
				if mesh.name=="RecessedShoreWall": mesh.material_override = shore_paint
	if flat_count>0:
		var mesh := MeshInstance3D.new(); mesh.mesh = flat.commit(); mesh.material_override = land_paint; root.add_child(mesh)
	return root


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point in [a,b,c,a,c,d]:
		surface.set_normal(Vector3.UP); surface.add_vertex(point)
