extends Node
## 屏幕路由：所有界面都是“脚本即场景”，由 Router 挂到 Main 的内容容器里。

var host: Control = null
var current: Control = null
var current_path: String = ""
var study_stage: StudyStage
var _courtyard: Control
var _courtyard_act := 0


func goto(screen_path: String, params: Dictionary = {}) -> void:
	if host == null:
		push_error("[Router] host 未设置，Main 还没准备好")
		return
	const MAP := "res://src/screens/room_map_screen.gd"
	var excursion := screen_path.get_file() in ["battle_screen.gd","reward_screen.gd","event_screen.gd","event_board_screen.gd","shop_screen.gd","rest_screen.gd"]
	# The active map can rebuild itself for a new act without a Router.goto().
	# Refresh the cache key before the next battle, so that battle's reward does
	# not discard the already-built new-act world as if it were the old one.
	if is_instance_valid(_courtyard) and current==_courtyard and _courtyard.run==GameState.room_run and _courtyard.loaded_act==GameState.act_index:
		_courtyard_act = GameState.act_index
	if is_instance_valid(_courtyard) and (_courtyard.run!=GameState.room_run or _courtyard_act!=GameState.act_index or (screen_path!=MAP and not excursion)):
		if current==_courtyard: current = null
		_courtyard.queue_free(); _courtyard = null
	if current != null and is_instance_valid(current):
		if current_path==MAP and excursion and bool(params.get("room_run",false)):
			_courtyard = current; _courtyard_act = GameState.act_index
			_courtyard.suspend_session()
		elif current!=_courtyard: current.queue_free()
	if is_instance_valid(study_stage):
		study_stage.set_screen(screen_path)
	if screen_path==MAP and is_instance_valid(_courtyard):
		current = _courtyard; current_path = MAP
		_courtyard.resume_session()
		Music.for_screen(screen_path)
		return
	var script: GDScript = load(screen_path)
	if script == null:
		push_error("[Router] 找不到屏幕脚本: %s" % screen_path)
		return
	var screen: Control = script.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	if screen.has_method("setup"):
		screen.call("setup", params)
	host.add_child(screen)
	current = screen
	current_path = screen_path
	Music.for_screen(screen_path)


func courtyard_cache_size() -> int:
	return 1 if is_instance_valid(_courtyard) else 0
