extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
var checks := 0
var failures: Array = []
var kinds := {}


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void: run_checks.call_deferred()


func settle(run: RefCounted) -> void:
	for guard in 12:
		if run.phase in ["map","act_end","victory","defeat"]: return
		match run.phase:
			"encounter":
				check(not run.travel.enabled and run.travel.gates.all(func(g):return not g.open),"encounter closes real exit gates")
				check(run.begin_live_battle(),"existing live battle begins")
				run.finish_live_battle(true)
				var gold: int = GameState.gold; run.finish_live_battle(true)
				check(GameState.gold==gold,"battle settles once")
			"reward":
				check(run.save_run("user://compact-reward-test.tres")==OK,"reward state saves")
				var restored = RUN.restore("user://compact-reward-test.tres"); restored.autosave = false
				check(restored.current_room==run.current_room and restored.reward_options==run.reward_options and not restored.travel.enabled,"reward reload preserves contents and closed doors")
				GameState.room_run = run
				var chosen: String = run.reward_options[0].glyph
				var size_before: int = run.tray.size()
				check(run.apply({"type":"reward","index":0,"glyph":chosen}).ok,"existing reward claim succeeds")
				check(run.phase in ["map","act_end"] and (run.tray.size()==size_before+1 if size_before<6 else true),"claim keeps original tray/deck destination")
				check(not run.apply({"type":"reward","index":0,"glyph":chosen}).ok,"reward cannot be claimed twice")
			"event","event_choose":
				var actions: Array = run.legal_actions()
				check(not actions.is_empty(),"event catalog has available choices")
				if actions.is_empty(): return
				check(run.apply(actions[-1]).ok,"event uses existing effect protocol")
			"shop":
				check(not run.shop_offers.is_empty(),"shop has persistent stock")
				run.apply({"type":"shop_leave"})
			"rest": run.apply({"type":"leave_service"})
			_: check(false,"unexpected phase "+run.phase); return
	check(false,"node failed to settle within bounded actions")


func run_checks() -> void:
	for seed_value in [17,29,67]:
		var run = RUN.new(); run.reset({"seed":seed_value,"layout":"compact_garden"}); run.autosave = false
		check(run.generation_error.is_empty(),"production adapter generates seed "+str(seed_value))
		GameState.player_max_hp = 1000; GameState.player_hp = 1000
		for act in [1,2,3]:
			check(run.graph.rooms.size()==55 and run.layout.walk_step==1,"55 candidates and one tile per step")
			check(run.observe().forward_only and run.observe().rooms.size()==55,"AI observes same candidates and forward-only rules")
			check(not run.enter_room("boss").ok,"cannot skip to the boss")
			var initial: Array = run.next_rooms().duplicate()
			var first: String = initial[(seed_value+act)%initial.size()]
			var path: Array = run.move_path(run.layout.rooms[first].stand_cell)
			for cell: Vector2i in path.slice(1):
				check(run.step(cell),"walks using the controller's actual grid edges")
				if run.travel.departed: break
			check(run.travel.departed,"can save after leaving source room")
			check(run.save_run("user://compact-walking-test.tres")==OK,"walking state saves")
			var restored = RUN.restore("user://compact-walking-test.tres"); restored.autosave = false
			check(restored.travel.departed and restored.position==run.position and restored.graph.rooms==run.graph.rooms and restored.graph.edges==run.graph.edges and restored.layout.compact.links==run.layout.compact.links,"reload preserves node content, geometry and in-transit state")
			run = restored
			check(run.move_path(run.layout.rooms.start.stand_cell).is_empty(),"reload never reopens return to start")
			for depth in 20:
				if run.phase=="act_end": break
				var next: Array = run.next_rooms()
				check(not next.is_empty(),"every completed node has a forward continuation")
				if next.is_empty(): break
				var target: String = first if depth==0 else next[(seed_value+depth+act)%next.size()]
				var previous: String = run.current_room
				var result: Dictionary = run.enter_room(target)
				check(result.ok,"physical path reaches "+target+": "+str(result))
				if not result.ok: break
				kinds[run.graph.rooms[target].kind] = true
				check(not run.enter_room(previous).ok,"cannot reenter the previous encounter")
				settle(run)
				check(run.legal_actions().all(func(a):return a.type!="enter_room" or run.next_rooms().has(a.room)),"no return-room action is advertised")
				if depth==0:
					for sibling: String in initial:
						if sibling!=first: check(run.sealed.has(sibling) and not run.enter_room(sibling).ok,"unchosen starting branch closes")
			check(run.phase=="act_end" and run.current_room=="boss" and run.visited_rooms.size()==17,"one forward route reaches boss in 17 stops")
			var tray: Array = run.tray.duplicate()
			run.apply({"type":"next_act"})
			if act<3: check(GameState.act_index==act+1 and run.phase=="map" and run.tray==tray,"next act replaces only map progression")
			else: check(run.phase=="victory","third boss completes the run")
		await get_tree().process_frame
	check(["battle","elite","event","rest","shop","treasure","boss"].all(func(k):return kinds.has(k)),"routes cover every production node kind")
	GameState.set_meta("courtyard_preview",true)
	var default_run = RUN.start(4294960007)
	check(default_run.layout_kind=="compact_garden" and default_run.graph.rooms.size()==55 and not default_run.autosave,"normal start uses compact generator and F6 restarts stay disposable")
	GameState.remove_meta("courtyard_preview")
	var report := {"checks":checks,"failures":failures,"seeds":[17,29,67],"acts_per_seed":3,"node_kinds":kinds.keys()}
	var folder := "res://docs/art-concepts/2026-10-18-garden-connected"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file := FileAccess.open(folder.path_join("run-checks.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  "))
	print("[CompactRun] ",report); get_tree().quit(0 if failures.is_empty() else 1)
