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
var _gold: StandardMaterial3D
var _red: StandardMaterial3D
var _atlas: Texture2D
var _face_shader: Shader
var _body_mesh: ArrayMesh


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
	_face_shader = preload("res://src/shaders/type_face_illustrated.gdshader")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("3a2e1d")
	wood.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wood = wood
	var frame: StandardMaterial3D = wood.duplicate()
	frame.albedo_color = Palette.GOLD_DK
	_frame = frame
	var floor_material: StandardMaterial3D = wood.duplicate()
	floor_material.albedo_color = Color("111b1a")
	_floor = floor_material
	_socket = StandardMaterial3D.new()
	_socket.albedo_color = Color("21170e")
	_socket.roughness = 0.92
	_gold = StandardMaterial3D.new()
	_gold.albedo_color = Color("d7a832")
	_gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	Ink.board_font_changed.connect(_refresh_font)
	_resize_viewport()


func _resize_viewport() -> void:
	if viewport == null:
		return
	var pixel_scale := maxf(1, float(DisplayServer.window_get_size().x) / maxf(1, get_viewport_rect().size.x))
	var side := int(clampf(size.x * pixel_scale, 320, 960))
	viewport.size = Vector2i(side, side)


func set_illustrated_framing(value: bool) -> void:
	camera.size = grid_size * PITCH + (1.0 if value else 0.65)
	for child in get_children():
		if child is BronzeFrame:
			child.illustrated_framing = value
			child.queue_redraw()


func _mesh(parent: Node3D, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, position: Vector3, dimensions: Vector3, material: Material, bevel := 0.012) -> MeshInstance3D:
	return _mesh(parent, TypeMeshes.beveled_box(dimensions, bevel), position, material)


func set_tiles(tiles: Array) -> void:
	_tiles = tiles
	grid_size = int(round(sqrt(tiles.size())))
	camera.size = grid_size * PITCH + 0.65
	_tray = Node3D.new()
	_world.add_child(_tray)
	var side := grid_size * PITCH + 0.46
	_box(_tray, Vector3(0, -0.115, 0), Vector3(side, 0.19, side), _floor, 0.028)
	for tile in tiles:
		actors.append(_make_actor(tile))
	add_child(BronzeFrame.new())
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
	label.shaded = false
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
	glyph.font = Ink.board_font
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
		for edge in actor.border.get_children():
			if edge is MeshInstance3D:
				edge.material_override = _red if tile.is_selected else _gold
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
	_sync_tiles()


func _refresh_font() -> void:
	for actor in actors: actor.glyph.font = Ink.board_font
