extends Node
const PLAN = preload("res://src/expedition/node_route_plan.gd")
const RUN = preload("res://src/expedition/room_run_state.gd")
var checks := 0
var failures := 0


func _ready() -> void:
	GameState.set_meta("courtyard_preview", true)
	SaveManager.enabled = false
	Settings.reduced_motion = true
	Engine.max_fps = 240
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var counts := {}
	var widths := {}
	var type_patterns := {}
	var topology_patterns := {}
	var fallback_count := 0
	var total_mixed := 0
	var began := Time.get_ticks_usec()
	var rng_before: int = GameState.rng.state
	for seed_value in 60:
		for act in range(1, 4):
			var graph: Dictionary = PLAN.generate(seed_value, act)
			var label := "seed %d act %d" % [seed_value, act]
			counts[graph.rooms.size()] = true
			if graph.get("content_fallback", false): fallback_count += 1
			check(graph.layout_version==2 and graph.rooms.size()>=PLAN.MIN_NODES and graph.rooms.size()<=PLAN.MAX_NODES, label+": version and candidate range")
			var bounds := {"start":[0, 0, 0, 0, 0]}
			var columns := {}
			var column_kinds := {}
			var forward := true
			var reciprocal := true
			var branches := 0
			var merges := 0
			for id: String in graph.rooms:
				var spec: Dictionary = graph.rooms[id]
				if spec.next.size()>1 and id!=graph.start: branches += 1
				if spec.previous.size()>1 and id!=graph.boss: merges += 1
				if spec.row>=0 and spec.row<PLAN.COLUMNS:
					if not columns.has(spec.row): columns[spec.row] = 0; column_kinds[spec.row] = {}
					columns[spec.row] += 1; column_kinds[spec.row][spec.kind] = true
				for target: String in spec.next:
					forward = forward and graph.rooms[target].row==spec.row+1
					reciprocal = reciprocal and graph.rooms[target].previous.has(id)
					if not bounds.has(id): continue
					var next: Dictionary = graph.rooms[target]
					var event := int(next.kind=="event")
					var combat := int(next.kind in ["battle", "elite"])
					var range_at: Array = [bounds[id][0]+event, bounds[id][1]+event, bounds[id][2]+combat, bounds[id][3]+combat, bounds[id][4]+int(spec.next.size()>1)]
					if bounds.has(target):
						var old: Array = bounds[target]
						range_at = [mini(old[0], range_at[0]), maxi(old[1], range_at[1]), mini(old[2], range_at[2]), maxi(old[3], range_at[3]), mini(old[4], range_at[4])]
					bounds[target] = range_at
			check(forward and reciprocal and bounds.size()==graph.rooms.size() and graph.rooms.values().all(func(spec): return spec.id==graph.start or not spec.previous.is_empty()), label+": all nodes reachable, links reciprocal, no backtracking")
			check(graph.rooms.values().all(func(spec): return spec.id==graph.boss or not spec.next.is_empty()), label+": no dead ends")
			check(bounds.boss[0]>=3 and bounds.boss[1]<=5 and bounds.boss[2]>=6 and bounds.boss[3]<=10, label+": every route has 3–5 events and 6–10 combat encounters")
			check(branches>=3 and merges>=2, label+": repeated splits and merges")
			check(bounds.boss[4]>=4, label+": each route has at least four actual route choices (%d)" % bounds.boss[4])
			check(graph.rooms.values().all(func(spec): return (spec.row!=0 or spec.kind=="battle") and (spec.row!=8 or spec.kind=="treasure") and (spec.row!=14 or spec.kind=="rest") and (spec.kind!="elite" or spec.row>=4)), label+": opening, chest, final rest and elite timing")
			var adjacent_repeat := false
			var crossing := false
			for edge: Dictionary in graph.edges:
				var a: Dictionary = graph.rooms[edge.from]
				var b: Dictionary = graph.rooms[edge.to]
				if a.kind in ["rest", "shop", "elite"] and a.kind==b.kind: adjacent_repeat = true
				for other: Dictionary in graph.edges:
					var c: Dictionary = graph.rooms[other.from]
					var d: Dictionary = graph.rooms[other.to]
					if a.row==c.row and (a.lane-c.lane)*(b.lane-d.lane)<0: crossing = true
			check(not adjacent_repeat and not crossing, label+": no consecutive identical services/elites or crossing lines")
			for width: int in columns.values(): widths[width] = true
			var mixed: int = column_kinds.values().filter(func(kinds): return kinds.size()>1).size()
			total_mixed += mixed
			check(mixed>=5 and graph.rooms.values().any(func(spec): return spec.kind=="shop") and graph.rooms.values().any(func(spec): return spec.kind=="elite"), label+": mixed encounter choices and all services")
			if act==1:
				type_patterns[JSON.stringify(graph.rooms.values().map(func(spec): return [spec.id, spec.kind]))] = true
				topology_patterns[JSON.stringify(graph.edges)] = true
	check(counts.size()>=8 and widths.size()>=3, "candidate totals and occupied widths vary across seeds")
	check(type_patterns.size()==60 and topology_patterns.size()==60, "seeds change both encounter placement and connectivity")
	check(fallback_count==0 and float(total_mixed)/180>=7.0, "normal generation avoids fallback columns and mixes at least seven columns on average")
	check(GameState.rng.state==rng_before, "generation does not advance gameplay RNG")
	check(PLAN.generate(29, 1)==PLAN.generate(29, 1) and PLAN.generate(29, 1)!=PLAN.generate(29, 2), "repeatable seeds with different act layouts")
	var run = RUN.start(29)
	var original: Dictionary = run.graph.duplicate(true)
	var first: String = run.next_rooms()[0]
	run.plan_room(first)
	check(run.save_run("user://node-generation-test.tres")==OK, "new layout saves")
	var restored = RUN.restore("user://node-generation-test.tres", true)
	var same_rooms: bool = restored.graph.rooms.size()==original.rooms.size() and original.rooms.keys().all(func(id): return restored.graph.rooms.has(id))
	for id: String in original.rooms:
		var old: Dictionary = original.rooms[id]
		var current: Dictionary = restored.graph.rooms[id]
		for key in ["id", "kind", "row", "lane", "number", "name", "content_seed", "previous", "next"]:
			same_rooms = same_rooms and old[key]==current[key]
		for key in ["jitter", "offset_x"]: same_rooms = same_rooms and is_equal_approx(old[key], current[key])
	check(same_rooms and restored.graph.edges==original.edges and restored.graph.layout_version==2 and restored.planned_route==[first], "restore preserves the graph and planned route without generation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://node-generation-test.tres"))
	if DisplayServer.get_name()!="headless" and OS.get_cmdline_user_args().has("--capture"): await capture_maps()
	print("[node_route_generation_test] CHECKS=%d FAIL=%d MAPS=180 COUNTS=%s WIDTHS=%s MIXED_AVG=%.2f FALLBACK=%d MS=%.1f" % [checks, failures, counts.keys(), widths.keys(), float(total_mixed)/180, fallback_count, (Time.get_ticks_usec()-began)/1000.0])
	get_tree().quit(0 if failures==0 else 1)


func capture_maps() -> void:
	var target := "res://shots/node-route-v2"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host); Router.host = host
	get_window().size = Vector2i(1280, 720)
	var samples: Array = []
	for seed_value in [29, 80, 2026]:
		var run = RUN.start(seed_value)
		Router.goto(RUN.MAP_SCREEN)
		for frame in 12: await get_tree().process_frame
		Router.current.map_view.show_overview()
		for frame in 4: await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(target.path_join("seed-%d.png" % seed_value))
		samples.append({"seed":seed_value, "candidates":run.graph.rooms.size(), "edges":run.graph.edges.size()})
	var file := FileAccess.open(target.path_join("samples.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(samples, "\t")+"\n")
