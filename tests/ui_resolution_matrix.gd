extends Control
## Native renderer archive. No setting setters or gameplay actions are called.
var archive := "res://docs/qa/ui-resolution-2026-10-17/"
const PROFILES := [
	["phone-640x360", 640, 360], ["iphone-se", 667, 375],
	["iphone-x", 812, 375], ["iphone-13", 844, 390],
	["iphone-14-pro", 852, 393], ["iphone-xr", 896, 414],
	["pixel-7", 915, 412], ["iphone-pro-max", 932, 430],
	["android-20x9", 960, 432], ["tablet-4x3", 1024, 768],
	["desktop-small", 1024, 576], ["hd", 1280, 720],
	["laptop", 1366, 768], ["desktop-900p", 1600, 900],
	["fhd", 1920, 1080], ["qhd", 2560, 1440],
	["ultrawide", 2560, 1080], ["uhd", 3840, 2160]]
const DENSITY_PROFILES := [
 ["apk-2436-480dpi",2436,1120,480], ["android-720-320dpi",1600,720,320],
 ["android-1080-440dpi",2400,1080,440], ["android-1440-560dpi",3200,1440,560],
 ["compact-1280-320dpi",1280,720,320], ["tablet-1920-240dpi",1920,1200,240],
 ["desktop-hd",1280,720,0], ["desktop-fhd",1920,1080,0]]
var density_matrix := false
var phase := "before"
var filter := ""
var results: Array = []
var profile := ""
var folder := ""
var saved_motion := false
var extras_only := false
var stress_only := false
var battle_only := false
var layout_only := false
var info_only := false

func _ready() -> void:
	Settings.storage_path = "user://ui_resolution_matrix-settings.cfg"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.get_slice("=", 1)
		if arg.begins_with("--profile="): filter = arg.get_slice("=", 1)
		if arg.begins_with("--archive="): archive = "res://" + arg.get_slice("=",1).trim_suffix("/") + "/"
		if arg == "--density-matrix": density_matrix = true
		if arg == "--extras-only": extras_only = true
		if arg == "--stress-only": stress_only = true
		if arg == "--battle-only": battle_only = true
		if arg == "--layout-only": layout_only = true
		if arg == "--info-only": info_only = true
	saved_motion = Settings.reduced_motion
	Settings.reduced_motion = true
	_run.call_deferred()

func frames(count := 4) -> void:
	for i in count: await get_tree().process_frame

func open_page(page: String, extra: Dictionary = {}) -> Control:
	GameState.start_new_run("v03")
	GameState.gold = 80
	GameState.player_hp = 37
	GameState.rng.seed = 20261016
	if page == "expedition_map": Expedition.start(20261016)
	Router.goto("res://src/screens/%s_screen.gd" % page, extra)
	await frames(8)
	return Router.current

func shot(state: String, subject: Control = null) -> void:
	await frames()
	RenderingServer.force_draw(false)
	var picture := get_viewport().get_texture().get_image()
	var path := folder + state + ".png"
	var error := picture.save_png(path)
	var leaves: Array = []
	var bounds: Array = []
	var clipped: Array = []
	var root := subject if subject != null else Router.current
	inspect(root, false, leaves, bounds)
	for leaf in leaves:
		var c := Router.current.get_node_or_null(NodePath(leaf.path)) as Control
		if c == null: continue
		var parent := c.get_parent()
		while parent != null and parent != Router.current:
			if parent is CanvasLayer: break
			if parent is ScrollContainer and parent.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED:
				var a := parent.get_global_rect() as Rect2
				var b := c.get_global_rect()
				if b.position.x < a.position.x - 2 or b.end.x > a.end.x + 2:
					clipped.append(leaf)
				break
			parent = parent.get_parent()
	if state.begins_with("battle"):
		for enemy in Router.current._enemy_widgets:
			var label: Label = enemy._hp_number
			var extent := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size"))
			if extent.x > label.size.x + 1: clipped.append({"text": label.text, "reason": "hp text width"})
	var overlaps: Array = []
	if state.begins_with("shop") or state == "reward-four":
		for card in Router.current._cards:
			if card._caption.get_global_rect().intersects(Router.current._hud.action_button.get_global_rect()): overlaps.append("price/action")
	results.append({"profile": profile, "state": state, "image": profile + "/" + state + ".png", "dpi": BattleTouchLayout.test_dpi, "pixels": [picture.get_width(), picture.get_height()], "viewport": [size.x, size.y], "outside": bounds, "clipped": clipped, "overlaps": overlaps, "controls": leaves, "saved": error == OK})

func save_results() -> void:
	var suffix := "-extras" if extras_only else ""
	if stress_only: suffix = "-stress"
	if battle_only: suffix = "-battle"
	if layout_only: suffix = "-layout"
	if info_only: suffix = "-info"
	var prefix := "zz-" if battle_only or layout_only else ""
	if info_only: prefix = "zzz-"
	var file := FileAccess.open(archive + phase + "/" + prefix + profile + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	results.clear()
	print("MATRIX ", phase, " ", profile, suffix, " complete")

func inspect(node: Node, scrolling: bool, leaves: Array, bounds: Array) -> void:
	if node is CanvasLayer: scrolling = false
	if node is Control:
		var c := node as Control
		if not c.is_visible_in_tree(): return
		var rect := c.get_global_rect()
		if c is Button or c is Label or c is RichTextLabel or c is ScrollContainer:
			var text := str(c.get("text")) if not c is ScrollContainer else "[scroll]"
			var item := {"path": str(Router.current.get_path_to(c)), "type": c.get_class(), "text": text.left(80), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "scrolling": scrolling}
			leaves.append(item)
			if not scrolling and rect.has_area() and not Rect2(Vector2(-2,-2), size + Vector2(4,4)).encloses(rect): bounds.append(item)
		if c is ScrollContainer: scrolling = true
	for child in node.get_children(): inspect(child, scrolling, leaves, bounds)

func overlay_shot(name: String, overlay: Control) -> void:
	Router.current.add_child(overlay)
	await shot(name, overlay)
	overlay.queue_free()
	await frames(3)

func _run() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames()
	for p in (DENSITY_PROFILES if density_matrix else PROFILES):
		if not filter.is_empty() and p[0] != filter: continue
		BattleTouchLayout.test_dpi = float(p[3]) if p.size() > 3 else 0.0
		profile = p[0]
		folder = archive + phase + "/" + profile + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
		get_window().size = Vector2i(p[1], p[2])
		await frames(8)
		if info_only:
			await info_shots()
			save_results()
			continue
		if layout_only:
			await layout_shots()
			save_results()
			continue
		if battle_only:
			await battle_shots()
			await battle_deck_shot()
			await stress_battle()
			save_results()
			continue
		if stress_only:
			await stress_shots()
			save_results()
			continue
		if extras_only:
			await extra_shots()
			save_results()
			continue
		await open_page("title")
		await shot("title")
		await overlay_shot("settings-top", SettingsOverlay.new())
		var settings := SettingsOverlay.new()
		Router.current.add_child(settings)
		await frames()
		for c in settings.find_children("*", "ScrollContainer", true, false): c.scroll_vertical = 10000
		await shot("settings-bottom", settings)
		settings.queue_free()
		await overlay_shot("pause", PauseOverlay.new())
		var collection := CollectionOverlay.new()
		collection.setup({"title": "字库图鉴", "words": Database.words.values()})
		Router.current.add_child(collection)
		await shot("collection-chars", collection)
		collection._show_tab("words")
		await shot("collection-words", collection)
		var sources := collection.find_children("*", "RichTextLabel", true, false)
		for source in sources:
			if source is EffectText:
				source.open_entry("term:block")
				source._pinned = true
				await shot("effect-help", collection)
				source.close_help()
				break
		collection.queue_free()
		await frames(3)
		CollectionOverlay.open_deck(Router.current)
		await frames()
		for child in Router.current.get_children():
			if child is CollectionOverlay:
				await shot("deck", child)
				child.queue_free()
		var choice := ChoiceOverlay.new()
		choice.setup({"title": "岔路 · 挑战与取舍", "body": "荒径分岔，前方的路由你决定。\n长说明与选项应完整可读，内容较多时可以滚动查看。", "options": [{"text": "挑战精英，获得一枚印章与稀有字", "primary": true}, {"text": "寻访事件，探索残碑背后的故事"}, {"text": "暂且休整，然后继续前行"}]})
		await overlay_shot("choice", choice)
		await open_page("custom_deck")
		await shot("custom-deck")
		var graph := await open_page("glyph_graph")
		await shot("glyph-graph")
		if not graph._view.nodes.is_empty():
			graph._view.select(str(graph._view.nodes[0].glyph))
			await shot("glyph-detail")
		await open_page("map")
		await shot("map")
		var rest := await open_page("rest")
		await shot("rest")
		rest._do_remove()
		await shot("rest-picker")
		for seed_value in [7, 8, 9]:
			GameState.rng.seed = seed_value
			var event := await open_page("event")
			# Pick deterministic seeds explicitly after open_page's baseline reset.
			if seed_value != 7:
				GameState.rng.seed = seed_value
				Router.goto("res://src/screens/event_screen.gd")
				await frames(16)
				event = Router.current
			await shot("event-" + str(event._event.id))
		var reward := await open_page("reward", {"count": 4})
		reward._inspect(3)
		await shot("reward-four")
		var shop := await open_page("shop")
		await shot("shop")
		shop._inspect(4)
		await shot("shop-service")
		var expedition := await open_page("expedition_map")
		await shot("expedition-map")
		if expedition._mobile_tabs != null:
			expedition._mobile_tabs.show_tab("字阵")
			await shot("expedition-plate")
			expedition._mobile_tabs.show_tab("战报")
			await shot("expedition-log")
			expedition._mobile_tabs.show_tab("行旅")
		else:
			await shot("expedition-plate")
			await shot("expedition-log")
		expedition._legend_box.show()
		await shot("expedition-legend")
		expedition._legend_box.hide()
		for kind in ["rest", "shop", "forge", "act_end"]:
			expedition.ex.panels = [{"kind": kind}]
			expedition.refresh()
			await shot("expedition-" + kind)
		expedition.ex.over = true
		expedition.ex.won = true
		expedition.refresh()
		await shot("expedition-win")
		expedition.ex.won = false
		expedition.refresh()
		await shot("expedition-loss")
		await battle_shots()
		await extra_shots()
		save_results()
	if is_instance_valid(Router.current): Router.current.queue_free()
	Router.current = null
	Router.host = null
	Router.study_stage = null
	Settings.reduced_motion = saved_motion
	get_tree().quit()

func extra_shots() -> void:
	for index in 3:
		await open_page("event")
		var event_script = load("res://src/screens/event_screen.gd")
		for candidate in 100:
			GameState.rng.seed = candidate
			if GameState.rng.randi_range(0, 2) == index:
				GameState.rng.seed = candidate
				break
		Router.goto("res://src/screens/event_screen.gd")
		await frames(8)
		await shot("event-all-" + str(event_script.EVENTS[index].id))
	var shop := await open_page("shop")
	shop._choose_char("选择要复制的字")
	await shot("shop-picker")
	var expedition := await open_page("expedition_map")
	if expedition._mobile_tabs != null:
		expedition._mobile_tabs.show_tab("整备")
	await shot("expedition-actions")
	if expedition._mobile_tabs != null: expedition._mobile_tabs.show_tab("行旅")
	var panels: Array = [{"kind": "loot", "tier": "大", "options": expedition.ex.loot_options("大")}, {"kind": "seal_swap", "seal": Expedition.SEALS.keys()[0]}, {"kind": "relic_bind", "relic": Relics.DEFS.keys()[0]}]
	for p in panels:
		expedition.ex.panels = [p]
		expedition.refresh()
		await shot("expedition-" + str(p.kind))
	for index in Expedition.EVENTS.size():
		expedition.ex.panels = [{"kind": "event", "event": index}]
		expedition.refresh()
		await shot("expedition-mystery-%d" % index)
	expedition.ex.panels.clear()
	expedition.ex.fight = {"kind": "boss", "g": "雷", "caught": true}
	expedition.refresh()
	await shot("expedition-boss")
	await battle_deck_shot()

func stress_shots() -> void:
	var expedition := await open_page("expedition_map")
	expedition.ex.seals = Expedition.SEALS.keys().slice(1, Expedition.SEAL_CAP + 1)
	GameState.relics = Relics.DEFS.keys()
	expedition.ex.panels = [{"kind": "seal_swap", "seal": Expedition.SEALS.keys()[0]}]
	expedition.refresh()
	await shot("expedition-seal-full")
	expedition.ex.panels = [{"kind": "relic_bind", "relic": "slab"}]
	expedition.refresh()
	await shot("expedition-bind-full")
	if expedition._mobile_tabs != null: expedition._mobile_tabs.show_tab("整备")
	await shot("expedition-late")
	await stress_battle()

func battle_shots() -> void:
	var enemy := EnemyData.new()
	enemy.id = "needle_wasp"
	enemy.name = "连针蜂"
	enemy.max_hp = 100
	enemy.moves = [EnemyMoveData.new()]
	var battle_node := MapNodeData.new()
	battle_node.enemies = [enemy, enemy.duplicate(), enemy.duplicate()]
	var battle := await open_page("battle", {"node": battle_node, "seed": 7})
	battle.battle.player.heat = 3
	battle.battle.player.energy = 2
	battle.battle.player.add_status("vulnerable", 2)
	battle._refresh_all()
	await shot("battle-status")
	battle._toggle_log()
	await shot("battle-log")
	battle._toggle_log()
	battle._open_pile("bag")
	await shot("battle-pile")
	for child in battle.get_children():
		if child is BattlePileOverlay: child.queue_free()
	await frames()
	battle._show_defeat()
	await shot("battle-defeat")

func battle_deck_shot() -> void:
	var enemy := EnemyData.new()
	enemy.id = "needle_wasp"
	enemy.name = "连针蜂"
	enemy.max_hp = 100
	enemy.moves = [EnemyMoveData.new()]
	var n := MapNodeData.new()
	n.enemies = [enemy]
	var battle := await open_page("battle", {"node": n, "seed": 7})
	battle._open_deck()
	await frames()
	for child in battle.get_children():
		if child is CollectionOverlay:
			child._show_tab("words")
			await shot("battle-deck-words", child)


func stress_battle() -> void:
	var enemy := EnemyData.new()
	enemy.id = "needle_wasp"
	enemy.name = "连针蜂"
	enemy.max_hp = 1000
	enemy.moves = [EnemyMoveData.new()]
	var n := MapNodeData.new()
	n.enemies = [enemy]
	await open_page("battle", {"node": n, "seed": 7})
	GameState.relics = ["press"]
	Router.goto("res://src/screens/battle_screen.gd", {"node": n, "seed": 7})
	await frames(16)
	Router.current.battle.player.heat = 9
	Router.current.battle.player.energy = 12
	Router.current._refresh_all()
	await shot("battle-five")


func layout_shots() -> void:
	var route := await open_page("map")
	await shot("map")
	if route._mobile:
		route._open_route_guide()
		await frames()
		for child in route.get_children():
			if child is ChoiceOverlay:
				await shot("map-guide", child)
				child.queue_free()
	var expedition := await open_page("expedition_map")
	await shot("expedition-map")
	if expedition._mobile_tabs != null:
		for tab in [["字阵","expedition-plate"],["战报","expedition-log"],["整备","expedition-actions"]]:
			expedition._mobile_tabs.show_tab(tab[0])
			await shot(tab[1])
		expedition._open_loadout()
		await frames()
		for child in expedition.get_children():
			if child is ChoiceOverlay:
				await shot("expedition-loadout-detail", child)
				child.queue_free()
		expedition._mobile_tabs.show_tab("行旅")
		expedition._open_guide()
		await frames()
		for child in expedition.get_children():
			if child is ChoiceOverlay:
				await shot("expedition-legend", child)
				await shot("expedition-guide", child)
				child.queue_free()
	else:
		expedition._legend_box.show()
		await shot("expedition-legend")
		expedition._legend_box.hide()
	for kind in ["rest", "shop", "forge", "act_end"]:
		expedition.ex.panels = [{"kind": kind}]
		expedition.refresh()
		await shot("expedition-" + kind)
	expedition.ex.over = true
	expedition.ex.won = true
	expedition.refresh()
	await shot("expedition-win")
	expedition.ex.won = false
	expedition.refresh()
	await shot("expedition-loss")
	await extra_shots()
	await stress_shots()

func info_shots() -> void:
	var route := await open_page("map")
	if route._mobile:
		route._open_route_guide()
		await frames()
		for child in route.get_children():
			if child is ChoiceOverlay:
				await shot("map-guide", child)
				child.queue_free()
	var expedition := await open_page("expedition_map")
	if expedition._mobile_tabs == null: return
	expedition._mobile_tabs.show_tab("整备")
	expedition._open_loadout()
	await frames()
	for child in expedition.get_children():
		if child is ChoiceOverlay:
			await shot("expedition-loadout-detail", child)
			child.queue_free()
	expedition._mobile_tabs.show_tab("行旅")
	expedition._open_guide()
	await frames()
	for child in expedition.get_children():
		if child is ChoiceOverlay:
			await shot("expedition-legend", child)
			await shot("expedition-guide", child)
			child.queue_free()
