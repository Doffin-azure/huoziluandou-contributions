extends Node3D
## Runtime floor marks use the same stone surface, with inset lighting normals.
## The original inlaid labels remain available for the isolated asset studies.
var glyph := ""
var palette: ExpeditionFlatPalette
var edge: Label3D
var face: Label3D
var spent := false
var floor_imprint := false
const MASK = preload("res://src/map/expedition_glyph_mask.gd")
const ENGRAVING = preload("res://src/shaders/expedition_engraved_glyph.gdshader")
var floor_mesh: MeshInstance3D
var floor_paint: ShaderMaterial
var embers: MultiMeshInstance3D
var _font: Font
var _in_sight := true


func setup(text: String, colors: ExpeditionFlatPalette, font: Font) -> void:
	glyph = text
	palette = colors
	_font = font
	edge = _label(font, 13)
	edge.position = Vector3(-.006, .006, -.006)
	face = _label(font, 8)
	face.position.y = .009
	palette.changed.connect(refresh)
	refresh()


func _exit_tree() -> void:
	if palette != null and palette.changed.is_connected(refresh): palette.changed.disconnect(refresh)


func _label(font: Font, width: int) -> Label3D:
	var result := Label3D.new()
	result.font = font
	result.font_size = 128
	result.pixel_size = .0045
	result.outline_size = width
	result.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	result.rotation_degrees.x = -90
	result.no_depth_test = false
	result.shaded = false
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(result)
	return result


func set_glyph(value: String) -> void:
	glyph = value
	refresh()


func set_spent(value: bool) -> void:
	spent = value
	refresh()


func set_in_sight(value: bool) -> void:
	_in_sight = value
	if embers!=null: embers.visible = floor_imprint and glyph=="火" and not spent and _in_sight


func set_floor_imprint(value := true, ground: ShaderMaterial = null) -> void:
	floor_imprint = value
	set_meta("ground_imprint",value)
	if value and floor_mesh==null:
		floor_mesh = MeshInstance3D.new()
		floor_mesh.name = "StoneIncision"
		var shape := PlaneMesh.new()
		shape.size = Vector2.ONE*.78
		floor_mesh.mesh = shape
		floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		floor_paint = ShaderMaterial.new()
		floor_paint.shader = ENGRAVING
		floor_mesh.material_override = floor_paint
		add_child(floor_mesh)
		# Almost coplanar; the shader supplies the inset and cut-face normals.
		position.y = .003
	if ground!=null:
		for parameter in ["fog_mask","land_mask","theme_tint","stone_color","stone_cool","stone_warm","fog_color","vision_origin","vision_size","clip_vision_bounds","stone_grid_offset","court_origin","court_x","court_z","court_size","court_style"]:
			var setting: Variant = ground.get_shader_parameter(parameter)
			if setting!=null: floor_paint.set_shader_parameter(parameter,setting)
	refresh()


func refresh() -> void:
	if face == null: return
	edge.text = glyph
	edge.modulate = palette.glyph_edge
	edge.outline_modulate = palette.glyph_edge
	face.text = glyph
	face.modulate = palette.glyph_fill.lerp(palette.stone_top, .50) if spent else palette.glyph_fill
	face.outline_modulate = palette.glyph_recess
	edge.visible = not floor_imprint
	face.visible = not floor_imprint
	if floor_mesh!=null:
		floor_mesh.visible = floor_imprint
		floor_paint.set_shader_parameter("glyph_mask",MASK.texture_for(_font,glyph))
		floor_paint.set_shader_parameter("worn",1.0 if spent else 0.0)
	if floor_imprint and glyph=="火" and embers==null: _build_embers()
	set_in_sight(_in_sight)


func _build_embers() -> void:
	embers = MultiMeshInstance3D.new()
	embers.name = "FaintGlyphEmbers"
	var mesh := SphereMesh.new()
	mesh.radius = .0045
	mesh.height = .014
	mesh.radial_segments = 4
	mesh.rings = 1
	var particles := MultiMesh.new()
	particles.transform_format = MultiMesh.TRANSFORM_3D
	particles.use_custom_data = true
	particles.mesh = mesh
	particles.instance_count = 5
	# These anchors sit on the fire character's five main stroke regions.
	var anchors := [Vector3(-.19,.006,-.07),Vector3(.16,.004,-.08),Vector3(0,.005,.08),Vector3(-.16,.004,.20),Vector3(.16,.006,.20)]
	for i in particles.instance_count:
		particles.set_instance_transform(i,Transform3D(Basis.IDENTITY,anchors[i]))
		particles.set_instance_custom_data(i,Color(i*.197,.13+i*.17,0,1))
	embers.multimesh = particles
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://src/shaders/expedition_glyph_embers.gdshader")
	embers.material_override = paint
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(embers)
