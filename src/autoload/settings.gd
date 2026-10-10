extends Node
## 玩家设置（持久化到 user://settings.cfg）。
## 目前只有一个手感选项；以后新增选项照抄模式即可。

signal changed

const PATH := "user://settings.cfg"

## 拖拽连线后“松手立即出字”。
##   false（默认）：松手只保留选择，需要按【出字】或回车/空格确认 —— 节奏更从容。
##   true：松手即结算（旧的手感，节奏更快）。
var drag_release_play: bool = false

var _cfg := ConfigFile.new()


func _ready() -> void:
	if _cfg.load(PATH) == OK:
		drag_release_play = bool(_cfg.get_value("input", "drag_release_play", drag_release_play))


func set_drag_release_play(value: bool) -> void:
	if drag_release_play == value:
		return
	drag_release_play = value
	_save()
	changed.emit()


func _save() -> void:
	_cfg.set_value("input", "drag_release_play", drag_release_play)
	_cfg.save(PATH)
