extends RefCounted
## Seeded route topology. Room IDs are independent of navigation coordinates.
const SITE = preload("res://src/expedition/garden_site_plan.gd")

static func generate(seed_value: int, act := 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + act * 1009
	var graph := {"schema":1,"seed":seed_value,"act":act,"rooms":{},"edges":[],"groups":[],"start":"start","boss":"boss"}
	_add(graph,"start","start",Vector2(0,12),Vector2.UP)
	_add(graph,"opening_1","battle",Vector2.ZERO,Vector2.UP)
	_add(graph,"opening_2","battle",Vector2(0,-12),Vector2.UP)
	_link(graph,"start","opening_1")
	_link(graph,"opening_1","opening_2")
	# Generate topology first. Spatial embedding belongs to the whole-site planner.
	var lengths: Array = []
	var total := 0
	for group in 3:
		var options := [[1,1],[1,2],[2,1],[2,2]]
		var choice: Array = options[rng.randi_range(0,options.size()-1)].duplicate()
		if group == 1 and rng.randf()<.28: choice = [1,2,2]
		lengths.append(choice)
		for n in choice: total += n
	# Keep 16–22 rooms while retaining unequal branches and occasional three-way choices.
	while total < 9:
		var g := rng.randi_range(0,2)
		var lane := rng.randi_range(0,lengths[g].size()-1)
		if lengths[g][lane] == 1: lengths[g][lane] = 2; total += 1
	# Preserve the historical content RNG sequence without using its U-shaped anchors.
	rng.randi_range(60,66); rng.randi_range(60,66)
	var merge_ids := ["treasure_merge","battle_merge","last_rest"]
	var merge_kinds := ["treasure","battle","rest"]
	var source := "opening_2"
	for g in 3:
		var destination: String = merge_ids[g]
		_add(graph,destination,merge_kinds[g],Vector2.ZERO,Vector2.UP)
		var branches: Array = []
		for b in lengths[g].size():
			var branch: Array = []
			var last := source
			for j in int(lengths[g][b]):
				var id := "g%d_b%d_%d" % [g,b,j]
				var kind := "battle"
				if g==0:
					kind = "battle" if j==0 else ["event","rest"][rng.randi_range(0,1)]
				elif g==1:
					kind = ("shop" if b==0 else "event") if j==0 else ("elite" if b>0 else "event")
				else:
					kind = ("elite" if b==0 else "event") if j==0 else ("event" if b==0 else ["battle","event"][rng.randi_range(0,1)])
				_add(graph,id,kind,Vector2.ZERO,Vector2.UP)
				graph.rooms[id].group = g
				graph.rooms[id].branch = b
				_link(graph,last,id)
				branch.append(id)
				last = id
			_link(graph,last,destination)
			branches.append(branch)
		graph.groups.append({"id":g,"source":source,"merge":destination,"branches":branches})
		source = destination
	_add(graph,"boss","boss",Vector2.ZERO,Vector2.UP)
	_link(graph,"last_rest","boss")
	for id in graph.rooms:
		graph.rooms[id]["content_seed"] = rng.randi_range(1,1<<30)
	# Keep the legacy topology RNG draws above for stable room-content seeds;
	# the final spatial pass is independently seeded and can migrate saved runs.
	compact_layout(graph)
	return graph


static func compact_layout(graph: Dictionary) -> bool:
	if graph.has("authored_site"): return false
	if int(graph.get("layout_version",1))>=4: return false
	SITE.apply(graph)
	return true


static func _add(graph: Dictionary, id: String, kind: String, center: Vector2, forward: Vector2) -> void:
	graph.rooms[id] = {"id":id,"kind":kind,"center":center.snapped(Vector2.ONE*.5),"forward":forward,"next":[],"previous":[]}


static func _link(graph: Dictionary, a: String, b: String) -> void:
	graph.rooms[a].next.append(b)
	graph.rooms[b].previous.append(a)
	graph.edges.append({"id":a+">"+b,"from":a,"to":b})


static func paths(graph: Dictionary, current := "start") -> Array:
	if current==graph.boss: return [[current]]
	var result: Array = []
	for target: String in graph.rooms[current].next:
		for tail: Array in paths(graph,target): result.append([current]+tail)
	return result
