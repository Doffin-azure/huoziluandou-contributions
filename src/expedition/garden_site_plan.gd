extends RefCounted
## Whole-site packing of the series/parallel route graph. A fork is a graph
## fragment, never a reserved rectangle. All room footprints enter the score.
const CATALOG = preload("res://src/expedition/room_template_catalog.gd")
const PONDS = preload("res://src/expedition/garden_pond_field.gd")
const PITCH := Vector2(8.5,7.5)
const NORMALS := {"N":Vector2.UP,"E":Vector2.RIGHT,"S":Vector2.DOWN,"W":Vector2.LEFT}
static var _cache := {}


static func candidate_count(graph: Dictionary) -> int:
	return _prepare(graph).size()


static func apply(graph: Dictionary, attempt := 0) -> void:
	var candidates := _prepare(graph)
	if candidates.is_empty():
		graph["site_plan"] = {"candidate":0,"error":"未找到可连接的整园布局"}
		graph["layout_version"] = 4
		return
	var chosen: Dictionary = candidates[attempt%candidates.size()]
	for id: String in graph.rooms:
		var spec: Dictionary = graph.rooms[id]
		for stale in ["cluster_id","cluster_role","cluster_side","cluster_rank","cluster_last"]: spec.erase(stale)
		spec.center = (Vector2(chosen.points[id])*PITCH).snapped(Vector2.ONE*.5)
		spec.forward = Vector2.UP
	graph.erase("clusters")
	graph["site_plan"] = {"candidate":attempt,"score":chosen.score,"seed":int(graph.seed)*193+int(graph.act)*743,"bounds":chosen.bounds}
	graph["layout_version"] = 4


static func _prepare(graph: Dictionary) -> Array:
	var key := str(graph.seed)+":"+str(graph.act)
	if not _cache.has(key):
		_cache[key] = _candidates(graph)
		if _cache.size()>16: _cache.erase(_cache.keys()[0])
	return _cache[key]


static func _candidates(graph: Dictionary) -> Array:
	var packed := _search(graph,true)
	var outward := _search(graph,false)
	packed.append_array(outward)
	packed.sort_custom(func(a,b): return a.score<b.score)
	var sizes := {}
	for template in CATALOG.templates(): sizes[template.kind] = Vector2(template.floor_size)
	var rng := RandomNumberGenerator.new(); rng.seed = int(graph.seed)*1103+int(graph.act)*6571
	var folded: Array = []
	for state: Dictionary in packed.slice(0,12):
		for group: Dictionary in graph.groups.slice(1):
			var tail := _tail(graph,group.source)
			var pivot: Vector2 = state.points[group.source]
			for turn in [0,1,2,3]:
				for offset: Vector2 in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP*2,Vector2.RIGHT*2,Vector2.DOWN*2,Vector2.LEFT*2]:
					var points: Dictionary = state.points.duplicate()
					for id: String in tail: points[id] = pivot+(Vector2(points[id])-pivot).rotated(turn*PI*.5).round()+offset
					if not _fits(points,graph,sizes,false): continue
					folded.append({"points":points,"score":_score(points,graph,sizes),"bounds":_bounds(points,graph,sizes),"curved":true})
	packed.append_array(folded)
	packed.sort_custom(func(a,b): return a.score<b.score)
	var relaxed: Array = []
	for state: Dictionary in packed.slice(0,8): relaxed.append(_relax(state,graph,sizes,rng))
	packed.append_array(relaxed)
	packed.sort_custom(func(a,b): return a.score<b.score)
	var tucked: Array = []
	var offsets := [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]
	for state: Dictionary in packed.slice(0,8):
		for first: Vector2 in offsets:
			for second: Vector2 in offsets:
				var points: Dictionary = state.points.duplicate()
				points.opening_1 = points.opening_2+first
				points.start = points.opening_1+second
				if not _fits(points,graph,sizes,false): continue
				tucked.append({"points":points,"score":_score(points,graph,sizes),"bounds":_bounds(points,graph,sizes)})
	packed.append_array(tucked)
	packed.sort_custom(func(a,b): return a.score<b.score)
	return packed


static func _tail(graph: Dictionary, source: String) -> Array:
	var found: Array = []; var queue: Array = graph.rooms[source].next.duplicate()
	while not queue.is_empty():
		var id: String = queue.pop_front()
		if found.has(id): continue
		found.append(id); queue.append_array(graph.rooms[id].next)
	return found


static func _relax(state: Dictionary, graph: Dictionary, sizes: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if state.get("curved",false): return state
	var points: Dictionary = state.points.duplicate()
	var score := _score(points,graph,sizes)
	var best := {"points":points.duplicate(),"score":score,"bounds":_bounds(points,graph,sizes)}
	var ids: Array = points.keys()
	for iteration in 450:
		var id: String = ids[rng.randi_range(0,ids.size()-1)]
		var old: Vector2 = points[id]
		var direction: Vector2 = [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT][rng.randi_range(0,3)]
		points[id] = old+direction
		if not _fits(points,graph,sizes): points[id] = old; continue
		var next := _score(points,graph,sizes)
		var temperature := lerpf(110.0,4.0,iteration/450.0)
		if next<score or rng.randf()<exp((score-next)/temperature): score = next
		else: points[id] = old; continue
		if score<float(best.score): best = {"points":points.duplicate(),"score":score,"bounds":_bounds(points,graph,sizes)}
	return best


static func _search(graph: Dictionary, inward: bool) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = int(graph.seed)*193+int(graph.act)*743
	var sizes := {}
	for template in CATALOG.templates(): sizes[template.kind] = Vector2(template.floor_size)
	var initial := {"points":{"start":Vector2(-2,0),"opening_1":Vector2(-1,0),"opening_2":Vector2.ZERO}}
	var beam: Array = [initial]
	for group: Dictionary in graph.groups:
		var expanded: Array = []
		for state: Dictionary in beam:
			for rotation in 4:
				for mirror in [-1,1]:
					for form in (range(4) if group.branches.size()==3 else range(5 if inward else 3)):
						var points: Dictionary = state.points.duplicate()
						var pattern := _pattern(group,form)
						var source: Vector2 = points[group.source]
						for id: String in pattern:
							var point: Vector2 = pattern[id]; point.y *= mirror
							points[id] = source+point.rotated(rotation*PI*.5).round()
						if not _fits(points,graph,sizes): continue
						var score := _score(points,graph,sizes)
						expanded.append({"points":points,"score":score+rng.randf()*9.0,"archetype":state.get("archetype",form)})
		expanded.sort_custom(func(a,b): return a.score<b.score)
		beam = []
		var signatures := {}
		# Retain large outer-court candidates until later rooms can occupy their
		# interior. A greedy partial-area cut would keep only long strips.
		var per_form := {}
		for state: Dictionary in expanded:
			var signature := str(state.points.values())
			if signatures.has(signature): continue
			if inward and int(per_form.get(state.archetype,0))>=20: continue
			per_form[state.archetype] = int(per_form.get(state.archetype,0))+1
			signatures[signature] = true; beam.append(state)
			if beam.size()>=100: break
	var final: Array = []
	for state: Dictionary in beam:
		for direction: Vector2 in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
			var points: Dictionary = state.points.duplicate()
			points[graph.boss] = points["last_rest"]+direction
			if not _fits(points,graph,sizes): continue
			var score := _score(points,graph,sizes)
			# A small seeded preference keeps equally compact plans from always
			# choosing the same fold. It never enters the gameplay RNG stream.
			final.append({"points":points,"score":score+rng.randf()*18,"bounds":_bounds(points,graph,sizes)})
	final.sort_custom(func(a,b): return a.score<b.score)
	return final.slice(0,96 if inward else 32)


static func _pattern(group: Dictionary, form: int) -> Dictionary:
	var result := {}
	if group.branches.size()==3:
		result[group.merge] = Vector2(2,1) if form==3 else Vector2(3 if form==1 else 2,0)
		for b in 3:
			var branch: Array = group.branches[b]
			var lane := 0 if b==0 else (1 if b==1 else -1)
			for j in branch.size():
				if form==3:
					result[branch[j]] = Vector2(1,0) if b==0 else (Vector2(j,1) if b==1 else Vector2(j+1,-1))
				else:
					result[branch[j]] = Vector2(1,0) if lane==0 else Vector2(j+1 if form==1 else j*2,lane*(2 if form==2 else 1))
		return result
	result[group.merge] = [Vector2(2,1),Vector2(1,0),Vector2(3,0),Vector2(4,0),Vector2(1,0)][form]
	var paths: Array = [
		[[Vector2(0,1),Vector2(1,1)],[Vector2(1,0),Vector2(2,0)]],
		[[Vector2(0,1),Vector2(1,1)],[Vector2(0,-1),Vector2(1,-1)]],
		[[Vector2(1,1),Vector2(2,1)],[Vector2(1,-1),Vector2(2,-1)]],
		[[Vector2(1,2),Vector2(5,2)],[Vector2(1,-2),Vector2(5,-2)]],
		[[Vector2(1,1),Vector2(2,1)],[Vector2(1,-1),Vector2(2,-1)]]][form]
	for b in 2:
		var branch: Array = group.branches[b]
		for j in branch.size(): result[branch[j]] = paths[b][j if branch.size()>1 else b]
	return result


static func _fits(points: Dictionary, graph: Dictionary, sizes: Dictionary, straight_edges := true) -> bool:
	var boxes: Array = []
	for id: String in points:
		var extent: Vector2 = sizes[graph.rooms[id].kind]
		var box := Rect2(Vector2(points[id])*PITCH-extent*.5,extent).grow(.70)
		for other: Rect2 in boxes:
			if box.intersects(other): return false
		boxes.append(box)
	for id: String in points:
		if id!="opening_2": continue
		var before := Vector2.ZERO; var after := Vector2.ZERO
		for neighbor: String in graph.rooms[id].previous:
			if points.has(neighbor): before += Vector2(points[neighbor])-Vector2(points[id])
		for neighbor: String in graph.rooms[id].next:
			if points.has(neighbor): after += Vector2(points[neighbor])-Vector2(points[id])
		if before.length_squared()>.01 and after.length_squared()>.01 and before.normalized().dot(after.normalized())>.45: return false
	if not straight_edges: return true
	var edges: Array = graph.edges.filter(func(edge): return points.has(edge.from) and points.has(edge.to))
	for i in edges.size():
		var edge: Dictionary = edges[i]
		var a: Vector2 = points[edge.from]; var b: Vector2 = points[edge.to]
		for id: String in points:
			if id in [edge.from,edge.to]: continue
			if Geometry2D.get_closest_point_to_segment(points[id],a,b).distance_to(points[id])<.35: return false
		for j in range(i):
			var other: Dictionary = edges[j]
			if edge.from in [other.from,other.to] or edge.to in [other.from,other.to]: continue
			if Geometry2D.segment_intersects_segment(a,b,points[other.from],points[other.to])!=null: return false
	return true


static func _bounds(points: Dictionary, graph: Dictionary, sizes: Dictionary) -> Rect2:
	var result := Rect2(Vector2(points.start)*PITCH,Vector2.ZERO)
	for id: String in points:
		var extent: Vector2 = sizes[graph.rooms[id].kind]
		result = result.merge(Rect2(Vector2(points[id])*PITCH-extent*.5,extent))
	return result


static func _score(points: Dictionary, graph: Dictionary, sizes: Dictionary) -> float:
	var bounds := _bounds(points,graph,sizes)
	var longest := maxf(bounds.size.x,bounds.size.y)
	var score := bounds.get_area()+longest*longest*.65+absf(bounds.size.x-bounds.size.y)*8
	for edge: Dictionary in graph.edges:
		if not points.has(edge.from) or not points.has(edge.to): continue
		var delta: Vector2 = (Vector2(points[edge.from])-Vector2(points[edge.to])).abs()*PITCH
		score += (delta.x+delta.y)*4
	# Terminal courts belong to the same garden: prefer another court behind a
	# wall rather than a long empty corner around the entrance or the boss.
	for id: String in ["start","boss"]:
		if not points.has(id): continue
		var near := 10.0
		for other: String in points:
			if other==id or other in graph.rooms[id].next or other in graph.rooms[id].previous: continue
			near = minf(near,Vector2(points[id]).distance_to(points[other]))
		score += near*90.0
	return score


static func configure_room(room: Dictionary, spec: Dictionary, graph: Dictionary) -> void:
	room.ports = []; room.lanes = []; room.water_sides = []
	var roles := {}
	# Entries are assigned first. An exit must never share an entry's wall opening.
	for role: String in ["entry","exit"]:
		var neighbors: Array = spec.previous if role=="entry" else spec.next
		for id: String in neighbors:
			var vector: Vector2 = graph.rooms[id].center-spec.center
			var options: Array = NORMALS.keys()
			options.sort_custom(func(a,b): return _door_score(vector,a,roles,role)>_door_score(vector,b,roles,role))
			var side: String = options[0]
			for candidate: String in options:
				var wall_length: float = room.floor_size.x if candidate in ["N","S"] else room.floor_size.y
				if not roles.has(candidate) or roles[candidate]==role or room.enclosure=="terrace" or wall_length>=5.0: side = candidate; break
			roles[side] = role
			var port_id := side.to_lower()+"_"+role
			var edge_id: String = id+">"+spec.id if role=="entry" else spec.id+">"+id
			var existing: Array = room.ports.filter(func(port): return port.id==port_id)
			if not existing.is_empty(): existing[0].edges.append(edge_id); continue
			var length: float = room.floor_size.x if side in ["N","S"] else room.floor_size.y
			var offset := length*.5
			if room.kind=="shop" and side=="N": offset = 4.5
			var terrace: bool = room.enclosure=="terrace"
			var port := CATALOG._port(side,offset,role,"open" if terrace else "moon")
			port["edges"] = [edge_id]; room.ports.append(port)
			var at: Vector3 = CATALOG.port_position(room,port)
			room.lanes.append([Vector2(at.x,at.z),room.stand])
	# Separate entry/exit openings on the same wall. Adjacent stages can touch
	# without forcing their external routes to cross around a shared door.
	for side: String in NORMALS:
		var ports: Array = room.ports.filter(func(port): return port.side==side)
		if ports.size()<2: continue
		var tangent := Vector2.RIGHT if side in ["N","S"] else Vector2.DOWN
		ports.sort_custom(func(a,b): return _port_target(a,graph).dot(tangent)<_port_target(b,graph).dot(tangent))
		var length: float = room.floor_size.x if side in ["N","S"] else room.floor_size.y
		for i in ports.size(): ports[i].offset = length*.5+(-1.0 if i==0 else 1.0)*(1.5 if length>=6 else 1.0)
	room.lanes = []
	for port in room.ports:
		var at: Vector3 = CATALOG.port_position(room,port)
		room.lanes.append([Vector2(at.x,at.z),room.stand])
	# Select a corner outside doors and retained services for a small true inset pool.
	if room.kind in ["event","rest"]:
		var at := Vector2(room.floor_size.x-1.05,.95)
		var blocked: bool = room.lanes.any(func(lane): return Geometry2D.get_closest_point_to_segment(at,lane[0],lane[1]).distance_to(at)<1.05)
		if not blocked:
			room["ponds"] = [{"center":at,"radius":Vector2(.72,.60),"seed":int(spec.content_seed)%10000}]
			room.props = room.props.filter(func(prop): return PONDS.sample(room.ponds,Vector2(prop.at.x,prop.at.z))<-.6)


static func _door_score(vector: Vector2, side: String, occupied: Dictionary, role: String) -> float:
	return vector.normalized().dot(NORMALS[side])-(.40 if occupied.has(side) else 0.0)-(.20 if occupied.has(side) and occupied[side]!=role else 0.0)


static func _port_target(port: Dictionary, graph: Dictionary) -> Vector2:
	var result := Vector2.ZERO
	for edge: String in port.edges:
		var ends := edge.split(">")
		result += Vector2(graph.rooms[ends[0] if port.role=="entry" else ends[1]].center)
	return result/port.edges.size()


static func describe(graph: Dictionary, rooms: Dictionary) -> Array:
	var bounds: Rect2 = rooms.start.bounds
	for room: Dictionary in rooms.values(): bounds = bounds.merge(room.bounds)
	var start := ((bounds.position-Vector2.ONE*3)*2).floor()*.5
	var finish := ((bounds.end+Vector2.ONE*3)*2).ceil()*.5
	return [{"id":"garden_site","members":rooms.keys(),"source":"start","merge":"boss","origin":Vector2.ZERO,"seed":graph.site_plan.seed,"bounds":Rect2(start,finish-start),"ponds":[],"ornaments":[],"gates":[]}]


static func finish_landscape(layout: RefCounted) -> void:
	var site: Dictionary = layout.clusters[0]
	var candidates: Array = []
	var bounds: Rect2 = site.bounds.grow(-1.0)
	for z in range(ceili(bounds.position.y),floori(bounds.end.y),2):
		for x in range(ceili(bounds.position.x),floori(bounds.end.x),2):
			var center := Vector2(x,z)
			var radius := Vector2(3.4,2.4)
			for scale_value in [1.0,.75,.5]:
				var extent: Vector2 = radius*scale_value
				var box := Rect2(center-extent*1.15,extent*2.3)
				if not bounds.encloses(box): continue
				if layout.rooms.values().any(func(room): return room.bounds.grow(.45).intersects(box)): continue
				if layout.corridors.any(func(corridor): return _path_near(corridor.points,box.grow(.65))): continue
				candidates.append({"center":center,"radius":extent,"seed":int(site.seed)+x*17+z*233}); break
	# Fill a few useful voids with different-sized pools, never the walking lanes.
	candidates.sort_custom(func(a,b): return a.radius.x*a.radius.y>b.radius.x*b.radius.y)
	for pond: Dictionary in candidates:
		if site.ponds.any(func(other): return other.center.distance_to(pond.center)<(other.radius.length()+pond.radius.length())*.9): continue
		site.ponds.append(pond)
		if site.ponds.size()>=4: break


static func _path_near(points: Array, bounds: Rect2) -> bool:
	for i in range(points.size()-1):
		if Rect2(points[i],Vector2.ZERO).expand(points[i+1]).grow(.01).intersects(bounds): return true
	return false
