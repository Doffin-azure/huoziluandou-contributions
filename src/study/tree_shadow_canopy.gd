extends Node3D
class_name TreeShadowCanopy
## 连续枝干、叶柄和尖卵形叶片形成树影；形态随机数仅用于美术。
var _rng := RandomNumberGenerator.new()
var _leaf_mesh: ArrayMesh
var _material: StandardMaterial3D
var _twigs: Array[Node3D] = []


func _ready() -> void:
	_rng.seed = 640519
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color("33352a")
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_leaf_mesh = _make_leaf_mesh()
	var spine: Array[Vector3] = [Vector3.ZERO, Vector3(0.64, 0.02, -0.12),
		Vector3(1.24, 0.04, -0.31), Vector3(1.82, 0.06, -0.63),
		Vector3(2.35, 0.09, -0.85), Vector3(2.78, 0.11, -1.13)]
	for index in range(spine.size() - 1):
		_branch(self, spine[index], spine[index + 1], lerpf(0.073, 0.014, index / 4.0), lerpf(0.061, 0.007, index / 4.0))
	for index in range(1, spine.size()):
		_make_twig(spine[index], Vector3(0.52 + index * 0.07, 0.035, -0.46 - index * 0.025), index)
		if index < 4:
			_make_twig(spine[index] + Vector3(-0.10, 0.0, 0.025), Vector3(0.47, -0.04, 0.32 + index * 0.03), index + 5)


func _branch(parent: Node3D, start: Vector3, end: Vector3, base_radius: float, tip_radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = base_radius
	mesh.top_radius = tip_radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 8
	var branch := MeshInstance3D.new()
	branch.mesh = mesh
	branch.material_override = _material
	branch.position = (start + end) * 0.5
	branch.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	branch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	parent.add_child(branch)


func _make_leaf_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# 叶基和叶尖收细，左右轮廓略不对称，中脉有轻微拱起。
	var outline: Array[Vector3] = [Vector3(0, 0, 0), Vector3(-0.12, 0.008, 0.19),
		Vector3(-0.205, 0.014, 0.43), Vector3(-0.17, 0.008, 0.66),
		Vector3(-0.07, 0.0, 0.86), Vector3(0, -0.008, 1),
		Vector3(0.085, 0, 0.84), Vector3(0.185, 0.008, 0.62),
		Vector3(0.195, 0.014, 0.40), Vector3(0.11, 0.008, 0.18)]
	for index in outline.size():
		for vertex in [Vector3(0, 0.035, 0.48), outline[index], outline[(index + 1) % outline.size()]]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(vertex)
	return surface.commit()


func _make_twig(anchor: Vector3, direction: Vector3, phase: int) -> void:
	var twig := Node3D.new()
	twig.position = anchor
	twig.set_meta("phase", float(phase))
	add_child(twig)
	_twigs.append(twig)
	var points: Array[Vector3] = [Vector3.ZERO, direction * 0.34 + Vector3(0, 0, 0.045),
		direction * 0.70 + Vector3(0, 0.02, 0.025), direction]
	for index in 3:
		_branch(twig, points[index], points[index + 1], 0.022 - index * 0.006, 0.014 - index * 0.005)
	var lateral := Vector3(-direction.z, 0, direction.x).normalized()
	for index in 7:
		var along := (index + 1.0) / 8.0
		var node := direction * along + Vector3(0, sin(along * PI) * 0.024, 0.02)
		var side := -1.0 if index % 2 == 0 else 1.0
		var petiole_end := node + lateral * side * _rng.randf_range(0.035, 0.07)
		_branch(twig, node, petiole_end, 0.005, 0.003)
		var leaf := MeshInstance3D.new()
		leaf.mesh = _leaf_mesh
		leaf.material_override = _material
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		leaf.position = petiole_end
		var aim := (lateral * side + direction.normalized() * _rng.randf_range(0.25, 0.70)).normalized()
		leaf.rotation = Vector3(_rng.randf_range(-0.40, 0.40), atan2(aim.x, aim.z), _rng.randf_range(-0.30, 0.30))
		var length := _rng.randf_range(0.34, 0.57)
		leaf.scale = Vector3(length * _rng.randf_range(0.80, 1.18), length, length)
		twig.add_child(leaf)


func sway(time: float, reduced_motion: bool) -> void:
	for twig in _twigs:
		var phase := float(twig.get_meta("phase"))
		twig.rotation.x = 0.0 if reduced_motion else sin(time * 0.35 + phase * 0.65) * 0.014
		twig.rotation.z = 0.0 if reduced_motion else sin(time * 0.27 + phase) * 0.011
