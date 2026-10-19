extends RefCounted
## Exit information is anchored to real doors and the first distinct branch.
## Merely looking at a sign never advances or seals the route.
static func options(run: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if run.travel==null: return result
	var edges: Array = run.layout.compact.corridors.filter(func(edge):return edge.from==run.current_room and run.next_rooms().has(edge.to))
	for edge: Dictionary in edges:
		var anchor := Vector2i.ZERO; var gate := Vector2i.ZERO; var found := false
		for cell: Vector2i in edge.floor:
			if not str(run.layout.compact.cells[cell]).is_empty(): continue
			if not found: gate = cell; anchor = cell; found = true
			if not edges.any(func(other):return other.id!=edge.id and other.floor.has(cell)):
				anchor = cell; break
		if found: result.append({"id":edge.to,"edge":edge.id,"gate":gate,"anchor":anchor,"steps":edge.floor.size()-1})
	return result


static func following(run: RefCounted, id: String) -> String:
	var kinds: Array[String] = []
	for next: String in run.graph.rooms[id].next:
		var kind: String = run.LABELS[run.graph.rooms[next].kind]
		if not kinds.has(kind): kinds.append(kind)
	return " / ".join(kinds) if not kinds.is_empty() else "本幕终点"
