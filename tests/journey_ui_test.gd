extends Control
## Capture real non-combat screens and verify their existing actions after the reskin.
var _pass := 0
var _fail := 0
var _capture := false
var _baseline := false
var _saved_motion := false
var _saved_style := ""
const BASELINE := "res://tests/fixtures/journey_ui_seed_20261016.json"
var _snapshot: Dictionary = {}
const PAGES := ["reward", "shop", "rest", "event", "map", "custom_deck", "expedition_map", "glyph_graph"]


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_baseline = OS.get_cmdline_user_args().has("--baseline")
	_saved_motion = Settings.reduced_motion
	_saved_style = Settings.visual_style
	Settings.reduced_motion = true
	Ink.apply_style(GameStyle.paper())
	_run.call_deferred()


func _frames(count := 6) -> void:
	for i in count: await get_tree().process_frame


func _ok(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("PASS ", message)
	else:
		_fail += 1
		push_error(message)


func _open(page: String) -> Control:
	GameState.start_new_run("v03")
	GameState.gold = 80
	GameState.player_hp = 37
	GameState.rng.seed = 20261016
	if page == "expedition_map": Expedition.start(20261016)
	Router.goto("res://src/screens/%s_screen.gd" % page)
	await _frames(12)
	return Router.current


func _shot(name: String) -> void:
	if not _capture: return
	RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	_ok(image.save_png("res://shots/journey-%s-%s.png" % ["before" if _baseline else "after", name]) == OK, "capture " + name)


func _run() -> void:
	Router.host = self
	for page in PAGES:
		var screen := await _open(page)
		_ok(is_instance_valid(screen.content), page + " screen builds")
		if page == "reward":
			_snapshot.reward = screen._options.map(func(item): return item.id)
			_snapshot.reward_rng = str(GameState.rng.state)
		elif page == "shop":
			# 遗物货架用旁路随机数，单独校验；这里只比原有货物
			_snapshot.shop = screen._offers.filter(func(item): return item.kind != "relic").map(func(item): return [item.kind, item.character.id if item.character != null else "", item.price])
			_snapshot.shop_rng = str(GameState.rng.state)
		elif page == "event":
			_snapshot.event = screen._event.id
			_snapshot.event_rng = str(GameState.rng.state)
		await _shot(page)
	var picker := CollectionOverlay.new()
	picker.setup({"title": "字库图鉴", "words": Database.words.values()})
	Router.current.add_child(picker)
	await _frames(12)
	await _shot("collection")
	picker._show_tab("words")
	await _frames(8)
	await _shot("collection-words")
	var effects := _descendants(picker, "effect")
	_ok(not effects.is_empty(), "word collection retains readable linked rule descriptions")
	var source: EffectText = effects[0]
	source.open_entry("term:block")
	await _frames(8)
	_ok(not source._cards.is_empty() and source._cards[0].theme.get_color("font_color", "Label") == JourneyStyle.TEXT, "journey rule popover explicitly retains ivory text across CanvasLayer")
	await _shot("effect-help")
	source.close_help()
	picker.queue_free()
	await _frames()
	var settings := SettingsOverlay.new()
	Router.current.add_child(settings)
	await _frames()
	await _shot("settings")
	settings.queue_free()
	await _frames()
	var choice := ChoiceOverlay.new()
	choice.setup({"title": "岔路", "body": "荒径分岔，前方的路由你决定。", "options": [{"text": "挑战精英", "primary": true}, {"text": "寻访事件"}, {"text": "再想想"}]})
	Router.current.add_child(choice)
	await _frames()
	await _shot("choice")
	choice.queue_free()
	await _frames()
	var menu := PauseOverlay.new()
	Router.current.add_child(menu)
	await _frames(8)
	await _shot("menu")
	menu._buttons[0].grab_focus()
	await _escape()
	_ok(not is_instance_valid(menu), "ESC closes the menu even after a button receives keyboard focus")
	if is_instance_valid(menu): menu._close()
	await _frames()
	if _baseline:
		var file := FileAccess.open(BASELINE, FileAccess.WRITE)
		file.store_string(JSON.stringify(_snapshot))
	else:
		if FileAccess.file_exists(BASELINE):
			var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
			_ok(JSON.stringify(JSON.parse_string(JSON.stringify(_snapshot))) == JSON.stringify(expected), "presentation preserves reward offers, shop prices, event choice and RNG states")
		await _verify_actions()
		await _verify_mobile()
		await _verify_expedition_merge()
	if is_instance_valid(Router.current): Router.current.queue_free()
	Router.current = null
	Router.host = null
	await _frames()
	Settings.reduced_motion = _saved_motion
	Settings.set_visual_style(_saved_style)
	Ink.apply_style(GameStyle.get_style(_saved_style))
	print("[journey_ui_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail else 0)


func _verify_actions() -> void:
	var reward := await _open("reward")
	var deck_before := GameState.deck_size()
	var node_before: int = GameState.node_index
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	reward._cards[0]._on_gui_input(click)
	_ok(GameState.deck_size() == deck_before, "inspecting a reward does not claim it prematurely")
	reward._hud.action_button.pressed.emit()
	await _frames()
	_ok(GameState.deck_size() == deck_before + 1 and GameState.node_index == node_before + 1, "reward selection adds one glyph and advances one node")
	var shop := await _open("shop")
	var gold_before: int = GameState.gold
	deck_before = GameState.deck_size()
	var price: int = shop._offers[0].price
	shop._buy(0)
	await _frames()
	_ok(GameState.gold == gold_before - price and GameState.deck_size() == deck_before + 1, "shop purchase retains the exact price and glyph")
	shop._choose_char("选择要复制的字")
	await _frames()
	var picker: CollectionOverlay
	for child in shop.get_children():
		if child is CollectionOverlay: picker = child
	var owned := GameState.glyph_counts()
	_ok(picker != null and not picker.cfg.characters.is_empty() and picker.cfg.characters.all(func(ch): return owned.has(ch.glyph)), "shop glyph picker contains owned glyphs rather than the entire database")
	picker._close()
	await _frames()
	var empty := CollectionOverlay.new()
	empty.setup({"characters": []})
	shop.add_child(empty)
	await _frames()
	_ok(empty._grid.get_child_count() == 0, "an explicitly empty collection does not fall back to the full database")
	empty._close()
	GameState.gold = 0
	shop._refresh()
	await _frames()
	deck_before = GameState.deck_size()
	shop._buy(0)
	_ok(GameState.deck_size() == deck_before and GameState.gold == 0, "insufficient funds cannot buy a glyph")
	var current := Router.current
	var rng_state: int = GameState.rng.state
	var offer_count: int = shop._offers.size()
	var settings := SettingsOverlay.new()
	shop.add_child(settings)
	settings._set_style("neon")
	await _frames()
	_ok(Router.current == current and GameState.rng.state == rng_state and shop._offers.size() == offer_count, "battle theme setting does not recreate the shop or reroll its offers")
	settings.queue_free()
	Ink.apply_style(GameStyle.paper())
	var rest := await _open("rest")
	var hp_before: int = GameState.player_hp
	var healing: int = rest._heal_amount()
	rest._do_heal()
	await _frames()
	_ok(GameState.player_hp == mini(GameState.player_max_hp, hp_before + healing), "rest healing is unchanged")


func _descendants(node: Node, kind: String) -> Array:
	var found: Array = []
	for child in node.get_children():
		if (kind == "card" and (child is CharCard or child is GlyphOffer)) or (kind == "button" and child is Button) or (kind == "effect" and child is EffectText): found.append(child)
		found.append_array(_descendants(child, kind))
	return found


func _escape() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await _frames()
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = false
	Input.parse_input_event(key)


func _verify_mobile() -> void:
	get_window().size = Vector2i(960, 432)
	await _frames(12)
	for page in ["reward", "shop", "rest", "map", "custom_deck", "expedition_map", "glyph_graph"]:
		var screen := await _open(page)
		var bounds := screen.get_global_rect()
		var buttons := _descendants(screen, "button")
		var ratio := float(get_window().size.y) / screen.size.y
		_ok(buttons.all(func(button): return button.get_global_rect().end.x <= bounds.end.x + 1), page + " phone buttons remain within horizontal bounds")
		if page in ["reward", "shop", "rest"]:
			_ok(buttons.all(func(button): return button.size.y * ratio >= 47.9), page + " phone actions retain 48px height")
		if page == "reward":
			var cards := _descendants(screen, "card")
			_ok(cards.size() == 3 and cards.all(func(card): return card.get_global_rect().end.x <= bounds.end.x + 1), "phone reward retains three readable glyphs")
		await _shot(page + "-phone")
		if page == "expedition_map":
			_ok(screen._map_view.size.distance_to(screen.size) < 1.0 and not screen._actor_panel.visible, "phone expedition keeps the world full screen with inventory collapsed")
			var tick: int = screen.ex.t
			var rng: int = screen.ex.rng.state
			screen._mobile_tabs.show_tab("构筑")
			await _frames()
			_ok(screen.ex.t == tick and screen.ex.rng.state == rng and screen._build_box.is_visible_in_tree(), "expedition tabs only change the view, not time or RNG")
			await _shot("expedition-plate-phone")
			screen._build_scroll.ensure_control_visible(screen._tray_row)
			await _frames()
			_ok(screen._build_scroll.get_global_rect().encloses(screen._tray_row.get_global_rect()), "phone construction tab can scroll to the character tray")
			await _shot("expedition-tray-phone")
			var steps: Array = MapGen.nbrs(screen.ex.pos).filter(func(k): return screen.ex.can_step(k))
			if not steps.is_empty():
				var destination: int = steps[0]
				screen._map_view.cell_pressed.emit(destination)
				await _frames(12)
				_ok(screen.ex.pos == destination and screen.ex.t > tick, "world cell click still forwards movement to the existing rules")
				_ok(screen._map_view.following, "moving in the world resumes camera following")
	var picker := CollectionOverlay.new()
	picker.setup({"title": "字袋", "characters": [GameState.deck[0].data], "counts": GameState.glyph_counts()})
	Router.current.add_child(picker)
	await _frames(12)
	_ok(picker._grid.columns <= 3 and picker._grid.get_child_count() == 1, "phone collection reflows columns and respects the supplied deck")
	await _shot("collection-phone")
	picker._close()
	await _frames()
	var settings := SettingsOverlay.new()
	Router.current.add_child(settings)
	await _frames(12)
	await _shot("settings-phone")
	settings.queue_free()
	await _frames()


func _verify_expedition_merge() -> void:
	var screen := await _open("expedition_map")
	var ex: Expedition = screen.ex
	_ok(not ex.has_method("open_wish") and screen._build_box != null, "merged map uses current construction rules without the removed wish machine")
	GameState.relics = Relics.DEFS.keys()
	screen.refresh()
	await _frames()
	_ok(screen._relic_label.get_theme_color("font_color") == JourneyStyle.GOLD and screen._relic_label.tooltip_text.contains(Relics.desc_of("press")), "merged relic inventory retains readable art colors and full descriptions")
	for window_size in [Vector2i(960, 432), Vector2i(1440, 810)]:
		get_window().size = window_size
		await _frames(12)
		Router.goto("res://src/screens/expedition_map_screen.gd")
		await _frames(12)
		screen = Router.current
		var bounds := screen.get_global_rect()
		var buttons := _descendants(screen._confront_btn.get_parent(), "button").filter(func(button): return button.is_visible_in_tree())
		_ok(buttons.all(func(button): return bounds.encloses(button.get_global_rect())), "late-run expedition actions fit with all relics at %s" % window_size)
		await _shot("expedition-relics-%d" % window_size.x)
	ex.fight = {"kind":"boss", "k":ex.boss, "g":"对", "name":"首领", "caught":false, "debuff":""}
	ex.finish_battle(true)
	screen.refresh()
	await _frames()
	_ok(ex.boss_down and screen._confront_btn.disabled and screen._confront_btn.text == "本层已结束", "defeated boss seals the map immediately under current planning rules")
	_ok(ex.top_panel().get("kind", "") == "act_end", "boss victory automatically opens the settlement panel")
