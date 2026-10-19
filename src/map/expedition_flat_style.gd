extends RefCounted
class_name ExpeditionFlatStyle
## Applies flat face colors and silhouette ink to existing meshes without changing their geometry.
const FACE_SHADER = preload("res://src/shaders/expedition_flat_faces.gdshader")
const LIT_FACE_SHADER = preload("res://src/shaders/expedition_lit_faces.gdshader")
const OUTLINE_SHADER = preload("res://src/shaders/expedition_flat_outline.gdshader")
var palette: ExpeditionFlatPalette
var camera: Camera3D
var enabled := true
var scene_lighting := false
var static_capture := false
var _faces: Dictionary = {}
var _inks: Dictionary = {}
var _solids: Dictionary = {}
var _edge_cache: Dictionary = {}
var _items: Array[MeshInstance3D] = []
var _outline_cursor := 0
var _fire_position := Vector3.ZERO
var _fire_color := Color("ffc078")
var _fire_energy := 0.0
var _fire_radius := 2.2
var _fire_pulse := 1.0


func reset_geometry_tracking() -> void:
	# A new expedition owns new geometry; discard references to the previous map.
	_items.clear()
	_edge_cache.clear()
	_outline_cursor = 0


func _init(colors: ExpeditionFlatPalette) -> void:
	palette = colors
	palette.changed.connect(refresh)


func set_palette(colors: ExpeditionFlatPalette) -> void:
	if palette.changed.is_connected(refresh): palette.changed.disconnect(refresh)
	palette = colors
	palette.changed.connect(refresh)
	refresh()


func face_material(role: String) -> ShaderMaterial:
	if not _faces.has(role):
		var material := ShaderMaterial.new()
		material.shader = LIT_FACE_SHADER if scene_lighting else FACE_SHADER
		_faces[role] = material
		_update_face(material, role)
	return _faces[role]


func solid_material(role: String) -> Material:
	if not _solids.has(role):
		var material: Material
		if role in ["slab_light","slab_dark"]:
			material = ShaderMaterial.new()
			material.shader = LIT_FACE_SHADER if scene_lighting else FACE_SHADER
		else:
			material = StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_solids[role] = material
		_update_solid(material, role)
	return _solids[role]


func mesh(parent: Node3D, shape: Mesh, position: Vector3, role: String, outline_scale := 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = position
	var original := StandardMaterial3D.new()
	original.albedo_color = palette.tones(role)[1]
	original.roughness = 0.8
	node.material_override = original
	parent.add_child(node)
	apply(node, role, outline_scale)
	return node


func apply(node: MeshInstance3D, role: String, outline_scale := 1.0) -> void:
	if node.has_meta("flat_role"): return
	node.set_meta("flat_role", role)
	node.set_meta("flat_original", node.material_override)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if scene_lighting else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if static_capture:
		node.set_meta("outline_scale",outline_scale)
		if enabled: node.material_override = face_material(role)
		node.set_meta("garden_face_material",node.material_override)
		return
	var outline := MeshInstance3D.new()
	outline.name = "InkContour"
	outline.set_meta("flat_outline_only", true)
	outline.mesh = ArrayMesh.new()
	outline.material_override = _ink_material(outline_scale)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.visible = enabled and outline_scale > 0.0
	node.add_child(outline)
	node.set_meta("flat_outline", outline)
	node.set_meta("outline_scale", outline_scale)
	_items.append(node)
	if enabled: node.material_override = face_material(role)


func apply_legacy(parent: Node) -> void:
	if parent.has_meta("flat_outline_only"): return
	# Snapshot children first: applying the style appends an outline mesh to each mesh.
	for child in parent.get_children(): apply_legacy(child)
	if parent is MeshInstance3D and not parent.has_meta("flat_role"):
		var role := "stone"
		if parent.material_override is StandardMaterial3D:
			var color: Color = parent.material_override.albedo_color
			role = "seal" if color.r > color.g * 1.2 else "bronze"
		apply(parent, role, 0.65)


func set_enabled(value: bool) -> void:
	enabled = value
	for item in _items:
		if not is_instance_valid(item): continue
		item.material_override = face_material(item.get_meta("flat_role")) if value else item.get_meta("flat_original")
		var outline: MeshInstance3D = item.get_meta("flat_outline")
		outline.visible = value and float(item.get_meta("outline_scale")) > 0.0


func refresh() -> void:
	for role in _faces: _update_face(_faces[role], role)
	for role in _solids: _update_solid(_solids[role], role)
	for scale_value in _inks:
		_inks[scale_value].set_shader_parameter("ink_color", palette.ink)
		_inks[scale_value].set_shader_parameter("width_pixels", palette.outline_pixels * float(scale_value))


func set_scene_lighting(value: bool) -> void:
	# Opt in per preview/world. Existing flat samples keep their previous material path.
	scene_lighting = value
	for material: ShaderMaterial in _faces.values():
		material.shader = LIT_FACE_SHADER if value else FACE_SHADER
	for material in _solids.values():
		if material is ShaderMaterial: material.shader = LIT_FACE_SHADER if value else FACE_SHADER
	for item in _items:
		if is_instance_valid(item): item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if value else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	refresh()


func _update_face(material: ShaderMaterial, role: String) -> void:
	var colors := palette.tones(role)
	material.set_shader_parameter("top_color", colors[0])
	material.set_shader_parameter("front_color", colors[1])
	material.set_shader_parameter("side_color", colors[2])
	material.set_shader_parameter("diffuse_response", palette.roof_light_response if role=="roof" else 1.0)
	_update_fire(material)


func _update_solid(material: Material, role: String) -> void:
	if material is ShaderMaterial:
		_update_face(material,role)
		return
	var color := palette.tones(role)[0]
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED


func set_fire_light(position: Vector3, color: Color, energy: float, radius: float) -> void:
	_fire_position = position
	_fire_color = color
	_fire_energy = energy
	_fire_radius = radius
	for material in _faces.values(): _update_fire(material)
	for material in _solids.values():
		if material is ShaderMaterial: _update_fire(material)


func set_fire_pulse(value: float) -> void:
	_fire_pulse = value
	for material in _faces.values(): material.set_shader_parameter("fire_pulse",value)
	for material in _solids.values():
		if material is ShaderMaterial: material.set_shader_parameter("fire_pulse",value)


func _update_fire(material: ShaderMaterial) -> void:
	material.set_shader_parameter("fire_position",_fire_position)
	material.set_shader_parameter("fire_color",_fire_color)
	material.set_shader_parameter("fire_energy",_fire_energy)
	material.set_shader_parameter("fire_radius",_fire_radius)
	material.set_shader_parameter("fire_pulse",_fire_pulse)


func _ink_material(scale_value: float) -> ShaderMaterial:
	if not _inks.has(scale_value):
		var material := ShaderMaterial.new()
		material.shader = OUTLINE_SHADER
		material.set_shader_parameter("ink_color", palette.ink)
		material.set_shader_parameter("width_pixels", palette.outline_pixels * scale_value)
		_inks[scale_value] = material
	return _inks[scale_value]


func _edges(source: Mesh) -> Array:
	var key := source.get_instance_id()
	if _edge_cache.has(key): return _edge_cache[key]
	var edges: Dictionary = {}
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for triangle in range(0,count,3):
			var tri: Array[int] = []
			for j in 3: tri.append(indices[triangle+j] if not indices.is_empty() else triangle+j)
			var normal := (normals[tri[0]]+normals[tri[1]]+normals[tri[2]]).normalized()
			for j in 3:
				var a := vertices[tri[j]].snapped(Vector3.ONE*.00001)
				var b := vertices[tri[(j+1)%3]].snapped(Vector3.ONE*.00001)
				var pair := [a,b] if _before(a,b) else [b,a]
				var edge_key := str(pair[0])+":"+str(pair[1])
				if not edges.has(edge_key): edges[edge_key] = {"a":pair[0],"b":pair[1],"normals":[]}
				edges[edge_key].normals.append(normal)
	var contours: Array = []
	for edge: Dictionary in edges.values():
		var normals_unique := PackedVector3Array()
		for normal: Vector3 in edge.normals:
			var duplicate := false
			for existing in normals_unique:
				if existing.is_equal_approx(normal): duplicate = true; break
			if not duplicate: normals_unique.append(normal)
		# A shared coplanar edge can never be a silhouette. Discard internal
		# triangulation once, instead of testing it every camera update.
		if edge.normals.size()>1 and normals_unique.size()==1: continue
		edge.normals = normals_unique
		edge.mid = (edge.a+edge.b)*.5
		contours.append(edge)
	_edge_cache[key] = contours
	return _edge_cache[key]


func _before(a: Vector3, b: Vector3) -> bool:
	if not is_equal_approx(a.x,b.x): return a.x < b.x
	if not is_equal_approx(a.y,b.y): return a.y < b.y
	return a.z < b.z


func outline_refresh_in_progress() -> bool:
	return _outline_cursor>0


func _inside_frustum(bounds: AABB, planes: Array[Plane]) -> bool:
	for plane in planes:
		var n := plane.normal
		var nearest := Vector3(bounds.position.x if n.x>=0 else bounds.end.x,bounds.position.y if n.y>=0 else bounds.end.y,bounds.position.z if n.z>=0 else bounds.end.z)
		if plane.distance_to(nearest)>0: return false
	return true


func refresh_outlines(budget_ms := 0.0) -> bool:
	if camera==null: return true
	var deadline := Time.get_ticks_usec()+int(budget_ms*1000)
	var start := _outline_cursor
	var planes := camera.get_frustum()
	var orthogonal := camera.projection==Camera3D.PROJECTION_ORTHOGONAL
	while _outline_cursor<_items.size():
		if budget_ms>0 and _outline_cursor>start and Time.get_ticks_usec()>=deadline: return false
		var node := _items[_outline_cursor]
		_outline_cursor += 1
		if not is_instance_valid(node) or not node.is_inside_tree() or not node.is_visible_in_tree(): continue
		if float(node.get_meta("outline_scale"))<=0 or not _inside_frustum(node.global_transform*node.get_aabb(),planes): continue
		# Transform the camera once. Local dot products give the same facing
		# signs as inverse-transpose normals in world space, including scale.
		var local_camera := node.to_local(camera.global_position)
		var local_direction := node.global_basis.inverse()*camera.global_basis.z if orthogonal else Vector3.ZERO
		var edges := _edges(node.mesh)
		var selected := PackedInt32Array()
		for index in edges.size():
			var edge: Dictionary = edges[index]
			var toward: Vector3 = local_direction if orthogonal else local_camera-edge.mid
			var front := false
			var back := false
			for normal: Vector3 in edge.normals:
				var facing: float = normal.dot(toward)
				front = front or facing > .00001
				back = back or facing < -.00001
			if not front or (not back and edge.normals.size()>1): continue
			selected.append(index)
		# Camera translation usually preserves the silhouettes. Reuse the mesh
		# until the set of visible edges changes, instead of rebuilding each frame.
		if node.has_meta("outline_edges") and node.get_meta("outline_edges") == selected: continue
		node.set_meta("outline_edges",selected)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in selected:
			var edge: Dictionary = edges[index]
			var direction: Vector3 = (edge.b-edge.a).normalized()
			for corner in [Vector2(0,-1),Vector2(1,-1),Vector2(1,1),Vector2(0,-1),Vector2(1,1),Vector2(0,1)]:
				surface.set_normal(direction)
				surface.set_uv(corner)
				surface.add_vertex(edge.a if corner.x==0 else edge.b)
		var outline: MeshInstance3D = node.get_meta("flat_outline")
		outline.mesh = surface.commit() if not selected.is_empty() else ArrayMesh.new()
	_outline_cursor = 0
	var live: Array[MeshInstance3D] = []
	for item in _items:
		if is_instance_valid(item): live.append(item)
	_items = live
	return true


func dispose() -> void:
	if palette.changed.is_connected(refresh): palette.changed.disconnect(refresh)
