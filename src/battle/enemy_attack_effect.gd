extends EnemyInkEffect
class_name EnemyAttackEffect
## 短促的材质轨迹，与实际命中逐次同步；不是新的 HUD 图标。
var attack_style := "brush"
const GOLD := Color("a48147")
const IVORY := Color("e1d0a7")


func _draw() -> void:
	if Settings.reduced_motion or _age < delay: return
	if attack_style == "brush":
		super._draw()
		return
	var t := progress
	var center := _point(t)
	var forward := (destination - origin).normalized()
	var side := forward.orthogonal()
	var color := RED if attack_style == "ember" else INK
	for i in 6:
		var p := _point(maxf(0, t - i * 0.026))
		var fade := 0.60 - i * 0.085
		if attack_style == "ember":
			var drift := side * sin(i * 2.4 + t * 8) * i
			draw_colored_polygon(PackedVector2Array([p + drift + forward * 5, p + drift + side * 2, p + drift - forward * 6, p + drift - side * 2]), Color(color, fade))
		else:
			draw_line(p - forward * 8, p, Color(color, fade), 2 + i * 0.25, true)
	match attack_style:
		"arc":
			var points := PackedVector2Array([center-forward*22,center-forward*8+side*7,center-forward*2-side*5,center+forward*10+side*4,center+forward*22])
			draw_polyline(points,Color("ead79a"),2.8,true)
		"seal":
			var shape := PackedVector2Array([center + Vector2(-8, -9), center + Vector2(9, -7), center + Vector2(8, 9), center + Vector2(-9, 8)])
			draw_colored_polygon(shape, INK)
			shape.append(shape[0])
			draw_polyline(shape, GOLD, 2, true)
		"blade", "paper":
			for i in 3:
				var p := center + side * (i - 1) * 7 - forward * i * 5
				draw_colored_polygon(PackedVector2Array([p + forward * 16, p + side * 2, p - forward * 10, p - side * 3]), IVORY if attack_style == "paper" else Color("b2b3a2"))
		"ember":
			draw_circle(center, 5, RED)
			draw_line(center - forward * 9, center + forward * 3, GOLD, 2.5, true)
		"press":
			var p := center + Vector2(0, -10 * (1 - t))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -9), p + Vector2(10, -9), p + Vector2(11, 6), p + Vector2(-9, 8)]), INK)
			draw_line(p + Vector2(-9, 7), p + Vector2(10, 7), GOLD, 2, true)
		"serpent":
			var points := PackedVector2Array()
			for i in 12:
				var u := maxf(0, t - i * 0.015)
				points.append(_point(u) + side * sin(i * 0.65 + t * 9) * 5)
			draw_polyline(points, INK, 5, true)
			draw_line(center, center + forward * 8 + side * 3, RED, 1.7, true)
		"maw":
			for sign_value in [-1.0, 1.0]:
				var p: Vector2 = center + side * sign_value * lerpf(15, 2, t)
				draw_colored_polygon(PackedVector2Array([p + forward * 9, p - forward * 4 + side * sign_value * 4, p - forward * 6 - side * sign_value * 3]), IVORY)
