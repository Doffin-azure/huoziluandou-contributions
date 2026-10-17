extends Control
class_name MapPath
## 地图上的墨色路径。

var points: Array = []       ## Array[Vector2]
var completed_upto := 0      ## 前 N 段已完成


func set_path(p_points: Array, p_completed: int) -> void:
	points = p_points
	completed_upto = p_completed
	queue_redraw()


func _draw() -> void:
	for i in range(points.size() - 1):
		if i >= points.size() - 1:
			break
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var done := i < completed_upto
		var base := JourneyStyle.GOLD if done else JourneyStyle.EDGE
		var alpha := 0.75 if done else 0.28
		draw_line(a, b, Color(base.r, base.g, base.b, alpha * 0.5), 9.0, true)
		if done:
			draw_line(a, b, JourneyStyle.GOLD, 4.0, true)
		else:
			draw_dashed_line(a, b, Color(base.r, base.g, base.b, 0.4), 3.0, 12.0, true)
