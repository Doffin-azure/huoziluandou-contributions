extends Control
## Real catalog costs and saved opt-in rewards, including destructive pickup effects.
const RUN = preload("res://src/expedition/room_run_state.gd")
const EFFECTS = preload("res://src/core/event_effects.gd")
const SAVE := "user://event-reward-audit.tres"
var run: RefCounted
var checks := 0
var failures := 0


func _ready() -> void:
	SaveManager.enabled = false
	GameState.set_meta("courtyard_preview",true)
	Settings.reduced_motion = true
	Engine.max_fps = 240
	get_tree().create_timer(60).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)


func frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func prepare(event_id: String) -> void:
	run = RUN.new()
	run.reset({"seed":8144,"layout":"node_graph"})
	for id: String in run.graph.rooms:
		if run.graph.rooms[id].kind=="event": run._arrive(id); break
	run.event_data = EFFECTS.get_event(event_id).duplicate(true)
	run.event_node = "start"
	run._sync_content()


func only_chaos() -> void:
	# Reserve other IDs without triggering their pickup effects.
	GameState.relics = Relics.normal_pool().filter(func(id):return id!="chaos_dice")


func deck_ids() -> Array:
	return GameState.deck.map(func(c): return c.uid)


func offer() -> ChoiceOverlay:
	for child in Router.current.get_children():
		if child is ChoiceOverlay and child.name=="EventRelicOffer" and not child.is_queued_for_deletion(): return child
	return null


func open_event(saved: Dictionary = {}) -> void:
	Router.goto("res://src/screens/event_screen.gd",{"room_run":true,"_saved_screen":saved})
	await frames()


func _run() -> void:
	Router.host = self
	get_window().size = Vector2i(1280,720)
	# The reported option previously inflicted 4 current HP damage and never paid max HP.
	for hp in [1,20,60]:
		prepare("floating_lantern")
		GameState.player_hp = hp
		var result: Dictionary = run.apply({"type":"event","index":0})
		check(result.ok and GameState.player_max_hp==56 and GameState.player_hp==mini(56,hp+20),"floating lantern spends 4 maximum HP and heals 20 at HP %d" % hp)
		check(run.phase=="map","floating lantern completes normally")
	prepare("floating_lantern")
	GameState.player_hp = 20; GameState.event_temp_hp = 8
	run.apply({"type":"event","index":0})
	check(GameState.player_max_hp==56 and GameState.player_hp==40,"temporary HP cannot pay a maximum HP cost")
	check(run.save_run(SAVE)==OK,"maximum HP change can be saved")
	run = RUN.restore(SAVE)
	check(GameState.player_max_hp==56 and GameState.player_hp==40,"maximum HP cost survives reload")

	# Random loot must not rebuild the deck before the player sees what it is.
	prepare("buy_case"); only_chaos()
	var original := deck_ids()
	await open_event()
	Router.current._choose(0); await frames()
	check(run.phase=="event_relic" and not GameState.has_relic("chaos_dice") and deck_ids()==original,"random chaos relic is offered before any destructive pickup")
	check(GameState.player_hp==54 and offer()!=null,"event cost settles once and the actual relic preview appears")
	var bar: Control = Router.current.inventory_bar
	var point: Vector2 = bar.buttons.deck.get_global_rect().get_center()
	for down in [true,false]:
		var click := InputEventMouseButton.new()
		click.position = point; click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT; click.pressed = down
		get_viewport().push_input(click,true); await frames(2)
	var blocked := is_instance_valid(bar) and bar._overlay==null and offer()!=null
	check(blocked,"backdrop clicks neither open inventory nor silently discard the relic")
	if not blocked: get_tree().quit(1); return
	check(offer().cfg.relic_id=="chaos_dice" and offer().cfg.body.contains(Relics.desc_of("chaos_dice")) and offer().cfg.options.size()==2 and offer().cfg.cancel_index==1,"preview shows the drawn relic and Escape declines it")
	check(run.observe().event.relic_offers==["chaos_dice"] and run.legal_actions().size()==2,"automation exposes take and skip for the same item")
	var rolled_rng: int = GameState.rng.state
	check(run.save_run(SAVE)==OK,"unclaimed event relic can be saved")
	run = RUN.restore(SAVE)
	await open_event({"event":EFFECTS.get_event("ink_pool")})
	check(Router.current._room_session.current() and Router.current._event.id=="buy_case" and offer()!=null,"room restore uses saved controller state rather than a stale classic screen snapshot")
	check(run.pending_event_relics==["chaos_dice"] and GameState.rng.state==rolled_rng and GameState.player_hp==54,"reload never rerolls the item or repeats its cost")
	offer()._on_choose(1); await frames()
	check(run.phase=="map" and not GameState.has_relic("chaos_dice") and deck_ids()==original and GameState.player_hp==54,"declining preserves the deck and the paid cost")
	check(not run.apply({"type":"event_relic_take"}).ok,"a declined find cannot later be claimed by a stale callback")

	prepare("buy_case"); only_chaos(); original = deck_ids()
	await open_event(); Router.current._choose(0); await frames()
	offer()._on_choose(0); await frames()
	check(GameState.has_relic("chaos_dice") and GameState.deck_size()==original.size()+3,"confirming chaos applies its intended reforge once")
	check(GameState.deck.all(func(c):return not original.has(c.uid)),"only confirmation replaces the old deck entities")
	check(not run.apply({"type":"event_relic_take"}).ok and GameState.deck_size()==original.size()+3,"repeated confirmation cannot reforge or add another three cards")

	prepare("snatch_gold"); only_chaos(); GameState.player_hp = 20
	var snatch: Dictionary = run.apply({"type":"event","index":0})
	check(snatch.ok and run.phase=="event_relic" and GameState.player_max_hp==57 and GameState.player_hp==20,"nested random reward pays maximum HP instead of current HP")
	run.apply({"type":"event_relic_skip"})
	check(GameState.player_max_hp==57 and GameState.player_hp==20,"declining nested loot does not erase its maximum HP cost")
	prepare("purge_mirror"); GameState.player_hp = 20
	GameState.add_character(Database.get_character("debt"),2)
	run.apply({"type":"event","index":0})
	check(GameState.player_max_hp==57 and GameState.player_hp==20 and GameState.deck.all(func(c):return not c.data.is_pollution),"purge mirror pays maximum HP and removes all pollution")

	# Chance failure produces its fallback, never a hidden relic.
	for success in [false,true]:
		prepare("jade_case"); only_chaos(); run.event_node = "one"
		var probe := RandomNumberGenerator.new()
		for value in 100:
			probe.seed = value
			if (probe.randf()<0.25)==success: GameState.rng.seed = value; break
		var gold := GameState.gold
		run.apply({"type":"event","index":1})
		check(run.phase==("event_relic" if success else "map") and not GameState.has_relic("chaos_dice"),"jade case chance result is preserved without automatic pickup")
		check(GameState.gold==gold+(0 if success else 10),"jade case only pays its stated failure fallback")
		if success: run.apply({"type":"event_relic_skip"})

	# Removing a rare letter still waits for all targets; only then is loot rolled.
	prepare("return_brush"); only_chaos()
	var rare: CharacterData
	for c: CharacterData in Database.characters.values():
		if c.rarity>=2 and not c.is_pollution and not c.pending_design and not c.tags.has("enemy"): rare = c; break
	GameState.add_character(rare)
	run.apply({"type":"event","index":0})
	check(run.phase=="event_choose" and bool(run.pending_event_effect.offer_relics),"pending removal retains optional loot semantics")
	run.pending_event_effect.erase("offer_relics") # A pending picker saved by an older build.
	check(run.save_run(SAVE)==OK,"legacy pending removal can be saved without the new opt-in field")
	run = RUN.restore(SAVE)
	run.apply({"type":"pick","glyph":rare.glyph})
	check(run.phase=="event_relic" and not GameState.has_relic("chaos_dice"),"legacy removal reward also waits for pickup consent after reload")
	run.apply({"type":"event_relic_skip"})
	check(run.phase=="map","removal event finishes after declining its loot")

	prepare("battle_relic"); only_chaos(); original = deck_ids()
	run.apply({"type":"event","index":0}); run.begin_live_battle(); run.finish_live_battle(true)
	check(run.phase=="event_relic" and deck_ids()==original and not GameState.has_relic("chaos_dice"),"event battle win does not force its random reward into the deck")
	check(run.save_run(SAVE)==OK,"post-battle event reward can be saved")
	run = RUN.restore(SAVE)
	check(run.phase=="event_relic" and run.pending_event_relics==["chaos_dice"],"post-battle offer survives reload without respawning the battle")
	run.apply({"type":"event_relic_skip"})
	check(run.phase=="map" and not run.spawned_battle and not GameState.has_relic("chaos_dice"),"declining event battle loot completes the encounter")

	# Main-route treasure used to trigger pickup before even showing its receipt.
	for take in [false,true]:
		prepare("ink_pool"); only_chaos(); original = deck_ids()
		for id: String in run.graph.rooms:
			if run.graph.rooms[id].kind=="treasure": run._arrive(id); break
		check(run.phase=="treasure" and not GameState.has_relic("chaos_dice") and deck_ids()==original,"treasure reveals its item without pickup")
		check(run.save_run(SAVE)==OK,"unclaimed treasure can be saved")
		run = RUN.restore(SAVE)
		var result: Dictionary = run.apply({"type":"treasure_ack" if take else "treasure_skip"})
		check(result.ok and run.phase=="map" and GameState.has_relic("chaos_dice")==take,"treasure allows explicit acceptance or refusal after reload")
		check(GameState.deck_size()==original.size()+(3 if take else 0),"treasure only reforges on explicit pickup")

	# Accepting loot must retain upstream's saved character-selection setup queue.
	for source in ["event", "treasure"]:
		prepare("buy_case")
		GameState.relics = Relics.normal_pool().filter(func(id):return id!="goldleaf")
		if source=="event": run.apply({"type":"event","index":0})
		else:
			for id: String in run.graph.rooms:
				if run.graph.rooms[id].kind=="treasure": run._arrive(id); break
		var result: Dictionary = run.apply({"type":"event_relic_take" if source=="event" else "treasure_ack"})
		check(result.ok and Relics.next_pending_peek()=="goldleaf","%s acceptance preserves pending character setup" % source)
		check(run.save_run(SAVE)==OK,"%s setup can be saved before its picker completes" % source)
		run = RUN.restore(SAVE)
		check(Relics.next_pending_peek()=="goldleaf","%s setup survives reload before selection" % source)

	prepare("buy_case")
	GameState.relics = Relics.normal_pool().filter(func(id):return id!="slab")
	await open_event(); Router.current._choose(0); await frames()
	offer()._on_choose(0); await frames()
	var binding: CollectionOverlay
	for child in Router.current.get_children():
		if child is CollectionOverlay: binding = child
	check(binding!=null and GameState.has_relic("slab"),"accepted binding relic opens its character picker")
	var chosen: CharacterData = GameState.deck[-1].data
	if binding!=null: binding._on_card_clicked(chosen)
	await frames()
	check(run.phase=="map" and GameState.relic_bound_inst("slab").id()==chosen.id,"the player can select the binding instead of keeping the automatic fallback")
	check(run.save_run(SAVE)==OK,"completed binding can be saved")
	run = RUN.restore(SAVE)
	check(GameState.relic_bound_inst("slab").id()==chosen.id,"the selected binding survives reload")

	prepare("buy_case"); only_chaos(); GameState.player_hp = 1
	await open_event(); Router.current._choose(0); await frames()
	check(run.phase=="defeat" and run.pending_event_relics.is_empty() and not GameState.has_relic("chaos_dice"),"lethal event cost never opens a pickup offer")
	check(Router.current_path.ends_with("run_result_screen.gd") and not GameState.last_run_result.get("victory",true),"lethal event cost enters unified defeat instead of continuing at zero HP")

	# The named risky event is a deliberate choice and retains its stated effect.
	prepare("chaos_dice"); original = deck_ids()
	run.apply({"type":"event","index":0})
	check(run.phase=="map" and GameState.has_relic("chaos_dice") and GameState.deck_size()==original.size()+3,"explicitly choosing the chaos event still reforges the deck")

	# Classic screen checkpoints also preserve the revealed result and cost.
	prepare("buy_case"); only_chaos(); GameState.room_run = null
	Router.goto("res://src/screens/event_screen.gd",{"_saved_screen":{"event":EFFECTS.get_event("buy_case").duplicate(true)}})
	await frames(); Router.current._choose(0); await frames()
	var checkpoint: Dictionary = Router.current.save_checkpoint()
	check(not checkpoint.is_empty() and checkpoint.screen.relic_offers==["chaos_dice"] and GameState.player_hp==54,"classic screen checkpoints the paid cost and unclaimed relic")
	Router.goto("res://src/screens/event_screen.gd",{"_saved_screen":checkpoint.screen})
	await frames()
	check(offer()!=null and GameState.player_hp==54 and not GameState.has_relic("chaos_dice"),"classic reload restores the offer without repaying or pickup")
	offer()._on_choose(1); await frames()
	check(not GameState.has_relic("chaos_dice") and GameState.player_hp==54,"classic event can also decline destructive loot")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("[event_reward_audit_test] CHECKS=%d FAIL=%d EVENTS=%d" % [checks,failures,EFFECTS.all().size()])
	Music.stop()
	get_tree().quit(0 if failures==0 else 1)
