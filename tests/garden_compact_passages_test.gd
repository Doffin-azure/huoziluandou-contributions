extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const PASSAGES = preload("res://src/map/garden_compact_passages.gd")
const EXITS = preload("res://src/map/garden_route_exits.gd")
var failures: Array[String] = []
var checks := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)


func _ready() -> void:
	var kinds := {}; var total := 0
	for seed_value in [1,17,29,42,67,99]:
		for act in [1,2,3]:
			var run := RUN.new(); run.reset({"seed":seed_value,"act":act,"layout":"compact_garden"}); run.autosave = false
			var rng_state: int = GameState.rng.state
			var features := PASSAGES.generate(run.layout)
			check(not features.is_empty(),"passages generated for %d/%d" % [seed_value,act])
			check(var_to_str(features)==var_to_str(PASSAGES.generate(run.layout)),"stable architectural arrangement")
			check(GameState.rng.state==rng_state and run.current_room=="start","decoration does not consume gameplay randomness or progression")
			for i in features.size():
				var feature: Dictionary = features[i]; total += 1; kinds[feature.kind] = true
				check(feature.length>=3 and feature.length<=7,"bounded reusable span length")
				check(is_equal_approx(feature.start.distance_to(feature.start+feature.direction*feature.length),float(feature.cells.size())),"span follows full-size walking cells")
				for cell: Vector2i in feature.cells:
					check(run.layout.compact.cells.get(cell,"missing")=="","bridge stays on an actual corridor")
					check(run.layout.compact.links.has(cell),"bridge floor has navigable grid data")
				check(not run.layout.rooms.values().any(func(room):return room.bounds.grow(.15).intersects(feature.bounds)),"roof envelope clears room shells and doors")
				for j in range(i): check(not features[j].bounds.grow(.1).intersects(feature.bounds),"separate span envelopes do not overlap")
			var options := EXITS.options(run)
			var covered := {}
			for feature: Dictionary in features:
				for cell: Vector2i in feature.cells: covered[cell] = true
			var rails := PASSAGES.balustrades(run.layout.compact,covered)
			var posts := {}
			for region: Dictionary in rails.values():
				for at: Vector2 in region.posts:
					check(not posts.has(at),"rail joints share exactly one post across regions")
					posts[at] = true
			for region: Dictionary in rails.values():
				for edge: Dictionary in region.edges:
					for at: Vector2 in [edge.start,edge.start+edge.direction]:
						var corner := (at+Vector2.ONE*.5).round()-Vector2.ONE*.5
						check(posts.has(corner),"every straight end and turn has a supporting pillar")
			check(options.size()==run.next_rooms().size(),"every live choice has a real-world exit sign")
			for option: Dictionary in options:
				check(run.move_path(option.anchor).size()>1,"exit sign anchor is on a reachable branch")
				check(not EXITS.following(run,option.id).is_empty(),"exit sign reveals subsequent node types")
			check(run.current_room=="start" and not run.travel.departed,"reading signs never commits a route")
	for kind: String in ["gallery","covered","pier","arch"]: check(kinds.has(kind),"approved "+kind+" models receive placements")
	print("[CompactPassages] ",{"checks":checks,"failures":failures,"spans":total,"kinds":kinds.keys()})
	get_tree().quit(0 if failures.is_empty() else 1)
