extends Control
## Real screens, illustrated artwork, consistent layering, and native captures.
const FOLDER := "res://docs/qa/ui-cleanup-2026-10-18"
const PAGES := ["title", "battle", "map", "reward", "shop", "rest", "event", "custom_deck", "expedition_map", "glyph_graph", "tutorial"]
var passed := 0
var failed := 0
var before := false
var restored := false


func _ready() -> void:
	Settings.storage_path = "user://ui_consistency_test-settings.cfg"
	before = OS.get_cmdline_user_args().has("--before")
	restored = OS.get_cmdline_user_args().has("--restored")
	get_tree().create_timer(120).timeout.connect(func(): get_tree().quit(2))
	run.call_deferred()


func frames(n := 10) -> void:
	for i in n: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS ", message)
	else: failed += 1; push_error(message)


func shot(name: String) -> void:
	await frames()
	RenderingServer.force_draw(false)
	var path := FOLDER.path_join(("restored-" if restored else "before-" if before else "after-") + name + ".png")
	check(get_viewport().get_texture().get_image().save_png(path) == OK, "capture " + name)


func run() -> void:
	Settings.reduced_motion = true
	Router.host = self
	DirAccess.make_dir_recursive_absolute(FOLDER)
	for dimensions in [Vector2i(1440,810), Vector2i(960,432)]:
		get_window().size = dimensions
		await frames()
		var suffix := "-%dx%d" % [dimensions.x, dimensions.y]
		for page in PAGES:
			GameState.start_new_run()
			GameState.rng.seed = 20261016
			GameState.gold = 80
			if page == "expedition_map": Expedition.start(20261016)
			Router.goto("res://src/screens/%s_screen.gd" % page, {"seed": 7})
			await frames(18)
			check(Router.current.get_global_rect().size.is_equal_approx(get_viewport_rect().size), page + suffix + " fills viewport")
			await shot(page + suffix)
			if page != "battle": continue
			var battle: Control = Router.current
			if not before:
				var primary: Button = battle._confirm_btn
				check(primary.get_child_count() == 1 and primary.get_child(0).material is ShaderMaterial, "commit retains its illustrated seal")
				for paper in [battle._preview_panel.get_child(0), battle._enemy_paper]:
					var material: ShaderMaterial = paper.material
					check(material != null and material.shader.resource_path.ends_with("taopunk_paper.gdshader") and material.get_shader_parameter("paper_texture") != null, "side panel retains original texture and decorative edge")
				check(battle._preview_panel.get_index() < battle._board_view.get_index() and battle._enemy_paper.get_index() < battle._board_view.get_index(), "both side backgrounds draw behind the board frame")
			for kind in ["menu", "settings", "choice", "collection"]:
				var overlay: Control
				match kind:
					"menu": overlay = PauseOverlay.new()
					"settings": overlay = SettingsOverlay.new()
					"choice":
						overlay = ChoiceOverlay.new()
						overlay.setup({"title":"选择行动", "body":"查看字盘与状态后再决定。", "options":[{"text":"继续", "primary":true}, {"text":"返回"}]})
					"collection":
						overlay = CollectionOverlay.new()
						overlay.setup({"title":"字袋", "characters":Database.char_by_glyph.values(), "counts":GameState.glyph_counts()})
				battle._mount_overlay(overlay)
				await shot(kind + suffix)
				if not before:
					check(overlay.get_theme_stylebox("normal", "Button") is StyleBoxTexture, kind + " retains illustrated journey controls")
				overlay.queue_free()
				await frames()
	Router.release_host(self)
	print("UI CONSISTENCY: %d passed / %d failed" % [passed, failed])
	get_tree().quit(1 if failed else 0)
