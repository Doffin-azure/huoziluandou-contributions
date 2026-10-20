extends Control
const RUN = preload("res://src/expedition/room_run_state.gd")
class RestProbe extends "res://src/screens/rest_screen.gd":
	var finished := false
	func _finish() -> void: finished = true
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames() -> void:
	for i in 4: await get_tree().process_frame

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	GameState.set_meta("courtyard_preview", true)
	GameState.start_new_run("v03", ["击", "击", "火"])
	var original := Database.get_character("ji")
	var amount := original.solo_effects[0].amount
	GameState.gild_character(GameState.deck[0])
	var uid := CharInstance._next_uid
	var rng := GameState.rng.state
	var text: String = GameState.deck[0].describe()
	check(text.contains("镀金：") and text.contains("%d铜钱" % BattleBalance.i("gild_gold", 1)) and text.contains("组词"), "gilded description explains exact reward and word use")
	check(CharInstance._next_uid == uid and GameState.rng.state == rng and not original.description.contains("镀金"), "description is read only and does not mutate original data")
	var overlay := CollectionOverlay.new()
	overlay.setup({"title":"字袋", "instances":GameState.deck})
	add_child(overlay); await frames()
	check(overlay._grid.get_child_count() == 3, "same glyph with different modifications has separate cards")
	check(overlay._grid.get_child(0)._desc.get_parsed_text().contains("镀金") and not overlay._grid.get_child(1)._desc.get_parsed_text().contains("镀金"), "owned collection displays actual per-entity modification")
	overlay.free()
	GameState.upgrade_character_type("ji")
	check(GameState.deck[0].data.solo_effects[0].amount == amount + 2 and GameState.deck[1].data.solo_effects[0].amount == amount + 2, "classic upgrade applies to existing instances")
	check(GameState.deck[0].describe().contains("造成%d伤害" % (amount+2)), "upgraded description uses real effect amount")
	GameState.upgrade_character_type("ji")
	check(GameState.deck[0].data.solo_effects[0].amount == amount + 2 and GameState.deck[0].describe().contains("造成%d伤害" % (amount+2)), "repeat rest keeps the existing upgrade rule and displays its actual amount")
	check(original.solo_effects[0].amount == amount, "upgrades do not alter the global character resource")
	var pile := BattlePileOverlay.new()
	pile.setup("字袋", GameState.deck)
	check(pile.groups.any(func(group): return group.character.description.contains("造成%d伤害" % (amount+2)) and group.character.description.contains("镀金")), "battle piles use the same real effect description")
	pile.free()
	var run = RUN.new()
	run.reset({"seed":17,"layout":"node_graph","deck":["击", "击", "火"]})
	# Use real owned instances and the real rest action / picker / completion UI.
	GameState.deck.clear()
	GameState.add_character(original, 2)
	GameState.add_character(Database.get_character_by_glyph("火"))
	var rest: String = run.graph.rooms.keys().filter(func(id): return run.graph.rooms[id].kind=="rest")[0]
	run._arrive(rest)
	var screen := RestProbe.new()
	screen.setup({"room_run":true})
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames()
	screen._do_upgrade(); await frames()
	var picker: CollectionOverlay = screen.find_children("*", "CollectionOverlay", true, false)[0] if not screen.find_children("*", "CollectionOverlay", true, false).is_empty() else null
	if picker == null:
		for child in screen.get_children():
			if child is CollectionOverlay: picker = child
	check(picker != null and picker.cfg.modification_preview.contains("铜钱"), "rest picker previews the real gilding effect")
	if picker != null:
		picker._grid.get_child(0).clicked.emit()
		await frames()
	check(GameState.deck.filter(func(inst): return inst.gilded).size() == 1 and run.phase == "map", "main mode modifies exactly one instance and settles rest")
	var notice: ChoiceOverlay
	for child in screen.get_children():
		if child is ChoiceOverlay: notice = child
	check(notice != null and notice.cfg.body.contains("镀金") and notice.cfg.body.contains("铜钱") and not screen.finished, "completion shows actual modifier effect before leaving")
	if OS.get_cmdline_user_args().has("--capture"):
		await frames()
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("/tmp/huozi-modifier-complete.png")
	if notice != null: notice._on_choose(0)
	check(screen.finished, "confirmation returns to the route")
	screen.free()
	var path := "user://modifier-display-test.tres"
	check(run.save_run(path) == OK, "modified deck saves")
	var restored = RUN.restore(path)
	check(restored != null and GameState.deck.filter(func(inst): return inst.describe().contains("镀金：")).size() == 1, "modifier effect description survives reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("[modifier_display_test] PASS=%d FAIL=%d" % [checks-failures, failures])
	get_tree().quit(1 if failures else 0)
