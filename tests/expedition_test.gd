extends Node
## 墨途远征 v0.3：地图生成对照原型 / 伏兵领地约束 / 词谱 / 迷雾与首领追逐 / 拾字与字匣 / 赏 / 休息 / 商店 /
## 战斗开场效果 / 战后与幕间 / 界面往返

var _pass := 0
var _fail := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(condition: bool, description: String) -> void:
	if condition:
		_pass += 1
		print("  ✓ ", description)
	else:
		_fail += 1
		push_error(description)


func _run() -> void:
	_test_parity()
	_test_generate()
	_test_movers()
	_test_lexicon()
	_test_start_and_move()
	_test_boss()
	_test_glyphs_and_tray()
	_test_plate()
	_test_loot_rest_shop()
	_test_battle_setup()
	_test_finish_and_acts()
	_test_autoplay()
	await _test_screens()
	print("[expedition_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _fresh(seed := 42) -> Expedition:
	var ex := Expedition.start(seed)
	return ex


## 首领刚起身、第 e 步、连续没走 miss 步时的走路概率
func _fresh_chance(e: int, miss: int) -> float:
	var ex := Expedition.start(1)
	ex.stir = 0
	ex.rise = 0
	ex.t = e
	ex.miss = miss
	return ex.move_chance()


## 地图上第一个满足条件的格
func _find(ex: Expedition, pred: Callable) -> int:
	for k in MapGen.N:
		if pred.call(k):
			return k
	return -1


func _set_words(ex: Expedition, words: Array) -> void:
	ex.active = {}
	for w in words:
		ex.active[w] = []


# ---------------------------------------------------------------- 地图生成
## 远距离移动机关：每个主题都有；位置规则 + 游戏里的效果
func _test_movers() -> void:
	var why := ""
	for tn in MapGen.THEME_ORDER:
		for s in [3, 17, 29, 41, 55, 68]:
			var m := MapGen.generate(s, tn)
			if m.is_empty():
				why = "%s/%d 生成失败" % [tn, s]
				continue
			var mv: Array = m.mech.keys().filter(func(k): return m.mech[k].kind in ["warp", "hoist", "wire", "slide"])
			var n_by := {"warp": 2, "wire": 2}
			var kind: String = "slide" if tn == "潮汐渠" else MapGen.MOVERS[tn].kind
			var count := mv.filter(func(k): return m.mech[k].kind == kind).size()
			if (kind in n_by and count != n_by[kind]) or count < 2 or count > 3:
				why = "%s/%d %s 有 %d 个" % [tn, s, kind, count]
			var mouth := {}
			for p in m.pockets:
				mouth[p.o] = true
			var walk := MapGen.mask_of(func(k): return m.ink[k] == 0 and not (m.mech.has(k) and m.mech[k].kind == "gate"))
			for k in mv:
				var mc: Dictionary = m.mech[k]
				if not mc.has("to"):
					continue
				var to: int = mc.to
				var bad: bool = m.ink[to] != 0 or m.pocket.has(to) or mouth.has(to) or m.node.has(to) or m.obst.has(to) 					or m.get("terr", {}).has(to) or m.get("terr", {}).has(k) or to == m.start or MapGen.man(to, m.lair) < 3
				if bad:
					why = "%s/%d 落点 %d 压住了禁区" % [tn, s, to]
				var d := MapGen.bfs(walk, k)[to]
				var need: int = {"warp": 8, "hoist": 4, "wire": MapGen.man(k, to) + 3}[mc.kind]
				if d < need or d >= MapGen.INF:
					why = "%s/%d %s 不值得用：走路 %d 步" % [tn, s, mc.g, d]
				if mc.kind in ["warp", "wire"] and m.mech.get(to, {}).get("to", -1) != k:
					why = "%s/%d %s 不成对" % [tn, s, mc.g]
	_ok(why.is_empty(), "每个主题都有远距离移动机关：数量对、成对、值得用、落点不压起点 / 凹槽 / 内容 / 伏兵 / 巢穴旁 %s" % why)
	# 游戏里的效果
	var ex := _fresh(7)
	ex.m = MapGen.generate(17, "墨池")
	var a := _find(ex, func(k): return ex.mech_at(k).get("g", "") == "渗")
	ex.pos = a
	_ok(ex._step_mech() == 0 and ex.pos == ex.m.mech[a].to, "渗墨点：传到另一个，不耗步")
	ex.pos = ex.m.mech[a].to
	ex._step_mech()
	_ok(ex.pos == a, "渗墨点：双向，可反复用")
	ex.m = MapGen.generate(17, "熔铸坊")
	var h := _find(ex, func(k): return ex.mech_at(k).get("g", "") == "吊")
	var hd: Vector2i = ex.m.mech[h].dir
	var over: Vector2i = MapGen.rc(h) + hd
	ex.used.clear()
	ex.pos = h
	ex._step_mech()
	_ok(ex.pos == ex.m.mech[h].to and ex.m.ink[MapGen.kk(over.x, over.y)] != 0, "吊钩：吊过箭头前面的墨渍墙")
	ex.pos = h
	ex._step_mech()
	_ok(ex.pos == h, "吊钩：一次性")
	ex.m = MapGen.generate(17, "雷池")
	_set_words(ex, [])
	var w := _find(ex, func(k): return ex.mech_at(k).get("g", "") == "线")
	ex.pos = w
	ex.t = 0
	ex._step_mech()
	_ok(ex.pos == ex.m.mech[w].to, "导线：电闸开着的步通电，到另一头")
	ex.pos = w
	ex.t = 4
	ex._step_mech()
	_ok(ex.pos == w, "导线：电闸关着的步没电，原地不动")
	_set_words(ex, ["停电"])
	ex._step_mech()
	_ok(ex.pos == ex.m.mech[w].to, "停电：导线一直通电")
	_ok(not ex.m.get("wire_path", []).is_empty(), "导线：有画出来的连线")
	# 首领不能用：首领的可走掩码里机关只看开关，不会因为机关跳格
	var bm := ex.boss_mask()
	_ok(MapGen.step_toward(bm, w, ex.m.mech[w].to) != ex.m.mech[w].to or MapGen.man(w, ex.m.mech[w].to) == 1, "首领不能用导线")


func _test_parity() -> void:
	var ref: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/mapgen_proto.json"))
	var same := 0
	for r in ref:
		var m := MapGen.gen_proto(int(r.seed), r.th)
		var ink := ""
		for k in MapGen.N:
			ink += str(m.ink[k])
		var nodes := {}
		for k in m.node:
			nodes[str(k)] = m.node[k].t + ("*" if m.node[k].get("beacon", false) else "") + m.node[k].get("g", "")
		var mech := {}
		for k in m.mech:
			mech[str(k)] = m.mech[k].g + ("%d,%d" % [m.mech[k].dir.x, m.mech[k].dir.y] if m.mech[k].has("dir") else "")
		var glyph := {}
		for k in m.glyph:
			glyph[str(k)] = m.glyph[k]
		var obst: Array = m.obst.keys()
		obst.sort()
		if m.tries == int(r.tries) and m.tn == r.tn and m.wake == int(r.wake) and m.start == int(r.start) and m.lair == int(r.lair) \
				and ink == r.ink and _norm(nodes) == _norm(r.node) and str(m.amb) == str(r.amb.map(func(x): return int(x))) \
				and _norm(glyph) == _norm(r.glyph) and str(obst) == str(r.obst.map(func(x): return int(x))) and _norm(mech) == _norm(r.mech) \
				and m.fog.got == int(r.fogGot) and m.fog.t == int(r.fogT):
			same += 1
	_ok(same == ref.size(), "地图生成与 HTML 原型逐格一致：%d/%d 张（四个主题 × 多个种子）" % [same, ref.size()])


func _norm(d: Dictionary) -> String:
	var ks: Array = d.keys().map(func(x): return int(x))
	ks.sort()
	return ",".join(ks.map(func(k): return "%d=%s" % [k, str(d[str(k)])]))


func _test_generate() -> void:
	var a := MapGen.generate(5, "雷池")
	var b := MapGen.generate(5, "雷池")
	_ok(not a.is_empty() and str(a.ink) == str(b.ink) and str(a.amb) == str(b.amb), "同一种子生成同一张图（含伏兵）")
	var ok_all := true
	var why := ""
	for s in [1, 2, 3, 4, 5, 6]:
		var m := MapGen.generate(s * 31)
		var ambs: Array = m.ambush
		if ambs.size() < 3 or ambs.size() > 6:
			ok_all = false
			why = "伏兵数 %d" % ambs.size()
		var seen := {}
		for a2 in ambs:
			if a2.sealed.size() < 1 or a2.sealed.size() > 2:
				ok_all = false
				why = "封 %d 个" % a2.sealed.size()
			for c in a2.cells:
				if seen.has(c) or c == m.start or (m.node.has(c) and (m.node[c].get("beacon", false) or m.node[c].t in ["休", "市"])):
					ok_all = false
					why = "领地重叠或盖住禁区"
				seen[c] = true
		if not MapGen._reach_ok(m, m.terr):
			ok_all = false
			why = "领地当墙后走不到首领 / 引导点"
		var n: float = m.content.size()
		if m.fog.got < 0.45 * n or m.fog.got > 0.75 * n:
			ok_all = false
			why = "初见玩家拿到 %d/%d" % [m.fog.got, n]
	_ok(ok_all, "伏兵领地：3～6 个、各封 1～2 个奖励、不重叠、不盖禁区、可绕开；初见模拟 45%%～75%% %s" % why)


func _test_lexicon() -> void:
	var w2: Dictionary = Lexicon.scan([["加", "速"], ["急", "停"]]).words
	_ok(w2.has("加速") and w2.has("急停") and w2.has("加急") and w2.size() == 3, "2×2「加速 / 急停」= 加速、急停、加急 %s" % [w2.keys()])
	var w3: Dictionary = Lexicon.scan([["加", "急", ""], ["速", "停", "火"], ["", "精", "力"]]).words
	_ok(w3.size() == 6 and w3.has("停火") and w3.has("火力") and w3.has("精力"), "3×3「加急· / 速停火 / ·精力」6 个词全部生效 %s" % [w3.keys()])
	_ok(Lexicon.longest_in(["复", "利", "投", "资"]).w == "复利投资", "每条线只取最长的词谱词")
	_ok(Lexicon.scan([["防", "火"], ["防", "火"]]).words.size() == 1, "同一个词摆两遍也只生效一次")
	_ok(Lexicon.WORDS.size() == 61, "词谱 61 个词")


func _test_start_and_move() -> void:
	var ex := _fresh()
	var ex_deck := GameState.glyph_counts()
	GameState.start_new_run("v03")
	var main_deck := GameState.glyph_counts()
	ex = _fresh()
	_ok(ex_deck == main_deck, "远征的战斗字袋 = 标准主线默认起始字袋（v03）")
	_ok(GameState.expedition == ex and GameState.deck_size() == 12 and ex.tray.is_empty() and ex.plate_n == 2 and ex.ink == Expedition.START_INK, "开局：字袋 12、字匣空、版面 2×2")
	_ok(ex.themes.size() == 4 and ex.m.tn == ex.themes[0] and ex.explored.has(ex.m.start), "三幕主题不重复；起点可见")
	_ok(not ex.explored.has(ex.m.lair), "首领巢穴藏在迷雾里")
	_ok(not ex.boss_revealed(), "开局看不见首领棋子")
	# 首领巢穴：最外一圈的随机空地，离起点沿路 ≥ 6 步，不贴着大赏 / 休息点 / 商店 / 精英
	var rim_ok := 0
	var lairs := {}
	for s in 60:
		var lm := MapGen.generate(3000 + s * 7, MapGen.THEME_ORDER[s % 4])
		if lm.is_empty():
			continue
		var lk: int = lm.lair
		lairs[lk] = true
		var pd := MapGen.bfs(MapGen.mask_of(func(x): return lm.ink[x] == 0 and not lm.obst.has(x) and not (lm.mech.has(x) and lm.mech[x].kind == "gate")), lm.start)
		var good: bool = MapGen.is_rim(lk) and pd[lk] >= MapGen.LAIR_MIN_PATH and lm.node.get(lk, {}).get("t", "") == "巢" \
			and lm.node.keys().filter(func(x): return lm.node[x].t == "巢").size() == 1 \
			and not lm.node.keys().any(func(x): return lm.node[x].t in ["大", "休", "市", "险"] and MapGen.man(x, lk) < 3) \
			and not lm.get("terr", {}).has(lk) and MapGen._reach_ok(lm, lm.get("terr", {}))
		if good:
			rim_ok += 1
	_ok(rim_ok == 60, "首领巢穴都在最外一圈、走得到、不贴着奖励（%d/60）" % rim_ok)
	var sides := {}
	for lk in lairs:
		var lp := MapGen.rc(lk)
		sides["上" if lp.x == 0 else ("下" if lp.x == MapGen.H - 1 else ("左" if lp.y == 0 else "右"))] = true
	_ok(lairs.size() >= 15 and sides.size() >= 3, "首领巢穴位置随机：60 张图里有 %d 个不同位置，分布在 %s" % [lairs.size(), sides.keys()])
	var g1 := MapGen.generate(4242, "墨池")
	var g2 := MapGen.generate(4242, "墨池")
	_ok(g1.lair == g2.lair, "同一种子首领位置一样")
	var sa := MapGen.sim(g1, "fog", true, g1.terr, MapGen.SLIDE_N, 5)
	var sb := MapGen.sim(g1, "fog", true, g1.terr, MapGen.SLIDE_N, 5)
	_ok(sa.got == sb.got and sa.t == sb.t, "概率追击模拟：同一个骰子种子结果一样")
	var nc := float(g1.content.size())
	_ok(g1.fog.got >= 0.45 * nc and g1.fog.got <= 0.75 * nc, "游戏用图按概率追击复核：初见拿到 %d/%d" % [g1.fog.got, nc])
	var nb := _find(ex, func(k): return ex.can_step(k) and ex.mech_at(k).is_empty() and not ex.m.obst.has(k) and not ex.m.get("terr", {}).has(k))
	ex.move(nb)
	_ok(ex.pos == nb and ex.t == 1, "走一步，时间 +1")
	_ok(not ex.can_step(ex.m.start + 2 * MapGen.W + 2) or MapGen.man(ex.m.start + 2 * MapGen.W + 2, ex.pos) == 1, "只能走相邻格")
	# 墨障：花 2 墨冲开；墨不够以血冲开
	# 找一张有墨障、且墨障旁有空地的图（不依赖某个种子碰巧有墨障）
	var exo: Expedition = null
	var ob := -1
	for sd in range(1, 60):
		exo = _fresh(sd)
		ob = _find(exo, func(k): return exo.m.obst.has(k) and MapGen.nbrs(k).any(func(n): return exo.m.ink[n] == 0 and not exo.m.obst.has(n)))
		if ob >= 0:
			break
	_ok(ob >= 0, "能找到带墨障的图")
	if ob >= 0:
		exo.pos = MapGen.nbrs(ob).filter(func(n): return exo.m.ink[n] == 0 and not exo.m.obst.has(n))[0]
		exo.panels.clear()
		exo.fight = {}
		exo.move(ob)
		_ok(exo.ink == Expedition.START_INK - Expedition.BARRIER_INK and not exo.m.obst.has(ob), "墨障：花 2 墨冲开")
	# 主题机关
	var hp := GameState.player_hp
	ex.m = MapGen.generate(11, "熔铸坊")
	ex.pos = _find(ex, func(k): return ex.mech_at(k).get("g", "") == "焰")
	ex._step_mech()
	_ok(GameState.player_hp == hp - 3, "烈焰格：气血 −3")
	_set_words(ex, ["防火"])
	ex._step_mech()
	_ok(GameState.player_hp == hp - 3, "防火：烈焰格不掉血")
	ex.m = MapGen.generate(11, "墨池")
	_set_words(ex, [])
	ex.pos = _find(ex, func(k): return ex.mech_at(k).get("g", "") == "纸")
	_ok(ex._step_mech() == 1, "吸墨纸：多耗 1 步")
	_set_words(ex, ["清流"])
	_ok(ex._step_mech() == 0, "清流：吸墨纸不再多耗步")
	ex.pos = _find(ex, func(k): return ex.mech_at(k).get("g", "") == "泉")
	var ink := ex.ink
	ex._step_mech()
	ex._step_mech()
	_ok(ex.ink == ink + 3, "墨泉：补 3 墨，一次性")
	_set_words(ex, ["开灯"])
	_ok(ex.vision() == 3, "开灯：视野 +1")


func _test_boss() -> void:
	var ex := _fresh(9)
	ex.t = ex.wake_time() - 1
	ex.tick()
	_ok(ex.stir != null and int(ex.rise) == ex.t + ex.buffer_steps() and not ex.awake() and ex.boss_revealed(), "到醒来时间被惊动，首领现身，缓冲 %d 步后起身" % ex.buffer_steps())
	var wakes := {}
	var bufs := {}
	var in_range := true
	for sd in range(1, 41):
		var gm := MapGen.generate(sd * 17)
		wakes[int(gm.wake)] = true
		bufs[int(gm.buffer)] = true
		in_range = in_range and int(gm.wake) >= 7 and int(gm.wake) <= 10 and int(gm.buffer) >= 7 and int(gm.buffer) <= 10
	_ok(in_range and wakes.size() >= 3 and bufs.size() >= 3, "首领第 7～10 步惊动、再过 7～10 步起身（40 张图：惊动 %s，缓冲 %s）" % [wakes.keys(), bufs.keys()])
	_ok(ex.alerts.size() == 1 and ex.alerts[0][0] == "首领被惊动了", "首领被惊动：弹窗提醒")
	_set_words(ex, ["停息"])
	_ok(ex.wake_time() == int(ex.m.wake) + 4, "停息：醒来推迟 4 步")
	_set_words(ex, ["急停"])
	ex.t = int(ex.rise) - 1
	ex.tick()
	_ok(ex.awake() and ex.stun == 1, "急停：起身后先原地停 2 步")
	_ok(ex.alerts.size() == 2 and ex.alerts[1][0] == "首领起身了", "首领起身：再弹一次提醒")
	_set_words(ex, [])
	ex.stun = 0
	var caught := false
	for i in 200:
		if ex.tick():
			caught = true
			break
	_ok(caught, "首领沿最短路追上原地不动的玩家")
	ex._caught()
	_ok(ex.fight.get("kind", "") == "boss" and ex.fight.caught, "被追上 → 首领战")
	var pk: int = ex.m.pockets[0].b
	_ok(ex.location_debuff(pk) == "先手", "在奖励凹槽里被追上：首领先手")
	# 首领走路：伪随机。基线 0.35，每步 +0.05；没走就累计（基线 × 连续没走数+1），走了回基线
	ex = _fresh(13)
	_ok(ex.move_chance() == 0.0, "首领没起身：不会走")
	ex.stir = 0
	ex.rise = 0
	ex.t = 0
	ex.miss = 0
	_ok(is_equal_approx(ex.move_base(), 0.35) and is_equal_approx(ex.move_chance(), 0.35), "起身那一步：概率 35%")
	ex.t = 4
	_ok(is_equal_approx(ex.move_base(), 0.55), "起身后第 4 步：基线 0.35 + 4×0.05 = 55%")
	ex.miss = 1
	_ok(is_equal_approx(ex.move_chance(), 1.0), "基线 55%，上一步没走：累计到 100%（封顶）")
	ex.t = 0
	ex.miss = 2
	_ok(is_equal_approx(ex.move_chance(), 1.0) and is_equal_approx(_fresh_chance(0, 1), 0.70), "基线 35%：没走 1 步 → 70%，没走 2 步 → 100%")
	_set_words(ex, ["冷却"])
	ex.t = 4
	ex.miss = 0
	_ok(is_equal_approx(ex.move_base(), 0.45), "冷却：基线增长减半（第 4 步 45%）")
	_set_words(ex, [])
	# 真跑：起身后 tick，走了 miss 归零，没走 miss +1；首领在远处不会追上
	var moves := 0
	var resets_ok := true
	var total := 0
	for s in 30:
		ex = _fresh(500 + s)
		ex.stir = 0
		ex.rise = 0
		ex.halt_done = true
		ex.boss = ex.m.lair
		for i in 6:
			var before_miss := ex.miss
			var before := ex.boss
			var p := ex.move_chance()
			ex.tick()
			total += 1
			if ex.boss != before:
				moves += 1
				if ex.miss != 0: resets_ok = false
			elif ex.miss != before_miss + 1 and p < 1.0:
				resets_ok = false
	_ok(resets_ok, "走了就回基线（miss=0），没走就累计（miss+1）")
	_ok(moves > total * 0.45 and moves < total * 0.85, "前 6 步首领约一半多的步数在动：%d/%d" % [moves, total])
	var e1 := _fresh(77)
	var e2 := _fresh(77)
	for x in [e1, e2]:
		x.stir = 0
		x.rise = 0
		x.halt_done = true
		for i in 8:
			x.tick()
	_ok(e1.boss == e2.boss and e1.miss == e2.miss, "同一种子首领走法一样")
	var mp := MapGen.generate(11, "墨池")
	ex.m = mp
	var paper := _find(ex, func(k): return ex.mech_at(k).get("g", "") == "纸")
	_ok(ex.location_debuff(paper) == "少抽字", "吸墨纸旁被追上：少抽 1 枚字")
	ex.pos = paper
	_set_words(ex, ["反超"])
	_ok(ex._boss_encounter(true).debuff == "", "反超：被追上也不吃位置减益")
	_ok(ex._boss_encounter(false).debuff == "", "主动迎战不吃位置减益")
	ex = _fresh(9)
	ex.stir = 0
	ex.rise = 0
	_set_words(ex, ["反转"])
	ex.boss = _find(ex, func(k): return MapGen.man(k, ex.pos) == 1 and ex.m.ink[k] == 0)
	ex._caught()
	_ok(ex.fight.is_empty() and ex.flip_used and MapGen.bfs(ex.boss_mask(), ex.boss)[ex.pos] > 1, "反转：把首领推回去，不开战（每幕一次）")
	ex._caught()
	_ok(not ex.fight.is_empty(), "反转用过后再被追上就开战")
	ex.fight = {}
	_set_words(ex, ["超能力"])
	_ok(ex.use_power() and ex.stun >= 6 and not ex.use_power(), "超能力：定住首领 6 步，每幕一次")


func _test_glyphs_and_tray() -> void:
	var ex := _fresh(21)
	var g := _find(ex, func(k): return ex.m.glyph.has(k) and not ex.sealed(k) and ex.guard_of(k).is_empty())
	ex.pos = g
	_ok(ex.pickup() and ex.tray.size() == 1 and ex.taken.has(g), "散字：走过去就拾进字匣")
	var guarded := _find(ex, func(k): return ex.m.glyph.has(k) and not ex.guard_of(k).is_empty())
	if guarded >= 0:
		ex.pos = guarded
		_ok(not ex.pickup(), "明敌身边的散字拾不走")
	var sealed := _find(ex, func(k): return ex.m.glyph.has(k) and ex.sealed(k))
	if sealed >= 0:
		ex.pos = sealed
		_ok(not ex.pickup(), "被封的散字拾不走")
	ex.tray = ["火", "火", "火", "火", "火", "火"]
	var free := _find(ex, func(k): return ex.m.glyph.has(k) and not ex.taken.has(k) and not ex.sealed(k) and ex.guard_of(k).is_empty())
	ex.pos = free
	_ok(not ex.pickup() and ex.tray.size() == 6, "字匣 6 格，满了不能再拾字")
	_set_words(ex, ["收放"])
	_ok(ex.tray_cap() == 7, "收放：字匣 +1")
	ex.seals = ["活字盒"]
	_ok(ex.tray_cap() == 9, "活字盒：字匣 +2")
	ex.seals = []
	_set_words(ex, [])
	ex.gain_glyph("电")
	_ok(GameState.deck_size() == 13, "字匣满了，发的字直接进字袋")
	_ok(ex.tray_to_deck(0) and GameState.deck_size() == 14 and ex.tray.size() == 5, "字匣 → 字袋")
	ex.discard(0)
	_ok(ex.buyback == ["火"] and ex.tray.size() == 4, "丢字进回购清单")
	_set_words(ex, ["转化"])
	ex.discard(0, true)
	_ok(ex.tray.size() == 4 and ex.tray[-1] != "火", "转化：丢字换一个同系统的随机字")
	_set_words(ex, ["重复"])
	ex.tray.clear()
	ex.repeat_used = false
	var g2 := _find(ex, func(k): return ex.m.glyph.has(k) and not ex.taken.has(k) and not ex.sealed(k) and ex.guard_of(k).is_empty())
	ex.pos = g2
	ex.pickup()
	_ok(ex.tray.size() == 2 and ex.tray[0] == ex.tray[1], "重复：每幕第一个拾到的字多复制一枚")


func _test_plate() -> void:
	var ex := _fresh(3)
	ex.tray = ["加", "速", "急", "停"]
	ex.place(0, Vector2i(0, 0))
	ex.place(0, Vector2i(0, 1))
	ex.place(0, Vector2i(1, 0))
	ex.place(0, Vector2i(1, 1))
	_ok(ex.has("加速") and ex.has("急停") and ex.has("加急") and ex.tray.is_empty(), "版面放字免费，词一拼出来就生效")
	var t0 := ex.t
	ex.take_back(Vector2i(1, 1))
	_ok(not ex.has("急停") and ex.t == t0 + 1 and ex.tray == ["停"], "取字耗 1 步，词拆开效果立刻消失")
	ex.plate = [["收", "回"], ["停", ""]]
	ex.refresh_active()
	ex.tray.clear()
	ex.take_back(Vector2i(1, 0))
	_ok(ex.has("收回") and ex.t == t0 + 1 and ex.tray == ["停"], "收回：取字不耗步")
	var mx := GameState.player_max_hp
	ex.plate = [["精", "力"], ["", ""]]
	ex.refresh_active()
	_ok(GameState.player_max_hp == mx + 8, "精力：最大气血 +8")
	ex.plate = [["精", ""], ["", ""]]
	ex.refresh_active()
	_ok(GameState.player_max_hp == mx, "拆掉精力，上限回落")
	ex._take_seal("宽版")
	_ok(ex.plate_n == 3 and ex.plate[0][0] == "精" and ex.wide_used, "宽版：版面扩成 3×3，原有的字保留")


func _test_loot_rest_shop() -> void:
	var ex := _fresh(4)
	_ok(ex.loot_options("小").size() == 2 and ex.loot_options("中").size() == 3 and ex.loot_options("大").size() == 3, "小赏二选一、中赏 / 大赏三选一")
	_set_words(ex, ["重金"])
	ex.seals = ["拓本"]
	_ok(ex.loot_options("大").size() == 5 and ex.loot_options("小").size() == 3, "重金：大赏多一个；拓本：所有赏多一个")
	ex.seals = []
	_set_words(ex, [])
	var owned := ex.owned_glyphs()
	var all_ok := true
	for i in 30:
		if not ex.formable(Database.get_character_by_glyph(ex.roll_glyph()), owned):
			all_ok = false
	_ok(all_ok, "发出的字都能和现有的字组成至少一个词")
	var base := {}
	for cd in Database.characters.values():
		if not cd.is_pollution and not cd.pending_design and not cd.tags.has("enemy") and not cd.tags.has("彩蛋"):
			base[cd.glyph] = cd.rarity
	var in_lib := true
	for i in 60:
		var g := ex.roll_glyph(i % 3, i % 2 == 0)
		if not base.has(g) or (i % 3 == 0 and base[g] > 2):
			in_lib = false
		for p in ex.roll_pair():
			if not base.has(p):
				in_lib = false
	_ok(in_lib and Database.get_word_by_glyphs(ex.roll_pair()) != null, "奖励字取自原游戏字库（同战后奖励 / 商店筛选与稀有度），成对的字是游戏词库里的词")
	_ok(ex.shop_offers().filter(func(o): return o.kind == "glyph").size() == 3, "商店同原版：三枚字")
	var big := _find(ex, func(k): return ex.m.node.has(k) and ex.m.node[k].t == "大")
	ex.pos = big
	ex.enter_cell()
	_ok(ex.top_panel().get("kind", "") == "loot" and ex.alarm, "打开大赏：弹出奖励，并惊动首领")
	var gold := GameState.gold
	var opts: Array = ex.top_panel().options
	var gi: int = opts.map(func(o): return o.kind).find("gold")
	if gi >= 0:
		ex.choose_loot(gi)
		_ok(GameState.gold > gold and ex.taken.has(big) and ex.panels.is_empty(), "选了金币，赏格清空")
	else:
		ex.choose_loot(0)
	# 休息
	GameState.player_hp = 20
	ex.push_panel({"kind": "rest"})
	var t0 := ex.t
	ex.rest("heal")
	_ok(GameState.player_hp == 38 and ex.t == t0 + 3, "休息治疗 30%（18 点），耗 3 步")
	ex.seals = ["蒲团"]
	_ok(ex.rest_heal_amount() == 36, "蒲团：治疗量翻倍")
	ex.seals = []
	ex.push_panel({"kind": "rest"})
	var id: String = GameState.deck[0].id()
	_set_words(ex, ["精金"])
	ex.rest("gild", id)
	_ok(GameState.deck.filter(func(c): return c.gilded).size() == 2, "修饰镀金；精金额外镀一枚")
	GameState.add_character(Database.get_character("pollution"))
	ex.push_panel({"kind": "rest"})
	var n := GameState.deck_size()
	ex.rest("remove", "pollution")
	_ok(GameState.deck_size() == n - 1, "休息删字（含污染字）")
	# 商店
	ex.pos = _find(ex, func(k): return ex.m.node.has(k) and ex.m.node[k].t == "市")
	var offers := ex.shop_offers()
	_ok(offers == ex.shop_offers(), "同一家商店的货不会重摇")
	var o: Dictionary = offers[0]
	_set_words(ex, ["收购", "投币"])
	var cost := ex.price(o)
	_ok(cost == int(ceil(o.base * 0.7)), "收购：买字 7 折")
	GameState.gold = 100
	ex.buy(0)
	_ok(GameState.gold == 100 - cost + 1 and ex.spent == cost, "投币：每买一样返 1 金币")
	_set_words(ex, ["合资"])
	var rm: Dictionary = offers.filter(func(x): return x.kind == "remove")[0]
	_ok(ex.price(rm) == rm.base - 5, "合资：删字 −5")
	ex.buyback = ["火"]
	_set_words(ex, ["回购"])
	_ok(ex.buyback_offers().size() == 1 and ex.price(ex.buyback_offers()[0]) == 7, "回购：丢掉的字半价买回")
	# 熔炉
	# 和任何遗物都不相关的两个字：一定熔成稀有字（许愿见 relic_test）
	ex.tray = ["冷", "冷"]
	ex.push_panel({"kind": "forge", "k": 0})
	_set_words(ex, ["炼金"])
	gold = GameState.gold
	_ok(ex.forge(0, 1) and ex.tray.size() == 1 and Database.get_character_by_glyph(ex.tray[0]).rarity >= 2 and GameState.gold == gold + 4, "熔炉：两个字熔成一个稀有字；炼金 +4")


func _battle(ex: Expedition, f: Dictionary) -> BattleState:
	ex.fight = f
	var state := BattleState.new(Database.rules)
	state.start(GameState.make_battle_deck(), ex.battle_node().enemies, 7)
	ex.apply_battle_setup(state)
	return state


func _deck_conserved(state: BattleState) -> bool:
	var n := state.bag.size()
	for c in state.board.cells:
		if c != null and not c.temporary:
			n += 1
	return n == GameState.deck.size()


func _test_battle_setup() -> void:
	var ex := _fresh(6)
	var foe := {"kind": "foe", "k": 10, "g": "爆", "name": "明敌"}
	ex.fight = foe
	var node := ex.battle_node()
	_ok(node.enemies[0].glyph == "爆" and Database.get_enemy(node.enemies[0].id).glyph != "爆", "敌人资源复制后换成地图敌字，不改原资源")
	_set_words(ex, ["护盾", "护甲", "蓄能", "蓄力", "重击", "火力"])
	var s := _battle(ex, foe)
	var e: Combatant = s.enemies[0]
	_ok(s.player.block == 4 and s.player.persistent_block == 2 and s.player.energy == 2, "护盾 +4 / 护甲 +2 持久盾 / 蓄能 +2 储能")
	_ok(s.ability_value("force_once") == 4 and s.pierce_once, "蓄力：首个词伤害 +4；重击：首次攻击无视护盾")
	_ok(e.hp == e.max_hp - 4, "火力：开场先对敌人造成 4 点伤害")
	_ok(_deck_conserved(s), "开场效果不吞字袋里的字")
	e.add_block(10)
	var before := e.hp
	s.deal_damage(e, 5)
	_ok(e.hp < before and e.block == 10 and not s.pierce_once, "重击：这一击穿过护盾，护盾保留")
	_set_words(ex, ["重甲", "加急", "蓄冷", "清热", "防御力"])
	s = _battle(ex, foe)
	var on_board := s.board.cells.filter(func(c): return c != null).size()
	_ok(s.player.block == 8 and s.player.heat_capacity == Database.rules.heat_capacity + 3 and s.player.permanent_damage_reduction == 1, "重甲 +8 护盾 / 蓄冷 热容 +3 / 防御力 受伤 −1")
	_ok(on_board == Database.rules.opening_draw, "重甲少抽 1 枚、加急多抽 1 枚，互相抵消")
	_ok(_deck_conserved(s), "少抽的字放回字袋")
	# 伏兵
	_set_words(ex, [])
	var hp := GameState.player_hp
	s = _battle(ex, {"kind": "ambush", "k": 0, "amb": 0, "name": "伏兵", "g": ""})
	_ok(s.enemies[0].move_index == 1, "伏兵突袭：敌人在你第一回合之前先动手")
	_set_words(ex, ["反击"])
	s = _battle(ex, {"kind": "ambush", "k": 0, "amb": 0, "name": "伏兵", "g": ""})
	_ok(s.enemies[0].move_index == 0, "反击：遭遇伏兵由你先手")
	_set_words(ex, [])
	var amb_f := {"kind": "ambush", "k": 0, "amb": 0, "name": "伏兵", "g": ""}
	s = _battle(ex, amb_f)
	var loss0: int = GameState.player_hp - s.player.hp
	_set_words(ex, ["防护"])
	s = _battle(ex, amb_f)
	var loss1: int = GameState.player_hp - s.player.hp
	_ok(loss1 == maxi(0, loss0 - 6) and s.player.block == maxi(0, 6 - loss0), "防护：伏兵战 +6 护盾，先挡突袭（突袭伤害 %d → %d）" % [loss0, loss1])
	_set_words(ex, ["回防"])
	s = _battle(ex, amb_f)
	_ok(s.player.turn_damage_halve and GameState.player_hp - s.player.hp <= loss0, "回防：第一回合（含突袭）敌人伤害减半")
	GameState.player_hp = hp
	# 首领
	_set_words(ex, ["电击"])
	var boss := {"kind": "boss", "k": ex.boss, "name": "首领", "g": ex.m.TH.boss, "caught": false, "debuff": ""}
	s = _battle(ex, boss)
	e = s.enemies[0]
	_ok(e.persistent_block == 8 and e.block == 6 and e.hp == e.max_hp - 6, "第一幕首领词条：护甲 8、护盾 6；电击：首领战开场先造成 6 点伤害（在词条之前结算）")
	_set_words(ex, ["破甲", "破防", "停火"])
	s = _battle(ex, boss)
	e = s.enemies[0]
	_ok(e.persistent_block == 0 and e.block == 0 and s.enemy_skip_turns == 1, "破甲护甲 −8 / 破防失去全部护盾 / 停火")
	hp = s.player.hp
	s.end_player_turn()
	_ok(s.player.hp == hp and s.enemy_skip_turns == 0, "停火：首领第一回合不攻击")
	_set_words(ex, [])
	ex.act = 2
	ex.seals = ["朱笔"]
	s = _battle(ex, boss)
	_ok(s.enemies[0].status_stacks("strength") == 0 and s.enemies[0].persistent_block == 12, "朱笔：首领少一条词条（第二幕去掉力量）")
	ex.seals = []
	ex.act = 1
	boss.debuff = "先手"
	s = _battle(ex, boss)
	_ok(s.enemies[0].move_index == 1, "位置减益·先手：首领在你第一回合之前行动")
	boss.debuff = "热度"
	s = _battle(ex, boss)
	_ok(s.player.heat == 3, "位置减益·熔铸坊烈焰格旁：开局热度 +3")
	boss.debuff = "首领护盾"
	s = _battle(ex, boss)
	_ok(s.enemies[0].block == 14, "位置减益·雷池：首领护盾 +8")
	boss.debuff = "污染字"
	s = _battle(ex, boss)
	_ok(s.bag.any(func(c): return c.data.is_pollution and c.temporary), "位置减益·墨泉旁：字袋混进 1 枚本场污染字")
	_ok(not GameState.deck.any(func(c): return c.data.is_pollution), "本场污染字不进永久字袋")


func _test_finish_and_acts() -> void:
	var ex := _fresh(8)
	var foe_k := _find(ex, func(k): return ex.m.node.has(k) and ex.m.node[k].t == "敌")
	ex.pos = foe_k
	ex.enter_cell()
	_ok(ex.fight.get("kind", "") == "foe", "踩上明敌进入战斗")
	_set_words(ex, ["金币", "充能"])
	var gold := GameState.gold
	var ink := ex.ink
	var t0 := ex.t
	var r := ex.finish_battle(true)
	_ok(r.reward and r.count == 3 and ex.taken.has(foe_k), "战胜明敌：去战后三选一")
	_ok(GameState.gold == gold + 2 and ex.ink == ink + 1 and ex.t >= t0 + 2, "金币 +2 / 充能回 1 墨 / 打仗花 2 步")
	_set_words(ex, ["分流"])
	ex.fight = {"kind": "foe", "k": foe_k, "g": "爆", "name": "明敌"}
	_ok(ex.finish_battle(true).count == 4, "分流：战后四选一")
	_set_words(ex, [])
	# 伏兵：打赢后领地里的奖励解封
	var amb: Dictionary = ex.m.ambush[0]
	var sealed_k: int = amb.sealed[0]
	_ok(ex.sealed(sealed_k), "伏兵领地里的奖励显示「封」")
	ex.fight = {}
	ex.panels.clear()
	ex.pos = amb.cells[0]
	ex.enter_cell()
	_ok(ex.fight.get("kind", "") == "ambush", "走进伏兵领地就必须开战")
	ex.finish_battle(true)
	_ok(not ex.sealed(sealed_k), "打赢伏兵，领地里的奖励解封")
	ex.fight = {}
	ex.panels.clear()
	# 精英给印章
	ex.fight = {"kind": "elite", "k": _find(ex, func(k): return ex.m.node.has(k) and ex.m.node[k].t == "险"), "g": "甲", "name": "守口精英"}
	_set_words(ex, ["铸币"])
	gold = GameState.gold
	ex.finish_battle(true)
	_ok(ex.seals.size() == 1 and Expedition.SEALS[ex.seals[0]][1] == "精英" and GameState.gold == gold + 5, "精英：掉一枚印章；铸币 +5")
	# 镇纸
	ex.seals = ["镇纸"]
	GameState.player_hp = 50
	ex.fight = {"kind": "foe", "k": 0, "g": "爆", "name": "明敌", "hp_start": 60}
	ex.finish_battle(true)
	_ok(GameState.player_hp == 54, "镇纸：每场战斗少掉 4 点血")
	ex.seals = []
	# 首领 → 幕终 → 下一幕
	ex.panels.clear()
	_set_words(ex, ["利息", "投资"])
	GameState.gold = 50
	ex.spent = 30
	ex.fight = {"kind": "boss", "k": ex.boss, "name": "首领", "g": "墨", "caught": false, "debuff": ""}
	r = ex.finish_battle(true)
	_ok(not r.reward and ex.boss_down and not ex.panels.any(func(p): return p.kind == "act_end"), "击败首领：不走三选一，也不直接结束本幕")
	_ok(not ex.awake() and not ex.can_confront() and not ex.boss_revealed() and ex.boss_path().is_empty(), "首领倒下：不再追击，棋子和路线都不显示")
	_ok(ex.boss_status().contains("已败") and ex.alerts.size() == 1 and ex.alerts[0][0] == "首领已被击败", "首领倒下：状态改为已败，只弹「可以继续探索」的提示")
	ex.alerts.clear()
	var t_before := ex.t
	var caught := false
	for i in 30:
		caught = ex.tick() or caught
	_ok(not caught and ex.fight.is_empty() and ex.t == t_before + 30, "首领倒下后过 30 步也不会被追上")
	var rest_k := _find(ex, func(k): return ex.m.node.get(k, {}).get("t", "") == "休")
	if rest_k >= 0:
		ex.pos = rest_k
		ex.enter_cell()
		_ok(ex.top_panel().get("kind", "") == "rest", "首领倒下后还能进休息点")
		ex.panels.clear()
	_ok(ex.can_finish_act() and ex.finish_act() and ex.top_panel().get("kind", "") == "act_end", "点「结束本幕」才进入幕间结算")
	_ok(not ex.finish_act(), "幕间结算面板开着时不能重复结束")
	_ok(ex.act_settlement() == [["利息", 5], ["投资返还", 6]], "幕间：利息 10%% / 投资返还 20%% %s" % [ex.act_settlement()])
	_set_words(ex, ["利息", "复利投资"])
	ex.act = 2
	GameState.gold = 200
	_ok(ex.act_settlement()[0][1] == 16, "复利投资：第二幕利息 20%（上限翻倍）")
	ex.act = 1
	ex.tray = ["火"]
	while ex.top_panel().get("kind", "") != "act_end":
		ex.pop_panel()
	var th1: String = ex.m.tn
	ex.next_act()
	_ok(ex.act == 2 and ex.m.tn != th1 and ex.tray == ["火"] and ex.t == 0 and ex.stir == null, "进入第二幕：换主题、新地图，字匣 / 版面 / 印章带过去")
	ex.act = 3
	ex.push_panel({"kind": "act_end"})
	ex.next_act()
	_ok(ex.over and ex.won, "第三幕首领倒下：远征完成")
	ex = _fresh(8)
	ex.fight = {"kind": "foe", "k": 0, "g": "爆", "name": "明敌"}
	ex.finish_battle(false)
	_ok(ex.over and not ex.won, "战败：远征中止")


func _test_screens() -> void:
	var ex := _fresh(12)
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	Router.host = host
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await get_tree().process_frame
	var screen: Control = Router.current
	_ok(screen._map_grid.get_child_count() == MapGen.N and screen._plate_grid.get_child_count() == 4, "远征地图 12×8 + 版面 2×2")
	_ok(screen._legend_box != null and screen._legend_box.is_inside_tree(), "页面里有图样说明（颜色、敌人、机关）")
	_ok(screen._boss_bar_label.text.contains("沉睡"), "地图上方的首领提示条：沉睡")
	await get_tree().process_frame
	_ok(not screen._boss_piece.visible, "首领沉睡且不在视野里：棋子不显示")
	ex.stir = ex.t
	ex.rise = ex.t
	ex.alerts.append(["首领起身了", "测试"])
	screen.refresh()
	_ok(screen._boss_bar_label.text.contains("正在追你") and screen._alert_open, "首领追来：提示条显示距离，并弹窗")
	await get_tree().process_frame
	_ok(screen._boss_piece.position == screen._cell_origin(ex.boss) and screen._boss_glyph.text == ex.m.TH.boss and screen._boss_piece.visible, "首领被惊动后显示：一枚棋子，摆在它所在的格")
	var from := ex.boss
	for i in 30:
		if ex.tick():
			break
	_ok(ex.boss != from and not ex.boss_trail.is_empty(), "首领每步都在地图上移动，记下走过的格")
	screen.refresh()
	_ok(ex.boss_trail.is_empty() and screen._boss_tween != null and screen._boss_shown == ex.boss, "棋子逐格走到新位置")
	_ok(screen._path_layer.points.size() == ex.boss_path().size(), "画出首领接下来要走的路")
	ex.boss = ex.m.lair
	ex.fight = {}
	var am: Dictionary = ex.m.ambush[0]
	ex.fight = {"kind": "ambush", "k": am.cells[-1], "amb": 0, "name": "伏兵", "g": ""}
	screen.refresh()
	await get_tree().process_frame
	_ok((screen._map_grid.get_child(am.k) as Button).text == "伏", "伏兵战进行中：伏兵所在格显示「伏」")
	ex.fight = {}
	ex.amb_done[0] = true
	screen.refresh()
	await get_tree().process_frame
	_ok((screen._map_grid.get_child(am.k) as Button).text == "✕", "打赢伏兵：那一格画 ✕")
	ex.amb_done.clear()
	ex.stir = null
	ex.rise = null
	ex.alerts.clear()
	screen._alert_open = false
	for c in screen.get_children():
		if c is ChoiceOverlay:
			c.queue_free()
	screen.refresh()
	var nb := _find(ex, func(k): return ex.can_step(k) and ex.mech_at(k).is_empty() and not ex.m.obst.has(k) and not ex.m.get("terr", {}).has(k) and not ex.m.node.has(k))
	screen._on_map_cell(nb)
	await get_tree().process_frame
	_ok(ex.pos == nb, "点脚边的格前进")
	ex.fight = {"kind": "foe", "k": nb, "g": "爆", "name": "明敌"}
	screen.refresh()
	screen._start_battle()
	await get_tree().process_frame
	var bs: Control = Router.current
	_ok(Router.current_path.contains("battle_screen") and bs._expedition and bs.battle.enemies[0].display_name == "明敌", "开战进入 4×4 战斗")
	bs.battle.enemies[0].hp = 0
	bs._check_battle_over()
	for i in 90:
		await get_tree().process_frame
		if Router.current_path.contains("reward_screen"):
			break
	_ok(Router.current_path.contains("reward_screen") and Router.current._options.size() == 3, "战胜明敌 → 战后三选一")
	var gold := GameState.gold
	Router.current._on_skip()
	await get_tree().process_frame
	_ok(Router.current_path.contains("expedition_map_screen") and GameState.gold == gold + 8, "跳过三选一拿 8 金币，回到远征地图")
	ex.fight = {"kind": "boss", "k": ex.boss, "name": "首领", "g": ex.m.TH.boss, "caught": true, "debuff": "先手"}
	Router.current.refresh()
	Router.current._start_battle()
	await get_tree().process_frame
	bs = Router.current
	bs.battle.enemies[0].hp = 0
	bs._check_battle_over()
	for i in 90:
		await get_tree().process_frame
		if Router.current_path.contains("expedition_map_screen"):
			break
	_ok(Router.current_path.contains("expedition_map_screen") and ex.boss_down and ex.top_panel().get("kind", "") in ["", "seal_swap"], "击败首领 → 回地图继续探索，不直接弹幕终")
	var scr: Control = Router.current
	ex.panels.clear()
	scr.refresh()
	_ok(scr._confront_btn.text == "结束本幕" and not scr._confront_btn.disabled, "首领倒下：按钮变成「结束本幕」")
	scr._confront_btn.pressed.emit()
	await get_tree().process_frame
	_ok(ex.top_panel().get("kind", "") == "act_end", "点「结束本幕」弹出幕终结算")
	scr._refresh_event()
	_ok(scr._event_box.get_child_count() > 0, "幕终面板构建")


## 自动跑完整局：随机走、处理每种面板、每场战斗都真的建 BattleState 并套开场效果（战斗按胜利结算）
func _test_autoplay() -> void:
	var finished := 0
	for seed in [1, 2, 3, 4]:
		var ex := _fresh(seed)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		for it in 3000:
			if ex.over:
				break
			if not ex.fight.is_empty():
				var s := BattleState.new(Database.rules)
				s.start(GameState.make_battle_deck(), ex.battle_node().enemies, it)
				ex.apply_battle_setup(s)
				GameState.player_hp = maxi(GameState.player_hp, 30)
				var r := ex.finish_battle(true)
				if r.get("reward", false):
					ex.receive_reward_glyph(Database.get_character_by_glyph(ex.roll_glyph()))
				continue
			var p := ex.top_panel()
			match p.get("kind", ""):
				"loot": ex.choose_loot(rng.randi_range(0, p.options.size() - 1))
				"rest": ex.rest("heal")
				"shop":
					GameState.add_gold(10)
					ex.buy(0)
					ex.leave_panel()
				"forge":
					if ex.tray.size() >= 2:
						ex.forge(0, 1)
					else:
						ex.leave_panel()
				"event": ex.choose_event(rng.randf() < 0.5)
				"seal_swap": ex.swap_seal(0)
				"relic_bind": ex.bind_relic(GameState.deck[0].id())
				"act_end": ex.next_act()
				_:
					if not ex.tray.is_empty() and rng.randf() < 0.3:
						var empty := []
						for r2 in ex.plate_n:
							for c2 in ex.plate_n:
								if str(ex.plate[r2][c2]).is_empty():
									empty.append(Vector2i(r2, c2))
						if not empty.is_empty():
							ex.place(0, empty[0])
						else:
							ex.tray_to_deck(0)
						continue
					# 一半时间朝首领走（让每幕都能结束），一半随机探索
					var opts: Array = MapGen.nbrs(ex.pos).filter(func(k): return ex.can_step(k))
					if opts.is_empty():
						ex.advance(1)
						continue
					var nx: int = opts[rng.randi_range(0, opts.size() - 1)]
					if rng.randf() < 0.5:
						var d := MapGen.bfs(MapGen.mask_of(func(k): return ex.can_enter(k)), ex.boss)
						opts.sort_custom(func(a, b): return d[a] < d[b])
						nx = opts[0]
					ex.move(nx)
					if ex.can_finish_act() and rng.randf() < 0.2:
						ex.finish_act()
					elif ex.can_confront():
						ex.confront()
		if ex.over and ex.won:
			finished += 1
	_ok(finished == 4, "自动跑完整局：4 个种子都走完三幕（%d/4）" % finished)
