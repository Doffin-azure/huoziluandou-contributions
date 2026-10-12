extends Node
## 棋盘组词概率模拟器（蒙特卡洛）。
## 对比 4×4 方阵（四邻接）与六边形棋盘（半径 2，19 格，六邻接）的“能连出词”的概率。
##
## 运行：
##   godot --headless --path . res://src/tools/board_sim.tscn

const SQUARE_DIRS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const HEX_DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

var _trie: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20261010
	_build_trie()
	print("词库：%d 个（已实现）" % Database.words.size())
	print("")

	var tops := [_topo_square(4), _topo_hex(2)]
	print("棋盘拓扑：")
	for t in tops:
		print("  %s：%d 格，平均邻接度 %.2f" % [t["name"], t["cells"].size(), _avg_degree(t)])
	print("")

	var decks := _decks()
	var trials := 4000
	for d in decks:
		print("=== 字袋：%s（%d 枚 / %d 种）===" % [d["name"], d["glyphs"].size(), d["kinds"]])
		print("   棋盘            落盘  P(≥1词)  P(≥2词)  平均词数  平均两字词  P(含3+字词)")
		for t in tops:
			for deal in d["deals"]:
				_run(d["glyphs"], t, deal, trials)
		print("")
	get_tree().quit()


func _build_trie() -> void:
	_trie.clear()
	for w in Database.words.values():
		var node := _trie
		for g in w.glyphs:
			if not node.has(g):
				node[g] = {}
			node = node[g]
		node["#"] = w.id


# ---------------------------------------------------------------- 拓扑
func _topo_square(n: int) -> Dictionary:
	var cells: Array = []
	for y in n:
		for x in n:
			cells.append(Vector2i(x, y))
	return {"name": "4×4 方阵(四邻)", "cells": cells, "dirs": SQUARE_DIRS, "kind": "square", "n": n}


func _topo_hex(radius: int) -> Dictionary:
	var cells: Array = []
	for q in range(-radius, radius + 1):
		for r in range(max(-radius, -q - radius), min(radius, -q + radius) + 1):
			cells.append(Vector2i(q, r))
	return {"name": "六边形 r2(19格)", "cells": cells, "dirs": HEX_DIRS, "kind": "hex", "n": radius}


func _neighbors(t: Dictionary, c: Vector2i, occ: Dictionary) -> Array:
	var out: Array = []
	for d in t["dirs"]:
		var n: Vector2i = c + d
		if occ.has(n):
			out.append(n)
	return out


func _avg_degree(t: Dictionary) -> float:
	var total := 0
	for c in t["cells"]:
		for d in t["dirs"]:
			if t["cells"].has(c + d):
				total += 1
	return float(total) / float(t["cells"].size())


# ---------------------------------------------------------------- 模拟
func _run(deck: Array, t: Dictionary, deal: int, trials: int) -> void:
	var cells: Array = t["cells"]
	var d: int = min(deal, cells.size())
	var p1 := 0
	var p2 := 0
	var p3 := 0
	var sum_words := 0.0
	var sum_two := 0.0
	for trial in trials:
		# 洗牌取 deal 枚
		var bag: Array = deck.duplicate()
		_shuffle(bag)
		var hand: Array = bag.slice(0, min(d, bag.size()))
		# 随机落盘
		var spots: Array = cells.duplicate()
		_shuffle(spots)
		var occ: Dictionary = {}
		for i in hand.size():
			occ[spots[i]] = hand[i]
		var found: Dictionary = {}
		for c in occ.keys():
			_dfs(occ, t, c, _trie, {}, found)
		var n: int = found.size()
		if n >= 1:
			p1 += 1
		if n >= 2:
			p2 += 1
		sum_words += n
		var two := 0
		var three := 0
		for wid in found.keys():
			var w: WordData = Database.words[wid]
			if w.glyphs.size() == 2:
				two += 1
			else:
				three += 1
		sum_two += two
		if three > 0:
			p3 += 1
	print("   %-15s %3d   %6.1f%%  %6.1f%%   %6.2f    %6.2f      %6.1f%%" % [
		t["name"], d,
		100.0 * p1 / trials, 100.0 * p2 / trials,
		sum_words / trials, sum_two / trials, 100.0 * p3 / trials])


func _dfs(occ: Dictionary, t: Dictionary, c: Vector2i, node: Dictionary, path: Dictionary, found: Dictionary) -> void:
	var g: String = occ[c]
	if not node.has(g):
		return
	var nn: Dictionary = node[g]
	if nn.has("#"):
		found[nn["#"]] = true
	path[c] = true
	for nb in _neighbors(t, c, occ):
		if not path.has(nb):
			_dfs(occ, t, nb, nn, path, found)
	path.erase(c)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# ---------------------------------------------------------------- 代表字袋
func _decks() -> Array:
	var d1 := ["击", "击", "防", "防", "回", "回", "反", "破", "重", "流", "连", "御"]
	var d2 := d1 + ["力", "合", "护", "盾", "金"]
	var d3 := ["热", "热", "热", "火", "火", "过", "过", "载", "冷", "加", "蓄", "充", "电"]
	var d4 := ["击", "击", "击", "防", "防", "回", "回"]
	var d5 := ["击", "防", "回", "反", "破", "重", "流", "连", "御", "力", "合", "护", "盾", "金", "热", "电", "蓄", "充", "转", "清"]
	return [
		{"name": "初始 V0.3", "glyphs": d1, "kinds": _kinds(d1), "deals": [8, 10, 12]},
		{"name": "中期(+力合护盾金)", "glyphs": d2, "kinds": _kinds(d2), "deals": [10, 12, 14]},
		{"name": "热系", "glyphs": d3, "kinds": _kinds(d3), "deals": [10, 12, 14]},
		{"name": "薄核(只3种字)", "glyphs": d4, "kinds": _kinds(d4), "deals": [7, 10]},
		{"name": "厚杂(20种各1)", "glyphs": d5, "kinds": _kinds(d5), "deals": [12, 14, 16]},
	]


func _kinds(glyphs: Array) -> int:
	var s := {}
	for g in glyphs:
		s[g] = true
	return s.size()
