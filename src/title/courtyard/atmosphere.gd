extends Node3D
## Bounded ambient motion, local volumetric fog and one instanced draw of petals.
const PETAL_COUNT := 112
const MIST_SHADER := preload("res://src/title/courtyard/low_mist.gdshader")
const PETAL_SHADER := preload("res://src/title/courtyard/falling_petal.gdshader")
var elapsed := 0.0
var motion_enabled := true
var fog_strength := 1.0
var petals: MultiMeshInstance3D
var fog_volumes: Array[FogVolume] = []
var _tracks: Array[Dictionary] = []
var _wind_materials: Array[ShaderMaterial] = []
var _fog_materials: Array[ShaderMaterial] = []
var _environment: Environment
var _water: ShaderMaterial
var _supports_fog := false


func setup(landscape: Node3D, environment: Environment, water: ShaderMaterial, mobile_quality := false) -> void:
	_environment = environment
	_water = water
	for instance in landscape.get_children():
		if instance is not MeshInstance3D: continue
		var material: Material = instance.material_override
		while material is ShaderMaterial:
			if not _wind_materials.has(material): _wind_materials.append(material)
			material = material.next_pass
	if not mobile_quality: _build_fog()
	_build_petals()
	if mobile_quality: petals.multimesh.visible_instance_count = 28
	seek(0.0)


func _build_fog() -> void:
	_supports_fog = RenderingServer.get_current_rendering_method() == "forward_plus"
	if not _supports_fog: return
	_environment.volumetric_fog_enabled = true
	_environment.volumetric_fog_density = 0.0
	_environment.volumetric_fog_length = 48.0
	_environment.volumetric_fog_detail_spread = 0.65
	_environment.volumetric_fog_sky_affect = 0.0
	_environment.volumetric_fog_gi_inject = 0.0
	_environment.volumetric_fog_ambient_inject = 0.2
	_environment.volumetric_fog_anisotropy = 0.25
	_environment.volumetric_fog_temporal_reprojection_amount = 0.75
	# Pool mist stays below the sign and windows; the second layer separates the rear trees.
	for definition in [[Vector3(0, 0.70, -5.0), Vector3(15, 2.6, 17), 0.052], [Vector3(0, 3.0, -23), Vector3(34, 9, 10), 0.020]]:
		var volume := FogVolume.new()
		volume.name = "PoolMist" if fog_volumes.is_empty() else "DistantMist"
		volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		volume.position = definition[0]
		volume.size = definition[1]
		var material := ShaderMaterial.new()
		material.shader = MIST_SHADER
		material.set_shader_parameter("density", definition[2])
		volume.material = material
		volume.set_meta("base_density", definition[2])
		add_child(volume)
		fog_volumes.append(volume)
		_fog_materials.append(material)


func _build_petals() -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf := preload("res://src/title/courtyard/foreground.gd").leaf_mesh()
	mesh.append_from(leaf,0,Transform3D(Basis(Vector3.RIGHT,PI*.5),Vector3.ZERO))
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = mesh.commit()
	instances.instance_count = PETAL_COUNT
	var random := RandomNumberGenerator.new()
	random.seed = 2026101602
	for i in PETAL_COUNT:
		var origin := Vector3(random.randf_range(-5.3, 4.0), random.randf_range(4.0, 6.0), random.randf_range(-12.0, -2.8))
		_tracks.append({"origin": origin, "duration": random.randf_range(11.0, 19.0), "phase": random.randf(), "size": random.randf_range(0.10, 0.19), "drift": Vector3(random.randf_range(0.15, 1.1), 0, random.randf_range(3.0, 7.0)), "spin": random.randf_range(0.7, 1.5)})
		if i>=PETAL_COUNT-8:
			_tracks[-1].origin = Vector3(random.randf_range(-2.4,4.4),random.randf_range(2.5,4.1),random.randf_range(3.0,6.6))
			_tracks[-1].drift = Vector3(random.randf_range(.1,.4),0,random.randf_range(.7,1.4))
			_tracks[-1].size = random.randf_range(.13,.25)
		instances.set_instance_custom_data(i, Color(random.randf(), 0, 0, 1))
	petals = MultiMeshInstance3D.new()
	petals.name = "FallingPetals"
	petals.multimesh = instances
	petals.custom_aabb = AABB(Vector3(-7, -0.3, -14), Vector3(14, 8, 24))
	petals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pigment := ShaderMaterial.new()
	pigment.shader = PETAL_SHADER
	petals.material_override = pigment
	add_child(petals)


func petal_transform(index: int, at_time: float) -> Transform3D:
	var track: Dictionary = _tracks[index]
	var progress := fposmod(at_time / float(track.duration) + float(track.phase), 1.0)
	var phase := float(track.phase) * TAU
	var origin: Vector3 = track.origin
	var petal_position: Vector3 = origin + track.drift * progress
	petal_position.y = lerpf(origin.y, 0.24, progress)
	petal_position.x += sin(at_time * 0.65 + phase) * 0.28
	petal_position.z += sin(at_time * 0.43 + phase) * 0.22
	var flutter := at_time * float(track.spin) + phase
	var petal_basis := Basis.from_euler(Vector3(sin(flutter) * 0.8, flutter * 0.6, sin(flutter * 0.73) * 0.9))
	# Shrink at the ends to conceal the respawn and landing; never accumulate nodes.
	var envelope := smoothstep(0.0, 0.06, progress) * (1.0 - smoothstep(0.89, 1.0, progress))
	return Transform3D(petal_basis.scaled(Vector3.ONE * float(track.size) * maxf(0.0001, envelope)), petal_position)


func _process(delta: float) -> void:
	if motion_enabled: seek(elapsed + delta)


func seek(at_time: float) -> void:
	elapsed = maxf(0.0, at_time)
	if petals == null: return
	var count := petals.multimesh.visible_instance_count
	for i in (PETAL_COUNT if count < 0 else count):
		petals.multimesh.set_instance_transform(i, petal_transform(i, elapsed))
	for material in _wind_materials: material.set_shader_parameter("ambient_time", elapsed)
	for material in _fog_materials: material.set_shader_parameter("ambient_time", elapsed)
	_water.set_shader_parameter("ambient_time", elapsed)


func set_fog_strength(value: float) -> void:
	fog_strength = clampf(value, 0.0, 1.5)
	_environment.volumetric_fog_enabled = _supports_fog and fog_strength > 0.0
	for i in fog_volumes.size():
		_fog_materials[i].set_shader_parameter("density", float(fog_volumes[i].get_meta("base_density")) * fog_strength)


func set_motion(enabled: bool) -> void:
	motion_enabled = enabled
