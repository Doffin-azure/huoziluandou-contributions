extends Node3D
## Baked static body with independently fading roof and budgeted light sockets.
var roof_parts: Array[GeometryInstance3D] = []
var lamps: Array[OmniLight3D] = []
var _roof_target := 0.0
var _roof_alpha := 0.0
var _aperture_ready := false
var _aperture_open := false
var _wall_parts: Array[MeshInstance3D] = []
var _wall_ready := false
var _wall_open := false


func bind(painter: ExpeditionFlatStyle) -> void:
	roof_parts.clear(); lamps.clear(); _wall_parts.clear()
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("roof_occluder",false):
			roof_parts.append(mesh); mesh.set_meta("unfaded_shadow",mesh.cast_shadow)
		else: _wall_parts.append(mesh)
		var role := str(mesh.get_meta("garden_role",""))
		if not role.is_empty(): mesh.material_override = painter.face_material(role)
	for lamp: OmniLight3D in find_children("*","OmniLight3D",true,false):
		lamp.shadow_enabled = false; lamp.visible = false; lamps.append(lamp)
	set_process(false)


func set_roofs_faded(value: bool) -> void:
	var target := .88 if value else 0.0
	if target==_roof_target: return
	_roof_target = target; set_process(true)
	for mesh in roof_parts:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if value else int(mesh.get_meta("unfaded_shadow",GeometryInstance3D.SHADOW_CASTING_SETTING_ON))


func set_roof_aperture(aperture: Vector4, cut_plane := Vector4.ZERO, window := Vector4.ZERO) -> void:
	var opened := aperture.w>.5
	if not opened and not _aperture_open: return
	if not _aperture_ready:
		for mesh: GeometryInstance3D in roof_parts:
			if mesh is MeshInstance3D and mesh.material_override is ShaderMaterial:
				mesh.material_override = preload("res://src/map/garden_roof_aperture.gd").material(mesh.material_override)
		_aperture_ready = true
	for mesh: GeometryInstance3D in roof_parts:
		mesh.set_instance_shader_parameter("garden_roof_aperture",aperture)
		mesh.set_instance_shader_parameter("garden_roof_cut_plane",cut_plane)
		mesh.set_instance_shader_parameter("garden_roof_window",window)
		if opened!=_aperture_open:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if opened else int(mesh.get_meta("unfaded_shadow",GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
	_aperture_open = opened


func set_wall_cutaway(clip: Vector4, plane: Vector4) -> void:
	var opened := plane.w>.5
	if not opened and not _wall_open: return
	if not _wall_ready:
		for mesh in _wall_parts:
			if mesh.material_override is ShaderMaterial:
				mesh.material_override = preload("res://src/map/garden_roof_aperture.gd").wall_material(mesh.material_override)
		_wall_ready = true
	for mesh in _wall_parts:
		mesh.set_instance_shader_parameter("garden_wall_clip",clip)
		mesh.set_instance_shader_parameter("garden_wall_plane",plane)
	_wall_open = opened


func _process(delta: float) -> void:
	_roof_alpha = move_toward(_roof_alpha,_roof_target,delta*5)
	for mesh in roof_parts: mesh.transparency = _roof_alpha
	if is_equal_approx(_roof_alpha,_roof_target): set_process(false)


func set_lamps_enabled(value: bool) -> void:
	for lamp in lamps: lamp.visible = value
