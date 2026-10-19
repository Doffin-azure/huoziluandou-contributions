extends Node
const PLAN = preload("res://src/expedition/garden_blockout_plan.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-18-garden-blockout"
var failures: Array = []
var cases: Array = []
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void: run_checks.call_deferred()


func run_checks() -> void:
	Engine.max_fps = 0
	var count := 256
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): count = maxi(1,int(arg.trim_prefix("--seeds=")))
	var signatures := {}; var topologies := {}; var orientations := {}; var dimensions := {}; var timings: Array = []
	var rng_before: int = GameState.rng.state
	for seed_value in count:
		for act in [1,2,3]:
			var plan = PLAN.generate(seed_value,act)
			var report: Dictionary = plan.validate(); cases.append(report); timings.append(plan.generation_ms)
			check(report.ok,"seed %d act %d: %s" % [seed_value,act,report.errors])
			check(plan.corridors.filter(func(e):return e.bridge).size()==5,"five cross-bank connections")
			# Static geometry is undirected. Actual traversal additionally obeys
			# garden_forward_travel; its no-return checks live in garden_forward_test.
			check(plan.path(plan.nodes.boss.at,plan.nodes.start.at).size()>1,"static geometry remains connected independently of progression gates")
			signatures[hash(var_to_str(plan.to_data()))] = true
			topologies[hash(var_to_str(plan.corridors.map(func(e):return e.id)))] = true
			orientations[plan.quarter_turns] = true; dimensions[str(plan.bounds.size)] = true
			if seed_value<4:
				var replay = PLAN.generate(seed_value,act)
				check(var_to_str(plan.to_data())==var_to_str(replay.to_data()),"same seed and act reproduce exact geometry")
				var restored = PLAN.from_data(JSON.parse_string(JSON.stringify(plan.to_data())))
				check(restored!=null and restored.validate().ok and restored.cells==plan.cells and restored.links==plan.links,"serialized layout preserves floors, walls and paths")
		if seed_value%32==0: print("[BlockoutSeeds] completed=",seed_value+1,"/",count)
		await get_tree().process_frame
	check(GameState.rng.state==rng_before,"geometry never consumes gameplay RNG")
	if count>=16:
		check(orientations.size()==4,"all four orientations covered")
		check(topologies.size()>count,"seeds alter connections, not only decoration")
		check(dimensions.size()>8,"seeds alter integer bay dimensions")
	var broken = PLAN.generate(17)
	broken.nodes.n01.at = broken.nodes.n02.at
	check(not broken.validate().ok,"validator detects deliberately overlapping room footprints")
	broken = PLAN.generate(17)
	broken.corridors[0].points[1] += Vector2i(1,1)
	check(not broken.validate().ok,"validator detects deliberately non-grid connector")
	broken = PLAN.generate(17)
	broken.links[broken.nodes.boss.at] = []
	check(not broken.validate().ok,"validator detects a deliberately cut return path")
	timings.sort()
	var summary := {"cases":cases.size(),"seeds":count,"acts":[1,2,3],"checks":checks,"failures":failures,"unique_layouts":signatures.size(),"unique_topologies":topologies.size(),"orientations":orientations.keys(),"dimensions":dimensions.size(),"generation_median_ms":timings[timings.size()/2],"generation_p95_ms":timings[mini(timings.size()-1,floori(timings.size()*.95))],"results":cases}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("seed-validation.json"),FileAccess.WRITE); file.store_string(JSON.stringify(summary,"  "))
	print("[GardenBlockout] cases=",cases.size()," checks=",checks," failures=",failures," median_ms=",summary.generation_median_ms," p95_ms=",summary.generation_p95_ms)
	get_tree().quit(0 if failures.is_empty() else 1)
