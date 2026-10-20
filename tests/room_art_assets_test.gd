extends Node
## 房间模式美术接入：事件插图、字肆抽屉肖像、3D 字肆店主。
const RUN = preload("res://src/expedition/room_run_state.gd")
const EVENTS = preload("res://src/core/event_effects.gd")
var failures: Array = []
var checks := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)


func _ready() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var run = RUN.new(); run.reset({"seed": 17}); run.autosave = false
	var event_id := ""
	var shop_id := ""
	for id: String in run.graph.rooms:
		if event_id.is_empty() and run.graph.rooms[id].kind == "event": event_id = id
		if shop_id.is_empty() and run.graph.rooms[id].kind == "shop": shop_id = id
	check(not event_id.is_empty(), "生成事件房")
	check(not shop_id.is_empty(), "生成商店房")

	run.current_room = event_id
	run.visited_rooms[event_id] = true
	run.event_data = EVENTS.get_event("ink_pool").duplicate(true)
	run.event_node = "start"; run.phase = "event"
	Router.goto(RUN.MAP_SCREEN)
	await _wait_built()
	var screen: Control = Router.current
	check(_has_texture(screen.choices_box, "res://assets/events/ink_pool.png"), "事件抽屉加载插图")

	Router.goto("res://src/screens/title_screen.gd")
	await frames(2)
	var run2 = RUN.new(); run2.reset({"seed": 17}); run2.autosave = false
	for id: String in run2.graph.rooms:
		if run2.graph.rooms[id].kind == "shop": shop_id = id; break
	run2.current_room = shop_id; run2.visited_rooms[shop_id] = true; run2._start_shop()
	Router.goto(RUN.MAP_SCREEN)
	await _wait_built()
	screen = Router.current
	check(_has_texture(screen.choices_box, "res://assets/characters/shopkeeper/portrait.png"), "字肆抽屉加载店主肖像")
	var sprite_found := false
	for node in screen.map_view.world.find_children("*", "Sprite3D", true, false):
		if node.texture != null and node.texture.resource_path == "res://assets/characters/shopkeeper/portrait.png": sprite_found = true
	check(sprite_found, "3D 字肆店主已装配")
	print("[RoomArtAssets] checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func _wait_built() -> void:
	await frames(6)
	var screen: Control = Router.current
	for _i in 180:
		if screen.map_view != null and not screen.map_view._building: break
		await frames(1)
	await frames(8)


func _has_texture(root: Control, path: String) -> bool:
	for node in root.find_children("*", "TextureRect", true, false):
		if node.texture != null and node.texture.resource_path == path: return true
	return false


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame
