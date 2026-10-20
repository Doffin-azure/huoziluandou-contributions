extends RefCounted
## Pure route topology; presentation never builds courtyard geometry or consumes run RNG.
const COLUMNS := 15
const LANES := 4


static func generate(seed_value: int, act: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("node-route:%d:%d:v1" % [seed_value, act])
	var graph := {"schema":1, "layout_kind":"node_graph", "layout_version":1,
		"seed":seed_value, "act":act, "rooms":{}, "edges":[], "groups":[], "start":"start", "boss":"boss"}
	_add(graph, "start", "start", -1, 1.5, rng)
	var reduced: Array = range(COLUMNS)
	for i in range(reduced.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old: int = reduced[i]
		reduced[i] = reduced[j]; reduced[j] = old
	var columns: Array = []
	for column in COLUMNS:
		var omitted := rng.randi_range(0, LANES - 1) if reduced.slice(0, 7).has(column) else -1
		var kinds := _kinds(column)
		for i in range(kinds.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var old: String = kinds[i]
			kinds[i] = kinds[j]; kinds[j] = old
		var ids: Array = []
		for lane in LANES:
			if lane == omitted: continue
			var id := "r%02d_%d" % [column + 1, lane]
			_add(graph, id, kinds[ids.size()], column, lane, rng)
			ids.append(id)
		columns.append(ids)
	_add(graph, "boss", "boss", COLUMNS, 1.5, rng)
	for id: String in columns[0]: _link(graph, "start", id)
	for column in COLUMNS - 1:
		var left: Array = columns[column]
		var right: Array = columns[column + 1]
		# Ordered nearest neighbours cover both sides without crossing paths.
		for id: String in left: _link(graph, id, _nearest(graph, id, right))
		for id: String in right:
			if graph.rooms[id].previous.is_empty(): _link(graph, _nearest(graph, id, left), id)
		var candidates: Array = []
		for a: String in left:
			for b: String in right:
				if absf(graph.rooms[a].lane - graph.rooms[b].lane) <= 1: candidates.append([a, b])
		for i in range(candidates.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var old: Array = candidates[i]
			candidates[i] = candidates[j]; candidates[j] = old
		for pair: Array in candidates:
			if rng.randf() < .62 and not _crosses(graph, pair[0], pair[1]): _link(graph, pair[0], pair[1])
	for id: String in columns[-1]: _link(graph, id, "boss")
	return graph


static func _kinds(column: int) -> Array:
	if column in [0, 1, 3, 7, 10, 13]: return ["battle", "battle", "battle", "battle"]
	if column in [2, 6, 11]: return ["event", "event", "event", "event"]
	if column == 8: return ["treasure", "treasure", "treasure", "treasure"]
	if column == 14: return ["rest", "rest", "rest", "rest"]
	if column in [4, 9]: return ["event", "shop", "elite", "battle"]
	if column == 5: return ["shop", "rest", "battle", "elite"]
	return ["battle", "elite", "battle", "elite"]


static func _add(graph: Dictionary, id: String, kind: String, column: int, lane: float, rng: RandomNumberGenerator) -> void:
	graph.rooms[id] = {"id":id, "kind":kind, "row":column, "lane":lane,
		"number":graph.rooms.size() + 1, "next":[], "previous":[],
		"name":{"start":"入狱", "boss":"幕末首领"}.get(kind, "%02d · %s" % [column + 1, _label(kind)]),
		"content_seed":rng.randi_range(1, 1 << 30), "jitter":rng.randf_range(-.13, .13)}


static func _label(kind: String) -> String:
	return {"battle":"战斗", "elite":"精英", "event":"奇遇", "rest":"休息", "shop":"字肆", "treasure":"宝藏"}.get(kind, kind)


static func _nearest(graph: Dictionary, id: String, candidates: Array) -> String:
	var best: String = candidates[0]
	for other: String in candidates:
		if absf(graph.rooms[id].lane - graph.rooms[other].lane) < absf(graph.rooms[id].lane - graph.rooms[best].lane): best = other
	return best


static func _crosses(graph: Dictionary, from: String, to: String) -> bool:
	for edge: Dictionary in graph.edges:
		if graph.rooms[edge.from].row != graph.rooms[from].row: continue
		if (graph.rooms[from].lane - graph.rooms[edge.from].lane) * (graph.rooms[to].lane - graph.rooms[edge.to].lane) < 0: return true
	return false


static func _link(graph: Dictionary, from: String, to: String) -> void:
	if graph.rooms[from].next.has(to): return
	graph.rooms[from].next.append(to); graph.rooms[to].previous.append(from)
	graph.edges.append({"id":from + ">" + to, "from":from, "to":to})
