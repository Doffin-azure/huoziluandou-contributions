extends Control
class_name GlyphGraphView
## 字网图谱视图：把词按相邻顺序画成有向图，节点大小=总度，颜色=所属体系。
## 点击节点可查看该字的出度/入度邻居。

signal node_selected(info: Dictionary)

const ITERATIONS := 260
const MARGIN := 70.0

var nodes: Array = []          ## [{glyph, out, in, wout, win, words, color, pos:Vector2, radius}]
var edges: Array = []          ## [{a:glyph, b:glyph, w:int}]
var _index: Dictionary = {}    ## glyph -> node
var selected := ""
var _hover := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func rebuild(words: Array, only_glyphs: Array = []) -> void:
	var out_adj: Dictionary = {}
	var in_adj: Dictionary = {}
	var edges_map: Dictionary = {}
	var word_count: Dictionary = {}
	var involved: Dictionary = {}

	for w in words:
		var gs: Array = w.glyphs
		for g in gs:
			if not only_glyphs.is_empty() and not only_glyphs.has(g):
				continue
			word_count[g] = int(word_count.get(g, 0)) + 1
			involved[g] = true
		for i in range(gs.size() - 1):
			var a := str(gs[i])
			var b := str(gs[i + 1])
			if not only_glyphs.is_empty() and (not only_glyphs.has(a) or not only_glyphs.has(b)):
				continue
			if not out_adj.has(a):
				out_adj[a] = {}
			if not in_adj.has(b):
				in_adj[b] = {}
			out_adj[a][b] = int(out_adj[a].get(b, 0)) + 1
			in_adj[b][a] = int(in_adj[b].get(a, 0)) + 1
			edges_map["%s|%s" % [a, b]] = int(edges_map.get("%s|%s" % [a, b], 0)) + 1
			involved[a] = true
			involved[b] = true

	nodes.clear()
	_index.clear()
	edges.clear()
	selected = ""

	var n: int = involved.size()
	var i := 0
	for g in involved.keys():
		var outs: Dictionary = out_adj.get(g, {})
		var ins: Dictionary = in_adj.get(g, {})
		var total: int = outs.size() + ins.size()
		var cd: CharacterData = Database.get_character_by_glyph(g)
		var angle := TAU * float(i) / float(max(1, n))
		var node := {
			"glyph": g,
			"out": outs.size(),
			"in": ins.size(),
			"wout": _sum(outs),
			"win": _sum(ins),
			"words": int(word_count.get(g, 0)),
			"color": _node_color(cd),
			"pos": Vector2(cos(angle), sin(angle)) * 260.0 + Vector2(320, 320),
			"radius": clampf(15.0 + total * 1.7, 15.0, 36.0),
		}
		nodes.append(node)
		_index[g] = node
		i += 1

	for k in edges_map.keys():
		var parts: PackedStringArray = str(k).split("|")
		edges.append({"a": parts[0], "b": parts[1], "w": int(edges_map[k])})

	_compute_layout()
	queue_redraw()


func _sum(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += int(d[k])
	return s


func _node_color(cd: CharacterData) -> Color:
	if cd == null:
		return Palette.INK_FAINT
	var t: Array = cd.tags
	if t.has("heat"):
		return Color("c9662e")
	if t.has("energy"):
		return Palette.GOLD
	if t.has("economy"):
		return Palette.JADE
	if t.has("defense"):
		return Palette.BLOCK
	if t.has("flow"):
		return Palette.INDIGO
	if t.has("space"):
		return Palette.PLUM
	if t.has("attack"):
		return Palette.VERMILION_DK
	if t.has("enemy"):
		return Palette.INK_FAINT
	return Palette.INK_SOFT


func _compute_layout() -> void:
	var n := nodes.size()
	if n <= 1:
		return
	var area: float = max(1.0, size.x) * max(1.0, size.y)
	if area < 100.0:
		area = 640.0 * 640.0
	var k: float = sqrt(area / float(n))
	var temp: float = size.x * 0.18 if size.x > 10.0 else 120.0
	for iter in ITERATIONS:
		var disp: Dictionary = {}
		for nd in nodes:
			disp[nd["glyph"]] = Vector2.ZERO
		# 斥力
		for a_i in n:
			for b_i in range(a_i + 1, n):
				var va: Vector2 = nodes[a_i]["pos"]
				var vb: Vector2 = nodes[b_i]["pos"]
				var delta: Vector2 = va - vb
				var d: float = max(0.01, delta.length())
				var force: float = k * k / d
				var dir: Vector2 = delta / d
				disp[nodes[a_i]["glyph"]] += dir * force
				disp[nodes[b_i]["glyph"]] -= dir * force
		# 引力
		for e in edges:
			var va2: Vector2 = _index[e["a"]]["pos"]
			var vb2: Vector2 = _index[e["b"]]["pos"]
			var delta2: Vector2 = va2 - vb2
			var d2: float = max(0.01, delta2.length())
			var force2: float = d2 * d2 / k
			var dir2: Vector2 = delta2 / d2
			disp[e["a"]] -= dir2 * force2
			disp[e["b"]] += dir2 * force2
		for nd2 in nodes:
			var d3: Vector2 = disp[nd2["glyph"]]
			var len: float = max(0.01, d3.length())
			nd2["pos"] += d3 / len * min(len, temp)
		temp *= 0.96
	_fit_to_canvas()


func _fit_to_canvas() -> void:
	var min_p := Vector2(1e9, 1e9)
	var max_p := Vector2(-1e9, -1e9)
	for nd in nodes:
		min_p = min_p.min(nd["pos"])
		max_p = max_p.max(nd["pos"])
	var span: Vector2 = max_p - min_p
	var avail: Vector2 = size - Vector2(MARGIN, MARGIN) * 2.0
	var scale: float = min(avail.x / max(1.0, span.x), avail.y / max(1.0, span.y))
	scale = min(scale, 1.6)
	for nd2 in nodes:
		nd2["pos"] = (nd2["pos"] - min_p) * scale + Vector2(MARGIN, MARGIN)


func _draw() -> void:
	if size.x < 10.0:
		return
	# 边
	for e in edges:
		var a: Dictionary = _index[e["a"]]
		var b: Dictionary = _index[e["b"]]
		var pa: Vector2 = a["pos"]
		var pb: Vector2 = b["pos"]
		var dir: Vector2 = (pb - pa).normalized()
		var start: Vector2 = pa + dir * a["radius"]
		var end: Vector2 = pb - dir * (b["radius"] + 2.0)
		var hl: bool = selected == e["a"] or selected == e["b"]
		var alpha: float = clampf(0.18 + e["w"] * 0.18, 0.15, 0.85)
		var col: Color = Palette.VERMILION if hl else Palette.INK_SOFT
		col.a = alpha if not hl else 0.9
		draw_line(start, end, col, 2.5 if hl else 1.4, true)
		# 箭头
		var perp := Vector2(-dir.y, dir.x)
		var size_a: float = 7.0 + min(4, e["w"]) * 0.8
		draw_polygon(PackedVector2Array([
			end, end - dir * size_a + perp * size_a * 0.5, end - dir * size_a - perp * size_a * 0.5
		]), PackedColorArray([col, col, col]))
	# 节点
	for nd in nodes:
		var p: Vector2 = nd["pos"]
		var r: float = nd["radius"]
		var is_sel: bool = selected == nd["glyph"]
		var is_hov: bool = _hover == nd["glyph"]
		if is_sel or is_hov:
			draw_circle(p, r + 5.0, Color(nd["color"].r, nd["color"].g, nd["color"].b, 0.28))
		draw_circle(p, r, nd["color"])
		draw_arc(p, r, 0, TAU, 32, Palette.PAPER * Color(1, 1, 1, 0.5), 1.5, true)
		var font: Font = Ink.serif
		var fs: int = int(clampf(r * 1.05, 14.0, 26.0))
		var tw := font.get_string_size(nd["glyph"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var ascent := font.get_ascent(fs)
		draw_string(font, p + Vector2(-tw * 0.5, ascent * 0.5 - fs * 0.06), nd["glyph"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.PAPER)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover = _node_at(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var g := _node_at(event.position)
		if not g.is_empty():
			selected = g
			node_selected.emit(info_for(g))
			queue_redraw()


func _node_at(p: Vector2) -> String:
	for nd in nodes:
		if nd["pos"].distance_to(p) <= nd["radius"] + 4.0:
			return nd["glyph"]
	return ""


func info_for(glyph: String) -> Dictionary:
	if not _index.has(glyph):
		return {}
	var nd: Dictionary = _index[glyph]
	var outs: Array = []
	var ins: Array = []
	for e in edges:
		if e["a"] == glyph:
			outs.append("%s%s" % [e["b"], ("×%d" % e["w"]) if e["w"] > 1 else ""])
		if e["b"] == glyph:
			ins.append("%s%s" % [e["a"], ("×%d" % e["w"]) if e["w"] > 1 else ""])
	outs.sort()
	ins.sort()
	return {
		"glyph": glyph,
		"out": nd["out"], "in": nd["in"], "wout": nd["wout"], "win": nd["win"],
		"words": nd["words"], "color": nd["color"],
		"out_list": outs, "in_list": ins,
	}


func select(glyph: String) -> void:
	selected = glyph
	node_selected.emit(info_for(glyph))
	queue_redraw()
