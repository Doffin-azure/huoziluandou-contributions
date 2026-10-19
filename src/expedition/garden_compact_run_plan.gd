extends RefCounted
## Adapter between the approved spatial plan and the existing encounter graph.
const PLAN = preload("res://src/expedition/garden_blockout_plan.gd")
const PACK = preload("res://src/expedition/garden_compact_assembly.gd")


static func generate(seed_value: int, act: int) -> Dictionary:
	var plan = PACK.fit(PLAN.generate(seed_value,act))
	var graph := {"schema":1,"seed":seed_value,"act":act,"layout_kind":"compact_garden","layout_version":8,"rooms":{},"edges":[],"groups":[],"start":"start","boss":"boss","compact_plan":plan.to_data()}
	if plan.assembly.has("error"):
		graph["error"] = str(plan.assembly.error); return graph
	var rng := RandomNumberGenerator.new(); rng.seed = hash("compact-content:%d:%d" % [seed_value,act])
	for node: Dictionary in plan.nodes.values():
		graph.rooms[node.id] = {"id":node.id,"kind":node.kind,"name":node.name,"role":node.role,"row":node.row,"number":node.number,"center":Vector2(node.at),"forward":Vector2.UP,"next":[],"previous":[],"content_seed":rng.randi_range(1,1<<30)}
	for edge: Dictionary in plan.corridors:
		graph.edges.append({"id":edge.id,"from":edge.from,"to":edge.to})
		graph.rooms[edge.from].next.append(edge.to); graph.rooms[edge.to].previous.append(edge.from)
	return graph


static func build(layout: RefCounted, graph: Dictionary) -> bool:
	layout.error = str(graph.get("error",""))
	if not layout.error.is_empty(): return false
	var plan = PLAN.from_data(graph.compact_plan)
	if plan==null: layout.error = "无法读取紧凑庭院布局版本"; return false
	layout.compact = plan; layout.walk_step = 1.0; layout.grid_origin = Vector2.ZERO
	layout.rooms.clear(); layout.cells.clear(); layout.corridors.clear(); layout.clusters.clear()
	layout.links = plan.links
	layout.bounds = Rect2(Vector2(plan.bounds.position)-Vector2.ONE*.5,Vector2(plan.bounds.size))
	layout.site = {"compact":true,"generation":{"kind":"compact_garden","version":PLAN.VERSION,"seed":graph.seed,"nodes":plan.nodes.size(),"area_reduction":plan.assembly.area_reduction}}
	for node: Dictionary in plan.nodes.values():
		var box: Rect2 = plan.node_rect(node)
		layout.rooms[node.id] = {"route_id":node.id,"kind":node.kind,"name":node.name,"role":node.role,"number":int(node.number),"bounds":box,"stand":Vector2(node.at),"stand_cell":Vector2i(node.at),"floor_size":Vector2(node.extent),"transform":Transform2D(0,box.position),"props":[],"ports":[],"mark":PLAN.GLYPHS[node.kind],"mark_at":Vector2(node.extent)*.5}
		preload("res://src/expedition/garden_compact_furnishings.gd").populate(layout.rooms[node.id],node,plan)
	for cell: Vector2i in plan.cells:
		var owner: String = plan.cells[cell]
		layout.cells[cell] = {"rooms":[owner] if not owner.is_empty() else [],"edges":[]}
	for edge: Dictionary in plan.corridors:
		var route := {"id":edge.id,"from":edge.from,"to":edge.to,"points":edge.points.map(func(p):return Vector2(p)),"bridge":edge.bridge}
		layout.corridors.append(route)
		for cell: Vector2i in edge.floor:
			if not layout.cells[cell].edges.has(edge.id): layout.cells[cell].edges.append(edge.id)
	return true
