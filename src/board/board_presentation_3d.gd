extends Control
class_name BoardPresentation3D
## 3D 只负责显示。稳定的格子投影用于原有 2D 连词输入，不引入物理拖拽。
const PITCH := 1.05
const FACE_Y := 0.151
var viewport: SubViewport
var camera: Camera3D
var grid_size := 4
var actors: Array[Dictionary] = []
var _tiles: Array = []
var _world: Node3D
var _tray: Node3D
var _sun: DirectionalLight3D
var _wood: Material
var _frame: Material
var _floor: Material
var _socket: StandardMaterial3D
var _red: StandardMaterial3D
var _atlas: Texture2D
var _face_shader: Shader
var _body_mesh: ArrayMesh
var _shared_stage: StudyStage


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(640, 640)
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var display := TextureRect.new()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(display)
	_world = Node3D.new()
	viewport.add_child(_world)
	_atlas = load("res://assets/battle/type_faces_atlas.png")
	_face_shader = load("res://src/shaders/type_face.gdshader")
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/study/walnut_albedo.png")
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	wood.roughness = 0.58
	_wood = wood
	var frame: StandardMaterial3D = wood.duplicate()
	frame.albedo_color = Color("978570")
	_frame = frame
	var floor_material: StandardMaterial3D = wood.duplicate()
	floor_material.albedo_color = Color("685242")
	_floor = floor_material
	if is_instance_valid(Router.study_stage) and Router.study_stage.shared_table_active():
		_shared_stage = Router.study_stage
		_wood = _shared_stage.battle_table.wood_material(Color("b19b7e"), Vector3(0.96, 0.18, 0.96), 0.24)
		var worn_frame := _shared_stage.battle_table.wood_material(Color("d3c1a9"), Vector3.ONE, 0.10)
		worn_frame.set_shader_parameter("grain_texture", load("res://assets/battle/worn_walnut_albedo.png"))
		_frame = worn_frame
		_floor = _shared_stage.battle_table.wood_material(Color("77634c"), Vector3.ONE, 0.10)
		display.hide()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_socket = StandardMaterial3D.new()
	_socket.albedo_color = Color("21170e")
	_socket.roughness = 0.92
	_red = StandardMaterial3D.new()
	_red.albedo_color = Palette.VERMILION
	_red.roughness = 0.75
	_red.emission_enabled = true
	_red.emission = Palette.VERMILION
	_red.emission_energy_multiplier = 0.15
	_body_mesh = TypeMeshes.beveled_box(Vector3(0.96, 0.18, 0.96), 0.027)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.near = 0.05
	camera.far = 20
	_world.add_child(camera)
	camera.position = Vector3(0, 8, 1.20)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.size = grid_size * PITCH + 0.65
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.TRANSPARENT
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7d4c8")
	environment.ambient_light_energy = 0.50
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-38, -55, 0)
	_sun.light_color = Color("ffe6be")
	_sun.light_energy = 0.80
	_sun.light_angular_distance = 0.6
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 12
	_sun.shadow_bias = 0.01
	_sun.shadow_normal_bias = 0.20
	_world.add_child(_sun)
	resized.connect(_resize_viewport)
	_resize_viewport()


func _resize_viewport() -> void:
	if viewport == null:
		return
	var pixel_scale := maxf(1, float(DisplayServer.window_get_size().x) / maxf(1, get_viewport_rect().size.x))
	var side := int(clampf(size.x * pixel_scale, 320, 960))
	viewport.size = Vector2i(side, side)


func _mesh(parent: Node3D, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, position: Vector3, dimensions: Vector3, material: Material, bevel := 0.012) -> MeshInstance3D:
	if material is ShaderMaterial and material.shader.resource_path.ends_with("table_wood.gdshader"):
		var surface: ShaderMaterial = material.duplicate()
		surface.set_shader_parameter("half_size", dimensions * 0.5)
		if dimensions.x > dimensions.z:
			surface.set_shader_parameter("rotate_grain", true)
			surface.set_shader_parameter("grain_scale", Vector2(maxf(0.20, dimensions.z * 0.70), maxf(0.40, dimensions.x * 0.70)))
		else:
			surface.set_shader_parameter("grain_scale", Vector2(maxf(0.20, dimensions.x * 0.70), maxf(0.40, dimensions.z * 0.70)))
		return _mesh(parent, TypeMeshes.beveled_box(dimensions, bevel), position, surface)
	return _mesh(parent, TypeMeshes.beveled_box(dimensions, bevel), position, material)


func set_tiles(tiles: Array) -> void:
	_tiles = tiles
	grid_size = int(round(sqrt(tiles.size())))
	camera.size = grid_size * PITCH + 0.65
	_tray = Node3D.new()
	if is_instance_valid(_shared_stage):
		_shared_stage.battle_table.add_child(_tray)
	else:
		_world.add_child(_tray)
	var side := grid_size * PITCH + 0.46
	_box(_tray, Vector3(0, -0.115, 0), Vector3(side, 0.19, side), _floor, 0.028)
	for axis in 2:
		for sign_value in [-1.0, 1.0]:
			var position := Vector3.ZERO
			position[axis * 2] = (side - 0.25) * 0.5 * sign_value
			position.y = 0.065
			var dimensions := Vector3(side, 0.30, 0.25) if axis == 1 else Vector3(0.25, 0.30, side)
			_box(_tray, position, dimensions, _frame, 0.030)
			# 窄凸线与内侧压边分别受光，形成参考图中磨亮的层叠木框。
			var ridge := position
			ridge.y = 0.222
			_box(_tray, ridge, Vector3(side - 0.08, 0.035, 0.072) if axis == 1 else Vector3(0.072, 0.035, side - 0.08), _frame, 0.009)
			var inset := position
			inset[axis * 2] -= sign_value * 0.117
			inset.y = 0.164
			_box(_tray, inset, Vector3(side - 0.26, 0.040, 0.045) if axis == 1 else Vector3(0.045, 0.040, side - 0.26), _frame, 0.008)
	for tile in tiles:
		actors.append(_make_actor(tile))
	_sync_shared_layout()
	_sync_tiles()


func _label(parent: Node3D, position: Vector3, color: Color, font_size: int, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.font = Ink.serif
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.outline_size = 0
	label.modulate = color
	label.rotation_degrees.x = -90
	label.position = position
	label.shaded = true
	parent.add_child(label)
	return label


func _base_position(index: int) -> Vector3:
	var tile: TileView = _tiles[index]
	var half := (grid_size - 1) * 0.5
	return Vector3((tile.grid_pos.x - half) * PITCH, 0, (tile.grid_pos.y - half) * PITCH)


func _make_actor(tile: TileView) -> Dictionary:
	var index := actors.size()
	var position := Vector3((tile.grid_pos.x - (grid_size - 1) * 0.5) * PITCH, 0, (tile.grid_pos.y - (grid_size - 1) * 0.5) * PITCH)
	var socket := _box(_tray, position + Vector3(0, -0.033, 0), Vector3(0.99, 0.014, 0.99), _socket, 0.005)
	var root := Node3D.new()
	root.position = position
	_tray.add_child(root)
	_mesh(root, _body_mesh, Vector3(0, 0.06, 0), _wood)
	var material := ShaderMaterial.new()
	material.shader = _face_shader
	material.set_shader_parameter("face_atlas", _atlas)
	var face_mesh := PlaneMesh.new()
	face_mesh.size = Vector2(0.905, 0.905)
	_mesh(root, face_mesh, Vector3(0, FACE_Y, 0), material)
	var glyph := _label(root, Vector3(0, FACE_Y + 0.012, 0), Color("211c16"), 110, 0.0059)
	var badges := _label(root, Vector3(0.10, FACE_Y + 0.014, -0.33), Palette.VERMILION_DK, 40, 0.0032)
	var uses := _label(root, Vector3(0.29, FACE_Y + 0.016, 0.33), Palette.GOLD_DK, 40, 0.0034)
	var border := Node3D.new()
	root.add_child(border)
	for axis in 2:
		for sign_value in [-1.0, 1.0]:
			var edge := Vector3(0, FACE_Y + 0.006, 0)
			edge[axis * 2] = 0.459 * sign_value
			_box(border, edge, Vector3(0.017, 0.014, 0.93) if axis == 0 else Vector3(0.93, 0.014, 0.017), _red, 0.003)
	var marker := Node3D.new()
	marker.position = Vector3(-0.32, FACE_Y + 0.009, -0.32)
	root.add_child(marker)
	var circle := CylinderMesh.new()
	circle.top_radius = 0.091
	circle.bottom_radius = 0.091
	circle.height = 0.005
	circle.radial_segments = 24
	_mesh(marker, circle, Vector3.ZERO, _red)
	var order := _label(marker, Vector3(0, 0.009, 0), Palette.PAPER, 46, 0.0033)
	var empty_hint := _label(_tray, position + Vector3(0, -0.013, 0), Palette.GOLD, 70, 0.004)
	empty_hint.text = "+"
	return {"root": root, "face": material, "glyph": glyph, "badges": badges, "uses": uses,
		"border": border, "marker": marker, "order": order, "socket": socket,
		"empty_hint": empty_hint, "key": "", "uid": -2, "index": index}


func _sync_tiles() -> void:
	var pixel_to_world := camera.size / maxf(1, size.x)
	for index in actors.size():
		var actor: Dictionary = actors[index]
		var tile: TileView = _tiles[index]
		var root: Node3D = actor.root
		var opacity := tile._visual.modulate.a
		root.visible = tile.instance != null and opacity > 0.025
		actor.empty_hint.visible = tile.instance == null and not tile.is_dimmed and not str(get_parent().get("pick_mode")).is_empty()
		if tile.instance == null:
			actor.uid = -1
			continue
		if actor.key != tile.display_key or int(actor.uid) != tile.display_uid:
			actor.uid = tile.display_uid
			actor.key = tile.display_key
			var variant := posmod(tile.display_uid, 4)
			actor.face.set_shader_parameter("quadrant", Vector2(variant % 2, variant / 2) * 0.5)
			actor.glyph.text = "".join(tile.instance.glyph_list())
			actor.glyph.pixel_size = 0.0040 if tile.instance.is_fused() else 0.0059
			actor.badges.text = "".join(tile.art_badges)
			actor.uses.text = tile._uses_label.text if tile._uses_label.visible else ""
		var tint := tile.art_tint
		if tile.is_dimmed:
			tint *= Color(0.55, 0.55, 0.55)
		actor.face.set_shader_parameter("tint", tint)
		actor.border.visible = tile.is_selected or tile.instance.gilded
		actor.marker.visible = tile.is_selected
		actor.order.text = tile._order.text
		actor.badges.visible = not tile.is_selected
		var base := _base_position(index)
		var lift := 0.0
		var offset := Vector3.ZERO
		if not Settings.reduced_motion:
			if tile.motion_kind == "enter":
				offset.x = tile._visual.position.x * pixel_to_world
				offset.z = tile._visual.position.y * pixel_to_world
				lift = (1.0 - opacity) * 0.20
			elif tile.motion_kind == "shake":
				offset.x = tile._visual.position.x * pixel_to_world
				lift = maxf(0, -tile._visual.position.y * 0.018)
			else:
				lift = maxf(0, -tile._visual.position.y * 0.018)
		root.position = base + offset + Vector3(0, lift, 0)
		var shrink := maxf(0.01, opacity)
		root.scale = Vector3(tile._visual.scale.x * shrink, maxf(0.05, shrink), tile._visual.scale.y * shrink)


func has_projection() -> bool:
	return camera != null and not _tiles.is_empty() and size.x > 50 and DisplayServer.get_name() != "headless"


func _project(point: Vector3) -> Vector2:
	if is_instance_valid(_shared_stage):
		var projected := _shared_stage.camera.unproject_position(_tray.global_transform * point)
		var canvas_point := _shared_stage.get_global_transform() * (projected * _shared_stage.size / Vector2(_shared_stage.viewport.size))
		return get_global_transform().affine_inverse() * canvas_point
	var pixel := camera.unproject_position(point)
	return pixel * size / Vector2(viewport.size)


func cell_polygon(index: int) -> PackedVector2Array:
	var base := _base_position(index) + Vector3(0, FACE_Y, 0)
	var points := PackedVector2Array()
	for corner in [Vector2(-0.48, -0.48), Vector2(0.48, -0.48), Vector2(0.48, 0.48), Vector2(-0.48, 0.48)]:
		points.append(_project(base + Vector3(corner.x, 0, corner.y)))
	return points


func cell_rect(index: int) -> Rect2:
	var points := cell_polygon(index)
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rect = rect.expand(point)
	return rect


func cell_at(local: Vector2) -> Vector2i:
	for index in _tiles.size():
		if Geometry2D.is_point_in_polygon(local, cell_polygon(index)):
			return _tiles[index].grid_pos
	return Vector2i(-1, -1)


func center_of(index: int) -> Vector2:
	return _project((actors[index].root as Node3D).position + Vector3(0, FACE_Y + 0.012, 0))


func _process(_delta: float) -> void:
	if is_instance_valid(_shared_stage):
		_sync_shared_layout()
	elif is_instance_valid(Router.study_stage):
		_sun.rotation = Router.study_stage._sun.rotation
		_sun.light_color = Router.study_stage._sun.light_color
	_sync_tiles()


func _sync_shared_layout() -> void:
	if not is_instance_valid(_shared_stage) or _tray == null or size.x < 10:
		return
	var rect := get_global_rect()
	var left := _shared_stage.table_point(rect.position, BattleTableScene.TABLE_Y)
	var right := _shared_stage.table_point(rect.position + Vector2(rect.size.x, 0), BattleTableScene.TABLE_Y)
	var world_scale := left.distance_to(right) / (grid_size * PITCH + 0.65)
	_tray.scale = Vector3.ONE * world_scale
	var face_height := BattleTableScene.TABLE_Y + (0.21 + FACE_Y) * world_scale
	_tray.position = _shared_stage.table_point(rect.get_center(), face_height) - Vector3(0, FACE_Y * world_scale, 0)


func _exit_tree() -> void:
	# 共享场景中的字盘仍由该控件拥有；切屏时主动释放，避免留下模型。
	if is_instance_valid(_shared_stage) and is_instance_valid(_tray):
		_tray.queue_free()
