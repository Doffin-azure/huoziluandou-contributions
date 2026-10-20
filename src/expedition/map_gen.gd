extends RefCounted
class_name MapGen
## 游戏地图使用 garden_v2 园林布局；build/gen_proto 保留 HTML 原型的逐格对照。
## 伏兵领地、封印和远征时间规则在布局落位之后校验。
## 格子用整数 k = 行 * W + 列。

const W := 12
const H := 8
const N := W * H
const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
const P := {"inkLo": 0.15, "inkHi": 0.20, "vision": 2, "wakeLo": 10, "wakeHi": 14, "buffer": 4, "v0": 0.5, "acc": 0.01,
	"vmax": 1.0, "p0": 0.35, "pGrow": 0.05, "fightT": 2, "restT": 3, "ambT": 1, "maxDetour": 5, "minDeg": 2.7}
const INF := 1 << 30
## 主题：字池、明敌、首领字、两种机关。gate=周期开关，slow=多耗 1 步，slide=顺流滑行，stun=定住首领，flavor=只影响资源
const THEME_ORDER := ["墨池", "熔铸坊", "潮汐渠", "雷池"]
const THEMES := {
	"墨池": {"ink": "3b3530", "glyphs": "火力合重精强防护", "foes": ["爆", "冷", "急"], "boss": "墨", "mech": [
		{"g": "泉", "n": [2, 3], "kind": "flavor", "color": "2f6f8f", "desc": "墨泉：踩上去回 3 墨，一次性"},
		{"g": "纸", "n": [4, 6], "kind": "slow", "color": "c9b88a", "desc": "吸墨纸：经过要多耗 1 步，首领不受影响"}]},
	"熔铸坊": {"ink": "4a2f28", "glyphs": "火热炼铸金精重强", "foes": ["爆", "热", "甲"], "boss": "铸", "mech": [
		{"g": "焰", "n": [3, 5], "kind": "flavor", "color": "d2542a", "desc": "烈焰格：可以走，每次经过气血 −3"},
		{"g": "炉", "n": [1, 2], "kind": "flavor", "color": "8a3a1f", "desc": "熔炉：投两枚字袋里的字，换一枚稀有字；一次性"}]},
	"潮汐渠": {"ink": "2b3a45", "glyphs": "流回转清冷急分合", "foes": ["冷", "急", "流"], "boss": "潮", "mech": [
		{"g": "流", "n": [2, 3], "kind": "slide", "color": "3d7fb0", "desc": "水流：顺着箭头滑出去，不耗步；首领不能用"},
		{"g": "潮", "n": [2, 3], "kind": "gate", "cycle": [4, 4], "color": "5a7f9a", "desc": "涨潮格：开 4 步、淹 4 步，淹着时谁都过不去"}]},
	"雷池": {"ink": "2e2a3d", "glyphs": "电能充放蓄超力加", "foes": ["电", "爆", "急"], "boss": "雷", "mech": [
		{"g": "闸", "n": [2, 3], "kind": "gate", "cycle": [3, 3], "color": "6a5aa0", "desc": "电闸：开 3 步、关 3 步，关着时谁都过不去"},
		{"g": "桩", "n": [1, 2], "kind": "stun", "color": "c9a83a", "desc": "蓄电桩：首领醒着时踩上去，把它定住 3 步，一次性"}]},
}
## 远距离移动机关（原型里没有）：原型合格之后另摆，见 place_movers，不打乱原型的随机序列。潮汐渠用原有的水流。
## warp=成对传送（双向，可反复用），hoist=吊过一道墨渍墙（一次性），wire=沿导线到另一头（只在电闸开着的步通电）
const MOVERS := {
	"墨池": {"g": "渗", "kind": "warp", "color": "5b4a7a", "desc": "渗墨点：成对出现，踩上一个就从另一个冒出来，双向、可反复用，不耗步；首领不能用"},
	"熔铸坊": {"g": "吊", "kind": "hoist", "n": [2, 3], "color": "7a6a5a", "desc": "吊钩：把你吊过箭头前面的墨渍墙，一次性，不耗步；首领不能用"},
	"雷池": {"g": "线", "kind": "wire", "cycle": [3, 3], "color": "4a7ab0", "desc": "导线：踩一头立刻到另一头，只在电闸开着的那 3 步通电，不耗步；首领不能用"},
}
const SHAPES := [[[0, 0], [0, 1]], [[0, 0], [1, 0]], [[0, 0], [0, 1], [0, 2]], [[0, 0], [1, 0], [2, 0]], [[0, 0], [1, 0], [1, 1]],
	[[0, 0], [0, 1], [1, 0]], [[0, 0], [0, 1], [1, 1]], [[0, 1], [1, 0], [1, 1]], [[0, 0], [0, 1], [0, 2], [1, 1]],
	[[0, 0], [1, 0], [2, 0], [1, 1]], [[0, 0], [1, 0], [1, 1], [1, 2]]]
const CONTENT_TYPES := "大中小休市谜"
const GARDEN_BACKUPS := {
	"墨池":[1047301,2199392,9740107],"熔铸坊":[8273602,2304348],
	"潮汐渠":[2199314,1361488,733186,5132031],"雷池":[5969558,12148575,4608159,2304348]}


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


## 移动机关第 t 步能不能用：导线和电闸同相位（电闸开着时通电），其余总能用
static func mover_live(mc: Dictionary, t: int) -> bool:
	return mc.get("kind", "") != "wire" or (t % (mc.cycle[0] + mc.cycle[1])) < mc.cycle[0]


## 首领速度，e = 起身后过了几步；acc_scale 用于「更漏」「冷却」
## 只给生成器的初见模拟用（和 HTML 原型对齐，决定地图合不合格）；游戏里首领走不走见 Expedition.move_chance
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
	var garden: Dictionary = {}

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
			if not resv.has(k) and not garden.get("pocket_forbidden",{}).has(k) and ink[k] == 0 and MapGen.man(k, start) >= far:
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
			if resv.has(n) or keep.has(n) or garden.get("pocket_forbidden",{}).has(n):
				return false
		var alcoves: Array = []
		if not garden.is_empty():
			var source: Script = load("res://src/expedition/garden_layout.gd")
			alcoves = source.alcove_runs(cells,o)
			if not source.alcove_fits(garden,alcoves): return false
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
		if not garden.is_empty(): load("res://src/expedition/garden_layout.gd").register_alcove(garden,alcoves)
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
		if not garden.is_empty():
			start = int(garden.get("start",start))
			for k in MapGen.N:
				ink[k] = 1 if garden.terrain_base[k]!=0 and not garden.bridges.has(k) else 0
				if ink[k]!=0: pwall[k] = true
			resv.merge(garden.reserved)
			used.merge(garden.no_content)
		resv[start] = true
		for n in MapGen.nbrs(start):
			resv[n] = true
		# 大赏 1～2 个（深 2 格，口上站精英）、中赏 1～2 个（深 1 格）
		var n_big := 1 + R.ri(2)
		var n_mid := 1 + R.ri(2)
		if not garden.is_empty(): n_big = 1; n_mid = 1
		if not make_pocket(2, 7):
			return {"fail": "大赏凹槽放不下"}
		if n_big > 1 and not make_pocket(2, 6):
			return {"fail": "第二个大赏凹槽放不下"}
		for i in n_mid:
			if not make_pocket(1, 4):
				return {"fail": "中赏凹槽放不下"}
		# 墨渍团块：随机形状撒到 15%～20%，团块之间尽量留空隙
		var target := int(round(MapGen.N * (P.inkLo + R.next() * (P.inkHi - P.inkLo))))
		if not garden.is_empty(): target = 0
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
		if not garden.is_empty():
			# Keep upstream's random rim lair, but mount its building before
			# placing services so its full footprint participates in layout.
			lair_c = outside.filter(func(k): return free_cell(k) and MapGen.is_rim(k) and ds[k]>=MapGen.LAIR_MIN_PATH \
				and not pocket.has(k) and node.keys().all(func(x): return node[x].t not in ["大","险"] or MapGen.man(x,k)>=3))
			lair_c = MapGen.Rng.new(seed*4099+29).shuf(lair_c)
		if lair_c.is_empty():
			return {"fail": "首领巢穴没位置"}
		var lair: int = lair_c[0]
		for k in lair_c:
			if ds[k] > ds[lair]:
				lair = k
		var lair_node := {"t":"巢"}
		if not garden.is_empty():
			lair_node = {}
			for candidate: int in lair_c:
				lair_node = mounted_node(candidate,"巢")
				if not lair_node.is_empty(): lair = candidate; break
			if lair_node.is_empty(): return {"fail":"首领门阙没有安全占地"}
		put(lair,lair_node)
		var n_rest := 1 + R.ri(2)
		var n_shop := 1 + R.ri(2)
		if not garden.is_empty(): n_rest = 1; n_shop = 1
		if place_n("休", n_rest, 0.35, 0.85, outside, ds, max_d, lair) < 1:
			return {"fail": "休息点没位置"}
		if place_n("市", n_shop, 0.2, 0.7, outside, ds, max_d, lair) < 1:
			return {"fail": "商店没位置"}
		var smalls: Array = R.shuf(outside.filter(func(k): return free_cell(k) and ds[k] >= 3))
		for k in smalls.slice(0, 2 + R.ri(2)):
			put(k, {"t": "小"})
		var evs: Array = preferred_entries("谜",R.shuf(outside.filter(func(k): return free_cell(k) and ds[k] >= 4)))
		if not evs.is_empty():
			for k in evs:
				var event := mounted_node(k,"谜")
				if event.is_empty(): continue
				put(k,event)
				break
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
		if not garden.is_empty():
			load("res://src/expedition/garden_layout.gd").finalize(garden,ink)
			m["layout"] = garden
			m["generation_version"] = garden.version
			m["cuts"] = []
			var final_outside := outside_of()
			var final_mask := floor_mask()
			deg_sum = 0
			for k in final_outside:
				if k!=start and _cuts(final_mask,k,final_outside): m.cuts.append(k)
				for n in MapGen.nbrs(k):
					if ink[n]==0: deg_sum += 1
			avg_deg = float(deg_sum)/final_outside.size()
			m.avgDeg = avg_deg
			cuts = m.cuts
		var terr := {}
		for a in amb:
			terr[a] = a
		m["fog"] = MapGen.sim(m, "fog", true, terr)
		var got: int = m.fog.got
		m["pass"] = cuts.is_empty() and avg_deg >= (2.5 if not garden.is_empty() else P.minDeg) and detour <= P.maxDetour and amb.size() >= 3 \
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
		if not garden.is_empty():
			for slot in garden.get("facility_slots",{}).get(t,[]):
				var k: int = slot.entry
				if not cand.has(k) and free_cell(k) and ds[k]>=3 and MapGen.man(k,lair)>=3 and _spread(k): cand.append(k)
		for k in preferred_entries(t,R.shuf(cand)):
			if c >= n:
				break
			if not free_cell(k): continue
			var placed := mounted_node(k,t)
			if placed.is_empty(): continue
			placed["beacon"] = c==0
			put(k,placed)
			c += 1
		return c

	func preferred_entries(type: String, candidates: Array) -> Array:
		if garden.is_empty(): return candidates
		var result: Array = []
		for slot in garden.get("facility_slots",{}).get(type,[]):
			if candidates.has(slot.entry): result.append(slot.entry)
		for k in candidates:
			if not result.has(k): result.append(k)
		return result

	func mounted_node(k: int, type: String) -> Dictionary:
		if garden.is_empty(): return {"t":type}
		if garden.get("facility_reserved",{}).get(k,type)!=type: return {}
		var layout_source: Script = load("res://src/expedition/garden_layout.gd")
		var profiles: Script = load("res://src/expedition/garden_asset_layout.gd")
		var p := MapGen.rc(k)
		var bodies: Array[Vector2i] = []
		for slot in garden.get("facility_slots",{}).get(type,[]):
			if slot.entry==k: bodies.append(MapGen.rc(slot.body))
		for delta: Vector2i in [Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0)]:
			if not bodies.has(p+delta): bodies.append(p+delta)
		for q: Vector2i in bodies:
			if not MapGen.inb(q.x,q.y): continue
			var delta := q-p
			var body := MapGen.kk(q.x,q.y)
			var own_slot: bool = garden.get("facility_reserved",{}).get(body,"")==type
			if not free_cell(body) or (resv.has(body) and not own_slot) or MapGen.man(body,start)<=1: continue
			var at := Vector3(q.y+.5,0,q.x+.5)
			# Move edge facilities inward so eaves do not cut through the enclosure.
			if q.y==0: at.x += .30
			if q.y==MapGen.W-1: at.x -= .30
			if q.x==0: at.z += .30
			if q.x==MapGen.H-1: at.z -= .30
			var turn := atan2(-float(delta.y),-float(delta.x))
			if not layout_source.room_for(garden,profiles.envelope(type,at,turn)): continue
			ink[body] = 1
			if find_cut()!=-1:
				ink[body] = 0
				continue
			garden.terrain_base[body] = 2
			garden.no_ambush[body] = true
			resv[body] = true
			pwall[body] = true
			used[body] = true
			layout_source.register_facility(garden,type,at,turn,k)
			return {"t":type,"body_cell":body,"mount_offset":at-Vector3(p.y+.5,0,p.x+.5),"mount_turn":turn}
		return {}

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
## slide_n：水流滑几格；0 = 原型的一直滑到墙（只给原型对照用），游戏里是 SLIDE_N
## boss_seed：-1 = 原型的匀加速追击（地图初筛和对照测试用）；≥0 = 游戏里的概率追击（同 Expedition.tick），用这个种子掷骰
static func sim(m: Dictionary, mode: String, chase: bool, terr: Dictionary, slide_n := 0, boss_seed := -1) -> Dictionary:
	var S := {"pos": m.start, "t": 0, "boss": m.lair, "acc": 0.0, "stir": null, "rise": null, "stun": 0, "alarm": false,
		"known": {}, "got": 0, "taken": {}, "hp": 60, "used": {}, "miss": 0}
	var brng := RandomNumberGenerator.new()
	brng.seed = maxi(0, boss_seed)
	var content := {}
	for k in m.content:
		content[k] = true
	var tick := func() -> bool:
		S.t += 1
		if not chase:
			return false
		if S.stir == null and (S.t >= m.wake or S.alarm or bfs(pass_mask(m, S.t), m.lair)[S.pos] <= 2):
			S.stir = S.t
			S.rise = S.t + int(m.get("buffer", P.buffer))
		if S.rise == null or S.t < S.rise:
			return false
		if S.stun > 0:
			S.stun -= 1
			return false
		var bm := pass_mask(m, S.t, true)
		if boss_seed >= 0:
			var base := minf(1.0, P.p0 + P.pGrow * maxi(0, S.t - int(S.rise)))
			if brng.randf() < minf(1.0, base * (S.miss + 1)):
				S.miss = 0
				S.boss = step_toward(bm, S.boss, S.pos)
			else:
				S.miss += 1
		else:
			S.acc += spd(S.t - S.rise)
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
				var left: int = slide_n if slide_n > 0 else (SLIDE_N if m.has("layout") else INF)
				while left > 0 and inb(p.x + mc.dir.x, p.y + mc.dir.y) and pm[kk(p.x + mc.dir.x, p.y + mc.dir.y)] != 0:
					p += mc.dir
					left -= 1

				S.pos = kk(p.x, p.y)
			# 新机关每个只让模拟用一次，免得渗墨点来回弹
			if mc.kind in ["warp", "hoist", "wire"] and not S.used.has(nx) and mover_live(mc, S.t):
				S.used[nx] = true
				S.used[mc.to] = true
				S.pos = mc.to
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


## 游戏用：园林结构、内容、伏兵及初见节奏依次校验，失败时有旧图回退。
static func generate(seed_value: int, theme_name := "随机") -> Dictionary:
	var layout_source: Script = load("res://src/expedition/garden_layout.gd")
	var rejected: Dictionary = {}
	for i in 128:
		# Failed candidates must not make nearby requested seeds converge onto
		# the same first acceptable map.
		var candidate_seed := seed_value+i*104729
		var builder := Builder.new(candidate_seed,theme_name)
		# Layout has its own RNG and chooses a spawn in the entrance court.
		builder.garden = layout_source.plan(candidate_seed,builder.tn)
		var m := builder.run()
		if m.has("fail") or not m.pass:
			var reason: String = m.get("fail","路网或初见节奏未通过")
			rejected[reason] = int(rejected.get(reason,0))+1
			continue
		roll_wake(m)
		# Garden footprints already own the lair placement; add upstream movers
		# after that layout, without relocating its solid building onto a path.
		if place_movers(m) and assign_ambush(m):
			m["tries"] = i+1
			m["generation_report"] = {"requested_seed":seed_value,"attempts":i+1,"rejections":rejected,"kind":m.layout.kind}
			return m
		rejected["伏兵领地未通过"] = int(rejected.get("伏兵领地未通过",0))+1
	var courtyard_backup := _garden_backup(seed_value,theme_name,layout_source,rejected)
	if not courtyard_backup.is_empty(): return courtyard_backup
	var fallback := generate_legacy(seed_value,theme_name)
	if fallback.is_empty(): fallback = generate_legacy(11,theme_name)
	fallback["generation_version"] = "legacy_fallback"
	fallback["generation_report"] = {"requested_seed":seed_value,"attempts":128,"rejections":rejected,"fallback":true}
	return fallback


static func _garden_backup(requested: int, theme_name: String, layout_source: Script, rejected: Dictionary) -> Dictionary:
	var theme: String = theme_name if THEMES.has(theme_name) else Rng.new(requested).pick(THEME_ORDER)
	# Preserve variety in the random rim lair even when normal candidates run
	# out; presentation and gameplay still derive only from the requested seed.
	var seeds: Array = GARDEN_BACKUPS[theme]
	var seed_value: int = seeds[Rng.new(requested*4099+29).ri(seeds.size())]
	var builder := Builder.new(seed_value,theme)
	builder.garden = layout_source.plan(seed_value,theme,0)
	var map := builder.run()
	if map.has("fail") or not map.pass: return {}
	roll_wake(map)
	if not place_movers(map) or not assign_ambush(map): return {}
	map["tries"] = 129
	map["generation_report"] = {"requested_seed":requested,"attempts":129,"rejections":rejected,"kind":map.layout.kind,"curated_fallback":true}
	return map


static func generate_legacy(seed_value: int, theme_name := "随机") -> Dictionary:
	for i in 400:
		var m := build(seed_value + i, theme_name)
		if m.has("fail") or not m.pass:
			continue
		roll_wake(m)
		if relocate_lair(m) and place_movers(m) and assign_ambush(m):
			m["tries"] = i + 1
			return m
	return {}


## 游戏里首领的节奏：第 8～11 步自然惊动（这时首领棋子出现在地图上），再过 7～10 步起身开追。
## 原型（gen_proto / build 里的初筛）仍用 P.wakeLo～wakeHi 和 P.buffer，地图对照测试不受影响。
const WAKE_GAME := Vector2i(8, 11)
const BUFFER_GAME := Vector2i(7, 10)


## 用单独的随机数重抽醒来时间和缓冲，不动原型的随机序列
static func roll_wake(m: Dictionary) -> void:
	var R := Rng.new(int(m.seed) * 7919 + 13)
	m["wake"] = WAKE_GAME.x + R.ri(WAKE_GAME.y - WAKE_GAME.x + 1)
	m["buffer"] = BUFFER_GAME.x + R.ri(BUFFER_GAME.y - BUFFER_GAME.x + 1)


## 游戏用图复核初见拿量时掷几次首领骰子
const FOG_ROLLS := 6


## 游戏里水流滑几格（「流速」另加，见 Expedition._slide）
const SLIDE_N := 3


## 摆远距离移动机关（MOVERS）。用单独的随机数，放在首领巢穴之后、伏兵之前。
## 共同规则：机关格和落点都是外面的空地，不压内容、散字、墨障、别的机关、起点、凹槽和凹槽口，落点离巢穴至少 3 格；
## 机关格之间至少隔 1 格；值得用：落点沿路走要比直接到远（渗 ≥ 8 步，吊 ≥ 4 步，线比导线长 ≥ 3 步）。
## 不会跳进凹槽，所以大赏仍要从口上的精英身边进。主题没有新机关（潮汐渠）直接返回 true；摆不下返回 false 换下一张图。
static func place_movers(m: Dictionary) -> bool:
	if not MOVERS.has(m.tn):
		return true
	var R := Rng.new(int(m.seed) * 6151 + 41)
	var mv: Dictionary = MOVERS[m.tn]
	var mouth := {}
	for p in m.pockets:
		mouth[p.o] = true
	# land：能当落点；free：还能当机关格（和别的机关格隔 1 格）
	var land := func(k: int) -> bool:
		return m.ink[k] == 0 and not m.pocket.has(k) and not mouth.has(k) and not m.node.has(k) and not m.glyph.has(k) \
			and not m.obst.has(k) and not m.mech.has(k) and k != m.start and m.ds[k] < INF and man(k, m.lair) >= 3 \
			and not (m.has("layout") and m.layout.no_content.has(k)) \
			and not m.mech.values().any(func(o): return o.get("to", -1) == k)
	var free := func(k: int) -> bool:
		return land.call(k) and not m.mech.keys().any(func(x): return man(x, k) < 2)
	# 走路距离：墨障能冲开，算可走；关着的门不算
	var walk := mask_of(func(k): return m.ink[k] == 0 and not (m.mech.has(k) and m.mech[k].kind == "gate"))
	var cand: Array = R.shuf(range(N).filter(func(k): return free.call(k)))
	match mv.kind:
		"warp":
			for a in cand:
				var d := bfs(walk, a)
				for b in cand:
					if b != a and d[b] >= 8 and d[b] < INF and man(a, b) >= 5 and free.call(a) and free.call(b):
						_put_mover(m, mv, a, b)
						_put_mover(m, mv, b, a)
						return true
			return false
		"hoist":
			var want: int = mv.n[0] + R.ri(mv.n[1] - mv.n[0] + 1)
			var c := 0
			for k in cand:
				if c >= want:
					break
				if not free.call(k):
					continue
				var p := rc(k)
				var d := bfs(walk, k)
				for dir in R.shuf(DIRS):
					# 箭头前面是 1～2 格墨渍，再过去是落点
					var q: Vector2i = p + dir
					var wall := 0
					while wall < 2 and inb(q.x, q.y) and m.ink[kk(q.x, q.y)] != 0:
						wall += 1
						q += dir
					if wall == 0 or not inb(q.x, q.y):
						continue
					var to := kk(q.x, q.y)
					if not land.call(to) or d[to] < 4 or d[to] >= INF:
						continue
					var mc := _put_mover(m, mv, k, to)
					mc["dir"] = dir
					c += 1
					break
			return c >= mv.n[0]
		"wire":
			for a in cand:
				var d := bfs(walk, a)
				for b in cand:
					var dm := man(a, b)
					if b == a or dm < 4 or dm > 6 or d[b] >= INF or d[b] < dm + 3 or not free.call(a) or not free.call(b):
						continue
					# 导线：先横后竖（或反过来）拐一个弯，只画出来，不占格
					var pa := rc(a)
					var pb := rc(b)
					var path: Array = []
					var cur := pa
					var horiz_first := R.next() < 0.5
					for leg in 2:
						var along_c := horiz_first == (leg == 0)
						while (cur.y != pb.y) if along_c else (cur.x != pb.x):
							if along_c:
								cur.y += signi(pb.y - cur.y)
							else:
								cur.x += signi(pb.x - cur.x)
							if cur != pb:
								path.append(kk(cur.x, cur.y))
					_put_mover(m, mv, a, b)["path"] = path
					_put_mover(m, mv, b, a)["path"] = path
					m["wire_path"] = path
					return true
			return false
	return false


static func _put_mover(m: Dictionary, mv: Dictionary, k: int, to: int) -> Dictionary:
	var o: Dictionary = mv.duplicate(true)
	o["to"] = to
	m.mech[k] = o
	return o


## 首领巢穴离起点至少几步（沿可走的路算）。起点总在地图中部偏左，太大会把左半圈排除掉
const LAIR_MIN_PATH := 6


## 地图最外一圈的格
static func is_rim(k: int) -> bool:
	var p := rc(k)
	return p.x == 0 or p.y == 0 or p.x == H - 1 or p.y == W - 1


## 首领巢穴改到最外一圈的随机空地（原型把它放在离起点最远处，玩家很快就能猜到）。
## 条件：走得到；离起点至少 LAIR_MIN_PATH 步（沿路走）；不贴着大赏、休息点、商店；不压机关、墨障、散字、凹槽。
## 用单独的随机数（只看种子），不影响原型的其余排布；一个合格的格都没有就换下一张图。
static func relocate_lair(m: Dictionary) -> bool:
	var R := Rng.new(int(m.seed) * 4099 + 29)
	var mk := mask_of(func(k): return m.ink[k] == 0 and not m.obst.has(k) and not (m.mech.has(k) and m.mech[k].kind == "gate"))
	var d := bfs(mk, m.start)
	var keep_off: Array = []
	for k in m.node:
		if m.node[k].t in ["大", "休", "市", "险"]:
			keep_off.append(k)
	var cand: Array = []
	for k in N:
		if not is_rim(k) or m.ink[k] != 0 or m.pocket.has(k) or m.obst.has(k) or m.mech.has(k) or m.glyph.has(k):
			continue
		if k == m.start or (m.node.has(k) and m.node[k].t != "巢") or d[k] >= INF or d[k] < LAIR_MIN_PATH:
			continue
		if keep_off.any(func(x): return man(x, k) < 3):
			continue
		cand.append(k)
	if cand.is_empty():
		return false
	var lair: int = cand[R.ri(cand.size())]
	m.node.erase(m.lair)
	m.node[lair] = {"t": "巢"}
	m["lair"] = lair
	return true


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
		if m.mech[k].has("to"):
			forbid[m.mech[k].to] = true
	for k in m.obst:
		forbid[k] = true
	for k in m.get("layout",{}).get("no_ambush",{}): forbid[k] = true
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
	# 复核用游戏里的概率追击：掷 FOG_ROLLS 次取平均，m.fog.got 记平均值（四舍五入）
	var got := 0
	var last := {}
	for r in FOG_ROLLS:
		last = sim(m, "fog", true, terr, SLIDE_N, int(m.seed) * 31 + r)
		got += int(last.got)
	last.got = int(round(float(got) / FOG_ROLLS))
	m["fog"] = last
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
