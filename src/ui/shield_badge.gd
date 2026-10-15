extends HintButton
class_name ShieldBadge
## 血条端点上的盾值，数字位于盾内，与能力角标区分。
var value := 0
var persistent := false
var ui_scale := 1.0


func _ready() -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	resized.connect(queue_redraw)


func _draw() -> void:
	var side := minf(size.x, size.y)
	var origin := (size - Vector2.ONE * side) * 0.5
	var points := PackedVector2Array()
	for point in [Vector2(0.5, 0.05), Vector2(0.92, 0.18), Vector2(0.87, 0.67), Vector2(0.5, 0.96), Vector2(0.13, 0.67), Vector2(0.08, 0.18)]:
		points.append(origin + point * side)
	var color := Palette.INK.lightened(0.12) if is_hovered() else Palette.INK
	draw_colored_polygon(points, color)
	if persistent:
		var rim := PackedVector2Array()
		for point in points: rim.append(origin + Vector2.ONE * side * 0.5 + (point - origin - Vector2.ONE * side * 0.5) * 0.84)
		rim.append(rim[0])
		draw_polyline(rim, Palette.PAPER, maxf(1, ui_scale), true)
	var font: Font = Ink.serif
	var font_size := int(20 * ui_scale)
	var text_value := str(value)
	while font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > side * 0.66 and font_size > int(11 * ui_scale):
		font_size -= 1
	var text_width := font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := origin.y + side * 0.46 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2((size.x - text_width) * 0.5, baseline), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.PAPER)
