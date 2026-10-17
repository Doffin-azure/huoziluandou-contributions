extends Control
class_name EnemyInkEffect
## 墨灵的局部墨迹：蓄墨、攻击笔锋、污染实体飞行。固定轨迹不消耗战斗 RNG。
var phase := "attack"
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var glyph := ""
var duration := 0.16
var delay := 0.0
var progress := 0.0
var _age := 0.0
var _word: Label
const INK := Color("172b2d")
const RED := Color("a72d2d")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if phase == "pollution":
		_word = Ink.label(glyph, "", Palette.PAPER_WARM)
		_word.add_theme_font_size_override("font_size", 25)
		_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_word.size = Vector2(36, 36)
		_word.hide()
		add_child(_word)


func _process(delta: float) -> void:
	if Settings.reduced_motion:
		queue_free()
		return
	_age += delta
	if _age >= duration + delay:
		queue_free()
		return
	progress = clampf((_age - delay) / duration, 0, 1)
	if _word != null:
		_word.visible = _age >= delay and progress > 0.30
		_word.position = _point(progress) - _word.size * 0.5
		_word.modulate.a = smoothstep(0.30, 0.60, progress)
	queue_redraw()


func _point(t: float) -> Vector2:
	var bend := origin.lerp(destination, 0.5) + Vector2(0, -minf(85, origin.distance_to(destination) * 0.22))
	return origin.lerp(bend, t).lerp(bend.lerp(destination, t), t)


func _draw() -> void:
	if _age < delay or Settings.reduced_motion: return
	var t := progress
	if phase == "charge":
		for i in 3:
			var radius := lerpf(40.0, 8.0, t) + i * 5.0
			var start := t * 1.5 + i * TAU / 3
			draw_arc(origin, radius, start, start + 1.0, 18, Color(INK, sin(t * PI) * 0.65), 2, true)
		draw_circle(origin, 3 + t * 5, Color(RED, sin(t * PI) * 0.65))
		return
	if phase == "attack":
		# 一笔扫出，尖端快、墨尾短；避免覆盖整个字盘和战况。
		var points := PackedVector2Array()
		var tail := maxf(0, t - 0.26)
		for i in 13:
			var u := lerpf(tail, t, i / 12.0)
			var p := _point(u)
			var tangent := (_point(minf(1, u + 0.01)) - _point(maxf(0, u - 0.01))).normalized()
			points.append(p + tangent.orthogonal() * sin(i / 12.0 * PI) * 8)
		for i in range(12, -1, -1):
			var u := lerpf(tail, t, i / 12.0)
			var p := _point(u)
			var tangent := (_point(minf(1, u + 0.01)) - _point(maxf(0, u - 0.01))).normalized()
			points.append(p - tangent.orthogonal() * sin(i / 12.0 * PI) * 4)
		if t > 0.01: draw_colored_polygon(points, Color(INK, 0.9))
		return
	if phase == "pollution":
		var center := _point(t)
		for i in 7:
			var u := maxf(0, t - i * 0.025)
			var p := _point(u) + Vector2(0, sin(i * 2.4 + t * 13) * i * 0.6)
			draw_circle(p, maxf(1, 10 - i * 1.2), Color(INK, 0.85 - i * 0.10))
		for i in 3:
			var offset := Vector2.from_angle(i * 2.1 + t * 5) * (14 + sin(t * PI) * 5)
			draw_circle(center + offset, 1.7, Color(INK, sin(t * PI) * 0.8))
		return
	if phase == "land":
		for i in 9:
			var direction := Vector2.from_angle(i * 2.399)
			var p := destination + direction * lerpf(4, 30, t)
			draw_line(p, p + direction * (4 + 6 * (1 - t)), Color(INK, (1 - t) * 0.75), 2 * (1 - t) + 0.5, true)
