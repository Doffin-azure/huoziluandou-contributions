extends RefCounted
## First fork: compact connected garden around one inner pond. IDs and contents
## remain unchanged. Geometry is derived anew, so spatial retries remain valid.
const FIELD = preload("res://src/expedition/garden_pond_field.gd")


static func apply_graph(graph: Dictionary) -> void:
	var group: Dictionary = graph.groups[0]
	var origin: Vector2 = graph.rooms[group.source].center
	var next_center := origin+Vector2(0,-20)
	var shift: Vector2 = next_center-graph.rooms[group.merge].center
	var members: Array = [group.source,group.merge]
	for branch: Array in group.branches: members.append_array(branch)
	for id: String in graph.rooms:
		# A narrow turning pocket outside the east garden gate keeps a three-way
		# next fork from trapping the common exit against its nearest courtyard.
		if id not in members and id not in ["start","opening_1"]: graph.rooms[id].center += shift+Vector2(3,0)
	graph.rooms[group.merge].center = next_center
	graph.rooms[group.source]["cluster_role"] = "source"
	graph.rooms[group.merge]["cluster_role"] = "merge"
	for b in group.branches.size():
		var branch: Array = group.branches[b]
		var side := -1.0 if b==0 else 1.0
		for j in branch.size():
			var spec: Dictionary = graph.rooms[branch[j]]
			var y := -10.0 if branch.size()==1 else (-6.5 if j==0 else -13.5)
			spec.center = origin+Vector2(side*7.0,y)
			spec["cluster_role"] = "wing"
			spec["cluster_side"] = int(side)
			spec["cluster_rank"] = j
			spec["cluster_last"] = j==branch.size()-1
			spec.forward = Vector2.UP
	for id: String in members: graph.rooms[id]["cluster_id"] = "lotus_garden"
	graph["clusters"] = [{"id":"lotus_garden","source":group.source,"merge":group.merge,"members":members,"seed":int(graph.seed)*97+int(graph.act)*131}]


static func configure_room(room: Dictionary, spec: Dictionary, transform: Transform2D) -> void:
	if not spec.has("cluster_id"): return
	room["cluster_id"] = spec.cluster_id
	room["cluster_role"] = spec.cluster_role
	room.ports = []
	if spec.cluster_role=="source":
		_world_port(room,transform,"S","entry",0)
		_world_port(room,transform,"N","exit",0)
	elif spec.cluster_role=="merge":
		_world_port(room,transform,"S","entry",0)
		_world_port(room,transform,"E","exit",0)
	else:
		var side: int = spec.cluster_side
		_world_port(room,transform,"S","entry",side*.5 if spec.cluster_rank>0 else 0)
		_world_port(room,transform,("E" if side<0 else "W") if spec.cluster_last else "N","exit",0 if spec.cluster_last else -side*1.0)
		# A real inset pool in the upper wing, distinct from the shared main pond.
		if spec.cluster_last and room.kind in ["event","rest"]:
			room["ponds"] = [{"center":Vector2(room.floor_size.x-1.2,.95),"radius":Vector2(.85,.65),"seed":int(spec.content_seed)%10000}]
			room.props = room.props.filter(func(prop): return prop.asset not in ["hollow_rockery","bare_locust","willow","low_rockery","rock_bed","crooked_pine"])
			for prop in room.props.duplicate():
				if FIELD.sample(room.ponds,Vector2(prop.at.x,prop.at.z))>-.35: room.props.erase(prop)
	# The shared outer garden replaces outside-water scenery for these courts.
	room.water_sides = []
	room.lanes = []
	for port in room.ports:
		var at := _port_at(room,port)
		room.lanes.append([Vector2(at.x,at.z),room.stand])


static func _world_port(room: Dictionary, transform: Transform2D, world_side: String, role: String, offset: float) -> void:
	var normal: Vector2 = {"N":Vector2.UP,"E":Vector2.RIGHT,"S":Vector2.DOWN,"W":Vector2.LEFT}[world_side]
	var local := transform.basis_xform_inv(normal)
	var side := "E" if local.x>.5 else ("W" if local.x<-.5 else ("S" if local.y>.5 else "N"))
	var length: float = room.floor_size.x if side in ["N","S"] else room.floor_size.y
	var tangent := Vector2.RIGHT if world_side in ["N","S"] else Vector2.DOWN
	var local_tangent := transform.basis_xform_inv(tangent*offset)
	var shift := local_tangent.x if side in ["N","S"] else local_tangent.y
	var terrace: bool = room.enclosure=="terrace"
	room.ports.append({"id":side.to_lower()+"_"+role,"side":side,"offset":length*.5+shift,"role":role,"frame":"open" if terrace else "moon","span":1.0 if terrace else 2.0,"clear_width":.95,"role_mutable":true})


static func _port_at(room: Dictionary, port: Dictionary) -> Vector3:
	match port.side:
		"N": return Vector3(port.offset,0,0)
		"E": return Vector3(room.floor_size.x,0,port.offset)
		"S": return Vector3(port.offset,0,room.floor_size.y)
	return Vector3(0,0,port.offset)


static func describe(graph: Dictionary, rooms: Dictionary) -> Array:
	var result: Array = []
	for source: Dictionary in graph.get("clusters",[]):
		var cluster := source.duplicate(true)
		var origin: Vector2 = graph.rooms[source.source].center
		var factor: float = (origin.y-graph.rooms[source.merge].center.y)/20.0
		cluster["origin"] = origin
		cluster["ponds"] = [{"center":origin+Vector2(0,-10.0)*factor,"radius":Vector2(2.35,5.1)*factor,"seed":cluster.seed},{"center":origin+Vector2(-7.0,.4)*factor,"radius":Vector2(1.7,1.35)*factor,"seed":int(cluster.seed)+233}]
		cluster["ornaments"] = [
			{"scene":"small_loft","at":origin+Vector2(-6.5,-19.5)*factor,"scale":.72},
			{"scene":"hex_pavilion","at":origin+Vector2(6.5,-21.7)*factor,"scale":.62},
			{"scene":"red_maple","at":origin+Vector2(7.2,.3)*factor,"scale":.58},
			{"scene":"weeping_willow","at":origin+Vector2(-9.5,1.0)*factor,"scale":.50},
			{"scene":"low_rockery","at":origin+Vector2(-4.8,1.8)*factor,"scale":.45},
			{"scene":"hollow_rockery","at":origin+Vector2(9.2,1.5)*factor,"scale":.42}]
		var bounds: Rect2 = rooms[source.source].bounds
		for id in source.members: bounds = bounds.merge(rooms[id].bounds)
		bounds = bounds.grow(1.0)
		var start := (bounds.position*2).floor()*.5
		var end := (bounds.end*2).ceil()*.5
		cluster["bounds"] = Rect2(start,end-start)
		cluster["gates"] = [{"side":"S","at":Vector2(origin.x,end.y)},{"side":"E","at":Vector2(end.x,graph.rooms[source.merge].center.y)}]
		result.append(cluster)
	return result


static func route(edge: Dictionary, rooms: Dictionary) -> Array:
	var from: Dictionary = rooms[edge.from]; var to: Dictionary = rooms[edge.to]
	if from.get("cluster_id","").is_empty() or from.get("cluster_id","")!=to.get("cluster_id",""): return []
	var a: Vector2 = from.output.at; var b: Vector2 = to.input.at
	if from.cluster_role=="source":
		var y := a.y-.75
		return [a,Vector2(a.x,y),Vector2(b.x,y),b]
	if to.cluster_role=="merge":
		var x: float = a.x+float(from.output.normal.x)*.75
		var y := b.y+1.0
		return [a,Vector2(x,a.y),Vector2(x,y),Vector2(b.x,y),b]
	var y := (a.y+b.y)*.5
	return [a,Vector2(a.x,y),Vector2(b.x,y),b]


static func wall_segments(cluster: Dictionary) -> Array:
	var bounds: Rect2 = cluster.bounds
	var result: Array = []
	for side: String in ["N","E","S","W"]:
		var length := bounds.size.x if side in ["N","S"] else bounds.size.y
		var holes: Array = []
		for gate in cluster.gates:
			if gate.side==side:
				var offset: float = gate.at.x-bounds.position.x if side in ["N","S"] else gate.at.y-bounds.position.y
				holes.append(Vector2(offset-1.0,offset+1.0))
		var cursor := 0.0
		while cursor<length-.01:
			var finish := minf(length,cursor+1.0)
			for hole: Vector2 in holes:
				if cursor>=hole.x-.001 and cursor<hole.y-.001: cursor = hole.y; finish = cursor; break
				if cursor<hole.x and finish>hole.x: finish = hole.x
			if finish<=cursor+.001: continue
			var first := _edge(bounds,side,cursor); var last := _edge(bounds,side,finish)
			result.append({"a":first,"b":last,"center":(first+last)*.5})
			cursor = finish
	return result


static func _edge(rect: Rect2, side: String, offset: float) -> Vector2:
	match side:
		"N": return rect.position+Vector2(offset,0)
		"S": return Vector2(rect.position.x+offset,rect.end.y)
		"E": return Vector2(rect.end.x,rect.position.y+offset)
	return rect.position+Vector2(0,offset)
