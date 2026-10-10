extends Node
## 字网图谱分析：把 105 词按相邻顺序建成有向图（A→B 表示 A 后面能接 B 成词），
## 统计每个字的出度/入度（含去重度与加权度），并输出：
##   docs/glyph_graph_report.md   —— 表格报告
##   docs/glyph_graph.dot         —— Graphviz
##   docs/glyph_graph.mmd         —— Mermaid
##
## 运行：
##   godot --headless --path . res://src/tools/glyph_graph.tscn

const OUT_DIR := "res://docs"

var _scopes: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var all_words: Array = Database.words.values()
	var impl_words: Array = all_words.filter(func(w): return w.implemented)

	_scopes = [
		{"name": "全部 105 词", "words": all_words, "file": "all"},
		{"name": "已实现 82 词", "words": impl_words, "file": "implemented"},
		{"name": "初始字袋（9 种字 / 全部词）", "words": all_words, "file": "starter", "only_glyphs": ["击", "防", "回", "反", "破", "重", "流", "连", "御"]},
	]

	var md: Array[String] = []
	md.append("# 字网图谱（出度 / 入度）\n")
	md.append("> 有向边 `A → B`：存在某个词，其中 A 紧接在 B 之前（按连线顺序）。\n")
	md.append("> 去重度 = 不同邻居数；加权度 = 所有词里该相邻对出现的总次数。\n")
	for scope in _scopes:
		_analyze_scope(scope, md)
	_write_files(md)
	print("[glyph_graph] 已输出到 %s" % OUT_DIR)
	get_tree().quit()


func _analyze_scope(scope: Dictionary, md: Array[String]) -> void:
	var words: Array = scope["words"]
	var only: Array = scope.get("only_glyphs", [])
	var out_adj: Dictionary = {}
	var in_adj: Dictionary = {}
	var edges: Dictionary = {}
	var word_count: Dictionary = {}
	var involved: Dictionary = {}

	for w in words:
		var gs: Array = w.glyphs
		for g in gs:
			if not only.is_empty() and not only.has(g):
				continue
			word_count[g] = int(word_count.get(g, 0)) + 1
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
			out_adj[a][b] = int(out_adj[a].get(b, 0)) + 1
			in_adj[b][a] = int(in_adj[b].get(a, 0)) + 1
			edges["%s→%s" % [a, b]] = int(edges.get("%s→%s" % [a, b], 0)) + 1
			involved[a] = true
			involved[b] = true

	# 组装每个字的度
	var rows: Array = []
	for g in involved.keys():
		var outs: Dictionary = out_adj.get(g, {})
		var ins: Dictionary = in_adj.get(g, {})
		rows.append({
			"glyph": g,
			"out": outs.size(),
			"in": ins.size(),
			"wout": _sum(outs),
			"win": _sum(ins),
			"words": int(word_count.get(g, 0)),
			"outs": outs,
			"ins": ins,
		})
	rows.sort_custom(func(a, b):
		var da: int = a["out"] + a["in"]
		var db: int = b["out"] + b["in"]
		if da != db:
			return da > db
		return a["glyph"] < b["glyph"])

	md.append("\n---\n\n## %s\n" % scope["name"])
	md.append("- 参与字：%d　·　有向边：%d　·　字袋枚数：%d\n" % [rows.size(), edges.size(), words.size()])
	var iso: Array = []
	for g in rows:
		if g["out"] + g["in"] == 0:
			iso.append(g["glyph"])
	if not iso.is_empty():
		md.append("- 孤立字（无相邻成词）：%s\n" % " ".join(iso))

	md.append("\n| 字 | 出度 | 入度 | 总度 | 加权出 | 加权入 | 出现词数 | 后续字（出） | 前置字（入） |\n")
	md.append("|---|--:|--:|--:|--:|--:|--:|---|---|\n")
	for r in rows:
		md.append("| **%s** | %d | %d | %d | %d | %d | %d | %s | %s |\n" % [
			r["glyph"], r["out"], r["in"], r["out"] + r["in"], r["wout"], r["win"], r["words"],
			_edges_text(r["outs"], true), _edges_text(r["ins"], true)])

	# 边权排行
	var elist: Array = []
	for k in edges.keys():
		elist.append({"e": k, "w": edges[k]})
	elist.sort_custom(func(a, b): return a["w"] > b["w"] if a["w"] != b["w"] else a["e"] < b["e"])
	var top: Array[String] = []
	for i in min(30, elist.size()):
		top.append("%s(%d)" % [elist[i]["e"], elist[i]["w"]])
	md.append("\n**边权 Top：** %s\n" % "　".join(top))


func _sum(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += int(d[k])
	return s


func _edges_text(d: Dictionary, with_weight: bool) -> String:
	if d.is_empty():
		return "—"
	var items: Array = []
	for k in d.keys():
		items.append("%s%s" % [k, ("×%d" % d[k]) if with_weight and int(d[k]) > 1 else ""])
	items.sort()
	return "、".join(items)


func _write_files(md: Array[String]) -> void:
	var f := FileAccess.open(OUT_DIR.path_join("glyph_graph_report.md"), FileAccess.WRITE)
	f.store_string("\n".join(md))
	f.close()
	_write_dot()
	_write_mermaid()


func _collect_edges(words: Array, only: Array) -> Dictionary:
	var edges: Dictionary = {}
	var nodes: Dictionary = {}
	for w in words:
		var gs: Array = w.glyphs
		for g in gs:
			if only.is_empty() or only.has(g):
				nodes[g] = true
		for i in range(gs.size() - 1):
			var a := str(gs[i])
			var b := str(gs[i + 1])
			if not only.is_empty() and (not only.has(a) or not only.has(b)):
				continue
			edges["%s|%s" % [a, b]] = int(edges.get("%s|%s" % [a, b], 0)) + 1
			nodes[a] = true
			nodes[b] = true
	return {"edges": edges, "nodes": nodes}


func _write_dot() -> void:
	var words: Array = Database.words.values()
	var info := _collect_edges(words, [])
	var f := FileAccess.open(OUT_DIR.path_join("glyph_graph.dot"), FileAccess.WRITE)
	f.store_line("digraph glyph_network {")
	f.store_line("  rankdir=LR; node [shape=circle, fontname=\"Noto Serif SC\"];")
	for n in info["nodes"].keys():
		f.store_line("  \"%s\";" % n)
	for e in info["edges"].keys():
		var parts: PackedStringArray = str(e).split("|")
		f.store_line("  \"%s\" -> \"%s\" [label=\"%d\"];" % [parts[0], parts[1], info["edges"][e]])
	f.store_line("}")
	f.close()


func _write_mermaid() -> void:
	# 初始 9 字子图用 flowchart，避免全图过大
	var words: Array = Database.words.values()
	var starter := ["击", "防", "回", "反", "破", "重", "流", "连", "御"]
	var info := _collect_edges(words, starter)
	var f := FileAccess.open(OUT_DIR.path_join("glyph_graph.mmd"), FileAccess.WRITE)
	f.store_line("flowchart LR")
	for e in info["edges"].keys():
		var parts: PackedStringArray = str(e).split("|")
		var w: int = info["edges"][e]
		if w > 1:
			f.store_line("  %s -->|%d| %s" % [parts[0], w, parts[1]])
		else:
			f.store_line("  %s --> %s" % [parts[0], parts[1]])
	f.close()
