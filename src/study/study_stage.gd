extends Control
class_name StudyStage
## 与游戏逻辑无关的持续书房场景，镜头从门口推进到桌面。
const ROOM_EYE := Vector3(3.6, 3.1, 4.0)
const ROOM_LOOK := Vector3(-0.7, 1.85, -1.45)
const DESK_EYE := Vector3(0.0, 5.6, 1.4)
const DESK_LOOK := Vector3(0.0, 1.30, -0.6)
const ENTRY_SECONDS := 1.45

var camera_blend := 0.0
var viewport: SubViewport
var camera: Camera3D
var _world: Node3D
var _sun: DirectionalLight3D
var _trees: Array[Node3D] = []
var _title_blocks: Node3D
var _desk_sheet: MeshInstance3D
var _battle_mode := false
var _camera_tween: Tween
var _clock := 0.0
var _wood: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _paper: StandardMaterial3D
var _brass: StandardMaterial3D
var _ink: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var battle_table: BattleTableScene
var _study_nodes: Array[Node3D] = []
var _environment: Environment
var _fill: OmniLight3D
var _display: TextureRect
var _illustrated_backdrop: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 198807
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.use_taa = RenderingServer.get_current_rendering_method() == "forward_plus"
	viewport.positional_shadow_atlas_size = 1024
	add_child(viewport)
	var display := TextureRect.new()
	_display = display
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	_illustrated_backdrop = TextureRect.new()
	_illustrated_backdrop.texture = TaopunkArt.background()
	_illustrated_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illustrated_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_illustrated_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_illustrated_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_illustrated_backdrop.hide()
	add_child(_illustrated_backdrop)
	_world = Node3D.new()
	viewport.add_child(_world)
	_make_materials()
	_build_room()
	_build_desk()
	_build_props()
	_build_outside()
	for child in _world.get_children():
		if child is Node3D:
			_study_nodes.append(child)
	_build_lighting()
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.08
	camera.far = 60
	_world.add_child(camera)
	battle_table = BattleTableScene.new()
	battle_table.stage = self
	_world.add_child(battle_table)
	battle_table.hide()
	_apply_camera(0)
	resized.connect(_resize_viewport)
	get_viewport().size_changed.connect(_resize_viewport)
	_resize_viewport()


func _resize_viewport() -> void:
	if viewport == null:
		return
	var pixels := Vector2(DisplayServer.window_get_size())
	if pixels.x < 100:
		pixels = size
	var factor := minf(1, 1600.0 / maxf(pixels.x, pixels.y))
	viewport.size = Vector2i(maxi(320, int(pixels.x * factor)), maxi(180, int(pixels.y * factor)))


func _plain(color: String, roughness := 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = roughness
	return material


func _make_materials() -> void:
	_wood = _plain("ffffff", 0.78)
	_wood.albedo_texture = load("res://assets/study/walnut_albedo.png")
	_wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_wood.uv1_scale = Vector3(1.8, 1.0, 1)
	_wood_dark = _wood.duplicate()
	_wood_dark.albedo_color = Color("796c60")
	_paper = _plain("eadfc3", 0.98)
	_brass = _plain("ae8751", 0.43)
	_brass.metallic = 0.7
	_ink = _plain("201e1b", 0.36)


func _box(parent: Node3D, pos: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance


func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, tip := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if tip < 0 else tip
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = (a + b) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	parent.add_child(instance)
	return instance


func _build_room() -> void:
	var plaster := _plain("ffffff", 0.96)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.055
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color("a99d85"))
	ramp.set_color(1, Color("e2d8c0"))
	texture.color_ramp = ramp
	plaster.albedo_texture = texture
	for i in 16:
		_box(_world, Vector3(-4.7 + i * 0.60, -0.075, 0), Vector3(0.59, 0.15, 10), _wood_dark)
	_box(_world, Vector3(0, 2.5, -4.4), Vector3(9.8, 5.0, 0.18), plaster)
	_box(_world, Vector3(4.8, 2.5, 0), Vector3(0.18, 5, 8.8), plaster)
	# 左墙留出真正的窗洞，而不是在墙面贴一张风景图。
	_box(_world, Vector3(-4.8, 0.66, 0), Vector3(0.18, 1.32, 8.8), plaster)
	_box(_world, Vector3(-4.8, 4.67, 0), Vector3(0.18, 0.66, 8.8), plaster)
	_box(_world, Vector3(-4.8, 2.83, -3.72), Vector3(0.18, 3.03, 1.38), plaster)
	_box(_world, Vector3(-4.8, 2.83, 2.77), Vector3(0.18, 3.03, 3.30), plaster)
	for y in [1.34, 4.34]:
		_box(_world, Vector3(-4.72, y, -1.25), Vector3(0.22, 0.12, 3.6), _wood_dark)
	for z in [-3.05, 0.55]:
		_box(_world, Vector3(-4.72, 2.84, z), Vector3(0.22, 3.10, 0.12), _wood_dark)
	for z in [-2.15, -1.25, -0.35]:
		_box(_world, Vector3(-4.70, 2.84, z), Vector3(0.11, 2.93, 0.055), _wood_dark)
	_box(_world, Vector3(-4.70, 2.84, -1.25), Vector3(0.11, 0.055, 3.50), _wood_dark)
	_box(_world, Vector3(-4.56, 1.27, -1.25), Vector3(0.60, 0.16, 3.95), _wood)
	for x in [-4.65, 0.05, 4.65]:
		_box(_world, Vector3(x, 2.45, -4.25), Vector3(0.16, 4.9, 0.16), _wood_dark)
	_box(_world, Vector3(0, 4.72, -4.22), Vector3(9.6, 0.20, 0.22), _wood_dark)
	_box(_world, Vector3(0, 0.22, -4.22), Vector3(9.6, 0.30, 0.20), _wood_dark)
	# 书架与线装书：书脊宽、高和色调各不相同。
	var shelf := Node3D.new()
	shelf.position = Vector3(2.60, 0, -4.0)
	_world.add_child(shelf)
	for x in [-1.13, 1.13]:
		_box(shelf, Vector3(x, 1.75, 0), Vector3(0.13, 3.50, 0.65), _wood)
	for row in 5:
		var y := 0.2 + row * 0.67
		_box(shelf, Vector3(0, y, 0), Vector3(2.35, 0.09, 0.70), _wood)
		var x := -0.96
		for book in 9:
			var width := _rng.randf_range(0.12, 0.21)
			var height := _rng.randf_range(0.36, 0.52)
			var color: String = ["645d40", "795f40", "8b7654", "46554a", "63524b"][(book + row) % 5]
			var cover := _plain(color)
			_box(shelf, Vector3(x, y + 0.08 + height * 0.5, 0.08), Vector3(width, height, 0.44), cover)
			_box(shelf, Vector3(x, y + height * 0.67, 0.31), Vector3(width * 0.65, 0.065, 0.008), _paper)
			x += width + 0.04
	# 墙上的手卷及天地轴。
	_box(_world, Vector3(-1.6, 3.00, -4.27), Vector3(0.97, 1.80, 0.02), _paper)
	for y in [2.07, 3.93]:
		_rod(_world, Vector3(-2.14, y, -4.20), Vector3(-1.06, y, -4.20), 0.05, _wood_dark)
	for index in 3:
		var label := Label3D.new()
		label.text = ["字", "成", "阵"][index]
		label.font = Ink.serif
		label.font_size = 80
		label.pixel_size = 0.005
		label.modulate = Color("504333")
		label.outline_size = 0
		label.shaded = true
		label.position = Vector3(-1.60, 3.50 - index * 0.50, -4.235)
		_world.add_child(label)


func _build_desk() -> void:
	_box(_world, Vector3(0, 1.27, -0.65), Vector3(6.40, 0.19, 3.70), _wood)
	for x in [-2.80, 2.80]:
		for z in [-2.20, 0.9]:
			_box(_world, Vector3(x, 0.60, z), Vector3(0.18, 1.20, 0.18), _wood_dark)
		_box(_world, Vector3(x, 0.48, -0.65), Vector3(0.16, 0.12, 3.20), _wood_dark)
	_box(_world, Vector3(0, 1.08, 1.12), Vector3(6.05, 0.25, 0.12), _wood_dark)
	for x in [-1.65, 0, 1.65]:
		_box(_world, Vector3(x, 1.07, 1.22), Vector3(1.50, 0.22, 0.09), _wood)
		_rod(_world, Vector3(x - 0.20, 1.07, 1.28), Vector3(x + 0.20, 1.07, 1.28), 0.022, _brass)
	# 真正位于桌面上的宣纸，接收窗格和树叶的实时阴影。
	_desk_sheet = _box(_world, Vector3(0, 1.38, -0.55), Vector3(4.45, 0.018, 2.64), _paper)
	_desk_sheet.rotation.y = -0.018
	_title_blocks = Node3D.new()
	_world.add_child(_title_blocks)
	for i in 4:
		var x := -1.0 + i * 0.62
		_box(_title_blocks, Vector3(x, 1.45, -0.25), Vector3(0.54, 0.14, 0.56), _wood)
		var glyph := Label3D.new()
		glyph.text = ["活", "字", "战", "斗"][i]
		glyph.font = Ink.serif
		glyph.font_size = 110
		glyph.pixel_size = 0.0036
		glyph.modulate = Color("29221b")
		glyph.outline_size = 0
		glyph.shaded = true
		glyph.rotation_degrees.x = -90
		glyph.position = Vector3(x, 1.527, -0.25)
		_title_blocks.add_child(glyph)


func _build_props() -> void:
	# 桌面只在边缘安排陈设，留出清楚的游戏纸面。
	for i in 4:
		var book := Node3D.new()
		book.position = Vector3(-2.59, 1.39 + i * 0.09, -1.65)
		book.rotation.y = -0.10 + i * 0.04
		_world.add_child(book)
		_box(book, Vector3.ZERO, Vector3(0.77, 0.085, 1.05), _paper)
		_box(book, Vector3(0, 0.05, 0), Vector3(0.80, 0.015, 1.08), _plain("50614f"))
		_box(book, Vector3(-0.20, 0.06, 0), Vector3(0.022, 0.01, 0.90), _brass)
	# 笔筒、墨砚、朱印和镇纸。
	_rod(_world, Vector3(2.65, 1.38, -1.85), Vector3(2.65, 1.72, -1.85), 0.18, _wood_dark)
	for i in 5:
		var a := Vector3(2.65 + (i - 2) * 0.045, 1.65, -1.85)
		var b := a + Vector3((i - 2) * 0.05, 0.68 + i * 0.055, sin(i) * 0.13)
		_rod(_world, a, b, 0.012, _wood)
		_rod(_world, b, b + Vector3(0, 0.12, 0), 0.025, _ink, 0.0)
	_box(_world, Vector3(2.62, 1.40, 0.30), Vector3(0.68, 0.075, 0.90), _ink)
	_box(_world, Vector3(2.62, 1.45, 0.20), Vector3(0.46, 0.025, 0.48), _plain("0e1010", 0.18))
	_rod(_world, Vector3(2.24, 1.48, 0.76), Vector3(2.88, 1.47, -0.38), 0.016, _wood)
	_box(_world, Vector3(-2.60, 1.41, 0.52), Vector3(0.23, 0.085, 0.23), _plain("983a2a"))
	_rod(_world, Vector3(-2.60, 1.44, 0.52), Vector3(-2.60, 1.63, 0.52), 0.057, _wood_dark)
	_box(_world, Vector3(-1.93, 1.41, -1.95), Vector3(1.55, 0.06, 0.13), _brass)
	var stool := Node3D.new()
	stool.position = Vector3(0.10, 0, 2.2)
	_world.add_child(stool)
	_box(stool, Vector3(0, 0.61, 0), Vector3(1.16, 0.11, 0.80), _wood)
	for x in [-0.43, 0.43]:
		for z in [-0.28, 0.28]:
			_box(stool, Vector3(x, 0.30, z), Vector3(0.11, 0.60, 0.11), _wood_dark)


func _build_outside() -> void:
	_box(_world, Vector3(-7.6, -0.13, 0), Vector3(5.4, 0.15, 13), _plain("77816a"))
	for i in 2:
		var tree := Node3D.new()
		tree.position = Vector3(-6.5 - i * 0.85, 0, -1.5 + i * 1.8)
		_world.add_child(tree)
		_trees.append(tree)
		var trunk := _plain("5d5b40")
		_rod(tree, Vector3.ZERO, Vector3(0.12, 3.7, 0), 0.15, trunk, 0.065)
		for j in 6:
			var a := j * 1.1
			var tip := Vector3(cos(a) * 1.3, 3.4 + sin(a * 2) * 0.55, sin(a) * 1.2)
			_rod(tree, Vector3(0.10, 2.45 + j * 0.17, 0), tip, 0.055, trunk, 0.015)
		var leaves := MultiMeshInstance3D.new()
		var geometry := SphereMesh.new()
		geometry.radius = 0.12
		geometry.height = 0.18
		geometry.radial_segments = 8
		geometry.rings = 4
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = geometry
		multi.instance_count = 380
		var leaf_material := _plain("8b9f66", 0.95)
		leaf_material.vertex_color_use_as_albedo = true
		geometry.material = leaf_material
		for j in 380:
			var a := _rng.randf_range(0, TAU)
			var r := sqrt(_rng.randf()) * 1.66
			var y := 3.2 + _rng.randf_range(-0.80, 0.90)
			var pos := Vector3(cos(a) * r, y, sin(a) * r)
			var rotation := Vector3(_rng.randf_range(-0.6, 0.6), a, _rng.randf_range(-0.6, 0.6))
			var basis := Basis.from_euler(rotation).scaled(Vector3(1.4, 0.28, 0.75) * _rng.randf_range(0.7, 1.3))
			multi.set_instance_transform(j, Transform3D(basis, pos))
			multi.set_instance_color(j, Color(_rng.randf_range(0.62, 1.0), _rng.randf_range(0.72, 1.0), 0.60))
		leaves.multimesh = multi
		tree.add_child(leaves)


func _build_lighting() -> void:
	var environment := Environment.new()
	_environment = environment
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("526173")
	sky_material.sky_horizon_color = Color("d8c9a7")
	sky_material.ground_bottom_color = Color("211710")
	sky_material.ground_horizon_color = Color("997b52")
	var reflection_sky := Sky.new()
	reflection_sky.sky_material = sky_material
	environment.sky = reflection_sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("91a6a1")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bcc7cb")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	environment.ssao_radius = 0.32
	environment.ssao_intensity = 1.4
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-28, -70, 0)
	_sun.light_color = Color("ffe5b6")
	_sun.light_energy = 1.55
	_sun.light_angular_distance = 1.2
	_sun.shadow_blur = 1.4
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 22
	_sun.shadow_bias = 0.025
	_sun.shadow_normal_bias = 0.35
	_world.add_child(_sun)
	var fill := OmniLight3D.new()
	_fill = fill
	fill.position = Vector3(1, 3.9, 1.4)
	fill.light_color = Color("ffc992")
	fill.light_energy = 0.15
	fill.omni_range = 6
	_world.add_child(fill)


func set_screen(path: String) -> void:
	# Title and journey pages own their backgrounds. Render the old world only for battle.
	if not path.ends_with("/battle_screen.gd"):
		_battle_mode = false
		show_room()
		if not path.ends_with("/title_screen.gd") and not path.contains("glyph_graph_screen"):
			_apply_camera(1)
		hide()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_battle_mode = path.contains("battle_screen")
	for study_node in _study_nodes:
		study_node.visible = not _battle_mode
	var illustrated := _battle_mode and Palette.STYLE_ID == "taopunk"
	battle_table.visible = _battle_mode and not illustrated
	_illustrated_backdrop.visible = illustrated
	_display.visible = not illustrated
	if _battle_mode:
		_sun.look_at_from_position(Vector3(-7, 4.8, -4), Vector3(0, 1.4, 0), Vector3.UP)
		_sun.light_color = Color("fff1d6")
		_sun.light_energy = 1.65
		_sun.light_angular_distance = 1.8
		_sun.shadow_blur = 1.8
		_sun.shadow_bias = 0.006
		_sun.shadow_normal_bias = 0.10
		_environment.ambient_light_color = Color("a8b5c9")
		_environment.ambient_light_energy = 0.46
		_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
		_environment.ssao_radius = 0.18
		_environment.ssao_intensity = 1.35
		_fill.light_energy = 0.12
	else:
		_sun.rotation_degrees = Vector3(-28, -70, 0)
		_sun.light_color = Color("ffe5b6")
		_sun.light_energy = 1.55
		_sun.light_angular_distance = 1.2
		_sun.shadow_blur = 1.4
		_sun.shadow_bias = 0.025
		_sun.shadow_normal_bias = 0.35
		_environment.ambient_light_color = Color("bcc7cb")
		_environment.ambient_light_energy = 0.45
		_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		_environment.ssao_radius = 0.32
		_environment.ssao_intensity = 1.4
		_fill.light_energy = 0.15
	_desk_sheet.visible = not _battle_mode
	visible = Palette.STYLE_ID in ["paper", "taopunk"]
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible and not illustrated else SubViewport.UPDATE_DISABLED
	if not visible:
		return
	if not path.contains("glyph_graph_screen"):
		if _camera_tween == null or not _camera_tween.is_running():
			_apply_camera(1)


func show_room() -> void:
	if _camera_tween != null:
		_camera_tween.kill()
	_apply_camera(0)


func enter_desk() -> float:
	if _camera_tween != null:
		_camera_tween.kill()
	if Settings.reduced_motion:
		_apply_camera(1)
		return 0.05
	_camera_tween = create_tween()
	_camera_tween.tween_method(_apply_camera, camera_blend, 1.0, ENTRY_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return ENTRY_SECONDS


func _apply_camera(value: float) -> void:
	camera_blend = value
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if _battle_mode else Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 6.4
	var bridge := Vector3(1.5, 4.6, 2.9)
	var desk_eye := Vector3(0, 8.7, 1.55) if _battle_mode else DESK_EYE
	var desk_look := Vector3(0, 1.36, 0) if _battle_mode else DESK_LOOK
	camera.position = ROOM_EYE.lerp(bridge, value).lerp(bridge.lerp(desk_eye, value), value)
	camera.look_at(ROOM_LOOK.lerp(desk_look, value), Vector3.UP)
	camera.fov = lerpf(49.0, 40.0 if _battle_mode else 47.0, value)
	_title_blocks.visible = value < 0.80
	if _battle_mode:
		var focus := CameraAttributesPractical.new()
		focus.dof_blur_near_enabled = true
		focus.dof_blur_near_distance = 5.9
		focus.dof_blur_near_transition = 1.0
		focus.dof_blur_amount = 0.12
		camera.attributes = focus
	else:
		camera.attributes = null


func shared_table_active() -> bool:
	return visible and _battle_mode and battle_table != null and Palette.STYLE_ID == "paper"


func table_point(canvas_point: Vector2, height: float) -> Vector3:
	var local := get_global_transform().affine_inverse() * canvas_point
	var pixel := local * Vector2(viewport.size) / Vector2(maxf(1, size.x), maxf(1, size.y))
	var origin := camera.project_ray_origin(pixel)
	var direction := camera.project_ray_normal(pixel)
	return origin + direction * ((height - origin.y) / minf(-0.001, direction.y))


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if Settings.reduced_motion:
		for tree in _trees:
			tree.rotation.z = 0
			tree.rotation.x = 0
		return
	for i in _trees.size():
		_trees[i].rotation.z = sin(_clock * 0.48 + i) * 0.017
		_trees[i].rotation.x = sin(_clock * 0.34 + i * 0.7) * 0.010
