extends Control
## Real reward UI: controller settlement, interactive meshes and pickup continuations.
const RUN := preload("res://src/expedition/room_run_state.gd")
const PREVIEW := preload("res://src/ui/relic_preview.gd")
const QA := "res://docs/qa/relic-expansion-2026-10-19/"
const SAVE := "user://relic-expansion-test.tres"
var passed := 0
var failed := 0


func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS ", message)
	else: failed += 1; push_error(message)


func frames(n := 12) -> void:
	for i in n: await get_tree().process_frame


func dialog() -> ChoiceOverlay:
	for child in Router.current.get_children():
		if child is ChoiceOverlay and not child.is_queued_for_deletion(): return child
	return null


func reward_run(kind: String) -> RefCounted:
	var run := RUN.new()
	run.reset({"seed": 129})
	run.autosave = false
	for id in run.graph.rooms:
		if run.graph.rooms[id].kind == kind:
			run.current_room = id
			break
	run.node = run.battle_node()
	run.phase = "encounter"
	run.begin_live_battle()
	run.finish_live_battle(true)
	return run


func open_reward(run: RefCounted) -> void:
	Router.goto("res://src/screens/reward_screen.gd", {"room_run": true, "node": run.node})
	await frames(22)
	if Router.current._relic_pending:
		Router.current._secondary_action()
		await frames()


func capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await frames()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(QA + name + ".png") == OK, "capture " + name)


func choose_with_input(button: Control, touch: bool) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().push_input(motion, true)
	await frames(2)
	for down in [true, false]:
		if touch:
			var tap := InputEventScreenTouch.new()
			tap.position = get_viewport().get_final_transform() * point
			tap.pressed = down
			Input.parse_input_event(tap)
		else:
			var click := InputEventMouseButton.new()
			click.position = point
			click.global_position = point
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			get_viewport().push_input(click, true)
		await frames(2)


func _ready() -> void:
	Settings.reduced_motion = true
	SaveManager.enabled = false
	Router.host = self
	DirAccess.make_dir_recursive_absolute(QA)
	_run.call_deferred()


func _run() -> void:
	var preserved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/remote-sync-2026-10-19/preserved-icons.json"))
	check(preserved.icons.all(func(entry): return FileAccess.get_sha256("res://" + entry.path) == entry.before_sha256), "original fifteen PNGs remain byte-identical")
	check(Relics.DEFS.keys().all(func(id): return RelicArt.texture(id) != null), "every current relic has registered art")
	check(Relics.EVENT_ONLY.all(func(id): return not Relics.normal_pool().has(id)), "three event-only relics keep their original acquisition rules")
	for window_size in [Vector2i(1280, 720), Vector2i(640, 360)]:
		get_window().size = window_size
		await frames()
		for kind in ["elite", "boss"]:
			var run := reward_run(kind)
			var count := 1 if kind == "elite" else 2
			check(run.contents[run.current_room].battle_relics.size() == count, kind + " controller creates the expected candidate count")
			var candidates: Array = ["ghost_hand"] if kind == "elite" else ["chaos_dice", "moon"]
			# Fixed eligible candidates make the visual and input checks reproducible.
			run.contents[run.current_room].battle_relics = candidates.duplicate()
			var hp := GameState.player_hp
			run.save_run(SAVE)
			run = RUN.restore(SAVE)
			run.autosave = false
			check(run.contents[run.current_room].battle_relics == candidates and GameState.player_hp == hp, "unclaimed candidates resume without rerolling or repeating boss healing")
			await open_reward(run)
			var screen = Router.current
			var choice := dialog()
			check(choice != null and choice.cfg.get("physical_relics", false), kind + " mounts the physical reward overlay")
			var previews: Array = choice.find_children("*", "Control", true, false).filter(func(node): return node is PREVIEW)
			check(previews.size() == count and previews.all(func(view): return view.specimen.get_child_count() > 0 and candidates.has(view.relic_id)), kind + " displays matching real meshes")
			var buttons := choice.relic_choice_buttons()
			check(buttons.size() == count and buttons.all(func(button): return choice._panel.get_global_rect().encloses(button.get_global_rect())), str(window_size) + kind + " keeps every take button visible")
			check(previews.all(func(view): return choice._panel.get_global_rect().encloses(view.get_global_rect())), str(window_size) + kind + " keeps every specimen visible")
			check(previews.all(func(view): return view.viewport.render_target_update_mode in [SubViewport.UPDATE_ONCE, SubViewport.UPDATE_DISABLED]), "idle previews retain their frame without continuous rendering")
			var first = previews[0]
			first.highlight(true)
			check(is_equal_approx(first._pivot.rotation.y, -0.16), "interaction rotates the actual specimen")
			first.highlight(false)
			check(screen._busy and screen._hud.action_button.disabled and screen._hud.secondary_button.disabled, "glyph claim stays blocked until relic pickup finishes")
			var before_deck := GameState.deck.duplicate()
			screen._accept_pick(); screen._on_skip()
			check(run.phase == "reward" and GameState.deck == before_deck, "pending relic cannot be bypassed through glyph claim or skip")
			await capture(kind + "-%d" % window_size.x)
			var before := GameState.relics.size()
			var target: Control = buttons[0] if window_size.x == 640 else choice.find_child("Take_" + str(candidates[0]), true, false)
			await choose_with_input(target, window_size.x == 640)
			await frames()
			check(GameState.relics.size() == before + 1 and GameState.has_relic(candidates[0]), "button grants exactly its displayed relic once")
			check(not screen._busy and not screen._hud.action_button.disabled, "pickup restores glyph reward controls")
			check(run.contents[run.current_room].battle_relics.is_empty() and not run.apply({"type": "reward_relic", "index": 0}).ok, "reward candidates clear and reject a second settlement")
			check(run.save_run(SAVE) == OK, "settled relic reward saves")
			var restored = RUN.restore(SAVE)
			check(restored != null and GameState.has_relic(candidates[0]) and restored.contents[restored.current_room].battle_relics.is_empty(), "resume keeps the chosen relic without reopening candidates")
	get_window().size = Vector2i(1280, 720)
	for id in ["goldleaf", "monkey", "slab"]:
		var run := reward_run("elite")
		run.contents[run.current_room].battle_relics = [id]
		await open_reward(run)
		var screen = Router.current
		dialog().relic_choice_buttons()[0].pressed.emit()
		await frames()
		check(screen._busy and screen._hud.action_button.disabled, id + " holds reward controls during its extra pickup step")
		if id == "monkey":
			var wish := dialog()
			check(wish != null and wish.cfg.options.size() == 3, "wish petition offers three wishes after the physical pickup")
			var at: int = wish.cfg.options.find_custom(func(option): return not option.text.contains("千字同文"))
			wish._on_choose(at)
		else:
			for step in (2 if id == "goldleaf" else 1):
				var pickers: Array = screen.get_children().filter(func(child): return child is CollectionOverlay and not child.is_queued_for_deletion())
				check(not pickers.is_empty(), id + " opens the original glyph picker")
				if not pickers.is_empty(): pickers.back()._close()
				await frames()
		check(not screen._busy and not screen._hud.action_button.disabled, id + " releases glyph rewards only after completing pickup")
		if id == "goldleaf": check(GameState.deck.filter(func(card): return card.gilded).size() == 2, "gold leaf still gilds exactly two cards")
		if id == "monkey": check(GameState.relic_counters.has("monkey"), "wish result is recorded")
		if id == "slab": check(GameState.relic_binds.has("slab"), "bound relic records its chosen glyph")
	# One mounted three-way offer must adapt when the window changes size.
	var choices := ChoiceOverlay.new()
	var picked := {"count": 0}
	choices.setup({"title": "幕末 · 遗物", "body": "从三件遗物中选择一件。", "physical_relics": true, "compact": true, "options": ["chain", "moon", "proof"].map(func(id): return {"text": Relics.name_of(id), "relic_id": id, "hint": Relics.desc_of(id)}), "on_choose": func(_index): picked.count += 1})
	Router.current.add_child(choices)
	await frames(20)
	for window_size in [Vector2i(640, 360), Vector2i(1280, 720)]:
		get_window().size = window_size
		await frames(22)
		var buttons := choices.relic_choice_buttons()
		var unit := JourneyStyle.touch_scale(choices)
		check(buttons.size() == 3 and buttons.all(func(button): return choices._panel.get_global_rect().encloses(button.get_global_rect()) and button.size.y >= 48 * unit - 0.1), "mounted three-way offer resizes with visible 48px take targets")
		if window_size.x == 640:
			var scroll: ScrollContainer = buttons[0].get_parent().get_child(2)
			check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "long nine-ring description scrolls within its own column")
			await capture("classic-choice-640")
	choices.relic_choice_buttons()[0].grab_focus()
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = down
		get_viewport().push_input(key, true)
		await frames(2)
	check(picked.count == 1, "keyboard confirms the focused physical relic choice once")
	var final_run := reward_run("boss")
	GameState.act_index = 3
	final_run.phase = "battle"
	final_run.contents[final_run.current_room].battle_relics = []
	final_run.finish_live_battle(true)
	check(final_run.contents[final_run.current_room].battle_relics.is_empty(), "final-act boss keeps the existing ending reward rule")
	DirAccess.remove_absolute(SAVE)
	Router.release_host(self)
	print("[relic_expansion_test] PASS=%d FAIL=%d TOTAL=%d" % [passed, failed, passed + failed])
	get_tree().quit(1 if failed else 0)
