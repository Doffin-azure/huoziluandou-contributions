extends Control
class_name ChoiceOverlay
## 通用选择浮层：岔路、事件选项、商店确认都用它。
## cfg = { title, body, options: [{text, primary, disabled, hint}], on_choose: Callable(index) }

signal chose(index)

var cfg: Dictionary = {}


func setup(p_cfg: Dictionary) -> void:
	cfg = p_cfg


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
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)

	var pad := Ink.margin(24)
	panel.add_child(pad)
	var col := Ink.vbox(14)
	pad.add_child(col)

	if not str(cfg.get("title", "")).is_empty():
		col.add_child(Ink.h2(str(cfg["title"])))
	if not str(cfg.get("body", "")).is_empty():
		var b := Ink.body(str(cfg["body"]))
		b.custom_minimum_size.x = 380
		col.add_child(b)
	col.add_child(Ink.hline())

	var options: Array = cfg.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		var btn := Ink.button(str(opt.get("text", "选项 %d" % (i + 1))), bool(opt.get("primary", false)))
		if opt.has("disabled"):
			btn.disabled = bool(opt["disabled"])
		btn.pressed.connect(_on_choose.bind(i))
		col.add_child(btn)
		if not str(opt.get("hint", "")).is_empty():
			var h := Ink.label(str(opt["hint"]), "Muted")
			h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(h)


func _on_choose(index: int) -> void:
	chose.emit(index)
	var cb = cfg.get("on_choose", null)
	if cb is Callable and cb.is_valid():
		cb.call(index)
	queue_free()
