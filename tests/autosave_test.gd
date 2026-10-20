extends Control
var _pass := 0
var _fail := 0
var _main: Control
const SLOT := "user://autosave_regression_test.save"


func _ready() -> void:
	Settings.storage_path = "user://autosave_test-settings.cfg"
	_run.call_deferred()


func _ok(value: bool, label: String) -> void:
	if value: _pass += 1; print("PASS ", label)
	else: _fail += 1; push_error(label)


func _frames(count := 4) -> void:
	for i in count: await get_tree().process_frame


func _commit() -> void:
	await _frames()
	SaveManager.checkpoint()
	SaveManager.flush()


func _resume() -> void:
	Router.goto("res://src/screens/title_screen.gd")
	await _frames()
	_ok(Router.current._continue_button.visible, "Continue visible after return to cached title")
	GameState.deck = []
	GameState.gold = -100
	_ok(SaveManager.resume_run(), "resume succeeds")
	await _frames()


func _run() -> void:
	Settings.reduced_motion = true
	if OS.get_cmdline_user_args().has("--restart-write") or OS.get_cmdline_user_args().has("--restart-read"):
		await _restart_phase()
		return
	SaveManager.activate(SLOT)
	SaveManager.clear_run()
	_ok(not SaveManager.has_save(), "fresh slot has no Continue")
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames()
	_ok(not Router.current._continue_button.visible, "Continue hidden for a fresh install")
	GameState.start_new_run()
	GameState.gold = 55
	GameState.player_hp = 39
	GameState.node_index = 3
	GameState.visited = {"1:1": true, "1:2": true}
	GameState._reinvestments = [{"amount": 12, "due_battle": 4}]
	var upgraded: CharacterData = GameState.deck[0].data.duplicate(true)
	if not upgraded.solo_effects.is_empty(): upgraded.solo_effects[0].amount += 2
	GameState.deck[0].data = upgraded
	GameState.deck[0].gilded = true
	GameState.relic_binds = {"test_bind": GameState.deck[0].uid}
	GameState.rng.seed = 9123456
	var rng_state := GameState.rng.state
	Router.goto("res://src/screens/map_screen.gd")
	await _commit()
	_ok(SaveManager.has_save(), "mainline map automatically saved")
	await _resume()
	_ok(GameState.gold == 55 and GameState.player_hp == 39 and GameState.node_index == 3 and GameState.visited.has("1:2"), "HP, gold and mainline route restored")
	if OS.get_cmdline_user_args().has("--capture"):
		Router.goto("res://src/screens/title_screen.gd")
		await _frames(12)
		await _capture_title(Vector2i(1280, 720), "title-desktop")
		await _capture_title(Vector2i(960, 432), "title-phone-landscape")
		_ok(SaveManager.resume_run(), "Continue returns after screenshots")
		await _frames()
	_ok(GameState.reinvest_gold == 12 and GameState._reinvestments[0].due_battle == 4, "investment due battle preserved")
	_ok(GameState.deck[0].gilded and GameState.deck[0].data.solo_effects[0].amount == upgraded.solo_effects[0].amount, "permanent glyph upgrades survive")
	_ok(GameState.relic_binds.test_bind == GameState.deck[0].uid and CharInstance.new().uid > GameState.deck[0].uid, "UIDs and relic bindings survive")
	_ok(GameState.rng.state == rng_state, "64-bit RNG state unchanged by resume")
	Router.goto("res://src/screens/shop_screen.gd")
	await _commit()
	var offers := var_to_bytes(SaveCodec.new().pack({"offers": Router.current._offers}))
	await _resume()
	_ok(offers == var_to_bytes(SaveCodec.new().pack({"offers": Router.current._offers})), "shop offers and prices do not reroll")
	var price: int = Router.current._offers[0].price
	Router.current._buy(0)
	await _commit()
	var bought_size := GameState.deck.size()
	await _resume()
	_ok(Router.current._offers.size() == 10 and GameState.gold == 55 - price and GameState.deck.size() == bought_size, "purchased offer remains sold, cost applied once")
	# Picker spends up front: interruption must restore the entire preceding transaction.
	Router.current._buy(Router.current._offers.find_custom(func(o): return o.kind == "remove"))
	_ok(not SaveManager.checkpoint(), "unfinished shop picker is not checkpointed")
	await _resume()
	_ok(GameState.gold == 55 - price and Router.current._offers.size() == 10, "unfinished purchase rolls back cost and offer together")
	Router.goto("res://src/screens/event_screen.gd")
	await _commit()
	var event_id: String = Router.current._event.id
	var event_rng: int = GameState.rng.state
	await _resume()
	_ok(Router.current._event.id == event_id and GameState.rng.state == event_rng, "event and RNG restored without reroll")
	Router.goto("res://src/screens/reward_screen.gd")
	await _commit()
	var glyphs: Array = Router.current._options.map(func(c): return c.id)
	await _resume()
	_ok(Router.current._options.map(func(c): return c.id) == glyphs, "reward choices restored exactly")
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 4321})
	await _frames()
	var screen := Router.current
	screen.battle.player.block = 17
	screen.battle.player.statuses = {"strength": 2}
	screen.battle.enemies[0].statuses = {"burn": 3}
	screen.battle.enemies[0].move_index = 1
	screen.battle.turn = 4
	screen.battle.reconnect_pending = [{"inst": screen.battle.bag[0], "pos": Vector2i(1, 2), "return_turn": 6}]
	await _commit()
	var battle_blob := var_to_bytes(SaveCodec.new().pack({"battle": screen.battle}))
	var sequence := GameState.battle_sequence
	var expected_uid: int = screen.battle.bag[0].uid
	# Mimic Android suspend while an action/picker has partially mutated the model.
	screen._busy = true
	screen.battle.player.hp -= 3
	SaveManager._notification(NOTIFICATION_APPLICATION_PAUSED)
	await _resume()
	screen = Router.current
	_ok(sequence == GameState.battle_sequence, "resume does not start an additional battle")
	_ok(battle_blob == var_to_bytes(SaveCodec.new().pack({"battle": screen.battle})), "complete stable battle restored: board, piles, statuses, turn and RNG")
	_ok(screen.battle.bag[0] == screen.battle.reconnect_pending[0].inst and screen.battle.bag[0].uid == expected_uid, "shared battle character references and coordinates preserved")
	# Prove the resumed random stream and enemy turn behave identically.
	var other = SaveCodec.new().unpack(SaveCodec.new().pack({"battle": screen.battle})).battle
	var uid_before := CharInstance._next_uid
	other.end_player_turn()
	CharInstance._next_uid = uid_before
	screen.battle.end_player_turn()
	_ok(var_to_bytes(SaveCodec.new().pack({"battle": other})) == var_to_bytes(SaveCodec.new().pack({"battle": screen.battle})), "next turn deterministic after restore")
	Expedition.start(42)
	GameState.gold = 91
	var ex := GameState.expedition
	ex.taken[ex.pos] = true
	ex.used[17] = 2
	ex.panels = [{"kind": "loot", "tier": "小", "options": ex.loot_options("小")}]
	var loot_blob := var_to_bytes(SaveCodec.new().pack({"panels": ex.panels}))
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await _commit()
	var map_before: PackedByteArray = ex.m.ink.duplicate()
	var pos_before := ex.pos
	var rng_before := ex.rng.state
	await _resume()
	ex = GameState.expedition
	_ok(ex.pos == pos_before and ex.m.ink == map_before and ex.used.has(17) and ex.taken.has(pos_before) and ex.rng.state == rng_before, "expedition map, integer keys, fog and random streams preserved")
	_ok(var_to_bytes(SaveCodec.new().pack({"panels": ex.panels})) == loot_blob, "pending expedition panel preserved")
	ex.fight = {"kind": "foe", "k": ex.pos, "g": "爆", "name": "存档测试"}
	Router.goto("res://src/screens/battle_screen.gd", {"node": ex.battle_node(), "expedition": true, "seed": 77})
	await _commit()
	var encounter_glyph: String = ex.fight.g
	var encounter_name: String = ex.fight.name
	var encounter_id: String = Router.current.battle.enemies[0].enemy_data.id
	sequence = GameState.battle_sequence
	await _resume()
	_ok(Router.current._expedition and GameState.battle_sequence == sequence and GameState.expedition.fight.g == encounter_glyph and GameState.expedition.fight.name == encounter_name and Router.current.battle.enemies[0].enemy_data.id == encounter_id, "expedition encounter and battle restored together")
	# Alternating generations: damage the newest file, recover the older valid slot.
	await _commit()
	GameState.gold = 92
	SaveManager.checkpoint()
	SaveManager.flush()
	var latest := SLOT + ("" if SaveManager._generation % 2 == 1 else ".bak")
	var file := FileAccess.open(latest, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([1, 2, 3]))
	file.close()
	var recovered := SaveManager._read_latest()
	_ok(not recovered.is_empty() and recovered.state.gold == 91, "truncated newest save falls back to previous generation")
	# Invalid objects can only refer to fixed model IDs; save files cannot load scripts.
	_ok(SaveCodec.new().unpack({"root": {}, "nodes": [{"type": "res://evil.gd", "fields": {}}]}).is_empty(), "unknown model type rejected")
	SaveManager.clear_run()
	_ok(not FileAccess.file_exists(SLOT) and not FileAccess.file_exists(SLOT + ".bak") and not SaveManager.has_save(), "finished run clears both save generations")
	GameState.start_new_run()
	Router.goto("res://src/screens/map_screen.gd")
	await _commit()
	EventBus.run_ended.emit(true)
	_ok(not SaveManager.has_save(), "mainline victory retires save")
	Expedition.start(42)
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await _commit()
	GameState.expedition.over = true
	SaveManager.checkpoint()
	_ok(not SaveManager.has_save(), "expedition finish retires save")
	SaveManager.clear_run()
	SaveManager.enabled = false
	_main.queue_free()
	await _frames()
	print("[autosave_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail else 0)


func _capture_title(resolution: Vector2i, name: String) -> void:
	get_window().size = resolution
	await _frames(15)
	var title := Router.current
	var scale := float(get_window().size.y) / title.size.y
	for button in title._buttons:
		if not button.visible: continue
		_ok(title.get_global_rect().encloses(button.get_global_rect()) and button.size.y * scale >= 47.9, "visible touch target " + button.text + " " + str(resolution))
	RenderingServer.force_draw(false)
	var folder := "res://docs/qa/autosave-2026-10-18"
	DirAccess.make_dir_recursive_absolute(folder)
	_ok(get_viewport().get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "screenshot " + name)


func _restart_phase() -> void:
	SaveManager.activate("user://autosave_process_test.save")
	_main = preload("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await _frames()
	if OS.get_cmdline_user_args().has("--restart-write"):
		SaveManager.clear_run()
		GameState.start_new_run()
		GameState.gold = 37
		Router.goto("res://src/screens/battle_screen.gd", {"seed": 9876})
		Router.current.battle.turn = 5
		Router.current.battle.player.statuses = {"strength": 4}
		await _commit()
		_ok(SaveManager.has_save(), "independent process wrote battle checkpoint")
	else:
		_ok(SaveManager.has_save() and Router.current._continue_button.visible, "independent process discovers Continue")
		_ok(SaveManager.resume_run(), "independent process resumes battle")
		await _frames()
		_ok(GameState.gold == 37 and Router.current.battle.turn == 5 and Router.current.battle.player.statuses.get("strength") == 4 and GameState.battle_sequence == 1, "independent process restores battle and run state")
		SaveManager.clear_run()
	_main.queue_free()
	await _frames()
	print("[autosave_restart] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail else 0)
