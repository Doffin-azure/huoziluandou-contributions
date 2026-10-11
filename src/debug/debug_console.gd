extends CanvasLayer
## 游戏内调试控制台（按 ` 即反引号呼出）。
## 仅在调试构建（编辑器运行 / Debug 导出）可用；Release 自动禁用。
## 命令注册见 src/debug/debug_commands.gd，新增命令 = 注册一行。

var enabled := true
var _root: Control
var _log_scroll: ScrollContainer
var _log_box: VBoxContainer
var _input_line: LineEdit
var _hist: Array = []
var _hist_idx := 0
var _open := false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = OS.is_debug_build()
	if enabled and DebugCommands.is_empty():
		DebugCommands.install()
	_build()
	_set_open(false)
	if enabled:
		print("[Debug] 调试控制台：按 ~ 或 F1 打开（/help 查看命令）")


func is_open() -> bool:
	return _open


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.keycode
		if kc == KEY_QUOTELEFT or kc == KEY_F1 or event.is_action_pressed("debug_console"):
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	_set_open(not _open)


func _set_open(v: bool) -> void:
	_open = v
	if _root == null:
		return
	_root.visible = v
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
	if v:
		_input_line.grab_focus()
	else:
		_input_line.release_focus()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.94)
	sb.set_corner_radius_all(0)
	sb.set_border_width_all(2)
	sb.border_color = Color("3ee0ff")
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -340
	panel.offset_bottom = 0
	_root.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var head := Label.new()
	head.text = "调试控制台　·　输入 /help 查看命令　·　` 关闭"
	head.add_theme_color_override("font_color", Color("3ee0ff"))
	head.add_theme_font_size_override("font_size", 14)
	col.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_log_scroll = scroll
	_log_box = VBoxContainer.new()
	_log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_theme_constant_override("separation", 0)
	scroll.add_child(_log_box)

	_input_line = LineEdit.new()
	_input_line.placeholder_text = "/help"
	_input_line.custom_minimum_size.y = 30
	_input_line.text_submitted.connect(_on_submit)
	_input_line.gui_input.connect(_on_input_event)
	col.add_child(_input_line)


func _on_input_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_UP:
		_history(-1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_DOWN:
		_history(1)


func _history(dir: int) -> void:
	if _hist.is_empty():
		return
	_hist_idx = clampi(_hist_idx + dir, 0, _hist.size() - 1)
	_input_line.text = _hist[_hist_idx]
	_input_line.caret_column = _input_line.text.length()


func _on_submit(text: String) -> void:
	text = text.strip_edges()
	_input_line.text = ""
	if text.is_empty():
		return
	_hist.append(text)
	_hist_idx = _hist.size()
	print_line("> " + text)
	for l in DebugCommands.execute(text):
		print_line(l)


func print_line(text: String) -> void:
	if _log_box == null:
		return
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 14)
	var col := Color("d7e6f2")
	if text.begins_with(">"):
		col = Color("3ee0ff")
	elif text.begins_with("  /"):
		col = Color("9fd6e8")
	l.add_theme_color_override("font_color", col)
	_log_box.add_child(l)
	while _log_box.get_child_count() > 200:
		var first := _log_box.get_child(0)
		_log_box.remove_child(first)
		first.queue_free()
	await get_tree().process_frame
	if _log_scroll != null:
		_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


func clear_log() -> void:
	if _log_box == null:
		return
	for c in _log_box.get_children():
		c.queue_free()
