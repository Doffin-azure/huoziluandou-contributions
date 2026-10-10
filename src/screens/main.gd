extends Control
## 启动入口：设置路由宿主，进入标题界面。

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Router.host = self
	Router.goto("res://src/screens/title_screen.gd")
