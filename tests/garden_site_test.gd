extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const GRAPH = preload("res://src/expedition/room_route_graph.gd")
const LAYOUT = preload("res://src/expedition/garden_room_layout.gd")
var failures: Array = []
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void:
	var shapes := {}
	for seed_value in [29,17,818]:
		var rng_before := GameState.rng.state
		var graph := GRAPH.generate(seed_value)
		var layout := LAYOUT.new()
		check(layout.build(graph),"whole site builds")
		check(GameState.rng.state==rng_before,"site packing and ponds do not consume gameplay RNG")
		var bounds: Rect2 = layout.clusters[0].bounds
		check(maxf(bounds.size.x,bounds.size.y)/minf(bounds.size.x,bounds.size.y)<1.6,"sample whole site is not a long strip")
		var positions: Array = []
		for spec: Dictionary in graph.rooms.values(): positions.append(spec.center-graph.rooms.opening_2.center)
		shapes[str(positions)] = true
		for id: String in layout.rooms:
			var room: Dictionary = layout.rooms[id]
			var allowed := func(cell): return layout.cells.has(cell) and layout.cells[cell].rooms.has(id)
			for port in room.edge_ports.values():
				check(not layout.path(room.stand_cell,layout.nearest(port.at,id),allowed).is_empty(),"all real doors reachable within "+id)
	check(shapes.size()==3,"seed samples have different spatial embeddings")
	var run := RUN.new(); run.reset({"seed":29}); run.autosave = false
	for id in ["opening_1","opening_2"]: check(run.enter_room(id).ok,"reach opening"); resolve(run)
	var group: Dictionary = run.graph.groups[0]
	for id in group.branches[0]: check(run.enter_room(id).ok,"reach chosen branch"); resolve(run)
	check(run.enter_room(group.merge).ok,"reach merge"); resolve(run)
	var content_seeds := {}
	for id in run.graph.rooms: content_seeds[id] = run.graph.rooms[id].content_seed
	var sealed := run.sealed.duplicate(); var resolved := run.resolved.duplicate()
	# Simulate the previous shipped spatial schema; progress is independent of coordinates.
	run.graph.layout_version = 3; run.graph.erase("site_plan")
	for spec: Dictionary in run.graph.rooms.values(): spec.center *= 2; spec["cluster_id"] = "lotus_garden"
	run.position = Vector2i(9999,9999); GameState.gold = 67
	check(run.save_run("user://garden-site-v3-migration-test.tres")==OK,"write legacy spatial save")
	var restored = RUN.restore("user://garden-site-v3-migration-test.tres")
	check(restored!=null,"restore previous spatial schema")
	if restored!=null:
		restored.autosave = false
		check(restored.graph.layout_version==4 and restored.graph.has("site_plan"),"legacy layout upgraded")
		check(restored.current_room==group.merge and restored.sealed==sealed and restored.resolved==resolved,"migration retains branch and settlements")
		check(GameState.gold==67 and restored.walkable(restored.position),"migration retains gold and relocates feet to safe court")
		for id in content_seeds: check(restored.graph.rooms[id].content_seed==content_seeds[id],"migration retains encounter seed")
	print("[GardenSite] checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func resolve(run: RefCounted) -> void:
	match run.phase:
		"encounter": run.begin_live_battle(); run.finish_live_battle(true); run.apply({"type":"skip"})
		"reward": run.apply({"type":"skip"})
		"event": run.apply({"type":"event","index":run.event_data.get("options",[]).size()-1})
		"rest": run.apply({"type":"leave_service"})
