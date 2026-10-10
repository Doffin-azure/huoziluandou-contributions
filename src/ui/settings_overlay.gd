extends Control
class_name SettingsOverlay
## 设置浮层（标题页与战斗内共用；浮层不影响任何界面状态）。

signal closed

var _cfg: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.06, 0.05, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Ink.panel("PanelCard")
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var pad := Ink.margin(24)
	panel.add_child(pad)
	var col := Ink.vbox(14)
	pad.add_child(col)

	col.add_child(Ink.h2("设置"))
	col.add_child(Ink.hline())

	# ---- 手感：拖拽松手是否立即出字 ----
	var row := Ink.hbox(12)
	col.add_child(row)
	var left := Ink.vbox(2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(Ink.label("拖拽松手立即出字", "Subheading"))
	left.add_child(Ink.caption("开启：拖动连词后松手立刻结算（节奏快）。\n关闭：松手只保留选择，按「出字」或回车 / 空格确认（节奏从容）。"))
	row.add_child(left)
	var toggle := Ink.button(_toggle_text())
	toggle.custom_minimum_size = Vector2(96, 44)
	toggle.pressed.connect(_on_toggle.bind(toggle))
	row.add_child(toggle)

	col.add_child(Ink.hline())
	col.add_child(Ink.label("选择确认后可用「清除」或 ESC 取消。", "Muted"))

	var close := Ink.button("关闭", true)
	close.pressed.connect(func():
		closed.emit()
		queue_free())
	col.add_child(close)


func _toggle_text() -> String:
	return "开" if Settings.drag_release_play else "关"


func _on_toggle(btn: Button) -> void:
	Settings.set_drag_release_play(not Settings.drag_release_play)
	btn.text = _toggle_text()
