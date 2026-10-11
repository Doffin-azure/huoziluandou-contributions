extends SceneTree
## 字网"加边"审计：在不新增字的前提下，找出能提升连通性的候选词（边）。
## 运行：godot --headless --script res://src/tools/graph_audit.gd

const CHAR_DIR := "res://resources/characters"
const WORD_DIR := "res://resources/words"

# 候选边（真词，且两字都在库中）。analyze() 会判断是否为新边并评估增益。
const CANDS := [
	"开火", "开放", "灯火", "电灯", "转速", "转载", "载重", "超重",
	"收复", "收回", "能力", "电能", "电力", "电热", "热电", "火电",
	"蓄热", "过冷", "过电", "急转", "火热", "热心", "急流", "火急",
	"防毒", "防雷", "雷电", "雷击", "击剑", "铸剑", "御剑", "剑心",
	"攻击", "反攻", "强攻", "速攻", "攻防", "攻心", "火攻",
	"障碍", "污秽", "灯火", "重利", "愈合", "精心", "心力", "心急",
	"障碍", "分开", "分心", "开心", "放心", "充分", "洗心",
]

var _chars: Array = []
var _adj: Dictionary = {}
var _has_edge: Dictionary = {}
var _word_set: Dictionary = {}

func _initialize() -> void:
	_load()
	_report()
	_eval_candidates()
	quit()

func _load() -> void:
	_adj = {}
	_has_edge = {}
	_word_set = {}
	for f in DirAccess.get_files_at(CHAR_DIR):
		if not f.ends_with(".tres"):
			continue
		var c = load(CHAR_DIR.path_join(f))
		if c == null:
			continue
		_chars.append(c.glyph)
		_adj[c.glyph] = {}
	for f in DirAccess.get_files_at(WORD_DIR):
		if not f.ends_with(".tres"):
			continue
		var w = load(WORD_DIR.path_join(f))
		if w == null:
			continue
		_word_set[w.word] = true
		var gs: Array = w.glyphs
		for i in gs.size():
			_adj[gs[i]] = _adj.get(gs[i], {})
			for j in gs.size():
				if i == j:
					continue
				_adj[gs[i]][gs[j]] = true
				_has_edge[_key(gs[i], gs[j])] = true

func _key(a: String, b: String) -> String:
	return a + "→" + b

func _report() -> void:
	print("=== 字网现状 ===")
	print("节点（字）：%d" % _chars.size())
	print("无向边（共现对）：%d" % (_has_edge.size() / 2))
	var comps := _components()
	comps.sort_custom(func(a, b): return a.size() > b.size())
	var sizes: Array = []
	for c in comps:
		sizes.append(c.size())
	print("连通分量：%d 个  大小：%s" % [comps.size(), str(sizes.slice(0, 10))])
	print("\n按度数升序（低=边缘）：")
	var deg: Array = []
	for g in _chars:
		deg.append([g, _adj[g].size()])
	deg.sort_custom(func(a, b): return a[1] < b[1])
	var line := ""
	for d in deg:
		line += "%s%d  " % [d[0], d[1]]
	print("  " + line)
	# 孤立单点
	var iso: Array = []
	for c in comps:
		if c.size() == 1:
			iso.append(c[0])
	print("\n孤立单点（不在任何多字词里）：", iso)

func _components() -> Array:
	var seen := {}
	var comps: Array = []
	for g in _chars:
		if seen.has(g):
			continue
		var stack := [g]
		var comp: Array = []
		while not stack.is_empty():
			var x: String = stack.pop_back()
			if seen.has(x):
				continue
			seen[x] = true
			comp.append(x)
			for y in _adj[x].keys():
				if not seen.has(y):
					stack.append(y)
		comps.append(comp)
	return comps

func _eval_candidates() -> void:
	print("\n=== 候选边评估（仅列新边）===")
	var seen := {}
	var rows: Array = []
	for w in CANDS:
		if _word_set.has(w) or seen.has(w):
			continue
		seen[w] = true
		var gs: Array = []
		for i in w.length():
			gs.append(w.substr(i, 1))
		var ok := true
		for g in gs:
			if not _adj.has(g):
				ok = false
		if not ok:
			continue
		# 该词引入的新无向边
		var fresh: Array = []
		for i in gs.size():
			for j in range(i + 1, gs.size()):
				if not _has_edge.has(_key(gs[i], gs[j])) and not _has_edge.has(_key(gs[j], gs[i])):
					fresh.append("%s-%s" % [gs[i], gs[j]])
		# 增益：连接了多少个"低度"字 + 是否桥接不同分量
		var low := 0
		for g in gs:
			if _adj[g].size() <= 3:
				low += 1
		rows.append({"w": w, "g": ",".join(gs), "fresh": fresh, "low": low, "new": fresh.size()})
	rows.sort_custom(func(a, b):
		if a.new != b.new:
			return a.new > b.new
		return a.low > b.low)
	for r in rows:
		print("  %s (%s)  新边%d 边缘字%d  %s" % [r.w, r.g, r.new, r.low, str(r.fresh)])
