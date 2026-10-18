extends Node
## 屏幕路由：所有界面都是“脚本即场景”，由 Router 挂到 Main 的内容容器里。

var host: Control = null
var current: Control = null
var current_path: String = ""
var study_stage: StudyStage


func goto(screen_path: String, params: Dictionary = {}) -> void:
	if host == null:
		push_error("[Router] host 未设置，Main 还没准备好")
		return
	if current != null and is_instance_valid(current):
		current.queue_free()
	Ink.apply_pending_style()
	var script: GDScript = load(screen_path)
	if script == null:
		push_error("[Router] 找不到屏幕脚本: %s" % screen_path)
		return
	var screen: Control = script.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	if screen.has_method("setup"):
		screen.call("setup", params)
	if is_instance_valid(study_stage):
		study_stage.set_screen(screen_path)
	host.add_child(screen)
	current = screen
	current_path = screen_path
	Music.for_screen(screen_path)
