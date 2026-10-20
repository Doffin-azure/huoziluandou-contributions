extends Control
## Native preview and real battle captures for the shared player/enemy status tiles.
const QA := "res://docs/qa/status-tiles-2026-10-20/"


func _ready() -> void:
	Settings.storage_path = "user://status-tiles-capture-settings.cfg"
	Settings.reduced_motion = true
	SaveManager.enabled = false
	Engine.max_fps = 120
	Router.host = self
	DirAccess.make_dir_recursive_absolute(QA)
	_run.call_deferred()


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 128)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Palette.STAGE
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var strip := StatusStrip.new()
	strip.position = Vector2(24, 16)
	strip.size = Vector2(592, 96)
	viewport.add_child(strip)
	strip.set_ui_scale(2.5)
	var sample: Array = []
	for id in ["poison", "vulnerable", "permanent_guard", "heart_layers", "next_bonus", "regen", "strength", "burn"]:
		var data := Database.get_status(id)
		if data != null:
			sample.append(StatusDisplay.entry(id, data.name, data.glyph, 2, data.description, data.color, data.kind))
		else:
			var guard: bool = id == "permanent_guard"
			sample.append(StatusDisplay.entry(id, "永久减伤" if guard else "心力", "防" if guard else "心", 1 if guard else 2, "预览", Palette.JADE if guard else Palette.VERMILION))
	strip.set_entries(sample)
	await _frames()
	RenderingServer.force_draw(false)
	assert(viewport.get_texture().get_image().save_png(QA + "tiles.png") == OK)
	viewport.queue_free()

	get_window().size = Vector2i(1280, 720)
	GameState.start_new_run()
	var node := MapNodeData.new()
	node.enemies = [Database.get_enemy("ink_creditor")]
	Router.goto("res://src/screens/battle_screen.gd", {"node": node, "seed": 7})
	await _frames(16)
	var screen: Control = Router.current
	var battle: BattleState = screen.battle
	for unit: Combatant in [battle.player, battle.enemies[0]]:
		unit.statuses = {"poison": 2, "vulnerable": 2, "next_bonus": 2, "regen": 1, "strength": 3, "burn": 1}
	battle.player.permanent_damage_reduction = 1
	battle.player.heart_power = 2
	for resolution in [Vector2i(1280, 720), Vector2i(844, 390), Vector2i(640, 360)]:
		get_window().size = resolution
		await _frames(16)
		screen._refresh_all()
		await _frames()
		for row: StatusStrip in [screen._player_status, screen._enemy_widgets[0]._status]:
			for button in row._buttons:
				assert(row.get_global_rect().grow(1).encloses(button.get_global_rect()))
				assert(button.get_node("Glyph") is Label)
				if button != row.item_for("more"):
					assert(button.has_node("Stacks"))
			var more := row.item_for("more")
			if more != row:
				assert(more.get_node("Glyph").text == "+%d" % (row.entries.size() - row._buttons.size() + 1))
		RenderingServer.force_draw(false)
		assert(get_viewport().get_texture().get_image().save_png(QA + "battle-%dx%d.png" % [resolution.x, resolution.y]) == OK)
	Router.release_host(self)
	print("[capture_status_tiles] Player/enemy text tiles and overflow verified at three resolutions")
	get_tree().quit()
