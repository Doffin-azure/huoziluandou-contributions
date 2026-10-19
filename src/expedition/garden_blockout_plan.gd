extends RefCounted
## Seeded 55-stop spatial model. Floors, walls and navigation share this data.
## No run state, reward settlement, branch seals, models or gameplay RNG.
const VERSION := 2
const CHUNK := 8
const DIRECTIONS := [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
const LABELS := {"start":"起点","battle":"普通战","elite":"精英","event":"事件","rest":"火堆","shop":"商店","treasure":"宝藏","boss":"首领"}
const GLYPHS := {"start":"始","battle":"战","elite":"镇","event":"问","rest":"息","shop":"市","treasure":"藏","boss":"渊"}
var seed_value := 0
var act := 1
var quarter_turns := 0
var bounds := Rect2i()
var nodes := {}
var corridors: Array = []
var banks: Array = []
var cells := {} # Vector2i -> node ID; empty ID is a shared corridor.
var plots := {} # Raised, visibly bounded planting/rock beds; not traversable.
var walls: Array = []
var links := {}
var chunks := {}
var junctions: Array[Vector2i] = []
var generation_ms := 0.0
var layout_mode := "parallel"
var ponds: Array = []
var assembly := {}
var _wall_keys := {}


static func generate(value: int, act_number := 1):
	var result = load("res://src/expedition/garden_blockout_plan.gd").new()
	result.seed_value = value; result.act = act_number
	var began := Time.get_ticks_usec()
	result._generate()
	result.generation_ms = (Time.get_ticks_usec()-began)/1000.0
	return result


func _generate() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = hash("garden-blockout:%d:%d" % [seed_value,act])
	var content := RandomNumberGenerator.new(); content.seed = hash("garden-stops:%d:%d" % [seed_value,act])
	var lanes := [9,0,0,0]
	lanes[1] = lanes[0]+rng.randi_range(13,16)
	lanes[2] = lanes[1]+rng.randi_range(16,20)
	lanes[3] = lanes[2]+rng.randi_range(13,16)
	var width: int = lanes[3]+10
	var depths: Array[int] = [12]
	for i in 14: depths.append(depths[-1]+rng.randi_range(6,8))
	var height: int = depths[-1]+13
	bounds = Rect2i(0,0,width,height)
	var south := height-6
	var center := roundi((lanes[1]+lanes[2])*.5)
	_add_node("start","start",Vector2i(center,south),Vector2i(13,5),-1,-1,"入园门厅")
	var omitted: Array[int] = []
	for i in 15: omitted.append(i)
	_shuffle(omitted,rng); omitted.resize(7)
	var names := ["门前夹院","南岸花径","照壁书庭","枫下石庭","曲廊过院","临池前庭","碑廊夹庭","莲浦水院","藏字水榭","北岸石庭","松风侧院","后园书斋","镇碑前院","终庭外廊","息灯前庭"]
	var rows: Array = []
	for row in 15:
		var ids: Array[String] = []
		var absent := rng.randi_range(0,3) if omitted.has(row) else -1
		var kinds := _kinds(row); _shuffle(kinds,content)
		for lane in 4:
			if lane==absent: continue
			var id := "n%02d" % nodes.size()
			var kind: String = kinds[ids.size()]
			var size := Vector2i(9 if kind=="elite" else (5 if kind in ["event","rest"] and rng.randf()<.3 else 7),5 if kind in ["battle","elite"] else 3)
			var at := Vector2i(lanes[lane]+rng.randi_range(-1,1),south-8-(depths[row]-depths[0]))
			_add_node(id,kind,at,size,row,lane,str(names[row])+"·"+["西","西岸","东岸","东"][lane])
			ids.append(id)
		rows.append(ids)
	_add_node("boss","boss",Vector2i(center,4),Vector2i(13,5),15,-1,"终庭镇守")
	for id: String in rows[0]: _connect("start",id)
	var crossings: Array[int] = []
	for i in range(1,13): crossings.append(i)
	_shuffle(crossings,rng); crossings.resize(5)
	for row in 14:
		var before: Array = rows[row]; var after: Array = rows[row+1]
		for id: String in before: _connect(id,_nearest(id,after))
		for id: String in after:
			if not corridors.any(func(edge):return edge.to==id): _connect(_nearest(id,before),id)
		for bank in 2:
			var a := before.filter(func(id):return (nodes[id].lane<2)==(bank==0))
			var b := after.filter(func(id):return (nodes[id].lane<2)==(bank==0))
			if a.size()==2 and b.size()==2 and rng.randf()<.60:
				var pick := rng.randi_range(0,1); _connect(a[pick],b[1-pick])
		if crossings.has(row):
			var reverse := rng.randf()<.5
			var a := before.filter(func(id):return (nodes[id].lane<2)!=reverse)
			var b := after.filter(func(id):return (nodes[id].lane<2)==reverse)
			_connect(a[0] if reverse else a[-1],b[-1] if reverse else b[0],true)
	for id: String in rows[-1]: _connect(id,"boss")
	for group in 5:
		var top: int = nodes[rows[group*3+2][0]].at.y-3
		var bottom: int = nodes[rows[group*3][0]].at.y+3
		if group>0: bottom = roundi((nodes[rows[group*3-1][0]].at.y+nodes[rows[group*3][0]].at.y)*.5)
		if group<4: top = roundi((nodes[rows[group*3+2][0]].at.y+nodes[rows[group*3+3][0]].at.y)*.5)+1
		var west: int = lanes[1]+rng.randi_range(0,4)
		var east: int = lanes[2]-rng.randi_range(0,4)
		banks.append({"rect":Rect2i(3,top,west-2,bottom-top+1),"kind":"rocks" if group==2 else "plants"})
		banks.append({"rect":Rect2i(east,top,width-east-3,bottom-top+1),"kind":"plants"})
	quarter_turns = rng.randi_range(0,3)
	_rotate()
	_raster()


func _kinds(row: int) -> Array:
	if row==0: return ["battle","battle","battle","battle"]
	if row==8: return ["treasure","treasure","treasure","treasure"]
	if row==14: return ["rest","rest","rest","rest"]
	var options := [["event","battle","shop","battle"],["battle","event","battle","rest"],["event","battle","event","shop"],["battle","rest","event","battle"],["elite","event","battle","shop"],["battle","event","elite","rest"],["shop","battle","rest","event"],["battle","event","elite","battle"],["rest","elite","event","battle"],["event","shop","battle","event"],["elite","battle","rest","event"]]
	var index: int = [0,0,1,2,3,4,5,6,0,7,8,9,10,7,0][row]
	return options[index].duplicate()


func _add_node(id: String, kind: String, at: Vector2i, extent: Vector2i, row: int, lane: int, title: String) -> void:
	nodes[id] = {"id":id,"kind":kind,"at":at,"extent":extent,"row":row,"lane":lane,"name":title,"number":nodes.size()+1,"door_axis":"y"}


func _nearest(id: String, candidates: Array) -> String:
	var matching := candidates.filter(func(other):return (nodes[other].lane<2)==(nodes[id].lane<2))
	matching.sort_custom(func(a,b):return absi(nodes[a].at.x-nodes[id].at.x)<absi(nodes[b].at.x-nodes[id].at.x))
	return matching[0]


func _connect(from: String, to: String, bridge := false) -> void:
	if corridors.any(func(edge):return edge.from==from and edge.to==to): return
	var a: Vector2i = nodes[from].at; var b: Vector2i = nodes[to].at
	var middle := roundi((a.y+b.y)*.5)
	var points: Array[Vector2i] = []
	for p in [a,Vector2i(a.x,middle),Vector2i(b.x,middle),b]:
		if points.is_empty() or points[-1]!=p: points.append(p)
	corridors.append({"id":from+">"+to,"from":from,"to":to,"points":points,"bridge":bridge})


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size()-1,0,-1):
		var pick := rng.randi_range(0,i); var previous: Variant = values[i]; values[i] = values[pick]; values[pick] = previous


func _rotate() -> void:
	for node: Dictionary in nodes.values():
		node.at = Vector2i(_turn(Vector2(node.at)))
		if quarter_turns%2==1: node.extent = Vector2i(node.extent.y,node.extent.x); node.door_axis = "x"
	for edge: Dictionary in corridors:
		for i in edge.points.size(): edge.points[i] = Vector2i(_turn(Vector2(edge.points[i])))
	for bank: Dictionary in banks:
		var rect: Rect2i = bank.rect
		var a := _turn(Vector2(rect.position)); var b := _turn(Vector2(rect.end-Vector2i.ONE))
		bank.rect = Rect2i(Vector2i(a.min(b)),Vector2i((a-b).abs())+Vector2i.ONE)
	for i in ponds.size():
		var rect: Rect2i = ponds[i]
		var a := _turn(Vector2(rect.position)); var b := _turn(Vector2(rect.end-Vector2i.ONE))
		ponds[i] = Rect2i(Vector2i(a.min(b)),Vector2i((a-b).abs())+Vector2i.ONE)
	if quarter_turns%2==1: bounds = Rect2i(Vector2i.ZERO,Vector2i(bounds.size.y,bounds.size.x))


func _turn(p: Vector2) -> Vector2:
	match quarter_turns:
		1: return Vector2(bounds.size.y-1-p.y,p.x)
		2: return Vector2(bounds.size.x-1-p.x,bounds.size.y-1-p.y)
		3: return Vector2(p.y,bounds.size.x-1-p.x)
	return p


func node_rect(node: Dictionary) -> Rect2:
	return Rect2(Vector2(node.at)-Vector2(node.extent)*.5,Vector2(node.extent))


func _raster() -> void:
	cells.clear(); plots.clear(); walls.clear(); links.clear(); chunks.clear(); junctions.clear(); _wall_keys.clear()
	for node: Dictionary in nodes.values():
		var rect := Rect2i(Vector2i(node.at)-(Vector2i(node.extent)-Vector2i.ONE)/2,Vector2i(node.extent))
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y): cells[Vector2i(x,y)] = node.id
		_node_walls(node)
	for edge: Dictionary in corridors:
		edge["floor"] = []
		for i in range(1,edge.points.size()):
			var a: Vector2i = edge.points[i-1]; var b: Vector2i = edge.points[i]
			var delta := Vector2i(signi(b.x-a.x),signi(b.y-a.y))
			for j in absi(b.x-a.x)+absi(b.y-a.y)+1:
				var c := a+delta*j
				if not cells.has(c): cells[c] = ""
				if edge.floor.is_empty() or edge.floor[-1]!=c: edge.floor.append(c)
	var blocked := {}
	# Build blocked grid edges from the rendered wall segments, including walls
	# beside shared corridor intersections. Open doorways never add a blocker.
	for wall: Dictionary in walls:
		var a: Vector2 = wall.a; var b: Vector2 = wall.b
		var count := roundi(a.distance_to(b))
		for i in count:
			var middle := a.lerp(b,(i+.5)/count)
			var delta := Vector2(.5,0) if is_equal_approx(a.x,b.x) else Vector2(0,.5)
			var from := Vector2i((middle-delta).round()); var to := Vector2i((middle+delta).round())
			if not blocked.has(from): blocked[from] = []
			if not blocked.has(to): blocked[to] = []
			blocked[from].append(to); blocked[to].append(from)
	for c: Vector2i in cells:
		var neighbours: Array[Vector2i] = []
		for delta: Vector2i in DIRECTIONS:
			var next := c+delta
			if cells.has(next) and not blocked.get(c,[]).has(next): neighbours.append(next)
		links[c] = neighbours
		if neighbours.size()>=3 and str(cells[c]).is_empty(): junctions.append(c)
	for bank: Dictionary in banks:
		var rect: Rect2i = bank.rect
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y):
				var c := Vector2i(x,y)
				if not cells.has(c): plots[c] = bank.kind
	for rect: Rect2i in ponds:
		for x in range(rect.position.x,rect.end.x):
			for y in range(rect.position.y,rect.end.y):
				var c := Vector2i(x,y)
				if not cells.has(c): plots[c] = "water"
	_index_chunks()


func _node_walls(node: Dictionary) -> void:
	var rect := node_rect(node); var at := Vector2(node.at)
	if node.has("doors"):
		var box := Rect2i(Vector2i(node.at)-(Vector2i(node.extent)-Vector2i.ONE)/2,Vector2i(node.extent))
		for x in range(box.position.x,box.end.x):
			for y in [box.position.y,box.end.y-1]:
				var normal := Vector2i.UP if y==box.position.y else Vector2i.DOWN
				if node.doors.any(func(door):return door.cell==Vector2i(x,y) and door.normal==normal): continue
				var point := Vector2(x,y)+Vector2(normal)*.5; _wall(point-Vector2(.5,0),point+Vector2(.5,0),node.id)
		for y in range(box.position.y,box.end.y):
			for x in [box.position.x,box.end.x-1]:
				var normal := Vector2i.LEFT if x==box.position.x else Vector2i.RIGHT
				if node.doors.any(func(door):return door.cell==Vector2i(x,y) and door.normal==normal): continue
				var point := Vector2(x,y)+Vector2(normal)*.5; _wall(point-Vector2(0,.5),point+Vector2(0,.5),node.id)
		return
	if node.door_axis=="y":
		for y in [rect.position.y,rect.end.y]:
			_wall(Vector2(rect.position.x,y),Vector2(at.x-.5,y),node.id)
			_wall(Vector2(at.x+.5,y),Vector2(rect.end.x,y),node.id)
		for x in [rect.position.x,rect.end.x]: _wall(Vector2(x,rect.position.y),Vector2(x,rect.end.y),node.id)
	else:
		for x in [rect.position.x,rect.end.x]:
			_wall(Vector2(x,rect.position.y),Vector2(x,at.y-.5),node.id)
			_wall(Vector2(x,at.y+.5),Vector2(x,rect.end.y),node.id)
		for y in [rect.position.y,rect.end.y]: _wall(Vector2(rect.position.x,y),Vector2(rect.end.x,y),node.id)


func _wall(a: Vector2, b: Vector2, owner: String) -> void:
	if a.distance_to(b)<=.01: return
	var key := str(a.min(b))+":"+str(a.max(b))
	if _wall_keys.has(key): return
	_wall_keys[key] = true; walls.append({"a":a,"b":b,"owner":owner})


static func chunk_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x/CHUNK),floori(point.y/CHUNK))


func _chunk(c: Vector2i) -> Dictionary:
	var key := chunk_at(Vector2(c))
	if not chunks.has(key): chunks[key] = {"floor":[],"plots":[],"walls":[],"nodes":[]}
	return chunks[key]


func _index_chunks() -> void:
	for c: Vector2i in cells: _chunk(c).floor.append(c)
	for c: Vector2i in plots: _chunk(c).plots.append(c)
	for node: Dictionary in nodes.values(): _chunk(node.at).nodes.append(node.id)
	for wall: Dictionary in walls:
		var count := roundi(wall.a.distance_to(wall.b))
		for i in count:
			var a: Vector2 = wall.a.lerp(wall.b,float(i)/count)
			var b: Vector2 = wall.a.lerp(wall.b,float(i+1)/count)
			_chunk(Vector2i(((a+b)*.5).floor())).walls.append({"a":a,"b":b,"owner":wall.owner})


func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not cells.has(from) or not cells.has(to): return []
	var previous := {from:from}; var queue: Array[Vector2i] = [from]; var cursor := 0
	while cursor<queue.size() and not previous.has(to):
		var c := queue[cursor]; cursor += 1
		for next: Vector2i in links.get(c,[]):
			if not previous.has(next): previous[next] = c; queue.append(next)
	if not previous.has(to): return []
	var result: Array[Vector2i] = [to]
	while result[-1]!=from: result.append(previous[result[-1]])
	result.reverse(); return result


func validate() -> Dictionary:
	var errors: Array[String] = []
	if nodes.size()!=55: errors.append("节点数不是55")
	var specs: Array = nodes.values()
	for i in specs.size():
		var node: Dictionary = specs[i]
		if not bounds.has_point(node.at) or not cells.has(node.at): errors.append("落脚点越界："+str(node.id))
		for j in range(i+1,specs.size()):
			var margin := .0 if layout_mode=="compact" else .2
			if node_rect(node).grow(margin).intersects(node_rect(specs[j]).grow(margin)): errors.append("院落净空重叠：%s / %s" % [node.id,specs[j].id])
	for edge: Dictionary in corridors:
		for i in range(1,edge.points.size()):
			var a := Vector2(edge.points[i-1]); var b := Vector2(edge.points[i])
			if a.x!=b.x and a.y!=b.y: errors.append("通路非四向："+str(edge.id))
			for node: Dictionary in specs:
				if node.id in [edge.from,edge.to]: continue
				var box := node_rect(node).grow(.0 if layout_mode=="compact" else .1)
				var hit := box.intersects(Rect2(a.min(b), (a-b).abs()).grow(.01))
				if hit: errors.append("道路穿过无关院落：%s / %s" % [edge.id,node.id])
		for i in range(1,edge.floor.size()):
			if not links.get(edge.floor[i-1],[]).has(edge.floor[i]): errors.append("门桥或转角被墙切断："+str(edge.id)); break
	var queue: Array = [Vector2i(nodes.start.at)]; var reached := {queue[0]:true}; var cursor := 0
	while cursor<queue.size():
		var c: Vector2i = queue[cursor]; cursor += 1
		for next: Vector2i in links.get(c,[]):
			if not reached.has(next): reached[next] = true; queue.append(next)
	for node: Dictionary in specs:
		if not reached.has(node.at): errors.append("节点不可达："+str(node.id))
	if reached.size()!=cells.size(): errors.append("存在孤立可行走地砖")
	for c: Vector2i in links:
		for next: Vector2i in links[c]:
			if absi(c.x-next.x)+absi(c.y-next.y)!=1 or not links.get(next,[]).has(c): errors.append("通行边不是四向双向边")
	for wall: Dictionary in walls:
		var count := roundi(wall.a.distance_to(wall.b))
		for i in count:
			var midpoint: Vector2 = wall.a.lerp(wall.b,(i+.5)/count)
			var normal := Vector2(.5,0) if is_equal_approx(wall.a.x,wall.b.x) else Vector2(0,.5)
			var from := Vector2i((midpoint-normal).round()); var to := Vector2i((midpoint+normal).round())
			if links.get(from,[]).has(to): errors.append("通行边穿过实体墙："+str(wall.owner))
	for rect: Rect2i in ponds:
		for c: Vector2i in cells:
			if rect.has_point(c): errors.append("地面侵入庭院莲池")
	return {"ok":errors.is_empty(),"errors":errors,"nodes":nodes.size(),"corridors":corridors.size(),"floor_cells":cells.size(),"chunks":chunks.size(),"junctions":junctions.size(),"generation_ms":generation_ms,"seed":seed_value,"act":act,"quarter_turns":quarter_turns,"mode":layout_mode,"assembly":assembly}


func to_data() -> Dictionary:
	var data := {"version":VERSION,"seed":seed_value,"act":act,"quarter_turns":quarter_turns,"bounds":[bounds.size.x,bounds.size.y],"nodes":nodes.values().map(func(n):return {"id":n.id,"kind":n.kind,"name":n.name,"row":n.row,"lane":n.lane,"number":n.number,"at":[n.at.x,n.at.y],"extent":[n.extent.x,n.extent.y],"door_axis":n.door_axis}),"corridors":corridors.map(func(e):return {"id":e.id,"from":e.from,"to":e.to,"points":e.points.map(func(p):return [p.x,p.y]),"bridge":e.bridge}),"banks":banks.map(func(b):return {"rect":[b.rect.position.x,b.rect.position.y,b.rect.size.x,b.rect.size.y],"kind":b.kind}),"mode":layout_mode,"assembly":assembly,"ponds":ponds.map(func(r):return [r.position.x,r.position.y,r.size.x,r.size.y])}
	for node: Dictionary in data.nodes:
		var original: Dictionary = nodes[node.id]
		if original.has("doors"): node["doors"] = original.doors.map(func(d):return {"cell":[d.cell.x,d.cell.y],"normal":[d.normal.x,d.normal.y],"flow":d.get("flow","")})
		if original.has("role"): node["role"] = original.role
	return data


static func from_data(data: Dictionary):
	if int(data.get("version",0)) not in [1,VERSION]: return null
	var result = load("res://src/expedition/garden_blockout_plan.gd").new()
	result.seed_value = int(data.seed); result.act = int(data.act); result.quarter_turns = int(data.quarter_turns)
	result.bounds = Rect2i(0,0,int(data.bounds[0]),int(data.bounds[1]))
	result.layout_mode = str(data.get("mode","parallel")); result.assembly = data.get("assembly",{}).duplicate(true)
	for rect in data.get("ponds",[]): result.ponds.append(Rect2i(rect[0],rect[1],rect[2],rect[3]))
	for raw: Dictionary in data.nodes:
		var node := raw.duplicate(true); node.at = Vector2i(raw.at[0],raw.at[1]); node.extent = Vector2i(raw.extent[0],raw.extent[1]); result.nodes[node.id] = node
		if node.has("doors"): node.doors = raw.doors.map(func(d):return {"cell":Vector2i(d.cell[0],d.cell[1]),"normal":Vector2i(d.normal[0],d.normal[1]),"flow":d.get("flow","")})
	for raw: Dictionary in data.corridors:
		var edge := raw.duplicate(true); edge.points = raw.points.map(func(p):return Vector2i(p[0],p[1])); result.corridors.append(edge)
	for raw: Dictionary in data.banks:
		result.banks.append({"rect":Rect2i(raw.rect[0],raw.rect[1],raw.rect[2],raw.rect[3]),"kind":raw.kind})
	result._raster(); return result
