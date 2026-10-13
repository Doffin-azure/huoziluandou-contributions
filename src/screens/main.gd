extends Control
## 启动入口：设置路由宿主，进入标题界面。

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var study := StudyStage.new()
	add_child(study)
	Router.study_stage = study
	Router.host = self
	Router.goto("res://src/screens/title_screen.gd")


func _exit_tree() -> void:
	Router.study_stage = null
