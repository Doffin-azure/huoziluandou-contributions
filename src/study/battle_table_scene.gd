extends Node3D
class_name BattleTableScene
## 桌面、字盘、纸张共享一个世界、相机和投影光源。仅维护表现资源。
const TABLE_Y := 1.36
const PAPER_Y := 1.405
var stage: StudyStage
var papers: Array[Dictionary] = []
var _props: Array[Dictionary] = []
var _leaf_cluster: Node3D
var _canopy: TreeShadowCanopy
var _wood: ShaderMaterial
var _paper: ShaderMaterial
var _brass: StandardMaterial3D
var _ink: StandardMaterial3D
var _last_size := Vector2.ZERO


func _ready() -> void:
	_wood = ShaderMaterial.new()
	_wood.shader = load("res://src/shaders/table_wood.gdshader")
	_wood.set_shader_parameter("grain_texture", load("res://assets/study/walnut_albedo.png"))
	_paper = ShaderMaterial.new()
	_paper.shader = load("res://src/shaders/table_paper.gdshader")
	_paper.set_shader_parameter("paper_texture", load("res://assets/battle/xuan_sheet.png"))
	_brass = StandardMaterial3D.new()
	_brass.albedo_color = Color("a77b38")
	_brass.metallic = 0.78
	_brass.roughness = 0.36
	_ink = StandardMaterial3D.new()
	_ink.albedo_color = Color("161714")
	_ink.roughness = 0.25
	# 独立桌面近景陈设：桌面的七块宽板保留细缝和倒角接触阴影。
	for plank in 7:
		var material: ShaderMaterial = _wood.duplicate()
		material.set_shader_parameter("tint", Color(0.88 + plank * 0.018, 0.85 + plank * 0.018, 0.79 + plank * 0.018))
		material.set_shader_parameter("grain_scale", Vector2(2.4, 0.44))
		material.set_shader_parameter("rotate_grain", true)
		material.set_shader_parameter("grain_offset", Vector2(plank * 0.19, plank * 0.37))
		_box(self, Vector3(0, TABLE_Y - 0.12, (plank - 3) * 1.21), Vector3(17, 0.24, 1.20), material, 0.024)
	_build_props()
	_build_shadow_casters()


func wood_material(tint: Color, dimensions: Vector3, polish := 0.20) -> ShaderMaterial:
	var material: ShaderMaterial = _wood.duplicate()
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("half_size", dimensions * 0.5)
	material.set_shader_parameter("wear", polish)
	return material


func _box(parent: Node3D, pos: Vector3, dimensions: Vector3, material: Material, bevel := 0.014) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = TypeMeshes.beveled_box(dimensions, bevel)
	if material is ShaderMaterial and material.shader == _wood.shader:
		var wood: ShaderMaterial = material.duplicate()
		wood.set_shader_parameter("half_size", dimensions * 0.5)
		instance.material_override = wood
	else:
		instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance


func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, tip := -1.0) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = radius
	cylinder.top_radius = radius if tip < 0 else tip
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 24
	var instance := MeshInstance3D.new()
	instance.mesh = cylinder
	instance.material_override = material
	instance.position = (a + b) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	parent.add_child(instance)
	return instance


func _prop(uv: Vector2, angle := 0.0) -> Node3D:
	var prop := Node3D.new()
	prop.rotation.y = angle
	add_child(prop)
	_props.append({"node": prop, "uv": uv})
	# 陈设退到桌面边缘：只留书、印台和毛笔，减少与操作区竞争的装饰。
	if uv in [Vector2(0.105, 0.11), Vector2(0.86, 0.088), Vector2(0.43, 0.87)]:
		prop.hide()
	return prop


func _loose_sheet(parent: Node3D, pos: Vector3, dimensions: Vector2, angle: float) -> void:
	var sheet := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = dimensions
	sheet.mesh = plane
	sheet.material_override = _paper
	sheet.rotation.y = angle
	sheet.position = pos
	parent.add_child(sheet)
	# 原生字形落在陈设纸上；不冒充战斗词效或操作入口。
	for row in 4:
		var note := Label3D.new()
		note.text = ["山水清音", "墨色入纸", "字成千象", "风过疏窗"][row]
		note.font = Ink.serif
		note.font_size = 32
		note.pixel_size = 0.0035
		note.modulate = Color("73644f")
		note.outline_size = 0
		note.shaded = true
		note.rotation_degrees.x = -90
		note.rotation.y = angle
		note.position = pos + Vector3(0.0, 0.004, -0.32 + row * 0.15)
		parent.add_child(note)


func _build_props() -> void:
	var book := _prop(Vector2(0.33, 0.105), -0.10)
	for index in 3:
		_box(book, Vector3(0, index * 0.10 + 0.045, 0), Vector3(1.95, 0.09, 0.78), _paper)
		_box(book, Vector3(0, index * 0.10 + 0.098, 0), Vector3(2.01, 0.018, 0.81), _wood)
		for thread in 5:
			_rod(book, Vector3(-0.85 + thread * 0.09, index * 0.1 + 0.115, -0.34), Vector3(-0.85 + thread * 0.09, index * 0.1 + 0.115, 0.34), 0.006, _brass)
	var type_case := _prop(Vector2(0.105, 0.11), -0.20)
	_box(type_case, Vector3(0, 0.055, 0), Vector3(1.0, 0.10, 0.74), _wood)
	for row in 2:
		for col in 3:
			var at := Vector3((col - 1) * 0.28, 0.16, (row - 0.5) * 0.28)
			_box(type_case, at, Vector3(0.25, 0.20, 0.25), _wood)
			var glyph := Label3D.new()
			glyph.text = ["字", "山", "印", "风", "月", "水"][row * 3 + col]
			glyph.font = Ink.serif
			glyph.font_size = 55
			glyph.pixel_size = 0.0032
			glyph.modulate = Color("ccb68c")
			glyph.shaded = true
			glyph.outline_size = 0
			glyph.rotation_degrees.x = -90
			glyph.position = at + Vector3(0, 0.105, 0)
			type_case.add_child(glyph)
	var coin := _prop(Vector2(0.86, 0.088), 0.15)
	_rod(coin, Vector3(0, 0.015, 0), Vector3(0, 0.08, 0), 0.47, _brass)
	for radius in [0.37, 0.43]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.013
		torus.outer_radius = radius + 0.013
		ring.mesh = torus
		ring.material_override = _brass
		ring.position.y = 0.083
		coin.add_child(ring)
	for index in 12:
		var a := TAU * index / 12
		var stamp := _box(coin, Vector3(cos(a) * 0.30, 0.087, sin(a) * 0.30), Vector3(0.055, 0.01, 0.07), _brass, 0.002)
		stamp.rotation.y = a
	_box(coin, Vector3(0, 0.09, 0), Vector3(0.11, 0.01, 0.11), _ink, 0.002)
	var cup := _prop(Vector2(0.995, 0.18))
	_rod(cup, Vector3(0, 0, 0), Vector3(0, 0.50, 0), 0.26, _wood)
	_rod(cup, Vector3(0, 0.50, 0), Vector3(0, 0.505, 0), 0.22, _ink)
	for i in 7:
		var bottom := Vector3((i - 3) * 0.045, 0.39, 0)
		var tip := bottom + Vector3((i - 3) * 0.05, 0.75 + i * 0.04, 0.05 * sin(i))
		_rod(cup, bottom, tip, 0.016, _wood)
		_rod(cup, tip, tip + Vector3(0, 0.18, 0), 0.032, _ink, 0.0)
	var brush := _prop(Vector2(0.77, 0.92), -0.48)
	_rod(brush, Vector3(-1.55, 0.10, 0), Vector3(1.28, 0.10, 0), 0.031, _wood)
	_rod(brush, Vector3(-1.78, 0.10, 0), Vector3(-1.55, 0.10, 0), 0.048, _ink, 0.01)
	_rod(brush, Vector3(-1.53, 0.10, 0), Vector3(-1.46, 0.10, 0), 0.036, _brass)
	var stone := _prop(Vector2(1.025, 0.96), -0.20)
	_box(stone, Vector3(0, 0.07, 0), Vector3(1.18, 0.14, 1.35), _ink, 0.05)
	var puddle := _ink.duplicate()
	puddle.albedo_color = Color("090d0c")
	puddle.roughness = 0.10
	_rod(stone, Vector3(0, 0.142, 0), Vector3(0, 0.148, 0), 0.44, puddle)
	var scraps := _prop(Vector2(0.43, 0.87), -0.25)
	_loose_sheet(scraps, Vector3(0, 0.015, 0), Vector2(1.72, 1.32), -0.20)
	_loose_sheet(scraps, Vector3(-0.30, 0.023, -0.10), Vector2(1.66, 1.12), 0.12)
	var edge_sheet := _prop(Vector2(0.018, 0.53), -0.43)
	_loose_sheet(edge_sheet, Vector3(0, 0.014, 0), Vector2(0.85, 1.9), -0.35)


func _build_shadow_casters() -> void:
	# 窗格位于镜头外，投影横跨同一张桌面和所有字块。
	var caster := Node3D.new()
	add_child(caster)
	var sunlight := Vector3(7.0, -3.4, 4.0).normalized()
	var height := 2.35
	var center := Vector3(-3.0, TABLE_Y, -1.1) - sunlight * (height / -sunlight.y)
	for index in 2:
		var bar := _box(caster, center + Vector3(-2.65 - index * 1.3, 0, 0), Vector3(0.038, 0.07, 10), _wood)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for index in 2:
		var bar := _box(caster, center + Vector3(2, 0, -1.25 - index * 1.8), Vector3(12, 0.07, 0.045), _wood)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	# 可见前景枝叶有景深；对应树冠投影保留柔和、缓慢的摆动。
	_leaf_cluster = _prop(Vector2(0.025, 0.08))
	var leaf_material := StandardMaterial3D.new()
	leaf_material.albedo_color = Color("4d5931")
	leaf_material.roughness = 0.87
	for i in 20:
		var a := float(i) * 2.4
		var leaf := MeshInstance3D.new()
		var shape := SphereMesh.new()
		shape.radius = 0.16
		shape.height = 0.32
		shape.radial_segments = 12
		shape.rings = 6
		leaf.mesh = shape
		leaf.material_override = leaf_material
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		leaf.position = Vector3(cos(a) * (0.36 + i * 0.025), 2.1 + sin(a) * 0.2, sin(a) * 0.74)
		leaf.scale = Vector3(1.4, 0.18, 0.68)
		leaf.rotation.y = a
		_leaf_cluster.add_child(leaf)
	var canopy := TreeShadowCanopy.new()
	_canopy = canopy
	add_child(canopy)


func register_paper(source: ArtPaper) -> void:
	var sheet := MeshInstance3D.new()
	sheet.material_override = _paper
	add_child(sheet)
	papers.append({"source": weakref(source), "mesh": sheet, "transform": Transform2D(), "size": Vector2.ZERO})


func unregister_paper(source: ArtPaper) -> void:
	for index in range(papers.size() - 1, -1, -1):
		var entry: Dictionary = papers[index]
		if entry.source.get_ref() == source:
			entry.mesh.queue_free()
			papers.remove_at(index)


func _paper_mesh(source: Control) -> ArrayMesh:
	var transform := source.get_global_transform()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2.ZERO, Vector2(source.size.x, 0), source.size, Vector2(0, source.size.y)]
	var uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	for index in [0, 1, 2, 0, 2, 3]:
		var point: Vector3 = stage.table_point(transform * corners[index], PAPER_Y)
		surface.set_normal(Vector3.UP)
		surface.set_uv(uvs[index])
		surface.add_vertex(point)
	surface.generate_tangents()
	return surface.commit()


func sync_layout() -> void:
	for prop in _props:
		prop.node.position = stage.table_point(stage.get_global_transform() * (stage.size * prop.uv), TABLE_Y + 0.018)
	if _canopy != null:
		var sunlight := Vector3(7.0, -3.4, 4.0).normalized()
		var shadow_root := stage.table_point(stage.get_global_transform() * (stage.size * Vector2(-0.08, 0.24)), PAPER_Y)
		_canopy.position = shadow_root - sunlight * (1.05 / -sunlight.y)
	for index in range(papers.size() - 1, -1, -1):
		var entry: Dictionary = papers[index]
		var source: ArtPaper = entry.source.get_ref()
		if not is_instance_valid(source):
			entry.mesh.queue_free()
			papers.remove_at(index)
			continue
		entry.mesh.visible = source.is_visible_in_tree() and source.size.x > 5
		if entry.transform != source.get_global_transform() or entry.size != source.size or _last_size != stage.size:
			entry.mesh.mesh = _paper_mesh(source)
			entry.transform = source.get_global_transform()
			entry.size = source.size
	_last_size = stage.size


func _process(_delta: float) -> void:
	if not visible:
		return
	sync_layout()
	if _leaf_cluster != null:
		_leaf_cluster.rotation.z = 0.0 if Settings.reduced_motion else sin(stage._clock * 0.32) * 0.018
	if _canopy != null:
		_canopy.rotation.z = 0.0 if Settings.reduced_motion else sin(stage._clock * 0.24) * 0.014
		_canopy.rotation.x = 0.0 if Settings.reduced_motion else sin(stage._clock * 0.31) * 0.010
		_canopy.sway(stage._clock, Settings.reduced_motion)
