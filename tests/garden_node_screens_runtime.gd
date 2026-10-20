extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
const EFFECTS = preload("res://src/core/event_effects.gd")
const OUTPUT := "res://docs/art-concepts/2026-10-19-courtyard-restored"
var checks := 0
var failures: Array = []
var run: RefCounted
var map_identity := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)


func _ready() -> void: run_checks.call_deferred()


func run_checks() -> void:
	Engine.max_fps = 120; Settings.reduced_motion = true
	get_window().size = Vector2i(1280,720)
	var host := Control.new(); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(host); Router.host = host
	run = RUN.new(); run.reset({"seed":29,"layout":"compact_garden"}); run.autosave = false
	Router.goto(RUN.MAP_SCREEN)
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		await frames(1)
		if not Router.current.map_view._building: break
	check(not Router.current.map_view._building,"map is ready")
	if Router.current.map_view._building: get_tree().quit(1); return
	await frames(20); map_identity = Router.current.map_view.get_instance_id()
	Router.current.map_view.recenter(); await frames(20); await snap("entrance-roof-and-furniture.png")
	var root: Node3D = Router.current.map_view.authored_root
	var start_house: Dictionary = root.houses.filter(func(house):return house.bounds==run.layout.rooms.start.bounds)[0]
	check(start_house.node.roof_parts.size()>0 and start_house.node._roof_alpha==0,"entrance retains its opaque roof")
	check(start_house.node._aperture_open,"only the walker aperture cuts through roof")
	check(root._node_roots.start.find_children("*","Node3D",true,false).any(func(mesh):return mesh.get_meta("interior_prop","")=="writing_desk"),"approved writing desk is in entrance")
	var entry_nodes: Array = root._node_roots.start.find_children("*","Node3D",true,false)
	check(entry_nodes.any(func(node):return node.get_meta("garden_tombstone",false)),"entry court uses the production tombstone asset")
	check(entry_nodes.any(func(node):return node.get_script()==preload("res://src/map/expedition_stylized_fire.gd") and node.ghost_fire),"entry court uses the production ghost-fire asset")
	var paper_meshes: Array = start_house.node.find_children("*","MeshInstance3D",true,false).filter(func(mesh):return str(mesh.get_meta("garden_role",""))=="garden_paper")
	check(not paper_meshes.is_empty(),"roofed hall lattice includes a paper-backed window mesh")
	# Fixtures jump directly to each node to inspect its production UI. Physical
	# walking, branch rules and all three acts are covered by the compact tests.
	var room := prepare("event")
	run.event_data = EFFECTS.get_event("old_bookshop").duplicate(true); run.event_node = "start"
	var rng_before: int = GameState.rng.state
	Router.current.refresh(); await frames(14)
	check(Router.current_path.ends_with("event_screen.gd") and Router.current._event.title==run.current_event().title,"event opens existing full-page art and choices")
	check(GameState.rng.state==rng_before,"opening event UI does not reroll it")
	await snap("event.png")
	var deck_before: int = GameState.deck_size()
	Router.current._choose(0); await frames(6)
	check(run.phase=="event_choose","event choice uses courtyard pending effect")
	var picker := picker_of(Router.current)
	check(picker!=null,"event opens shared glyph picker")
	if picker==null: get_tree().quit(1); return
	picker._on_card_clicked(Database.get_character_by_glyph(run.pending_glyphs[0])); await frames(15)
	check(GameState.deck_size()==deck_before-1 and run.resolved.has(room),"event picker removes exactly one glyph and settles node")
	check_cached()
	room = prepare("shop"); GameState.gold = 200
	var stock: Array = run.shop_offers.duplicate(true); rng_before = GameState.rng.state
	Router.current.refresh(); await frames(18)
	check(Router.current_path.ends_with("shop_screen.gd") and Router.current._offers.size()==stock.size(),"shop opens existing object stage with saved stock")
	check(GameState.rng.state==rng_before,"opening shop does not reroll stock")
	await snap("shop.png")
	deck_before = GameState.deck_size()
	var gold_before: int = GameState.gold; var price: int = stock[0].price
	Router.current._buy(0); await frames(6)
	check(GameState.gold==gold_before-price and GameState.deck_size()==deck_before+1 and run.shop_offers.size()==stock.size()-1,"shop purchase pays and removes saved offer once")
	var copy_index := -1
	for i in run.shop_offers.size():
		if run.shop_offers[i].kind=="copy": copy_index = i; break
	Router.current._buy(copy_index); await frames(4)
	check(run.phase=="shop_choose","shop copy enters saved pending picker")
	gold_before = GameState.gold
	picker = picker_of(Router.current); picker._close(); await frames(5)
	check(run.phase=="shop_choose" and GameState.gold==gold_before and picker_of(Router.current)!=null,"closing paid picker cannot discard service or charge again")
	picker_of(Router.current)._on_card_clicked(Database.get_character_by_glyph(run.pending_glyphs[0])); await frames(5)
	check(run.phase=="shop" and GameState.deck_size()==deck_before+2,"shop copy returns to same shop")
	Router.current._leave(); await frames(15); check_cached()
	room = prepare("rest"); GameState.player_hp = 1
	Router.current.refresh(); await frames(12)
	check(Router.current_path.ends_with("rest_screen.gd"),"rest opens full option cards")
	await snap("rest.png")
	var amount: int = run._heal_amount()
	Router.current._do_heal(); await frames(15)
	check(GameState.player_hp==1+amount and run.resolved.has(room),"rest settles through courtyard controller once")
	check_cached()
	room = prepare("rest")
	Router.current.refresh(); await frames(10); Router.current._do_upgrade(); await frames(5)
	check(run.phase=="rest_choose" and picker_of(Router.current)!=null,"rest upgrade uses persistent glyph choice")
	picker_of(Router.current)._on_card_clicked(Database.get_character_by_glyph(run.pending_glyphs[0])); await frames(15)
	check(run.resolved.has(room),"rest upgrade completes its own node")
	check_cached()
	room = prepare("treasure"); Router.current.refresh(); await frames(18)
	check(Router.current_path.ends_with("reward_screen.gd") and Router.current._hud.heading=="荷池 · 藏字","treasure opens full reward stage")
	await snap("treasure.png")
	deck_before = GameState.deck_size()
	Router.current._accept_pick(); await frames(15)
	check(run.resolved.has(room) and GameState.deck_size()==deck_before+1,"treasure selection reaches deck exactly once")
	check_cached()
	var report := {"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("node-screens-checks.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  "))
	print("[GardenNodeScreens] ",report); get_tree().quit(0 if failures.is_empty() else 1)


func prepare(kind: String) -> String:
	for id: String in run.graph.rooms:
		if run.graph.rooms[id].kind==kind and not run.resolved.has(id):
			run.position = run.layout.rooms[id].stand_cell; run._arrive(id); return id
	return ""


func check_cached() -> void:
	check(Router.current_path==RUN.MAP_SCREEN and Router.current.map_view.get_instance_id()==map_identity and Router.current.map_view.profile.build_count==1,"node UI returns to same garden without rebuilding")


func picker_of(screen: Control) -> CollectionOverlay:
	for child in screen.get_children():
		if child is CollectionOverlay and not child.is_queued_for_deletion(): return child
	return null


func frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture"): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT.path_join(name))
