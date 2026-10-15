extends Control
class_name ChoiceOverlay
## 通用选择浮层：岔路、事件选项、商店确认都用它。
## cfg = { title, body, options: [{text, primary, disabled, hint}], on_choose: Callable(index) }

signal chose(index)

var cfg: Dictionary = {}
var _chosen := false


func setup(p_cfg: Dictionary) -> void:
	cfg = p_cfg


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var hud_scale := clampf(get_viewport_rect().size.y / maxf(1, DisplayServer.window_get_size().y), 1.0, 1.85) if cfg.get("hud_details", false) else 1.0
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.06, 0.05, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Ink.panel("PanelCard")
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var pad := Ink.margin(24)
	panel.add_child(pad)
	var col := Ink.vbox(14)
	pad.add_child(col)

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
		if cfg.get("hud_details", false):
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
