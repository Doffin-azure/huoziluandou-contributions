extends Node
const PLAN = preload("res://src/expedition/garden_blockout_plan.gd")
const COMPACT = preload("res://src/expedition/garden_compact_assembly.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-18-garden-compact"
var failures: Array = []
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void: run_checks.call_deferred()


func run_checks() -> void:
	var cases: Array = []; var reductions: Array = []; var count := 64
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): count = int(arg.trim_prefix("--seeds="))
	var before_rng: int = GameState.rng.state
	for seed_value in count:
		for act in [1,2,3]:
			var source = PLAN.generate(seed_value,act)
			var source_data: String = var_to_str(source.to_data())
			var plan = COMPACT.fit(source)
			if plan.assembly.has("error"):
				check(false,"seed %d act %d: %s" % [seed_value,act,plan.assembly.error]); continue
			var result: Dictionary = plan.validate()
			check(result.ok,"seed %d act %d: %s" % [seed_value,act,result.errors])
			check(plan.nodes.size()==55 and plan.nodes.keys()==source.nodes.keys(),"all original stops retained")
			check(plan.corridors.map(func(e):return [e.id,e.from,e.to])==source.corridors.map(func(e):return [e.id,e.from,e.to]),"original graph retained exactly")
			check(plan.nodes.values().all(func(n):return n.kind==source.nodes[n.id].kind),"node content types retained")
			check(var_to_str(source.to_data())==source_data,"packing never mutates the source graph")
			check(plan.assembly.area_reduction>.15,"packing reduces enclosing area")
			check(plan.assembly.compounds.size()==10 and plan.nodes.values().any(func(n):return n.get("role","")=="侧室"),"real hall/side/ear-room compounds")
			var owner_contacts := true
			for c: Vector2i in plan.links:
				if str(plan.cells[c]).is_empty(): continue
				for next: Vector2i in plan.links[c]:
					var other: String = plan.cells[next]
					if other.is_empty() or other==plan.cells[c]: continue
					if not plan.corridors.any(func(e):return e.from==plan.cells[c] and e.to==other or e.to==plan.cells[c] and e.from==other): owner_contacts = false
			check(owner_contacts,"adjacent side rooms do not create an unplanned doorway")
			if seed_value<3:
				var loaded = PLAN.from_data(JSON.parse_string(JSON.stringify(plan.to_data())))
				check(loaded!=null and loaded.validate().ok and loaded.links==plan.links and loaded.nodes.values().all(func(n):return n.doors==plan.nodes[n.id].doors),"saved side-door positions, directions and shared walls restore exactly")
				var replay = COMPACT.fit(source)
				check(var_to_str(replay.to_data())==var_to_str(plan.to_data()),"same seed gives identical packed layout")
			cases.append({"seed":seed_value,"act":act,"ok":result.ok,"attempt":plan.assembly.attempt,"area_reduction":plan.assembly.area_reduction,"area":plan.assembly.area,"original_area":plan.assembly.original_area,"corridor_length":plan.assembly.corridor_length,"original_corridor_length":plan.assembly.original_corridor_length,"generation_ms":plan.generation_ms})
			reductions.append(plan.assembly.area_reduction)
		if seed_value%8==0: print("[CompactProgress] ",seed_value+1,"/",count)
		await get_tree().process_frame
	check(GameState.rng.state==before_rng,"packing does not consume gameplay RNG")
	reductions.sort()
	var summary := {"seeds":count,"cases":cases.size(),"checks":checks,"failures":failures,"minimum_area_reduction":reductions[0] if not reductions.is_empty() else 0,"maximum_area_reduction":reductions[-1] if not reductions.is_empty() else 0,"median_area_reduction":reductions[reductions.size()/2] if not reductions.is_empty() else 0,"results":cases}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("compact-seeds.json"),FileAccess.WRITE); file.store_string(JSON.stringify(summary,"  "))
	print("[GardenCompact] cases=",cases.size()," checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
