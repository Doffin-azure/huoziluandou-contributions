extends RefCounted
## Mesh-only prototypes: no procedural _build() on repeated instances or returns.
const BAKED = preload("res://src/map/garden_baked_asset.gd")
const DIRECTORY := "res://assets/expedition/baked"
const REVISION := 15
static var _scenes := {}
static var hits := 0
static var misses := 0
static var load_ms := 0.0
static var bake_ms := 0.0
static var _outline_paint: ShaderMaterial
static var _requests := {}
static var _preloaded := false


static func file_for(key: String) -> String:
	return DIRECTORY.path_join("v%d_%s.scn" % [REVISION,key.sha256_text().substr(0,24)])


static func instantiate(key: String, builder: Callable, painter: ExpeditionFlatStyle) -> Node3D:
	if not _scenes.has(key):
		var path := file_for(key)
		if ResourceLoader.exists(path) and not OS.get_cmdline_user_args().has("--rebuild-garden"):
			var began := Time.get_ticks_usec()
			if _requests.has(path) and ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED:
				_scenes[key] = ResourceLoader.load_threaded_get(path); _requests.erase(path)
			else: _scenes[key] = load(path)
			load_ms += (Time.get_ticks_usec()-began)/1000.0
		else:
			var began := Time.get_ticks_usec()
			var previous := painter.static_capture; painter.static_capture = true
			var original: Node3D = builder.call()
			var optimized := bake(original)
			if key.begins_with("boundary:"):
				for part in optimized.find_children("*","MeshInstance3D",true,false): part.set_meta("roof_occluder",false)
			painter.static_capture = previous
			var scene := PackedScene.new(); scene.pack(optimized)
			_scenes[key] = scene
			optimized.free(); original.free(); misses += 1
			bake_ms += (Time.get_ticks_usec()-began)/1000.0
			if _scenes.size()>128: _scenes.erase(_scenes.keys()[0])
	else: hits += 1
	var asset: Node3D = _scenes[key].instantiate()
	asset.set_meta("garden_prototype",key)
	if key.begins_with("boundary:"):
		for part: MeshInstance3D in asset.find_children("*","MeshInstance3D",true,false):
			if part.material_override is ShaderMaterial and part.material_override.shader.resource_path.contains("roof"):
				part.set_meta("garden_role","roof")
	asset.bind(painter)
	return asset


static func bake(original: Node3D) -> Node3D:
	var root := Node3D.new(); root.set_script(BAKED); root.name = "BakedGardenAsset"
	var groups := {}
	_collect(original,Transform3D.IDENTITY,false,root,groups)
	for key: String in groups:
		var group: Dictionary = groups[key]
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Dictionary in group.parts:
			for index in part.mesh.get_surface_count(): surface.append_from(part.mesh,index,part.transform)
		var mesh := MeshInstance3D.new(); mesh.mesh = surface.commit(); mesh.material_override = group.paint
		if not str(group.role).is_empty(): mesh.set_meta("garden_role",group.role)
		mesh.set_meta("roof_occluder",group.roof); root.add_child(mesh)
		if group.outline: _outline(root,mesh,group.roof)
	_own(root,root)
	return root


static func _collect(node: Node, transform: Transform3D, roof: bool, root: Node3D, groups: Dictionary) -> void:
	if node is Node3D and not node.visible: return
	var local := transform
	if node is Node3D: local *= node.transform
	var is_roof := roof or bool(node.get_meta("roof_occluder",false))
	if node is MeshInstance3D and node.mesh!=null and not node.get_meta("flat_outline_only",false):
		var paint: Material = node.material_override
		var shader: String = paint.shader.resource_path if paint is ShaderMaterial else ""
		var role := str(node.get_meta("flat_role","")) if shader.ends_with("faces.gdshader") and node.get_meta("garden_face_material",null)==paint else ""
		if shader.contains("roof"):
			# Roof shading uses its original local coordinates and dimensions.
			var copy := MeshInstance3D.new(); copy.mesh = node.mesh; copy.material_override = paint
			copy.transform = local; copy.set_meta("roof_occluder",is_roof); root.add_child(copy)
			# Eaves, ridge caps and deliberate tile strokes already carry the ink.
			# Outlining the roof's triangulation adds crossing wires over each slope.
		else:
			var key := str(paint.get_instance_id() if paint!=null else 0)+":"+str(is_roof)
			if not groups.has(key): groups[key] = {"parts":[],"paint":paint,"role":role,"roof":is_roof,"outline":false}
			groups[key].parts.append({"mesh":node.mesh,"transform":local})
			groups[key].outline = groups[key].outline or (node.has_meta("flat_role") and float(node.get_meta("outline_scale",0.0))>.0)
	elif node is OmniLight3D or node is Label3D:
		var copy: Node3D = node.duplicate(0); copy.transform = local; root.add_child(copy)
	for child in node.get_children(): _collect(child,local,is_roof,root,groups)


static func _outline(parent: Node3D, body: MeshInstance3D, roof: bool) -> void:
	if _outline_paint==null:
		_outline_paint = ShaderMaterial.new(); _outline_paint.shader = preload("res://src/shaders/expedition_flat_outline.gdshader")
		_outline_paint.set_shader_parameter("ink_color",Color("081419")); _outline_paint.set_shader_parameter("width_pixels",.80)
	# Bake structural creases once. Thin/open roof meshes do not form a closed
	# hull, so inverted hulls would paint their whole underside black.
	var topology := ExpeditionFlatStyle.new(load("res://assets/expedition/palettes/mochi_night.tres"))
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for edge: Dictionary in topology._edges(body.mesh):
		var crease: bool = edge.normals.size()==1
		for i in edge.normals.size():
			for j in range(i+1,edge.normals.size()):
				if edge.normals[i].dot(edge.normals[j])<.94: crease = true
		if not crease: continue
		var direction: Vector3 = (edge.b-edge.a).normalized()
		for corner in [Vector2(0,-1),Vector2(1,-1),Vector2(1,1),Vector2(0,-1),Vector2(1,1),Vector2(0,1)]:
			surface.set_normal(direction); surface.set_uv(corner)
			surface.add_vertex(edge.a if corner.x==0 else edge.b)
		count += 1
	topology.dispose()
	if count==0: return
	var outline := MeshInstance3D.new(); outline.mesh = surface.commit(); outline.material_override = _outline_paint
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.set_meta("roof_occluder",roof); parent.add_child(outline)


static func _own(node: Node, root: Node) -> void:
	for child in node.get_children(): child.owner = root; _own(child,root)


static func save_cached() -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	var count := 0
	for key: String in _scenes:
		if ResourceSaver.save(_scenes[key],file_for(key),ResourceSaver.FLAG_COMPRESS)==OK: count += 1
	var paths := {}
	if FileAccess.file_exists(DIRECTORY.path_join("manifest.json")):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join("manifest.json")))
		if previous is Dictionary: paths = previous
	for key: String in _scenes: paths[key] = file_for(key).get_file()
	var manifest := FileAccess.open(DIRECTORY.path_join("manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify(paths,"  "))
	return count


static func preload_common() -> void:
	if DisplayServer.get_name()=="headless": return
	if _preloaded: return
	_preloaded = true
	var keys: Array = ["prop:red_maple","prop:crooked_pine","prop:willow","prop:bare_locust","prop:lamp","prop:type_rack","prop:writing_desk","prop:type_cabinet","prop:lotus_tub","prop:incense","prop:stone_bench"]
	for piece in [6,7,8]:
		for pattern in 3: keys.append("boundary:%d:%d" % [piece,pattern])
	for key: String in keys:
		var path := file_for(key)
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path)==OK: _requests[path] = key


static func collect_preloads() -> void:
	# Completed requests still need load_threaded_get(), even if the camera
	# never visited that asset. Consume them without blocking the render loop.
	for path: String in _requests.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status==ResourceLoader.THREAD_LOAD_LOADED:
			_scenes[_requests[path]] = ResourceLoader.load_threaded_get(path); _requests.erase(path)
		elif status in [ResourceLoader.THREAD_LOAD_FAILED,ResourceLoader.THREAD_LOAD_INVALID_RESOURCE]: _requests.erase(path)
