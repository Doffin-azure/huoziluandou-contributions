extends RefCounted
class_name MapGen
## 墨途远征地图生成（v0.3）：逐行移植 ni-h/work/mapgen-open.html 的 build / sim / gen，
## 同一种子与 HTML 原型生成同一张图（tests/expedition_test 校验）；伏兵领地与封印为 v0.3 补充规则。
## 格子用整数 k = 行 * W + 列。

const W := 12
const H := 8
const N := W * H
const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
const P := {"inkLo": 0.15, "inkHi": 0.20, "vision": 2, "wakeLo": 10, "wakeHi": 14, "buffer": 4, "v0": 0.5, "acc": 0.01,
	"vmax": 1.0, "fightT": 2, "restT": 3, "ambT": 1, "maxDetour": 5, "minDeg": 2.7}
const INF := 1 << 30
## 主题：字池、明敌、首领字、两种机关。gate=周期开关，slow=多耗 1 步，slide=顺流滑行，stun=定住首领，flavor=只影响资源
const THEME_ORDER := ["墨池", "熔铸坊", "潮汐渠", "雷池"]
const THEMES := {
	"墨池": {"ink": "3b3530", "glyphs": "火力合重精强防护", "foes": ["爆", "冷", "急"], "boss": "墨", "mech": [
		{"g": "泉", "n": [2, 3], "kind": "flavor", "color": "2f6f8f", "desc": "墨泉：踩上去回 3 墨，一次性"},
		{"g": "纸", "n": [4, 6], "kind": "slow", "color": "c9b88a", "desc": "吸墨纸：经过要多耗 1 步，首领不受影响"}]},
	"熔铸坊": {"ink": "4a2f28", "glyphs": "火热炼铸金精重强", "foes": ["爆", "热", "甲"], "boss": "铸", "mech": [
		{"g": "焰", "n": [3, 5], "kind": "flavor", "color": "d2542a", "desc": "烈焰格：可以走，每次经过气血 −3"},
		{"g": "炉", "n": [1, 2], "kind": "flavor", "color": "8a3a1f", "desc": "熔炉：投两个字熔成一个稀有字，一次性"}]},
	"潮汐渠": {"ink": "2b3a45", "glyphs": "流回转清冷急分合", "foes": ["冷", "急", "流"], "boss": "潮", "mech": [
		{"g": "流", "n": [2, 3], "kind": "slide", "color": "3d7fb0", "desc": "水流：顺着箭头滑出去，不耗步；首领不能用"},
		{"g": "潮", "n": [2, 3], "kind": "gate", "cycle": [4, 4], "color": "5a7f9a", "desc": "涨潮格：开 4 步、淹 4 步，淹着时谁都过不去"}]},
	"雷池": {"ink": "2e2a3d", "glyphs": "电能充放蓄超力加", "foes": ["电", "爆", "急"], "boss": "雷", "mech": [
		{"g": "闸", "n": [2, 3], "kind": "gate", "cycle": [3, 3], "color": "6a5aa0", "desc": "电闸：开 3 步、关 3 步，关着时谁都过不去"},
		{"g": "桩", "n": [1, 2], "kind": "stun", "color": "c9a83a", "desc": "蓄电桩：首领醒着时踩上去，把它定住 3 步，一次性"}]},
}
const SHAPES := [[[0, 0], [0, 1]], [[0, 0], [1, 0]], [[0, 0], [0, 1], [0, 2]], [[0, 0], [1, 0], [2, 0]], [[0, 0], [1, 0], [1, 1]],
	[[0, 0], [0, 1], [1, 0]], [[0, 0], [0, 1], [1, 1]], [[0, 1], [1, 0], [1, 1]], [[0, 0], [0, 1], [0, 2], [1, 1]],
	[[0, 0], [1, 0], [2, 0], [1, 1]], [[0, 0], [1, 0], [1, 1], [1, 2]]]
const CONTENT_TYPES := "大中小休市谜"


## mulberry32，与 HTML 原型逐位一致
class Rng:
	const M := 0xFFFFFFFF
	var a: int

	func _init(seed_value: int) -> void:
		a = seed_value & M

	static func imul(x: int, y: int) -> int:
		x &= M
		y &= M
		return (((((x >> 16) * y) & 0xFFFF) << 16) + (x & 0xFFFF) * y) & M

	func next() -> float:
		a = (a + 0x6D2B79F5) & M
		var t := imul(a ^ (a >> 15), 1 | a)
		t = ((t + imul(t ^ (t >> 7), 61 | t)) & M) ^ t
		return float(t ^ (t >> 14)) / 4294967296.0

	func ri(n: int) -> int:
		return int(floor(next() * n))

	func pick(arr: Array) -> Variant:
		return arr[ri(arr.size())]

	func shuf(arr: Array) -> Array:
		var out := arr.duplicate()
		for i in range(out.size() - 1, 0, -1):
			var j := ri(i + 1)
			var tmp = out[i]
			out[i] = out[j]
			out[j] = tmp
		return out


# ---------------------------------------------------------------- 网格工具
static func rc(k: int) -> Vector2i:
	return Vector2i(k / W, k % W)


static func kk(r: int, c: int) -> int:
	return r * W + c


static func inb(r: int, c: int) -> bool:
	return r >= 0 and r < H and c >= 0 and c < W


static var _nb: Array = []


static func nbrs(k: int) -> Array:
	if _nb.is_empty():
		for i in N:
			var p := rc(i)
			var out: Array = []
			for d in DIRS:
				if inb(p.x + d.x, p.y + d.y):
					out.append(kk(p.x + d.x, p.y + d.y))
			_nb.append(out)
	return _nb[k]


static func man(a: int, b: int) -> int:
	var x := rc(a)
	var y := rc(b)
	return absi(x.x - y.x) + absi(x.y - y.y)


## 可走掩码 mask[k] = 1/0；返回各格到 src 的步数（走不到为 INF）
static func bfs(mask: PackedByteArray, src: int) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(N)
	d.fill(INF)
	if mask[src] == 0:
		return d
	d[src] = 0
	var q := PackedInt32Array([src])
	var i := 0
	while i < q.size():
		var k := q[i]
		i += 1
		for n in nbrs(k):
			if d[n] == INF and mask[n] != 0:
				d[n] = d[k] + 1
				q.append(n)
	return d


static func step_toward(mask: PackedByteArray, from: int, to: int) -> int:
	var d := bfs(mask, to)
	var best := from
	for n in nbrs(from):
		if mask[n] != 0 and d[n] < d[best]:
			best = n
	return best


static func mask_of(pass_fn: Callable) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(N)
	for k in N:
		m[k] = 1 if pass_fn.call(k) else 0
	return m


## 机关在第 t 步是否挡路
static func shut(mc: Dictionary, t: int) -> bool:
	return mc.kind == "gate" and (t % (mc.cycle[0] + mc.cycle[1])) >= mc.cycle[0]


## 首领速度，e = 起身后过了几步；acc_scale 用于「更漏」「冷却」
static func spd(e: int, acc_scale := 1.0) -> float:
	return minf(P.vmax, P.v0 + P.acc * acc_scale * maxi(0, e))



# ---------------------------------------------------------------- 生成（移植 build）
## 返回地图字典；失败时 {"fail": 原因}
static func build(seed_value: int, theme_name := "随机") -> Dictionary:
	return Builder.new(seed_value, theme_name).run()


class Builder:
	var R: MapGen.Rng
	var seed: int
	var tn: String
	var TH: Dictionary
	var ink := PackedByteArray()
	var resv := {}
	var pocket := {}
	var pwall := {}
	var keep := {}
	var start := 0
	var pockets: Array = []
	var node := {}
	var used := {}
	var mech := {}
	var obst := {}
	var glyph := {}

	func _init(seed_value: int, theme_name: String) -> void:
		seed = seed_value
		R = MapGen.Rng.new(seed_value)
		tn = R.pick(MapGen.THEME_ORDER) if theme_name == "随机" or not MapGen.THEMES.has(theme_name) else theme_name
		TH = MapGen.THEMES[tn]
		ink.resize(MapGen.N)

	func fl(k: int) -> bool:
		return ink[k] == 0

	func free_cell(k: int) -> bool:
		return ink[k] == 0 and not used.has(k) and not pocket.has(k)

	## 奖励凹槽：U 形墨渍围出的死路，背靠地图边缘
	func make_pocket(depth: int, far: int) -> bool:
		var cs: Array = []
		for k in MapGen.N:
			if not resv.has(k) and ink[k] == 0 and MapGen.man(k, start) >= far:
				cs.append(k)
		cs = R.shuf(cs)
		for b in cs:
			var p := MapGen.rc(b)
			var dirs: Array = R.shuf(MapGen.DIRS).filter(func(d): return not MapGen.inb(p.x - d.x, p.y - d.y))
			for d in dirs:
				var cells: Array = [b]
				for i in range(1, depth):
					cells.append(MapGen.kk(p.x + d.x * i, p.y + d.y * i))
				var o_r: int = p.x + d.x * depth
				var o_c: int = p.y + d.y * depth
				if not MapGen.inb(o_r, o_c):
					continue
				var o := MapGen.kk(o_r, o_c)
				var bad := false
				for i in cells.size():
					var cp := Vector2i(p.x + d.x * i, p.y + d.y * i)
					if not MapGen.inb(cp.x, cp.y) or resv.has(cells[i]) or ink[cells[i]] != 0:
						bad = true
						break
				if bad:
					continue
				if not _try_walls(cells, o, depth):
					continue
				return true
		return false

	## 凹槽的墙不能挨着别的墙留出窄缝；通过则落墙并登记
	func _try_walls(cells: Array, o: int, depth: int) -> bool:
		var walls := {}
		for k in cells:
			for n in MapGen.nbrs(k):
				if not cells.has(n) and n != o:
					walls[n] = true
		for n in walls:
			if resv.has(n) or keep.has(n):
				return false
		var open_n := 0
		for n in MapGen.nbrs(o):
			if not walls.has(n) and not cells.has(n):
				open_n += 1
		if open_n < 2:
			return false
		for n in walls:
			ink[n] = 1
			pwall[n] = true
		for n in walls:
			for x in MapGen.nbrs(n):
				if not walls.has(x) and not cells.has(x):
					keep[x] = true
		for k in cells:
			resv[k] = true
			pocket[k] = true
		resv[o] = true
		for n in MapGen.nbrs(o):
			if not walls.has(n):
				resv[n] = true
		pockets.append({"b": cells[0], "cells": cells, "o": o, "depth": depth})
		return true

	func put(k: int, o: Dictionary) -> void:
		node[k] = o
		used[k] = true

	func floor_mask() -> PackedByteArray:
		var m := PackedByteArray()
		m.resize(MapGen.N)
		for k in MapGen.N:
			m[k] = 1 if ink[k] == 0 else 0
		return m

	func outside_of() -> Array:
		var out: Array = []
		for k in MapGen.N:
			if ink[k] == 0 and not pocket.has(k):
				out.append(k)
		return out

	## 走不到的空地，或「去掉它地图就断开」的咽喉格；没有则返回 -1
	func find_cut() -> int:
		var out := outside_of()
		var m := floor_mask()
		var d0 := MapGen.bfs(m, start)
		for k in out:
			if d0[k] == MapGen.INF:
				return k
		for k in out:
			if k != start and _cuts(m, k, out):
				return k
		return -1

	func _cuts(m: PackedByteArray, k: int, out: Array) -> bool:
		m[k] = 0
		var d := MapGen.bfs(m, start)
		m[k] = 1
		for n in out:
			if n != k and d[n] == MapGen.INF:
				return true
		return false

	func run() -> Dictionary:
		var wake: int = P.wakeLo + R.ri(P.wakeHi - P.wakeLo + 1)
		start = MapGen.kk(3 + R.ri(2), 2 + R.ri(2))
		resv[start] = true
		for n in MapGen.nbrs(start):
			resv[n] = true
		# 大赏 1～2 个（深 2 格，口上站精英）、中赏 1～2 个（深 1 格）
		var n_big := 1 + R.ri(2)
		var n_mid := 1 + R.ri(2)
		if not make_pocket(2, 7):
			return {"fail": "大赏凹槽放不下"}
		if n_big > 1 and not make_pocket(2, 6):
			return {"fail": "第二个大赏凹槽放不下"}
		for i in n_mid:
			if not make_pocket(1, 4):
				return {"fail": "中赏凹槽放不下"}
		# 墨渍团块：随机形状撒到 15%～20%，团块之间尽量留空隙
		var target := int(round(MapGen.N * (P.inkLo + R.next() * (P.inkHi - P.inkLo))))
		var guard := 0
		while ink.count(1) < target:
			guard += 1
			if guard > 400:
				break
			var sh: Array = R.pick(MapGen.SHAPES)
			var r0 := R.ri(MapGen.H)
			var c0 := R.ri(MapGen.W)
			var ks: Array = []
			var ok := true
			for off in sh:
				var r: int = r0 + off[0]
				var c: int = c0 + off[1]
				if not MapGen.inb(r, c) or resv.has(MapGen.kk(r, c)) or keep.has(MapGen.kk(r, c)):
					ok = false
					break
				ks.append(MapGen.kk(r, c))
			if not ok:
				continue
			# 原型：逐格检查，碰到挨着别的墨的格就掷一次骰（<0.7 放弃这团）
			var reject := false
			for k in ks:
				var touch := false
				for n in MapGen.nbrs(k):
					if ink[n] != 0 and not ks.has(n):
						touch = true
						break
				if touch and R.next() < 0.7:
					reject = true
					break
			if reject:
				continue
			for k in ks:
				ink[k] = 1
		# 修补：有连不通的空地或咽喉格，就在旁边擦掉一格墨渍（凹槽的墙不擦）
		var repairs := 0
		var bad := find_cut()
		while bad != -1 and repairs < 30:
			var cand: Array = []
			for k in MapGen.N:
				if ink[k] != 0 and not pwall.has(k) and MapGen.man(k, bad) <= 4:
					cand.append(k)
			cand = R.shuf(cand)
			if cand.is_empty():
				return {"fail": "凹槽的墙把通道堵窄了"}
			var best: int = cand[0]
			for k in cand:
				if MapGen.man(k, bad) < MapGen.man(best, bad):
					best = k
			ink[best] = 0
			repairs += 1
			bad = find_cut()
		var fm := floor_mask()
		var ds := MapGen.bfs(fm, start)
		var floor_k: Array = []
		for k in MapGen.N:
			if ink[k] == 0:
				floor_k.append(k)
				if ds[k] == MapGen.INF:
					return {"fail": "有空地连不通"}
		var outside := outside_of()
		var cuts: Array = []
		for k in outside:
			if k != start and _cuts(fm, k, outside):
				cuts.append(k)
		var deg_sum := 0
		for k in outside:
			for n in MapGen.nbrs(k):
				if ink[n] == 0:
					deg_sum += 1
		var avg_deg := float(deg_sum) / outside.size()
		# 放内容：每类的第一个是引导点（★），第二个不发光
		node[start] = {"t": "起"}
		used[start] = true
		var bigs: Array = pockets.filter(func(p): return p.depth == 2)
		var mids: Array = pockets.filter(func(p): return p.depth == 1)
		for i in bigs.size():
			put(bigs[i].b, {"t": "大", "beacon": i == 0})
			put(bigs[i].cells[1], {"t": "险"})
		for p in mids:
			put(p.b, {"t": "中"})
		var max_d := 0
		for k in floor_k:
			max_d = maxi(max_d, ds[k])
		var lair_c: Array = outside.filter(func(k): return free_cell(k) and bigs.all(func(p): return MapGen.man(k, p.b) >= 4) and MapGen.man(k, start) >= 8)
		if lair_c.is_empty():
			return {"fail": "首领巢穴没位置"}
		var lair: int = lair_c[0]
		for k in lair_c:
			if ds[k] > ds[lair]:
				lair = k
		put(lair, {"t": "巢"})
		var n_rest := 1 + R.ri(2)
		var n_shop := 1 + R.ri(2)
		if place_n("休", n_rest, 0.35, 0.85, outside, ds, max_d, lair) < 1:
			return {"fail": "休息点没位置"}
		if place_n("市", n_shop, 0.2, 0.7, outside, ds, max_d, lair) < 1:
			return {"fail": "商店没位置"}
		var smalls: Array = R.shuf(outside.filter(func(k): return free_cell(k) and ds[k] >= 3))
		for k in smalls.slice(0, 2 + R.ri(2)):
			put(k, {"t": "小"})
		var evs: Array = R.shuf(outside.filter(func(k): return free_cell(k) and ds[k] >= 4))
		if not evs.is_empty():
			put(evs[0], {"t": "谜"})
		var fi := 0
		for k in R.shuf(outside.filter(func(k): return free_cell(k) and ds[k] >= 3 and MapGen.man(k, lair) >= 3)):
			if fi >= 3:
				break
			var near := false
			for x in node:
				if (node[x].t == "敌" and MapGen.man(x, k) < 4) or MapGen.man(x, k) < 2:
					near = true
					break
			if near:
				continue
			put(k, {"t": "敌", "g": TH.foes[fi]})
			fi += 1
		# 伏击 3～6 个（原型位置；游戏内另按 v0.3 领地规则重排，见 assign_ambush）
		var n_amb := 3 + R.ri(4)
		var amb: Array = []
		for k in R.shuf(outside.filter(func(k): return free_cell(k) and ds[k] >= 3)):
			if amb.size() >= n_amb:
				break
			if amb.any(func(a): return MapGen.man(a, k) < 2):
				continue
			amb.append(k)
			used[k] = true
		# 主题机关：挡路类（gate）只放在「堵上也不会切断地图」的格子
		for mc in TH.mech:
			var n: int = mc.n[0] + R.ri(mc.n[1] - mc.n[0] + 1)
			var c := 0
			for k in R.shuf(outside.filter(func(k): return free_cell(k) and ds[k] >= 2)):
				if c >= n:
					break
				if mech.keys().any(func(x): return MapGen.man(x, k) < 2):
					continue
				var o: Dictionary = mc.duplicate(true)
				if mc.kind == "slide":
					var p := MapGen.rc(k)
					var dir = null
					for d in R.shuf(MapGen.DIRS):
						var L := 0
						var rr: int = p.x + d.x
						var c2: int = p.y + d.y
						while MapGen.inb(rr, c2) and ink[MapGen.kk(rr, c2)] == 0:
							L += 1
							rr += d.x
							c2 += d.y
						if L >= 3:
							dir = d
							break
					if dir == null:
						continue
					o["dir"] = dir
				mech[k] = o
				if mc.kind == "gate" and not still_ok(outside):
					mech.erase(k)
					continue
				used[k] = true
				c += 1
		for k in R.shuf(outside.filter(func(k): return free_cell(k))).slice(0, 8):
			glyph[k] = TH.glyphs[R.ri(TH.glyphs.length())]
			used[k] = true
		# 墨障：两团墨之间只剩一格的空隙，堵上它；放完全图仍连通
		for k in R.shuf(outside.filter(func(k): return free_cell(k) and not glyph.has(k))):
			if obst.size() >= 2:
				break
			var p := MapGen.rc(k)
			var gap := false
			for pair in [[Vector2i(0, 1), Vector2i(0, -1)], [Vector2i(1, 0), Vector2i(-1, 0)]]:
				var a: Vector2i = p + pair[0]
				var b: Vector2i = p + pair[1]
				if MapGen.inb(a.x, a.y) and MapGen.inb(b.x, b.y) and ink[MapGen.kk(a.x, a.y)] != 0 and ink[MapGen.kk(b.x, b.y)] != 0:
					gap = true
					break
			if not gap:
				continue
			obst[k] = true
			if not still_ok(outside):
				obst.erase(k)
				continue
			used[k] = true
		var content: Array = []
		for k in node:
			if MapGen.CONTENT_TYPES.contains(node[k].t):
				content.append(k)
		var pm := MapGen.mask_of(func(k): return ink[k] == 0 and not obst.has(k))
		var dp := MapGen.bfs(pm, start)
		var detour := -MapGen.INF
		for k in content:
			detour = maxi(detour, dp[k] - MapGen.man(k, start) - (2 if pocket.has(k) else 0))
		var m := {"seed": seed, "tn": tn, "TH": TH, "wake": wake, "ink": ink, "pocket": pocket, "pockets": pockets, "start": start,
			"node": node, "lair": lair, "amb": amb, "glyph": glyph, "obst": obst, "mech": mech, "ds": dp, "content": content,
			"cuts": cuts, "avgDeg": avg_deg, "detour": detour, "inkPct": int(round(ink.count(1) * 100.0 / MapGen.N)),
			"count": {"大": bigs.size(), "中": mids.size(), "休": n_rest, "市": n_shop, "伏": amb.size()}}
		var terr := {}
		for a in amb:
			terr[a] = a
		m["fog"] = MapGen.sim(m, "fog", true, terr)
		var got: int = m.fog.got
		m["pass"] = cuts.is_empty() and avg_deg >= P.minDeg and detour <= P.maxDetour and amb.size() >= 3 \
			and got >= 0.45 * content.size() and got <= 0.75 * content.size()
		return m

	func blocks(k: int) -> bool:
		return ink[k] != 0 or obst.has(k) or (mech.has(k) and mech[k].kind == "gate")

	func still_ok(outside: Array) -> bool:
		var m := MapGen.mask_of(func(n): return not blocks(n))
		var d := MapGen.bfs(m, start)
		for x in node:
			if d[x] == MapGen.INF:
				return false
		for n in outside:
			if not blocks(n) and d[n] == MapGen.INF:
				return false
		return true

	func place_n(t: String, n: int, lo: float, hi: float, outside: Array, ds: PackedInt32Array, max_d: int, lair: int) -> int:
		var c := 0
		var cand: Array = outside.filter(func(k): return free_cell(k) and ds[k] >= lo * max_d and ds[k] <= hi * max_d and MapGen.man(k, lair) >= 3 and _spread(k))
		for k in R.shuf(cand):
			if c >= n:
				break
			put(k, {"t": t, "beacon": c == 0})
			c += 1
		return c

	func _spread(k: int) -> bool:
		for x in node:
			if node[x].t != "起" and MapGen.man(x, k) < 3:
				return false
		return true


# ---------------------------------------------------------------- 模拟（移植 sim）
## 玩家可走：非墨渍、非墨障、机关未关；首领可走：非墨渍、机关未关（墨障挡不住首领）
static func pass_mask(m: Dictionary, t: int, boss := false) -> PackedByteArray:
	var mk := PackedByteArray()
	mk.resize(N)
	for k in N:
		var ok: bool = m.ink[k] == 0 and (boss or not m.obst.has(k))
		if ok and m.mech.has(k) and shut(m.mech[k], t):
			ok = false
		mk[k] = 1 if ok else 0
	return mk


## fog = 初见玩家（只看见身边 2 步，朝引导点走，躲首领）；omni = 熟图玩家；chase=false 时首领不动
## terr：格 → 伏兵编号（走进领地任一格即触发该伏兵）
static func sim(m: Dictionary, mode: String, chase: bool, terr: Dictionary) -> Dictionary:
	var S := {"pos": m.start, "t": 0, "boss": m.lair, "acc": 0.0, "stir": null, "rise": null, "stun": 0, "alarm": false,
		"known": {}, "got": 0, "taken": {}, "hp": 60, "used": {}}
	var content := {}
	for k in m.content:
		content[k] = true
	var tick := func() -> bool:
		S.t += 1
		if not chase:
			return false
		if S.stir == null and (S.t >= m.wake or S.alarm or bfs(pass_mask(m, S.t), m.lair)[S.pos] <= 2):
			S.stir = S.t
			S.rise = S.t + P.buffer
		if S.rise == null or S.t < S.rise:
			return false
		if S.stun > 0:
			S.stun -= 1
			return false
		S.acc += spd(S.t - S.rise)
		var bm := pass_mask(m, S.t, true)
		while S.acc >= 1:
			S.acc -= 1
			S.boss = step_toward(bm, S.boss, S.pos)
		return bfs(bm, S.boss)[S.pos] <= 1
	for g in 400:
		var pm := pass_mask(m, S.t)
		if mode == "fog":
			var dv := bfs(pm, S.pos)
			for k in N:
				if dv[k] <= P.vision:
					S.known[k] = true
					for n in nbrs(k):
						S.known[n] = true
		var awake: bool = S.rise != null and S.t >= S.rise
		var dB := bfs(pass_mask(m, S.t, true), S.boss) if awake else PackedInt32Array()
		var kp := PackedByteArray()
		kp.resize(N)
		for k in N:
			var near_boss: bool = awake and dB[k] <= 2
			var ok: bool = pm[k] != 0 if (mode == "omni" or S.known.has(k)) else true
			kp[k] = 1 if (ok and not near_boss) else 0
		var dk := bfs(kp, S.pos)
		var tg := -1
		for k in N:
			if content.has(k) and not S.taken.has(k) and (mode == "omni" or S.known.has(k) or m.node[k].get("beacon", false)) \
					and dk[k] < INF and (tg == -1 or dk[k] < dk[tg]):
				tg = k
		if tg == -1 and mode == "fog":
			for k in N:
				if S.known.has(k) and pm[k] != 0 and nbrs(k).any(func(n): return not S.known.has(n)) and dk[k] < INF and (tg == -1 or dk[k] < dk[tg]):
					tg = k
		var nx: int
		if tg == -1:
			if not content.keys().any(func(k): return not S.taken.has(k)):
				break
			var opts: Array = nbrs(S.pos).filter(func(n): return pm[n] != 0)
			if awake:
				opts = _stable_desc(opts, dB)
			nx = opts[0] if not opts.is_empty() else S.pos
		else:
			nx = step_toward(kp, S.pos, tg)
		if nx == S.pos:
			if tick.call():
				return {"got": S.got, "t": S.t, "caught": true, "hp": S.hp}
			continue
		if pm[nx] == 0:
			S.known[nx] = true
			continue
		S.pos = nx
		var cost := 1
		var mc: Dictionary = m.mech.get(nx, {})
		if not mc.is_empty():
			if mc.kind == "slow":
				cost += 1
			if mc.g == "焰":
				S.hp -= 3
			if mc.kind == "stun" and S.rise != null and S.t >= S.rise and not S.used.has(nx):
				S.used[nx] = true
				S.stun = 3
			if mc.kind == "slide" and not S.used.has(nx):
				S.used[nx] = true
				var p := rc(S.pos)
				while inb(p.x + mc.dir.x, p.y + mc.dir.y) and pm[kk(p.x + mc.dir.x, p.y + mc.dir.y)] != 0:
					p += mc.dir
				S.pos = kk(p.x, p.y)
		var at: int = S.pos
		var o: Dictionary = m.node.get(at, {})
		if not o.is_empty() and (o.t == "敌" or o.t == "险") and not S.taken.has(at):
			S.taken[at] = true
			cost += P.fightT
		if terr.has(at) and not S.taken.has("amb%d" % terr[at]):
			S.taken["amb%d" % terr[at]] = true
			cost += P.ambT
			S.hp -= 6
		if content.has(at) and not S.taken.has(at):
			S.taken[at] = true
			S.got += 1
			if o.t == "休":
				cost += P.restT
			if o.t == "大":
				S.alarm = true
		for i in cost:
			if tick.call():
				return {"got": S.got, "t": S.t, "caught": true, "hp": S.hp, "stir": S.stir, "rise": S.rise}
	return {"got": S.got, "t": S.t, "caught": false, "hp": S.hp, "stir": S.stir, "rise": S.rise}


## 按 key 降序的稳定排序（等同 V8 对小数组的稳定插入排序）
static func _stable_desc(arr: Array, key: PackedInt32Array) -> Array:
	var out: Array = []
	for x in arr:
		var i := out.size()
		while i > 0 and key[out[i - 1]] < key[x]:
			i -= 1
		out.insert(i, x)
	return out


# ---------------------------------------------------------------- 选图
## 原型的 gen：从 seed 起逐个试，取第一张合格的图（伏击位置同原型，用于对照测试）
static func gen_proto(seed_value: int, theme_name := "随机") -> Dictionary:
	for i in 400:
		var m := build(seed_value + i, theme_name)
		if not m.has("fail") and m.pass:
			m["tries"] = i + 1
			return m
	return {}


## 游戏用：原型合格之后，再按 v0.3 规则排伏兵领地并复核初见模拟
static func generate(seed_value: int, theme_name := "随机") -> Dictionary:
	for i in 400:
		var m := build(seed_value + i, theme_name)
		if m.has("fail") or not m.pass:
			continue
		if assign_ambush(m):
			m["tries"] = i + 1
			return m
	return {}


## v0.3 伏兵：领地 = 所在格 + 上下左右；领地里的小赏 / 谜 / 散字被「封」；
## 领地不重叠，不盖起点、引导点、凹槽口、休息点、商店；把领地当墙仍走得到首领和所有引导点。
static func assign_ambush(m: Dictionary) -> bool:
	var R := Rng.new(int(m.seed) * 7919 + 17)
	var forbid := {m.start: true, m.lair: true}
	for k in m.node:
		var t: String = m.node[k].t
		if m.node[k].get("beacon", false) or t in ["休", "市", "敌", "险", "巢", "大", "中"]:
			forbid[k] = true
	for p in m.pockets:
		forbid[p.o] = true
	for k in m.mech:
		forbid[k] = true
	for k in m.obst:
		forbid[k] = true
	var target := 3 + R.ri(4)
	var ambs: Array = []
	var terr := {}
	var is_floor := func(k): return m.ink[k] == 0 and not m.pocket.has(k)
	var cand: Array = []
	for k in N:
		if is_floor.call(k) and not m.node.has(k) and not m.glyph.has(k) and not forbid.has(k) and m.ds[k] >= 3:
			cand.append(k)
	for a in R.shuf(cand):
		if ambs.size() >= target:
			break
		if ambs.any(func(x): return man(x.k, a) < 4):
			continue
		var cells: Array = [a]
		for n in nbrs(a):
			if is_floor.call(n):
				cells.append(n)
		var sealed: Array = []
		var ok := true
		for c in cells:
			if forbid.has(c) or terr.has(c):
				ok = false
				break
			if (m.node.has(c) and m.node[c].t in ["小", "谜"]) or m.glyph.has(c):
				sealed.append(c)
		if not ok or sealed.size() < 1 or sealed.size() > 2:
			continue
		for c in cells:
			terr[c] = ambs.size()
		if not _reach_ok(m, terr):
			for c in cells:
				terr.erase(c)
			continue
		ambs.append({"k": a, "cells": cells, "sealed": sealed})
	if ambs.size() < 3:
		return false
	m["amb"] = ambs.map(func(x): return x.k)
	m["ambush"] = ambs
	m["terr"] = terr
	m["fog"] = sim(m, "fog", true, terr)
	var n := float(m.content.size())
	return m.fog.got >= 0.45 * n and m.fog.got <= 0.75 * n


## 把所有领地当墙，起点仍走得到首领和所有引导点
static func _reach_ok(m: Dictionary, terr: Dictionary) -> bool:
	var mk := mask_of(func(k): return m.ink[k] == 0 and not m.obst.has(k) and not terr.has(k) and not (m.mech.has(k) and m.mech[k].kind == "gate"))
	var d := bfs(mk, m.start)
	if d[m.lair] >= INF:
		return false
	for k in m.node:
		if m.node[k].get("beacon", false) and d[k] >= INF:
			return false
	return true
