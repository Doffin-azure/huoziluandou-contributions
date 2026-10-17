extends Control
## Exercise the real title → map → battle entry, including legacy settings migration.
var _pass := 0
var _fail := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(value: bool, description: String) -> void:
	if value:
		_pass += 1
		print("PASS ", description)
	else:
		_fail += 1
		push_error(description)


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	var saved_style := Ink.style
	var saved_motion := Settings.reduced_motion
	var temporary := "user://battle_art_entry_%d.cfg" % Time.get_ticks_usec()
	var legacy := ConfigFile.new()
	legacy.set_value("visual", "style", "paper")
	legacy.save(temporary)
	var preferences: Node = load("res://src/autoload/settings.gd").new()
	preferences.storage_path = temporary
	add_child(preferences)
	_ok(preferences.visual_style == "taopunk", "legacy paper preference does not override the approved art default")
	Ink.apply_style(GameStyle.get_style(preferences.visual_style))
	legacy.set_value("visual", "art_style", "paper")
	legacy.save(temporary)
	preferences._ready()
	_ok(preferences.visual_style == "paper", "an explicit new art preference remains respected")
	preferences.queue_free()
	DirAccess.remove_absolute(temporary)
	Settings.reduced_motion = true
	var main: Control = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames()
	_ok(Router.current_path.ends_with("title_screen.gd"), "real main scene opens the courtyard title")
	Router.current._buttons[0].pressed.emit()
	var deadline := Time.get_ticks_msec() + 6000
	while not Router.current_path.ends_with("map_screen.gd") and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	_ok(Router.current_path.ends_with("map_screen.gd"), "title start reaches the real journey map")
	if Router.current_path.ends_with("map_screen.gd"):
		var map: Control = Router.current
		map._node_views[0].pressed.emit()
		await _frames(20)
		_ok(Router.current_path.ends_with("battle_screen.gd"), "map node opens the actual battle screen")
		if Router.current_path.ends_with("battle_screen.gd"):
			var battle: Control = Router.current
			_ok(battle.size.x >= 1280 and battle.size.y >= 720 and battle._board_view.size.x >= 300, "main scene anchors provide a full battle canvas and visible board")
			_ok(Palette.STYLE_ID == "taopunk" and Router.study_stage._illustrated_backdrop.visible and not Router.study_stage.shared_table_active(), "normal entry uses approved backdrop and disables the legacy table")
			_ok(battle._board_view._presentation.actors.size() == 16 and battle._enemy_widgets[0]._visual._actor != null, "normal entry connects the 3D board and illustrated guardian actor")
			if OS.get_cmdline_user_args().has("--capture"):
				RenderingServer.force_draw(false)
				get_viewport().get_texture().get_image().save_png("res://shots/integrated-normal-battle.png")
	main.queue_free()
	await _frames()
	Settings.reduced_motion = saved_motion
	Ink.apply_style(saved_style)
	print("[battle_art_entry_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail else 0)
