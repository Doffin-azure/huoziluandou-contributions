extends RefCounted
class_name Expedition
## 墨途远征 v0.3（《幕间探索设计报告 v0.3》+《字的经济与全局加成 v0.1》）：
## 迷雾开阔地图（MapGen）· 首领惊动与追逐 · 明敌看守 · 伏兵领地与封 · 字匣 / 字袋 / 版面三处放字 ·
## 版面词谱（Lexicon）· 印章 · 休息点三选一 · 商店 · 熔炉 · 谜 · 被追上的位置减益 · 三幕与幕间结算。
## 遭遇进入真正的 4×4 战斗（battle_screen），开场效果见 apply_battle_setup。格子用 MapGen 的整数 k。

const TRAY_CAP := 6
const DECK_CAP := 20
const SEAL_CAP := 3
const START_INK := 4
const BARRIER_INK := 2
const BARRIER_HP := 4
const FIGHT_T := 2
const AMBUSH_T := 1
const REST_T := 3
## 印章：效果 / 主要来源
const SEALS := {
	"镇纸": ["每场战斗少掉 4 点血", "精英"], "夜灯": ["视野 +1 格", "大赏"], "更漏": ["首领走路概率增长得更慢", "大赏"],
	"拓本": ["打开任何赏都多一个选项", "大赏"], "印鉴": ["被「封」的奖励会显示伏兵的位置", "精英"],
	"朱笔": ["首领战开场，首领少一条词条", "首领"], "蒲团": ["休息点的治疗量翻倍", "精英"],
	"活字盒": ["字匣 +2 格", "大赏"], "宽版": ["版面立刻扩成 3×3（一局只能有一次）", "首领"],
}
## 三幕首领：借用的敌人资源（数值沿用 resources/enemies），名字随主题
const BOSS := {1: "boss_word_demon", 2: "boss_lead_plate", 3: "boss_chaos_press"}
const BOSS_NAME := {"墨池": "墨渊", "熔铸坊": "铸印魔", "潮汐渠": "潮伯", "雷池": "雷公"}
## 首领词条（逐幕加强）：破甲 / 破防 / 朱笔 可以削掉
const BOSS_AFFIX := {1: [["armor", 8], ["shield", 6]], 2: [["armor", 12], ["shield", 8], ["strength", 1]],
	3: [["armor", 16], ["shield", 10], ["strength", 2]]}
const AFFIX_TEXT := {"armor": "护甲（持久盾）+%d", "shield": "开场护盾 +%d", "strength": "力量 +%d"}
const ELITE := "iron_seal"
const FOE_ENEMY := ["ink_spirit", "ember_imp", "paper_guard", "rust_scribe", "bronze_seal"]
## 被追上的位置减益（机关格本身及上下左右）
const SPOT_DEBUFF := {"纸": "少抽字", "泉": "污染字", "焰": "热度", "炉": "熔字", "流": "淹格", "潮": "淹格", "闸": "首领护盾", "桩": "首领护盾"}
const DEBUFF_TEXT := {"先手": "首领先手：第一回合首领先行动", "少抽字": "开局少抽 1 枚字", "污染字": "字袋混进 1 枚污染字（本场）",
	"热度": "开局热度 +3", "熔字": "开局 1 枚字被熔掉（本场）", "淹格": "字盘 1 格被水淹，第一回合不能放字", "首领护盾": "首领开局护盾 +8"}

var rng := RandomNumberGenerator.new()
var relic_rng := RandomNumberGenerator.new()  ## 遗物单独用一条随机数，不打乱地图 / 赏 / 印章的随机序列
var boss_rng := RandomNumberGenerator.new()   ## 首领走不走单独一条随机数
var run_seed := 0
var act := 1
var themes: Array = []
var m: Dictionary = {}          ## 当前幕地图（MapGen.generate 的结果）
var pos := 0
var t := 0                      ## 时间（步）
var steps := 0                  ## 玩家实际走了几步（加速）
var explored := {}
var visible := {}
var taken := {}                 ## 已拿走的赏 / 已击败的敌 / 已拾的散字 / 已用的休息点
var amb_done := {}              ## 已打过的伏兵编号
var revealed_amb := {}          ## 情报揭示的伏兵
var used := {}                  ## 机关使用次数
var boss := 0
var stir = null
var rise = null
var miss := 0                   ## 首领起身后连续没走的步数（伪随机累计）
var stun := 0
var alarm := false
var halt_done := false          ## 急停已触发
var boss_down := false          ## 本幕首领已被击败：不再追击，可以继续探索，随时结束本幕
var rush_left := 5              ## 急速剩余步数
var half_step := 0.0
var ink := START_INK
var tray: Array = []
var plate: Array = []
var plate_n := 2
var plate_4 := false            ## 本局已扩到 4×4
var wide_used := false
var seals: Array = []
var active := {}                ## 版面上正在生效的词谱词
var flip_used := false
var power_used := false
var wish_used := false          ## 随身许愿机本幕已用
var repeat_used := false
var spent := 0                  ## 本幕在商店花的金币
var buyback: Array = []
var panels: Array = []          ## 待处理的面板，顶上的先显示
var fight := {}                 ## 待开战的遭遇
var over := false
var won := false
var lines: Array = []
var alerts: Array = []          ## 待弹出的首领提醒 [标题, 正文]
var boss_trail: Array = []      ## 首领走过、界面还没播放的格（棋子逐格移动用）


## 开一局：v03 起始字袋（12 枚），三幕主题不重复；挂到 GameState.expedition
static func start(seed_value: int = -1) -> Expedition:
	GameState.start_new_run("v03")
	var ex := Expedition.new()
	if seed_value >= 0:
		ex.rng.seed = seed_value
	else:
		ex.rng.randomize()
	ex.run_seed = ex.rng.randi_range(1, 1 << 30)
	ex.relic_rng.seed = ex.run_seed ^ 0x5E1C
	ex.boss_rng.seed = ex.run_seed ^ 0xB055
	ex.themes = MapGen.THEME_ORDER.duplicate()
	for i in range(ex.themes.size() - 1, 0, -1):
		var j := ex.rng.randi_range(0, i)
		var tmp = ex.themes[i]
		ex.themes[i] = ex.themes[j]
		ex.themes[j] = tmp
	ex._resize_plate(2)
	GameState.expedition = ex
	ex.load_act(1)
	return ex


func load_act(n: int) -> void:
	act = n
	m = MapGen.generate(run_seed + n * 1009, themes[(n - 1) % themes.size()])
	pos = m.start
	t = 0
	steps = 0
	explored.clear()
	taken.clear()
	amb_done.clear()
	revealed_amb.clear()
	used.clear()
	boss = m.lair
	stir = null
	rise = null
	miss = 0
	stun = 0
	alarm = false
	halt_done = false
	boss_down = false
	rush_left = 5
	half_step = 0.0
	flip_used = false
	power_used = false
	wish_used = false
	repeat_used = false
	spent = 0
	fight = {}
	panels.clear()
	alerts.clear()
	boss_trail.clear()
	update_vision()
	_log("第 %d 幕 · %s：首领【%s】睡在远处的巢穴里" % [act, m.tn, m.TH.boss])


# ---------------------------------------------------------------- 派生数值
func has(w: String) -> bool:
	return active.has(w)


func has_seal(s: String) -> bool:
	return seals.has(s)


func tray_cap() -> int:
	return TRAY_CAP + (1 if has("收放") else 0) + (2 if has_seal("活字盒") else 0)


func vision() -> int:
	return MapGen.P.vision + (1 if has("开灯") else 0) + (1 if has_seal("夜灯") else 0)


## 首领这一步走的概率（伪随机）：基线 = 0.35 + 0.05 × 起身后的步数（冷却 / 更漏让增长变慢）；
## 没走就累计：概率 = 基线 × (连续没走的步数 + 1)，最高 100%；走了一步就回到基线
func move_base() -> float:
	if not awake():
		return 0.0
	return minf(1.0, MapGen.P.p0 + MapGen.P.pGrow * acc_scale() * maxi(0, t - int(rise)))


func move_chance() -> float:
	return minf(1.0, move_base() * (miss + 1))


func acc_scale() -> float:
	return (0.5 if has("冷却") else 1.0) * (0.5 if has_seal("更漏") else 1.0)


func awake() -> bool:
	return not boss_down and rise != null and t >= rise


func wake_time() -> int:
	return int(m.wake) + (4 if has("停息") else 0)


func mech_at(k: int) -> Dictionary:
	return m.mech.get(k, {})


func gate_shut(k: int, at_t: int) -> bool:
	return m.mech.has(k) and not has("停电") and MapGen.shut(m.mech[k], at_t)


## 玩家能否走进 k（墨障算可走：撞上时花墨冲开）；电流过载能穿过关着的门
func can_enter(k: int) -> bool:
	if m.ink[k] != 0:
		return false
	return not gate_shut(k, t) or has("电流过载")


func boss_mask() -> PackedByteArray:
	return MapGen.mask_of(func(k): return m.ink[k] == 0 and not gate_shut(k, t))


# ---------------------------------------------------------------- 迷雾
## 视野：沿可走路线 vision 步以内，外加一圈（看见墙）；「左右」再加十字 4 格
func update_vision() -> void:
	visible.clear()
	var mk := MapGen.mask_of(func(k): return m.ink[k] == 0 and not m.obst.has(k))
	var d := MapGen.bfs(mk, pos)
	for k in MapGen.N:
		if d[k] <= vision():
			visible[k] = true
			for n in MapGen.nbrs(k):
				visible[n] = true
	if has("左右"):
		var p := MapGen.rc(pos)
		for dir in MapGen.DIRS:
			for i in range(1, 5):
				var q: Vector2i = p + dir * i
				if not MapGen.inb(q.x, q.y):
					break
				visible[MapGen.kk(q.x, q.y)] = true
				if m.ink[MapGen.kk(q.x, q.y)] != 0:
					break
	for k in visible:
		explored[k] = true


## 引导点（每类第一个）隔着迷雾发光
func is_beacon(k: int) -> bool:
	return m.node.has(k) and m.node[k].get("beacon", false)


# ---------------------------------------------------------------- 时间与首领
## 过一步：首领到点 / 被大赏惊动 / 有人从巢穴 2 步内经过 → 惊动，缓冲 4 步后起身，沿最短路追
## 返回 true = 被追上
func tick() -> bool:
	t += 1
	if boss_down:
		return false
	if stir == null:
		var near := MapGen.bfs(MapGen.mask_of(func(k): return can_enter(k) and not m.obst.has(k)), m.lair)[pos] <= 2
		if t >= wake_time() or alarm or near:
			stir = t
			rise = t + MapGen.P.buffer
			_log("首领被惊动了：%d 步后起身" % MapGen.P.buffer)
			var why := "你打开了大赏" if alarm else ("你从巢穴旁经过" if near else "它睡醒了")
			alerts.append(["首领被惊动了", "%s。首领【%s】%d 步后起身，然后会沿最短路追你。
地图上的红色【%s】就是它。" % [why, m.TH.boss, MapGen.P.buffer, m.TH.boss]])
	if not awake():
		return false
	if not halt_done:
		halt_done = true
		alerts.append(["首领起身了", "首领【%s】开始追你，现在相距 %d 步。
战斗、休息都要花时间；被追上的位置会给首领战减益，主动迎战则不会。" % [m.TH.boss, MapGen.bfs(boss_mask(), boss)[pos]]])
		if has("急停"):
			stun += 2
			_log("急停：首领起身后先原地停 2 步")
	if stun > 0:
		stun -= 1
		return false
	var bm := boss_mask()
	if boss_rng.randf() < move_chance():
		miss = 0
		var nx := MapGen.step_toward(bm, boss, pos)
		if nx != boss:
			boss = nx
			boss_trail.append(boss)
	else:
		miss += 1
	return MapGen.bfs(bm, boss)[pos] <= 1


## 连续过 n 步，途中被追上就停下并准备首领战
func advance(n: int) -> void:
	for i in n:
		if tick():
			_caught()
			return


func _caught() -> void:
	if has("反转") and not flip_used:
		flip_used = true
		var bm := boss_mask()
		for i in 5:
			var d := MapGen.bfs(bm, pos)
			var best := boss
			for nb in MapGen.nbrs(boss):
				if bm[nb] != 0 and d[nb] > d[best]:
					best = nb
			boss = best
			boss_trail.append(boss)
		_log("反转：把首领推回 5 格，不开战（每幕一次）")
		return
	fight = _boss_encounter(true)
	_log("首领追上来了！")


func _boss_encounter(caught: bool) -> Dictionary:
	var debuff := ""
	if caught and not has("反超"):
		debuff = location_debuff(pos)
	return {"kind": "boss", "k": boss, "name": BOSS_NAME.get(m.tn, "首领"), "g": m.TH.boss, "caught": caught, "debuff": debuff}


## 被追上的位置：凹槽里 → 首领先手；主题机关旁 → 对应减益；空地无
func location_debuff(k: int) -> String:
	if m.pocket.has(k):
		return "先手"
	for c in [k] + MapGen.nbrs(k):
		var mc := mech_at(c)
		if not mc.is_empty() and SPOT_DEBUFF.has(mc.g):
			return SPOT_DEBUFF[mc.g]
	return ""


# ---------------------------------------------------------------- 移动
func busy() -> bool:
	return over or not panels.is_empty() or not fight.is_empty()


func can_step(k: int) -> bool:
	return not busy() and MapGen.man(k, pos) == 1 and can_enter(k)


func move(k: int) -> bool:
	if not can_step(k):
		return false
	if m.obst.has(k):
		# 墨障：花 2 墨冲开（爆破免费）；墨不够就以血冲开；防爆免伤
		if has("爆破"):
			_log("爆破：冲开墨障，不花墨")
		elif ink >= BARRIER_INK:
			ink -= BARRIER_INK
			_log("冲开墨障：墨 −%d" % BARRIER_INK)
		elif has("防爆"):
			_log("防爆：墨不够也能冲开墨障，不掉血")
		else:
			_hurt(BARRIER_HP, "墨不够，硬冲墨障")
		m.obst.erase(k)
	if gate_shut(k, t):
		_hurt(4, "电流过载：穿过关着的%s" % mech_at(k).g)
	pos = k
	steps += 1
	var cost := 1
	if has("加速") and steps % 10 == 0:
		cost = 0
		_log("加速：这一步免费，首领不动")
	elif has("急速") and awake() and rush_left > 0:
		rush_left -= 1
		half_step += 0.5
		cost = 1 if half_step >= 1.0 else 0
		if cost == 1:
			half_step -= 1.0
	cost += _step_mech()
	advance(cost)
	update_vision()
	if fight.is_empty():
		_check_boss_adjacent()
	if fight.is_empty():
		enter_cell()
	return true


## 踩上机关：返回额外耗步
func _step_mech() -> int:
	var mc := mech_at(pos)
	if mc.is_empty():
		return 0
	match mc.g:
		"泉":
			if not used.has(pos):
				used[pos] = 1
				ink += 3
				_log("墨泉：墨 +3")
		"纸":
			if not has("清流"):
				return 1
		"焰":
			if has("防火") or has("防爆"):
				_log("防火：烈焰格不掉血")
			else:
				_hurt(3, "烈焰格")
		"桩":
			var uses := 2 if has("放电") else 1
			if awake() and int(used.get(pos, 0)) < uses:
				used[pos] = int(used.get(pos, 0)) + 1
				stun += 3
				_log("蓄电桩：把首领定住 3 步")
		"流":
			if int(used.get(pos, 0)) < 1:
				used[pos] = 1
				_slide(mc.dir)
	return 0


## 水流：顺着箭头滑 3 格（流速 +2），撞墙停；不耗步
func _slide(dir: Vector2i) -> void:
	var p := MapGen.rc(pos)
	var n := 3 + (2 if has("流速") else 0)
	for i in n:
		var q: Vector2i = p + dir
		if not MapGen.inb(q.x, q.y) or not can_enter(MapGen.kk(q.x, q.y)) or m.obst.has(MapGen.kk(q.x, q.y)):
			break
		p = q
	pos = MapGen.kk(p.x, p.y)
	_log("顺着水流滑出去")


func _hurt(n: int, why: String) -> void:
	var real := mini(n, GameState.player_hp - 1)
	if real > 0:
		GameState.damage(real)
	_log("%s：气血 −%d" % [why, real])


func _check_boss_adjacent() -> void:
	if awake() and MapGen.bfs(boss_mask(), boss)[pos] <= 1:
		_caught()


# ---------------------------------------------------------------- 进格
## 走到 pos 上：伏兵领地 → 必须开战；明敌 / 精英 → 开战；赏 / 休 / 市 / 谜 / 熔炉 → 面板；散字 → 自动拾
func enter_cell() -> void:
	var terr: Dictionary = m.get("terr", {})
	if terr.has(pos) and not amb_done.has(terr[pos]):
		fight = {"kind": "ambush", "k": pos, "amb": terr[pos], "name": "伏兵", "g": ""}
		_log("伏兵！走进了它的领地")
		return
	var o: Dictionary = m.node.get(pos, {})
	var tp: String = o.get("t", "")
	if tp in ["敌", "险"] and not taken.has(pos):
		fight = {"kind": "elite" if tp == "险" else "foe", "k": pos, "g": o.get("g", "甲"), "name": "守口精英" if tp == "险" else "明敌"}
		return
	if taken.has(pos):
		return
	match tp:
		"大", "中", "小":
			if sealed(pos):
				return
			push_panel({"kind": "loot", "tier": tp, "options": loot_options(tp)})
			if tp == "大":
				alarm = true
				_log("打开大赏，惊动了首领")
		"休":
			push_panel({"kind": "rest"})
		"市":
			push_panel({"kind": "shop", "offers": shop_offers()})
		"谜":
			push_panel({"kind": "event", "event": _roll_event()})
	if m.glyph.has(pos):
		pickup()
	var mc := mech_at(pos)
	if not mc.is_empty() and mc.g == "炉" and int(used.get(pos, 0)) < (2 if has("精炼") else 1):
		push_panel({"kind": "forge", "k": pos})


## 这一格是不是某个伏兵本身；返回伏兵编号，不是返回 -1
func ambush_index_at(k: int) -> int:
	var ambs: Array = m.get("ambush", [])
	for i in ambs.size():
		if ambs[i].k == k:
			return i
	return -1


## 伏兵位置是否已知：情报揭示，或「印鉴」（被封的奖励会显示伏兵的位置）
func revealed_amb_at(k: int) -> bool:
	var ambs: Array = m.get("ambush", [])
	for i in ambs.size():
		if ambs[i].k == k and not amb_done.has(i) and (revealed_amb.has(i) or has_seal("印鉴")):
			return true
	return false


## 被封：落在未打过的伏兵领地里
func sealed(k: int) -> bool:
	var terr: Dictionary = m.get("terr", {})
	return terr.has(k) and not amb_done.has(terr[k])


## 散字被看守：上下左右有未击败的明敌 / 精英；返回看守者
func guard_of(k: int) -> String:
	for n in MapGen.nbrs(k):
		var o: Dictionary = m.node.get(n, {})
		if o.get("t", "") in ["敌", "险"] and not taken.has(n):
			return "精英" if o.t == "险" else "明敌【%s】" % o.g
	return ""


func pickup() -> bool:
	if not m.glyph.has(pos) or taken.has(pos) or sealed(pos):
		return false
	var gd := guard_of(pos)
	if not gd.is_empty():
		_log("散字【%s】被%s看守着，拾不走" % [m.glyph[pos], gd])
		return false
	if tray.size() >= tray_cap():
		_log("字匣满了（%d 格），拾不了【%s】" % [tray_cap(), m.glyph[pos]])
		return false
	taken[pos] = true
	var g: String = m.glyph[pos]
	tray.append(g)
	_log("拾得【%s】" % g)
	if has("重复") and not repeat_used:
		repeat_used = true
		gain_glyph(g, "重复：多复制一枚")
	return true


## 发字：先进字匣；字匣满了进字袋；都满了折 8 金币
func gain_glyph(g: String, why := "") -> void:
	if Database.get_character_by_glyph(g) == null:
		return
	var note := ("%s：" % why) if not why.is_empty() else ""
	if tray.size() < tray_cap():
		tray.append(g)
		_log("%s【%s】进字匣" % [note, g])
	elif GameState.deck_size() < DECK_CAP:
		GameState.add_character(Database.get_character_by_glyph(g))
		_log("%s字匣满了，【%s】直接进字袋" % [note, g])
	else:
		GameState.add_gold(8)
		_log("%s字匣、字袋都满了，【%s】折成 8 金币" % [note, g])


func push_panel(p: Dictionary) -> void:
	panels.append(p)


func pop_panel() -> void:
	if not panels.is_empty():
		panels.pop_back()


func top_panel() -> Dictionary:
	return panels.back() if not panels.is_empty() else {}


# ---------------------------------------------------------------- 发字的池子
## 发字沿用原游戏字库：与战后奖励 / 商店同一套筛选（不含污染字、待设计、敌方字、彩蛋字），
## 稀有度规则同 reward_screen：普通奖励 ≤2，首领级 ≥1。主题只做倾向，不另造字池。
func reward_pool() -> Array:
	var pool: Array = []
	for cd in Database.characters.values():
		if not cd.is_pollution and not cd.pending_design and not cd.tags.has("enemy") and not cd.tags.has("彩蛋"):
			pool.append(cd)
	return pool


func owned_glyphs() -> Dictionary:
	var out := {}
	for c in GameState.deck:
		out[c.glyph()] = true
	for g in tray:
		out[g] = true
	for row in plate:
		for g in row:
			if not str(g).is_empty():
				out[g] = true
	return out


func formable(cd: CharacterData, owned: Dictionary) -> bool:
	for w in Database.words.values():
		if w.glyphs.has(cd.glyph) and w.glyphs.all(func(g): return g == cd.glyph or owned.has(g)):
			return true
	return false


## tier：0 普通（稀有度 ≤2，同战后奖励 / 商店）/ 1 稀有（2～3）/ 2 首领级（≥1，同幕末大奖）
## theme=true 只取本幕主题字
func roll_glyph(tier := 0, theme := false, r: RandomNumberGenerator = null) -> String:
	var owned := owned_glyphs()
	var lo: int = [0, 2, 1][tier]
	var hi: int = [2, 4, 4][tier]
	var pool: Array = reward_pool().filter(func(cd): return cd.rarity >= lo and cd.rarity <= hi and (not theme or m.TH.glyphs.contains(cd.glyph)))
	if pool.is_empty():
		pool = reward_pool().filter(func(cd): return cd.rarity <= 2)
	var ok: Array = pool.filter(func(cd): return formable(cd, owned))
	if ok.is_empty():
		ok = pool
	var rr := r if r != null else rng
	return ok[rr.randi_range(0, ok.size() - 1)].glyph


## 成对的字：取游戏词库里一个两字词，两个字都在字库里
func roll_pair() -> Array:
	var base := {}
	for cd in reward_pool():
		if cd.rarity <= 2:
			base[cd.glyph] = true
	var ws: Array = Database.words.values().filter(func(w): return w.glyphs.size() == 2 and base.has(w.glyphs[0]) and base.has(w.glyphs[1]))
	var w: WordData = ws[rng.randi_range(0, ws.size() - 1)]
	return [w.glyphs[0], w.glyphs[1]]


# ---------------------------------------------------------------- 赏
## 小赏二选一、中赏 / 大赏三选一；重金让大赏多一个，拓本让所有赏多一个
func loot_options(tier: String) -> Array:
	var opts: Array = []
	match tier:
		"小":
			opts.append({"kind": "glyphs", "glyphs": [roll_glyph(0, true)]})
			opts.append({"kind": "glyphs", "glyphs": [roll_glyph(0, false)]})
			opts.append({"kind": "gold", "gold": 8})
		"中":
			opts.append({"kind": "glyphs", "glyphs": roll_pair()})
			opts.append({"kind": "glyphs", "glyphs": [roll_glyph(1)]})
			opts.append({"kind": "intel"})
			opts.append({"kind": "gold", "gold": 15})
		"大":
			var free_seals: Array = SEALS.keys().filter(func(s): return SEALS[s][1] == "大赏" and not seals.has(s))
			if not free_seals.is_empty():
				opts.append({"kind": "seal", "seal": free_seals[rng.randi_range(0, free_seals.size() - 1)]})
			opts.append({"kind": "glyphs", "glyphs": [roll_glyph(2), roll_glyph(0)]})
			if plate_n == 3 and not plate_4:
				opts.append({"kind": "plate4"})
			opts.append({"kind": "glyphs", "glyphs": roll_pair()})
			opts.append({"kind": "gold", "gold": 25})
			opts.append({"kind": "glyphs", "glyphs": [roll_glyph(2, true)]})
			opts.append({"kind": "intel"})
	var n := 2 if tier == "小" else 3
	if tier == "大" and has("重金"):
		n += 1
	if has_seal("拓本"):
		n += 1
	return opts.slice(0, mini(n, opts.size()))


func loot_text(o: Dictionary) -> String:
	match o.kind:
		"glyphs": return "字：" + "、".join(o.glyphs.map(func(g): return "【%s】" % g))
		"gold": return "❖ +%d" % o.gold
		"intel": return "情报：揭示最近的一个伏兵，或照亮周围 3 步"
		"seal": return "印章「%s」：%s" % [o.seal, SEALS[o.seal][0]]
		"plate4": return "版面扩成 4×4（一局一次）"
	return ""


func choose_loot(i: int) -> void:
	var p := top_panel()
	if p.get("kind", "") != "loot" or i < 0 or i >= p.options.size():
		return
	var o: Dictionary = p.options[i]
	pop_panel()
	taken[pos] = true
	match o.kind:
		"glyphs":
			for g in o.glyphs:
				gain_glyph(g, "开赏")
		"gold":
			GameState.add_gold(int(o.gold))
			_log("开赏：❖ +%d" % o.gold)
		"intel":
			_intel()
		"seal":
			add_seal(o.seal)
		"plate4":
			plate_4 = true
			_resize_plate(4)
			_log("版面扩成 4×4")


func _intel() -> void:
	var best := -1
	var ambs: Array = m.get("ambush", [])
	for i in ambs.size():
		if not amb_done.has(i) and not revealed_amb.has(i) and (best == -1 or MapGen.man(ambs[i].k, pos) < MapGen.man(ambs[best].k, pos)):
			best = i
	if best >= 0:
		revealed_amb[best] = true
		_log("情报：发现一处伏兵的位置")
		return
	for k in MapGen.N:
		if MapGen.man(k, pos) <= 3:
			explored[k] = true
	_log("情报：照亮周围 3 步")


# ---------------------------------------------------------------- 印章
## 一局最多 3 个；满了弹替换面板
func add_seal(s: String) -> void:
	if seals.has(s):
		return
	if seals.size() >= SEAL_CAP:
		push_panel({"kind": "seal_swap", "seal": s})
		return
	_take_seal(s)


func _take_seal(s: String) -> void:
	seals.append(s)
	_log("得到印章「%s」：%s" % [s, SEALS[s][0]])
	if s == "宽版" and not wide_used and plate_n < 3:
		wide_used = true
		_resize_plate(3)
		_log("宽版：版面扩成 3×3")


## index = 替换掉的印章下标；-1 = 不要新印章
func swap_seal(index: int) -> void:
	var p := top_panel()
	if p.get("kind", "") != "seal_swap":
		return
	pop_panel()
	if index >= 0 and index < seals.size():
		_log("丢掉印章「%s」" % seals[index])
		seals.remove_at(index)
		_take_seal(p.seal)
	update_vision()


# ---------------------------------------------------------------- 遗物
## 来源：熔炉许愿（见 forge）、商店货架；卖回商店拿一半价钱。遗物管战斗，不占印章格
func _grant_relic(id: String, why: String) -> bool:
	if not GameState.add_relic(id):
		return false
	_log("%s：得到遗物%s" % [why, Relics.text(id)])
	if Relics.needs_bind(id) and not GameState.deck.is_empty():
		push_panel({"kind": "relic_bind", "relic": id})
	return true


func sell_relic(id: String) -> bool:
	if top_panel().get("kind", "") != "shop" or not GameState.remove_relic(id):
		return false
	var gold := Relics.sell_price(id)
	GameState.add_gold(gold)
	_log("商店：卖掉遗物「%s」，❖ +%d" % [Relics.name_of(id), gold])
	return true


## 绑定类遗物：从字袋挑一枚字（按字形挑，绑到其中一枚实体）
func bind_relic(glyph_id: String) -> bool:
	var p := top_panel()
	if p.get("kind", "") != "relic_bind":
		return false
	if not GameState.bind_relic(p.relic, glyph_id):
		return false
	pop_panel()
	_log("「%s」绑定在【%s】上" % [Relics.name_of(p.relic), Database.get_character(glyph_id).glyph])
	return true


## 从某来源里挑一个还没有的印章（精英 / 首领）
func roll_seal(source: String) -> String:
	var free: Array = SEALS.keys().filter(func(s): return SEALS[s][1] == source and not seals.has(s) and not (s == "宽版" and wide_used))
	return free[rng.randi_range(0, free.size() - 1)] if not free.is_empty() else ""


# ---------------------------------------------------------------- 休息点
## 治疗 / 删字 / 修饰 三选一，耗 3 步，每个休息点只能用一次；清洗额外清 1 枚污染字
func rest_heal_amount() -> int:
	return int(round(GameState.player_max_hp * 0.3)) * (2 if has_seal("蒲团") else 1) + Relics.rest_bonus()


func rest(choice: String, glyph_id := "") -> bool:
	if top_panel().get("kind", "") != "rest":
		return false
	match choice:
		"heal":
			GameState.heal(rest_heal_amount())
			_log("休息：气血 +%d" % rest_heal_amount())
		"remove":
			if not GameState.remove_character_id(glyph_id):
				return false
			_log("休息：从字袋删掉【%s】" % Database.get_character(glyph_id).glyph)
		"gild":
			if not _gild(glyph_id):
				return false
		_:
			return false
	if has("清洗"):
		for c in GameState.deck:
			if c.data.is_pollution:
				GameState.remove_by_uid(c.uid)
				_log("清洗：额外清掉 1 枚污染字")
				break
	pop_panel()
	taken[pos] = true
	advance(REST_T)
	return true


## 修饰 = 镀金：参与多字词 +1 金币（GDD）；精金额外镀一枚
func _gild(glyph_id: String) -> bool:
	var n := 2 if has("精金") else 1
	var done := 0
	for c in GameState.deck:
		if c.id() == glyph_id and not c.gilded and done < n:
			c.gilded = true
			done += 1
	if done == 0:
		return false
	_log("镀金【%s】×%d：参与多字词 +1 金币" % [Database.get_character(glyph_id).glyph, done])
	return true


# ---------------------------------------------------------------- 商店
## 买字 / 回购 / 删字 / 修饰 / 治疗（GDD 价位）；收购 7 折、合资 −5、投币每买一样返 1、回购半价
func shop_offers() -> Array:
	if m.has("shops") and m.shops.has(pos):
		return m.shops[pos]
	var offers: Array = []
	# 同原商店：三枚 ≤2 稀有度的字，各 12～15 金币
	for i in 3:
		offers.append({"kind": "glyph", "glyph": roll_glyph(0), "base": rng.randi_range(12, 15)})
	offers.append({"kind": "remove", "base": rng.randi_range(16, 20)})
	offers.append({"kind": "gild", "base": rng.randi_range(28, 35)})
	offers.append({"kind": "heal", "base": rng.randi_range(10, 14)})
	# 遗物货架：每家一件，用遗物自己的随机数（不打乱原来的货）
	for id in Relics.roll_choices(GameState.relics, relic_rng):
		offers.append({"kind": "relic", "relic": id, "base": Relics.price(id)})
	if not m.has("shops"):
		m["shops"] = {}
	m.shops[pos] = offers
	return offers


func price(o: Dictionary) -> int:
	var p: int = o.base
	match o.kind:
		"glyph":
			if has("收购"):
				p = int(ceil(p * 0.7))
		"buyback":
			p = int(ceil(p * 0.5))
		"remove", "gild":
			if has("合资"):
				p = maxi(0, p - 5)
	return p


func buyback_offers() -> Array:
	if not has("回购"):
		return []
	return buyback.map(func(g): return {"kind": "buyback", "glyph": g, "base": 13})


## index 指 shop_offers() 后接 buyback_offers() 的下标
func buy(index: int, glyph_id := "") -> bool:
	var offers: Array = shop_offers()
	var all_offers: Array = offers + buyback_offers()
	if index < 0 or index >= all_offers.size():
		return false
	var o: Dictionary = all_offers[index]
	var cost := price(o)
	if GameState.gold < cost:
		return false
	match o.kind:
		"relic":
			if GameState.has_relic(o.relic):
				return false
		"glyph", "buyback":
			if tray.size() >= tray_cap() and GameState.deck_size() >= DECK_CAP:
				return false
		"remove":
			if not GameState.remove_character_id(glyph_id):
				return false
		"gild":
			if not _gild(glyph_id):
				return false
	GameState.spend_gold(cost)
	spent += cost
	match o.kind:
		"relic":
			# 先移掉货架，再拿遗物（绑定面板压在商店上面）
			offers.remove_at(index)
			index = -1
			_grant_relic(o.relic, "商店")
		"glyph":
			gain_glyph(o.glyph, "买字")
		"buyback":
			buyback.erase(o.glyph)
			gain_glyph(o.glyph, "回购")
		"remove":
			_log("商店：删掉【%s】" % Database.get_character(glyph_id).glyph)
		"heal":
			GameState.heal(int(round(GameState.player_max_hp * 0.3)))
			_log("商店：治疗")
	if has("投币"):
		GameState.add_gold(1)
	if index >= 0 and index < offers.size():
		offers.remove_at(index)
	return true


func leave_panel() -> void:
	var p := top_panel()
	if p.get("kind", "") in ["shop", "forge", "event"]:
		pop_panel()


# ---------------------------------------------------------------- 熔炉
## 投两个字匣里的字熔成一个稀有字；炼金 +4 金币；回收：消耗的字一半机会回到字匣
## 许愿：投 2～3 个字。和某件遗物相关的字越多，越可能熔出那件遗物（见 Relics.wish_odds）；
## 没熔出遗物就照旧熔成一个稀有字。c = 第三个字的下标（-1 = 只投两个）
func forge(a: int, b: int, c: int = -1) -> bool:
	var p := top_panel()
	var idx: Array = [a, b] + ([c] if c >= 0 else [])
	if p.get("kind", "") != "forge":
		return false
	for i in idx:
		if i < 0 or i >= tray.size() or idx.count(i) > 1:
			return false
	var gs: Array = idx.map(func(i): return tray[i])
	var order: Array = idx.duplicate()
	order.sort()
	order.reverse()
	for i in order:
		tray.remove_at(i)
	used[p.k] = int(used.get(p.k, 0)) + 1
	if p.get("wish", false):
		wish_used = true
	pop_panel()
	var named := "".join(gs.map(func(g): return "【%s】" % g))
	var wished := Relics.wish_roll(gs, GameState.relics, relic_rng)
	if not wished.is_empty():
		_grant_relic(wished, "熔炉许愿：%s" % named)
	else:
		var out := roll_glyph(1)
		_log("熔炉：%s熔成【%s】" % [named, out])
		gain_glyph(out)
	if has("炼金"):
		GameState.add_gold(4)
		_log("炼金：❖ +4")
	_recycle(gs)
	return true


func _recycle(gs: Array) -> void:
	if not has("回收"):
		return
	for g in gs:
		if rng.randf() < 0.5 and tray.size() < tray_cap():
			tray.append(g)
			_log("回收：【%s】回到字匣" % g)


# ---------------------------------------------------------------- 谜
const EVENTS := [
	{"title": "残页", "text": "墨渍里夹着半页旧谱。", "a": "撕下来（气血 −6，得一枚稀有字）", "b": "不碰它"},
	{"title": "污墨", "text": "一砚发臭的墨，摊主说能换钱。", "a": "收下（❖ +18，字袋混进 1 枚污染字）", "b": "走开"},
	{"title": "雾中灯", "text": "远处有人提灯。", "a": "跟上去（耗 2 步，地图迷雾散开一大片）", "b": "不跟"},
]


func _roll_event() -> int:
	return rng.randi_range(0, EVENTS.size() - 1)


func choose_event(take: bool) -> void:
	var p := top_panel()
	if p.get("kind", "") != "event":
		return
	pop_panel()
	taken[pos] = true
	if not take:
		return
	match int(p.event):
		0:
			_hurt(6, "残页")
			gain_glyph(roll_glyph(1), "残页")
		1:
			GameState.add_gold(18)
			GameState.add_character(Database.get_character("pollution"))
			_log("污墨：❖ +18，字袋混进 1 枚污染字")
		2:
			for k in MapGen.N:
				if MapGen.man(k, pos) <= 5:
					explored[k] = true
			_log("雾中灯：迷雾散开")
			advance(2)


# ---------------------------------------------------------------- 字匣 / 字袋 / 版面
## 一个字同一时间只在一个地方。字匣 → 字袋（上限 20）；字匣 → 版面空格免费；版面取字耗 1 步（收回免）
func tray_to_deck(i: int) -> bool:
	if busy() or i < 0 or i >= tray.size() or GameState.deck_size() >= DECK_CAP:
		return false
	var g: String = tray.pop_at(i)
	GameState.add_character(Database.get_character_by_glyph(g))
	_log("【%s】放进字袋" % g)
	return true


## 丢字：进回购清单；转化 = 换一个同系统的随机字
func discard(i: int, convert := false) -> bool:
	if busy() or i < 0 or i >= tray.size():
		return false
	var g: String = tray.pop_at(i)
	if convert and has("转化"):
		var sys := Lexicon.sys_of(g)
		var pool: Array = reward_pool().filter(func(cd): return cd.glyph != g and Lexicon.sys_of(cd.glyph) == sys)
		if not pool.is_empty():
			var n: String = pool[rng.randi_range(0, pool.size() - 1)].glyph
			tray.append(n)
			_log("转化：【%s】换成【%s】" % [g, n])
			return true
	buyback.append(g)
	_recycle([g])
	_log("丢掉【%s】" % g)
	return true


func place(i: int, p: Vector2i) -> bool:
	if busy() or i < 0 or i >= tray.size() or p.x >= plate_n or p.y >= plate_n or not str(plate[p.x][p.y]).is_empty():
		return false
	plate[p.x][p.y] = tray.pop_at(i)
	refresh_active()
	return true


func take_back(p: Vector2i) -> bool:
	if busy() or p.x >= plate_n or p.y >= plate_n or str(plate[p.x][p.y]).is_empty() or tray.size() >= tray_cap():
		return false
	tray.append(plate[p.x][p.y])
	plate[p.x][p.y] = ""
	refresh_active()
	if not has("收回"):
		advance(1)
		_check_boss_adjacent()
	return true


func _resize_plate(n: int) -> void:
	var old := plate
	plate = []
	for r in n:
		var row: Array = []
		for c in n:
			row.append(old[r][c] if r < old.size() and c < old[r].size() else "")
		plate.append(row)
	plate_n = n
	refresh_active()


## 版面变了：重算生效的词；精力即时改气血上限
func refresh_active() -> void:
	var before := active.duplicate()
	active = Lexicon.scan(plate).words
	if active.has("精力") != before.has("精力"):
		var d := 8 if active.has("精力") else -8
		GameState.player_max_hp += d
		GameState.player_hp = clampi(GameState.player_hp + maxi(0, d), 1, GameState.player_max_hp)
		EventBus.hp_changed.emit(GameState.player_hp, GameState.player_max_hp)
	for w in active:
		if not before.has(w):
			_log("版面生效「%s」：%s" % [w, Lexicon.WORDS[w][1]])
	if m.has("ink"):
		update_vision()


# ---------------------------------------------------------------- 首领：主动迎战 / 超能力 / 幕间
## 主动迎战：首领醒着且在 2 步内，或站在巢穴旁；不吃位置减益
func can_confront() -> bool:
	if busy() or boss_down:
		return false
	var d := MapGen.bfs(boss_mask(), boss)[pos]
	return d <= 2


func confront() -> bool:
	if not can_confront():
		return false
	fight = _boss_encounter(false)
	_log("主动迎战首领")
	return true


## 随身许愿机：开局就带着，每幕一次，在地图任意位置打开许愿面板（规则同熔炉，字匣里要有 2 个字）
const WISH_KEY := -1


func can_wish() -> bool:
	return not wish_used and not busy() and tray.size() >= 2


func open_wish() -> bool:
	if not can_wish():
		return false
	push_panel({"kind": "forge", "k": WISH_KEY, "wish": true})
	return true


func can_power() -> bool:
	return has("超能力") and not power_used and awake() and not busy()


func use_power() -> bool:
	if not can_power():
		return false
	power_used = true
	stun += 6
	_log("超能力：把首领定住 6 步")
	return true


## 首领接下来要走的路（界面画虚线用）：沿最短路追向玩家，最多 n 格，不含首领所在格
func boss_path(n := 6) -> Array:
	var out: Array = []
	if not awake():
		return out
	var bm := boss_mask()
	var cur := boss
	for i in n:
		var nx := MapGen.step_toward(bm, cur, pos)
		if nx == cur or nx == pos:
			break
		out.append(nx)
		cur = nx
	return out


## 首领状态（界面用）：睡着不报确切时间；惊动后倒计时；追击时报距离
## 首领棋子是否显示在地图上：被惊动以后，或者它所在的格在视野里 / 去过
func boss_revealed() -> bool:
	if boss_down:
		return false
	return stir != null or visible.has(boss) or explored.has(boss)


func boss_status() -> String:
	if boss_down:
		return "首领已败 · 可以继续探索"
	if stir == null:
		return "首领沉睡"
	if not awake():
		return "首领惊动 · %d 步后起身" % (int(rise) - t)
	var d := MapGen.bfs(boss_mask(), boss)[pos]
	return "首领追来 · 相距 %d 步%s" % [d, "（被定住 %d 步）" % stun if stun > 0 else ""]


## 打赢首领后，玩家自己决定什么时候结束本幕（进入幕间结算）
func can_finish_act() -> bool:
	return boss_down and not busy()


func finish_act() -> bool:
	if not can_finish_act():
		return false
	push_panel({"kind": "act_end"})
	_log("第 %d 幕完成" % act)
	return true


## 幕间结算：利息（复利投资逐幕翻倍）+ 投资返还（再投资提高到 50%）
func act_settlement() -> Array:
	var out: Array = []
	if has("利息"):
		var rate := 0.1 * (pow(2, act - 1) if has("复利投资") else 1.0)
		var cap := 8 * (int(pow(2, act - 1)) if has("复利投资") else 1)
		var n := mini(cap, int(floor(GameState.gold * rate)))
		if n > 0:
			out.append(["利息", n])
	if has("投资") and spent > 0:
		var n := int(floor(spent * (0.5 if has("再投资") else 0.2)))
		if n > 0:
			out.append(["投资返还", n])
	return out


func next_act() -> void:
	if top_panel().get("kind", "") != "act_end":
		return
	pop_panel()
	for item in act_settlement():
		GameState.add_gold(int(item[1]))
		_log("%s：❖ +%d" % item)
	if act >= 3:
		over = true
		won = true
		_log("三幕已尽，远征完成")
		return
	load_act(act + 1)


# ---------------------------------------------------------------- 接入 4×4 战斗
## 当前遭遇对应的战斗节点：复制敌人资源，换成本幕的敌名敌字，数值随幕上升
func battle_node() -> MapNodeData:
	var node := MapNodeData.new()
	var base_id := FOE_ENEMY[0]
	var hp_mul := 1.0 + 0.25 * (act - 1)
	match fight.kind:
		"boss":
			node.type = MapNodeData.Type.BOSS
			base_id = BOSS[act]
			hp_mul = 1.0
		"elite":
			node.type = MapNodeData.Type.ELITE
			base_id = ELITE
		"ambush":
			node.type = MapNodeData.Type.BATTLE
			base_id = "ink_spirit"
			fight.g = m.TH.foes[rng.randi_range(0, m.TH.foes.size() - 1)]
		_:
			node.type = MapNodeData.Type.BATTLE
			base_id = FOE_ENEMY[1 + (int(fight.k) + act) % (FOE_ENEMY.size() - 1)]
	var base: EnemyData = Database.get_enemy(base_id)
	if base == null:
		base = Database.get_enemy("ink_spirit")
	var ed: EnemyData = base.duplicate()
	ed.name = fight.name
	ed.glyph = fight.g if not str(fight.g).is_empty() else base.glyph
	ed.max_hp = int(round(base.max_hp * hp_mul))
	node.title = {"boss": "首领 · %s", "elite": "%s · 险战", "ambush": "%s · 突袭", "foe": "%s"}[fight.kind] % fight.name
	node.enemies.append(ed)
	return node


## battle.start() 之后、第一回合之前调用：词谱「战斗开场」类 + 印章 + 首领词条 + 位置减益 + 伏兵突袭
func apply_battle_setup(state: BattleState) -> void:
	fight["hp_start"] = GameState.player_hp
	var e: Combatant = state.enemies[0] if not state.enemies.is_empty() else null
	var kind: String = fight.kind
	var turn_block := 0
	if has("护盾"):
		turn_block += 4
	if has("重甲"):
		turn_block += 8
		_return_one(state, "重甲：第一回合少抽 1 枚字")
	if kind == "ambush" and has("防护"):
		turn_block += 6
	if turn_block > 0:
		# 开局抽字后 begin_player_turn 会清临挡，所以在第一回合直接加
		state.player.add_block(turn_block)
		state._log("开场护盾 +%d" % turn_block)
	if has("护甲"):
		state.player.add_persistent_block(2)
		state._log("护甲：持久盾 +2")
	var energy := (2 if has("蓄能") else 0) + (2 if has("充电") else 0) + (3 if has("充放电") else 0)
	if energy > 0:
		state.player.add_energy(energy)
		state._log("开场储能 +%d" % energy)
	if has("蓄冷"):
		state.player.heat_capacity += 3
	if has("清热"):
		state.player.add_heat(-2)
	if has("防御力"):
		state.player.permanent_damage_reduction += 1
	if has("蓄力"):
		state.enable_ability("force_once", state.ability_value("force_once") + 4)
	if has("重击"):
		state.pierce_once = true
	if has("加急"):
		var n := state.draw_to_board(1)
		if n > 0:
			state._log("加急：第一回合多抽 1 枚字")
	if e != null and has("火力"):
		state.deal_damage(e, 4, false)
		state._log("火力：开场先造成 4 点伤害")
	if e != null and has("电击") and kind in ["elite", "boss"]:
		state.deal_damage(e, 6, false)
		state._log("电击：开场先造成 6 点伤害")
	if kind == "boss" and e != null:
		_boss_setup(state, e)
	if kind == "ambush" and e != null:
		if has("反击"):
			state._log("反击：遭遇伏兵，由你先手")
		else:
			if has("回防"):
				state.player.turn_damage_halve = true
				state._log("回防：第一回合敌人伤害减半")
			state._log("伏兵突袭！")
			state._enemy_act(e, true)


## 首领词条：朱笔少一条；破甲护甲 −8；破防失去全部护盾；停火第一回合不攻击；被追上吃位置减益
func _boss_setup(state: BattleState, e: Combatant) -> void:
	var affixes: Array = BOSS_AFFIX[act].duplicate(true)
	if has_seal("朱笔") and not affixes.is_empty():
		var cut: Array = affixes.pop_back()
		state._log("朱笔：首领少一条词条（%s）" % (AFFIX_TEXT[cut[0]] % cut[1]))
	for a in affixes:
		var v: int = a[1]
		match a[0]:
			"armor":
				if has("破甲"):
					v = maxi(0, v - 8)
					state._log("破甲：首领护甲 −8")
				if v > 0:
					e.add_persistent_block(v)
			"shield":
				if has("破防"):
					state._log("破防：首领失去全部护盾")
					continue
				e.add_block(v)
			"strength":
				e.add_status("strength", v)
		state._log("首领词条：" + AFFIX_TEXT[a[0]] % v)
	if has("停火"):
		state.enemy_skip_turns = 1
		state._log("停火：首领第一回合不攻击")
	var debuff: String = fight.get("debuff", "")
	if debuff.is_empty():
		return
	state._log("被追上的位置：" + DEBUFF_TEXT[debuff])
	match debuff:
		"先手":
			state._enemy_act(e, true)
		"少抽字":
			_return_one(state, "")
		"污染字":
			var cd: CharacterData = Database.get_character("pollution")
			if cd != null:
				var inst := CharInstance.new(cd)
				inst.temporary = true
				state.bag.append(inst)
		"热度":
			state.player.add_heat(3)
		"熔字":
			if not state.bag.is_empty():
				var inst: CharInstance = state.bag.pop_at(state.rng.randi_range(0, state.bag.size() - 1))
				state.removed_this_battle.append(inst)
		"淹格":
			_return_one(state, "")
		"首领护盾":
			e.add_block(8)


## 把字盘上 1 枚非临时字放回字袋（少抽字 / 淹格：这一格第一回合空着）
func _return_one(state: BattleState, why: String) -> void:
	var cells: Array = []
	for i in state.board.cells.size():
		var c: CharInstance = state.board.cells[i]
		if c != null and not c.temporary:
			cells.append(i)
	if cells.is_empty():
		return
	var i: int = cells[state.rng.randi_range(0, cells.size() - 1)]
	state.bag.append(state.board.cells[i])
	state.board.cells[i] = null
	if not why.is_empty():
		state._log(why)


## 战斗结束回地图前调用；返回 {"reward": 是否去战后三选一, "count": 选项数}
func finish_battle(victory: bool) -> Dictionary:
	if fight.is_empty():
		return {"reward": false}
	var f := fight
	fight = {}
	if has_seal("镇纸") and victory:
		var lost: int = int(f.get("hp_start", GameState.player_hp)) - GameState.player_hp
		if lost > 0:
			GameState.heal(mini(4, lost))
			_log("镇纸：这场少掉 %d 点血" % mini(4, lost))
	if not victory:
		over = true
		_log("败于%s，远征中止" % f.name)
		return {"reward": false}
	var gold := 0
	if has("金币"):
		gold += 2
	if has("铸币") and f.kind in ["elite", "boss"]:
		gold += 5
	if gold > 0:
		GameState.add_gold(gold)
		_log("战后 ❖ +%d" % gold)
	var ink_gain := (1 if has("充能") else 0) + (2 if has("充放电") else 0)
	if ink_gain > 0:
		ink += ink_gain
		_log("战胜回墨 +%d" % ink_gain)
	match f.kind:
		"boss":
			var s := roll_seal("首领")
			if not s.is_empty():
				add_seal(s)
			boss_down = true
			stun = 0
			boss_trail.clear()
			alerts.clear()   ## 战前排队的惊动 / 起身提示已经过时
			_log("击败首领%s：可以继续探索，准备好了就结束本幕" % f.name)
			alerts.append(["首领已被击败", "首领【%s】倒下了，不会再追你。
剩下的赏、商店、休息点都还在，可以慢慢拿完；准备好了，点「结束本幕」进入幕间结算。" % m.TH.boss])
			return {"reward": false}
		"ambush":
			amb_done[int(f.amb)] = true
			_log("击退伏兵，领地里的奖励解封")
		"elite":
			taken[int(f.k)] = true
			var s := roll_seal("精英")
			if not s.is_empty():
				add_seal(s)
		_:
			taken[int(f.k)] = true
	advance(FIGHT_T if f.kind != "ambush" else AMBUSH_T)
	if fight.is_empty():
		_check_boss_adjacent()
	if fight.is_empty():
		enter_cell()
	return {"reward": true, "count": 4 if has("分流") else 3}


## 战后三选一选中的字
func receive_reward_glyph(cd: CharacterData) -> void:
	if cd != null:
		gain_glyph(cd.glyph, "战利品")


func _log(text: String) -> void:
	lines.push_front(text)
	if lines.size() > 40:
		lines.resize(40)
