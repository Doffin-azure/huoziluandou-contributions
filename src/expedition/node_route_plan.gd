extends RefCounted
## Build the routes first, then assign encounters. Never consumes gameplay RNG.
const COLUMNS := 15
const LANES := 5
const PATHS := 6
const MIN_NODES := 46
const MAX_NODES := 64


static func generate(seed_value: int, act: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("node-route:%d:%d:v2" % [seed_value, act])
	var graph := {}
	# Retry only the topology; the total is a range, not a fixed number of slots.
	for attempt in 12:
		graph = _routes(seed_value, act, rng)
		if graph.rooms.size() >= MIN_NODES and graph.rooms.size() <= MAX_NODES and _has_choices(graph): break
	var ordered: Array = graph.rooms.keys()
	ordered.sort_custom(func(a, b):
		var left: Dictionary = graph.rooms[a]
		var right: Dictionary = graph.rooms[b]
		return left.row < right.row if left.row != right.row else left.lane < right.lane)
	var sorted_rooms := {}
	for id: String in ordered: sorted_rooms[id] = graph.rooms[id]
	graph.rooms = sorted_rooms
	for attempt in 24:
		if _encounters(graph, ordered, rng): break
		if attempt == 23: _fallback_encounters(graph, rng)
	for id: String in ordered:
		var spec: Dictionary = graph.rooms[id]
		spec.number = ordered.find(id) + 1
		spec.name = {"start":"入狱", "boss":"幕末首领"}.get(spec.kind, "%02d · %s" % [spec.row + 1, _label(spec.kind)])
		spec.content_seed = rng.randi_range(1, 1 << 30)
		spec.jitter = rng.randf_range(-.17, .17) if spec.row in range(1, COLUMNS - 1) else 0.0
		spec.offset_x = rng.randf_range(-.10, .10) if spec.row in range(1, COLUMNS - 1) else 0.0
	return graph


static func _routes(seed_value: int, act: int, rng: RandomNumberGenerator) -> Dictionary:
	var graph := {"schema":1, "layout_kind":"node_graph", "layout_version":2,
		"seed":seed_value, "act":act, "lane_count":LANES, "rooms":{}, "edges":[], "groups":[], "start":"start", "boss":"boss"}
	_add(graph, "start", -1, (LANES - 1) * .5)
	var starts: Array = [rng.randi_range(0, 1), 2, rng.randi_range(3, 4)]
	if rng.randf() < .45:
		var remaining: Array = range(LANES).filter(func(lane): return not starts.has(lane))
		starts.append(remaining[rng.randi_range(0, remaining.size() - 1)])
	for path in PATHS:
		var lane: int = starts[path] if path < starts.size() else starts[rng.randi_range(0, starts.size() - 1)]
		var previous := "start"
		for column in COLUMNS:
			if column > 0:
				var candidates: Array = []
				var weights: Array = []
				for next_lane in range(maxi(0, lane - 1), mini(LANES - 1, lane + 1) + 1):
					var target := _id(column, next_lane)
					if _crosses_lane(graph, previous, column, next_lane): continue
					candidates.append(next_lane)
					var weight := 1.15 if next_lane == lane else 1.0
					if graph.rooms.has(target): weight *= 1.1
					if graph.rooms[previous].next.has(target): weight *= .35
					weights.append(weight)
				lane = candidates[_weighted_index(weights, rng)]
			var id := _id(column, lane)
			if not graph.rooms.has(id): _add(graph, id, column, lane)
			_link(graph, previous, id)
			previous = id
	_add(graph, "boss", COLUMNS, (LANES - 1) * .5)
	for id: String in graph.rooms:
		if graph.rooms[id].row == COLUMNS - 1: _link(graph, id, "boss")
	return graph


static func _encounters(graph: Dictionary, ordered: Array, rng: RandomNumberGenerator) -> bool:
	var events := {}
	var event_choices: Array = []
	for id: String in ordered:
		var row: int = graph.rooms[id].row
		var eligible := row > 0 and row < COLUMNS - 1 and row != 8
		events[id] = eligible and rng.randf() < .28
		if eligible: event_choices.append(id)
	# Keep the existing 3–5 event budget, without putting events in fixed columns.
	if not _balance(graph, ordered, events, event_choices, 3, 5, rng): return false
	var combat := {}
	var combat_choices: Array = []
	for id: String in ordered:
		var row: int = graph.rooms[id].row
		var eligible: bool = row >= 0 and row < COLUMNS - 1 and row != 8 and not events[id]
		combat[id] = eligible and (row < 3 or row == 13 or rng.randf() < .72)
		if eligible and row >= 3 and row < 13: combat_choices.append(id)
	if not _balance(graph, ordered, combat, combat_choices, 6, 9, rng): return false
	for id: String in ordered:
		var spec: Dictionary = graph.rooms[id]
		if id == graph.start: spec.kind = "start"
		elif id == graph.boss: spec.kind = "boss"
		elif spec.row == 8: spec.kind = "treasure"
		elif spec.row == COLUMNS - 1: spec.kind = "rest"
		elif events[id]: spec.kind = "event"
		elif combat[id]:
			spec.kind = "elite" if spec.row >= 4 and not _neighbour_kind(graph, id, "elite", false) and rng.randf() < .22 else "battle"
		else:
			var services: Array = ["rest", "shop"].filter(func(kind): return not _neighbour_kind(graph, id, kind, false))
			# A merge with both services before it gets combat instead of a repeat.
			spec.kind = services[rng.randi_range(0, services.size() - 1)] if not services.is_empty() else "battle"
	if not graph.rooms.values().any(func(spec): return spec.kind == "elite"):
		var battles: Array = ordered.filter(func(id): return graph.rooms[id].kind == "battle" and graph.rooms[id].row >= 4)
		if battles.is_empty(): return false
		graph.rooms[battles[rng.randi_range(0, battles.size() - 1)]].kind = "elite"
	var columns := {}
	for spec: Dictionary in graph.rooms.values():
		if not columns.has(spec.row): columns[spec.row] = {}
		columns[spec.row][spec.kind] = true
	var mixed: int = columns.values().filter(func(kinds): return kinds.size() > 1).size()
	return mixed >= 5 and graph.rooms.values().any(func(spec): return spec.kind == "shop")


static func _has_choices(graph: Dictionary) -> bool:
	# Every playable route gets at least four choices, including its entry branch.
	var minimum := {"start":0}
	for row in range(-1, COLUMNS):
		for id: String in graph.rooms:
			var spec: Dictionary = graph.rooms[id]
			if spec.row != row: continue
			var count: int = minimum[id] + int(spec.next.size() > 1)
			for target: String in spec.next: minimum[target] = mini(int(minimum.get(target, COLUMNS)), count)
	return int(minimum[graph.boss]) >= 4


## Flip event/combat flags to satisfy budgets across every possible route, not just
## the six walks used to draw the graph. Prefix/suffix histograms count merged routes.
static func _balance(graph: Dictionary, ordered: Array, flags: Dictionary, choices: Array, lower: int, upper: int, rng: RandomNumberGenerator) -> bool:
	for step in 40:
		var prefix := {}
		var suffix := {}
		for id: String in ordered:
			prefix[id] = _histogram(); suffix[id] = _histogram()
		prefix[graph.start][0] = 1
		for id: String in ordered:
			for next: String in graph.rooms[id].next:
				for count in COLUMNS:
					if prefix[id][count]: prefix[next][count + int(flags[next])] += prefix[id][count]
		suffix[graph.boss][0] = 1
		for index in range(ordered.size() - 1, -1, -1):
			var id: String = ordered[index]
			for next: String in graph.rooms[id].next:
				for count in COLUMNS:
					if suffix[next][count]: suffix[id][count + int(flags[next])] += suffix[next][count]
		var score := 0
		for count in COLUMNS + 1: score += prefix[graph.boss][count] * _penalty(count, lower, upper)
		if score == 0: return true
		var best_delta := 0
		var best: Array = []
		for id: String in choices:
			var change := -1 if flags[id] else 1
			var delta := 0
			for before in COLUMNS + 1:
				if not prefix[id][before]: continue
				for after in COLUMNS + 1 - before:
					if not suffix[id][after]: continue
					delta += prefix[id][before] * suffix[id][after] * (_penalty(before + after + change, lower, upper) - _penalty(before + after, lower, upper))
			if delta < best_delta: best_delta = delta; best = [id]
			elif delta == best_delta and delta < 0: best.append(id)
		if best.is_empty(): return false
		var chosen: String = best[rng.randi_range(0, best.size() - 1)]
		flags[chosen] = not flags[chosen]
	return false


static func _histogram() -> Array:
	var result: Array = []; result.resize(COLUMNS + 1); result.fill(0)
	return result


static func _penalty(count: int, lower: int, upper: int) -> int:
	var distance := maxi(lower - count, maxi(0, count - upper))
	return distance * distance


static func _fallback_encounters(graph: Dictionary, rng: RandomNumberGenerator) -> void:
	# Bounded safety net if content constraints ever conflict; topology stays intact.
	var events := [rng.randi_range(1, 2), rng.randi_range(4, 5), rng.randi_range(10, 11)]
	for spec: Dictionary in graph.rooms.values():
		if spec.row == -1: spec.kind = "start"
		elif spec.row == COLUMNS: spec.kind = "boss"
		elif spec.row == 8: spec.kind = "treasure"
		elif spec.row == 14 or spec.row == 12: spec.kind = "rest"
		elif spec.row == 6: spec.kind = "shop"
		elif events.has(spec.row): spec.kind = "event"
		elif spec.row == 9: spec.kind = "elite"
		else: spec.kind = "battle"
	graph["content_fallback"] = true


static func _neighbour_kind(graph: Dictionary, id: String, kind: String, include_next := true) -> bool:
	var ids: Array = graph.rooms[id].previous.duplicate()
	if include_next: ids.append_array(graph.rooms[id].next)
	return ids.any(func(other): return graph.rooms[other].get("kind", "") == kind)


static func _weighted_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight: float in weights: total += weight
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0: return i
	return weights.size() - 1


static func _id(column: int, lane: int) -> String:
	return "r%02d_%d" % [column + 1, lane]


static func _add(graph: Dictionary, id: String, column: int, lane: float) -> void:
	graph.rooms[id] = {"id":id, "row":column, "lane":lane, "next":[], "previous":[]}


static func _label(kind: String) -> String:
	return {"battle":"战斗", "elite":"精英", "event":"奇遇", "rest":"休息", "shop":"字肆", "treasure":"宝藏"}.get(kind, kind)


static func _crosses_lane(graph: Dictionary, from: String, column: int, lane: float) -> bool:
	for edge: Dictionary in graph.edges:
		if graph.rooms[edge.to].row != column: continue
		if (graph.rooms[from].lane - graph.rooms[edge.from].lane) * (lane - graph.rooms[edge.to].lane) < 0: return true
	return false


static func _crosses(graph: Dictionary, from: String, to: String) -> bool:
	return _crosses_lane(graph, from, int(graph.rooms[to].row), float(graph.rooms[to].lane))


static func _link(graph: Dictionary, from: String, to: String) -> void:
	if graph.rooms[from].next.has(to): return
	graph.rooms[from].next.append(to); graph.rooms[to].previous.append(from)
	graph.edges.append({"id":from + ">" + to, "from":from, "to":to})
