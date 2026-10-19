extends RefCounted
## One authored whole garden; architecture is independent of gameplay node zones.
const PATH := "res://assets/expedition/layouts/mochi_garden_v1.json"
static var _source := {}


static func source() -> Dictionary:
	if _source.is_empty():
		_source = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _source


static func rect(value: Array) -> Rect2:
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))


static func vector(value: Array) -> Vector2: return Vector2(float(value[0]),float(value[1]))


static func polygon(value: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in value: result.append(vector(p))
	return result


static func graph(seed_value: int, act: int) -> Dictionary:
	return graph_for(source(),seed_value,act)


static func graph_for(data: Dictionary, seed_value: int, act: int) -> Dictionary:
	var result := {"schema":1,"seed":seed_value,"act":act,"layout_version":5,"authored_site":data.id,"rooms":{},"edges":[],"groups":[],"start":"start","boss":"boss"}
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value+act*1009
	for id: String in data.nodes:
		var node: Dictionary = data.nodes[id]
		result.rooms[id] = {"id":id,"kind":node.kind,"center":vector(node.at),"forward":Vector2.UP,"next":[],"previous":[],"content_seed":rng.randi_range(1,1<<30)}
	for raw: Dictionary in data.edges:
		result.rooms[raw.from].next.append(raw.to)
		result.rooms[raw.to].previous.append(raw.from)
		result.edges.append({"id":raw.from+">"+raw.to,"from":raw.from,"to":raw.to})
	for raw: Dictionary in data.groups:
		var group: Dictionary = raw.duplicate(true)
		group.id = int(group.id); result.groups.append(group)
		for b in group.branches.size():
			for id: String in group.branches[b]:
				result.rooms[id]["group"] = group.id; result.rooms[id]["branch"] = b
	return result


static func water_distance(p: Vector2, site: Dictionary = {}) -> float:
	var poly := polygon((source() if site.is_empty() else site).pond_polygon)
	var distance := INF
	for i in poly.size(): distance = minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,poly[i],poly[(i+1)%poly.size()])))
	return distance if Geometry2D.is_point_in_polygon(p,poly) else -distance


static func is_deck(p: Vector2, site: Dictionary = {}) -> bool:
	var data := source() if site.is_empty() else site
	for value in data.bridges+data.platforms:
		if rect(value).has_point(p): return true
	return false


static func wall_at(p: Vector2, clearance := .24, site: Dictionary = {}) -> bool:
	for path in (source() if site.is_empty() else site).walls:
		for i in path.size()-1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p,vector(path[i]),vector(path[i+1])))<clearance: return true
	return false


static func building_openings(data: Dictionary, house: Dictionary) -> Dictionary:
	var box := rect(house.rect)
	var openings := {"N":[],"E":[],"S":[],"W":[]}
	var exterior: Dictionary = house.get("exterior_openings",{"S":[0.0]} if house.id=="gatehouse" else {})
	for side: String in exterior: openings[side].append_array(exterior[side])
	for corridor: Dictionary in data.edges:
		for i in corridor.points.size()-1:
			var a := vector(corridor.points[i]); var b := vector(corridor.points[i+1])
			for side in openings:
				var horizontal: bool = side in ["N","S"]
				var edge := box.position.y if side=="N" else (box.end.y if side=="S" else (box.position.x if side=="W" else box.end.x))
				var da := a.y if horizontal else a.x; var db := b.y if horizontal else b.x
				if is_equal_approx(da,db) or (da-edge)*(db-edge)>0: continue
				var at := a.lerp(b,(edge-da)/(db-da))
				var along := at.x-box.get_center().x if horizontal else at.y-box.get_center().y
				if absf(along)>(box.size.x if horizontal else box.size.y)*.5+.01: continue
				if not openings[side].any(func(value):return absf(value-along)<.4): openings[side].append(along)
	return openings


static func building_facades(data: Dictionary) -> Array:
	var result: Array = []
	for house: Dictionary in data.buildings:
		if house.id in ["south_gallery","turn_gallery","treasure_pavilion","last_rest"]: continue
		var box := rect(house.rect); var openings := building_openings(data,house)
		for side in openings:
			var horizontal: bool = side in ["N","S"]
			var length := box.size.x if horizontal else box.size.y
			var cuts: Array = openings[side].duplicate(); cuts.sort(); cuts.append(length*.5+.85)
			var cursor := -length*.5
			for cut: float in cuts:
				var end := minf(cut-.85,length*.5)
				if end-cursor>.08:
					var center := box.get_center()
					var at := Vector2(cursor,-box.size.y*.5 if side=="N" else box.size.y*.5) if horizontal else Vector2(-box.size.x*.5 if side=="W" else box.size.x*.5,cursor)
					var to := Vector2(end,at.y) if horizontal else Vector2(at.x,end)
					result.append([[center.x+at.x,center.y+at.y],[center.x+to.x,center.y+to.y]])
				cursor = maxf(cursor,cut+.85)
	return result


static func build(layout: RefCounted, route_graph: Dictionary) -> bool:
	var data: Dictionary = route_graph.get("garden_site",source())
	layout.walk_step = float(data.get("walk_step",.25))
	layout.grid_origin = vector(data.get("grid_origin",[0,0]))
	layout.site = data
	layout.rooms.clear(); layout.cells.clear(); layout.corridors.clear(); layout.clusters.clear()
	layout.bounds = rect(data.bounds).grow(1)
	layout.error = ""
	for id: String in route_graph.rooms:
		var node: Dictionary = data.nodes[id]
		var box := rect(node.zones[0])
		for value in node.zones: box = box.merge(rect(value))
		var at := vector(node.at)
		var frame := Rect2(at-Vector2(5.5,4.5),Vector2(11,9))
		if id=="boss": frame = box.grow(1)
		layout.rooms[id] = {"route_id":id,"kind":node.kind,"name":node.name,"bounds":box,"frame_bounds":frame,"transform":Transform2D.IDENTITY,"floor_size":box.size,"stand":at,"stand_cell":layout.cell(at),"props":[],"ponds":[],"edge_ports":{},"input":{},"output":{}}
		for value in node.zones: _raster(layout,rect(value),"rooms",id)
	for raw: Dictionary in data.edges:
		var corridor := {"id":raw.from+">"+raw.to,"from":raw.from,"to":raw.to,"points":[]}
		for p in raw.points: corridor.points.append(vector(p))
		layout.corridors.append(corridor)
		for value in raw.get("passage_zones",[]): _raster(layout,rect(value),"edges",corridor.id)
		for i in corridor.points.size()-1:
			_raster(layout,Rect2(corridor.points[i],Vector2.ZERO).expand(corridor.points[i+1]).grow(.60),"edges",corridor.id)
	# There is one paved surface. It is also the exact allowed movement mask;
	# planted soil remains visibly different and is not a shortcut between nodes.
	for cell in layout.cells.keys():
		var p: Vector2 = layout.point(cell)
		if wall_at(p,.24,data) or _obstacle_at(p,data) or (water_distance(p,data)>-.12 and not is_deck(p,data)): layout.cells.erase(cell)
	for id: String in layout.rooms:
		var room: Dictionary = layout.rooms[id]
		room.stand_cell = layout.nearest(room.stand,id)
		if not layout.cells.has(room.stand_cell): layout.error = "节点没有安全落脚点："+id; return false
	if layout.walk_step>=1:
		for cell: Vector2i in layout.cells:
			layout.links[cell] = []
			for direction: Vector2i in layout.DIRECTIONS:
				var next := cell+direction
				if not layout.cells.has(next): continue
				var clear := true
				for fraction in [.25,.5,.75]:
					var p: Vector2 = layout.point(cell).lerp(layout.point(next),fraction)
					if wall_at(p,.18,data) or _obstacle_at(p,data) or (water_distance(p,data)>-.10 and not is_deck(p,data)): clear = false; break
				if clear: layout.links[cell].append(next)
	return true


static func _obstacle_at(p: Vector2, site: Dictionary) -> bool:
	for face: Array in site.get("facades",[]):
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,vector(face[0]),vector(face[1])))<.18: return true
	for span: Dictionary in site.bridge_spans:
		var local := (p-vector(span.at)).rotated(-float(span.turn))
		if local.x>-.05 and local.x<float(span.length)+.05 and absf(local.y)<.8 and absf(local.y)>.34: return true
	for raw: Dictionary in site.buildings:
		var box := rect(raw.rect)
		for corner in [box.position,box.end,Vector2(box.end.x,box.position.y),Vector2(box.position.x,box.end.y)]:
			if p.distance_to(corner)<.22: return true
	for raw in site.trees:
		if p.distance_to(Vector2(float(raw[0]),float(raw[1])))<.25: return true
	for prop: Dictionary in site.get("props",[]):
		var half := Vector2(.24,.22)*float(prop.scale)+Vector2.ONE*.12
		var local := (p-vector(prop.at)).rotated(-float(prop.get("turn",0.0)))
		if prop.asset=="tomb":
			if Rect2(-half,half*2).has_point(local): return true
		else:
			var spec: Dictionary = preload("res://src/expedition/room_interior_assets.gd").MODELS.get(prop.asset,{})
			half = Vector2(spec.get("half",Vector2(.3,.3)))*float(prop.scale)+Vector2.ONE*.10
			if Rect2(-half,half*2).has_point(local): return true
	for screen: Dictionary in site.get("screens",[]):
		var local := (p-vector(screen.at)).rotated(-float(screen.turn))
		var half := Vector2(1.9,.4)*float(screen.scale)+Vector2.ONE*.1
		if Rect2(-half,half*2).has_point(local): return true
	# The square pavilion's two side benches and back rail remain solid while
	# its floor is flush with the site, matching its actual production geometry.
	for landmark: Dictionary in site.landmarks:
		var local := (p-vector(landmark.at)).rotated(-float(landmark.turn))
		for box: Rect2 in preload("res://src/expedition/room_interior_assets.gd").local_blocks(landmark.asset):
			if Rect2(box.position*float(landmark.scale),box.size*float(landmark.scale)).grow(.1).has_point(local): return true
	return false


static func _raster(layout: RefCounted, box: Rect2, key: String, id: String) -> void:
	var step: float = layout.walk_step
	for x in range(floori((box.position.x-layout.grid_origin.x)/step),ceili((box.end.x-layout.grid_origin.x)/step)+1):
		for y in range(floori((box.position.y-layout.grid_origin.y)/step),ceili((box.end.y-layout.grid_origin.y)/step)+1):
			var cell := Vector2i(x,y)
			if not box.has_point(layout.point(cell)): continue
			if not layout.cells.has(cell): layout.cells[cell] = {"rooms":[],"edges":[]}
			if not layout.cells[cell][key].has(id): layout.cells[cell][key].append(id)
