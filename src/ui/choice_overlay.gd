extends Control
class_name ChoiceOverlay
## 通用选择浮层：岔路、事件选项、商店确认都用它。
## cfg = { title, body, options: [{text, primary, disabled, hint}], on_choose: Callable(index) }

signal chose(index)

var cfg: Dictionary = {}
var _chosen := false
var _sheet: Control
var _panel: PanelContainer
var _padding: MarginContainer
var _peek_button: Button
var _peeking := false


func setup(p_cfg: Dictionary) -> void:
	cfg = p_cfg


func _ready() -> void:
	JourneyStyle.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	resized.connect(_layout)
	_layout.call_deferred()


func _build() -> void:
	var hud_scale := clampf(get_viewport_rect().size.y / maxf(1, DisplayServer.window_get_size().y), 1.0, 1.85)
	_sheet = Control.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sheet)
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.06, 0.05, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_sheet.add_child(dim)

	_panel = Ink.panel("PanelCard")
	_sheet.add_child(_panel)
	var sheet_scroll := ScrollContainer.new()
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(sheet_scroll)

	var pad := Ink.margin(24)
	_padding = pad
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_scroll.add_child(pad)
	var col := Ink.vbox(14)
	pad.add_child(col)
	col.minimum_size_changed.connect(_layout.call_deferred)

	if not str(cfg.get("title", "")).is_empty():
		var heading := Ink.h2(str(cfg["title"]))
		if cfg.get("hud_details", false):
			heading.add_theme_font_size_override("font_size", int(24 * hud_scale))
			heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(heading)
	if not str(cfg.get("body", "")).is_empty():
		var b := Ink.body(str(cfg["body"]))
		b.custom_minimum_size.x = 380
		if cfg.get("hud_details", false):
			b.add_theme_font_size_override("font_size", int(18 * hud_scale))
		if cfg.get("scroll_body", false):
			var scroll := ScrollContainer.new()
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.custom_minimum_size = Vector2(380, minf(320, get_viewport_rect().size.y * 0.4))
			col.add_child(scroll)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			scroll.add_child(b)
		else:
			col.add_child(b)
	col.add_child(Ink.hline())

	var options: Array = cfg.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		var btn := Ink.button(str(opt.get("text", "选项 %d" % (i + 1))), bool(opt.get("primary", false)))
		btn.focus_mode = Control.FOCUS_ALL
		btn.custom_minimum_size.y = 48 * hud_scale
		btn.add_theme_font_size_override("font_size", int(20 * hud_scale))
		if opt.has("disabled"):
			btn.disabled = bool(opt["disabled"])
		btn.pressed.connect(_on_choose.bind(i))
		col.add_child(btn)
		if not str(opt.get("hint", "")).is_empty():
			var h := Ink.label(str(opt["hint"]), "Muted")
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(h)
	if cfg.get("board_peek", false):
		_peek_button = JourneyStyle.button("查看棋盘", _toggle_peek)
		add_child(_peek_button)


func _layout() -> void:
	if _panel == null or size.y < 1: return
	var scale := JourneyStyle.touch_scale(self)
	var top := 16.0 * scale
	if _peek_button != null:
		_peek_button.size = Vector2(200, 48) * scale
		_peek_button.position = Vector2(size.x - _peek_button.size.x - 16 * scale, top)
		top += _peek_button.size.y + 8 * scale
	var skin := _panel.get_theme_stylebox("panel")
	_panel.size = Vector2(minf(520 * scale, size.x - 32 * scale), minf(_padding.get_combined_minimum_size().y + skin.get_minimum_size().y, size.y - top - 16 * scale))
	_panel.position = Vector2((size.x - _panel.size.x) * 0.5, top + (size.y - top - 16 * scale - _panel.size.y) * 0.5)


func _toggle_peek() -> void:
	_peeking = not _peeking
	_sheet.visible = not _peeking
	_peek_button.text = "返回选择" if _peeking else "查看棋盘"
	_peek_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _peeking and event.is_action_pressed("cancel_selection"):
		_toggle_peek()
		get_viewport().set_input_as_handled()


func _on_choose(index: int) -> void:
	var options: Array = cfg.get("options", [])
	if _chosen or index < 0 or index >= options.size() or bool(options[index].get("disabled", false)):
		return
	_chosen = true
	chose.emit(index)
	var cb = cfg.get("on_choose", null)
	if cb is Callable and cb.is_valid():
		cb.call(index)
	# 立即从场景树摘除，让父级（如战斗页的 _modal_count）在本次点击内即可恢复盘面交互。
	if is_inside_tree():
		get_parent().remove_child(self)
	queue_free()
