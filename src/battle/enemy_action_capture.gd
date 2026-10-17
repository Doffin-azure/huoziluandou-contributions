extends RefCounted
class_name EnemyActionCapture
## 只读快照：污染飞行必须对应实际生成的实体，不能按意图数量猜测落点。


static func board_snapshot(board: BoardState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in board.cells.size():
		var inst: CharInstance = board.cells[i]
		if inst != null:
			result.append({"uid": inst.uid, "enemy": inst.is_enemy_owned(), "glyph": inst.glyph(), "cell": board.to_xy(i)})
	return result


static func injected(before: Array, after: Array) -> Array[Dictionary]:
	var known: Dictionary = {}
	for item in before: known[item.uid] = true
	var added: Array[Dictionary] = []
	for item in after:
		if item.enemy and not known.has(item.uid): added.append(item)
	return added
