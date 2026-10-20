extends "res://src/map/authored_garden_visual.gd"
## Regional assembly of the approved compounds; encounters use production art.
const BOX = preload("res://src/map/garden_blockout_visual.gd")
const GRID = preload("res://src/expedition/garden_blockout_plan.gd")
const PASSAGES = preload("res://src/map/garden_compact_passages.gd")
const CACHE_LIMIT := 49
var plan: RefCounted
var chunks := {}
var wanted := {}
var pending: Array[Vector2i] = []
var _used := {}
var _tick := 0
var _center := Vector2i(-9999,-9999)
var _node_roots := {}
var _mask: Texture2D
var _vision := Rect2()
var _doors: Node3D
var _door_signature := ""
var _door_painter: RefCounted
var _run: RefCounted
var _floor_box: BoxMesh
var _plot_box: BoxMesh
var _pending_rooms: Array[String] = []
var _view_focus := Vector2.ZERO
var _manual_view := false
var terrain_root: Node3D
var _exterior_used: Array[Rect2] = []
var _exterior_layouts := {}
var _detail_counts := {"grass":0,"moss":0,"corner_stones":0}
var _haunted_used := {}
var _haunted_counts := {"tombstone":0,"ghost_fire":0}
var _assembling := false
var _instancing := false
var _occlusion_signature := ""
var _wall_clip := Vector4.ZERO
var _wall_plane := Vector4.ZERO
var _loading := true
var passage_features: Array[Dictionary] = []
var _bridge_cells := {}
var _balustrades := {}


func build(room_layout: RefCounted, painter: ExpeditionFlatStyle, view: Camera3D, settings: Environment, ground: Material, cooperative := false) -> void:
	set_process(false)
	_loading = true
	layout = room_layout; plan = layout.compact; style = painter; camera = view
	_cooperative = cooperative; _deadline = Time.get_ticks_usec()+4000
	art = ExpeditionMapArt.new(style,camera,settings); art.ground_material = ground
	factory = ExpeditionMapProps.new(52); factory.map_art = art
	_floor_box = BoxMesh.new(); _floor_box.size = Vector3(1,.36,1)
	_plot_box = BoxMesh.new(); _plot_box.size = Vector3(1,.48,1)
	soil = ShaderMaterial.new(); soil.shader = preload("res://src/shaders/garden_planted_ground.gdshader"); soil.set_shader_parameter("tint",style.palette.garden_soil); soil.set_shader_parameter("grass_dark",style.palette.garden_grass_dark); soil.set_shader_parameter("grass_moss",style.palette.garden_moss)
	var white := Image.create(1,1,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE)
	update_fog(ImageTexture.create_from_image(white),layout.bounds)
	_door_painter = BOX.new()
	passage_features = PASSAGES.generate(layout)
	var passage_shapes := {}
	for feature: Dictionary in passage_features:
		for cell: Vector2i in feature.cells: _bridge_cells[cell] = true
		var key := "%s:%d" % [feature.kind,feature.length]
		if not passage_shapes.has(key):
			passage_shapes[key] = true
			var prototype := PASSAGES.instance(feature.kind,feature.length,style); prototype.free()
			await _slice()
	for kind: String in ["rail","post"]:
		var prototype := PASSAGES.instance(kind,1,style); prototype.free()
		await _slice()
	set_meta("passage_features",passage_features.size())
	_balustrades = PASSAGES.balustrades(plan,_bridge_cells)
	# Warm the few shared roof shapes during entry, rather than baking a new
	# house on the first frame back from a reward. Names live in the 2D labels.
	var shapes := {}
	for room: Dictionary in layout.rooms.values():
		if not _covered(room): continue
		var spec := _house_spec(room)
		var key := var_to_str(spec)
		if shapes.has(key): continue
		shapes[key] = true
		var prototype := _passage(spec); prototype.free()
		await _slice()
	# Bake/cache shared approved props during the loading screen. A new room
	# should instantiate meshes, not build a desk, tree or tomb on a walking frame.
	for asset: String in ["writing_desk","type_cabinet","type_rack","stone_bench","stone_table","incense","lotus_tub","lamp","tomb_0","tomb_1","tomb_2","tomb_3","red_maple","crooked_pine","low_rockery","small_loft","hex_pavilion"]:
		var prototype := _instance(asset); prototype.free()
		await _slice()
	await _lotus()
	# Continuous ground is inexpensive and always present. Only architectural
	# detail streams in/out, so a load boundary can never cut away a stone path.
	terrain_root = Node3D.new(); terrain_root.name = "ContinuousTerrain"; add_child(terrain_root)
	_detail_counts = {"grass":0,"moss":0,"corner_stones":0}
	_haunted_used.clear(); _haunted_counts = {"tombstone":0,"ghost_fire":0}; set_meta("haunted_props",0)
	for key: Vector2i in plan.chunks:
		_build_terrain(key); await _slice()
	set_meta("ground_detail_counts",_detail_counts.duplicate(true))
	_stream(Vector2(plan.nodes.start.at))
	var initial := pending.size()
	while not pending.is_empty():
		await _assemble_one(); progress = 1-float(pending.size())/maxi(1,initial)
		await _slice()
	for id: String in layout.rooms:
		if layout.rooms[id].stand.distance_to(Vector2(plan.nodes.start.at))>14: continue
		await _room(id); await _slice()
	progress = 1
	_loading = false
	set_process(true)


func _slice() -> void:
	if _cooperative and Time.get_ticks_usec()>_deadline:
		await get_tree().process_frame
		# Entry has a loading screen and no moving world. Use more of that frame
		# rather than spending many 16ms waits on tiny construction batches.
		_deadline = Time.get_ticks_usec()+(12000 if _loading else 3000)


func _stream(player: Vector2) -> void:
	var center: Vector2i = GRID.chunk_at(player)
	if center==_center: return
	_center = center; _tick += 1; wanted.clear(); pending.clear()
	for x in range(center.x-2,center.x+3):
		for y in range(center.y-2,center.y+3):
			var key := Vector2i(x,y)
			if plan.chunks.has(key):
				wanted[key] = true; _used[key] = _tick
				if not chunks.has(key): pending.append(key)
	pending.sort_custom(func(a,b):return a.distance_squared_to(center)<b.distance_squared_to(center))
	for key: Vector2i in chunks: chunks[key].visible = wanted.has(key)
	_evict()
	_door_signature = ""


func _assemble_one() -> void:
	if pending.is_empty() or _assembling: return
	_assembling = true
	var key: Vector2i = pending.pop_front()
	if chunks.has(key) or not wanted.has(key): _assembling = false; return
	var root := Node3D.new(); root.name = "GardenRegion_%d_%d" % [key.x,key.y]; add_child(root)
	var data: Dictionary = plan.chunks[key]
	await _build_region_walls(root,key,data)
	await _build_region_passages(root,key)
	chunks[key] = root
	_evict()
	timings["regional_builds"] = int(timings.get("regional_builds",0))+1
	_assembling = false; _occlusion_signature = ""


func _build_terrain(key: Vector2i) -> void:
	var root := Node3D.new(); root.name = "Ground_%d_%d" % [key.x,key.y]; terrain_root.add_child(root)
	var data: Dictionary = plan.chunks[key]
	var paving: Dictionary = preload("res://src/map/garden_compact_paving.gd").build(plan,data.floor,_bridge_cells)
	if paving.top!=null: _mesh(root,paving.top,art.ground_material)
	if paving.sides!=null: _mesh(root,paving.sides,style.face_material("stone"))
	if paving.rim!=null: _mesh(root,paving.rim,style.face_material("garden_stone"))
	var plots_surface := SurfaceTool.new(); plots_surface.begin(Mesh.PRIMITIVE_TRIANGLES); var plot_count := 0
	for c: Vector2i in data.plots:
		if plan.plots[c]=="water": continue
		plots_surface.append_from(_plot_box,0,Transform3D(Basis.IDENTITY,Vector3(c.x,-.02,c.y))); plot_count += 1
	if plot_count>0: _mesh(root,plots_surface.commit(),soil)
	_build_ground_details(root,key,data)


func _build_ground_details(root: Node3D, chunk_key: Vector2i, data: Dictionary) -> void:
	var grass := SurfaceTool.new(); grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var moss := SurfaceTool.new(); moss.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stones := SurfaceTool.new(); stones.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_grass := false; var has_moss := false; var has_stones := false
	for c: Vector2i in data.plots:
		var kind: String = str(plan.plots.get(c,""))
		if kind=="plants":
			var seed_value := absi(hash("grass:%d:%d:%d" % [plan.seed_value,c.x,c.y]))
			if seed_value%3!=0:
				_append_grass_tuft(grass,Vector3(c.x-.22+float(seed_value%37)/100.0,.045,c.y-.18+float(seed_value%29)/100.0),seed_value,.27+float(seed_value%5)*.024)
				has_grass = true; _detail_counts.grass += 1
			if seed_value%5==0:
				_append_grass_tuft(moss,Vector3(c.x+.18,.042,c.y+.16),seed_value+17,.08)
				has_moss = true; _detail_counts.moss += 1
		elif kind=="rocks" and absi(hash("stone:%d:%d:%d" % [plan.seed_value,c.x,c.y]))%3==0:
			_append_detail_box(stones,Vector3(c.x+.17,.055,c.y-.12),Vector3(.30,.11,.20))
			has_stones = true; _detail_counts.corner_stones += 1
	for c: Vector2i in data.floor:
		if not str(plan.cells.get(c,"" )).is_empty(): continue
		var neighbours: Array = plan.links.get(c,[])
		var has_horizontal := neighbours.has(c+Vector2i.LEFT) or neighbours.has(c+Vector2i.RIGHT)
		var has_vertical := neighbours.has(c+Vector2i.UP) or neighbours.has(c+Vector2i.DOWN)
		if not has_horizontal or not has_vertical: continue
	# Mark actual direction changes in corridor centerlines. The old junction
	# heuristic decorated nearly every connected tile, so these are placed only
	# on true L turns and remain outside the movement center.
	var turn_cells := {}
	for corridor: Dictionary in plan.corridors:
		var route: Array = corridor.get("floor",[])
		for i in range(1,route.size()-1):
			var previous: Vector2i = route[i-1]; var corner: Vector2i = route[i]; var following: Vector2i = route[i+1]
			var incoming := corner-previous; var outgoing := following-corner
			if incoming==outgoing or incoming==-outgoing: continue
			if GRID.chunk_at(Vector2(corner))!=chunk_key: continue
			var turn_key := str(corner)
			if turn_cells.has(turn_key): continue
			turn_cells[turn_key] = true
			var outer := Vector2(-incoming+outgoing).normalized()
			var center := Vector3(corner.x,0.035,corner.y)+Vector3(outer.x,0,outer.y)*.78
			var outer_cell := Vector2i(Vector2(center.x,center.z).round())
			if plan.cells.has(outer_cell): continue
			_append_detail_box(stones,center,Vector3(.30,.09,.22))
			has_stones = true; _detail_counts.corner_stones += 1
	if has_grass:
		_mesh(root,grass.commit(),style.face_material("garden_grass"))
	if has_moss:
		_mesh(root,moss.commit(),style.face_material("garden_moss"))
	if has_stones:
		_mesh(root,stones.commit(),style.face_material("garden_stone"))


func _append_grass_tuft(surface: SurfaceTool, at: Vector3, seed_value: int, height: float) -> void:
	for i in 3:
		var angle := TAU*float(posmod(seed_value+i*41,100))/100.0
		var direction := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-direction.z,0,direction.x)*.025
		var base := at+direction*.018*i
		var tip := base+direction*.045+Vector3(0,height*(.84+float(i)*.06),0)
		for point in [base-side,base+side,tip]: surface.set_normal(Vector3.UP); surface.add_vertex(point)
		for point in [base-side,tip,base+side]: surface.set_normal(Vector3.UP); surface.add_vertex(point)


func _append_detail_box(surface: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var half := size*.5
	for axis in 3:
		for sign_value in [-1.0,1.0]:
			var normal := Vector3.ZERO; normal[axis] = sign_value
			var u := (axis+1)%3; var v := (axis+2)%3
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point := center; point[axis] += half[axis]*sign_value; point[u] += corner.x*half[u]; point[v] += corner.y*half[v]
				surface.set_normal(normal); surface.add_vertex(point)


func _build_region_walls(root: Node3D, key: Vector2i, data: Dictionary) -> void:
	var merged := {}; var posts := {}
	for wall: Dictionary in data.walls:
		var direction: Vector2 = wall.b-wall.a
		var pattern: int = absi(hash(str(wall.a)))%3
		var part := _boundary(BOUNDARY.Piece.WINDOW_WALL if pattern==1 else BOUNDARY.Piece.WALL,pattern)
		part.position = Vector3(wall.a.x,0,wall.a.y); part.rotation.y = -atan2(direction.y,direction.x); part.scale = Vector3(.5,.65,.65)
		_collect(part,Transform3D.IDENTITY,merged); part.free()
		await _slice()
		for at: Vector2 in [wall.a,wall.b]:
			# A shared pillar is emitted only by the region owning its position.
			if GRID.chunk_at(at)==key: posts[at] = true
	# Include endpoints owned by this region even when its wall lies next door.
	for wall: Dictionary in plan.walls:
		for at: Vector2 in [wall.a,wall.b]:
			if GRID.chunk_at(at)==key: posts[at] = true
	for at: Vector2 in posts:
		var post := _boundary(BOUNDARY.Piece.WALL_POST); post.position = Vector3(at.x,0,at.y); post.scale = Vector3.ONE*.65
		_collect(post,Transform3D.IDENTITY,merged); post.free()
		await _slice()
	var facade_meshes: Array[MeshInstance3D] = []
	for group: Dictionary in merged.values():
		var paint: Material = group.paint
		if paint is ShaderMaterial: paint = preload("res://src/map/garden_roof_aperture.gd").wall_material(paint)
		var mesh := _mesh(root,group.surface.commit(),paint)
		mesh.set_instance_shader_parameter("garden_wall_clip",_wall_clip); mesh.set_instance_shader_parameter("garden_wall_plane",_wall_plane)
		facade_meshes.append(mesh)
		await _slice()
	root.set_meta("facades",facade_meshes)


func _collect(node: Node, parent_transform: Transform3D, merged: Dictionary) -> void:
	var transform := parent_transform
	if node is Node3D: transform *= node.transform
	if node is MeshInstance3D and node.mesh!=null:
		var paint: Material = node.material_override
		var key := paint.get_instance_id() if paint!=null else 0
		if not merged.has(key):
			var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			merged[key] = {"surface":surface,"paint":paint}
		for index in node.mesh.get_surface_count(): merged[key].surface.append_from(node.mesh,index,transform)
	for child in node.get_children(): _collect(child,transform,merged)


func _build_region_passages(root: Node3D, key: Vector2i) -> void:
	for feature: Dictionary in passage_features:
		var middle: Vector2 = feature.start+feature.direction*float(feature.length)*.5
		if GRID.chunk_at(middle)!=key: continue
		var span := PASSAGES.instance(feature.kind,feature.length,style)
		span.name = "Passage_"+feature.id; root.add_child(span)
		span.position = Vector3(feature.start.x,0,feature.start.y)
		span.rotation.y = atan2(-feature.direction.y,feature.direction.x)
		span.set_meta("passage_kind",feature.kind)
		for mesh: MeshInstance3D in span.find_children("*","MeshInstance3D",true,false): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if feature.kind in ["gallery","covered"]:
			houses.append({"node":span,"bounds":feature.bounds,"room_id":""})
		_track(span,middle)
		await _slice()
	# Bare water-side paths receive a connected stone balustrade, including
	# their bends. Shared endpoints get one post, not two overlapping posts.
	var merged := {}
	var pieces: Dictionary = _balustrades.get(key,{"edges":[],"posts":[]})
	for edge: Dictionary in pieces.edges:
		var part := PASSAGES.instance("rail",1,style)
		part.position = Vector3(edge.start.x,0,edge.start.y); part.rotation.y = atan2(-edge.direction.y,edge.direction.x)
		_collect(part,Transform3D.IDENTITY,merged); part.free(); await _slice()
	for at: Vector2 in pieces.posts:
		var part := PASSAGES.instance("post",1,style); part.position = Vector3(at.x,0,at.y)
		_collect(part,Transform3D.IDENTITY,merged); part.free(); await _slice()
	for group: Dictionary in merged.values():
		_mesh(root,group.surface.commit(),group.paint); await _slice()


func _mesh(parent: Node3D, mesh: Mesh, paint: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.mesh = mesh; node.material_override = paint; parent.add_child(node)
	# The merged wall geometry uses painted shading; only individual facilities
	# and actors participate in the limited real-time shadow budget.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func update_fog(mask: Texture2D, bounds: Rect2) -> void:
	_mask = mask; _vision = bounds
	super.update_fog(mask,bounds)


func _evict() -> void:
	while chunks.size()>CACHE_LIMIT:
		var oldest := Vector2i(-9999,-9999); var stamp := 2147483647
		for key: Vector2i in chunks:
			if not wanted.has(key) and int(_used[key])<stamp: oldest = key; stamp = int(_used[key])
		if oldest.x==-9999: break
		chunks[oldest].free(); chunks.erase(oldest); _used.erase(oldest)


func _process(_delta: float) -> void:
	if _assembling or _instancing: return
	if not pending.is_empty(): _assemble_one()
	elif not _pending_rooms.is_empty():
		var id: String = _pending_rooms.pop_front()
		if not _node_roots.has(id): await _room(id)
		if _run!=null: refresh(_run,layout.point(_run.position))


func refresh(run: RefCounted, player: Vector2) -> void:
	_run = run
	var focus := _view_focus if _manual_view else player
	_stream(focus)
	var visible_nodes: Array = layout.rooms.keys()
	_pending_rooms.assign(_pending_rooms.filter(func(id):return visible_nodes.has(id)))
	for id: String in _node_roots.keys():
		if layout.rooms[id].stand.distance_to(focus)>26 and not reveal_all:
			_node_roots[id].free(); _node_roots.erase(id); encounters.erase(id)
	items = items.filter(func(item):return is_instance_valid(item.node))
	houses = houses.filter(func(item):return is_instance_valid(item.node))
	for id: String in visible_nodes:
		if not reveal_all and layout.rooms[id].stand.distance_to(focus)>23: continue
		if not _node_roots.has(id):
			if not _pending_rooms.has(id): _pending_rooms.append(id)
			continue
		var encounter: Dictionary = encounters[id]
		encounter.root.visible = true
		encounter.content.visible = not run.resolved.has(id) and not run.sealed.has(id)
		encounter.mark.set_spent(run.resolved.has(id))
		for child in encounter.content.get_children():
			if child.has_method("set_enabled"): child.set_enabled(not run.resolved.has(id) and id==run.current_room)
	for id: String in _node_roots: _node_roots[id].visible = visible_nodes.has(id)
	for item in items:
		item.node.visible = true
		if item.node.has_method("set_lamps_enabled"): item.node.set_lamps_enabled(item.at.distance_to(player)<7)
		else:
			for child in item.node.get_children():
				if child.has_method("set_lamps_enabled"): child.set_lamps_enabled(item.at.distance_to(player)<7)
	var signature := str([run.current_room,run.phase,run.travel.departed,_center])
	if signature!=_door_signature:
		_door_signature = signature
		if _doors!=null: _doors.free()
		_doors = _door_painter.gates(run.travel,wanted); add_child(_doors)
		for mesh: MeshInstance3D in _doors.find_children("*","MeshInstance3D",true,false):
			mesh.material_override = _door_painter.material; mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	update_occlusion(Vector3(player.x,0,player.y))


func update_view(at: Vector2, following: bool) -> void:
	_manual_view = not following; _view_focus = at
	if _run==null: return
	var focus: Vector2 = layout.point(_run.position) if following else at
	if GRID.chunk_at(focus)!=_center: refresh(_run,layout.point(_run.position))


func _room(id: String) -> void:
	_instancing = true
	var container := Node3D.new(); container.name = "Stop_"+id; add_child(container); _node_roots[id] = container
	_encounter(id); encounters[id].root.reparent(container)
	var room: Dictionary = layout.rooms[id]; var at: Vector2 = room.stand
	if _covered(room):
		var house := _passage(_house_spec(room)); house.position = Vector3(at.x,0,at.y); container.add_child(house)
		house.set_meta("building_name",room.name)
		house.set_meta("room_id",id)
		# The hall shell frames the room but must not cast broad roof and wall
		# shadows over the traveler or the small approved furniture models.
		for mesh: MeshInstance3D in house.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if room.kind=="start":
			var gate := preload("res://src/map/expedition_garden_architecture.gd").new()
			gate.building = gate.Building.MOON_GATE; gate.open_floor_passage = true
			gate.scale = Vector3.ONE*.5; gate.position = Vector3(0,0,-room.bounds.size.y*.5-.02)
			house.add_child(gate); gate.setup(style)
		houses.append({"node":house,"bounds":room.bounds,"room_id":id}); _track(house,at)
	if room.kind=="start": _add_entry_haunt(room,container)
	for prop: Dictionary in room.props:
		var point: Vector2 = room.transform*Vector2(prop.at.x,prop.at.z)
		var asset := _asset(prop.asset,point,float(prop.scale))
		asset.get_parent().rotation.y = float(prop.turn); asset.get_parent().reparent(container)
		asset.set_meta("interior_prop",prop.asset)
		for mesh: MeshInstance3D in asset.find_children("*","MeshInstance3D",true,false): mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		await _slice()
		if not is_instance_valid(container): _instancing = false; return
	_haunted_details(room,container)
	_exterior(room,container)
	update_fog(_mask,_vision)
	set_meta("lights_dirty",true)
	_instancing = false; _occlusion_signature = ""


func _house_spec(room: Dictionary) -> Dictionary:
	var openings := {"N":[],"E":[],"S":[],"W":[]}
	# Compact rooms are open halls. Mirror the actual generated door cells in
	# the shell so the entrance is visibly connected to its three approaches.
	if room.kind=="start" and plan!=null and plan.nodes.has(room.route_id):
		var node: Dictionary = plan.nodes[room.route_id]
		var half := Vector2(node.extent)*.5
		for door: Dictionary in node.get("doors",[]):
			var local := Vector2(door.cell)-Vector2(node.at)
			var side := "N" if door.normal==Vector2i.UP else ("S" if door.normal==Vector2i.DOWN else ("E" if door.normal==Vector2i.RIGHT else "W"))
			var length: float = room.bounds.size.x if side in ["N","S"] else room.bounds.size.y
			var offset := local.x if side in ["N","S"] else local.y
			openings[side].append(clampf(offset,-length*.5+.6,length*.5-.6))
	return {"size":room.bounds.size-Vector2.ONE*.35,"openings":openings,"title":"","gallery":room.kind!="start","upper":room.kind=="shop","omit":[],"roof_kind":"hip" if room.kind in ["start","shop","treasure","boss"] else ""}


func _covered(room: Dictionary) -> bool:
	return room.kind in ["start","rest","shop","treasure","boss","event"] or room.role in ["正厅","后厅"]


func _add_entry_haunt(room: Dictionary, container: Node3D) -> void:
	# Put the signature cemetery pair inside the opening court, where the player
	# sees it immediately instead of relying on a distant random planting plot.
	var tomb_point: Vector2 = room.transform*Vector2(2.0,3.75)
	var memorial := _holder(tomb_point); memorial.reparent(container)
	var tomb := _instance("tomb_0"); tomb.scale = Vector3.ONE*.32; memorial.add_child(tomb); tomb.set_meta("garden_tombstone",true)
	var fire_point: Vector2 = room.transform*Vector2(1.15,3.55)
	var shrine := _holder(fire_point); shrine.reparent(container)
	var ghost := preload("res://src/map/expedition_stylized_fire.gd").new()
	ghost.set_ghost_fire(true); ghost.scale = Vector3.ONE*.42; shrine.add_child(ghost)
	ghost.setup(style,camera,art.environment,false)
	_haunted_counts.tombstone += 1; _haunted_counts.ghost_fire += 1
	set_meta("haunted_props",int(get_meta("haunted_props",0))+2)


func _haunted_details(room: Dictionary, container: Node3D) -> void:
	# Place tombs and ghost flames on actual planted/rock plots, never on a
	# navigable cell or in water. Deterministic selection keeps every seed stable.
	var seed_value := absi(hash("haunt:%d:%s" % [plan.seed_value,room.route_id]))
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in plan.plots:
		var kind: String = str(plan.plots[cell])
		if kind not in ["plants","rocks"] or plan.cells.has(cell) or (_haunted_used.has(cell) and _haunted_used[cell]!=room.route_id): continue
		var at := Vector2(cell)+Vector2.ONE*.5
		if room.bounds.grow(.75).has_point(at) or at.distance_to(room.stand)>7.0: continue
		candidates.append(cell)
	candidates.sort_custom(func(a,b):
		var da := (Vector2(a)+Vector2.ONE*.5).distance_squared_to(room.stand)
		var db := (Vector2(b)+Vector2.ONE*.5).distance_squared_to(room.stand)
		if not is_equal_approx(da,db): return da<db
		var ha := absi(hash("%d:%s" % [seed_value,a]))
		var hb := absi(hash("%d:%s" % [seed_value,b]))
		if ha!=hb: return ha<hb
		return a.x<b.x or a.x==b.x and a.y<b.y)
	var placed := 0
	for cell: Vector2i in candidates:
		var at := Vector2(cell)+Vector2.ONE*.5
		_haunted_used[cell] = room.route_id
		if placed%2==0:
			var tomb := _instance("tomb_%d" % ((seed_value+placed)%4)); tomb.scale = Vector3.ONE*.36; tomb.set_meta("garden_tombstone",true)
			var holder := _holder(at); holder.reparent(container); holder.add_child(tomb)
			_haunted_counts.tombstone += 1
		else:
			var ghost := preload("res://src/map/expedition_stylized_fire.gd").new(); ghost.set_ghost_fire(true); ghost.scale = Vector3.ONE*.42
			var holder := _holder(at); holder.reparent(container); holder.add_child(ghost); ghost.setup(style,camera,art.environment,false)
			_haunted_counts.ghost_fire += 1
		placed += 1
		if placed>=(2 if room.kind in ["event","boss"] else 1): break
	set_meta("haunted_props",int(get_meta("haunted_props",0))+placed)
	set_meta("haunted_prop_counts",_haunted_counts.duplicate(true))


func _exterior(room: Dictionary, container: Node3D) -> void:
	if _exterior_layouts.has(room.route_id):
		for cached: Dictionary in _exterior_layouts[room.route_id]:
			var prop := _asset(cached.asset,cached.at,cached.scale); prop.get_parent().reparent(container)
		return
	var used: Array[Rect2] = []
	var placements: Array = []
	for asset: String in ["small_loft" if int(room.number)%5==0 else ("hex_pavilion" if int(room.number)%3==0 else "low_rockery"),"red_maple" if int(room.number)%2==0 else "crooked_pine"]:
		if asset in ["small_loft","hex_pavilion","low_rockery"] and int(room.number)%3!=0: continue
		var scale_value := .48 if asset in ["small_loft","hex_pavilion"] else .55
		var half: Vector2 = INTERIORS.MODELS[asset].get("crown",INTERIORS.MODELS[asset].half)*scale_value
		for delta in [Vector2(0,-4),Vector2(0,4),Vector2(-4,0),Vector2(4,0),Vector2(-4,-4),Vector2(4,4)]:
			var point: Vector2 = (room.stand+delta).round()
			var rect := Rect2(point-half,half*2).grow(.2)
			if _exterior_used.any(func(old):return old.intersects(rect)): continue
			if passage_features.any(func(feature):return feature.bounds.intersects(rect)): continue
			var clear := true
			for x in range(floori(rect.position.x+.5),ceili(rect.end.x+.5)):
				for y in range(floori(rect.position.y+.5),ceili(rect.end.y+.5)):
					if not plan.plots.has(Vector2i(x,y)) or plan.plots[Vector2i(x,y)]=="water": clear = false; break
				if not clear: break
			if not clear: continue
			var prop := _asset(asset,point,scale_value); prop.get_parent().reparent(container)
			_exterior_used.append(rect); used.append(rect); placements.append({"asset":asset,"at":point,"scale":scale_value}); break
	_exterior_layouts[room.route_id] = placements
	container.set_meta("exterior_bays",used)


func update_occlusion(walker: Vector3) -> void:
	houses = houses.filter(func(item):return is_instance_valid(item.node))
	var signature := str([walker,camera.global_transform,camera.get_viewport().size,houses.size()])
	if signature==_occlusion_signature: return
	_occlusion_signature = signature
	var viewport_size := Vector2(camera.get_viewport().size)
	var foot := camera.unproject_position(walker)
	var head := camera.unproject_position(walker+Vector3.UP*1.37)
	var center := foot.lerp(head,.55)/viewport_size
	var radius := (head.distance_to(foot)*.88+18)/maxf(1,viewport_size.y)
	var back := Vector2(camera.global_position.x-walker.x,camera.global_position.z-walker.z).normalized()
	_wall_plane = Vector4.ZERO
	if _run!=null:
		var current_box: Rect2 = layout.rooms[_run.current_room].bounds.grow(.22)
		_wall_clip = Vector4(current_box.position.x,current_box.position.y,current_box.end.x,current_box.end.y)
		if current_box.has_point(Vector2(walker.x,walker.z)):
			_wall_plane = Vector4(back.x,back.y,back.dot(current_box.get_center()),1.0)
	for chunk: Node3D in chunks.values():
		for mesh: MeshInstance3D in chunk.get_meta("facades",[]):
			mesh.set_instance_shader_parameter("garden_wall_clip",_wall_clip); mesh.set_instance_shader_parameter("garden_wall_plane",_wall_plane)
	for house in houses:
		var box: Rect2 = house.bounds
		var bounds := AABB(Vector3(box.position.x,1.65,box.position.y),Vector3(box.size.x,3.2,box.size.y))
		var occludes: bool = bounds.intersects_segment(camera.global_position,walker+Vector3.UP*.75)!=null
		var room_id := str(house.get("room_id",house.node.get_meta("room_id","")))
		var inside := box.has_point(Vector2(walker.x,walker.z)) and not reveal_all
		var adjacent_occluder: bool = occludes and not inside and not room_id.is_empty() and room_id!=_run.current_room
		if house.node.has_method("set_wall_cutaway"): house.node.set_wall_cutaway(_wall_clip,_wall_plane if inside else Vector4.ZERO)
		if house.node.has_method("set_roofs_faded"):
			house.node.set_roofs_faded(adjacent_occluder and not reveal_all)
		if house.node.has_method("set_roof_aperture"):
			# Cut along the actual ridge. Keeping the opposite roof slope reads as
			# a roofed building, rather than a hollow frame or a diagonal slice.
			var axis := Vector2(signf(back.x),0) if box.size.y>box.size.x else Vector2(0,signf(back.y))
			var plane := Vector4(axis.x,axis.y,axis.dot(box.get_center()),1.0) if inside else Vector4.ZERO
			var mode := 1.0 if (occludes or inside) and not reveal_all else 0.0
			house.node.set_roof_aperture(Vector4(center.x,center.y,radius,mode),plane)


func _lotus() -> void:
	var water_y: float = preload("res://src/expedition/garden_bridge_plan.gd").WATER_Y
	for pond: Rect2i in plan.ponds:
		var at := Vector2(pond.position)+(Vector2(pond.size)-Vector2.ONE)*.5
		var root := _holder(at)
		var leaves := LIBRARY.instantiate("compact:lotus-leaves-v1",func():
			var original := preload("res://src/map/expedition_lotus_leaf_layer.gd").new()
			original.half_extent = Vector2(1.35,.35); original.small_leaf_count = 7; original.large_leaf_count = 0
			original.water_height = water_y+.008; original.setup(style); return original,style)
		root.add_child(leaves)
		if pond.size.y>pond.size.x: root.rotation.y = PI*.5
		var flower := LIBRARY.instantiate("compact:lotus-flower-v1",func():
			var original := preload("res://src/map/expedition_lotus_tile.gd").new(); original.plants_only = true
			original.water_height = water_y/.3; original.setup(style); return original,style)
		root.add_child(flower); flower.scale = Vector3.ONE*.3
		root.visible = false
		await _slice()
