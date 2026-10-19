extends Node
const GRAPH = preload("res://src/expedition/room_route_graph.gd")
const LAYOUT = preload("res://src/expedition/garden_room_layout.gd")
const CATALOG = preload("res://src/expedition/room_template_catalog.gd")
var failures: Array = []
var checks := 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void:
	for seed_value in [17,818]:
		var layout := LAYOUT.new()
		check(layout.build(GRAPH.generate(seed_value)),"layout "+str(seed_value))
		for room: Dictionary in layout.rooms.values():
			var id: String = room.route_id
			var allowed := func(cell): return layout.cells.has(cell) and layout.cells[cell].rooms.has(id)
			for port in room.ports:
				var at: Vector3 = CATALOG.port_position(room,port)
				var world: Vector2 = room.transform*Vector2(at.x,at.z)
				var target: Vector2i = layout.nearest(world,id)
				check(not layout.path(room.stand_cell,target,allowed).is_empty(),"furniture blocks "+id+" / "+port.side+" seed "+str(seed_value))
			var before := var_to_str(room.props)
			CATALOG.apply_enclosure(room); CATALOG.apply_enclosure(room)
			check(var_to_str(room.props)==before,"interior application is stable: "+id)
	# A side entrance must remove its decorative shelf without deleting the shop.
	var sample: Dictionary = CATALOG.templates().filter(func(room): return room.kind=="shop")[0]
	sample.ports = [CATALOG._port("W",2.5,"entry"),CATALOG._port("E",3)]
	CATALOG.apply_enclosure(sample)
	check(not sample.props.any(func(prop): return prop.asset=="type_cabinet"),"west entrance clears its shelf")
	check(sample.props.any(func(prop): return prop.asset=="stall" and prop.state=="service"),"shop service survives port adaptation")
	print("[RoomInteriors] checks=",checks," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
