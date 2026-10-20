extends RefCounted
## Square-holed bronze cash, stacked and scattered directly on the reward counter.
const Workshop := preload("res://src/ui/object_stage/relic_mesh.gd")
const FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")


static func build(stage: Node3D, amount: int) -> Node3D:
	var node := Node3D.new()
	node.name = "RewardCoins"
	node.set_meta("gold_amount", amount)
	var w := Workshop.new()
	var palette: Dictionary = preload("res://src/ui/object_stage/relic_specimen.gd")._palette(stage)
	var metal: Material = palette.edge
	var edge: Material = palette.bronze
	var mesh := _coin()
	for pile in 3:
		var at := Vector3((pile - 1) * 0.48, 0, -0.12 if pile == 1 else 0.10)
		var count := 5 - pile
		for layer in count:
			var center := at + Vector3(sin(layer * 2.1 + pile) * 0.018, 0.035 + layer * 0.072, 0)
			w.add(mesh, metal, Transform3D(Basis(Vector3.UP, layer * 0.17), center), "Cash")
			w.ring(center + Vector3(0, 0.033, 0), 0.295, 0.012, edge)
		_inscription(w, at + Vector3(0, 0.074 * count, 0), palette.dark)
	# An upright coin exposes the square hole and engraved face at gameplay distance.
	w.add(mesh, metal, Transform3D(Basis.from_euler(Vector3(1.12, 0, -0.2)), Vector3(-0.50, 0.30, 0.48)), "Cash")
	w.finish(node)
	return node


static func _inscription(w, at: Vector3, material: Material) -> void:
	for i in 4:
		var text := TextMesh.new()
		text.font = FONT
		text.text = ["炼", "字", "通", "宝"][i]
		text.font_size = 48
		text.pixel_size = 0.0022
		text.depth = 0.004
		var offset: Vector3 = [Vector3(0, 0, -0.18), Vector3(0, 0, 0.18), Vector3(0.18, 0, 0), Vector3(-0.18, 0, 0)][i]
		w.add(text, material, Transform3D(Basis(Vector3.RIGHT, -PI / 2), at + offset), "Inscription")


static func _coin() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sector in 48:
		var points: Array[Vector3] = []
		for a in [TAU * sector / 48.0, TAU * (sector + 1) / 48.0]:
			var d := Vector3(cos(a), 0, sin(a))
			points.append(d * 0.31)
			points.append(d * (0.075 / maxf(absf(d.x), absf(d.z))))
		for side in [-1.0, 1.0]:
			var lift := Vector3(0, side * 0.03, 0)
			var order := [0, 3, 1, 0, 2, 3] if side > 0 else [0, 1, 3, 0, 3, 2]
			for index in order:
				surface.set_normal(Vector3.UP * side)
				surface.set_uv(Vector2(points[index].x, points[index].z))
				surface.add_vertex(points[index] + lift)
		for pair in [[0, 2], [3, 1]]:
			var a: Vector3 = points[pair[0]]
			var b: Vector3 = points[pair[1]]
			var normal := Vector3.UP.cross(b - a).normalized()
			for index in [0, 2, 1, 0, 3, 2]:
				var vertices := [a + Vector3.UP * 0.03, b + Vector3.UP * 0.03, b - Vector3.UP * 0.03, a - Vector3.UP * 0.03]
				surface.set_normal(normal)
				surface.set_uv(Vector2(index % 2, index / 2))
				surface.add_vertex(vertices[index])
	surface.index()
	return surface.commit()
