extends RefCounted
class_name BattleTouchLayout
## 手机横屏的空间预算。尺寸以界面单位计算，unit 表示一个触控逻辑像素。
## 先给字盘分配完整高度，再安放侧栏；不再为底栏重复预留一行空间。

## Debug-only density injection for renderer regression captures; release ignores it.
static var test_dpi := 0.0

static func unit_for(view_size: Vector2, window_size: Vector2i) -> float:
	if OS.is_debug_build() and test_dpi > 0:
		return maxf(1.0, view_size.y / maxf(1, window_size.y) * maxf(1, test_dpi / 160.0))
	return ScreenLayout.unit_for(view_size, window_size)


static func measure(view_size: Vector2, unit: float, _has_status: bool) -> Dictionary:
	var margin := 8 * unit
	var gap := 6 * unit
	var row := 48 * unit
	var vertical_gap := 4 * unit
	var body_y := row + vertical_gap
	var action_y := view_size.y - vertical_gap - row
	var side := minf(action_y - vertical_gap - body_y, view_size.x * 0.46)
	var column := (view_size.x - side) * 0.5 - margin - gap
	var board_x := (view_size.x - side) * 0.5
	# Keep one status row available even before the first buff. Its icons hide at
	# zero; gaining/losing a resource must never reflow the paper during a play.
	var status_height := row + gap
	var right_x := board_x + side + gap
	return {
		"column": column,
		"topbar": Rect2(margin, 0, view_size.x - margin * 2, row),
		"board": Rect2(board_x, body_y, side, side),
		"player": Rect2(margin, 0, maxf(column, minf(270 * unit, view_size.x * 0.38)), row),
		"status": Rect2(margin, body_y, column, row),
		"preview": Rect2(margin, body_y + status_height, column, side - status_height),
		"enemy": Rect2(right_x, body_y, column, side),
		"actions": Rect2(board_x, action_y, side, row),
		"end": Rect2(right_x, action_y, column, row),
		"footer": Rect2(margin, action_y, column, row),
	}
