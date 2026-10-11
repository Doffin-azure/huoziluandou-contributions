extends Control
class_name PauseOverlay
## 暂停 / 中途退出菜单。ESC 或「菜单」按钮呼出。

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := Ink.panel("PanelCard")
	panel.custom_minimum_size = Vector2(340, 0)
	center.add_child(panel)
	var pad := Ink.margin(22)
	panel.add_child(pad)
	var col := Ink.vbox(10)
	pad.add_child(col)

	col.add_child(Ink.h2("菜单"))
	col.add_child(Ink.hline())

	var resume := Ink.button("继续", true)
	resume.pressed.connect(_close)
	col.add_child(resume)

	var settings := Ink.button("设置")
	settings.pressed.connect(func():
		var ov := SettingsOverlay.new()
		ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(ov))
	col.add_child(settings)

	var abandon := Ink.button("放弃本局（返回标题）")
	abandon.pressed.connect(func():
		Router.goto("res://src/screens/title_screen.gd"))
	col.add_child(abandon)

	var quit := Ink.button("退出游戏")
	quit.theme_type_variation = "DangerButton"
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(quit)


func _close() -> void:
	queue_free()
