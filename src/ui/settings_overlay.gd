extends Control
class_name SettingsOverlay
## 设置浮层（标题页与战斗内共用；浮层不影响任何界面状态）。

signal closed

var _style_row: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Ink.panel("PanelCard")
	panel.custom_minimum_size = Vector2(600, 0)
	center.add_child(panel)
	var pad := Ink.margin(24)
	panel.add_child(pad)
	var col := Ink.vbox(14)
	pad.add_child(col)

	col.add_child(Ink.h2("设置"))
	col.add_child(Ink.hline())

	# ---- 视觉风格 ----
	col.add_child(Ink.label("视觉风格", "Subheading"))
	col.add_child(Ink.caption("切换整套界面风格：宣纸活字（传统）↔ 墨芯（大模型 / 科技）。战斗内切换下一场生效。"))
	_style_row = Ink.hbox(10)
	col.add_child(_style_row)
	_build_style_buttons()

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
	col.add_child(Ink.label("再次点击选中字可撤销；「清除」或 ESC 可清空选择。", "Muted"))
	var motion_row := Ink.hbox(12)
	motion_row.add_child(Ink.label("减少动效", "Subheading"))
	motion_row.add_child(Ink.expander())
	var motion := Ink.button("开" if Settings.reduced_motion else "关")
	motion.custom_minimum_size = Vector2(96, 48)
	motion.pressed.connect(func():
		Settings.set_reduced_motion(not Settings.reduced_motion)
		motion.text = "开" if Settings.reduced_motion else "关")
	motion_row.add_child(motion)
	col.add_child(motion_row)

	var close := Ink.button("关闭", true)
	close.pressed.connect(func():
		closed.emit()
		queue_free())
	col.add_child(close)


func _build_style_buttons() -> void:
	for c in _style_row.get_children():
		c.queue_free()
	var options := [["paper", "宣纸活字"], ["neon", "墨芯 · 大模型"]]
	for opt in options:
		var active: bool = Palette.STYLE_ID == opt[0]
		var b := Ink.button(opt[1] + ("　✓" if active else ""), active)
		b.custom_minimum_size = Vector2(180, 44)
		b.disabled = active
		b.pressed.connect(_set_style.bind(opt[0]))
		_style_row.add_child(b)


func _toggle_text() -> String:
	return "开" if Settings.drag_release_play else "关"


func _on_toggle(btn: Button) -> void:
	Settings.set_drag_release_play(not Settings.drag_release_play)
	btn.text = _toggle_text()


func _set_style(style_id: String) -> void:
	Settings.set_visual_style(style_id)
	Ink.apply_style(GameStyle.get_style(style_id))
	# 重建当前界面以套用新配色（战斗界面保持不重建，避免丢失战斗状态）
	var path := Router.current_path
	if not path.is_empty() and not path.contains("battle_screen"):
		Router.goto(path)
	else:
		_build_style_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
