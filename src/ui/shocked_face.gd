extends Control
class_name ShockedFace
## “这家伙在说什么呢”的占位脸。若存在 assets/reactions/invalid_word.png 会用贴图。


func _ready() -> void:
	custom_minimum_size = Vector2(84, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	# 头发
	_ellipse(Vector2(w * 0.5, h * 0.34), w * 0.46, h * 0.30, Color("2b2b38"))
	# 脸
	_ellipse(Vector2(w * 0.5, h * 0.56), w * 0.40, h * 0.40, Color("e8c9a0"))
	# 眼白
	_ellipse(Vector2(w * 0.36, h * 0.56), w * 0.13, h * 0.15, Color("f7f7fb"))
	_ellipse(Vector2(w * 0.64, h * 0.56), w * 0.13, h * 0.15, Color("f7f7fb"))
	# 瞳孔
	draw_circle(Vector2(w * 0.36, h * 0.58), h * 0.045, Color("141829"))
	draw_circle(Vector2(w * 0.64, h * 0.58), h * 0.045, Color("141829"))
	# 嘴
	_ellipse(Vector2(w * 0.5, h * 0.80), w * 0.10, h * 0.07, Color("7a3b3b"))


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, segments := 32) -> void:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
