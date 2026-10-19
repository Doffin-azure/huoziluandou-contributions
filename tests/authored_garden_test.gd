extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
var failures: Array = []
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void: run_checks.call_deferred()


func run_checks() -> void:
	for mask in 8:
		var run := RUN.new(); run.reset({"seed":29,"layout":"authored_garden"}); run.autosave = false
		check(run.generation_error.is_empty(),"authored layout builds")
		check(run.graph.rooms.size()==18,"all 18 nodes retained")
		var order: Array = ["opening_1","opening_2"]
		for g in 3:
			order.append_array(run.graph.groups[g].branches[(mask>>g)&1]); order.append(run.graph.groups[g].merge)
		order.append("boss")
		for id: String in order:
			var before := run.current_room
			var result: Dictionary = run.enter_room(id)
			check(result.get("ok",false),"route %d %s -> %s: %s" % [mask,before,id,result])
			if not result.get("ok",false): break
			resolve(run)
			for sealed: String in run.sealed:
				check(not run.walkable(run.layout.rooms[sealed].stand_cell),"discarded node stays blocked: "+sealed)
		check(run.current_room=="boss","route reaches boss: "+str(mask))
		if mask==0:
			check(run.save_run("user://authored-garden-test.tres")==OK,"authored save")
			var saved = RUN.restore("user://authored-garden-test.tres")
			check(saved!=null and saved.layout_kind=="authored_garden" and saved.current_room=="boss","authored restore retains mode and progress")
	print("[AuthoredGarden] checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func resolve(run: RefCounted) -> void:
	match run.phase:
		"encounter": run.begin_live_battle(); run.finish_live_battle(true); run.apply({"type":"skip"})
		"reward": run.apply({"type":"skip"})
		"event": run.apply({"type":"event","index":2})
		"rest": run.apply({"type":"leave_service"})
		"shop": run.apply({"type":"shop_leave"})
