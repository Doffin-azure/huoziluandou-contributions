extends Control
## Actual screens plus engine-driven mouse hover: empty descriptions must not create popups.
var checks := 0
var fails := 0
var audited_buttons := 0
var _saved_motion := false

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("[tooltip_ui] " + note)

func frames(n := 8) -> void:
	for i in n: await get_tree().process_frame

func descendants(node: Node) -> Array:
	var found: Array = []
	for child in node.get_children(true):
		found.append(child)
		found.append_array(descendants(child))
	return found

func popups() -> Array:
	return descendants(get_tree().root).filter(func(n): return n is Window and n.visible)

func popup_text() -> String:
	var texts := PackedStringArray()
	for popup in popups():
		for node in descendants(popup):
			if node is Label: texts.append(node.text)
	return "\n".join(texts).strip_edges()

func move_to(point: Vector2) -> void:
	get_viewport().warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.relative = Vector2(1, 0)
	Input.parse_input_event(motion)

func hover(control: Control) -> void:
	move_to(Vector2(2, 2))
	await frames(3)
	var point := get_viewport().get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))
	move_to(point)
	await get_tree().create_timer(0.7).timeout
	check(get_viewport().gui_get_hovered_control() == control, "real mouse reaches " + (control.text if control is Button else str(control.name)))

func audit(node: Node, page: String) -> void:
	var buttons := descendants(node).filter(func(n): return n is HintButton or n is EnemyIntent)
	for button in buttons:
		var hint: Control = button._make_custom_tooltip(button.get_tooltip())
		if button.get_tooltip().strip_edges().is_empty():
			check(hint == null, page + ": no empty popup for " + button.text)
		else:
			check(hint is Label and not hint.text.strip_edges().is_empty(), page + ": preserve real hint")
		if hint != null: hint.free()
	audited_buttons += buttons.size()
	print("AUDIT ", page, " ", buttons.size(), " shared hint controls")

func shot(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	RenderingServer.force_draw(false)
	check(get_viewport().get_texture().get_image().save_png("res://shots/tooltip-" + name + ".png") == OK, "capture " + name)

func _ready() -> void:
	_saved_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	get_window().gui_embed_subwindows = true
	get_window().grab_focus()
	Router.host = self
	for page in ["reward", "shop", "rest", "event", "map", "custom_deck", "expedition_map", "glyph_graph", "battle", "title"]:
		GameState.start_new_run("v03")
		GameState.gold = 80
		if page == "expedition_map": Expedition.start(91)
		Router.goto("res://src/screens/%s_screen.gd" % page)
		await frames(12)
		var screen: Control = Router.current
		audit(screen, page)
		var empty_buttons := descendants(screen).filter(func(n): return n is HintButton and not n.text.is_empty() and n.is_visible_in_tree() and not n.disabled and n.get_tooltip().strip_edges().is_empty() and get_viewport_rect().encloses(n.get_global_rect()))
		if not empty_buttons.is_empty():
			await hover(empty_buttons.filter(func(b): return b.text == "清空")[0] if page == "custom_deck" else empty_buttons[0])
			check(popups().is_empty(), page + ": no empty floating frame after hover")
		move_to(Vector2(2, 2))
	# Reproduce the exact rest panel in the supplied screenshot.
	var ex := Expedition.start(91)
	ex.panels = [{"kind":"rest"}]
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await frames(12)
	var screen: Control = Router.current
	var rest_buttons: Array = screen._event_box.get_children().filter(func(n): return n is Button)
	check(rest_buttons.size() == 3, "rest panel retains all three actions")
	for button in rest_buttons:
		await hover(button)
		check(popups().is_empty(), "rest action has no empty frame: " + button.text)
	await shot("rest-fixed")
	# Nonempty map descriptions and reward descriptions must remain available.
	await hover(screen._confront_btn)
	check(popup_text().contains("首领"), "real mouse hover still shows boss instructions")
	await shot("description-preserved")
	move_to(Vector2(2, 2))
	ex.panels = [{"kind":"loot","tier":"大","options":[{"kind":"relic","relic":"slab"},{"kind":"gold","gold":25}]}]
	screen.refresh()
	await frames()
	audit(screen, "expedition reward")
	var relic: Button = screen._event_box.get_children().filter(func(n): return n is Button)[0]
	await hover(relic)
	check(popup_text().contains(Relics.name_of("slab")), "relic reward retains its real tooltip")
	move_to(Vector2(2, 2))
	for overlay in [PauseOverlay.new(), SettingsOverlay.new(), ChoiceOverlay.new()]:
		if overlay is ChoiceOverlay: overlay.setup({"title":"测试选择", "options":[{"text":"继续"}]})
		screen.add_child(overlay)
		await frames()
		audit(overlay, overlay.get_class())
		var buttons := descendants(overlay).filter(func(n): return n is HintButton and n.is_visible_in_tree() and not n.disabled and n.get_tooltip().is_empty())
		if not buttons.is_empty():
			await hover(buttons[0])
			check(popups().is_empty(), "overlay actions have no empty tooltip")
		overlay.queue_free()
		move_to(Vector2(2, 2))
		await frames()
	for empty in ["", " ", "\t\n"]:
		check(Ink.tooltip(empty) == null, "shared battle tooltip rejects whitespace")
	var intent := EnemyIntent.new()
	check(intent._make_custom_tooltip("") == null, "empty enemy intent creates no tooltip")
	intent.free()
	Settings.reduced_motion = _saved_motion
	print("[tooltip_ui_test] PASS=%d FAIL=%d BUTTONS=%d" % [checks-fails,fails,audited_buttons])
	get_tree().quit(1 if fails else 0)
