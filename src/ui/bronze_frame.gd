extends Control
class_name BronzeFrame
## 桌面保留完整机关比例，手机适配边角；字盘内容独立实时渲染。
var _texture: Texture2D
var illustrated_framing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture = TaopunkArt.frame()
	resized.connect(queue_redraw)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	if _texture == null: return
	if illustrated_framing:
		# 按原始比例绘制，避免九宫压扁顶端圆锁、铆钉和四角的机械结构。
		draw_texture_rect(_texture, Rect2(-size * 0.08, size * 1.16), false)
		return
	var source := Vector2(_texture.get_size())
	var source_border := source * 0.19
	var border := minf(size.x, size.y) * 0.07
	var xs := [0.0, border, size.x - border, size.x]
	var ys := [0.0, border, size.y - border, size.y]
	var sx := [0.0, source_border.x, source.x - source_border.x, source.x]
	var sy := [0.0, source_border.y, source.y - source_border.y, source.y]
	for y in 3:
		for x in 3:
			if x == 1 and y == 1: continue
			draw_texture_rect_region(_texture, Rect2(xs[x], ys[y], xs[x + 1] - xs[x], ys[y + 1] - ys[y]), Rect2(sx[x], sy[y], sx[x + 1] - sx[x], sy[y + 1] - sy[y]))
