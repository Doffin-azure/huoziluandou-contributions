extends "res://src/title/courtyard/mesh_workshop.gd"
## Small-scale modelling primitives; merged into a handful of material surfaces.


func rounded(center: Vector3, dimensions: Vector3, radius: float, material: Material, rotation := Vector3.ZERO) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := dimensions * 0.5
	var r := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.9)
	var core := half - Vector3.ONE * r
	for axis in 3:
		for side in [-1.0, 1.0]:
			var u := (axis + 1) % 3
			var v := (axis + 2) % 3
			var us := [-half[u], -core[u], core[u], half[u]]
			var vs := [-half[v], -core[v], core[v], half[v]]
			for i in 3:
				for j in 3:
					var points: Array[Vector3] = []
					for uv in [Vector2(us[i], vs[j]), Vector2(us[i + 1], vs[j]), Vector2(us[i + 1], vs[j + 1]), Vector2(us[i], vs[j + 1])]:
						var p := Vector3.ZERO
						p[axis] = half[axis] * side
						p[u] = uv.x
						p[v] = uv.y
						points.append(p)
					for k in ([0, 2, 1, 0, 3, 2] if side > 0 else [0, 1, 2, 0, 2, 3]):
						var p := points[k]
						var nearest := p.clamp(-core, core)
						var normal := (p - nearest).normalized()
						surface.set_normal(normal)
						surface.set_uv(Vector2(p[u], p[v]))
						surface.add_vertex(nearest + normal * r)
	surface.index()
	add(surface.commit(), material, Transform3D(Basis.from_euler(rotation), center), "Relic")


func lathe(profile: Array, material: Material, center := Vector3.ZERO, rotation := Vector3.ZERO) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in profile.size() - 1:
		for sector in 48:
			for ij in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var index: int = row + ij.y
				var a: float = TAU * (sector + ij.x) / 48.0
				var p: Vector2 = profile[index]
				var slope: Vector2 = profile[mini(index + 1, profile.size() - 1)] - profile[maxi(index - 1, 0)]
				surface.set_normal(Vector3(cos(a) * slope.y, -slope.x, sin(a) * slope.y).normalized())
				surface.set_uv(Vector2(float(sector + ij.x) / 48.0, p.y))
				surface.add_vertex(Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
	surface.index()
	add(surface.commit(), material, Transform3D(Basis.from_euler(rotation), center), "Relic")


func ring(center: Vector3, radius: float, tube: float, material: Material, rotation := Vector3.ZERO) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	mesh.rings = 48
	mesh.ring_segments = 10
	add(mesh, material, Transform3D(Basis.from_euler(rotation), center), "Relic")


func rod(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	add(mesh, material, Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) * 0.5), "Relic")


func orb(center: Vector3, dimensions: Vector3, material: Material, rotation := Vector3.ZERO) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 32
	mesh.rings = 16
	add(mesh, material, Transform3D(Basis.from_euler(rotation).scaled_local(dimensions), center), "Relic")


func silhouette(points: PackedVector2Array, depth: float, material: Material, center := Vector3.ZERO, rotation := Vector3.ZERO) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(points)
	for side in [-1.0, 1.0]:
		for t in range(0, indices.size(), 3):
			for k in ([0, 1, 2] if side < 0 else [2, 1, 0]):
				var p := points[indices[t + k]]
				surface.set_normal(Vector3(0, 0, side))
				surface.set_uv(p)
				surface.add_vertex(Vector3(p.x, p.y, side * depth * 0.5))
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		quad(surface, Vector3(a.x, a.y, -depth * 0.5), Vector3(b.x, b.y, -depth * 0.5), Vector3(b.x, b.y, depth * 0.5), Vector3(a.x, a.y, depth * 0.5))
	surface.index()
	add(surface.commit(), material, Transform3D(Basis.from_euler(rotation), center), "Relic")


func leaf(a: Vector3, b: Vector3, width: float, material: Material, vein: Material) -> void:
	var delta := b - a
	var normal := Vector3(0, 0, 1)
	var across := delta.cross(normal).normalized() * width
	var middle := a.lerp(b, 0.48)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	quad(surface, a, middle + across, b, middle + Vector3(0, 0, 0.035))
	quad(surface, a, middle + Vector3(0, 0, 0.035), b, middle - across)
	surface.index()
	add(surface.commit(), material, Transform3D.IDENTITY, "Relic")
	rod(a, b, 0.008, vein)
	for i in range(1, 4):
		var root := a.lerp(b, i * 0.2)
		for side in [-1.0, 1.0]: rod(root, root + delta * 0.13 + across * side * 0.5, 0.004, vein)


static func _flame_point(t: float, angle: float, height: float, width: float, lean: float) -> Vector3:
	var radius := width * pow(maxf(0, sin(PI * t)), 0.72) * (1.0 - t * 0.7)
	return Vector3(lean * t * t + cos(angle) * radius, height * t, sin(angle) * radius * 0.55)


func tongue(center: Vector3, height: float, width: float, lean: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 32:
		for sector in 32:
			for ij in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var t: float = (row + ij.y) / 32.0
				var a: float = TAU * (sector + ij.x) / 32.0
				var along := _flame_point(minf(t + 0.002, 1.0), a, height, width, lean) - _flame_point(maxf(t - 0.002, 0), a, height, width, lean)
				var around := _flame_point(clampf(t, 0.001, 0.999), a + 0.002, height, width, lean) - _flame_point(clampf(t, 0.001, 0.999), a - 0.002, height, width, lean)
				surface.set_normal(along.cross(around).normalized())
				surface.set_uv(Vector2(a / TAU, t))
				surface.add_vertex(_flame_point(t, a, height, width, lean))
	surface.index()
	add(surface.commit(), material, Transform3D(Basis.IDENTITY, center), "Relic")


func cloth_surface(center: Vector3, width: float, depth: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 20:
		for col in 28:
			for ij in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var x: float = ((col + ij.x) / 28.0 - 0.5) * width
				var z: float = ((row + ij.y) / 20.0 - 0.5) * depth
				var y := sin(x * 18.0 + z * 5.0) * 0.009 + sin(z * 30.0) * 0.004
				var dx := cos(x * 18.0 + z * 5.0) * 0.162
				var dz := cos(x * 18.0 + z * 5.0) * 0.045 + cos(z * 30.0) * 0.12
				surface.set_normal(Vector3(-dx, 1, -dz).normalized())
				surface.set_uv(Vector2(x, z))
				surface.add_vertex(Vector3(x, y, z))
	surface.index()
	add(surface.commit(), material, Transform3D(Basis.IDENTITY, center), "Relic")
