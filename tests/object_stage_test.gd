extends Control
## Validate the physical object menus, including timed claims and mobile picking.
var _pass := 0
var _fail := 0
var _saved_motion := false
var _saved_style := ""
var _capture := false


func _ready() -> void:
	_saved_motion = Settings.reduced_motion
	_saved_style = Settings.visual_style
	_capture = OS.get_cmdline_user_args().has("--capture")
	Settings.reduced_motion = false
	Ink.apply_style(GameStyle.paper())
	_run.call_deferred()


func _ok(value: bool, title: String) -> void:
	if value:
		_pass += 1
		print("PASS ", title)
	else:
		_fail += 1
		push_error(title)


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _open(page: String, count := 3) -> Control:
	GameState.start_new_run("v03")
	GameState.gold = 80
	GameState.rng.seed = 20261016
	Router.goto("res://src/screens/%s_screen.gd" % page, {"count": count})
	await _frames(8)
	return Router.current


func _shot(name: String) -> void:
	if not _capture: return
	RenderingServer.force_draw(false)
	_ok(get_viewport().get_texture().get_image().save_png("res://shots/object-%s.png" % name) == OK, "capture " + name)


func _wait_screen_change(previous: Control) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while Router.current == previous and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.01).timeout


func _run() -> void:
	Router.host = self
	var reward := await _open("reward", 4)
	_ok(reward._cards.size() == 4 and reward._showcase.stage.objects.size() == 4, "four-option reward creates four actual 3D specimens")
	_ok(reward._showcase.viewport.own_world_3d and reward._showcase.stage.camera.current, "specimens use their own 3D world and camera")
	_ok(reward._selected == -1 and reward._hud.action_button.disabled, "reward requires an explicit selection before claiming")
	reward._accept_pick()
	_ok(not reward._busy and not reward._settled, "claiming without selecting cannot take a default glyph")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	reward._cards[2]._on_gui_input(click)
	var selected_title: String = reward._hud.detail_title.text
	for card: GlyphOffer in reward._cards:
		card.mouse_entered.emit()
		card.focus_entered.emit()
	_ok(reward._selected == 2 and reward._cards[2].selected and reward._hud.detail_title.text == selected_title, "crossing other glyphs or moving focus preserves the clicked selection")
	click.button_index = MOUSE_BUTTON_RIGHT
	reward._cards[1]._on_gui_input(click)
	_ok(reward._selected == 2, "right click does not change the selected reward")
	click.button_index = MOUSE_BUTTON_LEFT
	reward._cards[3]._on_gui_input(click)
	_ok(reward._selected == 3 and not reward._hud.action_button.disabled and reward._cards.filter(func(card): return card.selected).size() == 1, "left click changes selection and enables a separate claim confirmation")
	var rng: int = GameState.rng.state
	reward._inspect(3)
	await _frames(10)
	_ok(reward._hud.description.get_parsed_text() == BattleText.clean(reward._with_hint(reward._options[3]).description) and GameState.rng.state == rng, "inspection retains complete rules without consuming RNG")
	var offered: CharacterData = reward._options[3]
	for character: CharacterData in Database.characters.values():
		if character.description.contains("热度"):
			reward._options[3] = character
			break
	reward._inspect(3)
	var body: EffectText = reward._hud.description
	_ok("url=term:heat" in body.text, "reward glyph explanation links heat to the glossary")
	var words: Array = reward._words_for(reward._options[3].glyph)
	_ok(words.is_empty() or "url=word:" in body.text, "suggested reward words open their full effects")
	body.meta_hover_started.emit("term:heat")
	await _frames(2)
	_ok(body._cards.size() == 1 and body._cards[0].get_meta("entry") == "term:heat", "hovering reward heat opens its explanation")
	body.meta_clicked.emit("term:heat")
	_ok(body._pinned, "reward explanations can be pinned by clicking")
	body.open_entry("term:capacity", 1)
	_ok(body._cards.size() == 2, "reward explanations support nested glossary reading")
	reward._options[3] = offered
	reward._inspect(0)
	_ok(body._cards.is_empty(), "changing reward glyph dismisses the previous explanation")
	reward._inspect(3)
	_ok(GameState.rng.state == rng, "reading reward explanations leaves reward RNG unchanged")
	var stage: Node3D = reward._showcase.stage
	_ok(stage.objects[3].position.y > stage.rests[3].y, "inspection physically lifts the selected specimen")
	await _shot("reward-four")
	var before := GameState.deck_size()
	var weak_stage: WeakRef = weakref(stage)
	reward._accept_pick()
	reward._accept_pick()
	_ok(reward._busy and reward._hud.action_button.disabled and reward._hud.secondary_button.disabled and GameState.deck_size() == before, "claim animation locks actions without premature or double settlement")
	await _frames(2)
	_ok(stage.objects[3].position.z > stage.rests[3].z, "claim pulls the specimen toward the player")
	await _wait_screen_change(reward)
	await _frames()
	_ok(GameState.deck_size() == before + 1 and Router.current_path.ends_with("map_screen.gd"), "claim settles once and returns to the existing route")
	_ok(weak_stage.get_ref() == null, "leaving the reward releases its 3D stage")
	var shop := await _open("shop")
	var shop_body: EffectText = shop._hud.description
	_ok(shop_body.get_parsed_text().contains("可组：") and shop_body.text.contains("url=word:"), "shop glyphs show composable words as effect-help links")
	var shop_word: String = EffectGlossary.words_for_glyph(shop._offers[0].character.glyph)[0]
	shop_body.meta_hover_started.emit("word:" + shop_word)
	await _frames(2)
	_ok(shop_body._cards.size() == 1 and shop_body._cards[0].get_meta("entry") == "word:" + shop_word, "shop word hints open the full word effect on hover")
	shop_body.close_help()
	await _shot("shop-desktop")
	shop._inspect(4)
	_ok(shop._hud.detail_title.text.begins_with("复制") and shop._hud.description.text.contains("复制"), "service seals explain the original shop services")
	shop._inspect(0)
	var gold: int = GameState.gold
	before = GameState.deck_size()
	var price: int = shop._offers[0].price
	var second_rest: Vector3 = shop._showcase.stage.rests[1]
	shop._purchase_selected()
	shop._purchase_selected()
	_ok(shop._busy and GameState.gold == gold, "purchase waits for the pickup and rejects duplicate presses")
	await get_tree().create_timer(0.4).timeout
	_ok(GameState.gold == gold - price and GameState.deck_size() == before + 1 and shop._offers.size() == 6, "purchase charges the exact original price once")
	_ok(shop._showcase.stage.rests[0] == second_rest and shop._offers[0].display_slot == 1, "remaining goods retain their counter positions")
	Settings.reduced_motion = true
	Settings.changed.emit()
	_ok(not shop._showcase.stage.is_processing(), "live reduced motion stops the lantern")
	Settings.reduced_motion = false
	Settings.changed.emit()
	_ok(shop._showcase.stage.is_processing(), "restoring motion resumes the lantern")
	get_window().size = Vector2i(960, 432)
	await _frames(12)
	Settings.reduced_motion = true
	for page in ["reward", "shop"]:
		var screen := await _open(page)
		var ratio := float(get_window().size.y) / screen.size.y
		var bounds := screen.get_global_rect()
		_ok(screen._cards.all(func(card): return card.size.x * ratio >= 47.9 and card.size.y * ratio >= 47.9 and bounds.encloses(card.get_global_rect())), page + " physical picking bounds fit the phone and retain 48px targets")
		_ok(screen._cards.all(func(card): return not card._caption.get_global_rect().intersects(screen._hud.action_button.get_global_rect())), page + " price labels do not overlap the primary action")
		await _shot(page + "-phone")
	if is_instance_valid(Router.current): Router.current.queue_free()
	Router.current = null
	Router.host = null
	await _frames()
	Settings.reduced_motion = _saved_motion
	Ink.apply_style(GameStyle.get_style(_saved_style))
	print("[object_stage_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail else 0)
