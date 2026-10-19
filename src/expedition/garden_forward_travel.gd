extends RefCounted
## Node progression is directed; walking inside a room remains four-way.
## Every blocked crossing is a real doorway, also drawn by the sample view.
var plan: RefCounted
var current_node := "start"
var departed := false
var enabled := true # Encounters close the exit until their settlement completes.
var history: Array[String] = ["start"]
var gates: Array[Dictionary] = []
var next_nodes: Array[String] = []
var _gate_at := {}


func _init(layout: RefCounted) -> void:
	plan = layout
	var indexed := {}
	for cell: Vector2i in plan.links:
		var owner: String = plan.cells[cell]
		if owner.is_empty(): continue
		for outside: Vector2i in plan.links[cell]:
			if plan.cells[outside]==owner: continue
			var key := _key(cell,outside)
			if not indexed.has(key):
				var gate := {"a":cell,"b":outside,"entries":[],"open":false,"direction":Vector2i.ZERO}
				indexed[key] = gate; gates.append(gate)
				if not _gate_at.has(cell): _gate_at[cell] = {}
				if not _gate_at.has(outside): _gate_at[outside] = {}
				_gate_at[cell][outside] = indexed[key]; _gate_at[outside][cell] = indexed[key]
			indexed[key].entries.append({"owner":owner,"cell":cell,"normal":outside-cell,"flow":_flow(owner,cell,outside)})
	_refresh()


static func _key(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.x>b.x or a.x==b.x and a.y>b.y: return Vector4i(b.x,b.y,a.x,a.y)
	return Vector4i(a.x,a.y,b.x,b.y)


func _flow(owner: String, cell: Vector2i, outside: Vector2i) -> String:
	for door: Dictionary in plan.nodes[owner].get("doors",[]):
		if door.cell==cell and door.normal==outside-cell and not str(door.get("flow","")).is_empty(): return door.flow
	# The parallel comparison and older layouts have no explicit door metadata.
	for edge: Dictionary in plan.corridors:
		if owner not in [edge.from,edge.to]: continue
		for i in range(1,edge.floor.size()):
			if edge.from==owner and edge.floor[i-1]==cell and edge.floor[i]==outside: return "out"
			if edge.to==owner and edge.floor[i-1]==outside and edge.floor[i]==cell: return "in"
	return ""


func _refresh() -> void:
	next_nodes.clear()
	for edge: Dictionary in plan.corridors:
		if edge.from==current_node and not next_nodes.has(edge.to): next_nodes.append(edge.to)
	for gate: Dictionary in gates:
		gate.open = enabled; gate.direction = Vector2i.ZERO
		for entry: Dictionary in gate.entries:
			var allowed: bool = entry.flow=="out" and entry.owner==current_node and not departed or entry.flow=="in" and next_nodes.has(entry.owner)
			if not allowed: gate.open = false
			if allowed: gate.direction = entry.normal if entry.flow=="out" else -entry.normal


func can_step(from: Vector2i, to: Vector2i) -> bool:
	if not plan.links.get(from,[]).has(to): return false
	var gate: Dictionary = _gate_at.get(from,{}).get(to,{})
	if gate.is_empty(): return true
	return gate.open and to-from==gate.direction


func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not plan.cells.has(from) or not plan.cells.has(to): return []
	var owner: String = plan.cells[to]
	if not owner.is_empty() and owner!=current_node and not next_nodes.has(owner): return []
	var previous := {from:from}; var queue: Array[Vector2i] = [from]; var cursor := 0
	while cursor<queue.size() and not previous.has(to):
		var cell := queue[cursor]; cursor += 1
		for next: Vector2i in plan.links.get(cell,[]):
			if not previous.has(next) and can_step(cell,next): previous[next] = cell; queue.append(next)
	if not previous.has(to): return []
	var result: Array[Vector2i] = [to]
	while result[-1]!=from: result.append(previous[result[-1]])
	result.reverse(); return result


func step(from: Vector2i, to: Vector2i) -> bool:
	if not can_step(from,to): return false
	var owner: String = plan.cells[to]
	var changed := false
	if plan.cells[from]==current_node and owner!=current_node: departed = true; changed = true
	if next_nodes.has(owner):
		current_node = owner; history.append(owner); departed = false; changed = true
	if changed: _refresh()
	return true
