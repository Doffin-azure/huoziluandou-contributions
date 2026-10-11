extends Control
class_name MascotView
## 吉祥物：程序化蓝鲸（占位）。若存在 res://assets/mascot/whale.png 则改用贴图。
## 只是“气泡框的挂点”，不影响玩法。

const BLUE_DARK := Color("2f4a86")
const BLUE := Color("4b6cb7")
const BLUE_LIGHT := Color("7fa0e0")
const BELLY := Color("cfe0ff")
const EYE := Color("141c33")

const MASCOT_CANDIDATES := [
	"res://assets/mascot/mascot.png",
	"res://assets/mascot/mascot.jpg",
	"res://assets/mascot/mascot.webp",
	"res://assets/mascot/whale.png",
	"res://assets/mascot/whale.jpg",
]

var _tex: Texture2D


func _ready() -> void:
	custom_minimum_size = Vector2(140, 128)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in MASCOT_CANDIDATES:
		if ResourceLoader.exists(p):
			_tex = load(p)
			break


func _draw() -> void:
	if _tex != null:
		var s: float = min(size.x / _tex.get_width(), size.y / _tex.get_height())
		var d: Vector2 = Vector2(_tex.get_width(), _tex.get_height()) * s
		draw_texture_rect(_tex, Rect2((size - d) * 0.5, d), false)
		return
	var w := size.x
	var h := size.y
	# 尾巴
	var tail := PackedVector2Array([
		Vector2(w * 0.10, h * 0.56),
		Vector2(w * 0.30, h * 0.44),
		Vector2(w * 0.28, h * 0.70),
	])
	draw_colored_polygon(tail, BLUE_DARK)
	# 身体
	_ellipse(Vector2(w * 0.55, h * 0.58), w * 0.36, h * 0.24, BLUE)
	# 肚皮
	_ellipse(Vector2(w * 0.58, h * 0.66), w * 0.28, h * 0.15, BELLY)
	# 背脊高光
	_ellipse(Vector2(w * 0.52, h * 0.46), w * 0.24, h * 0.06, BLUE_LIGHT)
	# 眼睛
	draw_circle(Vector2(w * 0.74, h * 0.50), h * 0.055, EYE)
	draw_circle(Vector2(w * 0.755, h * 0.485), h * 0.018, Color.WHITE)
	# 喷水
	var sx := w * 0.55
	var sy := h * 0.32
	draw_line(Vector2(sx, sy), Vector2(sx, sy - h * 0.14), BLUE_LIGHT, 2.0)
	draw_circle(Vector2(sx - w * 0.05, sy - h * 0.16), 3.0, BLUE_LIGHT)
	draw_circle(Vector2(sx + w * 0.05, sy - h * 0.18), 3.5, BLUE_LIGHT)
	draw_circle(Vector2(sx, sy - h * 0.24), 3.0, BLUE_LIGHT)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, segments := 40) -> void:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
