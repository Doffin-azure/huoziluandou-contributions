extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
var checks := 0
var failures: Array = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void:
	for seed_value in [29,67]:
		var run = RUN.new(); run.reset({"seed":seed_value,"layout":"compact_garden"}); run.autosave = false
		var initial: Array = run.next_rooms().duplicate()
		var rng_state: int = GameState.rng.state
		var position: Vector2i = run.position
		var gates: Array = run.travel.gates.duplicate(true)
		for i in 16:
			var choices: Array = run.plan_choices()
			check(not choices.is_empty(),"a preview can continue to the boss")
			check(run.apply({"type":"plan_room","room":choices[0]}).ok,"connected preview accepted")
		check(run.planned_route.size()==16 and run.planned_route[-1]=="boss","complete route contains sixteen future encounters")
		check(run.current_room=="start" and run.phase=="map" and run.position==position and run.sealed.is_empty(),"planning does not commit movement, encounter or branch abandonment")
		check(GameState.rng.state==rng_state and run.travel.gates==gates,"preview does not consume gameplay RNG or change gates")
		check(not run.apply({"type":"plan_room","room":"start"}).ok,"cannot preview a backwards edge")
		var prefix: Array = run.planned_route.slice(0,5)
		check(run.plan_room(prefix[-1]).ok and run.planned_route==prefix,"clicking a planned room truncates its continuation")
		check(run.save_run("user://garden-plan-test.tres")==OK,"preview is saved")
		var restored = RUN.restore("user://garden-plan-test.tres"); restored.autosave = false
		check(restored.planned_route==prefix and restored.current_room=="start","reload preserves uncommitted preview")
		run = restored
		check(run.enter_room(prefix[0]).ok,"first confirmed step uses existing physical travel")
		check(run.current_room==prefix[0] and run.phase=="encounter" and run.planned_route==prefix.slice(1),"arrival consumes only first preview and stops for its encounter")
		check(not run.enter_room(prefix[1]).ok,"preview cannot skip unresolved encounter")
		check(not run.enter_room("start").ok,"planning cannot reopen return route")
		check(run.apply({"type":"clear_plan"}).ok and run.planned_route.is_empty(),"preview can be discarded independently of progress")
		var second = RUN.new(); second.reset({"seed":seed_value,"layout":"compact_garden"}); second.autosave = false
		second.plan_room(initial[0]); second.plan_room(second.plan_choices()[0])
		check(second.plan_room(initial[1]).ok and second.planned_route==[initial[1]],"switching first branch replaces its preview tail")
		second.plan_room(second.plan_choices()[0])
		check(second.apply({"type":"undo_plan"}).ok and second.planned_route==[initial[1]],"undo removes only the last previewed node")
		var before: Array = second.planned_route.duplicate()
		check(not second.plan_room("boss").ok and second.planned_route==before,"cannot preview unconnected shortcut")
	var report := {"checks":checks,"failures":failures}
	var folder := "res://docs/art-concepts/2026-10-18-garden-route-planning"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file := FileAccess.open(folder.path_join("planning-checks.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  "))
	print("[GardenPlanning] ",report)
	get_tree().quit(0 if failures.is_empty() else 1)
