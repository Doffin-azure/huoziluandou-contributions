extends Node
## 把字网导出为 SVG 图（真实力导向布局），供策划案插图。
## 运行：godot --headless --path . res://src/tools/glyph_network_svg.tscn

const OUT := "res://docs/images"
const STARTER := ["击", "防", "回", "反", "破", "重", "流", "连", "御"]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20261010
	DirAccess.make_dir_recursive_absolute(OUT)
	var all: Array = Database.words.values()
	_write(all, [], "%s/glyph_network.svg" % OUT, "字网图谱 · 全部 %d 词" % all.size(), 1220, 900)
	_write(all, STARTER, "%s/glyph_network_starter.svg" % OUT, "初始字袋（9 种字）字网", 780, 560)
	print("[glyph_network_svg] done")
	get_tree().quit()


func _write(words: Array, only: Array, path: String, title: String, w: int, h: int) -> void:
	var graph := _build(words, only)
	if only.is_empty():
		graph = _keep_largest(graph)
	_layout(graph["nodes"], graph["edges"], w, h)
	var svg := _svg(graph, title, w, h)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(svg)
	f.close()
	print("  · %s（字 %d / 边 %d）" % [path, graph["nodes"].size(), graph["edges"].size()])


func _build(words: Array, only: Array) -> Dictionary:
	var out_adj: Dictionary = {}
	var in_adj: Dictionary = {}
	var edges_map: Dictionary = {}
	var involved: Dictionary = {}
	for w in words:
		var gs: Array = w.glyphs
		for g in gs:
			if only.is_empty() or only.has(g):
				involved[g] = true
		for i in range(gs.size() - 1):
			var a := str(gs[i])
			var b := str(gs[i + 1])
			if not only.is_empty() and (not only.has(a) or not only.has(b)):
				continue
			if not out_adj.has(a):
				out_adj[a] = {}
			if not in_adj.has(b):
				in_adj[b] = {}
			out_adj[a][b] = true
			in_adj[b][a] = true
			edges_map["%s|%s" % [a, b]] = true
			involved[a] = true
			involved[b] = true
	var nodes: Array = []
	for g in involved.keys():
		var o: int = out_adj.get(g, {}).size()
		var i2: int = in_adj.get(g, {}).size()
		nodes.append({
			"glyph": g, "out": o, "in": i2, "total": o + i2,
			"color": _color(Database.get_character_by_glyph(g)),
		})
	nodes.sort_custom(func(a, b): return a["glyph"] < b["glyph"])
	var edges: Array = []
	for k in edges_map.keys():
		var p: PackedStringArray = str(k).split("|")
		edges.append({"a": p[0], "b": p[1]})
	return {"nodes": nodes, "edges": edges}


## 只保留最大连通分量（把【开灯】等孤立小岛挡在布局之外）
func _keep_largest(graph: Dictionary) -> Dictionary:
	var adj: Dictionary = {}
	for e in graph["edges"]:
		if not adj.has(e["a"]):
			adj[e["a"]] = []
		if not adj.has(e["b"]):
			adj[e["b"]] = []
		adj[e["a"]].append(e["b"])
		adj[e["b"]].append(e["a"])
	var seen: Dictionary = {}
	var best: Array = []
	for g in adj.keys():
		if seen.has(g):
			continue
		var stack: Array = [g]
		var comp: Array = []
		seen[g] = true
		while not stack.is_empty():
			var cur: String = stack.pop_back()
			comp.append(cur)
			for nb in adj[cur]:
				if not seen.has(nb):
					seen[nb] = true
					stack.append(nb)
		if comp.size() > best.size():
			best = comp
	var keep: Dictionary = {}
	for g2 in best:
		keep[g2] = true
	var nodes: Array = []
	for nd in graph["nodes"]:
		if keep.has(nd["glyph"]):
			nodes.append(nd)
	var edges: Array = []
	for e2 in graph["edges"]:
		if keep.has(e2["a"]) and keep.has(e2["b"]):
			edges.append(e2)
	return {"nodes": nodes, "edges": edges}


func _color(cd: CharacterData) -> String:
	if cd == null:
		return "#7c7360"
	var t: Array = cd.tags
	if t.has("heat"): return "#c9662e"
	if t.has("energy"): return "#c9a35a"
	if t.has("economy"): return "#5f7d6a"
	if t.has("defense"): return "#5f7f9a"
	if t.has("flow"): return "#3c4a6b"
	if t.has("space"): return "#7a4a63"
	if t.has("attack"): return "#8c2a20"
	if t.has("彩蛋"): return "#b8a06a"
	if t.has("enemy"): return "#7c7360"
	return "#4a4438"


func _layout(nodes: Array, edges: Array, w: int, h: int) -> void:
	var n := nodes.size()
	if n == 0:
		return
	var idx: Dictionary = {}
	for i in n:
		idx[nodes[i]["glyph"]] = i
		var ang := TAU * float(i) / float(n)
		nodes[i]["x"] = w * 0.5 + cos(ang) * min(w, h) * 0.3
		nodes[i]["y"] = h * 0.5 + sin(ang) * min(w, h) * 0.3
	var area := float(w * h)
	var k := sqrt(area / float(n))
	var temp: float = min(w, h) * 0.16
	for it in 300:
		var dx: Array = []
		var dy: Array = []
		dx.resize(n)
		dy.resize(n)
		dx.fill(0.0)
		dy.fill(0.0)
		for a in n:
			for b in range(a + 1, n):
				var ddx: float = nodes[a]["x"] - nodes[b]["x"]
				var ddy: float = nodes[a]["y"] - nodes[b]["y"]
				var d: float = max(0.01, sqrt(ddx * ddx + ddy * ddy))
				var f: float = k * k / d
				dx[a] += ddx / d * f
				dy[a] += ddy / d * f
				dx[b] -= ddx / d * f
				dy[b] -= ddy / d * f
		for e in edges:
			var a2: int = idx[e["a"]]
			var b2: int = idx[e["b"]]
			var ddx2: float = nodes[a2]["x"] - nodes[b2]["x"]
			var ddy2: float = nodes[a2]["y"] - nodes[b2]["y"]
			var d2: float = max(0.01, sqrt(ddx2 * ddx2 + ddy2 * ddy2))
			var f2: float = d2 * d2 / k
			dx[a2] -= ddx2 / d2 * f2
			dy[a2] -= ddy2 / d2 * f2
			dx[b2] += ddx2 / d2 * f2
			dy[b2] += ddy2 / d2 * f2
		for i in n:
			var l: float = max(0.01, sqrt(dx[i] * dx[i] + dy[i] * dy[i]))
			var lim: float = min(l, temp)
			nodes[i]["x"] += dx[i] / l * lim
			nodes[i]["y"] += dy[i] / l * lim
		temp *= 0.96
	# fit
	var minx := INF
	var miny := INF
	var maxx := -INF
	var maxy := -INF
	for nd in nodes:
		minx = min(minx, nd["x"])
		miny = min(miny, nd["y"])
		maxx = max(maxx, nd["x"])
		maxy = max(maxy, nd["y"])
	var margin := 60.0
	var spanx: float = max(1.0, maxx - minx)
	var spany: float = max(1.0, maxy - miny)
	var scale: float = min((w - margin * 2) / spanx, (h - margin * 2) / spany)
	for nd2 in nodes:
		nd2["x"] = margin + (nd2["x"] - minx) * scale
		nd2["y"] = margin + (nd2["y"] - miny) * scale
		nd2["r"] = clampf(16.0 + nd2["total"] * 2.0, 16.0, 40.0)


func _svg(graph: Dictionary, title: String, w: int, h: int) -> String:
	var nodes: Array = graph["nodes"]
	var edges: Array = graph["edges"]
	var idx: Dictionary = {}
	for nd in nodes:
		idx[nd["glyph"]] = nd
	var s := ""
	s += "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\">\n" % [w, h, w, h]
	s += "  <rect width=\"%d\" height=\"%d\" fill=\"#f4ecd8\"/>\n" % [w, h]
	s += "  <text x=\"30\" y=\"42\" font-family=\"Noto Serif SC, SimSun, serif\" font-size=\"24\" font-weight=\"bold\" fill=\"#221f1a\">%s</text>\n" % title
	s += "  <text x=\"30\" y=\"66\" font-family=\"Noto Serif SC, SimSun, serif\" font-size=\"14\" fill=\"#7c7360\">有向边 A→B：存在某个词，其中 A 紧接在 B 之前。节点大小=总度，颜色=所属体系。</text>\n"
	# 边
	for e in edges:
		var a: Dictionary = idx[e["a"]]
		var b: Dictionary = idx[e["b"]]
		var ax: float = a["x"]
		var ay: float = a["y"]
		var bx: float = b["x"]
		var by: float = b["y"]
		var ddx: float = bx - ax
		var ddy: float = by - ay
		var d: float = max(0.01, sqrt(ddx * ddx + ddy * ddy))
		var ux: float = ddx / d
		var uy: float = ddy / d
		var sx: float = ax + ux * a["r"]
		var sy: float = ay + uy * a["r"]
		var ex: float = bx - ux * (b["r"] + 2.0)
		var ey: float = by - uy * (b["r"] + 2.0)
		var col := "#9a8f79"
		s += "  <line x1=\"%.1f\" y1=\"%.1f\" x2=\"%.1f\" y2=\"%.1f\" stroke=\"%s\" stroke-width=\"1.6\" stroke-linecap=\"round\"/>\n" % [sx, sy, ex, ey, col]
		var px := -uy
		var py := ux
		var a_size := 7.0
		s += "  <polygon points=\"%.1f,%.1f %.1f,%.1f %.1f,%.1f\" fill=\"%s\"/>\n" % [
			ex, ey, ex - ux * a_size + px * a_size * 0.5, ey - uy * a_size + py * a_size * 0.5,
			ex - ux * a_size - px * a_size * 0.5, ey - uy * a_size - py * a_size * 0.5, col]
	# 节点
	for nd in nodes:
		var x: float = nd["x"]
		var y: float = nd["y"]
		var r: float = nd["r"]
		s += "  <circle cx=\"%.1f\" cy=\"%.1f\" r=\"%.1f\" fill=\"%s\" stroke=\"#f4ecd8\" stroke-width=\"1.6\"/>\n" % [x, y, r, nd["color"]]
		var fs: float = clampf(r * 1.05, 15.0, 30.0)
		s += "  <text x=\"%.1f\" y=\"%.1f\" text-anchor=\"middle\" font-family=\"Noto Serif SC, SimSun, serif\" font-size=\"%.0f\" fill=\"#f4ecd8\">%s</text>\n" % [
			x, y + fs * 0.36, fs, nd["glyph"]]
	s += "</svg>\n"
	return s
