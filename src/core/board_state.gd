extends RefCounted
class_name BoardState
## 4×4 字盘的数据层（纯逻辑，不含美术）。

var size: int = 4
var cells: Array = []   ## Array[CharInstance | null]，长度 size*size


func _init(p_size: int = 4) -> void:
	size = p_size
	cells.resize(size * size)
	cells.fill(null)


func idx(x: int, y: int) -> int:
	return y * size + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size


func to_xy(i: int) -> Vector2i:
	return Vector2i(i % size, i / size)


func from_xy(v: Vector2i) -> int:
	return v.y * size + v.x


func get_cell(x: int, y: int) -> CharInstance:
	if not in_bounds(x, y):
		return null
	return cells[idx(x, y)]


func set_cell(x: int, y: int, c: CharInstance) -> void:
	if in_bounds(x, y):
		cells[idx(x, y)] = c


func get_xy(v: Vector2i) -> CharInstance:
	if not in_bounds(v.x, v.y):
		return null
	return cells[idx(v.x, v.y)]


func set_xy(v: Vector2i, c: CharInstance) -> void:
	if in_bounds(v.x, v.y):
		cells[idx(v.x, v.y)] = c


func clear_xy(v: Vector2i) -> void:
	set_xy(v, null)


func empty_indices() -> Array:
	var out: Array = []
	for i in cells.size():
		if cells[i] == null:
			out.append(to_xy(i))
	return out


func free_count() -> int:
	var n := 0
	for c in cells:
		if c == null:
			n += 1
	return n


func fill_count() -> int:
	return cells.size() - free_count()


func neighbors(v: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: Vector2i = v + d
		if in_bounds(n.x, n.y):
			out.append(n)
	return out


func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func valid_path(path: Array) -> bool:
	if path.is_empty():
		return true
	for i in path.size():
		var v: Vector2i = path[i]
		if not in_bounds(v.x, v.y) or get_xy(v) == null:
			return false
		if i > 0 and not is_adjacent(path[i - 1], v):
			return false
	return true


func glyphs_of(path: Array) -> Array:
	var out: Array = []
	for v in path:
		var c: CharInstance = get_xy(v)
		if c == null:
			out.append("")
		else:
			out.append_array(c.glyph_list())
	return out
