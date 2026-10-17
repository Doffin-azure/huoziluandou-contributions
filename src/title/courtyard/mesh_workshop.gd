extends RefCounted
## Model authoring helpers. Merge by material instead of retaining thousands of draw calls.
var _surfaces: Dictionary = {}
var _materials: Dictionary = {}
var _unit_box := BoxMesh.new()
var _cylinder_cache: Dictionary = {}
var parts := 0


func add(mesh: Mesh, material: Material, transform := Transform3D.IDENTITY, group := "Architecture") -> void:
	var key := group + str(material.get_instance_id())
	if not _surfaces.has(key):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = surface
		_materials[key] = material
	_surfaces[key].append_from(mesh, 0, transform)
	parts += 1


func box(center: Vector3, dimensions: Vector3, material: Material, rotation := Vector3.ZERO, group := "Timber") -> void:
	add(_unit_box, material, Transform3D(Basis.from_euler(rotation) * Basis.from_scale(dimensions), center), group)


func beam(a: Vector3, b: Vector3, width: float, depth: float, material: Material, group := "Joinery") -> void:
	var direction := b - a
	var basis := Basis(Quaternion(Vector3.UP, direction.normalized())) * Basis.from_scale(Vector3(width, direction.length(), depth))
	add(_unit_box, material, Transform3D(basis, (a + b) * 0.5), group)


func cylinder(center: Vector3, radius: float, height: float, material: Material, taper := 1.0, group := "Columns") -> void:
	var key := str(taper)
	if not _cylinder_cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 20
		mesh.rings = 1
		mesh.top_radius = 0.5 * taper
		mesh.bottom_radius = 0.5
		mesh.height = 1.0
		_cylinder_cache[key] = mesh
	add(_cylinder_cache[key], material, Transform3D(Basis.IDENTITY.scaled(Vector3(radius * 2, height, radius * 2)), center), group)


func finish(parent: Node3D) -> void:
	for key in _surfaces:
		var surface: SurfaceTool = _surfaces[key]
		surface.generate_tangents()
		var instance := MeshInstance3D.new()
		instance.name = str(key).left(40)
		instance.mesh = surface.commit()
		instance.material_override = _materials[key]
		# The reflected camera must not see the underside of the world foundation.
		if str(key).begins_with("Foundation"): instance.layers = 4
		parent.add_child(instance)
		instance.owner = parent
	parent.set_meta("modelled_parts", parts)


static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for item in [[a, uv_a], [b, uv_b], [c, uv_c]]:
		surface.set_normal(normal)
		surface.set_uv(item[1])
		surface.add_vertex(item[0])


static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_scale := 1.0) -> void:
	triangle(surface, a, b, c, Vector2(a.x, a.z) * uv_scale, Vector2(b.x, b.z) * uv_scale, Vector2(c.x, c.z) * uv_scale)
	triangle(surface, a, c, d, Vector2(a.x, a.z) * uv_scale, Vector2(c.x, c.z) * uv_scale, Vector2(d.x, d.z) * uv_scale)


static func roof_height(x: float, z: float, width: float, depth: float, rise: float) -> float:
	var t := absf(z) / (depth * 0.5)
	var end := pow(absf(x) / (width * 0.5), 8)
	return rise * (1.0 - t) + 0.38 * pow(t, 5) + 0.34 * end * pow(t, 4)


func roof(origin: Vector3, width: float, depth: float, rise: float, tile: Material, timber: Material) -> void:
	var under := SurfaceTool.new()
	under.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiles := SurfaceTool.new()
	tiles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := ceili(width / 0.19)
	var rows := ceili(depth * 0.5 / 0.30)
	for side in [-1.0, 1.0]:
		for i in cols:
			var x := -width * 0.5 + (i + 0.5) * width / cols
			for row in rows:
				var near_z: float = side * (row * depth * 0.5 / rows)
				var far_z: float = side * (minf(depth * 0.5, (row + 1) * depth * 0.5 / rows + 0.065))
				for arc in 6:
					var x0 := x + cos(PI * arc / 6.0) * 0.095
					var x1 := x + cos(PI * (arc + 1) / 6.0) * 0.095
					var y0 := sin(PI * arc / 6.0) * 0.065
					var y1 := sin(PI * (arc + 1) / 6.0) * 0.065
					var a := origin + Vector3(x0, roof_height(x0, near_z, width, depth, rise) + y0, near_z)
					var b := origin + Vector3(x1, roof_height(x1, near_z, width, depth, rise) + y1, near_z)
					var c := origin + Vector3(x1, roof_height(x1, far_z, width, depth, rise) + y1, far_z)
					var d := origin + Vector3(x0, roof_height(x0, far_z, width, depth, rise) + y0, far_z)
					if side < 0: quad(tiles, a, b, c, d, 1.3)
					else: quad(tiles, d, c, b, a, 1.3)
		# A complete timber soffit, visible from the covered foreground.
		for i in 24:
			var x0 := -width * 0.5 + width * i / 24.0
			var x1 := -width * 0.5 + width * (i + 1) / 24.0
			var a := origin + Vector3(x0, rise - 0.11, 0)
			var b := origin + Vector3(x1, rise - 0.11, 0)
			var c := origin + Vector3(x1, roof_height(x1, depth * side * 0.5, width, depth, rise) - 0.11, depth * side * 0.5)
			var d := origin + Vector3(x0, roof_height(x0, depth * side * 0.5, width, depth, rise) - 0.11, depth * side * 0.5)
			if side < 0: quad(under, d, c, b, a)
			else: quad(under, a, b, c, d)
		for edge_index in 24:
			var x0 := -width * 0.5 + width * edge_index / 24.0
			var x1 := -width * 0.5 + width * (edge_index + 1) / 24.0
			var z: float = side * depth * 0.5
			beam(origin + Vector3(x0, roof_height(x0, z, width, depth, rise) - 0.05, z), origin + Vector3(x1, roof_height(x1, z, width, depth, rise) - 0.05, z), 0.14, 0.16, timber, "CurvedFascia")
		for rafter in range(1, cols, 2):
			var x := -width * 0.5 + rafter * width / cols
			beam(origin + Vector3(x, rise - 0.17, 0), origin + Vector3(x, roof_height(x, side * depth * 0.5, width, depth, rise) - 0.18, side * depth * 0.5), 0.09, 0.11, timber, "RafterEnds")
	add(tiles.commit(), tile, Transform3D.IDENTITY, "IndividualRoofTiles")
	add(under.commit(), timber, Transform3D.IDENTITY, "RoofSoffits")
	beam(origin + Vector3(-width * 0.5 - 0.15, rise + 0.11, 0), origin + Vector3(width * 0.5 + 0.15, rise + 0.11, 0), 0.16, 0.22, tile, "RidgeCaps")
