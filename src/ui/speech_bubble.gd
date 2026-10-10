extends Control
class_name SpeechBubble
## 鲸鱼气泡框：显示“选中词语预览”与“本次出字结果”。
## 结果卡与预览都走这里，不再单独出右侧结果面板。

enum State { IDLE, PREVIEW, RESULT, ERROR }

var title: Label
var body: Label
var _state: int = State.IDLE
var _tail_h := 20.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 170)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := Ink.margin(0)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", int(_tail_h) + 10)
	add_child(pad)
	var col := Ink.vbox(4)
	pad.add_child(col)
	title = Ink.label("", "Subheading")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	body = Ink.label("", "Muted")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)


func _draw() -> void:
	var bw := size.x
	var bh := size.y - _tail_h
	var sb := StyleBoxFlat.new()
	sb.bg_color = _bg()
	sb.set_corner_radius_all(18 + Palette.CORNER_BONUS)
	sb.set_border_width_all(2)
	sb.border_color = _border()
	if Palette.GLOW:
		sb.shadow_color = Color(_border().r, _border().g, _border().b, 0.25)
		sb.shadow_size = 8
	draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(bw, bh)))
	# 指向左侧吉祥物的小尾巴
	var pts := PackedVector2Array([
		Vector2(26, bh - 1),
		Vector2(74, bh - 1),
		Vector2(26, size.y - 1),
	])
	draw_colored_polygon(pts, _bg())
	draw_line(pts[0], pts[2], _border(), 2.0)
	draw_line(pts[2], pts[1], _border(), 2.0)


func _bg() -> Color:
	var c := Palette.PAPER
	return Color(c.r, c.g, c.b, 0.94)


func _border() -> Color:
	match _state:
		State.ERROR: return Palette.VERMILION
		State.RESULT: return Palette.GOLD
		State.PREVIEW: return Palette.VERMILION
		_: return Palette.BORDER_SOFT


func set_state(s: int) -> void:
	if _state == s:
		return
	_state = s
	queue_redraw()


func set_text(t: String, b: String, s: int = State.PREVIEW) -> void:
	if title == null or body == null:
		return
	title.text = t
	body.text = b
	set_state(s)


func set_result(word: WordData, glyphs: Array, messages: Array) -> void:
	var w := ""
	for g in glyphs:
		w += str(g)
	var head := "《%s》" % (word.word if word != null else w)
	var lines: Array = []
	if word != null and not word.effect_summary.is_empty():
		lines.append(word.effect_summary)
	for m in messages:
		lines.append("· " + str(m))
	if lines.is_empty():
		lines.append("（没有效果，仅消耗）")
	set_text(head, "\n".join(lines), State.RESULT)


func set_error(reason: String) -> void:
	set_text("嗯……", reason, State.ERROR)


func set_idle(hint: String) -> void:
	set_text("想想连什么词…", hint, State.IDLE)
