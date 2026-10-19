extends Node
const GRAPH = preload("res://src/expedition/room_route_graph.gd")
const RUN = preload("res://src/expedition/room_run_state.gd")
var failures: Array = []
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)

func _ready() -> void:
	for seed_value in [1,17,2026,818]:
		var graph := GRAPH.generate(seed_value)
		var layout := preload("res://src/expedition/garden_room_layout.gd").new()
		check(layout.build(graph),"generated physical layout seed="+str(seed_value)+": "+layout.error)
		check(graph.rooms.size()>=16 and graph.rooms.size()<=22,"room budget")
		for path: Array in GRAPH.paths(graph):
			var fights := 0
			for id: String in path:
				if graph.rooms[id].kind in ["battle","elite","boss"]: fights += 1
			check(path.size()>=10 and path.size()<=13 and fights>=5 and fights<=7,"path budget")
	var run := RUN.new()
	run.reset({"seed":17})
	check(run.generation_error.is_empty(),"layout: "+run.generation_error)
	if run.generation_error.is_empty():
		check(run.enter_room("boss").ok==false,"cannot skip to boss")
		check(run.enter_room("opening_1").ok,"first room reachable")
		check(run.phase=="encounter","arrival triggers encounter")
		run.begin_live_battle(); run.finish_live_battle(true)
		var before := GameState.gold
		run.finish_live_battle(true)
		check(GameState.gold==before,"battle settlement once")
		run.apply({"type":"skip"})
		check(run.enter_room("opening_2").ok,"second room reachable")
		run.begin_live_battle(); run.finish_live_battle(true); run.apply({"type":"skip"})
		var branch: Array = run.graph.groups[0].branches[0]
		check(run.enter_room(branch[0]).ok,"fork threshold reachable")
		var rejected: Array = run.graph.groups[0].branches[1]
		check(run.sealed.has(rejected[0]),"other branch sealed")
		run.begin_live_battle(); run.finish_live_battle(true)
		check(run.save_run("user://room-route-test.tres")==OK,"save reward")
		var restored = RUN.restore("user://room-route-test.tres")
		check(restored!=null,"restore")
		if restored!=null:
			check(restored.phase=="reward" and restored.current_room==branch[0] and restored.sealed==run.sealed,"restore room/branch/reward")
	# Exercise the actual navigation through every path of a generated act,
	# without replaying battles whose resolver is unchanged.
	for route: Array in GRAPH.paths(GRAPH.generate(17)):
		run.reset({"seed":17}); run.autosave = false
		for id: String in route.slice(1):
			var travel: Dictionary = run.enter_room(id)
			check(travel.ok,"route navigation to "+id+": "+str(travel))
			if not travel.ok: break
			match run.phase:
				"encounter": run.begin_live_battle(); run.finish_live_battle(true); run.apply({"type":"skip"})
				"reward": run.apply({"type":"skip"})
				"shop": run.apply({"type":"shop_leave"})
				"event": run.apply({"type":"event","index":run.event_data.get("options",[]).size()-1})
				"rest": run.apply({"type":"leave_service"})
		check(run.phase=="act_end","complete generated act")
		for rejected: String in run.sealed:
			check(not run.walkable(run.layout.rooms[rejected].stand_cell),"sealed branch remains inaccessible from merge")
	# Service persistence and next-act transition use the same state object.
	run.reset({"seed":17}); run.autosave = false
	var shop_id := ""
	for id: String in run.graph.rooms:
		if run.graph.rooms[id].kind=="shop": shop_id = id; break
	run._arrive(shop_id); GameState.gold = 99
	var initial_stock := run.shop_offers.size()
	run.apply(run.legal_actions()[0])
	check(run.shop_offers.size()==initial_stock-1,"shop purchase consumes stock")
	check(run.save_run("user://room-route-service-test.tres")==OK,"save service stock")
	var service = RUN.restore("user://room-route-service-test.tres")
	check(service!=null and service.shop_offers.size()==initial_stock-1,"restore service stock")
	run.phase = "act_end"
	run.apply({"type":"next_act"})
	check(GameState.act_index==2 and run.current_room=="start" and run.phase=="map","second act starts at its own room")
# 宝箱直接掉普通遗物，不进入选字奖励。
	run.reset({"seed":17}); run.autosave = false
	var treasure_id := ""
	for id: String in run.graph.rooms:
		if run.graph.rooms[id].kind=="treasure": treasure_id = id; break
	check(not treasure_id.is_empty(),"has treasure room")
	if not treasure_id.is_empty():
		var before_relics: int = GameState.relics.size()
		run._arrive(treasure_id)
		check(run.phase=="map" and GameState.relics.size()==before_relics+1,"treasure drops one normal relic")
		check(not Relics.is_event_relic(str(GameState.relics[-1])),"treasure never drops event-pool relic")
	# 事件选项可以附带即时宝箱。
	run.reset({"seed":17}); run.autosave = false
	run.phase = "event"; run.event_node = "start"
	run.event_data = {"id":"test_spawn_treasure","title":"藏匣","body":"","options":[{"text":"打开","spawn":"treasure","effects":[]}]}
	var before_event_relics: int = GameState.relics.size()
	var spawn_treasure: Dictionary = run._apply_event({"index":0})
	check(spawn_treasure.get("ok",false) and run.phase=="map" and GameState.relics.size()==before_event_relics+1,"event can spawn treasure drop")
	# 事件选项可以附带即时战斗。
	run.reset({"seed":17}); run.autosave = false
	run.phase = "event"; run.event_node = "start"
	run.event_data = {"id":"test_spawn_battle","title":"拦路","body":"","options":[{"text":"迎战","spawn":"battle","effects":[]}]}
	var spawn_battle: Dictionary = run._apply_event({"index":0})
	check(spawn_battle.get("ok",false) and run.phase=="encounter" and run.node != null and run.spawned_battle,"event can spawn a battle encounter")
	check(run.begin_live_battle() and run.phase=="battle","spawned battle can start")
	print("[RoomRoute] checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
