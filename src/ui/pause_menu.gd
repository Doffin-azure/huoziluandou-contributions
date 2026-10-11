extends Node
## 全局暂停菜单：ESC（ui_cancel）在“没有别的操作吃掉 ESC”时呼出。
## 战斗内若正在连线/选目标，会先由 BoardView/浮层处理，不会误弹菜单。

var _instance: PauseOverlay = null


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _instance != null and is_instance_valid(_instance):
		return
	if Debug != null and Debug.has_method("is_open") and Debug.is_open():
		return
	var cur = Router.current
	if cur == null:
		return
	if Router.current_path.contains("title_screen"):
		return
	open()


func open() -> void:
	if _instance != null and is_instance_valid(_instance):
		return
	_instance = PauseOverlay.new()
	_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	var host = Router.current
	if host == null:
		host = get_tree().root
	host.add_child(_instance)
	get_viewport().set_input_as_handled()
