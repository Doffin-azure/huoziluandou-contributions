extends Control

var passed := 0
var failed := 0
var _settings_completed := false


func _ready() -> void:
	Settings.storage_path = "user://first_run_tutorial_test-settings.cfg"
	_run.call_deferred()


func _check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error(label)


func _frames(count := 4) -> void:
	for i in count:
		await get_tree().process_frame


func _run() -> void:
	_settings_completed = Settings.first_run_tutorial_completed
	Settings.reduced_motion = true
	SaveManager.enabled = false
	add_child(preload("res://scenes/main.tscn").instantiate())
	await _frames(8)
	GameState.start_new_run()
	GameState.first_run_tutorial = true
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 4361, "first_run_tutorial": true})
	await _frames(8)
	var screen: Control = Router.current
	_check(screen._first_run_tutorial and screen._tutorial_step == 0, "first adventure battle enables inline tutorial")
	_check(screen._bubble._effect_text.contains("第一局引导"), "first battle instruction uses combat hint bubble")
	screen._tutorial_step = 1
	var checkpoint: Dictionary = screen.save_checkpoint()
	_check(checkpoint.screen.get("first_run_tutorial", false) and checkpoint.screen.get("tutorial_step", -1) == 1, "tutorial stage is included in battle checkpoint")
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 4361, "_saved_screen": checkpoint.screen})
	await _frames(8)
	screen = Router.current
	_check(screen._first_run_tutorial and screen._tutorial_step == 1, "resuming battle restores the active tutorial step")
	var pause := PauseOverlay.new()
	add_child(pause)
	await _frames(2)
	var has_skip := false
	for button in pause._buttons:
		if button.text == "跳过新手引导":
			has_skip = true
	pause.queue_free()
	_check(has_skip, "pause menu exposes skip while first-run tutorial is active")
	await screen._on_end_turn()
	_check(not screen._first_run_tutorial and not GameState.first_run_tutorial, "ending first real turn completes inline tutorial")
	_check(Settings.first_run_tutorial_completed, "completion is remembered for future adventures")
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 4362, "first_run_tutorial": true})
	await _frames(8)
	screen = Router.current
	screen.skip_first_run_tutorial()
	_check(not screen._first_run_tutorial and not GameState.first_run_tutorial, "skip action closes tutorial state")
	_check(not screen.save_checkpoint().screen.get("first_run_tutorial", true), "skip state is saved with battle")
	Settings.first_run_tutorial_completed = _settings_completed
	Settings._save()
	SaveManager.enabled = false
	print("First run tutorial: %d passed / %d failed" % [passed, failed])
	get_tree().quit(1 if failed else 0)
