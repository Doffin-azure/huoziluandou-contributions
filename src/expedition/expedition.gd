extends RefCounted
class_name Expedition
## 墨途远征：迷雾探索、分阶段敌人、首领追逐、字匣与战斗构筑。
## 印章 / 遗物 / 休息 / 商店 / 熔炉保留；首领击败即封层。
## 遭遇进入真正的 4×4 战斗（battle_screen），开场效果见 apply_battle_setup。格子用 MapGen 的整数 k。


## 每幕前 / 中 / 深区的固定投放；战斗组词本身保留。
const NORMAL_STAGES := {
	1: [["paper_shell", "needle_bee"], ["tilting_inkwell", "fold_moth"], ["blank_child", "corrosion_beetle"]],
	2: [["glutton", "furnace_beast"], ["charge_badger", "ink_creditor"], ["double_slip", "nest_moth", "bomb_press"]],
	3: [["charge_badger", "ink_creditor", "bomb_press"], ["glutton", "double_slip", "nest_moth"], ["furnace_beast", "double_slip", "nest_moth"]],
}
const ELITE_STAGES := {
	1: [["iron_seal"], ["iron_seal"], ["iron_seal"]],
	2: [["copy_master"], ["copy_master", "seal_officer"], ["wheel_master", "leech"]],
	3: [["copy_master", "seal_officer"], ["seal_officer", "wheel_master"], ["wheel_master", "leech"]],
}
const ENCOUNTER_STAGES := {
	1: ["起步·基础应对", "起步·盘面练习", "起步·污染管理"],
	2: ["成型·资源运转", "成型·费用调度", "成型·组合考验"],
	3: ["兑现·复合应对", "兑现·循环稳定", "兑现·终局考验"],
}

const TRAY_CAP := 6
const DECK_CAP := 20
const SEAL_CAP := 3
const START_INK := 4
const BARRIER_INK := 2
const BARRIER_HP := 4
const FIGHT_T := 2
const AMBUSH_T := 1
const REST_T := 3
## 首领击败即封层；有限补给代替无压力清图，进入下一幕时发放。
const ACT_SUPPLY := {1: {"gold": 12, "heal": 8, "ink": 1}, 2: {"gold": 16, "heal": 10, "ink": 1}}
## 印章：效果 / 主要来源
const SEALS := {
	"镇纸": ["每场战斗少掉 4 点血", "精英"], "夜灯": ["视野 +1 格", "大赏"], "更漏": ["首领走路概率增长得更慢", "大赏"],
	"拓本": ["打开任何赏都多一个选项", "大赏"], "印鉴": ["被「封」的奖励会显示伏兵的位置", "精英"],
	"朱笔": ["首领战开场，新首领生命上限 −6；旧首领少一条词条", "首领"], "蒲团": ["休息点的治疗量翻倍", "精英"],
	"活字盒": ["字匣 +2 格", "大赏"], "字印": ["每场战斗开场多抽 1 枚字", "首领"],
}
## 三幕首领使用精选机制资源；地图主题仍保留。
const BOSS := EnemyRoster.BOSSES
const BOSS_NAME := {"墨池": "墨渊", "熔铸坊": "铸印魔", "潮汐渠": "潮伯", "雷池": "雷公"}
## 旧资源兼容用的首领词条（逐幕加强），朱笔可以削掉
const BOSS_AFFIX := {1: [["armor", 8], ["shield", 6]], 2: [["armor", 12], ["shield", 8], ["strength", 1]],
	3: [["armor", 16], ["shield", 10], ["strength", 2]]}
const AFFIX_TEXT := {"armor": "护甲（持久盾）+%d", "shield": "开场护盾 +%d", "strength": "力量 +%d"}
const ELITE := "iron_seal"
const FOE_ENEMY := ["ink_spirit", "ember_imp", "paper_guard", "rust_scribe", "bronze_seal"]
## 被追上的位置减益（机关格本身及上下左右）
const SPOT_DEBUFF := {"纸": "少抽字", "泉": "污染字", "焰": "热度", "炉": "熔字", "流": "淹格", "潮": "淹格", "闸": "首领护盾", "桩": "首领护盾",
	"渗": "污染字", "吊": "熔字", "线": "首领护盾"}
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
var steps := 0                  ## 玩家实际走过的格数
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
var halt_done := false          ## 起身提示已触发
var boss_down := false          ## 首领已败，本层封闭，只能处理首领奖励与幕间结算。
var ink := START_INK
var tray: Array = []
var seals: Array = []
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
	GameState.expedition = ex
	ex.load_act(1)
	return ex


func load_act(n: int) -> void:
	act = n
	m = MapGen.generate(run_seed + n * 1009, themes[(n - 1) % themes.size()])
	_assign_encounter_stages()
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
	fight = {}
	panels.clear()
	alerts.clear()
	boss_trail.clear()
	update_vision()
	_log("第 %d 幕 · %s：首领【%s】睡在远处的巢穴里" % [act, m.tn, m.TH.boss])


# ---------------------------------------------------------------- 派生数值


func has_seal(s: String) -> bool:
	return seals.has(s)


func tray_cap() -> int:
	return TRAY_CAP + (2 if has_seal("活字盒") else 0)


func vision() -> int:
	return MapGen.P.vision + (1 if has_seal("夜灯") else 0)


## 首领这一步走的概率（伪随机）：基线 = 0.35 + 0.05 × 起身后的步数（更漏让增长变慢）；
## 没走就累计：概率 = 基线 × (连续没走的步数 + 1)，最高 100%；走了一步就回到基线
func move_base() -> float:
	if not awake():
		return 0.0
	return minf(1.0, MapGen.P.p0 + MapGen.P.pGrow * acc_scale() * maxi(0, t - int(rise)))


func move_chance() -> float:
	return minf(1.0, move_base() * (miss + 1))


func acc_scale() -> float:
	return 0.5 if has_seal("更漏") else 1.0


func awake() -> bool:
	return not boss_down and rise != null and t >= rise


## 惊动到起身的缓冲步数（每张图 7～10 步，见 MapGen.roll_wake）
func buffer_steps() -> int:
	return int(m.get("buffer", MapGen.P.buffer))


func wake_time() -> int:
	return int(m.wake)


func mech_at(k: int) -> Dictionary:
	return m.mech.get(k, {})


func gate_shut(k: int, at_t: int) -> bool:
	return m.mech.has(k) and MapGen.shut(m.mech[k], at_t)


## 玩家能否走进 k（墨障算可走：撞上时花墨冲开）
func can_enter(k: int) -> bool:
	return m.ink[k] == 0 and not gate_shut(k, t)


## 导线与电闸采用同一通电相位
func mover_live(k: int, at_t: int) -> bool:
	return MapGen.mover_live(mech_at(k), at_t)


func boss_mask() -> PackedByteArray:
	return MapGen.mask_of(func(k): return m.ink[k] == 0 and not gate_shut(k, t))


# ---------------------------------------------------------------- 迷雾
## 视野：沿可走路线 vision 步以内，外加一圈看见墙
func update_vision() -> void:
	visible.clear()
	var mk := MapGen.mask_of(func(k): return m.ink[k] == 0 and not m.obst.has(k))
	var d := MapGen.bfs(mk, pos)
	for k in MapGen.N:
		if d[k] <= vision():
			visible[k] = true
			for n in MapGen.nbrs(k):
				visible[n] = true
	for k in visible:
		explored[k] = true


## 引导点（每类第一个）隔着迷雾发光
func is_beacon(k: int) -> bool:
	return m.node.has(k) and m.node[k].get("beacon", false)


# ---------------------------------------------------------------- 时间与首领
## 过一步：首领到点 / 被大赏惊动 / 有人从巢穴 2 步内经过 → 惊动，缓冲 7～10 步后起身，沿最短路追
## 返回 true = 被追上
func tick() -> bool:
	if boss_down or over:
		return false
	t += 1
	if stir == null:
		var near := MapGen.bfs(MapGen.mask_of(func(k): return can_enter(k) and not m.obst.has(k)), m.lair)[pos] <= 2
		if t >= wake_time() or alarm or near:
			stir = t
			rise = t + buffer_steps()
			_log("首领被惊动了：%d 步后起身" % buffer_steps())
			var why := "你打开了大赏" if alarm else ("你从巢穴旁经过" if near else "它睡醒了")
			alerts.append(["首领被惊动了", "%s。首领【%s】%d 步后起身，然后会沿最短路追你。
地图上的红色【%s】就是它。" % [why, m.TH.boss, buffer_steps(), m.TH.boss]])
	if not awake():
		return false
	if not halt_done:
		halt_done = true
		alerts.append(["首领起身了", "首领【%s】开始追你，现在相距 %d 步。
战斗、休息都要花时间；被追上的位置会给首领战减益，主动迎战则不会。" % [m.TH.boss, MapGen.bfs(boss_mask(), boss)[pos]]])
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
	fight = _boss_encounter(true)
	_log("首领追上来了！")


func _boss_encounter(caught: bool) -> Dictionary:
	var debuff := ""
	if caught:
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
	return over or boss_down or not panels.is_empty() or not fight.is_empty()


func can_step(k: int) -> bool:
	return not busy() and MapGen.man(k, pos) == 1 and can_enter(k)


func move(k: int) -> bool:
	if not can_step(k):
		return false
	if m.obst.has(k):
		if ink >= BARRIER_INK:
			ink -= BARRIER_INK
			_log("冲开墨障：墨 −%d" % BARRIER_INK)
		else:
			_hurt(BARRIER_HP, "墨不够，硬冲墨障")
		m.obst.erase(k)
	pos = k
	steps += 1
	advance(1 + _step_mech())
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
			return 1
		"焰":
			_hurt(3, "烈焰格")
		"桩":
			if awake() and int(used.get(pos, 0)) < 1:
				used[pos] = int(used.get(pos, 0)) + 1
				stun += 3
				_log("蓄电桩：把首领定住 3 步")
		"流":
			if int(used.get(pos, 0)) < 1:
				used[pos] = 1
				_slide(mc.dir)
		"渗":
			pos = mc.to
			_log("渗墨点：从另一个渗墨点冒出来")
		"吊":
			if not used.has(pos):
				used[pos] = 1
				pos = mc.to
				_log("吊钩：被吊过墨渍墙")
		"线":
			if mover_live(pos, t):
				pos = mc.to
				_log("导线通电：一下子到了另一头")
			else:
				_log("导线没电：等电闸开了再来")
	return 0


## 水流：顺着箭头滑 3 格，撞墙停；不耗步
func _slide(dir: Vector2i) -> void:
	var p := MapGen.rc(pos)
	var n := MapGen.SLIDE_N
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
	if boss_down or over: return
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
	if not mc.is_empty() and mc.g == "炉" and int(used.get(pos, 0)) < 1:
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
			var kind := "elite" if o.t == "险" else "foe"
			if not explored.has(n): return "精英" if kind == "elite" else "明敌"
			return ("精英" if kind == "elite" else "明敌") + "【%s】" % encounter_enemy(kind, n).name
	return ""


func pickup() -> bool:
	if boss_down or over or not m.glyph.has(pos) or taken.has(pos) or sealed(pos):
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
## 小赏二选一、中赏 / 大赏三选一；中大赏加入遗物，拓本让所有赏多一个
func loot_options(tier: String) -> Array:
	if tier not in ["小", "中", "大"]: return []
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
			opts.append({"kind": "glyphs", "glyphs": roll_pair()})
			opts.append({"kind": "gold", "gold": 25})
			opts.append({"kind": "glyphs", "glyphs": [roll_glyph(2, true)]})
			opts.append({"kind": "intel"})
	if tier in ["中", "大"]:
		var relic := roll_loot_relic(tier)
		if not relic.is_empty(): opts.append({"kind": "relic", "relic": relic})
	var n := 2 if tier == "小" else 3
	if has_seal("拓本"):
		n += 1
	# 同一份奖励只出现一次；先保证字与金币，再抽特色和额外选项。
	var pool: Array = []
	var keys := {}
	for option in opts:
		var key := _loot_key(option)
		if not keys.has(key):
			keys[key] = true
			pool.append(option)
	# 两次随机发字可能恰好重复；补足候选，避免拓本奖励空耗。
	if pool.size() < n:
		var owned := owned_glyphs()
		var fallback: Array = reward_pool().filter(func(cd): return cd.rarity <= 2 and formable(cd, owned) and not keys.has("glyphs:" + cd.glyph))
		while pool.size() < n and not fallback.is_empty():
			var cd: CharacterData = fallback.pop_at(rng.randi_range(0, fallback.size() - 1))
			pool.append({"kind": "glyphs", "glyphs": [cd.glyph]})
	var selected: Array = []
	_take_loot(pool, selected, ["gold"])
	_take_loot(pool, selected, ["glyphs"])
	if tier == "大": _take_loot(pool, selected, ["seal", "relic"])
	while selected.size() < n and not pool.is_empty():
		selected.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	# 展示位置不固定，避免首项长期偏向同一种收益。
	for i in range(selected.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var item: Dictionary = selected[i]
		selected[i] = selected[j]
		selected[j] = item
	return selected


## 中赏最多少见，大赏包含稀有；已有遗物不重复进入奖励池。
func loot_relic_pool(tier: String) -> Array:
	if tier not in ["中", "大"]: return []
	var max_tier := 2 if tier == "中" else 3
	return Relics.DEFS.keys().filter(func(id): return not GameState.has_relic(id) and int(Relics.TIER[id]) <= max_tier)


func roll_loot_relic(tier: String) -> String:
	var pool := loot_relic_pool(tier)
	return str(pool[relic_rng.randi_range(0, pool.size() - 1)]) if not pool.is_empty() else ""


func _loot_key(option: Dictionary) -> String:
	if option.kind == "glyphs":
		var glyphs: Array = option.glyphs.duplicate()
		glyphs.sort()
		return "glyphs:" + "".join(glyphs)
	return str(option.kind) + ":" + str(option.get("relic", option.get("seal", option.get("gold", ""))))


func _take_loot(pool: Array, selected: Array, kinds: Array) -> void:
	var choices: Array = pool.filter(func(option): return kinds.has(option.kind))
	if choices.is_empty(): return
	var chosen: Dictionary = choices[rng.randi_range(0, choices.size() - 1)]
	pool.erase(chosen)
	selected.append(chosen)


func loot_text(o: Dictionary) -> String:
	match o.kind:
		"glyphs": return "字：" + "、".join(o.glyphs.map(func(g): return "【%s】" % g))
		"gold": return "❖ +%d" % o.gold
		"intel": return "情报：揭示最近的一个伏兵，或照亮周围 3 步"
		"seal": return "印章「%s」：%s" % [o.seal, SEALS[o.seal][0]]
		"relic": return "遗物" + Relics.text(o.relic)
	return ""


func choose_loot(i: int) -> void:
	var p := top_panel()
	if p.get("kind", "") != "loot" or i < 0 or i >= p.options.size():
		return
	var o: Dictionary = p.options[i]
	if o.kind == "relic" and GameState.has_relic(o.relic):
		_log("这件遗物已经拥有，请选择其他奖励")
		return
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
		"relic":
			_grant_relic(o.relic, "开赏")


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
## 来源：中赏 / 大赏、商店货架；卖回商店拿一半价钱。遗物管战斗，不占印章格
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
	var free: Array = SEALS.keys().filter(func(s): return SEALS[s][1] == source and not seals.has(s))
	return free[rng.randi_range(0, free.size() - 1)] if not free.is_empty() else ""


# ---------------------------------------------------------------- 休息点
## 治疗 / 删字 / 修饰 三选一，耗 3 步，每个休息点只能用一次
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
	pop_panel()
	taken[pos] = true
	advance(REST_T)
	return true


## 修饰 = 镀金：单字或组词打出+1金币（GDD）
func _gild(glyph_id: String) -> bool:
	var n := 1
	var done := 0
	for c in GameState.deck:
		if c.id() == glyph_id and not c.gilded and done < n:
			c.gilded = true
			done += 1
	if done == 0:
		return false
	_log("镀金【%s】×%d：单字或组词打出+1金币" % [Database.get_character(glyph_id).glyph, done])
	return true


# ---------------------------------------------------------------- 商店
## 买字 / 回购 / 删字 / 修饰 / 治疗（GDD 价位）；丢弃字可半价回购
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
	return int(ceil(o.base * 0.5)) if o.kind == "buyback" else int(o.base)


func buyback_offers() -> Array:
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
	if index >= 0 and index < offers.size():
		offers.remove_at(index)
	return true


func leave_panel() -> void:
	var p := top_panel()
	if p.get("kind", "") in ["shop", "forge", "event"]:
		pop_panel()


# ---------------------------------------------------------------- 熔炉
## 每个地图熔炉一次；投两个字匣里的字熔成一个稀有字。
func forge(a: int, b: int) -> bool:
	var p := top_panel()
	if p.get("kind", "") != "forge" or boss_down or over:
		return false
	var cell := int(p.get("k", -1))
	if cell != pos or mech_at(cell).get("g", "") != "炉" or int(used.get(cell, 0)) >= 1:
		return false
	if a == b or a < 0 or b < 0 or a >= tray.size() or b >= tray.size():
		return false
	var gs: Array = [tray[a], tray[b]]
	tray.remove_at(maxi(a, b))
	tray.remove_at(mini(a, b))
	used[cell] = 1
	pop_panel()
	var out := roll_glyph(1)
	_log("熔炉：%s熔成【%s】" % ["".join(gs.map(func(g): return "【%s】" % g)), out])
	gain_glyph(out)
	return true


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


# ---------------------------------------------------------------- 字匣 / 字袋
## 字匣 → 字袋（上限 20），探索获得的字用于战斗构筑
func tray_to_deck(i: int) -> bool:
	if busy() or i < 0 or i >= tray.size() or GameState.deck_size() >= DECK_CAP:
		return false
	var g: String = tray.pop_at(i)
	GameState.add_character(Database.get_character_by_glyph(g))
	_log("【%s】放进字袋" % g)
	return true


## 丢字进入回购清单
func discard(i: int) -> bool:
	if busy() or i < 0 or i >= tray.size():
		return false
	var g: String = tray.pop_at(i)
	buyback.append(g)
	_log("丢掉【%s】，可在商店回购" % g)
	return true


# ---------------------------------------------------------------- 首领：主动迎战 / 幕间
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
		return "首领已败 · 本层封闭，进入幕间结算"
	if stir == null:
		return "首领沉睡"
	if not awake():
		return "首领惊动 · %d 步后起身" % (int(rise) - t)
	var d := MapGen.bfs(boss_mask(), boss)[pos]
	return "首领追来 · 相距 %d 步%s" % [d, "（被定住 %d 步）" % stun if stun > 0 else ""]


## 首领胜利自动结算；保留幂等入口供流程恢复，不允许恢复探索。
func can_finish_act() -> bool:
	return boss_down and not over and panels.is_empty() and fight.is_empty()


func finish_act() -> bool:
	if not can_finish_act():
		return false
	push_panel({"kind": "act_end"})
	_log("第 %d 幕完成" % act)
	return true


## 幕间只发有限补给


func act_supply() -> Dictionary:
	return ACT_SUPPLY.get(act, {"gold": 0, "heal": 0, "ink": 0}).duplicate()


func next_act() -> void:
	if top_panel().get("kind", "") != "act_end":
		return
	pop_panel()
	if act >= 3:
		over = true
		won = true
		_log("三幕已尽，远征完成")
		return
	var supply := act_supply()
	GameState.add_gold(int(supply.gold))
	var hp_before := GameState.player_hp
	GameState.heal(int(supply.heal))
	ink += int(supply.ink)
	_log("幕间补给：金币 +%d，气血 +%d，墨 +%d" % [supply.gold, GameState.player_hp - hp_before, supply.ink])
	load_act(act + 1)


# ---------------------------------------------------------------- 接入 4×4 战斗
## 当前遭遇的固定成长阶段，与预告和实际开战共用。
func _assign_encounter_stages() -> void:
	var distances := MapGen.bfs(MapGen.mask_of(func(k): return m.ink[k] == 0), m.start)
	var anchors: Array = []
	for k in m.node:
		if m.node[k].t == "敌": anchors.append(int(k))
	for amb in m.get("ambush", []):
		if not anchors.has(int(amb.k)): anchors.append(int(amb.k))
	anchors.sort_custom(func(a, b): return distances[a] < distances[b] if distances[a] != distances[b] else a < b)
	var stages := {}
	for i in anchors.size(): stages[anchors[i]] = mini(2, int(i * 3.0 / anchors.size()))
	for k in m.node:
		if m.node[k].t != "险": continue
		var before := anchors.filter(func(a): return distances[a] <= distances[k]).size()
		stages[int(k)] = mini(2, int(before * 3.0 / maxi(1, anchors.size())))
	m["encounter_stages"] = stages


## 伏兵用领地主人作锚点，换一个入口也不会换怪。阶段由地图固定，不随等待或绕路升级。
func encounter_anchor(kind: String, cell: int) -> int:
	if kind == "ambush":
		var owner := int(m.get("terr", {}).get(cell, -1))
		var ambs: Array = m.get("ambush", [])
		if owner >= 0 and owner < ambs.size(): return int(ambs[owner].k)
	return cell


func encounter_stage(kind: String, cell: int) -> int:
	return 2 if kind == "boss" else int(m.get("encounter_stages", {}).get(encounter_anchor(kind, cell), 0))


func stage_text(kind: String, cell: int) -> String:
	if kind == "boss": return ["起步·幕末检验", "成型·幕末检验", "兑现·终局首领"][act - 1]
	return ENCOUNTER_STAGES[act][encounter_stage(kind, cell)]


func encounter_enemy(kind: String, cell: int) -> EnemyData:
	var stage := encounter_stage(kind, cell)
	var pool: Array = NORMAL_STAGES[act][stage]
	if kind == "boss": pool = [EnemyRoster.BOSSES[act]]
	elif kind == "elite": pool = ELITE_STAGES[act][stage]
	var pick := RandomNumberGenerator.new()
	pick.seed = run_seed * 997 + act * 100003 + encounter_anchor(kind, cell) * 31
	var source: EnemyData = Database.get_enemy(pool[pick.randi_range(0, pool.size() - 1)])
	# 深区小幅延长机制应对，伤害沿用初稿；第三幕再加12%生命。首领保持88/124/168。
	var ed: EnemyData = source.duplicate(true)
	if kind != "boss": ed.max_hp = ceili(source.max_hp * (100 + 4 * stage + (12 if act == 3 else 0)) / 100.0)
	return ed


func encounter_rewards(encounter: Dictionary) -> Dictionary:
	var kind: String = encounter.kind
	var source := "首领" if kind == "boss" else ("精英" if kind == "elite" else "")
	var seal_available := not source.is_empty() and SEALS.keys().any(func(s): return SEALS[s][1] == source and not seals.has(s))
	return {"gold": 6 if kind == "boss" else (4 if kind == "elite" else 2),
		"ink": 1, "count": 3, "seal": seal_available,
		"time": 0 if kind == "boss" else (AMBUSH_T if kind == "ambush" else FIGHT_T)}


func encounter_info(encounter: Dictionary) -> Dictionary:
	var kind: String = encounter.kind
	var ed := encounter_enemy(kind, int(encounter.k))
	var rewards := encounter_rewards(encounter)
	var hp := maxi(1, ed.max_hp - (6 if kind == "boss" and has_seal("朱笔") and not ed.mechanic.is_empty() else 0))
	var rewards_text := "战利品%d选1；也可跳过，拿8金币。" % rewards.count if kind != "boss" else "击败即结束本层，未拿资源放弃；随后处理印章与幕间结算。"
	if rewards.seal:
		rewards_text += " 获得1枚印章" + ("（印章位已满，需选择替换）" if seals.size() >= SEAL_CAP else "") + "。"
	if int(rewards.gold) > 0: rewards_text += " 额外金币+%d。" % rewards.gold
	if int(rewards.ink) > 0: rewards_text += " 墨+%d。" % rewards.ink
	if kind == "ambush": rewards_text += " 解封该伏兵控制的奖励。"
	if kind == "boss" and act < 3:
		var supply := act_supply()
		rewards_text += " 进入下一幕后补给：金币+%d、气血最多+%d、墨+%d。" % [supply.gold, supply.heal, supply.ink]
	var first: EnemyMoveData = ed.moves[0] if not ed.moves.is_empty() else null
	return {"enemy": ed, "stage": stage_text(kind, int(encounter.k)), "hp": hp, "initial_block": ed.initial_block,
		"mechanic": ed.description if not ed.description.is_empty() else "按行动循环攻击、防御或干扰字盘。",
		"cycle": " → ".join(ed.moves.map(func(move): return _encounter_move_text(move))),
		"first": _encounter_move_text(first) if first != null else "无行动",
		"rewards": rewards_text,
		"time": ("胜利后耗%d步；首领已被击败，不再追逐。" if boss_down else "胜利后耗%d步，首领会照常推进。") % rewards.time if kind != "boss" else "击败首领后本层立即封闭，不能再探索。"}


func _encounter_move_text(move: EnemyMoveData) -> String:
	var result := move.title
	match move.kind:
		EnemyMoveData.Kind.ATTACK, EnemyMoveData.Kind.MULTI:
			result += " %d" % move.damage
			if move.hits > 1: result += "×%d" % move.hits
		EnemyMoveData.Kind.BLOCK: result += " +%d盾" % move.block
		EnemyMoveData.Kind.ATTACK_BLOCK: result += " %d伤/+%d盾" % [move.damage, move.block]
		EnemyMoveData.Kind.INJECT: result += " 注%d字" % move.inject_count
	if move.inject_count > 0 and move.kind != EnemyMoveData.Kind.INJECT:
		result += "（空间类时注%d枚【%s】）" % [move.inject_count, move.inject_glyph] if move.mechanic_action == "copy" else " 注%d枚【%s】" % [move.inject_count, move.inject_glyph]
	return result


func battle_node() -> MapNodeData:
	var node := MapNodeData.new()
	var kind: String = fight.kind
	node.type = MapNodeData.Type.BOSS if kind == "boss" else (MapNodeData.Type.ELITE if kind == "elite" else MapNodeData.Type.BATTLE)
	var ed := encounter_enemy(kind, int(fight.k))
	node.title = ("首领 · " if kind == "boss" else ("精英 · " if kind == "elite" else "")) + ed.name
	node.enemies.append(ed)
	fight.name = ed.name
	fight.g = ed.glyph
	return node


## battle.start() 之后、第一回合之前调用：印章 + 位置减益 + 伏兵突袭
func apply_battle_setup(state: BattleState) -> void:
	fight["hp_start"] = GameState.player_hp
	var e: Combatant = state.enemies[0] if not state.enemies.is_empty() else null
	var kind: String = fight.kind
	if has_seal("字印"):
		var drawn := state.draw_to_board(BattleBalance.i("seal_draw", 1))
		state._log("字印：开场多抽 %d 枚字" % drawn)
	if kind == "boss" and e != null:
		_boss_setup(state, e)
	if kind == "ambush" and e != null:
		state._log("伏兵突袭！")
		state._enemy_act(e, true)
	# 开场先手推进了招式时，为玩家真正面对的下一招开题。
	state.monster_entered.clear()
	if e != null and e.move_index != int(EnemyMechanics.data(e).get("move", -1)):
		EnemyMechanics.begin_phase(state)


## 朱笔降低机制首领生命；旧首领少一条词条；被追上吃位置减益
func _boss_setup(state: BattleState, e: Combatant) -> void:
	var affixes: Array = [] if not e.enemy_data.mechanic.is_empty() else BOSS_AFFIX[act].duplicate(true)
	if not e.enemy_data.mechanic.is_empty():
		# 朱笔保留收益：降低首领当前/最大生命6，不改任务伤害。
		if has_seal("朱笔"):
			e.max_hp = maxi(1, e.max_hp - BattleBalance.i("seal_boss_hp", 6))
			e.hp = maxi(0, e.hp - BattleBalance.i("seal_boss_hp", 6))
			state._log("朱笔：首领生命上限 −6")
	if has_seal("朱笔") and not affixes.is_empty():
		var cut: Array = affixes.pop_back()
		state._log("朱笔：首领少一条词条（%s）" % (AFFIX_TEXT[cut[0]] % cut[1]))
	for a in affixes:
		var v: int = BattleBalance.i("legacy_boss_%d_%s" % [act, a[0]], int(a[1]))
		match a[0]:
			"armor":
				if v > 0:
					e.add_persistent_block(v)
			"shield":
				e.add_block(v)
			"strength":
				e.add_status("strength", v)
		state._log("首领词条：" + AFFIX_TEXT[a[0]] % v)
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
			state.player.add_heat(BattleBalance.i("debuff_heat", 3))
		"熔字":
			if not state.bag.is_empty():
				var inst: CharInstance = state.bag.pop_at(state.rng.randi_range(0, state.bag.size() - 1))
				state.removed_this_battle.append(inst)
		"淹格":
			_return_one(state, "")
		"首领护盾":
			e.add_block(BattleBalance.i("debuff_shield", 8))


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
	if boss_down or fight.is_empty():
		return {"reward": false}
	var f := fight
	fight = {}
	if has_seal("镇纸") and victory:
		var lost: int = int(f.get("hp_start", GameState.player_hp)) - GameState.player_hp
		if lost > 0:
			GameState.heal(mini(BattleBalance.i("seal_recovery", 4), lost))
			_log("镇纸：这场少掉 %d 点血" % mini(BattleBalance.i("seal_recovery", 4), lost))
	if not victory:
		over = true
		_log("败于%s，远征中止" % f.name)
		return {"reward": false}
	var payout := encounter_rewards(f)
	var gold: int = payout.gold
	if gold > 0:
		GameState.add_gold(gold)
		_log("战后 ❖ +%d" % gold)
	var ink_gain: int = payout.ink
	if ink_gain > 0:
		ink += ink_gain
		_log("战胜回墨 +%d" % ink_gain)
	match f.kind:
		"boss":
			boss_down = true
			stun = 0
			boss_trail.clear()
			alerts.clear()
			# 关闭旧层面板。结算压在首领奖励下方，满印章先选替换再进入结算。
			panels.clear()
			push_panel({"kind": "act_end"})
			var seal := roll_seal("首领")
			if not seal.is_empty(): add_seal(seal)
			_log("击败首领%s：本层已封闭，未拿资源放弃，进入幕间结算" % f.name)
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
	return {"reward": true, "count": payout.count}


## 战后三选一选中的字
func receive_reward_glyph(cd: CharacterData) -> void:
	if cd != null:
		gain_glyph(cd.glyph, "战利品")


func _log(text: String) -> void:
	lines.push_front(text)
	if lines.size() > 40:
		lines.resize(40)
