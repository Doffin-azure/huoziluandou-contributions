extends Node3D
## Runtime assembly of the authored room templates; no production-workbench UI dependency.
const CATALOG = preload("res://src/expedition/room_template_catalog.gd")
const ARCH = preload("res://src/map/expedition_garden_architecture.gd")
const BOUNDARY = preload("res://src/map/expedition_garden_boundary.gd")
const LOTUS = preload("res://src/map/expedition_lotus_tile.gd")
const LEAVES = preload("res://src/map/expedition_lotus_leaf_layer.gd")
const ASSET_LAYOUT = preload("res://src/expedition/garden_asset_layout.gd")
const FURNISHINGS = preload("res://src/map/garden_room_furnishings.gd")
const INTERIORS = preload("res://src/expedition/room_interior_assets.gd")
const POND_FIELD = preload("res://src/expedition/garden_pond_field.gd")
const POND_GROUND = preload("res://src/map/garden_pond_ground.gd")
var room: Dictionary
var style: ExpeditionFlatStyle
var art: ExpeditionMapArt
var factory: ExpeditionMapProps
var ground_paint: ShaderMaterial
var contents: Node3D
var assets: Array = []
var assemblies: Array = []
var trees: Array = []
var main_objects: Array = []
var occupied: Array = []
var occluders: Array = []
var _post_keys := {}
var _gate_seams: Array[Vector3] = []
var current_mode := 0
var revealed := false
var palette: ExpeditionFlatPalette


func build(data: Dictionary, painter: ExpeditionFlatStyle, camera: Camera3D, environment: Environment, ground: ShaderMaterial) -> void:
	room = data
	CATALOG.apply_enclosure(room)
	style = painter; palette = style.palette
	current_mode = absi(str(room.route_id).hash())%1000
	art = ExpeditionMapArt.new(style,camera,environment)
	ground_paint = ground.duplicate()
	var transform: Transform2D = room.get("transform",Transform2D.IDENTITY)
	ground_paint.set_shader_parameter("court_origin",transform.origin)
	ground_paint.set_shader_parameter("court_x",transform.x)
	ground_paint.set_shader_parameter("court_z",transform.y)
	ground_paint.set_shader_parameter("court_size",Vector2(room.floor_size))
	ground_paint.set_shader_parameter("court_style",3.0 if room.kind in ["elite","boss"] else 1.0)
	art.ground_material = ground_paint
	factory = ExpeditionMapProps.new(52); factory.map_art = art
	contents = Node3D.new(); add_child(contents)
	_make_ground(); _make_boundary()
	for prop in room.props: _place_prop(prop)
	art.inlay(contents,room.mark,Vector3(room.mark_at.x,0,room.mark_at.y),1.12)
	_make_water_plants()
	_cache_occluders()


func update_state(known: bool, used: bool, near: bool) -> void:
	revealed = known
	for item in occupied:
		if not str(item.label).begins_with("门"): item.root.visible = known
	for child in contents.get_children():
		if child is Node3D and str(child.name) in ["pine","ghost_fire","foe","elite","boss"]: child.visible = known
	_apply_room_state(used)
	for asset in assets:
		if asset.has_method("set_lamps_enabled"): asset.set_lamps_enabled(known and near)
		if asset.has_method("set_enabled") and asset.get_script()==ExpeditionMapArt.FIRE: asset.set_enabled(known and near and not used)
	# Preserve the complete enclosure. Occlusion depends on the actual camera,
	# never a hard-coded local south/east pair (rooms can rotate on the route).


func sync_camera(camera: Camera3D) -> void:
	for tree in trees:
		tree.sync_camera(); tree.scale = Vector3.ONE*float(tree.get_meta("preview_scale",.5))
	for item in main_objects:
		if item.state=="enemy":
			var sprite := item.node.get_child(0) as Sprite3D
			sprite.position = item.node.global_basis.inverse()*camera.global_basis.y*float(item.node.get_meta("card_height"))*.5


func _flat_floor(rect: Rect2, y := 0.0) -> void:
	if rect.get_area()<=0: return
	var shape := PlaneMesh.new()
	shape.size = rect.size
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = shape
	floor_mesh.material_override = ground_paint
	floor_mesh.position = Vector3(rect.get_center().x,y,rect.get_center().y)
	contents.add_child(floor_mesh)


func _make_ground() -> void:
	if not room.get("ponds",[]).is_empty():
		var root := POND_GROUND.build(contents,Rect2(Vector2.ZERO,Vector2(room.floor_size)),room.ponds,style,ground_paint,style.face_material("stone"))
		var width: float = room.floor_size.x; var depth: float = room.floor_size.y
		for entry in [[Vector3(width*.5,-.376,.05),Vector3(width,.74,.10)],[Vector3(width*.5,-.376,depth-.05),Vector3(width,.74,.10)],[Vector3(.05,-.376,depth*.5),Vector3(.10,.74,depth)],[Vector3(width-.05,-.376,depth*.5),Vector3(.10,.74,depth)]]:
			style.mesh(root,TypeMeshes.beveled_box(entry[1],.005),entry[0],"architecture",.6)
		occupied.append({"label":"内池地形","root":root})
		return
	_flat_floor(Rect2(Vector2.ZERO,Vector2(room.floor_size)))
	# Keep the walking plane at zero; deeper masonry reaches the lowered bridge water.
	style.mesh(contents,TypeMeshes.beveled_box(Vector3(room.floor_size.x,.74,room.floor_size.y),.008),Vector3(room.floor_size.x*.5,-.376,room.floor_size.y*.5),"architecture",.65)


func _edge_at(side: String, offset: float) -> Vector3:
	return CATALOG.port_position(room,{"side":side,"offset":offset})


func _make_boundary() -> void:
	for port in room.ports:
		_gate_seams.append(_edge_at(port.side,port.offset-port.span*.5))
		_gate_seams.append(_edge_at(port.side,port.offset+port.span*.5))
	for side: String in ["N","E","S","W"]:
		var length: float = room.floor_size.x if side in ["N","S"] else room.floor_size.y
		var ports: Array = room.ports.filter(func(p): return p.side==side)
		ports.sort_custom(func(a,b): return a.offset<b.offset)
		var start := 0.0
		for port in ports:
			_wall_span(side,start,port.offset-port.span*.5)
			start = port.offset+port.span*.5
		_wall_span(side,start,length)
	for port in room.ports: _make_gate(port)


func _wall_span(side: String, from: float, to: float) -> void:
	if to-from<.01: return
	var a := _edge_at(side,from)
	var b := _edge_at(side,to)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE*.5
	contents.add_child(holder)
	var wall: bool = room.get("enclosure","walled")!="terrace"
	var group := BOUNDARY.assemble(holder,style,[a*2,b*2],wall,false,wall)
	assemblies.append(group)
	for part in group.get_children():
		if part.piece in [BOUNDARY.Piece.WALL_POST,BOUNDARY.Piece.WALL_END,BOUNDARY.Piece.RAIL_POST,BOUNDARY.Piece.RAIL_END]:
			var point: Vector3 = contents.to_local(part.global_position)
			var key := Vector3i(roundi(point.x*1000),0,roundi(point.z*1000))
			if _post_keys.has(key) or _gate_seams.any(func(p): return p.distance_to(point)<.005):
				group.remove_child(part)
				part.queue_free()
				continue
			_post_keys[key] = true
		assets.append(part)
		if wall: occluders.append({"root":part,"roof":false})


func _make_gate(port: Dictionary) -> void:
	var root := Node3D.new()
	root.position = CATALOG.port_position(room,port)
	root.rotation.y = PI*.5 if port.side in ["E","W"] else 0.0
	contents.add_child(root)
	var gate: Node3D
	if port.frame=="open":
		# Rail platforms use paired rail ends, never isolated moon-gate wall panels.
		for x in [-port.span*.5,port.span*.5]:
			var post := BOUNDARY.new()
			post.piece = BOUNDARY.Piece.RAIL_END
			post.position.x = x
			post.scale = Vector3.ONE*.5
			root.add_child(post)
			post.setup(style)
			assets.append(post)
	elif port.frame=="beast":
		gate = art._asset(root,ExpeditionMapArt.GATE,1.0 if room.kind=="boss" else .70)
		main_objects.append({"node":gate,"state":"door"})
		var half_width := 1.16*(2.0 if room.kind=="boss" else 1.4)*.5
		var infill: float = port.span*.5-half_width
		if infill>.01:
			for sign_value in [-1.0,1.0]:
				var join := BOUNDARY.new()
				join.piece = BOUNDARY.Piece.WALL
				join.position.x = half_width if sign_value>0 else -half_width-infill
				join.scale = Vector3(infill*.5,.5,.5)
				root.add_child(join); join.setup(style)
				assets.append(join)
	else:
		gate = ARCH.new()
		gate.building = ARCH.Building.MOON_GATE
		gate.open_floor_passage = true
		gate.scale = Vector3.ONE*.5
		root.add_child(gate)
		gate.setup(style)
	if gate!=null:
		assets.append(gate)
		art._hide_asset_inlays(gate)
		occluders.append({"root":root,"roof":false})
	root.set_meta("room_port",port.id)
	occupied.append({"label":"门 "+str(port.id),"root":root})


func _place_prop(prop: Dictionary) -> void:
	var root := Node3D.new()
	root.name = str(prop.asset)
	root.position = prop.at
	if prop.asset in ["shrine","tomb"]:
		for other in room.props:
			if other.asset=="stele_plinth" and other.at.distance_to(prop.at)<.01: root.position.y += .15*other.scale
	root.rotation.y = prop.turn
	contents.add_child(root)
	var node: Node3D
	if INTERIORS.has_asset(prop.asset):
		var spec: Dictionary = INTERIORS.MODELS[prop.asset]
		if spec.has("scene"):
			var scene: PackedScene = load("res://assets/expedition/garden/%s.tscn" % spec.scene)
			node = scene.instantiate()
		elif spec.has("furnishing"):
			node = FURNISHINGS.new(); node.kind = spec.furnishing
		if node != null:
			node.scale = Vector3.ONE*float(prop.scale)
			root.add_child(node); node.setup(style)
	match prop.asset:
		"pine":
			node = art.tree(root,prop.scale)
			node.set_meta("preview_scale",prop.scale)
			trees.append(node)
		"tomb": node = art.tomb(root,prop.variant,prop.scale)
		"lamp": node = art.lamp(root,prop.scale)
		"ghost_fire": node = art.fire(root,prop.scale)
		"pavilion": node = art._asset(root,ExpeditionMapArt.REST,prop.scale)
		"stall": node = art._asset(root,ExpeditionMapArt.STALL,prop.scale)
		"beast_gate": node = art._asset(root,ExpeditionMapArt.GATE,prop.scale)
		"shrine": node = art._asset(root,ExpeditionMapArt.SHRINE,prop.scale)
		"shopkeeper":
			var shopkeeper := Sprite3D.new()
			var portrait_texture: Texture2D = load("res://assets/characters/shopkeeper/portrait.png")
			if portrait_texture == null: return
			var portrait_height := 1.45
			shopkeeper.texture = portrait_texture
			shopkeeper.pixel_size = portrait_height / maxf(1.0,float(portrait_texture.get_height()))
			shopkeeper.position.y = portrait_height * .5
			shopkeeper.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			shopkeeper.shaded = false
			shopkeeper.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			shopkeeper.alpha_scissor_threshold = .4
			shopkeeper.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
			shopkeeper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			shopkeeper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shopkeeper.modulate = Color("dce2d6")
			root.add_child(shopkeeper)
			node = shopkeeper
		"chest":
			node = art._asset(root,ExpeditionMapArt.CASKET,prop.scale)
		"screen":
			node = ARCH.new()
			node.building = ARCH.Building.SCREEN_WALL
			node.scale = Vector3.ONE*float(prop.scale)
			root.add_child(node); node.setup(style)
		"water_pavilion","rock_bed","type_cabinet","stele_plinth":
			node = FURNISHINGS.new()
			node.kind = {"water_pavilion":FURNISHINGS.Kind.WATER_PAVILION,"rock_bed":FURNISHINGS.Kind.ROCK_BED,"type_cabinet":FURNISHINGS.Kind.TYPE_CABINET,"stele_plinth":FURNISHINGS.Kind.STELE_PLINTH}[prop.asset]
			node.scale = Vector3.ONE*float(prop.scale)
			root.add_child(node); node.setup(style)
			if prop.asset=="water_pavilion":
				for label in node._labels: label.text = "藏" if room.kind=="treasure" else "息"
		"covered_walk":
			node = ARCH.new()
			node.building = ARCH.Building.COVERED_WALK
			node.scale = Vector3.ONE*ASSET_LAYOUT.WALK_SCALE
			node.position.y = ASSET_LAYOUT.WALK_FLOOR_Y
			root.add_child(node)
			node.setup(style)
			ASSET_LAYOUT.walk_fixtures(node)
			# Reuse the production approach builder in its local coordinate frame.
			var scenery: Node3D = load("res://src/map/expedition_garden_scenery.gd").new()
			scenery._art = art
			scenery._make_approaches(root,"covered_walk")
			scenery.free()
		"foe","elite","boss": node = factory.actor(root,prop.variant,prop.scale)
	if node==null: return
	art._hide_asset_inlays(node)
	if node.has_method("set_scene_lighting"): node.set_scene_lighting(true)
	if node.has_method("set_lamps_enabled"): assets.append(node)
	if not str(prop.state).is_empty(): main_objects.append({"node":node,"state":prop.state})
	if prop.asset not in ["pine","ghost_fire","foe","elite","boss"]: occupied.append({"label":prop.asset,"root":root})
	if prop.asset in ["water_pavilion","covered_walk","stall","pavilion"]:
		_register_roofs(node)
	elif prop.asset in ["square_pavilion","hex_pavilion"]:
		_register_roofs(node)
	elif INTERIORS.is_tree(prop.asset):
		var canopy_meshes: Array = []
		for leaf in node._leaf_nodes: _collect_meshes(leaf,canopy_meshes)
		if not canopy_meshes.is_empty(): occluders.append({"root":node,"roof":false,"meshes":canopy_meshes})
	elif prop.asset in ["small_loft","hollow_rockery","type_rack"]:
		occluders.append({"root":root,"roof":false})
	elif prop.asset in ["screen","shrine","type_cabinet","tomb"]:
		occluders.append({"root":root,"roof":false})


func _make_water_plants() -> void:
	for pond: Dictionary in room.get("ponds",[]):
		var center: Vector2 = pond.center
		var layer := LEAVES.new(); layer.position = Vector3(center.x,0,center.y)
		layer.half_extent = pond.radius; layer.small_leaf_count = 5; layer.large_leaf_count = 1
		layer.layout_seed = pond.seed; layer.water_height = -.45
		layer.water_test = func(point: Vector2): return POND_FIELD.sample(room.ponds,center+point)>.03
		contents.add_child(layer); layer.setup(style); occupied.append({"label":"内池荷叶","root":layer})
		var flower := LOTUS.new(); flower.plants_only = true; flower.position = Vector3(center.x,0,center.y)
		flower.scale = Vector3.ONE*.40; flower.water_height = -.45/.40
		flower.water_test = func(point: Vector2): return POND_FIELD.sample(room.ponds,center+point*.40)>.03
		contents.add_child(flower); flower.setup(style); assets.append(flower)
		occupied.append({"label":"内池荷花","root":flower})
	for side: String in room.water_sides:
		var anchor := _edge_at(side,(room.floor_size.x if side in ["N","S"] else room.floor_size.y)*.28)
		var outward := {"N":Vector3.FORWARD,"E":Vector3.RIGHT,"S":Vector3.BACK,"W":Vector3.LEFT}[side] as Vector3
		var layer := LEAVES.new()
		layer.position = anchor+outward*.78
		layer.half_extent = Vector2(.55,.55)
		layer.water_height = preload("res://src/expedition/garden_bridge_plan.gd").WATER_Y
		layer.layout_seed = 417+current_mode*13+side.unicode_at(0)
		layer.small_leaf_count = 5
		layer.large_leaf_count = 1
		contents.add_child(layer)
		layer.setup(style)
		var flower := LOTUS.new()
		flower.plants_only = true
		flower.plant = LOTUS.Plant.BLOOM
		flower.scale = Vector3.ONE*.50
		flower.water_height = preload("res://src/expedition/garden_bridge_plan.gd").WATER_Y*2
		flower.position = anchor+outward*.83+Vector3(.22,0,.18)
		contents.add_child(flower)
		flower.setup(style)
		assets.append(flower)


func _register_roofs(node: Node) -> void:
	if node is GeometryInstance3D and node.has_meta("roof_occluder"):
		occluders.append({"root":node,"roof":true})
		return
	for child in node.get_children(): _register_roofs(child)


func _cache_occluders() -> void:
	for item in occluders:
		var meshes: Array = item.get("meshes",[])
		if meshes.is_empty(): _collect_meshes(item.root,meshes)
		item["meshes"] = meshes
		var bounds := AABB()
		var first := true
		for mesh: MeshInstance3D in meshes:
			if mesh.has_meta("flat_outline_only"): continue
			var box: AABB = mesh.global_transform*mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		item["bounds"] = bounds
		item["faded"] = false


func _collect_meshes(node: Node, result: Array) -> void:
	if node is MeshInstance3D: result.append(node)
	for child in node.get_children(): _collect_meshes(child,result)


func update_occlusion(player: Vector3, camera: Camera3D, force_preview := false) -> void:
	var target := player+Vector3.UP*.45
	var origin := camera.global_position
	for item in occluders:
		var bounds: AABB = item.bounds
		var fade := false
		# A new framing angle can leave the head visible while a gate hides the
		# legs. Probe the whole figure instead of only the torso center.
		for height in [.12,.45,.78]:
			var body: Vector3 = player+Vector3.UP*height
			var hit: Variant = bounds.intersects_ray(origin,(body-origin).normalized())
			if hit is Vector3 and origin.distance_to(hit)<origin.distance_to(body) and hit.distance_to(body)<2.4:
				fade = true
				break
		fade = fade or (force_preview and (camera.unproject_position(bounds.get_center()).y>camera.unproject_position(target).y))
		if fade==item.faded: continue
		item.faded = fade
		for mesh in item.meshes: mesh.transparency = .82 if fade else 0.0


func _apply_room_state(used: bool) -> void:
	for item in main_objects:
		var node: Node3D = item.node
		match item.state:
			"enemy": node.visible = revealed and not used
			"fire": node.set_enabled(not used)
			"open": node.set_alternate_state(true)
			_:
				if node.has_method("set_alternate_state"): node.set_alternate_state(used)
				elif node.has_method("set_lamp_lit"): node.set_lamp_lit(not used)
