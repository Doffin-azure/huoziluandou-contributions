extends RefCounted
## Seeded garden grammar: shared architectural bands, connected water, variable
## branch stops and encounters. The resulting site is saved, never re-rolled.
const PLAN = preload("res://src/expedition/authored_garden_plan.gd")
const X := [3.0,10.0,24.7,28.0,32.3,42.8,53.0]
const Y := [2.0,5.6,12.0,18.0,24.1,30.3,35.0,45.8]
const LABELS := {"battle":"普通战","elite":"精英","event":"事件","shop":"商店","treasure":"宝藏","rest":"火堆"}
var x_to: Array = []
var y_to: Array = []
var rotation := 0.0
var offset := Vector2.ZERO


static func generate(seed_value: int, act: int, attempt := 0) -> Dictionary:
	var builder = load("res://src/expedition/random_garden_plan.gd").new()
	return builder._generate(seed_value,act,attempt)


func _generate(seed_value: int, act: int, attempt: int) -> Dictionary:
	var data: Dictionary = PLAN.source().duplicate(true)
	var rng := RandomNumberGenerator.new(); rng.seed = hash("garden:%d:%d:%d" % [seed_value,act,attempt])
	x_to = _bands(X,rng,attempt>=6); y_to = _bands(Y,rng,attempt>=6)
	rotation = float(rng.randi_range(0,3))*PI*.5
	var minimum := Vector2(INF,INF)
	for p in [Vector2(3,2),Vector2(53,2),Vector2(53,45.8),Vector2(3,45.8)]: minimum = minimum.min(_point(p))
	offset = Vector2(3,3)-minimum
	# The northern water tongue leaves one complete dry tile below the last
	# pavilion's exit; the old sub-tile sliver was not a usable grid passage.
	for p: Array in data.pond_polygon:
		if float(p[1])<13 and float(p[0])>24: p[1] = 13.0
	# Shore variation is restricted to the open western garden; the narrow
	# east-bank lanes and water-pavilion landings keep their required clearances.
	if attempt<6:
		for p: Array in data.pond_polygon:
			if float(p[0])<23.0:
				p[0] = float(p[0])+rng.randf_range(-.65,.65)
				p[1] = float(p[1])+rng.randf_range(-.45,.45)
	var content_rng := RandomNumberGenerator.new(); content_rng.seed = hash("garden-nodes:%d:%d" % [seed_value,act])
	var patio := PLAN.rect(data.nodes.g0_b0_1.zones[0]).grow(1.0)
	data.nodes.g0_b0_1.zones = [[patio.position.x,patio.position.y,patio.size.x,patio.size.y]]
	_assign_nodes(data,content_rng)
	var battle_ids: Array = data.nodes.keys().filter(func(id): return data.nodes[id].kind in ["battle","elite","boss"])
	_add_event_stops(data)
	# Every coordinate follows the same monotone mapping. Shared walls, pond
	# edges and galleries therefore stay joined instead of drifting per room.
	for node: Dictionary in data.nodes.values():
		node.at = _pair(_point(PLAN.vector(node.at)).round())
		for i in node.zones.size(): node.zones[i] = _rect(node.zones[i])
		if node.get("corridor_stop",false):
			var at := PLAN.vector(node.at)
			node.zones = [[at.x-.49,at.y-.49,.98,.98]]
	for edge: Dictionary in data.edges:
		edge.points = _path(edge.points,1.0)
		for i in edge.get("passage_zones",[]).size(): edge.passage_zones[i] = _rect(edge.passage_zones[i])
	for key in ["walls","galleries","scenic_paths","rockeries"]:
		for i in data[key].size(): data[key][i] = _path(data[key][i],1.0 if key=="galleries" else .5)
	data.pond_polygon = _path(data.pond_polygon)
	for raw: Dictionary in data.buildings:
		raw.rect = _rect(raw.rect,true)
		if raw.id=="gatehouse": raw["exterior_openings"] = {(["S","W","N","E"])[roundi(rotation/(PI*.5))]:[0.0]}
	for key in ["bridges","platforms"]:
		for i in data[key].size(): data[key][i] = _rect(data[key][i])
	for raw: Array in data.trees:
		var at := _point(Vector2(float(raw[0]),float(raw[1])))
		raw[0] = at.x; raw[1] = at.y
		# Independent decoration RNG does not advance combat/reward randomness.
		raw[2] = float(raw[2])*rng.randf_range(.86,1.08)
		var species := rng.randf()
		raw[3] = "maple" if species<.4 else ("pine" if species<.78 else ("bare" if species<.92 else "willow"))
	for key in ["props","landmarks","screens"]:
		for raw: Dictionary in data[key]:
			raw.at = _pair(_point(PLAN.vector(raw.at)).snapped(Vector2.ONE*(1.0 if key=="landmarks" else .5)))
			raw["turn"] = float(raw.get("turn",0.0))+rotation
	for span: Dictionary in data.bridge_spans:
		var original := PLAN.vector(span.at)
		span.at = _pair(_point(original).round())
		span.length = _point(original+Vector2(float(span.length),0)).round().distance_to(PLAN.vector(span.at))
		span.turn = rotation
	data.lotus_centers = _path(data.lotus_centers)
	data.bounds = _rect(data.bounds)
	for gate: Dictionary in data.gates:
		gate.at = _pair(_point(PLAN.vector(gate.at)))
		if roundi(rotation/(PI*.5))%2==1: gate.axis = "v" if gate.axis=="h" else "h"
	_decorate(data)
	_reserve_paths(data)
	data["facades"] = PLAN.building_facades(data)
	data["id"] = "seeded_garden_v2"; data["status"] = "seeded whole-tile garden"
	data["walk_step"] = 1.0; data["grid_origin"] = [0,0]
	data["generation"] = {"version":2,"seed":seed_value,"act":act,"attempt":attempt,"quarter_turns":roundi(rotation/(PI*.5)),"x_bands":x_to,"y_bands":y_to,"battle_nodes":battle_ids}
	var graph := PLAN.graph_for(data,seed_value,act)
	graph["layout_version"] = 7; graph["garden_site"] = data
	graph["layout_kind"] = "random_garden"
	return graph


func _assign_nodes(data: Dictionary, rng: RandomNumberGenerator) -> void:
	# Alternatives contrast risk with a service; do not make both doors identical.
	var early := [["battle","rest","battle","event"],["battle","event","battle","treasure"],["battle","rest","event","battle"]]
	var middle := [["shop","event","event","elite"],["event","elite","shop","event"],["shop","battle","event","elite"],["elite","event","event","shop"]]
	var late := [["elite","event","battle"],["elite","battle","event"],["treasure","battle","elite"]]
	var profiles: Array = [early[rng.randi_range(0,early.size()-1)],middle[rng.randi_range(0,middle.size()-1)],late[rng.randi_range(0,late.size()-1)]]
	for g in 3:
		var index := 0
		for branch: Array in data.groups[g].branches:
			for id: String in branch:
				data.nodes[id].kind = profiles[g][index]; index += 1
	# Bypass a stop by converting its whole footprint into the same connecting
	# lane. The house remains scenery; no invisible gameplay node survives.
	if rng.randf()<.55: _bypass(data,"g0_b1_1" if data.nodes.g0_b1_1.kind=="event" else "g0_b0_1")
	var middle_optional := "g1_b0_1" if data.nodes.g1_b0_1.kind=="event" else "g1_b1_1"
	if data.nodes[middle_optional].kind!="event": middle_optional = "g1_b1_0"
	if rng.randf()<.6: _bypass(data,middle_optional)
	if rng.randf()<.45: _bypass(data,"g2_b1_1")
	var names := {"g0_b0_0":"沿池南廊","g0_b1_0":"南侧夹院","g0_b1_1":"问字轩","g1_b0_0":"东侧前廊","g1_b0_1":"东书斋前院","g1_b1_1":"碑堂夹庭","g2_b0_0":"镇碑堂前庭"}
	for id: String in names:
		if data.nodes.has(id): data.nodes[id].name = names[id]
	for group: Dictionary in data.groups:
		group.options = []
		for branch: Array in group.branches:
			var parts: Array = []
			for id: String in branch: parts.append(LABELS[data.nodes[id].kind])
			group.options.append(" → ".join(parts))


func _bypass(data: Dictionary, id: String) -> void:
	if not data.nodes.has(id): return
	var incoming: Dictionary = {}; var outgoing: Dictionary = {}
	for edge: Dictionary in data.edges:
		if edge.to==id: incoming = edge
		if edge.from==id: outgoing = edge
	if incoming.is_empty() or outgoing.is_empty(): return
	var replacement := incoming.duplicate(true)
	replacement.to = outgoing.to
	replacement.points.append_array(outgoing.points.slice(1))
	replacement["passage_zones"] = data.nodes[id].zones.duplicate(true)
	data.edges.erase(incoming); data.edges.erase(outgoing); data.edges.append(replacement)
	for group: Dictionary in data.groups:
		for branch: Array in group.branches: branch.erase(id)
	data.nodes.erase(id)


func _bands(source: Array, rng: RandomNumberGenerator, conservative: bool) -> Array:
	var result: Array = [source[0]]
	for i in range(1,source.size()): result.append(float(result[-1])+maxf(3,roundf(float(source[i])-float(source[i-1]))+(0 if conservative else rng.randi_range(0,2))))
	return result


func _axis(value: float, before: Array, after: Array) -> float:
	for i in range(1,before.size()):
		if value<=float(before[i]) or i==before.size()-1: return lerpf(float(after[i-1]),float(after[i]),(value-float(before[i-1]))/(float(before[i])-float(before[i-1])))
	return value


func _point(p: Vector2) -> Vector2:
	return Vector2(_axis(p.x,X,x_to),_axis(p.y,Y,y_to)).rotated(rotation)+offset


func _path(path: Array, snap := .5) -> Array:
	var result: Array = []
	for raw: Array in path:
		var p := _pair(_point(PLAN.vector(raw)).snapped(Vector2.ONE*snap))
		if result.is_empty() or p!=result[-1]: result.append(p)
	return result


func _rect(raw: Array, cell_edges := false) -> Array:
	var original := PLAN.rect(raw)
	var shift := Vector2.ONE*.5 if cell_edges else Vector2.ZERO
	var quantum := Vector2.ONE if cell_edges else Vector2.ONE*.5
	var result := Rect2((_point(original.position)-shift).snapped(quantum)+shift,Vector2.ZERO)
	for p in [original.end,Vector2(original.position.x,original.end.y),Vector2(original.end.x,original.position.y)]: result = result.expand((_point(p)-shift).snapped(quantum)+shift)
	return [result.position.x,result.position.y,result.size.x,result.size.y]


func _pair(p: Vector2) -> Array: return [p.x,p.y]


func _reserve_paths(data: Dictionary) -> void:
	for key in ["trees","props"]:
		var kept: Array = []
		for raw in data[key]:
			var at := Vector2(float(raw[0]),float(raw[1])) if key=="trees" else PLAN.vector(raw.at)
			var radius := .48 if key=="trees" else (.35 if raw.asset in ["tomb","lamp","incense"] else .65)
			var placed := false
			var offsets: Array = [Vector2.ZERO]
			for distance in [.5,1.0,1.5]:
				for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]: offsets.append(direction*distance)
			for offset_value: Vector2 in offsets:
				var p := at+offset_value
				if PLAN.water_distance(p,data)>-.3 or PLAN.wall_at(p,.28,data): continue
				var clear := true
				for edge: Dictionary in data.edges:
					for i in edge.points.size()-1:
						if p.distance_to(Geometry2D.get_closest_point_to_segment(p,PLAN.vector(edge.points[i]),PLAN.vector(edge.points[i+1])))<radius: clear = false; break
					if not clear: break
				if not clear: continue
				if key=="trees": raw[0] = p.x; raw[1] = p.y
				else: raw.at = _pair(p)
				placed = true; break
			if placed: kept.append(raw)
		data[key] = kept


func _decorate(data: Dictionary) -> void:
	for house: Dictionary in data.buildings:
		var box := PLAN.rect(house.rect)
		if minf(box.size.x,box.size.y)<2.5: continue
		var assets: Array = ["lotus_tub","stone_bench","lamp"]
		if house.id in ["shop","shop_store"]: assets = ["type_rack","writing_desk","lamp"]
		elif house.id in ["library","moon_study","east_study"]: assets = ["type_cabinet","writing_desk","lamp"]
		elif house.id in ["boss_hall","north_shrine","stele_house"]: assets = ["incense","tomb","lamp"]
		var anchors := [box.position+Vector2(.8,.8),Vector2(box.end.x-.8,box.position.y+.8),Vector2(box.position.x+.6,box.end.y-.65)]
		for i in 3: data.props.append({"asset":assets[i],"at":_pair(anchors[i]),"scale":.65 if assets[i]!="tomb" else .4,"turn":rotation,"mount":"wall_bay"})
	for path: Array in data.galleries:
		for i in path.size()-1:
			var a := PLAN.vector(path[i]); var b := PLAN.vector(path[i+1]); var length := a.distance_to(b)
			if length<3: continue
			var normal := (b-a).normalized().orthogonal()*.65
			for index in maxi(1,floori(length/4)):
				var at := a.lerp(b,float(index+.5)/maxi(1,floori(length/4)))+normal
				data.props.append({"asset":"lamp","at":_pair(at),"scale":.62,"turn":rotation,"mount":"gallery"})


func _add_event_stops(data: Dictionary) -> void:
	var stops := [{"id":"passage_event","name":"折廊灯龛","at":[45,29.5]},{"id":"pond_event","name":"沿池拾页","at":[30,20]},{"id":"rear_event","name":"后园过厅","at":[48,12]}]
	for stop: Dictionary in stops:
		stop["kind"] = "event"; stop["corridor_stop"] = true
		stop["zones"] = [[float(stop.at[0])-.5,float(stop.at[1])-.5,1,1]]
		data.nodes[stop.id] = stop
	for edge: Dictionary in data.edges.duplicate():
		if edge.from=="opening_1" and edge.to=="opening_2":
			data.edges.erase(edge)
			data.edges.append({"from":"opening_1","to":"passage_event","points":[[47,32],[47,29.5],[45,29.5]]})
			data.edges.append({"from":"passage_event","to":"opening_2","points":[[45,29.5],[41,29.5],[41,27.5]]})
		elif edge.from=="treasure_merge":
			edge.from = "pond_event"; edge.points = [[30,20]]+edge.points.slice(1)
		elif edge.from=="battle_merge":
			edge.from = "rear_event"
			edge.points = [[48,12]]+([[49,12]] if edge.branch==1 else [])+edge.points.slice(2)
	data.edges.append({"from":"treasure_merge","to":"pond_event","points":[[30,26],[30,20]]})
	data.edges.append({"from":"battle_merge","to":"rear_event","points":[[47,16],[47,12],[48,12]]})
	data.groups[1].source = "pond_event"; data.groups[2].source = "rear_event"
	# Retain all combat identities. Only an excess optional non-combat event
	# becomes treasure, keeping every possible route within 3--5 events.
	for mask in 8:
		var events: Array = []
		for g in 3:
			for id: String in data.groups[g].branches[(mask>>g)&1]:
				if data.nodes[id].kind=="event": events.append(id)
		if events.size()>2: data.nodes[events[-1]].kind = "treasure"


static func validate_navigation(layout: RefCounted) -> bool:
	for edge: Dictionary in layout.corridors:
		var allowed := func(cell: Vector2i) -> bool:
			if not layout.cells.has(cell): return false
			var owners: Dictionary = layout.cells[cell]
			return owners.rooms.has(edge.from) or owners.rooms.has(edge.to) or owners.edges.has(edge.id)
		if layout.path(layout.rooms[edge.from].stand_cell,layout.rooms[edge.to].stand_cell,allowed).is_empty():
			layout.error = "门路未连通："+edge.id
			return false
	return true
