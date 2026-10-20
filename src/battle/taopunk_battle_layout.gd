extends RefCounted
class_name TaopunkBattleLayout
## Desktop uses the available height, with a square board and flexible side papers.
## Artwork scale controls typography/ornaments, not a fixed letterboxed canvas.


static func measure(view: Vector2, _has_status: bool) -> Dictionary:
	var factor := view.y / 900.0
	var margin := 20.0 * factor
	var gap := 16.0 * factor
	var header := 80.0 * factor
	var action := 86.0 * factor
	var body_y := margin + header + gap
	var action_y := view.y - margin - action
	var side := minf(action_y - gap - body_y, view.x * 0.46)
	var column := (view.x - margin * 2 - gap * 2 - side) * 0.5
	var board_x := margin + column + gap
	var right_x := board_x + side + gap
	return {
		"scale": factor,
		"column": column,
		"topbar": Rect2(margin, margin, view.x - margin * 2, header),
		"player": Rect2(margin, margin, column, header),
		"board": Rect2(board_x, body_y, side, side),
		"preview": Rect2(margin, body_y, column, side),
		"enemy": Rect2(right_x, body_y, column, side),
		"actions": Rect2(board_x, action_y, side, action),
		"end": Rect2(right_x, action_y, column, action),
		"footer": Rect2(margin, action_y, column, action),
		# Statuses have a stable home in the middle of the header, above the board.
		"status": Rect2(board_x, margin + 12 * factor, side, 48 * factor),
		"turn": Rect2(right_x, margin, 100 * factor, header),
	}
