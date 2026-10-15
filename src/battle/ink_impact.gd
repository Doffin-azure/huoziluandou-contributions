extends Control
class_name InkImpact
var ink_color := Palette.VERMILION_DK
var heavy := false
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var fade := 1.0 - progress
	var reach := lerpf(12.0, 46.0 if heavy else 30.0, progress)
	for i in 12:
		var a := i * 2.399
		var direction := Vector2(cos(a), sin(a) * 0.7)
		var tip := direction * reach * (0.6 + absf(sin(i * 1.9)) * 0.4)
		draw_line(tip - direction * (8.0 * fade), tip, Color(ink_color, fade * 0.75), 1.0 + fade * 2.0, true)
		draw_circle(tip + direction * 5.0, 0.8 + fade * (i % 3), Color(ink_color, fade * 0.60))
	draw_arc(Vector2.ZERO, reach * 0.6, 0.3, 4.7, 24, Color(ink_color, fade * 0.35), 1.5, true)
