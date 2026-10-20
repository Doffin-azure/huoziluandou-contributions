extends Control
## Real rendered header geometry, collection navigation and resize regression.
const QA := "res://docs/qa/header-overlay-2026-10-19/"
var passed := 0
var failed := 0
var capture := false
var before := false


func _ready() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	before = OS.get_cmdline_user_args().has("--before")
	SaveManager.enabled = false
	Settings.storage_path = "user://header-test-settings.cfg"
	Settings.reduced_motion = true
	_run.call_deferred()


func frames(n := 8) -> void:
	for i in n: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS ", message)
	else: failed += 1; push_error(message)


func shot(tag: String) -> void:
	if not capture: return
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(QA + ("before-" if before else "after-") + tag + ".png")


func button_with_text(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text == text: return child
		var result := button_with_text(child, text)
		if result != null: return result
	return null


func _run() -> void:
	Ink.apply_style(GameStyle.taopunk())
	Router.host = self
	GameState.start_new_run("v03")
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 7})
	var s := Router.current
	# Reuse the same controls: wide -> narrow must actually shrink populated rows.
	for profile in [[Vector2i(1920,1080),0], [Vector2i(1280,720),0], [Vector2i(1100,720),0], [Vector2i(2560,1440),0], [Vector2i(844,390),0], [Vector2i(1280,540),0], [Vector2i(2400,1080),440], [Vector2i(2340,1080),440]]:
		get_window().size = profile[0]
		BattleTouchLayout.test_dpi = profile[1]
		s.params["touch_layout"] = profile[1] > 0
		await frames(14)
		var tag := "%dx%d-%ddpi" % [profile[0].x,profile[0].y,profile[1]]
		s.battle.turn = 99
		GameState.gold = 999999
		s.battle.player.heat = 3
		s.battle.player.energy = 4
		for id in StatusDisplay.ABILITY_NAMES:
			if id not in StatusDisplay.ABILITY_PARAMETERS: s.battle.enable_ability(id, 2)
		s._refresh_all()
		await frames()
		var menu: Rect2 = s._menu_btn.get_global_rect()
		var gold: Rect2 = s._gold_strip.get_global_rect()
		var turn: Rect2 = s._turn_label.get_global_rect()
		var status: Rect2 = s._player_status.get_global_rect()
		check(absf(menu.get_center().y - gold.get_center().y) <= 1, tag + " menu/currency vertical centers align")
		if s._turn_label.visible:
			check(s._turn_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER and absf(menu.get_center().y-turn.get_center().y) <= 1, tag + " turn text/menu vertical centers align")
			check(not turn.intersects(status) and not turn.intersects(gold) and not turn.intersects(menu), tag + " turn has an exclusive region")
		check(not status.intersects(gold) and not status.intersects(menu) and not status.intersects(s._player_hp.get_global_rect()), tag + " buffs do not cover currency/menu/health")
		var hp_number: Label = s._player_hp_value
		var text_width := hp_number.get_theme_font("font").get_string_size(hp_number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hp_number.get_theme_font_size("font_size")).x
		check(not status.intersects(hp_number.get_global_rect()) and text_width <= hp_number.size.x + 1, tag + " full health text fits without entering buffs")
		check(s._player_status.item_for("more") != s._player_status, tag + " excess buffs fold into details")
		var fits := true
		for button in s._player_status._buttons:
			fits = fits and status.grow(1).encloses(button.get_global_rect())
		check(fits, tag + " populated row shrinks within reserved width")
		await shot(tag + "-battle")
		# Return to normal currency for the clean visual comparison.
		GameState.gold = 6
		s.battle.turn = 2
		s._refresh_all()
		await frames()
		check(s._turn_label.visible, tag + " normal turn remains visible")
		await shot(tag + "-normal")
		var overlay := CollectionOverlay.new()
		overlay.setup({"title":"字库图鉴", "subtitle":"60 种实体字 · 162 个词", "words":Database.words.values()})
		s.add_child(overlay)
		await frames(12)
		var close := button_with_text(overlay,"关闭")
		var header := close.get_parent() as Control
		check(absf(close.get_global_rect().end.x-header.get_global_rect().end.x) <= 1, tag + " collection close is at header right edge")
		check(overlay.get_global_rect().encloses(close.get_global_rect()) and close.size.y >= 48 * JourneyStyle.touch_scale(overlay), tag + " close stays onscreen with touch target")
		overlay._show_tab("words")
		await frames()
		await shot(tag + "-collection")
		var closed := [false]
		overlay.closed.connect(func(): closed[0] = true)
		close.pressed.emit()
		await frames(2)
		check(closed[0] and not is_instance_valid(overlay), tag + " close dismisses overlay")
	BattleTouchLayout.test_dpi = 0
	Router.current = null
	print("HEADER OVERLAY: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if before or failed == 0 else 1)
