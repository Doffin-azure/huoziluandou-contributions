extends Control
## Direct gains, exact furnace instances and legacy save migration through live UI.
var passed := 0
var failed := 0


func check(ok: bool, note: String) -> void:
	if ok: passed += 1; print("PASS ", note)
	else: failed += 1; push_error(note)


func frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func text_of(node: Node) -> String:
	var out := str(node.text) if node is Label or node is Button else ""
	for child in node.get_children(): out += "\n" + text_of(child)
	return out


func _ready() -> void:
	Settings.storage_path = "user://direct-deck-settings.cfg"
	Settings.reduced_motion = true
	Engine.max_fps = 120
	SaveManager.enabled = false
	GameState.set_meta("courtyard_preview", true)
	Router.host = self
	_run.call_deferred()


func _run() -> void:
	var ex := Expedition.start(21)
	check(not ex.get_property_list().any(func(p): return p.name == "tray") and not ex.has_method("tray_to_deck") and not ex.has_method("tray_cap") and not ex.has_method("discard"), "legacy expedition has no tray state or inventory actions")
	var gold := GameState.gold
	var before := GameState.deck_size()
	for i in 15: ex.gain_glyph("火", "测试")
	check(GameState.deck_size() == before + 15 and GameState.gold == gold, "every new glyph enters the deck beyond the former capacity, without turning into coins")
	var free := -1
	for cell in ex.m.glyph:
		if not ex.sealed(cell) and ex.guard_of(cell).is_empty(): free = cell; break
	ex.pos = free
	before = GameState.deck_size()
	check(ex.pickup() and GameState.deck_size() == before + 1 and not ex.pickup(), "map pickup enters the deck once")
	ex.panels = [{"kind":"loot", "tier":"小", "options":[{"kind":"glyphs", "glyphs":["冷","电"]}]}]
	before = GameState.deck_size()
	ex.choose_loot(0)
	check(GameState.deck_size() == before + 2, "loot glyphs enter the same deck")
	ex.panels = [{"kind":"shop"}]
	GameState.gold = 100
	var cost := ex.price(ex.shop_offers()[0])
	before = GameState.deck_size()
	check(ex.buy(0) and GameState.deck_size() == before + 1 and GameState.gold == 100 - cost, "purchased glyph enters the deck and charges its real price")
	ex.panels.clear()
	var node := MapNodeData.new()
	node.type = MapNodeData.Type.BATTLE
	Router.goto("res://src/screens/reward_screen.gd", {"expedition":true, "node":node})
	await frames(20)
	var reward: Control = Router.current
	reward._cards[0].clicked.emit()
	check(reward._hud.action_button.text == "收入字袋" and not text_of(reward).contains("字匣"), "expedition reward uses deck copy throughout")
	before = GameState.deck_size()
	reward._accept_pick()
	await frames(12)
	check(GameState.deck_size() == before + 1 and Router.current_path.ends_with("expedition_map_screen.gd"), "reward enters the deck before returning to exploration")
	check(not text_of(Router.current).contains("字匣") and not Router.current.has_method("_on_tray"), "exploration UI has no tray, transfer controls or capacity warning")

	# Two copies are separate instances; do not replace either selection after
	# an unrelated deck update. Bound relic carriers cannot become ingredients.
	ex.m = MapGen.generate(17, "熔铸坊")
	for cell in ex.m.mech:
		if ex.m.mech[cell].g == "炉": ex.pos = cell; break
	GameState.deck.clear()
	GameState.add_character(Database.get_character_by_glyph("火"), 2)
	GameState.add_character(Database.get_character_by_glyph("防"))
	var ingredients := [GameState.deck[0].uid, GameState.deck[1].uid]
	var survivor: CharInstance = GameState.deck[2]
	survivor.gilded = true
	survivor.upgrade_level = 2
	ex.panels = [{"kind":"forge", "k":ex.pos}]
	GameState.relic_binds = {"slab":ingredients[0]}
	var original := GameState.deck.duplicate()
	check(not ex.forge(0, 0) and not ex.forge(-1, 1) and not ex.forge(0, 99) and not ex.forge(0, 1) and GameState.deck == original, "invalid indices, duplicate selection and relic-bound ingredients consume nothing")
	GameState.relic_binds.clear()
	Router.current.refresh()
	await frames()
	var screen: Control = Router.current
	var grid: HFlowContainer = screen._event_box.get_children().filter(func(child): return child is HFlowContainer)[0]
	grid.get_child(0).pressed.emit()
	await frames()
	grid = screen._event_box.get_children().filter(func(child): return child is HFlowContainer and not child.is_queued_for_deletion())[0]
	grid.get_child(1).pressed.emit()
	await frames()
	check(screen._forge_sel == ingredients, "furnace buttons select the two exact duplicate instances")
	ex.gain_glyph("电")
	screen.refresh()
	await frames()
	screen._forge_from_deck()
	check(GameState.deck_size() == 3 and GameState.deck.has(survivor) and survivor.gilded and survivor.upgrade_level == 2 and not GameState.deck.any(func(inst): return ingredients.has(inst.uid)), "furnace consumes selected instances, preserves other glyphs and puts the result in the deck")
	check(GameState.deck[-1].data.rarity >= 2 and not ex.forge(0, 1), "furnace still produces one rare glyph and remains single-use")

	# Write a real pre-removal save fixture using the same checksum/envelope.
	SaveManager.activate("user://direct-deck-migration.save")
	SaveManager.clear_run()
	ex = Expedition.start(81)
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await frames()
	var first: CharInstance = GameState.deck[0]
	first.gilded = true
	first.upgrade_level = 2
	var uid := first.uid
	var counts := GameState.glyph_counts()
	check(SaveManager.checkpoint(), "direct-deck expedition saves through the actual checkpoint")
	SaveManager.flush()
	var record := {"generation":SaveManager._generation + 1}
	var envelope: Dictionary = bytes_to_var(SaveManager._last_payload)
	for saved_node in envelope.graph.nodes:
		if saved_node.type == "expedition":
			check(not saved_node.fields.has("tray"), "new saves omit retired tray data")
			saved_node.fields.tray = {"array":["火","火","电"]}
			saved_node.fields.seals = {"array":["活字盒"]}
	record.payload = var_to_bytes(envelope)
	record.sha256 = SaveManager._digest(record.payload)
	var file := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	file.store_buffer(var_to_bytes(record))
	file.close()
	SaveManager._read_latest()
	SaveManager._read_latest()
	check(GameState.glyph_counts() == counts, "probing legacy saves does not mutate the live deck")
	check(SaveManager.resume_run(), "legacy save with a retired tray remains readable")
	await frames()
	check(GameState.glyph_counts().get("火", 0) == int(counts.get("火", 0)) + 2 and GameState.glyph_counts().get("电", 0) == int(counts.get("电", 0)) + 1, "legacy migration preserves every copy in the deck")
	check(GameState.deck[0].uid == uid and GameState.deck[0].gilded and GameState.deck[0].upgrade_level == 2 and GameState.expedition.seals == ["字印"], "migration preserves old instances and replaces the retired capacity seal")
	check(SaveManager.checkpoint(), "migrated expedition saves without a second inventory")
	SaveManager.flush()
	counts = GameState.glyph_counts()
	check(SaveManager.resume_run(), "migrated save resumes again")
	await frames()
	check(GameState.glyph_counts() == counts, "saving and resuming never duplicates migrated glyphs")
	SaveManager.clear_run()
	SaveManager.enabled = false
	var room = preload("res://src/expedition/room_run_state.gd").start(129)
	room.autosave = false
	check(room.save_run("user://direct-deck-room.tres") == OK, "courtyard saves its direct deck")
	var old_save = ResourceLoader.load("user://direct-deck-room.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(not old_save.run.has("tray") and not old_save.run.has("plate") and not old_save.run.has("active"), "new courtyard saves contain no retired inventories or layout bonuses")
	old_save.run.tray = ["火", "火", "电"]
	old_save.run.plate = [["防", "御"], ["", ""]]
	old_save.run.active = {"金币":true, "护盾":true}
	ResourceSaver.save(old_save, "user://direct-deck-room.tres")
	counts = GameState.glyph_counts()
	room = preload("res://src/expedition/room_run_state.gd").restore("user://direct-deck-room.tres")
	room.autosave = false
	check(GameState.glyph_counts().get("火", 0) == int(counts.get("火", 0)) + 2 and GameState.glyph_counts().get("电", 0) == int(counts.get("电", 0)) + 1 and GameState.glyph_counts().get("防", 0) == int(counts.get("防", 0)) + 1 and GameState.glyph_counts().get("御", 0) == int(counts.get("御", 0)) + 1, "courtyard migration preserves tray duplicates and every old layout glyph")
	check(not room.get_property_list().any(func(p): return p.name in ["tray", "plate", "active"]), "courtyard migration does not restore a second inventory or its bonuses")
	counts = GameState.glyph_counts()
	room.save_run("user://direct-deck-room.tres")
	room = preload("res://src/expedition/room_run_state.gd").restore("user://direct-deck-room.tres")
	check(GameState.glyph_counts() == counts, "courtyard save and restore never duplicate migrated copies")
	DirAccess.remove_absolute("user://direct-deck-room.tres")
	Router.release_host(self)
	print("[direct_deck_test] PASS=%d FAIL=%d TOTAL=%d" % [passed, failed, passed + failed])
	get_tree().quit(1 if failed else 0)
