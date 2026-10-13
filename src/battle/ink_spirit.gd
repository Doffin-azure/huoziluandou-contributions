extends Control
class_name InkSpirit
## 墨灵使用独立透明角色插画；其他敌人保留各自字形以便区分。
var glyph := "墨"
var _ink: Texture2D
var _character: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink = load("res://assets/battle/ink_spirit.png")
	_character = load("res://assets/battle/ink_spirit_character.png")
	resized.connect(queue_redraw)


func _draw() -> void:
	if _ink == null:
		return
	var unit := minf(size.x, size.y)
	var origin := (size - Vector2.ONE * unit) * 0.5
	if glyph == "墨" and _character != null:
		draw_texture_rect(_character, Rect2(origin, Vector2.ONE * unit), false)
		return
	draw_texture_rect(_ink, Rect2(origin, Vector2.ONE * unit), false)
	var fs := int(unit * 0.37)
	var font: Font = Ink.serif
	var width := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var center := size * Vector2(0.50, 0.56)
	draw_string(font, center + Vector2(-width * 0.5, (font.get_ascent(fs) - font.get_descent(fs)) * 0.5),
		glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.PAPER_WARM)
