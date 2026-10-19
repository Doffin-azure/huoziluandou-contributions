extends Node3D
## Eight-tile visibility chunks. Roofs remain separate for local occlusion.
var entries: Array = []
var groups := {}
var instance_total := 0
var wall_entries: Array = []
var wall_owners: Array[Node3D] = []
var wall_batches: Array = []
var _owner_ids := {}
var _visibility: ImageTexture
var _paints := {}
var _paint_keys := {}
var _shaders := {}
var _source_arrays := {}
var wall_groups := 0


func register(owner: Node3D) -> void:
	var wall: bool = str(owner.get_meta("garden_prototype","")).begins_with("boundary:")
	if wall and not _owner_ids.has(owner.get_instance_id()):
		_owner_ids[owner.get_instance_id()] = wall_owners.size(); wall_owners.append(owner)
	for mesh: MeshInstance3D in owner.find_children("*","MeshInstance3D",true,false):
		if mesh.get_meta("roof_occluder",false) or mesh.mesh==null: continue
		if not mesh.get_parent() is Node3D: continue
		mesh.visible = false
		if wall: wall_entries.append({"owner":owner,"mesh":mesh})
		else: entries.append({"owner":owner,"mesh":mesh})


func build_walls() -> void:
	var image := Image.create(64,maxi(1,ceili(wall_owners.size()/64.0)),false,Image.FORMAT_RGBA8); image.fill(Color.BLACK)
	_visibility = ImageTexture.create_from_image(image)
	var combined := {}
	var deadline := Time.get_ticks_usec()+4000
	for entry in wall_entries:
		var mesh: MeshInstance3D = entry.mesh
		var chunk := Vector2i(floori(mesh.global_position.x/8),floori(mesh.global_position.z/8))
		var key := str(chunk)+_paint_key(mesh.material_override)
		if not combined.has(key): combined[key] = {"paint":mesh.material_override,"parts":[],"shadow":mesh.cast_shadow}
		combined[key].parts.append(entry)
	for key: String in combined:
		var data: Dictionary = combined[key]
		var vertices := PackedVector3Array(); var normals := PackedVector3Array()
		var coordinates := PackedVector2Array(); var visibility := PackedVector2Array()
		var indices := PackedInt32Array()
		for entry in data.parts:
			var mesh: MeshInstance3D = entry.mesh
			var index: int = _owner_ids[entry.owner.get_instance_id()]
			var uv := Vector2((index%64+.5)/64.0,(index/64+.5)/image.get_height())
			var transform: Transform3D = global_transform.affine_inverse()*mesh.global_transform
			var normal_basis := transform.basis.inverse().transposed()
			for part in mesh.mesh.get_surface_count():
				var source_key := str(mesh.mesh.get_instance_id())+":"+str(part)
				if not _source_arrays.has(source_key): _source_arrays[source_key] = mesh.mesh.surface_get_arrays(part)
				var arrays: Array = _source_arrays[source_key]
				var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var offset := vertices.size()
				for i in source_vertices.size():
					vertices.append(transform*source_vertices[i])
					normals.append((normal_basis*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
					coordinates.append(arrays[Mesh.ARRAY_TEX_UV][i] if arrays[Mesh.ARRAY_TEX_UV]!=null else Vector2.ZERO)
					visibility.append(uv)
				if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty():
					for vertex: int in arrays[Mesh.ARRAY_INDEX]: indices.append(offset+vertex)
				else:
					for vertex in source_vertices.size(): indices.append(offset+vertex)
		var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = coordinates; arrays[Mesh.ARRAY_TEX_UV2] = visibility; arrays[Mesh.ARRAY_INDEX] = indices
		var merged := ArrayMesh.new(); merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var result := MeshInstance3D.new(); result.mesh = merged; result.material_override = _masked(data.paint)
		result.cast_shadow = data.shadow; add_child(result); wall_groups += 1
		wall_batches.append({"node":result,"owners":data.parts.map(func(entry): return entry.owner)})
		if Time.get_ticks_usec()>deadline:
			await get_tree().process_frame; deadline = Time.get_ticks_usec()+4000
	_source_arrays.clear()


func _paint_key(paint: Material) -> String:
	if paint==null: return "none"
	var id := paint.get_instance_id()
	if _paint_keys.has(id): return _paint_keys[id]
	if not paint is ShaderMaterial: return str(paint.get_instance_id())
	var parameters := {}
	for property in paint.shader.get_shader_uniform_list():
		var value: Variant = paint.get_shader_parameter(property.name)
		if value!=null: parameters[property.name] = value
	var key: String = paint.shader.resource_path+var_to_str(parameters)
	_paint_keys[id] = key
	return key


func _masked(base: Material) -> Material:
	var key := _paint_key(base)
	if _paints.has(key): return _paints[key]
	if not base is ShaderMaterial: return base
	var source: String = base.shader.resource_path
	if not _shaders.has(source):
		var shader := Shader.new()
		var code: String = base.shader.code
		code = code.replace("void vertex() {","varying vec2 visibility_uv;\nuniform sampler2D visibility_mask : filter_nearest, repeat_disable;\nvoid vertex() {\n visibility_uv = UV2;")
		var start := code.find("void fragment() {")
		var end := code.find("\n}",start)
		code = code.insert(end,"\n ALBEDO *= texture(visibility_mask,visibility_uv).g;\n")
		code = code.replace("void fragment() {","void fragment() {\n if (texture(visibility_mask,visibility_uv).r < .5) discard;")
		shader.code = code; _shaders[source] = shader
	var paint := ShaderMaterial.new(); paint.shader = _shaders[source]
	for property in base.shader.get_shader_uniform_list():
		var value: Variant = base.get_shader_parameter(property.name)
		if value!=null: paint.set_shader_parameter(property.name,value)
	paint.set_shader_parameter("visibility_mask",_visibility)
	_paints[key] = paint
	return paint


func refresh() -> void:
	var image := Image.create(64,maxi(1,ceili(wall_owners.size()/64.0)),false,Image.FORMAT_RGBA8); image.fill(Color.BLACK)
	for i in wall_owners.size():
		var owner := wall_owners[i]
		image.set_pixel(i%64,i/64,Color(1 if owner.is_visible_in_tree() else 0,float(owner.get_meta("garden_dim",1.0)),0))
	_visibility.update(image)
	# 可见性遮罩只作用于颜色 pass；shadow pass 仍会使用整块合并墙体。
	# 因此只要合并批次中有不可见/未加载的墙，就关闭该批次的投影，
	# 避免“看不见的墙”在地面留下带窗洞的长影。
	for batch: Dictionary in wall_batches:
		var any_visible := false
		var all_visible := true
		for owner in batch.owners:
			if not is_instance_valid(owner) or not owner.is_visible_in_tree(): all_visible = false
			else: any_visible = true
		var node: MeshInstance3D = batch.node
		if not is_instance_valid(node): continue
		node.visible = any_visible
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if all_visible else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var desired := {}
	for entry in entries:
		if not entry.owner.is_visible_in_tree(): continue
		var mesh: MeshInstance3D = entry.mesh
		var chunk := Vector2i(floori(mesh.global_position.x/8),floori(mesh.global_position.z/8))
		var key := str([chunk,mesh.mesh.get_instance_id(),mesh.material_override.get_instance_id() if mesh.material_override!=null else 0])
		if not desired.has(key): desired[key] = {"mesh":mesh.mesh,"paint":mesh.material_override,"shadow":mesh.cast_shadow,"transforms":[]}
		desired[key].transforms.append(global_transform.affine_inverse()*mesh.global_transform)
	instance_total = 0
	for key: String in groups:
		if not desired.has(key): groups[key].visible = false
	for key: String in desired:
		var data: Dictionary = desired[key]
		if not groups.has(key):
			var batch := MultiMeshInstance3D.new(); batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D; batch.multimesh.mesh = data.mesh
			batch.material_override = data.paint; batch.cast_shadow = data.shadow
			add_child(batch); groups[key] = batch
		var batch: MultiMeshInstance3D = groups[key]
		batch.visible = true
		if batch.multimesh.instance_count<data.transforms.size(): batch.multimesh.instance_count = data.transforms.size()
		batch.multimesh.visible_instance_count = data.transforms.size()
		for i in data.transforms.size(): batch.multimesh.set_instance_transform(i,data.transforms[i])
		instance_total += data.transforms.size()
