extends Node
## Retain the expensive title and active route map, with separate save owners.
signal route_changed(screen_path: String)
const TITLE_SCREEN := "res://src/screens/title_screen.gd"
const MAP := "res://src/screens/room_map_screen.gd"
var host: Control
var current: Control
var current_path := ""
var study_stage: StudyStage
var _title_screen: Control
var _courtyard: Control
var _courtyard_act := 0


func goto(screen_path: String, params: Dictionary = {}) -> void:
	if not is_instance_valid(host):
		push_error("[Router] host 未设置")
		return
	if screen_path == TITLE_SCREEN: SaveManager.checkpoint()
	var excursion := screen_path.get_file() in ["battle_screen.gd", "reward_screen.gd", "event_screen.gd", "event_board_screen.gd", "shop_screen.gd", "rest_screen.gd"]
	if is_instance_valid(_courtyard) and current == _courtyard and _courtyard.run == GameState.room_run and _courtyard.loaded_act == GameState.act_index:
		_courtyard_act = GameState.act_index
	if is_instance_valid(_courtyard) and (_courtyard.run != GameState.room_run or _courtyard_act != GameState.act_index or (screen_path != MAP and not excursion)):
		if current == _courtyard: current = null
		_courtyard.queue_free()
		_courtyard = null
	var screen: Control
	var cached_map := screen_path == MAP and is_instance_valid(_courtyard)
	if cached_map:
		screen = _courtyard
	elif screen_path == TITLE_SCREEN and is_instance_valid(_title_screen) and not _title_screen.is_queued_for_deletion() and _title_screen.get_parent() == host:
		screen = _title_screen
	else:
		var script: GDScript = load(screen_path)
		if script == null:
			push_error("[Router] 找不到屏幕脚本: %s" % screen_path)
			return
		screen = script.new()
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(current) and current != screen:
		if current == _title_screen:
			_title_active(false)
		elif current_path == MAP and excursion and bool(params.get("room_run", false)):
			_courtyard = current
			_courtyard_act = GameState.act_index
			_courtyard.suspend_session()
		else:
			current.hide()
			current.process_mode = Node.PROCESS_MODE_DISABLED
			current.queue_free()
	if is_instance_valid(study_stage): study_stage.set_screen(screen_path)
	if cached_map:
		screen.resume_session()
	else:
		if screen.has_method("setup"): screen.call("setup", params)
		if screen.get_parent() == null: host.add_child(screen)
	current = screen
	current_path = screen_path
	if screen_path == TITLE_SCREEN:
		_title_screen = screen
		_title_active(true)
	Music.for_screen(screen_path)
	route_changed.emit(screen_path)
	SaveManager.request_save()


func _title_active(active: bool) -> void:
	if not is_instance_valid(_title_screen): return
	if _title_screen.has_method("set_route_active"):
		_title_screen.set_route_active(active)
	else:
		_title_screen.visible = active
		_title_screen.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func courtyard_cache_size() -> int:
	return 1 if is_instance_valid(_courtyard) else 0


func release_host(owner: Control) -> void:
	if host != owner: return
	host = null
	current = null
	current_path = ""
	study_stage = null
	_title_screen = null
	_courtyard = null
