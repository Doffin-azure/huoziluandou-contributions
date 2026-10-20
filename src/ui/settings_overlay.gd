extends Control
class_name SettingsOverlay
## 设置浮层（标题页与战斗内共用；浮层不影响任何界面状态）。

signal closed

var _style_row: VBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	JourneyStyle.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if _panel != null:
		_panel.custom_minimum_size = Vector2(minf(600, size.x - 32), minf(580, size.y - 32))


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
	_panel = panel
	center.add_child(panel)
	var shell := Ink.vbox(12)
	panel.add_child(shell)
	var header := Ink.hbox(16)
	header.add_child(Ink.h2("设置"))
	header.add_child(Ink.expander())
	var close := JourneyStyle.button("关闭", func(): closed.emit(); queue_free())
	close.custom_minimum_size.y = 48 * JourneyStyle.touch_scale(self)
	header.add_child(close)
	shell.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	var pad := Ink.margin(24)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	var col := Ink.vbox(14)
	pad.add_child(col)

	col.add_child(Ink.hline())

	# 音量优先显示，窄屏也能直接访问。
	col.add_child(Ink.label("音量", "Subheading"))
	_add_volume_control(col, "BGMVolume", "背景音乐（BGM）", Settings.music_volume, Settings.set_music_volume)
	_add_volume_control(col, "SFXVolume", "音效", Settings.sfx_volume, Settings.set_sfx_volume)
	col.add_child(Ink.caption("分别调节，实时生效并自动保存；调至 0% 静音。"))
	col.add_child(Ink.hline())

	# ---- 战斗字盘 ----
	col.add_child(Ink.label("战斗字盘", "Subheading"))
	col.add_child(Ink.caption("切换战斗字盘的显示风格，下场战斗生效。行旅界面保持墨青与朱砂配色。"))
	_style_row = Ink.vbox(8)
	col.add_child(_style_row)
	_build_style_buttons()
	col.add_child(BoardFontPicker.new())

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
	toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	toggle.custom_minimum_size = Vector2(96, 48 * JourneyStyle.touch_scale(self))
	toggle.pressed.connect(_on_toggle.bind(toggle))
	row.add_child(toggle)

	col.add_child(Ink.hline())
	col.add_child(Ink.label("再次点击选中字可撤销；「清除」或 ESC 可清空选择。", "Muted"))
	var motion_row := Ink.hbox(12)
	motion_row.add_child(Ink.label("减少动效", "Subheading"))
	motion_row.add_child(Ink.expander())
	var motion := Ink.button("开" if Settings.reduced_motion else "关")
	motion.custom_minimum_size = Vector2(96, 48 * JourneyStyle.touch_scale(self))
	motion.pressed.connect(func():
		Settings.set_reduced_motion(not Settings.reduced_motion)
		motion.text = "开" if Settings.reduced_motion else "关")
	motion_row.add_child(motion)
	col.add_child(motion_row)


func _add_volume_control(parent: Control, control_name: String, title: String, initial: float, setter: Callable) -> void:
	var group := Ink.vbox(0)
	group.name = control_name
	parent.add_child(group)
	var row := Ink.hbox(12)
	group.add_child(row)
	row.add_child(Ink.label(title, "Subheading"))
	row.add_child(Ink.expander())
	var percent := Ink.label("%d%%" % roundi(initial * 100), "Subheading")
	percent.name = "Percent"
	row.add_child(percent)
	var slider := HSlider.new()
	slider.name = "Slider"
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = initial * 100
	slider.custom_minimum_size = Vector2(0, 48 * JourneyStyle.touch_scale(self))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.accessibility_name = title
	slider.value_changed.connect(func(value: float):
		setter.call(value / 100.0)
		percent.text = "%d%%" % roundi(value))
	group.add_child(slider)


func _build_style_buttons() -> void:
	for c in _style_row.get_children():
		c.queue_free()
	var options := [["taopunk", "青铜绘卷"], ["paper", "宣纸活字"], ["neon", "墨芯 · 大模型"]]
	for opt in options:
		var active: bool = Settings.visual_style == opt[0]
		var b := Ink.button(opt[1] + ("　✓" if active else ""), active)
		b.custom_minimum_size = Vector2(180, 48 * JourneyStyle.touch_scale(self))
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
	if Router.current_path.ends_with("/battle_screen.gd"):
		Ink.pending_style = style_id
	else:
		Ink.apply_style(GameStyle.get_style(style_id))
		Ink.pending_style = ""
	# Journey pages own their theme. Rebuilding them would reroll rewards and shops.
	_build_style_buttons()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
