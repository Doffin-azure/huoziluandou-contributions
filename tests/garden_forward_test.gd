extends Node
const PLAN = preload("res://src/expedition/garden_blockout_plan.gd")
const COMPACT = preload("res://src/expedition/garden_compact_assembly.gd")
const TRAVEL = preload("res://src/expedition/garden_forward_travel.gd")
var failures: Array = []
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void: run_checks.call_deferred()


func run_checks() -> void:
	var count := 16; var cases := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): count = int(arg.trim_prefix("--seeds="))
	for seed_value in count:
		for act in [1,2,3]:
			var plan = COMPACT.fit(PLAN.generate(seed_value,act))
			if plan.assembly.has("error"): check(false,str(plan.assembly)); continue
			var travel = TRAVEL.new(plan)
			check(not travel.gates.is_empty(),"real door thresholds indexed")
			check(travel.gates.all(func(g):return g.entries.all(func(e):return e.flow in ["in","out"])),"every physical door has an unambiguous progression role")
			for node: Dictionary in plan.nodes.values():
				var incoming: Array = node.doors.filter(func(d):return d.flow=="in")
				var outgoing: Array = node.doors.filter(func(d):return d.flow=="out")
				check(node.id=="start" or not incoming.is_empty(),"non-start room has entrance")
				check(node.id=="boss" or not outgoing.is_empty(),"non-boss room has exit")
				check(incoming.all(func(d):return outgoing.all(func(o):return o.normal!=d.normal)),"entry and exit use separate facades")
			for edge: Dictionary in plan.corridors:
				# Treat this source as the room just reached. Test every original
				# connection with the same doors and rules used by actual walking.
				travel.current_node = edge.from; travel.departed = false; travel.history.assign([edge.from]); travel._refresh()
				var source: Vector2i = plan.nodes[edge.from].at; var target: Vector2i = plan.nodes[edge.to].at
				var path: Array[Vector2i] = travel.path(source,target)
				check(path.size()>1,"seed %d act %d: directed connection %s remains walkable" % [seed_value,act,edge.id])
				if path.size()<2: continue
				var walked := true; var door_backtracks := false
				for i in range(1,path.size()):
					var old_owner: String = plan.cells[path[i-1]]; var new_owner: String = plan.cells[path[i]]
					if not travel.step(path[i-1],path[i]): walked = false; break
					if old_owner!=new_owner and not old_owner.is_empty() and travel.can_step(path[i],path[i-1]): door_backtracks = true
				check(walked and not door_backtracks and travel.current_node==edge.to,"door closes behind walker without trapping forward route")
				check(travel.history==[edge.from,edge.to],"no extra encounter can be crossed while travelling between stops")
				check(travel.path(target,source).is_empty(),"returning to previous room is refused")
				check(travel.gates.all(func(g):return not g.open or g.entries.all(func(e):return e.owner!=edge.from)),"all previous room gates visibly close")
				for node: Dictionary in plan.nodes.values():
					if node.id!=travel.current_node and not travel.next_nodes.has(node.id):
						check(travel.path(target,node.at).is_empty(),"abandoned branches and later rows cannot be selected")
			# A complete run chooses one branch at each depth, never all 55 stops.
			travel = TRAVEL.new(plan)
			var cell: Vector2i = plan.nodes.start.at
			for depth in 20:
				if travel.current_node=="boss": break
				if travel.next_nodes.is_empty(): check(false,"non-boss node has no forward choice"); break
				var next: String = travel.next_nodes[(seed_value+depth)%travel.next_nodes.size()]
				var path: Array[Vector2i] = travel.path(cell,plan.nodes[next].at)
				if path.size()<2: check(false,"full route blocked"); break
				for step: Vector2i in path.slice(1):
					check(travel.step(cell,step),"full run advances tile by tile"); cell = step
			check(travel.current_node=="boss" and travel.history.size()==17,"55 alternatives yield 17 forward stops per run")
			cases += 1
		await get_tree().process_frame
		if seed_value%4==0: print("[ForwardProgress] ",seed_value+1,"/",count)
	var summary := {"cases":cases,"checks":checks,"failures":failures,"directed_nodes":true,"tile_walking":true}
	var file := FileAccess.open("res://docs/art-concepts/2026-10-18-garden-compact/forward-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"  "))
	print("[GardenForward] ",summary); get_tree().quit(0 if failures.is_empty() else 1)
