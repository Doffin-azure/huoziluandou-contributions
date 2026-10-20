extends RefCounted
## 璇玑字盘：生成一个 4×4 的随机字盘，保证至少有三个 2～3 字词。
## 事件只把字盘当拼词棋盘，不触发词效、重力或污染。

const SIZE := 4
const TARGET_WORDS := 3


static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cells: Array = []
	cells.resize(SIZE * SIZE)
	cells.fill("")
	var pool: Array = _word_pool()
	_shuffle(pool, rng)
	var chosen: Array = []
	var paths: Array = []
	for word: WordData in pool:
		if chosen.size() >= TARGET_WORDS:
			break
		var glyphs: Array = word.glyphs.duplicate()
		var path := _place_word(rng, glyphs, cells)
		if path.is_empty():
			continue
		chosen.append(word.word)
		paths.append(path)
	if chosen.size() < TARGET_WORDS:
		# 极少数布局失败：重试一次，避免生成没有足够词的盘。
		return generate(seed_value + 104729)
	_fill_empty(rng, cells)
	return {"seed": seed_value, "glyphs": cells, "words": chosen, "paths": paths}


static func _word_pool() -> Array:
	var pool: Array = []
	for word: WordData in Database.words.values():
		if word.glyphs.size() < 2 or word.glyphs.size() > 3:
			continue
		var ok := true
		for glyph in word.glyphs:
			var cd: CharacterData = Database.get_character_by_glyph(str(glyph))
			if cd == null or cd.is_pollution or cd.pending_design or cd.tags.has("event") or cd.tags.has("enemy"):
				ok = false
				break
		if ok:
			pool.append(word)
	return pool


static func _place_word(rng: RandomNumberGenerator, glyphs: Array, cells: Array) -> Array:
	for _attempt in 100:
		var start := Vector2i(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1))
		var path: Array = [start]
		var used := {start: true}
		var walk_ok := true
		for i in range(1, glyphs.size()):
			var candidates: Array = []
			for n: Vector2i in _neighbors(path[path.size() - 1]):
				if not used.has(n):
					candidates.append(n)
			if candidates.is_empty():
				walk_ok = false
				break
			_shuffle(candidates, rng)
			var next: Vector2i = candidates[0]
			path.append(next)
			used[next] = true
		if not walk_ok:
			continue
		var can_place := true
		for i in path.size():
			var pos: Vector2i = path[i]
			var at := _idx(pos)
			if str(cells[at]) != "" and str(cells[at]) != str(glyphs[i]):
				can_place = false
				break
		if not can_place:
			continue
		for i in path.size():
			cells[_idx(path[i])] = str(glyphs[i])
		return path
	return []


static func _fill_empty(rng: RandomNumberGenerator, cells: Array) -> void:
	var glyphs: Array = []
	for cd: CharacterData in Database.characters.values():
		if cd.is_pollution or cd.pending_design or cd.tags.has("event") or cd.tags.has("enemy") or cd.tags.has("彩蛋"):
			continue
		if not glyphs.has(cd.glyph):
			glyphs.append(cd.glyph)
	if glyphs.is_empty():
		return
	for i in cells.size():
		if str(cells[i]).is_empty():
			cells[i] = str(glyphs[rng.randi_range(0, glyphs.size() - 1)])


static func _neighbors(pos: Vector2i) -> Array:
	var out: Array = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: Vector2i = pos + d
		if n.x >= 0 and n.y >= 0 and n.x < SIZE and n.y < SIZE:
			out.append(n)
	return out


static func _idx(pos: Vector2i) -> int:
	return pos.y * SIZE + pos.x


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
