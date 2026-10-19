extends Node3D
class_name ExpeditionStylizedFire
## Three painted flame shapes, a restrained bloom, and shared local light. No gameplay RNG.
const FLAME_SHADER = preload("res://src/shaders/expedition_flame.gdshader")
var enabled := true
var animate := true
var glow := true
var clock := 0.0
var pulse := 1.0
var style: ExpeditionFlatStyle
var camera: Camera3D
var environment: Environment
var flame_root: Node3D
var brazier: Node3D
var light: OmniLight3D
var _paints: Array[ShaderMaterial] = []
var _sparks: Array[MeshInstance3D] = []
var _halo: MeshInstance3D
var _halo_material: ShaderMaterial
var manage_environment := true
var ghost_fire := false


func setup(materials: ExpeditionFlatStyle, view: Camera3D, settings: Environment, configure_environment := true) -> void:
	style = materials
	camera = view
	environment = settings
	manage_environment = configure_environment
	brazier = Node3D.new()
	add_child(brazier)
	var base := CylinderMesh.new()
	base.top_radius = .25
	base.bottom_radius = .25
	base.height = .06
	base.radial_segments = 8
	style.mesh(brazier,base,Vector3(0,.03,0),"stone",.65)
	for angle in [30.0,150.0,270.0]:
		var a := deg_to_rad(angle)
		style.mesh(brazier,TypeMeshes.beveled_box(Vector3(.055,.18,.055),.006),Vector3(cos(a)*.12,.14,sin(a)*.12),"bronze",.45)
	var bowl := CylinderMesh.new()
	bowl.top_radius = .215
	bowl.bottom_radius = .145
	bowl.height = .17
	bowl.radial_segments = 8
	style.mesh(brazier,bowl,Vector3(0,.265,0),"bronze",.65)
	var mouth := CylinderMesh.new()
	mouth.top_radius = .165
	mouth.bottom_radius = .165
	mouth.height = .006
	mouth.radial_segments = 12
	var charcoal := MeshInstance3D.new()
	charcoal.mesh = mouth
	charcoal.position.y = .352
	charcoal.material_override = style.solid_material("ink")
	brazier.add_child(charcoal)
	flame_root = Node3D.new()
	flame_root.position.y = .355
	add_child(flame_root)
	_halo_material = ShaderMaterial.new()
	_halo_material.shader = preload("res://src/shaders/expedition_ground_glow.gdshader")
	var halo_shape := QuadMesh.new()
	halo_shape.size = Vector2(.90,1.05)
	_halo = MeshInstance3D.new()
	_halo.mesh = halo_shape
	_halo.material_override = _halo_material
	_halo.position = Vector3(0,.3,-.035)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame_root.add_child(_halo)
	_add_flame(_curve(Vector2(-.17,.02),[
		[Vector2(-.25,.13),Vector2(-.14,.3),Vector2(-.09,.34)],
		[Vector2(-.11,.24),Vector2(-.01,.27),Vector2(.01,.42)],
		[Vector2(0,.5),Vector2(.10,.55),Vector2(.065,.67)],
		[Vector2(.24,.49),Vector2(.08,.38),Vector2(.17,.28)],
		[Vector2(.25,.14),Vector2(.19,.02),Vector2(.09,0)],
		[Vector2(.04,-.025),Vector2(-.09,-.025),Vector2(-.17,.02)]
	]),0,.12,0.0)
	_add_flame(_curve(Vector2(-.105,.01),[
		[Vector2(-.15,.11),Vector2(-.025,.17),Vector2(-.015,.29)],
		[Vector2(.035,.23),Vector2(.055,.35),Vector2(.055,.46)],
		[Vector2(.19,.29),Vector2(.085,.22),Vector2(.13,.12)],
		[Vector2(.15,.02),Vector2(.03,-.03),Vector2(-.105,.01)]
	]),.006,.55,.8)
	_add_flame(_curve(Vector2(-.055,.005),[
		[Vector2(-.08,.08),Vector2(-.02,.12),Vector2(.012,.24)],
		[Vector2(.06,.15),Vector2(.11,.09),Vector2(.07,.01)],
		[Vector2(.04,-.02),Vector2(-.03,-.02),Vector2(-.055,.005)]
	]),.012,1.1,1.3)
	for i in 2:
		var spark := MeshInstance3D.new()
		var shape := QuadMesh.new()
		shape.size = Vector2(.014,.028)
		spark.mesh = shape
		spark.material_override = _paints[1]
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame_root.add_child(spark)
		_sparks.append(spark)
	light = OmniLight3D.new()
	light.position = Vector3(0,.75,0)
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = .8
	add_child(light)
	if manage_environment:
		for level in 7: environment.set_glow_level(level,[.3,.45,.3,.12,0.0,0.0,0.0][level])
		environment.glow_intensity = .55
		environment.glow_strength = .8
		environment.glow_hdr_threshold = .9
		environment.glow_bloom = 0.0
	refresh()
	sync_camera()
	if ghost_fire: flame_root.scale = Vector3(.74,1.16,1.0)
	update_at(0.0)


func set_ghost_fire(value: bool) -> void:
	ghost_fire = value
	if style!=null: refresh()


func _fire_colors() -> Array[Color]:
	if ghost_fire: return [Color("5540a3"),Color("7b9ee7"),Color("d0e3ff")]
	return [style.palette.fire_outer,style.palette.fire_inner,style.palette.fire_core]


func _light_color() -> Color:
	return Color("a99aec") if ghost_fire else style.palette.fire_light


func _energy() -> float:
	return style.palette.fire_energy*(.75 if ghost_fire else 1.0)


func _curve(start: Vector2, segments: Array) -> PackedVector2Array:
	var points := PackedVector2Array([start])
	var origin := start
	for segment: Array in segments:
		for step in range(1,11): points.append(origin.bezier_interpolate(segment[0],segment[1],segment[2],step/10.0))
		origin = segment[2]
	# The last cubic closes the shape; triangulation expects the first point only once.
	points.remove_at(points.size()-1)
	return points


func _add_flame(points: PackedVector2Array, depth: float, energy: float, phase: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in Geometry2D.triangulate_polygon(points):
		surface.set_normal(Vector3.BACK)
		surface.add_vertex(Vector3(points[index].x,points[index].y,0))
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	material.set_shader_parameter("emission_energy",energy)
	material.set_shader_parameter("phase",phase)
	_paints.append(material)
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.position.z = depth
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame_root.add_child(node)


func sync_camera() -> void:
	if flame_root!=null: flame_root.global_basis = camera.global_basis


func set_enabled(value: bool) -> void:
	enabled = value
	flame_root.visible = value
	refresh()


func set_animation(value: bool) -> void:
	animate = value
	if not value: update_at(0.0)


func set_glow(value: bool) -> void:
	glow = value
	if manage_environment: environment.glow_enabled = value and enabled
	_halo.visible = value


func refresh() -> void:
	if style==null: return
	var colors := style.palette
	var paints := _fire_colors()
	for i in _paints.size(): _paints[i].set_shader_parameter("paint",paints[i])
	style.set_fire_light(global_position+Vector3(0,.75,0),_light_color(),_energy() if enabled else 0.0,colors.fire_radius)
	light.light_color = _light_color()
	light.omni_range = colors.fire_radius
	light.light_energy = _energy()*pulse if enabled else 0.0
	if manage_environment: environment.glow_enabled = glow and enabled
	_halo.visible = glow
	_halo_material.set_shader_parameter("tint",Color(paints[1].r,paints[1].g,paints[1].b,.13*pulse))


func update_at(time: float) -> void:
	clock = time
	pulse = 1.0 + sin(time*4.1)*.07 + sin(time*7.7+.6)*.035
	for material in _paints: material.set_shader_parameter("clock",time)
	style.set_fire_pulse(pulse)
	light.light_energy = _energy()*pulse if enabled else 0.0
	var tint := _fire_colors()[1]
	if ghost_fire: flame_root.position.y = .44+sin(time*1.2)*.022
	_halo_material.set_shader_parameter("tint",Color(tint.r,tint.g,tint.b,.13*pulse))
	for i in _sparks.size():
		var phase := fposmod(time*.39+i*.47,1.0)
		_sparks[i].position = Vector3(-.07+i*.13+sin(time*1.8+i)*.025,.28+phase*.56,.018)
		_sparks[i].visible = phase>.15 and phase<.9
		_sparks[i].scale = Vector3.ONE*(1.0-phase*.65)


func _process(delta: float) -> void:
	if style!=null and enabled and animate: update_at(clock+delta)
