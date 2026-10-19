extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const GENERATOR = preload("res://src/expedition/random_garden_plan.gd")
var failures: Array = []
var checks := 0
var covered := {}


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void: run_checks.call_deferred()


func run_checks() -> void:
	var signatures := {}; var sizes := {}; var topologies := {}
	for seed_value in [1,2,7,17,29,67,101,20261018]:
		var start_time := Time.get_ticks_msec()
		var run := RUN.new(); run.reset({"seed":seed_value,"layout":"random_garden"}); run.autosave = false
		check(run.generation_error.is_empty(),"seed %d generated: %s" % [seed_value,run.generation_error])
		if not run.generation_error.is_empty(): continue
		var graph: Dictionary = run.graph.duplicate(true); var layout: RefCounted = run.layout
		var rng_before := GameState.rng.state
		var replay := GENERATOR.generate(seed_value,1,int(layout.site.generation.attempt))
		check(var_to_str(graph)==var_to_str(replay),"same seed reproduces exact site and nodes")
		check(GameState.rng.state==rng_before,"layout generation does not consume gameplay RNG")
		signatures[var_to_str(layout.site.pond_polygon)] = true
		sizes[graph.rooms.size()] = true
		topologies[str(graph.edges.map(func(edge): return edge.id))] = true
		check(graph.rooms.size()>=18 and graph.rooms.size()<=21,"bounded stop count")
		check(is_equal_approx(layout.walk_step,1.0),"one tile per logical step")
		check(layout.rooms.values().all(func(room): return layout.point(room.stand_cell).is_equal_approx(room.stand)),"all node stands are at tile centers")
		check(layout.site.generation.battle_nodes.all(func(id): return graph.rooms.has(id) and graph.rooms[id].kind in ["battle","elite","boss"]),"combat stops are retained")
		for kind in ["shop","elite","treasure","rest"]: check(graph.rooms.values().any(func(room): return room.kind==kind),"generated garden retains "+kind)
		for mask in 8:
			GameState.start_new_run("v03"); GameState.player_hp = 25; GameState.gold = 200
			run.graph = graph.duplicate(true); run.layout = layout
			run.current_room = "start"; run.resolved = {"start":true}; run.visited_rooms = {"start":true}
			run.choices = {}; run.sealed = {}; run.contents = {}; run.seen_events = []
			run.tray = []; run.position = layout.rooms.start.stand_cell; run.phase = "map"
			var order: Array = ["opening_1","passage_event","opening_2"]
			for g in 3:
				order.append_array(graph.groups[g].branches[(mask>>g)&1]); order.append(graph.groups[g].merge)
				if g<2: order.append("pond_event" if g==0 else "rear_event")
			order.append("boss")
			check(order.filter(func(id):return graph.rooms[id].kind=="event").size() in [3,4,5],"every route has 3--5 events")
			for id: String in order:
				var previous := run.current_room
				var result: Dictionary = run.enter_room(id)
				check(result.get("ok",false),"seed %d route %d %s -> %s: %s" % [seed_value,mask,previous,id,result])
				if not result.get("ok",false): break
				covered[graph.rooms[id].kind] = true
				resolve(run)
				for excluded: String in run.sealed:
					check(not run.walkable(layout.rooms[excluded].stand_cell),"unchosen branch cannot be entered: "+excluded)
			check(run.current_room=="boss" and run.phase=="act_end","seed %d route %d reaches boss settlement" % [seed_value,mask])
		# Save the actual site, not just a generator version and seed.
		check(run.save_run("user://random-garden-test.tres")==OK,"generated site save")
		var restored = RUN.restore("user://random-garden-test.tres")
		check(restored!=null and restored.layout_kind=="random_garden","restore generated mode")
		if restored!=null:
			restored.autosave = false
			check(restored.layout.cells.keys().all(func(cell): return layout.cells.has(cell)) and restored.layout.cells.size()==layout.cells.size(),"restore identical walkable geometry")
			check(restored.graph.rooms.size()==run.graph.rooms.size() and restored.graph.rooms.keys().all(func(id): return run.graph.rooms.has(id)),"restore generated node set")
			check(restored.layout.site.generation.seed==seed_value and restored.layout.site.generation.act==1 and restored.layout.site.generation.quarter_turns==layout.site.generation.quarter_turns,"restore generation identity")
			check(restored.position==run.position and restored.sealed==run.sealed,"restore exact progress")
			check(restored.apply({"type":"next_act"}).get("ok",false) and GameState.act_index==2,"boss advances act")
			check(restored.layout_kind=="random_garden" and restored.graph.act==2 and restored.generation_error.is_empty(),"next act builds a fresh random garden")
			check(var_to_str(restored.layout.site.pond_polygon)!=var_to_str(layout.site.pond_polygon),"act changes site geometry")
		print("[RandomGarden] seed=",seed_value," nodes=",graph.rooms.size()," attempt=",layout.site.generation.attempt," time_ms=",Time.get_ticks_msec()-start_time)
	check(signatures.size()==8,"different seeds have different geography")
	check(sizes.size()>1 and topologies.size()>1,"branch stop counts and graph change")
	for kind in ["battle","elite","event","shop","treasure","rest","boss"]: check(covered.has(kind),"node gameplay covered: "+kind)
	print("[RandomGarden] checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func resolve(run: RefCounted) -> void:
	match run.phase:
		"encounter":
			check(run.begin_live_battle(),"encounter starts battle")
			var gold_before := GameState.gold
			run.finish_live_battle(true)
			check(run.phase=="reward" and GameState.gold>gold_before,"battle settles gold and reward")
			resolve(run)
		"reward":
			var before: int = run.tray.size()
			check(run.apply(run.legal_actions()[0]).get("ok",false),"treasure/battle reward selection")
			check(run.resolved.has(run.current_room) and (run.tray.size()==before+1 or before==6),"reward enters tray/deck and opens exit")
			check(not run.apply({"type":"reward","index":0}).get("ok",false),"reward cannot settle twice")
		"event":
			for i in 12:
				if run.phase=="map": break
				var actions: Array = run.legal_actions()
				check(not actions.is_empty(),"event has available choices")
				if actions.is_empty(): break
				check(run.apply(actions[-1]).get("ok",false),"event option/pending choice resolves")
			check(run.phase=="map" and run.resolved.has(run.current_room),"event returns to garden")
		"rest":
			GameState.player_hp = 25
			check(run.apply({"type":"rest","kind":"heal"}).get("ok",false),"rest heal connected")
			check(GameState.player_hp>25 and run.phase=="map","rest heals and opens exit")
			check(not run.apply({"type":"rest","kind":"heal"}).get("ok",false),"rest cannot repeat")
		"shop":
			var before := GameState.deck_size(); var offers: int = run.shop_offers.size()
			check(run.apply(run.legal_actions()[0]).get("ok",false),"shop purchase connected")
			check(GameState.deck_size()==before+1 and run.shop_offers.size()==offers-1,"shop removes sold stock")
			check(run.apply({"type":"shop_leave"}).get("ok",false) and run.phase=="map","shop leave opens exit")
