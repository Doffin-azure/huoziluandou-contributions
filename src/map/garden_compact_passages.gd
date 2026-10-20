extends RefCounted
## Architecture follows the existing, full-size walking tiles. It never adds
## shortcuts, consumes gameplay randomness, or changes the ground height.
const KIT = preload("res://src/map/garden_bridge_kit.gd")
const LIBRARY = preload("res://src/map/garden_mesh_library.gd")
const GRID = preload("res://src/expedition/garden_blockout_plan.gd")


static func generate(layout: RefCounted) -> Array[Dictionary]:
	var plan: RefCounted = layout.compact
	var result: Array[Dictionary] = []
	var owners := {}
	for edge: Dictionary in plan.corridors:
		for cell: Vector2i in edge.floor:
			if not owners.has(cell): owners[cell] = []
			if not owners[cell].has(edge.id): owners[cell].append(edge.id)
	for edge: Dictionary in plan.corridors:
		var runs: Array = []; var run: Array[Vector2i] = []; var heading := Vector2i.ZERO
		for i in edge.floor.size():
			var cell: Vector2i = edge.floor[i]
			var direction: Vector2i = edge.floor[i+1]-cell if i+1<edge.floor.size() else heading
			var valid: bool = str(plan.cells[cell]).is_empty() and owners[cell].size()==1
			if valid:
				var perpendicular := Vector2i(-direction.y,direction.x)
				valid = not plan.cells.has(cell+perpendicular) and not plan.cells.has(cell-perpendicular)
				for room: Dictionary in layout.rooms.values():
					if room.bounds.grow(.7).has_point(Vector2(cell)): valid = false; break
			if not valid or direction!=heading:
				if run.size()>=3: runs.append(run.duplicate())
				run.clear()
			if valid: run.append(cell)
			heading = direction
		if run.size()>=3: runs.append(run.duplicate())
		# A bridge or roof is one continuous run, rather than a chain of tiny roofs.
		runs.sort_custom(func(a,b):return a.size()>b.size())
		for cells: Array in runs:
			var length := mini(7,cells.size())
			var offset := (cells.size()-length)/2
			var first: Vector2i = cells[offset]; var last: Vector2i = cells[offset+length-1]
			var direction := Vector2(last-first).normalized()
			var start := Vector2(first)-direction*.5
			var finish := Vector2(last)+direction*.5
			var envelope := Rect2(start,Vector2.ZERO).expand(finish).grow(.84)
			if result.any(func(old):return old.bounds.grow(.10).intersects(envelope)): continue
			if layout.rooms.values().any(func(room):return room.bounds.grow(.15).intersects(envelope)): continue
			var water := 0
			var normal := Vector2i(-roundi(direction.y),roundi(direction.x))
			for i in range(offset,offset+length):
				for side in [-1,1]:
					if str(plan.plots.get(cells[i]+normal*side,"water"))=="water": water += 1
			var kind := "gallery"
			if water>=length:
				var destination: String = plan.nodes[edge.to].kind
				kind = "covered" if edge.from=="start" or destination in ["rest","shop","event"] else ("arch" if destination=="treasure" else "pier")
			result.append({"id":edge.id+"_passage","edge":edge.id,"kind":kind,"start":start,"direction":direction,"length":length,"bounds":envelope,"cells":cells.slice(offset,offset+length)})
			break
	return result


static func balustrades(plan: RefCounted, bridge_cells: Dictionary) -> Dictionary:
	var regions := {}; var seen_posts := {}
	for cell: Vector2i in plan.cells:
		if not str(plan.cells[cell]).is_empty() or bridge_cells.has(cell): continue
		var key: Vector2i = GRID.chunk_at(Vector2(cell))
		if not regions.has(key): regions[key] = {"edges":[],"posts":[]}
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			if plan.cells.has(cell+direction) or str(plan.plots.get(cell+direction,"water"))!="water": continue
			var normal := Vector2(direction); var tangent := Vector2(-direction.y,direction.x)
			regions[key].edges.append({"start":Vector2(cell)+normal*.475-tangent*.5,"direction":tangent})
			for at: Vector2 in [Vector2(cell)+normal*.5-tangent*.5,Vector2(cell)+normal*.5+tangent*.5]:
				if seen_posts.has(at): continue
				seen_posts[at] = true
				var owner: Vector2i = GRID.chunk_at(at)
				if not plan.chunks.has(owner): owner = key
				if not regions.has(owner): regions[owner] = {"edges":[],"posts":[]}
				regions[owner].posts.append(at)
	return regions


static func instance(kind: String, length: int, painter: ExpeditionFlatStyle) -> Node3D:
	return LIBRARY.instantiate("compact-span:level-v3:%s:%d" % [kind,length],func():
		var original := KIT.new(); original.kind = kind; original.span_length = float(length)
		original.with_deck = false; original.level_deck = true
		original.canopy_height = 1.22
		if kind=="rail": original.omit_first_post = true; original.omit_last_post = true
		original.setup(painter)
		return original,painter)
