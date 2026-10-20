extends Control
func _ready() -> void:
	Achievements.test_enabled = true
	Achievements.autosave = false
	Achievements.profile = {"version":1,"unlocked":{},"lifetime":{},"best":{},"sessions":{}}
	GameState.start_new_run("v03")
	Achievements.start_run("capture")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 30: await get_tree().process_frame
	var title = Router.current
	title._on_achievements()
	Achievements.commit("fixture", [{"metric":"word_plays","amount":108},{"metric":"unique_words","value":"击破"}])
	for i in 20: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/private/tmp/achievement-overview.png")
	var overlay = title.get_children().filter(func(c): return c is AchievementOverlay)[0]
	overlay._close()
	var toast := preload("res://src/ui/achievement_toast.gd").new()
	add_child(toast)
	toast.enqueue("words_100")
	for i in 12: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("/private/tmp/achievement-toast.png")
	Achievements.suspend_run()
	get_tree().quit()
