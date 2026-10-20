extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const EVENTS = preload("res://src/core/event_effects.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-19-horizontal-node-map"
var checks := 0
var failures: Array = []
var run: RefCounted
var identity := 0


func _ready() -> void: run_checks.call_deferred()


func run_checks() -> void:
	GameState.set_meta("courtyard_preview",true)
	Settings.reduced_motion = true; Engine.max_fps = 120
	get_window().size = Vector2i(1920,1080)
	var host := Control.new(); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(host); Router.host = host
	run = RUN.start(29); Router.goto(RUN.MAP_SCREEN)
	await frames(12)
	identity = Router.current.get_instance_id()
	var map: Control = Router.current
	check(map.find_children("*","SubViewport",true,false).is_empty(),"2D map has no 3D viewport")
	var before: int = GameState.rng.state
	var geometry: Dictionary = map.map_view.points.duplicate()
	check(not map._action.visible and map.map_view.size.y>map.size.y*.8,"initial map fills the screen without a detail footer or unavailable travel action")
	var far: String = run.graph.boss
	map._select_node(far)
	check(run.planned_route.is_empty() and not map._action.visible,"inspecting a distant node does not invent a route or enable travel")
	map._toggle_planning()
	for i in 3: map._select_node(run.plan_choices()[0])
	map._toggle_planning()
	check(run.planned_route.size()==3 and GameState.rng.state==before and run.current_room=="start","three map clicks plan three stops without entering a node or consuming RNG")
	var planned: Array = run.planned_route.duplicate()
	map._select_node(planned[0])
	check(run.planned_route==planned,"inspecting an already planned stop preserves the rest of the route")
	var enemy_name: String = run.battle_node(planned[0]).enemies[0].name
	var labels := map.find_children("*","Label",true,false)
	check(labels.all(func(label):return not enemy_name in label.text),"selecting a battle node does not reveal its enemy in the map UI")
	await frames(4)
	check(map.map_view.points==geometry,"selecting a route keeps the map geometry stable")
	await frames(4); await snap("node-map-1920.png")
	get_window().size = Vector2i(1280,720); await frames(10)
	check(Rect2(Vector2.ZERO,map.size).encloses(map._action.get_global_rect()),"720p action fits viewport")
	await snap("node-map-1280.png")
	get_window().size = Vector2i(1600,720); await frames(10)
	check(Rect2(Vector2.ZERO,map.size).encloses(map._action.get_global_rect()),"wide landscape action fits viewport")
	await snap("node-map-landscape.png")
	get_window().size = Vector2i(844,390); await frames(12)
	check(map.map_view.get_global_rect().encloses(map._tools.get_global_rect()),"phone landscape keeps floating controls inside the map")
	check(Rect2(Vector2.ZERO,map.size).encloses(map._stats.get_global_rect()),"phone landscape keeps the player stats inside the viewport")
	var physical_scale := float(get_window().size.y)/map.get_viewport_rect().size.y
	check(map._action.size.y*physical_scale>=47.9 and map._view_button.size.y*physical_scale>=47.9,"resized phone actions retain physical touch target height")
	await snap("node-map-phone.png")
	get_window().size = Vector2i(1280,720); await frames(8)
	map.map_view.focus_current(); await frames(2)
	var points: Dictionary = map.map_view.points.duplicate()
	map._open_deck(); await frames(2); picker_of(map)._close(); await frames(2)
	check(map.map_view.points==points,"viewing the deck does not move the route scroll")
	var first: String = run.next_rooms()[0]
	map._select_node(first); map._confirm_selected(); await frames(16)
	check(Router.current_path.ends_with("battle_screen.gd") and run.phase=="battle","confirm enters real combat")
	# Resolve combat directly: combat mechanics have their own regression suite.
	run.finish_live_battle(true)
	Router.goto("res://src/screens/reward_screen.gd",{"room_run":true,"node":run.node}); await frames(12)
	var reward: Control = Router.current
	var reward_deck_size := GameState.deck_size()
	var chosen: CharacterData = reward._options[1]
	var chosen_count := int(GameState.glyph_counts().get(chosen.glyph,0))
	reward._inspect(1); reward._accept_pick(); await frames(10)
	check_cached()
	check(GameState.deck_size()==reward_deck_size+1 and int(GameState.glyph_counts().get(chosen.glyph,0))==chosen_count+1,"reward reaches the deck once")
	Router.current.map_view.show_overview(); await frames(4); await snap("node-map-progress.png")
	var id := prepare("event")
	run.event_data = EVENTS.get_event("old_bookshop").duplicate(true); run.event_node = "start"; run._sync_content()
	before = GameState.rng.state
	Router.current.refresh(); await frames(10)
	check(Router.current_path.ends_with("event_screen.gd") and GameState.rng.state==before,"full event UI uses cached event")
	await snap("event.png")
	var deck_before := GameState.deck_size()
	Router.current._choose(0); await frames(3)
	var picker := picker_of(Router.current)
	check(picker!=null and run.phase=="event_choose","event opens saved glyph choice")
	if picker==null: finish(); return
	picker._on_card_clicked(Database.get_character_by_glyph(run.pending_glyphs[0])); await frames(10)
	check(GameState.deck_size()==deck_before-1 and run.resolved.has(id),"event settlement removes exactly one glyph")
	check_cached()
	prepare("shop"); GameState.gold = 200; run._sync_content()
	before = GameState.rng.state
	Router.current.refresh(); await frames(14)
	check(Router.current_path.ends_with("shop_screen.gd") and GameState.rng.state==before,"shop shows saved stock")
	await snap("shop.png")
	var gold_before := GameState.gold
	Router.current._refresh_stock(); await frames(4)
	check(GameState.gold==gold_before-5 and Router.current._offers==run.shop_offers.map(func(o):return o.merged({"display_slot":run.shop_offers.find(o)})),"UI refresh updates the saved stock and charges 5")
	Router.current._leave(); await frames(10); check_cached()
	id = prepare("rest"); GameState.player_hp = 1; Router.current.refresh(); await frames(10)
	check(Router.current_path.ends_with("rest_screen.gd"),"rest opens full option cards")
	await snap("rest.png")
	Router.current._do_heal(); await frames(10)
	check(GameState.player_hp>1 and run.resolved.has(id),"rest heals and completes its own node")
	check_cached()
	id = prepare("treasure"); Router.current.refresh(); await frames(5)
	var receipt := choice_of(Router.current)
	check(receipt!=null and run.phase=="treasure","treasure displays a receipt before continuing")
	await snap("treasure.png")
	if receipt!=null: receipt._on_choose(0)
	await frames(3)
	# Expanded relics may require two picks, a wish, then another glyph pick.
	for _step in 8:
		if run.phase != "treasure": break
		var binding := picker_of(Router.current)
		if binding != null: binding._close()
		else:
			var followup := choice_of(Router.current)
			if followup != null: followup._on_choose(0)
		await frames(3)
	await frames(6)
	check(run.resolved.has(id) and run.phase=="map","treasure settles once")
	check_cached()
	finish()


func prepare(kind: String) -> String:
	for id: String in run.graph.rooms:
		if run.graph.rooms[id].kind==kind and not run.resolved.has(id):
			run._arrive(id); return id
	return ""


func check_cached() -> void:
	check(Router.current_path==RUN.MAP_SCREEN and Router.current.get_instance_id()==identity,"returns to same 2D map instance")


func picker_of(screen: Control) -> CollectionOverlay:
	for child in screen.get_children():
		if child is CollectionOverlay and not child.is_queued_for_deletion(): return child
	return null


func choice_of(screen: Control) -> ChoiceOverlay:
	for child in screen.get_children():
		if child is ChoiceOverlay and not child.is_queued_for_deletion(): return child
	return null


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func snap(filename: String) -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(filename))


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)


func finish() -> void:
	print("[node_route_runtime] CHECKS=%d FAIL=%d" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
