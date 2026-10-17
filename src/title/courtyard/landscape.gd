extends Node3D
const Workshop := preload("res://src/title/courtyard/mesh_workshop.gd")
const Materials := preload("res://src/title/courtyard/material_library.gd")
@export_range(0.5, 3.0) var blossom_scale := 1.0
var model := Workshop.new()
var rng := RandomNumberGenerator.new()
var bark: StandardMaterial3D
var flowers: Array[StandardMaterial3D] = []
var _flower_mesh: ArrayMesh


func _ready() -> void:
	rng.seed = 20261016
	bark = Materials.new().wood.duplicate()
	bark.albedo_color = Color("9a8a79")
	bark.set_meta("wind_mode", 2)
	for color in ["c9a8aa", "d3b2b4", "e6c7c4", "b88894"]:
		var material: StandardMaterial3D = Materials.plain(Color(color), 0.85)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.backlight_enabled = true
		material.backlight = Color(0.12, 0.07, 0.07)
		flowers.append(material)
	_flower_mesh = _make_flower()
	_tree(Vector3(-6.0, 0.24, -11.8), 1.0)
	_tree(Vector3(4.7, 0.24, -13.1), 1.10)
	_tree(Vector3(-11.8, 0.0, -8.3), 1.25)
	_tree(Vector3(13.2, 0.0, -15.0), 1.5)
	_tree(Vector3(-8.8, 0.0, -20.8), 1.4)
	_tree(Vector3(2.3, 0.0, -23.5), 1.6)
	_mountains()
	_lantern(Vector3(5.95, 3.1, -1.2), 0.72)
	_lantern(Vector3(5.95, 2.2, -1.2), 0.56)
	_lantern(Vector3(-3.4, 3.55, -12.1), 0.55)
	_lantern(Vector3(1.45, 3.55, -12.1), 0.55)
	model.finish(self)


func _branch(a: Vector3, b: Vector3, radius: float, taper := 0.72) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * taper
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	mesh.rings = 1
	var basis := Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	model.add(mesh, bark, Transform3D(basis, (a + b) * 0.5), "TreeBranches")


func _tree(origin: Vector3, scale_factor: float) -> void:
	var turn := Basis(Vector3.UP, rng.randf_range(-0.6, 0.6))
	var stem: Array[Vector3] = [Vector3.ZERO, Vector3(0.12, 0.75, 0.05), Vector3(-0.1, 1.8, -0.1), Vector3(0.10, 2.75, -0.17), Vector3(-0.12, 3.65, -0.1)]
	for i in 4: _branch(origin + turn * stem[i] * scale_factor, origin + turn * stem[i + 1] * scale_factor, (0.19 - i * 0.035) * scale_factor)
	var crown: Array[Vector3] = []
	# Three unequal primary branches, attached at different trunk heights.
	var limbs := [
		[stem[1], Vector3(-0.55, 1.75, 0.12), Vector3(-1.5, 2.6, 0.25), Vector3(-2.05, 3.55, 0.45)],
		[stem[2], Vector3(0.65, 2.5, -0.25), Vector3(1.55, 3.05, -0.50), Vector3(2.0, 3.85, -0.65)],
		[stem[3], Vector3(-0.45, 3.35, -0.6), Vector3(-0.9, 4.0, -1.0), Vector3(-0.55, 4.65, -0.8)]]
	for limb in limbs:
		for segment in 3:
			_branch(origin + turn * limb[segment] * scale_factor, origin + turn * limb[segment + 1] * scale_factor, (0.11 - segment * 0.033) * scale_factor, 0.65)
		crown.append(turn * limb[3])
		for fork in 3:
			var start: Vector3 = limb[1].lerp(limb[3], 0.3 + fork * 0.22)
			var tip: Vector3 = start + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.65, 1.1), rng.randf_range(-0.9, 0.9))
			var joint := start.lerp(tip, 0.5) - Vector3(0, 0.16, 0)
			_branch(origin + turn * start * scale_factor, origin + turn * joint * scale_factor, 0.035 * scale_factor, 0.65)
			_branch(origin + turn * joint * scale_factor, origin + turn * tip * scale_factor, 0.022 * scale_factor, 0.22)
			crown.append(turn * tip)
	crown.append(turn * (stem[4] + Vector3(0.15, 0.4, 0.1)))
	for cluster in crown:
		for i in 210:
			var offset := Vector3(rng.randfn(0, 0.52), rng.randfn(0, 0.28), rng.randfn(0, 0.46))
			if offset.length_squared() > 1.5: continue
			var point := origin + (cluster + offset) * scale_factor
			var size := rng.randf_range(0.75, 1.35) * scale_factor * blossom_scale
			var rotation := Basis.from_euler(Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI)))
			model.add(_flower_mesh, flowers[rng.randi_range(0, flowers.size() - 1)], Transform3D(rotation.scaled(Vector3.ONE * size), point), "CherryBlossoms")


func _make_flower() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for petal in 5:
		var angle := TAU * petal / 5.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-sin(angle), 0, cos(angle))
		var base := direction * 0.018
		var tip := direction * 0.08 + Vector3.UP * 0.012
		var left := direction * 0.055 - side * 0.034
		var right := direction * 0.055 + side * 0.034
		Workshop.quad(surface, base, left, tip, right, 5.0)
	return surface.commit()


func _mountains() -> void:
	for layer in 3:
		var color := Color("8faaa3").lerp(Color("c2cdc0"), layer * 0.3)
		var material := Materials.plain(color.darkened(0.18), 1.0)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for peak in 5:
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var x0 := -40.0 + peak * 19.0 + layer * 2.0
			var z0 := -43.0 - layer * 18.0
			var height := 13.0 + sin(peak * 3.2 + layer) * 5.0
			for row in 18:
				for col in 24:
					var corners: Array[Vector3] = []
					for point in [Vector2(col, row), Vector2(col + 1, row), Vector2(col + 1, row + 1), Vector2(col, row + 1)]:
						var u: float = point.x / 24.0
						var v: float = point.y / 18.0
						var width := 8.0 + (1 - v) * 7.0
						var x := x0 + (u - 0.5) * width * 2
						var profile := 0.86 + sin(u * PI) * 0.10 + sin(u * 7.0 + peak) * 0.07
						var y := -1.0 + height * v * profile
						var z := z0 + sin(u * PI) * (3.0 + (1 - v) * 9.0) + sin(u * 40.0) * 0.25
						corners.append(Vector3(x, y, z))
					Workshop.quad(surface, corners[0], corners[3], corners[2], corners[1], 0.12)
			model.add(surface.commit(), material, Transform3D.IDENTITY, "DistantCliffs")


func _lantern(origin: Vector3, height: float) -> void:
	var cloth := Materials.plain(Color("a54f43"), 0.8)
	cloth.emission_enabled = true
	cloth.emission = Color("a75128")
	cloth.emission_energy_multiplier = 0.18
	var brass := Materials.plain(Color("9d855b"), 0.5)
	brass.metallic = 0.45
	for material in [cloth, brass]:
		material.set_meta("wind_mode", 3)
		material.set_meta("lantern_pivot", origin + Vector3.UP * height * 1.12)
		material.set_meta("wind_phase", origin.x * 0.31 + origin.y * 0.43)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := height * 0.42
	for ring in 12:
		for side in 24:
			var points: Array[Vector3] = []
			for p in [Vector2(side, ring), Vector2(side + 1, ring), Vector2(side + 1, ring + 1), Vector2(side, ring + 1)]:
				var t: float = p.y / 12
				var angle: float = TAU * p.x / 24
				var r := radius * (0.48 + 0.52 * sin(PI * t))
				points.append(origin + Vector3(cos(angle) * r, (t - 0.5) * height, sin(angle) * r))
			Workshop.quad(surface, points[0], points[1], points[2], points[3], 2.0)
	model.add(surface.commit(), cloth, Transform3D.IDENTITY, "LanternSilk")
	for sign in [-1.0, 1.0]:
		model.cylinder(origin + Vector3(0, sign * height * 0.50, 0), radius * 0.52, 0.055, brass, 1.0, "LanternCaps")
	for side in 12:
		var angle := TAU * side / 12.0
		for segment in 8:
			var a := segment / 8.0
			var b := (segment + 1) / 8.0
			var r0 := radius * (0.48 + 0.52 * sin(PI * a)) + 0.006
			var r1 := radius * (0.48 + 0.52 * sin(PI * b)) + 0.006
			model.beam(origin + Vector3(cos(angle) * r0, (a - 0.5) * height, sin(angle) * r0), origin + Vector3(cos(angle) * r1, (b - 0.5) * height, sin(angle) * r1), 0.010, 0.010, brass, "LanternRibs")
	for tassel in 7:
		model.box(origin + Vector3((tassel - 3) * 0.015, -height * 0.78, 0), Vector3(0.008, height * 0.46, 0.008), cloth, Vector3.ZERO, "LanternTassels")
	model.box(origin + Vector3(0, height * 0.83, 0), Vector3(0.014, height * 0.58, 0.014), brass, Vector3.ZERO, "LanternCords")
