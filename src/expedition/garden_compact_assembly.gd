extends RefCounted
## Preserve the stop graph, then pack six stops into hall/wing/ear-room compounds.
const PLAN = preload("res://src/expedition/garden_blockout_plan.gd")


static func fit(source: RefCounted):
	var result: RefCounted
	for attempt in 3:
		result = build(source,attempt)
		if not result.assembly.has("error") and result.validate().ok: return result
	return result


static func build(source: RefCounted, attempt := 0):
	var began := Time.get_ticks_usec()
	var result = PLAN.new(); result.seed_value = source.seed_value; result.act = source.act
	result.layout_mode = "compact"; result.quarter_turns = source.quarter_turns
	result.nodes = source.nodes.duplicate(true); result.corridors = source.corridors.duplicate(true)
	var rng := RandomNumberGenerator.new(); rng.seed = hash("compact:%d:%d:%d" % [source.seed_value,source.act,attempt])
	var step := rng.randi_range(17,18)+attempt*2
	var gap := rng.randi_range(21,24)+attempt*3
	var width := gap+25
	var height := step*4+33
	result.bounds = Rect2i(0,0,width,height)
	var offsets: Array[int] = []
	for i in 5: offsets.append(rng.randi_range(-1,1))
	for node: Dictionary in result.nodes.values():
		node["doors"] = []; node.door_axis = "y"
		if node.id in ["start","boss"]:
			node.at = Vector2i(12+gap/2,height-6 if node.id=="start" else 5); node.extent = Vector2i(5,5) if node.id=="start" else Vector2i(11,5)
			node["role"] = "门厅" if node.id=="start" else "终庭"
			continue
		var bank := 0 if node.lane<2 else 1
		var group := int(node.row)/3
		var center := Vector2i(12+gap*bank+offsets[group],height-19-step*group)
		var inner: bool = node.lane in [1,2]
		var side := -1 if bank==0 else 1
		match int(node.row)%3:
			0,2:
				node.extent = Vector2i(7,5) if inner else Vector2i(5,3)
				node.at = center+Vector2i(0 if inner else side*6,5 if int(node.row)%3==0 else -5)
				node.role = ("正厅" if int(node.row)%3==0 else "后厅") if inner else ("前耳房" if int(node.row)%3==0 else "后耳房")
			1:
				node.extent = Vector2i(5,3); node.at = center+Vector2i((-side if inner else side)*5,0); node.role = "侧室"
		node.name = str(node.role)+" · "+PLAN.LABELS[node.kind]
	var compounds: Array = []
	for group in 5:
		for bank in 2:
			var center := Vector2i(12+gap*bank+offsets[group],height-19-step*group)
			result.banks.append({"rect":Rect2i(center-Vector2i(9,8),Vector2i(19,17)),"kind":"plants"})
			result.ponds.append(Rect2i(center-Vector2i(1,0),Vector2i(3,1)))
			var members: Array = result.nodes.values().filter(func(n):return n.row>=0 and n.row<15 and int(n.row)/3==group and (n.lane<2)==(bank==0)).map(func(n):return n.id)
			compounds.append({"members":members,"form":"合院" if members.size()==6 else "偏院"})
	for edge: Dictionary in result.corridors: edge.points = []
	result._rotate()
	var router = load("res://src/expedition/garden_compact_assembly.gd").new()
	var error: String = router._route(result)
	if not error.is_empty():
		result.assembly = {"error":error,"attempt":attempt}; return result
	result._raster()
	result.generation_ms = (Time.get_ticks_usec()-began)/1000.0
	var area: int = result.bounds.size.x*result.bounds.size.y
	var original: int = source.bounds.size.x*source.bounds.size.y
	result.assembly = {"attempt":attempt,"original_area":original,"area":area,"area_reduction":1-float(area)/original,"logical_edges_preserved":result.corridors.map(func(e):return e.id)==source.corridors.map(func(e):return e.id),"compounds":compounds}
	result.assembly["original_corridor_length"] = _length(source.corridors)
	result.assembly["corridor_length"] = _length(result.corridors)
	return result


static func _length(edges: Array) -> int:
	var total := 0
	for edge: Dictionary in edges:
		for i in range(1,edge.points.size()):
			var delta: Vector2i = edge.points[i]-edge.points[i-1]; total += absi(delta.x)+absi(delta.y)
	return total


var _plan: RefCounted
var _astar: AStarGrid2D
var _occupied := {}
var _reserved := {}
var _water := {}


func _route(plan: RefCounted) -> String:
	_plan = plan; _astar = AStarGrid2D.new(); _astar.region = plan.bounds
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER; _astar.update()
	for node: Dictionary in plan.nodes.values():
		var rect := Rect2i(Vector2i(node.at)-(Vector2i(node.extent)-Vector2i.ONE)/2,Vector2i(node.extent))
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y):
				var c := Vector2i(x,y); _occupied[c] = node.id; _astar.set_point_solid(c)
	for rect: Rect2i in plan.ponds:
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y):
				var c := Vector2i(x,y); _astar.set_point_solid(c); _water[c] = true
	var ordered: Array = plan.corridors.duplicate()
	ordered.sort_custom(func(a,b):
		var ap: int = 0 if a.from=="start" or a.to=="boss" else 1
		var bp: int = 0 if b.from=="start" or b.to=="boss" else 1
		if ap!=bp: return ap<bp
		return plan.nodes[a.from].at.distance_squared_to(plan.nodes[a.to].at)<plan.nodes[b.from].at.distance_squared_to(plan.nodes[b.to].at))
	for edge: Dictionary in ordered:
		if not _edge(edge): return "无法保持原连接："+str(edge.id)
	return ""


func _ports(node: Dictionary, flow: String) -> Array:
	var result: Array = []; var at := Vector2i(node.at); var half := (Vector2i(node.extent)-Vector2i.ONE)/2
	var opposite: Array = node.doors.filter(func(d):return d.flow!=flow)
	for delta: Vector2i in PLAN.DIRECTIONS:
		# Separate entrance and exit facades. A side room is a through-room,
		# never a dead-end that asks the player to leave through its entrance.
		if opposite.any(func(d):return d.normal==delta): continue
		var count: int = half.y-1 if delta.x!=0 else half.x-1
		for offset in range(-count,count+1):
			var cell := at+Vector2i(delta.x*half.x,delta.y*half.y)+(Vector2i(0,offset) if delta.x!=0 else Vector2i(offset,0))
			var outside := cell+delta
			if _plan.bounds.has_point(outside): result.append({"cell":cell,"normal":delta,"outside":outside})
	return result


func _edge(edge: Dictionary) -> bool:
	# Approaches to the same hall can share a real forecourt/port. Unrelated
	# connections keep a full tile of separation, so packing adds no crossings.
	for cell: Vector2i in _reserved:
		var unrelated: bool = _reserved[cell].any(func(old):return old.from not in [edge.from,edge.to] and old.to not in [edge.from,edge.to])
		_astar.set_point_solid(cell,unrelated or _water.has(cell))
	var a: Dictionary = _plan.nodes[edge.from]; var b: Dictionary = _plan.nodes[edge.to]
	var aa := _ports(a,"out"); var bb := _ports(b,"in"); var candidates: Array = []
	for start: Dictionary in aa:
		for end: Dictionary in bb:
			if start.outside==end.cell and end.outside==start.cell:
				_commit(edge,start,end,[]); return true
			if _occupied.has(start.outside) or _occupied.has(end.outside): continue
			if _astar.is_point_solid(start.outside) or _astar.is_point_solid(end.outside): continue
			var distance: int = absi(start.outside.x-end.outside.x)+absi(start.outside.y-end.outside.y)
			candidates.append({"start":start,"end":end,"score":distance})
	candidates.sort_custom(func(p,q):return p.score<q.score)
	for candidate: Dictionary in candidates.slice(0,32):
		var path := _astar.get_id_path(candidate.start.outside,candidate.end.outside)
		if path.is_empty(): continue
		_commit(edge,candidate.start,candidate.end,_straighten(path)); return true
	return false


func _straighten(path: Array[Vector2i]) -> Array[Vector2i]:
	# A* finds a valid shortest path but may alternate axes at every step.
	# Replace clear stretches by orthogonal runs with fewer bends. Every
	# replacement respects the same occupied/reserved cells as the original.
	if path.size()<4: return path
	var result: Array[Vector2i] = [path[0]]; var cursor := 0
	while cursor<path.size()-1:
		var changed := false
		for end in range(mini(path.size()-1,cursor+28),cursor+2,-1):
			var old_bends := _bend_count(path.slice(cursor,end+1))
			if old_bends<2: continue
			for x_first in [true,false]:
				var a := path[cursor]; var b := path[end]
				var via := Vector2i(b.x,a.y) if x_first else Vector2i(a.x,b.y)
				var line: Array[Vector2i] = [a]
				for target: Vector2i in [via,b]:
					var at := line[-1]
					var direction := Vector2i(signi(target.x-at.x),signi(target.y-at.y))
					while at!=target: at += direction; line.append(at)
				if line.any(func(cell):return not _plan.bounds.has_point(cell) or _astar.is_point_solid(cell)): continue
				result.append_array(line.slice(1)); cursor = end; changed = true; break
			if changed: break
		if not changed: cursor += 1; result.append(path[cursor])
	return result


static func _bend_count(points: Array) -> int:
	var count := 0
	for i in range(1,points.size()-1):
		if points[i]-points[i-1]!=points[i+1]-points[i]: count += 1
	return count


func _commit(edge: Dictionary, start: Dictionary, end: Dictionary, outside: Array) -> void:
	var a: Dictionary = _plan.nodes[edge.from]; var b: Dictionary = _plan.nodes[edge.to]
	for pair in [[a,start,"out"],[b,end,"in"]]:
		if not pair[0].doors.any(func(d):return d.cell==pair[1].cell and d.normal==pair[1].normal): pair[0].doors.append({"cell":pair[1].cell,"normal":pair[1].normal,"flow":pair[2]})
	var points: Array[Vector2i] = [a.at]
	points.append(Vector2i(start.cell.x,a.at.y)); points.append(start.cell)
	for c: Vector2i in outside: points.append(c)
	points.append(end.cell); points.append(Vector2i(end.cell.x,b.at.y)); points.append(b.at)
	var compact: Array[Vector2i] = []
	for c: Vector2i in points:
		if not compact.is_empty() and compact[-1]==c: continue
		while compact.size()>1 and (compact[-1].x==compact[-2].x and c.x==compact[-1].x or compact[-1].y==compact[-2].y and c.y==compact[-1].y): compact.pop_back()
		compact.append(c)
	edge.points = compact
	for c: Vector2i in outside:
		for offset: Vector2i in PLAN.DIRECTIONS+[Vector2i.ZERO]:
			var next := c+offset
			if _plan.bounds.has_point(next) and not _occupied.has(next):
				_astar.set_point_solid(next)
				if not _reserved.has(next): _reserved[next] = []
				_reserved[next].append(edge)
