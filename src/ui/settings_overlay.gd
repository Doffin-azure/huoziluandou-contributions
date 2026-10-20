extends Control
class_name SettingsOverlay
## 设置浮层（标题页与战斗内共用；浮层不影响任何界面状态）。

signal closed

var _panel: PanelContainer


func _ready() -> void:
	JourneyStyle.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if _panel != null:
		_panel.custom_minimum_size = Vector2(minf(680 * JourneyStyle.touch_scale(self), size.x - 32), minf(580, size.y - 32))


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

	# 字盘字体独立于美术风格，只选择随包发布的内置样式。
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
	var audio_row := Ink.hbox(12)
	audio_row.add_child(Ink.label("音效音量", "Subheading"))
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = Settings.sfx_volume * 100
	volume.custom_minimum_size = Vector2(160, 48)
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.value_changed.connect(func(value: float): Settings.set_sfx_volume(value / 100.0))
	audio_row.add_child(volume)
	col.add_child(audio_row)
	var music_row := Ink.hbox(12)
	music_row.add_child(Ink.label("音乐音量", "Subheading"))
	var music_volume := HSlider.new()
	music_volume.min_value = 0
	music_volume.max_value = 100
	music_volume.step = 1
	music_volume.value = Settings.music_volume * 100
	music_volume.custom_minimum_size = Vector2(160, 48)
	music_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_volume.value_changed.connect(func(value: float): Settings.set_music_volume(value / 100.0))
	music_row.add_child(music_volume)
	col.add_child(music_row)

	_wrap_labels(col)


func _wrap_labels(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wrap_labels(child)


func _toggle_text() -> String:
	return "开" if Settings.drag_release_play else "关"


func _on_toggle(btn: Button) -> void:
	Settings.set_drag_release_play(not Settings.drag_release_play)
	btn.text = _toggle_text()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection"):
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
