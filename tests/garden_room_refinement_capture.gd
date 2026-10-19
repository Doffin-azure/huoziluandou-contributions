extends Node
## Focused native-render check: shared room renderer, enclosure and real walking.
const RUN = preload("res://src/expedition/room_run_state.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-17-refined-rooms"
var failures: Array = []


func _ready() -> void:
	get_window().size = Vector2i(1600,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	Router.host = host
	var run := RUN.new()
	run.reset({"seed":17})
	run.autosave = false
	for room: Dictionary in run.layout.rooms.values():
		var terrace: bool = room.enclosure=="terrace"
		if room.rail_sides.size()!=(4 if terrace else 0): failures.append("mixed enclosure: "+room.route_id)
		if terrace and room.ports.any(func(port): return port.frame!="open"): failures.append("isolated wall gate on terrace")
	Router.goto(RUN.MAP_SCREEN)
	await frames(20)
	await capture("12-runtime-start")
	# The public walking path must still reach the first battle through real gates.
	var view: Control = Router.current.map_view
	if not view.walk_to_room("opening_1"): failures.append("first room not walkable")
	for i in 1600:
		await get_tree().process_frame
		if run.phase=="encounter": break
	if run.phase!="encounter": failures.append("battle threshold did not trigger")
	view._distance = 18
	await frames(18)
	await capture("13-runtime-battle")
	# Stage a water room, then use its normal quarter-grid movement to enter the
	# open pavilion; do not teleport the render-only walker past a solid building.
	var treasure_id := ""
	for id: String in run.graph.rooms:
		if run.graph.rooms[id].kind=="treasure": treasure_id = id; break
	run.current_room = treasure_id
	run.visited_rooms[treasure_id] = true
	run.resolved[treasure_id] = true
	run.position = run.layout.rooms[treasure_id].stand_cell
	run.phase = "map"
	Router.goto(RUN.MAP_SCREEN)
	await frames(18)
	view = Router.current.map_view
	view._distance = 14
	await frames(12)
	await capture("14-runtime-water-pavilion")
	var room: Dictionary = run.layout.rooms[treasure_id]
	var point: Vector2 = room.transform*Vector2(2,.35)
	if not view.walk_to(run.layout.nearest(point,treasure_id)): failures.append("pavilion bypass not walkable")
	for i in 700:
		await get_tree().process_frame
		if not view._moving: break
	var near_exit: Vector2 = room.transform.affine_inverse()*run.layout.point(run.position)
	if near_exit.distance_to(Vector2(2,.35))>.35: failures.append("pavilion passage blocked")
	# The exit itself is outside the roof in a rotated room; walk back under it
	# before requiring a fade. Clear roofs must remain opaque at the exit.
	var roof_point: Vector2 = room.transform*Vector2(2,.75)
	if not view.walk_to(run.layout.nearest(roof_point,treasure_id)): failures.append("cannot step under roof")
	for i in 300:
		await get_tree().process_frame
		if not view._moving: break
	await frames(45)
	var visual: Node3D = view.room_roots[treasure_id]
	visual.update_occlusion(view.walker.global_position,view.camera)
	var faded_roof: bool = visual.occluders.any(func(item): return item.roof and item.faded)
	if not faded_roof: failures.append("pavilion roof does not fade above player")
	await capture("15-runtime-local-occlusion")
	print("[RoomRefinement] real gate walking, pavilion bypass, coherent enclosure, local roof fade=",faded_roof," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(name+".png"))
