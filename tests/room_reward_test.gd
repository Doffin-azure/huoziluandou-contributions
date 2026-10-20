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
	run.reset({"seed":17})
	run.autosave = false
	run.enter_room("opening_1")
	run.begin_live_battle(); run.finish_live_battle(true)
	return run


func reward_screen(room_mode := true) -> RewardProbe:
	var screen := RewardProbe.new()
	screen.setup({"room_run":room_mode})
	add_child(screen)
	screen._cards[0].clicked.emit() # These settlement cases start with a deliberate selection.
	return screen


func _ready() -> void:
	Settings.reduced_motion = true
	var run: RefCounted = reward_run()
	var screen := reward_screen()
	screen._inspect(1)
	var chosen: CharacterData = screen._options[1]
	var before_deck := GameState.deck_size()
	var before_gold := GameState.gold
	screen._hud.action_button.pressed.emit()
	check(run.phase=="map" and GameState.deck[-1].glyph()==chosen.glyph,"real claim button settles the selected glyph into deck")
	check(GameState.deck_size()==before_deck+1 and GameState.gold==before_gold,"glyph claim adds one instance and no skip gold")
	check(screen._options.size()==3,"settlement does not erase the screen's option snapshot")
	check(screen.routes==[RUN.MAP_SCREEN],"successful claim leaves reward exactly once")
	screen._accept_pick(); screen._on_skip(); screen._on_pick(chosen)
	check(GameState.deck_size()==before_deck+1 and screen.routes.size()==1 and GameState.gold==before_gold,"repeat claim and skip callbacks cannot settle again")
	check(run.save_run("user://room-reward-test.tres")==OK,"claimed reward saved")
	var restored = RUN.restore("user://room-reward-test.tres")
	check(restored!=null and GameState.deck[-1].glyph()==chosen.glyph and restored.phase=="map","deck reward survives reload")
	if restored!=null:
		restored.autosave = false
		check(restored.reward_options.is_empty() and not restored.apply({"type":"reward","index":1,"glyph":chosen.glyph}).ok,"reload cannot claim cleared reward again")
	screen.queue_free(); await get_tree().process_frame

	run = reward_run()
	GameState.add_character(Database.get_character_by_glyph("火"), 20)
	screen = reward_screen()
	chosen = screen._options[0]
	before_deck = GameState.deck_size()
	var glyph_count := int(GameState.glyph_counts().get(chosen.glyph,0))
	check(screen._hud.action_button.text=="收入字袋","reward names the deck without a tray capacity")
	screen._accept_pick()
	check(run.phase=="map" and not run.get_property_list().any(func(p):return p.name=="tray"),"claim completes without a second inventory")
	check(GameState.deck_size()==before_deck+1 and int(GameState.glyph_counts().get(chosen.glyph,0))==glyph_count+1,"large deck still receives exactly the chosen glyph")
	screen.queue_free(); await get_tree().process_frame

	run = reward_run(); screen = reward_screen()
	before_deck = GameState.deck_size()
	run.phase = "map" # Simulate a rejected/stale settlement.
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
	await get_tree().create_timer(.35).timeout
	check(run.phase=="map" and GameState.deck_size()==before_deck+1 and GameState.deck[-1].glyph()==chosen.glyph and GameState.gold==before_gold,"animated claim keeps its chosen glyph and blocks skip")
	check(screen.routes.size()==1,"animated claim navigates once")
	screen.queue_free(); await get_tree().process_frame

	# The reward page is shared with the original route; its destination and
	# animation timing must stay intact while fixing courtyard settlement.
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
	await get_tree().create_timer(.35).timeout
	check(GameState.deck_size()==before_deck+1 and screen.routes.size()==1,"classic animation settles once after the take")
	screen.queue_free(); await get_tree().process_frame
	print("[RoomReward] checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
