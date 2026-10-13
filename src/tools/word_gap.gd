extends Node
## 字对缺口挖掘：把「可能该收录但没收录」的二字对挖出来，缩小人工审阅范围。
## 运行：godot --headless --path . res://src/tools/word_gap.tscn
## 产物：docs/字词缺口报告.md

const OUT := "res://docs/字词缺口报告.md"

var _glyphs: Array = []
var _tags: Dictionary = {}      ## glyph -> Array[String]
var _covered: Dictionary = {}   ## "AB" -> word
var _prefix: Dictionary = {}    ## A -> {B: word}
var _suffix: Dictionary = {}    ## B -> {A: word}


func _ready() -> void:
	for c in Database.characters.values():
		if c.glyph == "" or c.glyph == "字":
			continue
		_glyphs.append(c.glyph)
		_tags[c.glyph] = c.tags
	_glyphs.sort()
	var multi := []
	for w in Database.words.values():
		var gs: Array = w.glyphs
		if gs.size() == 2:
			var a := String(gs[0])
			var b := String(gs[1])
			_covered[a + b] = w.word
			if not _prefix.has(a):
				_prefix[a] = {}
			if not _suffix.has(b):
				_suffix[b] = {}
			_prefix[a][b] = w.word
			_suffix[b][a] = w.word
		elif gs.size() >= 3:
			multi.append(w)

	var lines: Array = []
	lines.append("# 字词缺口报告（自动生成，勿手改）\n")
	lines.append("字 %d · 有序字对 %d · 已收录二字词 %d（覆盖 %.1f%%）\n" % [
		_glyphs.size(), _glyphs.size() * (_glyphs.size() - 1), _covered.size(),
		100.0 * _covered.size() / (_glyphs.size() * (_glyphs.size() - 1))])
	lines.append("> 说明：这是**候选挖掘**，不是「应该收录」的判决。三张表按优先级排列，人工只需逐条判「收 / 不收」。\n")

	_section_reverse(lines)
	_section_tags(lines)
	_section_multisub(lines, multi)
	_section_full(lines)

	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("[word_gap] 写出 %s（%d 行）" % [OUT, lines.size()])
	get_tree().quit()


## ① 反向缺失：收录了 AB，却没收录 BA（中文里很多词是成对的）
func _section_reverse(lines: Array) -> void:
	lines.append("\n## ① 反向缺失（AB 已收录，BA 未收录）\n")
	var n := 0
	for key in _covered:
		var ab := String(key)
		var ba := ab.substr(1, 1) + ab.substr(0, 1)
		if ab.substr(0, 1) == ab.substr(1, 1):
			continue
		if not _covered.has(ba):
			lines.append("- [ ] %s（已收：%s） → 反向 **%s**" % [ab, _covered[ab], ba])
			n += 1
	lines.append("\n共 %d 组。\n" % n)


## ② 同语义域一致性：同一 tag 的字，在「X→B」「A→X」上的收录应当大致一致
func _section_tags(lines: Array) -> void:
	lines.append("\n## ② 同语义域一致性缺口\n")
	lines.append("同一 tag 内的字互相搭配时，若已有 ≥2 个收录，则剩下的多半也该收。\n")
	var by_tag: Dictionary = {}
	for g in _glyphs:
		for t in _tags[g]:
			if not by_tag.has(t):
				by_tag[t] = []
			by_tag[t].append(g)
	for t in by_tag.keys():
		var group: Array = by_tag[t]
		if group.size() < 3:
			continue
		lines.append("\n### 标签 `%s`（%s）\n" % [t, "、".join(group)])
		lines.append("| 前缀 → | 已收录后缀 | 该 tag 内缺失的后缀 |")
		lines.append("|---|---|---|")
		for a in group:
			var have: Array = _prefix.get(a, {}).keys()
			if have.is_empty():
				continue
			var miss: Array = []
			for b in group:
				if b == a or _covered.has(a + b):
					continue
				miss.append(b)
			if not miss.is_empty():
				lines.append("| **%s** | %s | %s |" % [a, "、".join(have), "、".join(miss)])
		# 反向：同一个 tag 里已有 ≥2 个字能接 B，那该 tag 内剩下的大多也能接
		for b in group:
			var srcs: Array = []
			for s in _suffix.get(b, {}).keys():
				if group.has(s):
					srcs.append(s)
			if srcs.size() < 2:
				continue
			var miss2: Array = []
			for a in group:
				if a != b and not _covered.has(a + b):
					miss2.append(a)
			if not miss2.is_empty():
				lines.append("| → **%s** | %s | %s |" % [b, "、".join(srcs), "、".join(miss2)])
		lines.append("")



## ③ 多字词拆解：3 字以上词的二字子串，看是否也该作为独立词收录
func _section_multisub(lines: Array, multi: Array) -> void:
	lines.append("\n## ③ 多字词的二字子串\n")
	lines.append("已收录的 3+ 字词，其连续二字子串往往也能独立成词。\n")
	for w in multi:
		var gs: Array = w.glyphs
		var subs: Array = []
		for i in range(gs.size() - 1):
			var ab := String(gs[i]) + String(gs[i + 1])
			subs.append("%s%s" % [ab, "（已收）" if _covered.has(ab) else "（**未收**）"])
		lines.append("- 《%s》：%s" % [w.word, "、".join(subs)])
	lines.append("")


## ④ 全量未收录清单，按前缀字分组（含两字的 tag，人工分片审）
func _section_full(lines: Array) -> void:
	lines.append("\n## ④ 全量未收录二字对（按前缀字分组，共 %d 组）\n" % _glyphs.size())
	for a in _glyphs:
		var miss: Array = []
		for b in _glyphs:
			if b != a and not _covered.has(a + b):
				miss.append(b)
		if miss.is_empty():
			continue
		lines.append("- **%s**[%s] → %s" % [a, "、".join(_tags[a]), "、".join(miss)])
