extends Node3D
## Independent 3D courtyard with a limited pigment palette and real planar reflections.
const Style := preload("res://src/title/courtyard/render_style.gd")
const Atmosphere := preload("res://src/title/courtyard/atmosphere.gd")
@onready var camera: Camera3D = $Camera
@onready var geometry: Node3D = $Architecture
@onready var landscape: Node3D = $Landscape
var key: DirectionalLight3D
var accent: SpotLight3D
var environment: Environment
var render_style := Style.new()
var mirror_viewport: SubViewport
var mirror_camera: Camera3D
var _look_target := Vector3.ZERO
var inspection := 0.0
var _motion: Tween
var contours: MeshInstance3D
var atmosphere: Node3D
var foreground: Node3D
var mobile_quality := false
var _camera_inspection := -1.0


func _ready() -> void:
	render_style.apply(geometry, landscape, not mobile_quality)
	_build_daylight()
	foreground = preload("res://src/title/courtyard/foreground.gd").new()
	foreground.name = "LanternTerrace"; add_child(foreground); foreground.build()
	_build_water()
	if not mobile_quality:
		_build_planar_reflection()
		_build_contours()
	else:
		$ReflectingPool.material_override.set_shader_parameter("reflection_strength", 0.0)
	atmosphere = Atmosphere.new()
	atmosphere.name = "CourtyardAtmosphere"
	add_child(atmosphere)
	atmosphere.setup(landscape, environment, $ReflectingPool.material_override, mobile_quality)
	get_viewport().size_changed.connect(_apply_camera)
	_apply_camera()


func _build_contours() -> void:
	if RenderingServer.get_current_rendering_method() != "forward_plus": return
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var pass_node := MeshInstance3D.new()
	pass_node.name = "PaintedContours"
	pass_node.mesh = quad
	# Screen pass belongs to the primary camera only; never recurse through the pool.
	pass_node.layers = 8
	pass_node.extra_cull_margin = 16384.0
	pass_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = load("res://src/title/courtyard/contour.gdshader")
	material.render_priority = 100
	pass_node.material_override = material
	camera.add_child(pass_node)
	contours = pass_node


func set_contours(enabled: bool) -> void:
	if contours != null: contours.visible = enabled


func _build_daylight() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://src/title/courtyard/painted_sky.gdshader")
	sky_material.set_shader_parameter("paper_texture", load("res://assets/title/courtyard/materials/white_plaster_rough_01_diffuse.jpg"))
	sky_material.set_shader_parameter("gilt_clouds",preload("res://assets/title/courtyard/gilt-clouds.svg"))
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("28575e")
	environment.ambient_light_energy = 0.35
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# Linear tonemapping keeps the chosen paint colours predictable; no filmic desaturation.
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.ssao_enabled = not mobile_quality and RenderingServer.get_current_rendering_method() == "forward_plus"
	environment.ssao_radius = 0.25
	environment.ssao_intensity = 0.65
	environment.ssr_enabled = false
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = false
	var world_environment := WorldEnvironment.new()
	world_environment.name = "CourtyardEnvironment"
	world_environment.environment = environment
	add_child(world_environment)
	key = DirectionalLight3D.new()
	key.name = "Daylight"
	key.rotation_degrees = Vector3(-53, -32, 0)
	key.light_color = Color("fff4df")
	key.light_energy = 1.85
	key.light_angular_distance = 0.5
	key.light_volumetric_fog_energy = 0.35
	key.shadow_enabled = not mobile_quality
	key.shadow_bias = 0.08
	key.shadow_normal_bias = 1.1
	key.directional_shadow_max_distance = 55
	add_child(key)
	accent = SpotLight3D.new()
	accent.name = "PavilionBounce"
	accent.position = Vector3(-1, 3.9, -12.9)
	accent.light_color = Color("ffe0b6")
	accent.light_energy = 3.6
	accent.light_volumetric_fog_energy = 0.45
	accent.spot_range = 7
	accent.spot_angle = 60
	add_child(accent)
	accent.look_at(Vector3(-1, 1.3, -15))
	for point in [Vector3(5.95, 3.0, -1.2), Vector3(-3.4, 3.5, -12.1), Vector3(1.45, 3.5, -12.1)]:
		var lamp := OmniLight3D.new()
		lamp.name = "LanternLight"
		lamp.position = point
		lamp.light_color = Color("f3ad72")
		lamp.light_energy = 0.9
		lamp.light_volumetric_fog_energy = 0.35
		lamp.omni_range = 2.5
		add_child(lamp)



func _build_water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(12.6, 13.9)
	var water := MeshInstance3D.new()
	water.name = "ReflectingPool"
	water.layers = 2
	water.mesh = mesh
	water.position = Vector3(0, 0.055, -5.0)
	var material := ShaderMaterial.new()
	material.shader = load("res://src/title/courtyard/water.gdshader")
	water.material_override = material
	add_child(water)


func _build_planar_reflection() -> void:
	mirror_viewport = SubViewport.new()
	mirror_viewport.name = "WaterReflectionView"
	mirror_viewport.world_3d = get_world_3d()
	mirror_viewport.size = Vector2i(800, 450)
	mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mirror_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(mirror_viewport)
	mirror_camera = Camera3D.new()
	mirror_camera.cull_mask = 1
	mirror_camera.near = 0.1
	mirror_camera.far = 180.0
	mirror_viewport.add_child(mirror_camera)
	mirror_camera.current = true
	var material: ShaderMaterial = $ReflectingPool.material_override
	material.set_shader_parameter("reflection_texture", mirror_viewport.get_texture())


func _process(_delta: float) -> void:
	if not is_equal_approx(inspection, _camera_inspection): _apply_camera()


func _apply_camera() -> void:
	_camera_inspection = inspection
	camera.position = Vector3(1.55, 2.65, 8.4).lerp(Vector3(-0.55, 2.20, -0.5), inspection)
	_look_target = Vector3(-1.0, 2.65, -13).lerp(Vector3(-1, 2.55, -15), inspection)
	camera.look_at(_look_target)
	camera.fov = lerpf(66, 58, inspection)
	if mirror_camera != null:
		mirror_camera.position = Vector3(camera.position.x, 0.11 - camera.position.y, camera.position.z)
		mirror_camera.look_at(Vector3(_look_target.x, 0.11 - _look_target.y, _look_target.z))
		mirror_camera.fov = camera.fov
		var render_size := get_viewport().get_visible_rect().size
		mirror_viewport.size = Vector2i(maxi(320, int(render_size.x * 0.5)), maxi(180, int(render_size.y * 0.5)))


func show_detail(enabled: bool) -> Tween:
	if _motion != null: _motion.kill()
	_motion = create_tween()
	_motion.tween_property(self, "inspection", 1.0 if enabled else 0.0, 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return _motion


func reset_camera(value := 0.0) -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	inspection = clampf(value, 0.0, 1.0)
	_apply_camera()


func set_key_strength(value: float) -> void:
	key.light_energy = value


func set_accent_strength(value: float) -> void:
	accent.light_energy = value


func set_terrace_strength(value: float) -> void:
	for lamp: OmniLight3D in foreground.lamps: lamp.light_energy = clampf(value,0.0,4.0)


func set_reflections(enabled: bool) -> void:
	if mirror_viewport == null: return
	var material: ShaderMaterial = $ReflectingPool.material_override
	material.set_shader_parameter("reflection_strength", 0.50 if enabled else 0.0)
	mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED


func _exit_tree() -> void:
	# Break the viewport-texture -> shared world -> water material reference chain.
	var water := get_node_or_null("ReflectingPool")
	if water != null:
		water.material_override.set_shader_parameter("reflection_texture", null)
	if mirror_viewport != null: mirror_viewport.world_3d = null
