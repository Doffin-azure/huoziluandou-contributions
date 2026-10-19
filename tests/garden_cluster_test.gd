extends Node
const GRAPH = preload("res://src/expedition/room_route_graph.gd")
const LAYOUT = preload("res://src/expedition/garden_room_layout.gd")
const FIELD = preload("res://src/expedition/garden_pond_field.gd")
const RUN = preload("res://src/expedition/room_run_state.gd")
var failures: Array = []
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void:
	for seed_value in [1,17,29,2026,818]:
		var graph := GRAPH.generate(seed_value)
		var layout := LAYOUT.new()
		check(layout.build(graph),"cluster layout seed "+str(seed_value)+": "+layout.error)
		if not layout.error.is_empty(): continue
		var cluster: Dictionary = layout.clusters[0]
		var ponds: Array = cluster.ponds.duplicate(true)
		for id in cluster.members: ponds.append_array(FIELD.world_ponds(layout.rooms[id]))
		var wet := 0; var crossed_walls := 0; var shared_unrelated := 0; var foreign_rooms := 0
		for cell in layout.cells:
			var point: Vector2 = layout.point(cell)
			if not cluster.bounds.has_point(point): continue
			var entry: Dictionary = layout.cells[cell]
			if FIELD.sample(ponds,point)>0: wet += 1
			for edge_id: String in entry.edges:
				var ends := edge_id.split(">")
				for id: String in layout.rooms:
					if id not in ends and layout.rooms[id].bounds.grow(-.10).has_point(point): foreign_rooms += 1
				for id: String in ends:
					var room: Dictionary = layout.rooms[id]
					var box: Rect2 = room.bounds
					if not box.grow(.01).has_point(point): continue
					var edge_distance := minf(minf(absf(point.x-box.position.x),absf(point.x-box.end.x)),minf(absf(point.y-box.position.y),absf(point.y-box.end.y)))
					if edge_distance>.13: continue
					var port: Dictionary = room.edge_ports.get(edge_id,room.output if id==ends[0] else room.input)
					if point.distance_to(port.at)>.56: crossed_walls += 1
			for a in entry.edges.size():
				for b in range(a+1,entry.edges.size()):
					var one: PackedStringArray = entry.edges[a].split(">")
					var two: PackedStringArray = entry.edges[b].split(">")
					if not one.has(two[0]) and not one.has(two[1]): shared_unrelated += 1
		check(wet==0,"walking grid excludes all actual pond shapes seed "+str(seed_value))
		check(crossed_walls==0,"corridors enter only real doorways seed "+str(seed_value)+" bad="+str(crossed_walls))
		check(shared_unrelated==0,"unrelated routes do not share cells seed "+str(seed_value))
		check(foreign_rooms==0,"routes do not cross an unrelated court seed "+str(seed_value))
		for id in cluster.members:
			var room: Dictionary = layout.rooms[id]
			for port in room.ports: check(is_equal_approx(port.offset*2,roundf(port.offset*2)),"native wall modules fit door offsets")
		print("[ClusterGeometry] seed=",seed_value," members=",cluster.members.size()," bounds=",cluster.bounds," wet=",wet," wall_crossings=",crossed_walls)
	# Traverse both alternatives through the real state controller; no render-only
	# teleport can prove that the chosen branch and merge still behave correctly.
	for branch_index in 2:
		var run := RUN.new(); run.reset({"seed":29}); run.autosave = false
		for id in ["opening_1","opening_2"]:
			check(run.enter_room(id).ok,"reach forecourt "+id); _resolve(run)
		var group: Dictionary = run.graph.groups[0]
		for id in group.branches[branch_index]:
			check(run.enter_room(id).ok,"walk chosen wing "+str(id)); _resolve(run)
		check(run.enter_room(group.merge).ok,"reach pond-side merge"); _resolve(run)
		for id in group.branches[1-branch_index]:
			check(run.sealed.has(id) and not run.walkable(run.layout.rooms[id].stand_cell),"other wing stays closed at merge")
		check(run.save_run("user://garden-cluster-test.tres")==OK,"save clustered route")
		var restored = RUN.restore("user://garden-cluster-test.tres")
		check(restored!=null and restored.graph.layout_version==4 and restored.current_room==group.merge and restored.sealed==run.sealed,"restore whole-site graph/progress")
	print("[GardenCluster] checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func _resolve(run: RefCounted) -> void:
	match run.phase:
		"encounter": run.begin_live_battle(); run.finish_live_battle(true); run.apply({"type":"skip"})
		"reward": run.apply({"type":"skip"})
		"event": run.apply({"type":"event","index":run.event_data.get("options",[]).size()-1})
		"rest": run.apply({"type":"leave_service"})
