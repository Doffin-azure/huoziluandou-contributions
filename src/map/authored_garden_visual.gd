extends Node3D
## Continuous site assembly: shared ground/walls/architecture, separate encounters.
const PLAN = preload("res://src/expedition/authored_garden_plan.gd")
const BUILDING = preload("res://src/map/garden_passage_building.gd")
const BOUNDARY = preload("res://src/map/expedition_garden_boundary.gd")
const INTERIORS = preload("res://src/expedition/room_interior_assets.gd")
const LIBRARY = preload("res://src/map/garden_mesh_library.gd")
const FURNISHINGS = preload("res://src/map/garden_room_furnishings.gd")
var layout: RefCounted
var style: ExpeditionFlatStyle
var camera: Camera3D
var art: ExpeditionMapArt
var factory: ExpeditionMapProps
var soil: ShaderMaterial
var items: Array = []
var houses: Array = []
var encounters := {}
var reveal_all := false
var explored := {}
var scenery_batch: Node3D
var _cooperative := false
var _deadline := 0
var progress := .0
var timings := {}
var _refresh_signature := ""
var _columns := {}


func build(room_layout: RefCounted, painter: ExpeditionFlatStyle, view: Camera3D, environment: Environment, ground: Material, cooperative := false) -> void:
	_cooperative = cooperative; _deadline = Time.get_ticks_usec()+4000
	layout = room_layout; style = painter; camera = view
	art = ExpeditionMapArt.new(style,camera,environment); art.ground_material = ground
	factory = ExpeditionMapProps.new(52); factory.map_art = art
	soil = ShaderMaterial.new(); soil.shader = preload("res://src/shaders/garden_planted_ground.gdshader")
	soil.set_shader_parameter("tint",Color("29392f"))
	# fog_mask 由 _update_fog 稍后写入。先给白色兜底，避免地面在
	# 建筑已装配、探索遮罩尚未刷新的一帧里变成全黑/“空地面”。
	var white_image := Image.create(1,1,false,Image.FORMAT_RGBA8); white_image.fill(Color.WHITE)
	soil.set_shader_parameter("fog_mask",ImageTexture.create_from_image(white_image))
	soil.set_shader_parameter("vision_origin",Vector2.ZERO)
	soil.set_shader_parameter("vision_size",Vector2(4096,4096))
	soil.set_shader_parameter("clip_vision_bounds",false)
	var stage := Time.get_ticks_usec()
	await preload("res://src/map/authored_garden_ground.gd").build(self,layout,style,soil,ground,cooperative)
	timings["ground_ms"] = (Time.get_ticks_usec()-stage)/1000.0; stage = Time.get_ticks_usec()
	progress = .2
	await _build_walls()
	timings["walls_ms"] = (Time.get_ticks_usec()-stage)/1000.0; stage = Time.get_ticks_usec()
	progress = .35
	for raw: Dictionary in layout.site.buildings: _building(raw); await _slice()
	await _build_galleries()
	timings["buildings_ms"] = (Time.get_ticks_usec()-stage)/1000.0; stage = Time.get_ticks_usec()
	progress = .65
	for raw in layout.site.trees:
		var at := Vector2(float(raw[0]),float(raw[1]))
		_asset({"maple":"red_maple","pine":"crooked_pine","willow":"willow","bare":"bare_locust"}.get(raw[3],"crooked_pine"),at,float(raw[2])*.62)
		await _slice()
	for shape in layout.site.rockeries:
		var box := Rect2(PLAN.vector(shape[0]),Vector2.ZERO)
		for p in shape: box = box.expand(PLAN.vector(p))
		var rock := _asset("low_rockery",box.get_center(),minf(box.size.x/2.9,box.size.y/1.9))
		if PLAN.water_distance(box.get_center(),layout.site)>.1: rock.position.y = -.45
		await _slice()
	for raw: Dictionary in layout.site.landmarks:
		var asset := _asset(raw.asset,PLAN.vector(raw.at),float(raw.scale))
		asset.position.y = float(raw.get("offset_y",0.0)); asset.get_parent().rotation.y = -float(raw.turn)
	for prop: Dictionary in layout.site.props:
		var at := PLAN.vector(prop.at)
		if prop.asset=="tomb":
			var tomb := _asset("tomb_%d" % (int(prop.get("variant",0))%4),at,float(prop.scale)); tomb.get_parent().rotation.y = -float(prop.get("turn",0.0))
		else:
			var asset := _asset(prop.asset,at,float(prop.scale)); asset.get_parent().rotation.y = -float(prop.get("turn",0.0))
		await _slice()
	for raw: Dictionary in layout.site.screens:
		var screen := _asset("screen",PLAN.vector(raw.at),float(raw.scale)); screen.get_parent().rotation.y = -float(raw.turn)

	_bridge()
	await _plants()
	timings["scenery_ms"] = (Time.get_ticks_usec()-stage)/1000.0; stage = Time.get_ticks_usec()
	progress = .9
	for id: String in layout.rooms: _encounter(id); await _slice()
	scenery_batch = preload("res://src/map/garden_scenery_batch.gd").new(); add_child(scenery_batch)
	for item in items:
		item["lamp_controllers"] = []
		if item.node.has_method("set_lamps_enabled"): item.lamp_controllers.append(item.node)
		else:
			for child in item.node.get_children():
				if child.has_method("set_lamps_enabled"): item.lamp_controllers.append(child)
		if item.node.get_script()==preload("res://src/map/garden_baked_asset.gd") or item.node.get_child_count()>0 and item.node.get_child(0).get_script()==preload("res://src/map/garden_baked_asset.gd"):
			scenery_batch.register(item.node)
	await scenery_batch.build_walls()
	timings["batching_ms"] = (Time.get_ticks_usec()-stage)/1000.0
	progress = 1.0


func _slice() -> void:
	if _cooperative and Time.get_ticks_usec()>_deadline:
		await get_tree().process_frame; _deadline = Time.get_ticks_usec()+4000


func _holder(at: Vector2) -> Node3D:
	var root := Node3D.new(); root.position = Vector3(at.x,0,at.y); add_child(root); _track(root,at)
	return root


func _track(node: Node3D, at: Vector2) -> void:
	items.append({"node":node,"at":at})


func _asset(asset: String, at: Vector2, scale_value: float) -> Node3D:
	var descriptor: Dictionary = INTERIORS.MODELS.get(asset,{})
	var root := _holder(at)
	var node := _instance(asset)
	root.add_child(node); node.scale = Vector3.ONE*scale_value
	if node.has_method("set_lamps_enabled"): node.set_lamps_enabled(false)
	if node.has_method("set_roofs_faded"):
		var half: Vector2 = descriptor.get("crown",descriptor.get("half",Vector2.ONE))*scale_value
		houses.append({"node":node,"bounds":Rect2(at-half,half*2)})
	return node


func _instance(asset: String) -> Node3D:
	var descriptor: Dictionary = INTERIORS.MODELS.get(asset,{})
	return LIBRARY.instantiate("prop:"+asset,func():
		var original: Node3D
		if descriptor.has("scene"): original = load("res://assets/expedition/garden/%s.tscn" % descriptor.scene).instantiate()
		elif asset=="lamp": original = preload("res://src/map/expedition_bronze_lamp.gd").new()
		elif asset=="screen":
			original = preload("res://src/map/expedition_garden_architecture.gd").new(); original.building = original.Building.SCREEN_WALL
		elif asset.begins_with("tomb_"):
			original = preload("res://src/map/expedition_tombstone.gd").new(); original.variant = int(asset.trim_prefix("tomb_"))
		elif asset in ["casket","stall","shrine"]:
			original = {"casket":ExpeditionMapArt.CASKET,"stall":ExpeditionMapArt.STALL,"shrine":ExpeditionMapArt.SHRINE}[asset].new()
		else: original = FURNISHINGS.new(); original.kind = descriptor.get("furnishing",2)
		original.setup(style)
		return original,style)


func _mounted(parent: Node3D, asset: String, scale_value: float, at: Vector3) -> Node3D:
	var node := _instance(asset); parent.add_child(node); node.scale = Vector3.ONE*scale_value; node.position = at
	return node


func _building(raw: Dictionary) -> void:
	var box := PLAN.rect(raw.rect)
	var node := BUILDING.new(); node.extent = box.size; node.title = raw.name
	node.second_storey = raw.id=="library"
	node.gallery = raw.id in ["south_gallery","turn_gallery","treasure_pavilion","last_rest"]
	node.openings = PLAN.building_openings(layout.site,raw)
	var spec := {"size":box.size,"openings":node.openings,"title":node.title,"gallery":node.gallery,"upper":node.second_storey,"omit":_column_omit(box)}
	node.free()
	var built := _passage(spec)
	built.set_meta("building_name",raw.name)
	built.position = Vector3(box.get_center().x,0,box.get_center().y)
	add_child(built)
	_track(built,box.get_center()); houses.append({"node":built,"bounds":box})


func _passage(spec: Dictionary) -> Node3D:
	return LIBRARY.instantiate("house:"+var_to_str(spec),func():
		var original := BUILDING.new(); original.extent = spec.size; original.openings = spec.openings
		original.title = spec.title; original.gallery = spec.gallery; original.second_storey = spec.upper
		original.column_omit = spec.get("omit",[]); original.roof_kind = str(spec.get("roof_kind",""))
		original.setup(style)
		return original,style)


func _column_omit(box: Rect2) -> Array:
	var omitted: Array = []
	for p in [box.position,box.end,Vector2(box.end.x,box.position.y),Vector2(box.position.x,box.end.y)]:
		var key := Vector2(p).snapped(Vector2.ONE*.01)
		if _columns.has(key): omitted.append(Vector2(p)-box.get_center())
		_columns[key] = true
	return omitted


func _boundary(piece: int, pattern := 0) -> Node3D:
	return LIBRARY.instantiate("boundary:%d:%d" % [piece,pattern],func():
		var original := BOUNDARY.new(); original.piece = piece; original.window_pattern = pattern; original.setup(style)
		return original,style)


func _build_walls() -> void:
	var posts := {}
	var edges := preload("res://src/map/garden_wall_graph.gd").segments(layout.site.walls)
	set_meta("wall_edge_count",edges.size())
	for edge: Array in edges:
		var a: Vector2 = edge[0]; var b: Vector2 = edge[1]
		var length := a.distance_to(b); var direction := (b-a).normalized()
		var cursor := 0.0; var index := 0
		while cursor<length-.01:
			var size := minf(1.3,length-cursor)
			var start := a+direction*cursor; var finish := start+direction*size
			var piece := BOUNDARY.Piece.WINDOW_WALL if index%3==1 and size>1.29 else BOUNDARY.Piece.WALL
			var part := _boundary(piece,index%3)
			part.position = Vector3(start.x,0,start.y); part.rotation.y = -atan2(direction.y,direction.x)
			part.scale = Vector3(size*.5,.65,.65)
			add_child(part); _track(part,(start+finish)*.5)
			for p in [start,finish]: posts[str(Vector2i((p*100).round()))] = p
			cursor += size; index += 1
			await _slice()
	for p: Vector2 in posts.values():
		var post := _boundary(BOUNDARY.Piece.WALL_POST); post.scale = Vector3.ONE*.65
		post.position = Vector3(p.x,0,p.y); add_child(post); _track(post,p)
		await _slice()
	set_meta("wall_post_count",posts.size())


func _build_galleries() -> void:
	var segments := preload("res://src/map/garden_wall_graph.gd").segments(layout.site.galleries)
	var junctions := {}
	for edge: Array in segments:
		for i in 2:
			var at: Vector2 = edge[i]
			if not junctions.has(at): junctions[at] = []
			junctions[at].append((Vector2(edge[1-i])-at).normalized())
	var corners := {}
	for at: Vector2 in junctions:
		var directions: Array = junctions[at]
		if directions.size()<2: continue
		if directions.size()==2 and directions[0].dot(directions[1])<-.9: continue
		if layout.site.buildings.any(func(raw):return PLAN.rect(raw.rect).grow(-.15).has_point(at)): continue
		corners[at] = true
	for edge: Array in segments:
		var a: Vector2 = edge[0]; var b: Vector2 = edge[1]
		var direction := (b-a).normalized()
		var start := a+direction*(.62 if corners.has(a) else 0.0)
		var finish := b-direction*(.62 if corners.has(b) else 0.0)
		if (finish-start).dot(direction)<.12: continue
		var box := Rect2(start,Vector2.ZERO).expand(finish)
		if absf(direction.x)>.5: box.position.y -= .62; box.size.y = 1.24
		else: box.position.x -= .62; box.size.x = 1.24
		await _gallery(box,"")
	for at: Vector2 in corners: await _gallery(Rect2(at-Vector2.ONE*.62,Vector2.ONE*1.24),"hip")
	set_meta("gallery_joint_count",corners.size())


func _gallery(box: Rect2, roof_kind: String) -> void:
	var middle := box.get_center()
	if layout.site.buildings.any(func(raw): return PLAN.rect(raw.rect).grow(-.15).has_point(middle)): return
	var node := _passage({"size":box.size,"openings":{"N":[],"E":[],"S":[],"W":[]},"title":"","gallery":true,"upper":false,"omit":_column_omit(box),"roof_kind":roof_kind})
	node.position = Vector3(middle.x,0,middle.y); add_child(node)
	_track(node,middle); houses.append({"node":node,"bounds":box})
	await _slice()


func _bridge() -> void:
	for raw: Array in layout.site.bridges:
		var box := PLAN.rect(raw)
		var root := _holder(box.get_center())
		# The continuous paving owns the deck at y=0. Masonry stays below it.
		style.mesh(root,TypeMeshes.beveled_box(Vector3(box.size.x,.19,box.size.y),.008),Vector3(0,-.105,0),"stone",.5)
	for raw: Dictionary in layout.site.bridge_spans:
		var at := PLAN.vector(raw.at)
		var span := LIBRARY.instantiate("bridge:"+str(raw.length),func():
			var original := preload("res://src/map/garden_bridge_kit.gd").new()
			original.kind = "pier"; original.span_length = float(raw.length); original.with_deck = false; original.setup(style)
			return original,style)
		span.position = Vector3(at.x,0,at.y); span.rotation.y = -float(raw.turn)
		add_child(span); _track(span,at)



func _plants() -> void:
	for index in layout.site.lotus_centers.size():
		var at := PLAN.vector(layout.site.lotus_centers[index])
		var key := str(hash(var_to_str(layout.site.pond_polygon)))+":"+str(index)
		var layer := LIBRARY.instantiate("leaves:"+key,func():
			var original := preload("res://src/map/expedition_lotus_leaf_layer.gd").new()
			original.half_extent = Vector2(1.6,1.2); original.layout_seed = 1729+index*137
			original.small_leaf_count = 12; original.large_leaf_count = 2; original.water_height = -.45
			original.water_test = func(local: Vector2): return PLAN.water_distance(at+local,layout.site)>.15
			original.setup(style)
			return original,style)
		layer.position = Vector3(at.x,0,at.y); add_child(layer); _track(layer,at)
		var flower := LIBRARY.instantiate("flowers:"+key,func():
			var original := preload("res://src/map/expedition_lotus_tile.gd").new()
			original.plants_only = true; original.water_height = -1.0
			original.water_test = func(local: Vector2): return PLAN.water_distance(at+local*.45,layout.site)>.1
			original.setup(style)
			return original,style)
		flower.scale = Vector3.ONE*.45; flower.position = Vector3(at.x,0,at.y); add_child(flower); _track(flower,at)
		await _slice()


func _encounter(id: String) -> void:
	var room: Dictionary = layout.rooms[id]
	var root := Node3D.new(); root.position = Vector3(room.stand.x,0,room.stand.y); add_child(root)
	var content := Node3D.new(); root.add_child(content)
	match room.kind:
		"battle","elite","boss":
			var actor := factory.actor(content,3 if room.kind=="boss" else (2 if room.kind=="elite" else 1),1.4 if room.kind=="boss" else 1.05)
			actor.position.z = -.7
		"rest": art.fire(content,.6)
		"treasure":
			_mounted(content,"casket",.7,Vector3(-.7,0,-.45))
		"shop": _mounted(content,"stall",.65,Vector3(0,0,-.5))
		"event": _mounted(content,"shrine",.38,Vector3(-.85,0,-.6))
	var mark := art.inlay(root,{"start":"始","battle":"战","elite":"镇","boss":"渊","rest":"息","treasure":"藏","shop":"市","event":"问"}[room.kind],Vector3(0,.01,.25),.78)
	encounters[id] = {"root":root,"content":content,"mark":mark}


func update_fog(mask: Texture2D, bounds: Rect2) -> void:
	soil.set_shader_parameter("fog_mask",mask); soil.set_shader_parameter("vision_origin",bounds.position); soil.set_shader_parameter("vision_size",bounds.size)
	soil.set_shader_parameter("clip_vision_bounds",true)
	for item in encounters.values():
		if item.mark.floor_paint==null: continue
		item.mark.floor_paint.set_shader_parameter("fog_mask",mask)
		item.mark.floor_paint.set_shader_parameter("vision_origin",bounds.position)
		item.mark.floor_paint.set_shader_parameter("vision_size",bounds.size)
		item.mark.floor_paint.set_shader_parameter("clip_vision_bounds",true)


func refresh(run: RefCounted, player: Vector2) -> void:
	var signature := str([player,run.current_room,run.visited_rooms,run.resolved,reveal_all])
	if signature==_refresh_signature: return
	_refresh_signature = signature
	var scenery_changed := false
	for item in items:
		var known: bool = reveal_all or explored.has(item.node.get_instance_id())
		if not known:
			for id: String in run.visited_rooms:
				if layout.rooms[id].bounds.grow(4).has_point(item.at): known = true; break
		if known: explored[item.node.get_instance_id()] = true
		if item.node.visible!=known: scenery_changed = true
		item.node.visible = known
		var dim: bool = known and item.at.distance_to(player)>9 and not reveal_all
		if item.get("dim",false)!=dim:
			scenery_changed = true
			item.node.set_meta("garden_dim",.48 if dim else 1.0)
			art.shade(item.node,.48 if dim else 1.0); item["dim"] = dim
		for controller in item.lamp_controllers: controller.set_lamps_enabled(known and item.at.distance_to(player)<7)
	for id: String in encounters:
		var item: Dictionary = encounters[id]; var known: bool = reveal_all or run.visited_rooms.has(id)
		item.root.visible = known
		var used: bool = run.resolved.has(id)
		item.content.visible = not used
		item.mark.set_spent(used)
		for child in item.content.get_children():
			if child.has_method("set_enabled"): child.set_enabled(known and not used)
	if scenery_batch!=null and (scenery_changed or scenery_batch.groups.is_empty()): scenery_batch.refresh()
	update_occlusion(Vector3(player.x,0,player.y))


func update_occlusion(walker: Vector3) -> void:
	for house in houses:
		var box: Rect2 = house.bounds
		var inside := box.grow(.35).has_point(Vector2(walker.x,walker.z))
		var bounds := AABB(Vector3(box.position.x,1.75,box.position.y),Vector3(box.size.x,2,box.size.y))
		var occludes: bool = bounds.intersects_segment(camera.global_position,walker+Vector3.UP*.5)!=null
		house.node.set_roofs_faded(not reveal_all and (inside or occludes))
