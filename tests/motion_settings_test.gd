extends Control
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func fresh(path: String) -> Node:
	var settings = load("res://src/autoload/settings.gd").new()
	settings.storage_path = path
	add_child(settings)
	return settings

func _ready() -> void:
	Settings.storage_path = "user://motion_settings_test-settings.cfg"
	var path := "user://motion-default-%d.cfg" % Time.get_ticks_usec()
	var local := fresh(path)
	check(not local.reduced_motion, "fresh settings default to full animation")
	local.set_sfx_volume(0.3)
	local.free()
	local = fresh(path)
	check(not local.reduced_motion, "saving audio does not enable reduced motion")
	local.set_reduced_motion(true)
	local.free()
	local = fresh(path)
	check(local.reduced_motion, "explicit reduced motion opt-in persists")
	local.set_reduced_motion(false)
	local.free()
	local = fresh(path)
	check(not local.reduced_motion, "explicit full animation choice persists")
	local.free()
	var cfg := ConfigFile.new()
	cfg.set_value("visual", "art_style", "paper")
	cfg.save(path)
	local = fresh(path)
	check(not local.reduced_motion, "legacy config without motion key defaults off")
	local.free()
	Settings.reduced_motion = false
	var overlay := SettingsOverlay.new()
	add_child(overlay)
	await get_tree().process_frame
	var motion: Button
	for label in overlay.find_children("*", "Label", true, false):
		if label.text == "减少动效":
			for child in label.get_parent().get_children():
				if child is Button: motion = child
	check(motion != null and motion.text == "关", "settings overlay displays reduced motion off")
	if motion != null:
		motion.pressed.emit()
		check(Settings.reduced_motion and motion.text == "开", "button enables reduced motion explicitly")
		motion.pressed.emit()
		check(not Settings.reduced_motion and motion.text == "关", "button restores full animation")
	DirAccess.remove_absolute(path)
	print("[motion_settings_test] PASS=%d FAIL=%d" % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)
