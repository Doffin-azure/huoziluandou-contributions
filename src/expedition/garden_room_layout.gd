extends RefCounted
## Dynamic room geometry and a quarter-unit walking grid, independent of run state.
const CATALOG = preload("res://src/expedition/room_template_catalog.gd")
const INTERIORS = preload("res://src/expedition/room_interior_assets.gd")
const CLUSTER = preload("res://src/expedition/garden_cluster_plan.gd")
const SITE = preload("res://src/expedition/garden_site_plan.gd")
const POND_FIELD = preload("res://src/expedition/garden_pond_field.gd")
const STEP := .25
const DIRECTIONS := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
var rooms := {}
var corridors: Array = []
var cells := {} # Vector2i -> {rooms:[], edges:[]}; junction cells may have several owners.
var bounds := Rect2()
var error := ""
var clusters: Array = []
var site := {} # Authored whole-site geometry, independent of node bounds.
var walk_step := STEP
var grid_origin := Vector2.ZERO
var links := {} # New whole-tile maps validate the fine clearance between tile centers.
var compact: RefCounted # Present only for the 55-stop compound layout.


func build(graph: Dictionary) -> bool:
	walk_step = STEP; grid_origin = Vector2.ZERO; links.clear()
	compact = null
	if graph.has("compact_plan"): return preload("res://src/expedition/garden_compact_run_plan.gd").build(self,graph)
	if graph.has("authored_site"): return preload("res://src/expedition/authored_garden_plan.gd").build(self,graph)
	site = {}
	if not graph.has("site_plan"): return _build_candidate(graph)
	if graph.site_plan.has("error"): error = graph.site_plan.error; return false
	var first: int = graph.site_plan.candidate
	for attempt in SITE.candidate_count(graph):
		if attempt>0: SITE.apply(graph,(first+attempt)%SITE.candidate_count(graph))
		if _build_candidate(graph): return true
	return false


func _build_candidate(graph: Dictionary) -> bool:
	rooms.clear(); corridors.clear(); cells.clear(); clusters.clear(); error = ""
	var templates := {}
	for template in CATALOG.templates(): templates[template.kind] = template
	var first := true
	for id: String in graph.rooms:
		var spec: Dictionary = graph.rooms[id]
		var room := CATALOG.with_variant(templates[spec.kind],spec.kind in ["event","rest"])
		# Runtime services have two through ports; branching happens at real bridge junctions.
		if spec.kind=="shop":
			room.ports = [CATALOG._port("S",3,"entry"),CATALOG._port("N",4.5)]
		elif spec.kind!="start":
			room.ports = room.ports.filter(func(p): return p.side in ["N","S"])
		room.erase("bridge_side") # Inter-room connectors own their decks and approaches.
		room["route_id"] = id
		var angle := atan2(spec.forward.x,-spec.forward.y)
		if spec.kind=="start" and not graph.has("site_plan"): angle += PI
		var basis := Transform2D(angle,Vector2.ZERO)
		var half := Vector2(room.floor_size)*.5
		var transform := Transform2D(angle,spec.center-basis*half)
		# A merge may turn the route around the lake. Its entrance follows the OLD
		# segment, while its exit follows the NEW segment; never force both onto one axis.
		if not graph.has("site_plan") and not spec.previous.is_empty():
			var incoming: Vector2 = graph.rooms[spec.previous[0]].forward
			var local_normal := transform.basis_xform_inv(-incoming)
			var side := "E" if local_normal.x>.5 else ("W" if local_normal.x<-.5 else ("S" if local_normal.y>.5 else "N"))
			for port in room.ports:
				if port.role=="entry":
					port.side = side
					port.offset = (room.floor_size.x if side in ["N","S"] else room.floor_size.y)*.5
		room["transform"] = transform
		if graph.has("site_plan"): SITE.configure_room(room,spec,graph)
		else: CLUSTER.configure_room(room,spec,transform)
		CATALOG.apply_enclosure(room)
		var box := Rect2(transform*Vector2.ZERO,Vector2.ZERO)
		for p in [Vector2(room.floor_size.x,0),Vector2(room.floor_size),Vector2(0,room.floor_size.y)]: box = box.expand(transform*p)
		room["bounds"] = box
		room["input"] = _port_world(room,"entry")
		room["output"] = _port_world(room,"exit")
		room["edge_ports"] = {}
		for port in room.ports:
			for edge_id: String in port.get("edges",[]): room.edge_ports[edge_id] = _world_port(room,port)
		room["blocks"] = _prop_blocks(room)
		rooms[id] = room
		bounds = box if first else bounds.merge(box)
		first = false
		_add_room_cells(room)
	clusters = SITE.describe(graph,rooms) if graph.has("site_plan") else CLUSTER.describe(graph,rooms)
	bounds = bounds.grow(9)
	# Route wide corridors on a coarser grid, then rasterize the same decks for walking.
	var reserve := {}
	for edge: Dictionary in graph.edges:
		var route := _route(edge,reserve)
		if route.is_empty(): error = "无法连接房门："+edge.id; return false
		var corridor := edge.duplicate(true)
		if graph.has("site_plan"): corridor["site_route"] = true
		if rooms[edge.from].get("cluster_id","")!="" and rooms[edge.from].get("cluster_id","")==rooms[edge.to].get("cluster_id",""):
			corridor["cluster_id"] = rooms[edge.from].cluster_id
		corridor["points"] = route
		corridors.append(corridor)
		for i in range(route.size()-1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i+1]
			var rect := Rect2(a,Vector2.ZERO).expand(b).grow(.42)
			for c in _grid_rect(rect):
				var p := point(c)
				if rect.has_point(p): _own(c,"edges",edge.id)
			var reserved := rect.grow(.55)
			for c in _coarse_rect(reserved):
				if not reserved.has_point(Vector2(c)*.5): continue
				if not reserve.has(c): reserve[c] = []
				reserve[c].append(edge)
	if graph.has("site_plan"): SITE.finish_landscape(self)
	return true


func _port_world(room: Dictionary, role: String) -> Dictionary:
	for port: Dictionary in room.ports:
		if port.role!=role: continue
		return _world_port(room,port)
	return {}


func _world_port(room: Dictionary, port: Dictionary) -> Dictionary:
	var local3 := CATALOG.port_position(room,port)
	var normal: Vector2 = {"N":Vector2.UP,"S":Vector2.DOWN,"E":Vector2.RIGHT,"W":Vector2.LEFT}[port.side]
	return {"at":room.transform*Vector2(local3.x,local3.z),"normal":room.transform.basis_xform(normal)}


func _prop_blocks(room: Dictionary) -> Array:
	var blocks: Array = []
	var half_sizes := {"pavilion":Vector2(.96,.85),"stall":Vector2(1.0,.65),"shrine":Vector2(.72,.56),"chest":Vector2(.55,.36),"beast_gate":Vector2(1.05,.32),"pine":Vector2(.25,.22),"tomb":Vector2(.48,.28),"lamp":Vector2(.16,.16),"ghost_fire":Vector2(.22,.22),"screen":Vector2(1.83,.48),"type_cabinet":Vector2(.52,.36),"rock_bed":Vector2(.65,.50),"stele_plinth":Vector2(.56,.41)}
	for prop: Dictionary in room.props:
		if INTERIORS.has_asset(prop.asset):
			for local: Rect2 in INTERIORS.local_blocks(prop.asset):
				_add_prop_block(blocks,prop,local.get_center(),local.size*.5)
		elif prop.asset=="water_pavilion":
			# Roofs and benches are not an invisible solid building. Reserve the two
			# side bays, leaving both the central passage and outside bypass usable.
			for x in [-1.2,1.2]:
				_add_prop_block(blocks,prop,Vector2(x,0),Vector2(.13,.77))
		elif half_sizes.has(prop.asset):
			_add_prop_block(blocks,prop,Vector2.ZERO,half_sizes[prop.asset])
	# Gallery pillars are solid; its center lane retains its real raised floor.
	for prop: Dictionary in room.props:
		if prop.asset=="covered_walk":
			for z in [1.4,2.5,3.6]:
				for x in [.34,1.30]: blocks.append(Rect2(x-.12,z-.12,.24,.24))
	return blocks


func _add_prop_block(blocks: Array, prop: Dictionary, center: Vector2, half: Vector2) -> void:
	var half_size := half*float(prop.scale)+Vector2.ONE*.10
	var transform := Transform2D(-float(prop.turn),Vector2(prop.at.x,prop.at.z))
	var at: Vector2 = center*float(prop.scale)
	var rect := Rect2(transform*(at-half_size),Vector2.ZERO)
	for corner in [Vector2(-1,1),Vector2(1,1),Vector2(1,-1)]: rect = rect.expand(transform*(at+half_size*corner))
	blocks.append(rect)


func _add_room_cells(room: Dictionary) -> void:
	var inv: Transform2D = room.transform.affine_inverse()
	for c in _grid_rect(room.bounds.grow(.3)):
		var local: Vector2 = inv*point(c)
		var inside := Rect2(Vector2.ONE*.25,Vector2(room.floor_size)-Vector2.ONE*.5).has_point(local)
		for port in room.ports:
			var at := CATALOG.port_position(room,port)
			var door := Rect2(at.x-.32,at.z-.32,.64,.64)
			if port.side in ["N","S"]: door = door.grow_individual(0,.25,0,.25)
			else: door = door.grow_individual(.25,0,.25,0)
			inside = inside or door.has_point(local)
		if inside and POND_FIELD.sample(room.get("ponds",[]),local)<=-.18 and not room.blocks.any(func(rect): return rect.has_point(local)):
			_own(c,"rooms",room.route_id)
	var stand: Vector2 = room.transform*room.stand
	room["stand_cell"] = nearest(stand,room.route_id)


func _own(c: Vector2i, key: String, id: String) -> void:
	if not cells.has(c): cells[c] = {"rooms":[],"edges":[]}
	if not cells[c][key].has(id): cells[c][key].append(id)


func _route(edge: Dictionary, reserve: Dictionary) -> Array:
	var start: Dictionary = rooms[edge.from].edge_ports.get(edge.id,rooms[edge.from].output)
	var finish: Dictionary = rooms[edge.to].edge_ports.get(edge.id,rooms[edge.to].input)
	if start.is_empty() or finish.is_empty(): return []
	var authored := CLUSTER.route(edge,rooms)
	if not authored.is_empty(): return authored
	var a: Vector2 = start.at+start.normal*1.0
	var b: Vector2 = finish.at+finish.normal*1.0
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(Vector2i((bounds.position*2).floor()),Vector2i((bounds.size*2).ceil())+Vector2i.ONE)
	astar.cell_size = Vector2.ONE*.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for cluster: Dictionary in clusters:
		for segment: Dictionary in CLUSTER.wall_segments(cluster):
			var wall := Rect2(segment.a,Vector2.ZERO).expand(segment.b).grow(.20)
			for c in _coarse_rect(wall):
				if wall.has_point(Vector2(c)*.5) and astar.is_in_boundsv(c): astar.set_point_solid(c)
		var pond_bounds: Rect2 = cluster.bounds
		for c in _coarse_rect(pond_bounds):
			if astar.is_in_boundsv(c) and POND_FIELD.sample(cluster.ponds,Vector2(c)*.5)>-.55: astar.set_point_solid(c)
	for room: Dictionary in rooms.values():
		var obstacle: Rect2 = room.bounds.grow(.65)
		for c in _coarse_rect(obstacle):
			if obstacle.has_point(Vector2(c)*.5) and astar.is_in_boundsv(c): astar.set_point_solid(c)
	for c: Vector2i in reserve:
		var permitted := false
		for old: Dictionary in reserve[c]:
			if old.from==edge.from: permitted = true
			if old.to==edge.to: permitted = true
		if not permitted and astar.is_in_boundsv(c): astar.set_point_solid(c)
	var first := Vector2i((a*2).round())
	var last := Vector2i((b*2).round())
	astar.set_point_solid(first,false); astar.set_point_solid(last,false)
	var raw := astar.get_id_path(first,last)
	if raw.is_empty(): return []
	var points: Array = [start.at,a]
	# A* ties otherwise alternate X/Y into a staircase. Pull clear orthogonal
	# segments through the SAME reservation grid, so no decorative shortcut is invented.
	var cursor := 0
	while cursor<raw.size()-1:
		var chosen := cursor+1
		var bend: Vector2i = raw[chosen]
		for j in range(raw.size()-1,cursor,-1):
			var horizontal := Vector2i(raw[j].x,raw[cursor].y)
			var vertical := Vector2i(raw[cursor].x,raw[j].y)
			if _clear_line(astar,raw[cursor],horizontal) and _clear_line(astar,horizontal,raw[j]): chosen = j; bend = horizontal; break
			if _clear_line(astar,raw[cursor],vertical) and _clear_line(astar,vertical,raw[j]): chosen = j; bend = vertical; break
		points.append(Vector2(raw[cursor])*.5); points.append(Vector2(bend)*.5); points.append(Vector2(raw[chosen])*.5)
		cursor = chosen
	points.append(b); points.append(finish.at)
	var compact: Array = []
	for p: Vector2 in points:
		if not compact.is_empty() and p.is_equal_approx(compact[-1]): continue
		if compact.size()>1 and (p-compact[-1]).normalized().is_equal_approx((compact[-1]-compact[-2]).normalized()): compact[-1] = p
		else: compact.append(p)
	return compact


func _clear_line(astar: AStarGrid2D, a: Vector2i, b: Vector2i) -> bool:
	var direction := Vector2i(signi(b.x-a.x),signi(b.y-a.y))
	var distance := absi(b.x-a.x)+absi(b.y-a.y)
	for i in distance+1:
		var p := a+direction*i
		if not astar.is_in_boundsv(p) or astar.is_point_solid(p): return false
	return true


func nearest(p: Vector2, room_id := "") -> Vector2i:
	var c := cell(p)
	var best := c
	var distance := INF
	for x in range(-6,7):
		for y in range(-6,7):
			var k := c+Vector2i(x,y)
			if not cells.has(k) or (not room_id.is_empty() and not cells[k].rooms.has(room_id)): continue
			var d := point(k).distance_squared_to(p)
			if d<distance: distance = d; best = k
	return best


func path(from: Vector2i, to: Vector2i, permitted: Callable) -> Array:
	if not cells.has(to) or not permitted.call(to): return []
	var queue: Array[Vector2i] = [from]
	var previous := {from:from}
	var cursor := 0
	while cursor<queue.size():
		var c := queue[cursor]; cursor += 1
		if c==to: break
		for delta: Vector2i in DIRECTIONS:
			var next := c+delta
			if previous.has(next) or not cells.has(next) or not permitted.call(next): continue
			if not can_step(c,next): continue
			previous[next] = c; queue.append(next)
	if not previous.has(to): return []
	var result: Array = [to]
	while result[-1]!=from: result.append(previous[result[-1]])
	result.reverse()
	return result


func cell(p: Vector2) -> Vector2i: return Vector2i(((p-grid_origin)/walk_step).round())
func point(c: Vector2i) -> Vector2: return grid_origin+Vector2(c)*walk_step


func can_step(from: Vector2i, to: Vector2i) -> bool:
	return links.is_empty() or links.get(from,[]).has(to)

static func _grid_rect(rect: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(floori(rect.position.x/STEP),ceili(rect.end.x/STEP)+1):
		for y in range(floori(rect.position.y/STEP),ceili(rect.end.y/STEP)+1): result.append(Vector2i(x,y))
	return result

static func _coarse_rect(rect: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(floori(rect.position.x*2),ceili(rect.end.x*2)+1):
		for y in range(floori(rect.position.y*2),ceili(rect.end.y*2)+1): result.append(Vector2i(x,y))
	return result
