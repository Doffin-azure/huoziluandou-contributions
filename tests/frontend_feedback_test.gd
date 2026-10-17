extends Control
## Frontend-only feedback acceptance: native layouts, read-only inspection and staged actions.
var passed := 0
var failed := 0
var screen: Control
var saved_motion := false
var saved_style := ""

func _ready() -> void:
	saved_motion = Settings.reduced_motion
	saved_style = Palette.STYLE_ID
	Settings.reduced_motion = true
	Ink.apply_style(GameStyle.get_style("taopunk"))
	run.call_deferred()

func frames(n := 8) -> void:
	for i in n: await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS ", message)
	else: failed += 1; push_error(message)

func shot(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await frames(3)
	RenderingServer.force_draw(false)
	check(get_viewport().get_texture().get_image().save_png("res://shots/feedback-" + name + ".png") == OK, "capture " + name)

func open_page(page: String) -> void:
	GameState.start_new_run("v03")
	GameState.gold = 80
	GameState.player_hp = 37
	GameState.rng.seed = 20261016
	Router.goto("res://src/screens/%s_screen.gd" % page, {"seed": 7})
	await frames(16)
	screen = Router.current

func nodes(root: Node, kind: String) -> Array:
	var found: Array = []
	for child in root.get_children():
		if (kind == "button" and child is Button) or (kind == "collection" and child is CollectionOverlay): found.append(child)
		found.append_array(nodes(child, kind))
	return found

func signature() -> String:
	return var_to_str([GameState.player_hp, GameState.gold, GameState.node_index, GameState.rng.state, GameState.deck.map(func(c): return c.uid)])

func battle_signature() -> String:
	var b: BattleState = screen.battle
	return var_to_str([b.player.hp, b.player.block, b.player.persistent_block, b.player.next_damage_reduction, b.next_draw_penalty, b.rng.state, b.board.cells, b.bag, b.discard, b.pending_reveal, b.turn])

func put(x: int, y: int, glyph: String) -> CharInstance:
	var c := CharInstance.new(Database.get_character_by_glyph(glyph))
	screen.battle.board.set_cell(x, y, c)
	return c

func select_word(word: String) -> Array:
	var path: Array = []
	for i in word.length(): put(i, 0, word[i]); path.append(Vector2i(i, 0))
	screen._board_view.rebuild()
	screen._board_view.path = path.duplicate()
	screen._board_view._sync_selection()
	screen._current_word = Database.get_word_by_glyphs_string(word)
	return path

func choice() -> ChoiceOverlay:
	for child in screen.get_children():
		if child is ChoiceOverlay: return child
	return null

func idle() -> void:
	var until := Time.get_ticks_msec() + 5000
	while screen._busy and Time.get_ticks_msec() < until: await get_tree().process_frame
	await frames()
	check(not screen._busy, "action releases input")

func run() -> void:
	Router.host = self
	for window_size in [Vector2i(1440, 810), Vector2i(960, 432)]:
		get_window().size = window_size
		await frames()
		for page in ["shop", "rest"]:
			await open_page(page)
			var before := signature()
			var entries := nodes(screen, "button").filter(func(b): return b.text == "字袋")
			check(entries.size() == 1, page + " has an independent deck entry")
			if entries.is_empty(): continue
			var button: Button = entries[0]
			var scale := float(window_size.y) / screen.size.y
			check(screen.get_global_rect().encloses(button.get_global_rect()) and button.size.y * scale >= 47.9, page + " deck entry fits and retains 48px touch height")
			await shot(page + "-%d" % window_size.x)
			button.pressed.emit()
			screen._open_deck()
			await frames()
			var overlays := nodes(screen, "collection")
			check(overlays.size() == 1 and overlays[0].cfg.counts == GameState.glyph_counts(), page + " browser contains the complete owned counts without duplicate overlays")
			check(not overlays[0].cfg.get("pick_on_click", false), page + " browser does not select a destructive action")
			await shot(page + "-deck-%d" % window_size.x)
			overlays[0]._close()
			await frames()
			check(before == signature() and (not screen._busy if page == "shop" else not screen._done), page + " browsing spends no gold, glyph, RNG, node or rest action")
		await open_page("battle")
		var path := select_word("反转")
		screen._on_commit(path)
		await frames()
		var overlay := choice()
		check(overlay != null and overlay._peek_button != null, "reverse exposes board inspection")
		var before := battle_signature()
		overlay._peek_button.pressed.emit()
		await frames()
		check(not overlay._sheet.visible and not screen._board_view._interactable and screen._modal_count == 1, "peeking reveals the board while retaining the modal input lock")
		screen._board_view._on_tile_pressed(Vector2i(3, 3))
		screen._on_end_turn()
		check(before == battle_signature() and screen._pending_path == path, "peeking cannot play, advance time or lose the pending path")
		await shot("reverse-peek-%d" % window_size.x)
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		Input.parse_input_event(escape)
		await frames()
		check(overlay._sheet.visible and not overlay._peeking and screen._modal_count == 1, "ESC returns to the retained choice instead of closing or unlocking it")
		check(screen.get_global_rect().encloses(overlay._panel.get_global_rect()), "row and column choices scroll within the viewport")
		await shot("reverse-options-%d" % window_size.x)
		var scroll: ScrollContainer = overlay._padding.get_parent()
		var options := nodes(overlay._panel, "button")
		scroll.ensure_control_visible(options.back())
		await frames()
		# ScrollContainer uses integer offsets; allow subpixel rounding after viewport scaling.
		check(scroll.get_global_rect().grow(1).encloses(options.back().get_global_rect()), "last column choice is reachable by scrolling")
		var retained_scroll := scroll.scroll_vertical
		overlay._toggle_peek()
		overlay._toggle_peek()
		await frames()
		check(scroll.scroll_vertical == retained_scroll, "board inspection preserves choice scroll position")
		overlay._on_choose(0)
		await idle()
		check(screen._modal_count == 0, "reverse still executes after viewing the board")
	await open_page("battle")
	var b: BattleState = screen.battle
	for i in 16: b.board.cells[i] = null
	var polluted := put(0, 0, "击")
	polluted.add_pollution("scorch")
	polluted.add_pollution("rush")
	polluted.add_pollution("block")
	var path := [Vector2i.ZERO]
	var before := battle_signature()
	screen._on_selection_changed(path, ["击"], null)
	var text: String = screen._bubble._effect_text
	check(text.contains("出字时") and text.contains("灼热：1伤害") and text.contains("刺痛：2伤害") and text.contains("下次补字-1"), "pollution preview states timing, each base damage and draw penalty")
	check(before == battle_signature(), "pollution preview never damages, spends shields, applies penalties or consumes RNG")
	put(1, 0, "破")
	path.append(Vector2i(1, 0))
	screen._board_view.rebuild()
	screen._board_view.path = path.duplicate()
	screen._board_view._sync_selection()
	screen._on_selection_changed(path, ["击", "破"], Database.get_word_by_glyphs_string("击破"))
	check(screen._bubble._effect_text.contains("刺痛"), "word preview retains pollution details")
	await shot("pollution-preview")
	var hot := put(0, 1, "热")
	hot.add_pollution("scorch")
	b.abilities["fireproof"] = 1
	check(EffectPreview.solo_text(hot, b, [Vector2i(0, 1)]).contains("防火生效"), "fireproof preview matches the existing exemption")
	b.bag.clear()
	b.discard.clear()
	var hui := put(0, 0, "回")
	check(EffectPreview.solo_text(hui, b, [Vector2i.ZERO]).contains("没有其他可换字"), "empty pools warn before playing hui without changing its rule")
	check(screen._confirm_btn._make_custom_tooltip("") == null, "empty hints do not create a blank tooltip")
	var tooltip: Control = screen._confirm_btn._make_custom_tooltip(screen._confirm_btn.tooltip_text)
	check(tooltip is Label and tooltip.text.contains("出字"), "commit hover contains an explicit readable operation hint")
	tooltip.free()
	b.player.temp_funds = 3
	screen._refresh_player()
	check(screen._gold_strip.item_for("temp_funds").tooltip_text.contains("优先消耗") and screen._gold_strip.item_for("temp_funds").tooltip_text.contains("清空"), "temporary funds explain payment priority and expiry at the HUD")
	await open_page("battle")
	b = screen.battle
	for i in 16: put(i % 4, i / 4, "防")
	path = select_word("合流")
	b.bag = [CharInstance.new(Database.get_character_by_glyph("防"))]
	b.discard = [CharInstance.new(Database.get_character_by_glyph("御"))]
	before = battle_signature()
	screen._on_commit(path)
	check(screen._bubble._effect_text.contains("相邻空格") and screen._bubble._effect_text.contains("未消耗") and before == battle_signature(), "unavailable merge shows an immediate reason without consuming the operation")
	b.board.set_cell(2, 2, null)
	b.board.set_cell(3, 2, null)
	screen._board_view.rebuild()
	screen._on_commit(path)
	await frames()
	var overlay := choice()
	check(overlay.cfg.body.contains("最后点「发动」"), "merge explains the whole interaction before selection")
	overlay._on_choose(overlay.cfg.options.size() - 1)
	await frames()
	check(not screen._merge_active and b.pending_reveal.is_empty() and b.bag.size() == 1 and b.board.get_cell(0, 0).glyph() == "合", "merge cancellation returns the reveal and preserves the selected word")
	screen._on_commit(path)
	await frames()
	choice()._on_choose(0)
	await frames()
	check(screen._bubble._effect_text.contains("2/3"), "merge keeps the first-placement instruction visible")
	screen._board_view._on_tile_pressed(Vector2i(2, 2))
	check(not screen._board_view._valid_pick(Vector2i(0, 3)) and screen._board_view._valid_pick(Vector2i(3, 2)), "second placement only highlights legal adjacent empty cells")
	screen._board_view._on_tile_pressed(Vector2i(3, 2))
	check(not screen._ready_action.is_empty() and screen._bubble._effect_text.contains("点击「发动」"), "merge enters an explicit final confirmation state")
	await shot("merge-ready")
	screen._on_primary()
	await idle()
	check(b.board.get_cell(2, 2).glyph() == "防" and b.board.get_cell(3, 2).glyph() == "御", "guided merge still places the two original entities")
	Router.current.queue_free()
	Router.current = null
	Router.host = null
	await frames()
	Settings.reduced_motion = saved_motion
	Ink.apply_style(GameStyle.get_style(saved_style))
	print("[frontend_feedback_test] PASS=%d FAIL=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
