extends Control
class_name StatBar
## 圆角血条 / 护盾条。

var value := 0
var max_value := 1
var bar_color := Palette.HP
var bg_color := Color(0.15, 0.12, 0.1, 0.85)
var label_text := ""
var show_text := true
var font_size := 15


func setup_bar(v: int, m: int, c: Color, label := "") -> void:
	value = v
	max_value = max(1, m)
	bar_color = c
	if label.is_empty():
		label_text = "%d / %d" % [value, max_value]
	else:
		label_text = label
	queue_redraw()


func _ready() -> void:
	custom_minimum_size.y = 22
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var r := h * 0.5
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.set_corner_radius_all(int(r))
	draw_style_box(bg, Rect2(Vector2.ZERO, size))

	var ratio: float = clampf(float(value) / float(max_value), 0.0, 1.0)
	if ratio > 0.0:
		var fg := StyleBoxFlat.new()
		fg.bg_color = bar_color
		fg.set_corner_radius_all(int(r))
		draw_style_box(fg, Rect2(Vector2.ZERO, Vector2(max(h, size.x * ratio), h)))

	if show_text:
		var font: Font = Ink.serif
		var ascent := font.get_ascent(font_size)
		var pos := Vector2(0, (h + ascent) * 0.5 - 2)
		draw_string(font, pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Palette.PAPER)
