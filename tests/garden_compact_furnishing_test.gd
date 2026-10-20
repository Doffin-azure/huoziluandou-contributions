extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const ASSETS = preload("res://src/expedition/room_interior_assets.gd")
var checks := 0
var failures: Array = []


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func _ready() -> void:
	var kinds := {}
	for seed_value in [17,29,67]:
		var run = RUN.new(); run.reset({"seed":seed_value,"layout":"compact_garden"}); run.autosave = false
		for id: String in run.layout.rooms:
			var room: Dictionary = run.layout.rooms[id]
			check(room.props.size()>=4,"room has furnished corner and wall bays")
			for prop: Dictionary in room.props:
				kinds[prop.asset] = true
				check(not run.layout.links.has(prop.reserved_cell),"furniture bay is excluded from walking")
				var rect: Rect2 = ASSETS.placed_rect(prop).grow(.18)
				for cell: Vector2i in run.layout.links:
					if not room.bounds.has_point(Vector2(cell)): continue
					var local: Vector2 = room.transform.affine_inverse()*Vector2(cell)
					check(not rect.has_point(local),"walking cell has clearance from "+prop.asset)
			for door: Dictionary in run.layout.compact.nodes[id].doors:
				check(run.layout.links.has(door.cell),"furnishing leaves doorway clear")
		check(kinds.size()>=8,"approved furniture families are actually assigned")
	print("[GardenFurnishings] ",{"checks":checks,"failures":failures,"assets":kinds.keys()})
	get_tree().quit(0 if failures.is_empty() else 1)
