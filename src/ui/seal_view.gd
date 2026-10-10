extends Control
class_name SealView
## 朱印：用于标题、敌人头像、地图节点。纯绘制。

enum Shape { SQUARE, CIRCLE }

var glyph := "活"
var seal_color := Palette.VERMILION
var glyph_color := Palette.PAPER
var shape: int = Shape.SQUARE
var font_ratio := 0.62
var ring := true
var wobble := 0.0


func setup(p_glyph: String, p_color: Color, p_shape: int = Shape.SQUARE, p_glyph_color: Color = Palette.PAPER) -> void:
	glyph = p_glyph
	seal_color = p_color
	shape = p_shape
	glyph_color = p_glyph_color
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var m: float = minf(size.x, size.y) * 0.5
	if shape == Shape.CIRCLE:
		draw_circle(c, m, seal_color)
		if ring:
			draw_arc(c, m - 3, 0, TAU, 48, seal_color.lightened(0.35), 2.0, true)
	else:
		var radius := m * 0.28
		var sb := StyleBoxFlat.new()
		sb.bg_color = seal_color
		sb.set_corner_radius_all(int(radius))
		sb.set_border_width_all(2)
		sb.border_color = seal_color.darkened(0.25)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if ring:
			var inner := StyleBoxFlat.new()
			inner.bg_color = Color(0, 0, 0, 0)
			inner.set_corner_radius_all(int(radius * 0.8))
			inner.set_border_width_all(1)
			inner.border_color = glyph_color * Color(1, 1, 1, 0.35)
			inner.set_content_margin_all(4)
			draw_style_box(inner, Rect2(Vector2(5, 5), size - Vector2(10, 10)))

	var fs := int(m * font_ratio * 2.0)
	var font: Font = Ink.serif
	var ascent := font.get_ascent(fs)
	var tw := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - tw * 0.5, c.y + ascent * 0.5 - fs * 0.04), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, glyph_color)
