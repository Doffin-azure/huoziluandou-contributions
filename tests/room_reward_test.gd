extends Node
const RUN = preload("res://src/expedition/room_run_state.gd")
var failures: Array = []
var checks := 0

class RewardProbe extends "res://src/screens/reward_screen.gd":
	var routes: Array = []
	func goto(path: String, _params: Dictionary = {}) -> void:
		routes.append(path)


func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)


func reward_run() -> RefCounted:
	var run := RUN.new()
	run.reset({"seed":17,"layout":"node_graph"})
	run.autosave = false
	run.enter_room(run.next_rooms()[0])
	run.begin_live_battle(); run.finish_live_battle(true)
	return run


func reward_screen(room_mode := true) -> RewardProbe:
	var screen := RewardProbe.new()
	screen.setup({"room_run":room_mode})
	add_child(screen)
	return screen


func _ready() -> void:
	GameState.set_meta("courtyard_preview",true)
	Settings.reduced_motion = true
	var run: RefCounted = reward_run()
	var screen := reward_screen()
	screen._inspect(1)
	var chosen: CharacterData = screen._options[1]
	var before_deck := GameState.deck_size()
	var before_gold := GameState.gold
	screen._hud.action_button.pressed.emit()
	check(run.phase=="map" and GameState.deck_size()==before_deck+1,"real claim button settles the selected glyph into deck")
	check(GameState.deck[-1].glyph()==chosen.glyph and GameState.gold==before_gold,"claim adds the chosen glyph without awarding skip gold")
	check(screen._options.size()==3,"settlement does not erase the screen's option snapshot")
	check(screen.routes==[RUN.MAP_SCREEN],"successful claim leaves reward exactly once")
	screen._accept_pick(); screen._on_skip(); screen._on_pick(chosen)
	check(GameState.deck_size()==before_deck+1 and screen.routes.size()==1 and GameState.gold==before_gold,"repeat claim and skip callbacks cannot settle again")
	check(run.save_run("user://room-reward-test.tres")==OK,"claimed reward saved")
	var restored = RUN.restore("user://room-reward-test.tres")
	check(restored!=null and GameState.deck_size()==before_deck+1 and GameState.deck[-1].glyph()==chosen.glyph and restored.phase=="map","deck reward survives reload")
	if restored!=null:
		restored.autosave = false
		check(restored.reward_options.is_empty() and not restored.apply({"type":"reward","index":1,"glyph":chosen.glyph}).ok,"reload cannot claim cleared reward again")
	screen.queue_free(); await get_tree().process_frame

	run = reward_run()
	for glyph in ["火","火","电","击","防","御"]: GameState.add_character(Database.get_character_by_glyph(glyph))
	screen = reward_screen()
	chosen = screen._options[0]
	before_deck = GameState.deck_size()
	var glyph_count := int(GameState.glyph_counts().get(chosen.glyph,0))
	check(screen._hud.action_button.text=="收入字袋" and not screen._hud.status.contains("字匣"),"reward names the deck without a tray capacity")
	screen._accept_pick()
	check(run.phase=="map","claim resolves its encounter")
	check(GameState.deck_size()==before_deck+1 and int(GameState.glyph_counts().get(chosen.glyph,0))==glyph_count+1,"reward adds exactly the chosen glyph to a larger deck")
	screen.queue_free(); await get_tree().process_frame

	run = reward_run(); screen = reward_screen()
	run.phase = "map" # Simulate a rejected/stale settlement.
	before_deck = GameState.deck_size()
	screen._accept_pick()
	check(screen.routes.is_empty() and GameState.deck_size()==before_deck,"failed claim stays on the reward page without granting a glyph")
	check(not screen._busy and not screen._hud.action_button.disabled and not screen._hud.secondary_button.disabled,"failed claim releases both controls for retry")
	run.phase = "reward"
	screen._accept_pick()
	check(run.phase=="map" and GameState.deck_size()==before_deck+1 and screen.routes.size()==1,"retry after rejection settles once")
	screen.queue_free(); await get_tree().process_frame

	run = reward_run(); screen = reward_screen()
	before_gold = GameState.gold
	before_deck = GameState.deck_size()
	screen._on_skip(); screen._on_skip()
	check(GameState.gold==before_gold+Expedition.SKIP_GOLD and GameState.deck_size()==before_deck and run.phase=="map","skip grants gold once and no glyph")
	check(screen.routes.size()==1,"repeated skip navigates once")
	screen.queue_free(); await get_tree().process_frame

	Settings.reduced_motion = false
	run = reward_run(); screen = reward_screen()
	screen._inspect(2); chosen = screen._options[2]
	before_gold = GameState.gold
	before_deck = GameState.deck_size()
	screen._accept_pick(); screen._on_skip()
	check(GameState.deck_size()==before_deck and screen._busy and screen._hud.secondary_button.disabled,"room animation retains deferred settlement and input lock")
	await wait_for_claim(screen)
	check(run.phase=="map" and GameState.deck_size()==before_deck+1 and GameState.deck[-1].glyph()==chosen.glyph and GameState.gold==before_gold,"animated claim keeps its chosen glyph and blocks skip")
	check(screen.routes.size()==1,"animated claim navigates once")
	screen.queue_free(); await get_tree().process_frame

	# The reward page is shared with the original route; its destination and
	# animation timing must stay intact while fixing courtyard settlement.
	check_legacy_migration()
	Settings.reduced_motion = true
	GameState.start_new_run("v03")
	screen = reward_screen(false)
	before_deck = GameState.deck_size()
	var before_node := GameState.node_index
	screen._accept_pick(); screen._accept_pick(); screen._on_skip()
	check(GameState.deck_size()==before_deck+1 and GameState.node_index==before_node+1,"classic reward still grants one glyph to deck and completes one node")
	check(screen.routes==["res://src/screens/map_screen.gd"],"classic reward keeps original destination")
	screen.queue_free(); await get_tree().process_frame
	GameState.start_new_run("v03")
	Settings.reduced_motion = false
	screen = reward_screen(false)
	before_deck = GameState.deck_size()
	screen._accept_pick(); screen._on_skip()
	check(GameState.deck_size()==before_deck and screen._busy and screen._hud.secondary_button.disabled,"classic animation retains deferred settlement and input lock")
	await wait_for_claim(screen)
	check(GameState.deck_size()==before_deck+1 and screen.routes.size()==1,"classic animation settles once after the take")
	screen.queue_free(); await get_tree().process_frame
	print("[RoomReward] checks=",checks," failures=",failures.size())
	for path in ["user://room-reward-test.tres","user://room-inventory-legacy-test.tres","user://room-inventory-migrated-test.tres"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Music.stop()
	get_tree().quit(0 if failures.is_empty() else 1)


func wait_for_claim(screen: RewardProbe) -> void:
	# Cold shader compilation can delay frames; wait for completion instead of
	# racing a fixed timer against the animation's tween on a slow first frame.
	var deadline := Time.get_ticks_msec()+5000
	while not screen._settled and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame


func check_legacy_migration() -> void:
	var old_run := reward_run()
	var counts := GameState.glyph_counts()
	var uid: int = GameState.deck[0].uid
	GameState.deck[0].gilded = true
	GameState.deck[0].upgrade_level = 2
	var offers: Array = old_run.reward_options.map(func(ch):return ch.id)
	var rng_before: int = GameState.rng.state
	check(old_run.save_run("user://room-inventory-legacy-test.tres")==OK,"new reward state saves")
	var old_save = ResourceLoader.load("user://room-inventory-legacy-test.tres","",ResourceLoader.CACHE_MODE_IGNORE)
	check(not old_save.run.has("tray") and not old_save.run.has("plate") and not old_save.run.has("active"),"new saves omit removed inventory fields")
	old_save.run["tray"] = ["火","火","电"]
	old_save.run["plate"] = [["护","盾"],["火",""]]
	old_save.run["active"] = {"护盾":true,"充电":true,"金币":true,"分流":true,"火力":true}
	check(ResourceSaver.save(old_save,"user://room-inventory-legacy-test.tres")==OK,"legacy fixture contains tray and plate glyphs")
	var restored = RUN.restore("user://room-inventory-legacy-test.tres",true)
	for glyph in ["火","火","电","护","盾","火"]: counts[glyph] = int(counts.get(glyph,0))+1
	check(restored!=null and GameState.glyph_counts()==counts,"legacy tray and plate return every glyph, including duplicate copies, to the deck")
	check(GameState.deck[0].uid==uid and GameState.deck[0].gilded and GameState.deck[0].upgrade_level==2,"migration preserves existing deck entities and upgrades")
	check(restored.phase=="reward" and restored.reward_options.map(func(ch):return ch.id)==offers and GameState.rng.state==rng_before,"migration preserves pending reward options and RNG")
	var observation: Dictionary = restored.observe()
	check(not observation.has("tray") and not observation.has("plate") and not observation.has("inventory_actions"),"automation no longer advertises removed inventory state")
	var deck_before := GameState.deck_size()
	for action in [{"type":"tray_to_deck","index":0},{"type":"plate","index":0,"row":0,"col":0},{"type":"take_plate","row":0,"col":0}]:
		check(not restored.apply(action).ok and GameState.deck_size()==deck_before,"retired inventory actions cannot move or duplicate glyphs")
	check(restored.save_run("user://room-inventory-migrated-test.tres")==OK,"migrated save writes the new format")
	restored = RUN.restore("user://room-inventory-migrated-test.tres",true)
	check(GameState.glyph_counts()==counts,"resaving and reloading migrated inventory does not duplicate glyphs")
	restored.phase = "encounter"; restored.node = restored.battle_node()
	check(restored.apply({"type":"interact"}).ok and restored.battle_h.battle.player.block==0 and restored.battle_h.battle.enemies[0].hp==restored.node.enemies[0].max_hp,"retired plate words do not grant block or damage enemies at battle start")
	var gold_before := GameState.gold
	restored.finish_live_battle(true)
	check(GameState.gold==gold_before+10 and restored.reward_options.size()==3,"retired plate words grant no extra victory gold or reward slot")
