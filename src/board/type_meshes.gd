extends RefCounted
class_name TypeMeshes
## 小倒角保留木块边缘的真实受光；所有面用同一份共享几何。
static func beveled_box(dimensions: Vector3, bevel: float) -> ArrayMesh:
	var half := dimensions * 0.5
	var amount := minf(bevel, minf(half.x, minf(half.y, half.z)) * 0.7)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var axis_a := (axis + 1) % 3
		var axis_b := (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var vertices: Array[Vector3] = []
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var vertex := Vector3.ZERO
				vertex[axis] = half[axis] * sign_value
				vertex[axis_a] = (half[axis_a] - amount) * corner.x
				vertex[axis_b] = (half[axis_b] - amount) * corner.y
				vertices.append(vertex)
			_quad(surface, vertices, normal, dimensions)
	for axis_a in 3:
		for axis_b in range(axis_a + 1, 3):
			var free_axis := 3 - axis_a - axis_b
			for sign_a in [-1.0, 1.0]:
				for sign_b in [-1.0, 1.0]:
					var vertices: Array[Vector3] = []
					for index in 4:
						var vertex := Vector3.ZERO
						vertex[axis_a] = sign_a * (half[axis_a] - (amount if index == 1 or index == 2 else 0.0))
						vertex[axis_b] = sign_b * (half[axis_b] - (amount if index == 0 or index == 3 else 0.0))
						vertex[free_axis] = (half[free_axis] - amount) * (-1.0 if index < 2 else 1.0)
						vertices.append(vertex)
					var normal := Vector3.ZERO
					normal[axis_a] = sign_a
					normal[axis_b] = sign_b
					_quad(surface, vertices, normal.normalized(), dimensions)
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var normal := Vector3(x, y, z)
				var base := normal * (half - Vector3.ONE * amount)
				_triangle(surface, base + Vector3(x * amount, 0, 0), base + Vector3(0, y * amount, 0), base + Vector3(0, 0, z * amount), normal.normalized(), dimensions)
	surface.generate_tangents()
	return surface.commit()


static func _quad(surface: SurfaceTool, vertices: Array[Vector3], normal: Vector3, dimensions: Vector3) -> void:
	_triangle(surface, vertices[0], vertices[1], vertices[2], normal, dimensions)
	_triangle(surface, vertices[0], vertices[2], vertices[3], normal, dimensions)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, dimensions: Vector3) -> void:
	# Godot 使用顺时针前面；倒角面也显式指定朝外法线。
	var vertices: Array = [a, c, b] if (b - a).cross(c - a).dot(normal) > 0 else [a, b, c]
	for vertex in vertices:
		var uv := Vector2(vertex.x / dimensions.x + 0.5, vertex.z / dimensions.z + 0.5)
		if absf(normal.x) > 0.75:
			uv = Vector2(vertex.z / dimensions.z + 0.5, vertex.y / dimensions.y + 0.5)
		elif absf(normal.z) > 0.75:
			uv = Vector2(vertex.x / dimensions.x + 0.5, vertex.y / dimensions.y + 0.5)
		surface.set_normal(normal)
		surface.set_uv(uv)
		surface.add_vertex(vertex)
