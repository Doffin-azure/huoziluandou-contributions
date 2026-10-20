extends Control
class_name ChoiceOverlay
## 通用选择浮层：岔路、事件选项、商店确认都用它。
## cfg = { title, body, options: [{text, primary, disabled, hint}], on_choose: Callable(index) }
## scroll_options 限高滚动候选；cancel_index 指定固定在滚动区外的取消选项。

signal chose(index)

var cfg: Dictionary = {}
var _chosen := false
var _options_scroll: ScrollContainer
var _options_content: VBoxContainer
var _panel: PanelContainer


func setup(p_cfg: Dictionary) -> void:
	cfg = p_cfg


func _ready() -> void:
	JourneyStyle.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var hud_scale := clampf(get_viewport_rect().size.y / maxf(1, DisplayServer.window_get_size().y), 1.0, 1.85)
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.06, 0.05, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Ink.panel("PanelCard")
	_panel = panel
	panel.custom_minimum_size = Vector2(minf(520 * hud_scale, get_viewport_rect().size.x - 48), 0)
	center.add_child(panel)

	var pad := Ink.margin(24)
	panel.add_child(pad)
	var col := Ink.vbox(14)
	pad.add_child(col)

	if not str(cfg.get("title", "")).is_empty():
		var heading := Ink.h2(BattleText.clean(str(cfg["title"])))
		if cfg.get("hud_details", false):
			heading.add_theme_font_size_override("font_size", int(24 * hud_scale))
			heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(heading)
	if not str(cfg.get("body", "")).is_empty():
		var b: Control
		if cfg.get("hud_details", false):
			var effects := EffectText.new()
			effects.name = "EffectDetails"
			effects.set_effect_text(str(cfg["body"]))
			effects.add_theme_font_size_override("normal_font_size", int(18 * hud_scale))
			b = effects
		else:
			b = Ink.body(BattleText.clean(str(cfg["body"])))
		b.custom_minimum_size.x = 380
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
	var scroll_options := bool(cfg.get("scroll_options", false))
	var cancel_index := int(cfg.get("cancel_index", -1))
	var option_parent: VBoxContainer = col
	if scroll_options:
		z_index = 80
		_options_scroll = ScrollContainer.new()
		_options_scroll.name = "OptionsScroll"
		_options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_options_scroll.follow_focus = true
		_options_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(_options_scroll)
		_options_content = Ink.vbox(10)
		_options_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_options_scroll.add_child(_options_content)
		option_parent = _options_content
	for i in options.size():
		if scroll_options and i == cancel_index: continue
		_add_option(option_parent, i, hud_scale)
	if scroll_options and cancel_index >= 0 and cancel_index < options.size():
		col.add_child(Ink.hline())
		_add_option(col, cancel_index, hud_scale)
	if scroll_options:
		resized.connect(_fit_scroll_options)
		_fit_scroll_options.call_deferred()


func _add_option(parent: VBoxContainer, index: int, hud_scale: float) -> void:
	var opt: Dictionary = cfg.options[index]
	var btn := Ink.button(BattleText.clean(str(opt.get("text", "选项 %d" % (index + 1)))), bool(opt.get("primary", false)))
	btn.name = "Option_%d" % index
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size.y = 48 * hud_scale
	btn.add_theme_font_size_override("font_size", int(20 * hud_scale))
	btn.disabled = bool(opt.get("disabled", false))
	btn.pressed.connect(_on_choose.bind(index))
	parent.add_child(btn)
	if not str(opt.get("hint", "")).is_empty():
		var hint := Ink.label(BattleText.clean(str(opt.hint)), "Muted")
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		parent.add_child(hint)


func _fit_scroll_options() -> void:
	if _options_scroll == null or not is_inside_tree(): return
	# 标题、说明与取消固定在列表外；只有候选区按剩余高度滚动。
	var fixed_height := _panel.get_combined_minimum_size().y - _options_scroll.custom_minimum_size.y
	var available := maxf(48, get_viewport_rect().size.y - 48 - fixed_height)
	_options_scroll.custom_minimum_size.y = minf(_options_content.get_combined_minimum_size().y, available)


func _unhandled_key_input(event: InputEvent) -> void:
	if not cfg.get("scroll_options", false): return
	var cancel_index := int(cfg.get("cancel_index", -1))
	if event.is_action_pressed("ui_cancel") and cancel_index >= 0:
		accept_event()
		_on_choose(cancel_index)


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
