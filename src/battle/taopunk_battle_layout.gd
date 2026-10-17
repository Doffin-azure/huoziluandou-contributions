extends RefCounted
class_name TaopunkBattleLayout
## 定稿以 1980×792 为构图基准。桌面保留画幅留白，手机沿用触控布局。
const CANVAS := Vector2(1980, 792)


static func measure(view: Vector2, has_status: bool) -> Dictionary:
	var factor := minf(view.x / CANVAS.x, view.y / CANVAS.y)
	var origin := (view - CANVAS * factor) * 0.5
	var rect := func(x: float, y: float, w: float, h: float) -> Rect2:
		return Rect2(origin + Vector2(x, y) * factor, Vector2(w, h) * factor)
	var status_h := 60.0 if has_status else 0.0
	return {
		"scale": factor,
		"column": 490.0 * factor,
		"topbar": rect.call(200, 18, 1590, 76),
		"player": rect.call(210, 18, 500, 76),
		"board": rect.call(695, 90, 565, 565),
		"preview": rect.call(200, 132 + status_h, 490, 520 - status_h),
		"enemy": rect.call(1280, 140, 500, 516),
		"actions": rect.call(730, 680, 585, 86),
		"end": rect.call(1330, 680, 460, 86),
		"footer": rect.call(200, 680, 510, 86),
		"status": rect.call(214, 136, 458, 48),
	}
