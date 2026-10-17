extends Control
## Retired frontend assets stay retired; old preferences retain all unrelated values.
var passed := 0
var failed := 0

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS ", message)
	else: failed += 1; push_error(message)

func run() -> void:
	var original_style: GameStyle = Ink.style
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/frontend-legacy-cleanup")) == OK, "isolated settings directory is available")
	for id in ["neon", "unknown", "paper", "taopunk"]:
		var path := "res://shots/frontend-legacy-cleanup/settings-%s.cfg" % id
		var config := ConfigFile.new()
		config.set_value("visual", "art_style", id)
		config.set_value("visual", "style", "neon")
		config.set_value("visual", "board_font", "res://assets/fonts/NotoSerifSC-VF.ttf")
		config.set_value("visual", "reduced_motion", true)
		config.set_value("audio", "sfx_volume", 0.31)
		config.set_value("input", "drag_release_play", true)
		config.set_value("custom", "keep", "unchanged")
		check(config.save(path) == OK, id + " isolated settings fixture saves")
		var local = load("res://src/autoload/settings.gd").new()
		local.storage_path = path
		add_child(local)
		var expected := "taopunk"
		check(local.visual_style == expected and GameStyle.get_style(id).id == expected, id + " resolves to a supported theme")
		check(local.reduced_motion and local.drag_release_play and is_equal_approx(local.sfx_volume, 0.31) and local.board_font_path.ends_with("NotoSerifSC-VF.ttf"), id + " migration preserves motion, input, volume and font preferences")
		local.set_visual_style("paper")
		local.set_visual_style("neon")
		var saved := ConfigFile.new()
		check(saved.load(path) == OK and saved.get_value("visual", "art_style") == "taopunk" and not saved.has_section_key("visual", "style") and saved.get_value("custom", "keep") == "unchanged", id + " setter persists the supported id without duplicate legacy keys")
		local.queue_free()
		await get_tree().process_frame
	for retained_style in [GameStyle.taopunk(), GameStyle.paper()]:
		var id: String = retained_style.id
		Ink.apply_style(retained_style)
		var background := Ink.background()
		var material := Ink.make_tile_material(Color("d9c7ab"))
		check(background.material.shader.resource_path.ends_with("/paper.gdshader") and material.shader.resource_path.ends_with("/wood.gdshader"), id + " retains its paper and wood materials")
		var skin := Ink.theme.get_stylebox("normal", "Button") as StyleBoxFlat
		check(skin.bg_color == Palette.PAPER_WARM and skin.shadow_size == 0 and skin.corner_radius_top_left == 8 + Palette.CORNER_BONUS, id + " keeps its exact panel color, radius and shadow behavior")
		background.free()
	var settings := SettingsOverlay.new()
	add_child(settings)
	await get_tree().process_frame
	check(settings.find_children("*", "Button", true, false).all(func(b): return not b.text.contains("宣纸活字") and not b.text.contains("青铜绘卷") and not b.text.contains("墨芯")) and settings.find_children("*", "Control", true, false).any(func(c): return c is BoardFontPicker), "settings retain the font picker without theme switching")
	settings.queue_free()
	Ink.apply_style(original_style)
	await get_tree().process_frame
	print("[frontend_cleanup_test] PASS=%d FAIL=%d" % [passed, failed])
	get_tree().quit(1 if failed else 0)
