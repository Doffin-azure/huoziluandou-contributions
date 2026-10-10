extends Node
## 导出独立的“字表”（含 出度/入度/词数/单字效果）。
## 运行：godot --headless --path . res://src/tools/dump_chars.tscn

func _ready() -> void:
	var out_adj: Dictionary = {}
	var in_adj: Dictionary = {}
	var wc: Dictionary = {}
	for w in Database.words.values():
		for g in w.glyphs:
			wc[g] = int(wc.get(g, 0)) + 1
		for i in range(w.glyphs.size() - 1):
			var a: String = w.glyphs[i]
			var b: String = w.glyphs[i + 1]
			if not out_adj.has(a):
				out_adj[a] = {}
			if not in_adj.has(b):
				in_adj[b] = {}
			out_adj[a][b] = true
			in_adj[b][a] = true

	var chars: Array = Database.characters.values()
	chars.sort_custom(func(a, b):
		var da: int = out_adj.get(a.glyph, {}).size() + in_adj.get(a.glyph, {}).size()
		var db: int = out_adj.get(b.glyph, {}).size() + in_adj.get(b.glyph, {}).size()
		if da != db:
			return da > db
		var wa: int = int(wc.get(a.glyph, 0))
		var wb: int = int(wc.get(b.glyph, 0))
		if wa != wb:
			return wa > wb
		return a.glyph < b.glyph)

	print("共 **%d** 个字。出度/入度按“词里的相邻顺序”统计（无向邻接的字也计）。\n" % chars.size())
	print("| 字 | id | 拼音 | 标签 | 稀有度 | 单字效果 | 词数 | 出度 | 入度 | 备注 |")
	print("|---|---|---|---|---:|---|---:|---:|---:|---|")
	for c in chars:
		var o: int = out_adj.get(c.glyph, {}).size()
		var i2: int = in_adj.get(c.glyph, {}).size()
		print("| **%s** | `%s` | %s | %s | %s | %s | %d | %d | %d | %s |" % [
			c.glyph, c.id, c.pinyin, _tags(c.tags), _rarity(c.rarity),
			_solo(c), int(wc.get(c.glyph, 0)), o, i2, _note(c)])
	get_tree().quit()


func _tags(t: Array) -> String:
	if t.is_empty():
		return "—"
	var out: Array = []
	for x in t:
		out.append(_tag_name(str(x)))
	return " / ".join(out)


func _tag_name(t: String) -> String:
	match t:
		"attack": return "攻击"
		"defense": return "防御"
		"space": return "空间"
		"flow": return "流转"
		"economy": return "经济"
		"energy": return "储能"
		"heat": return "热度"
		"utility": return "辅助"
		"alchemy": return "淬炼"
		"pollution": return "污染源"
		"enemy": return "敌方"
		"彩蛋": return "彩蛋"
		"pending": return "候选"
		_: return t


func _rarity(r: int) -> String:
	match r:
		0: return "基础"
		1: return "普通"
		2: return "稀有"
		3: return "史诗"
		4: return "特殊"
		_: return str(r)


func _solo(c: CharacterData) -> String:
	if c.solo_effects.is_empty():
		return "（无 / 仅腾格）"
	var parts: Array = []
	for e in c.solo_effects:
		parts.append(e.describe())
	return "；".join(parts)


func _note(c: CharacterData) -> String:
	var out: Array = []
	if c.is_pollution:
		out.append("污染源")
	if c.tags.has("enemy"):
		out.append("敌方字")
	if c.tags.has("彩蛋"):
		out.append("彩蛋")
	if c.pending_design:
		out.append("候选/待定")
	if out.is_empty():
		return "—"
	return " / ".join(out)
