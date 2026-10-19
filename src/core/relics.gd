extends RefCounted
class_name Relics
## 遗物（第一批）：常驻被动，跨战斗生效；按获得顺序记录在 GameState.relics。
## 设计来源：docs/遗物设计清单_2026-10-15.md。本批只接入规则已确认、或可按清单建议取默认值的条目；
## 默认取值与未定项见 docs/遗物接入说明_第一批.md。
##
## 与印章的分工：印章管地图（视野、字匣、首领），遗物管战斗；两者互不占位。
## 战斗侧所有钩子都只读 BattleState.relics（开战时从 GameState 复制），测试可直接改它。

## id -> [名称, 说明, 是否需要绑定一枚字]
## 名称走冥府镇物、葬仪与庭院旧物一路；内部 id 不变（存档、测试都用 id）
const DEFS := {
	"strike": ["刑卒护指", "带【击】的单字、词，每段攻击伤害 +2", false],
	"breach": ["定罪朱签", "每场开局，所有敌人获得 2 层易伤", false],
	"slab": ["坠字石", "选一枚字：它在盘面上始终下落；本场额外使用 5 次，用尽后本场移出", true],
	"press": ["续碑座", "字盘变为 5×5；开局多补 4 枚字", false],
	"sleep": ["安魂枕", "休息处治疗额外 +20", false],
	"clean": ["无垢拓纸", "回合补字后，若盘面没有污染字，多补 1 枚", false],
	"wheel": ["四方轮", "每回合按 上、下、左、右 轮流让全盘下落", false],
	"powerbank": ["藏雷珠", "每场开局获得 4 储能", false],
	"fireman": ["余烬匣", "拾取时获得 4 枚【火】", false],
	"fertilizer": ["寄字菌", "选一枚字：本场它变为临时字，每回合结束向四邻空格繁殖临时复制", true],
	"skyfire": ["天火遗诏", "打出【流火】时，额外对敌人造成 50 点伤害", false],
	"blitz": ["借时香", "每场第一回合结束后，敌人跳过这一次行动", false],
	"egg": ["孕字卵", "每赢 4 场战斗，获得 1 枚字", false],
	"buckler": ["龟甲片", "每场开局获得 4 持久盾", false],
	"barrier": ["护身纸符", "每场开局获得 10 临时格挡（第一回合有效）", false],
	"empty_case": ["空铅盒", "回合结束时，每有一整行为空，获得 2 持久盾", false],
	"stay_wax": ["留字蜡", "打出的字有 5% 概率留在原位", false],
	"amber": ["血珀", "溢出的治疗量转为持久盾", false],
	"ghost_hand": ["补字鬼手", "每场前 3 枚实际打出的字立即补位", false],
	"cracked_bottle": ["裂雷瓶", "获得的储能翻倍；每回合结束清空储能", false],
	"rotting_fruit": ["将腐供果", "每场开局随机一枚字本场变为临时字", false],
	"chaos_dice": ["乱文骨骰", "拾取时重铸字袋：所有字替换为随机字，并额外补 3 枚", false],
	"black_water": ["黑水瓶", "事件中封存幽都黑水；部分井、墨、渡口事件出现额外选项", false],
	"life_lantern": ["命灯", "借来的寿火；连续事件中可抵挡一次反噬", false],
	"life_debt": ["寿契", "记着未还的寿债；持有期间，讨债事件可能找上门", false],
}
## 档次：1 常见 / 2 少见 / 3 稀有。中赏最多2档，大赏包含3档。
const TIER := {
	"strike": 2, "breach": 2, "slab": 3, "press": 3, "sleep": 1, "clean": 1, "wheel": 2, "powerbank": 1,
	"fireman": 1, "fertilizer": 3, "skyfire": 2, "blitz": 2, "egg": 2, "buckler": 1, "barrier": 1, "empty_case": 2, "stay_wax": 2, "amber": 3, "ghost_hand": 2, "cracked_bottle": 2, "rotting_fruit": 2, "chaos_dice": 3, "black_water": 2, "life_lantern": 2, "life_debt": 2,
}
const PRICE := {1: 35, 2: 50, 3: 70}
const EGG_EVERY := 4
const WHEEL_DIRS := ["up", "down", "left", "right"]
const WHEEL_TEXT := {"up": "上", "down": "下", "left": "左", "right": "右"}
## 事件遗物池：只能由事件发放，不进入商店、许愿、普通奖励等普通遗物池。
const EVENT_ONLY := ["black_water", "life_lantern", "life_debt"]


static func name_of(id: String) -> String:
	return DEFS[id][0] if DEFS.has(id) else id


static func desc_of(id: String) -> String:
	return BattleBalance.relic_description(id, DEFS[id][1]) if DEFS.has(id) else ""


static func needs_bind(id: String) -> bool:
	return DEFS.has(id) and bool(DEFS[id][2])


static func text(id: String) -> String:
	return "「%s」%s" % [name_of(id), desc_of(id)]


## 普通遗物池：不含事件专属遗物。商店、许愿、普通奖励都从这里取。
static func normal_pool() -> Array:
	return DEFS.keys().filter(func(id): return not EVENT_ONLY.has(id))


## 事件遗物池：只给事件使用；事件可以显式指定，也可用 roll_event_choices。
static func event_pool() -> Array:
	return EVENT_ONLY.filter(func(id): return DEFS.has(id))


static func is_event_relic(id: String) -> bool:
	return EVENT_ONLY.has(id)


## 还没拥有的遗物里随机挑 n 个；pool 默认普通池，事件要用事件池必须显式传入。
static func roll_choices(owned: Array, rng: RandomNumberGenerator, n := 1, pool := "normal") -> Array:
	var ids: Array = event_pool() if pool == "event" else normal_pool()
	ids = ids.filter(func(id): return not owned.has(id))
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	return ids.slice(0, mini(n, ids.size()))


## 事件遗物随机池的便捷入口；一般事件给普通遗物时仍用 roll_choices 的默认池。
static func roll_event_choices(owned: Array, rng: RandomNumberGenerator, n := 1) -> Array:
	return roll_choices(owned, rng, n, "event")


static func price(id: String) -> int:
	return PRICE[TIER.get(id, 2)]


static func sell_price(id: String) -> int:
	return int(price(id) / 2)


static func board_size(rules: BattleRules, relics: Array) -> int:
	return maxi(rules.board_size, BattleBalance.i("press_board", 5)) if relics.has("press") else rules.board_size


static func opening_draw(rules: BattleRules, relics: Array) -> int:
	return rules.opening_draw + (BattleBalance.i("press_draw", 4) if relics.has("press") else 0)


## 洗袋之前：寄字菌母本换成本场临时副本；坠字石记下绑定的实体。
static func prepare_deck(b: BattleState) -> void:
	if b.relics.has("slab"):
		var inst := _bag_inst(b, int(b.relic_binds.get("slab", -1)))
		if inst != null:
			b.slab_uid = inst.uid
			b.slab_uses = BattleBalance.i("slab_uses", 5)
	if b.relics.has("fertilizer"):
		var src := _bag_inst(b, int(b.relic_binds.get("fertilizer", -1)))
		if src != null and src.uid != b.slab_uid:
			# 永久实体留在 GameState.deck，本场只用它的临时副本，打完不会丢字
			var copy := src.clone()
			copy.temporary = true
			copy.temporary_uses = 0
			copy.pinned = false
			b.bag[b.bag.find(src)] = copy
			b.temp_chars.append(copy)
			b.breeders[copy.uid] = true
	if b.relics.has("rotting_fruit"):
		var candidates: Array = b.bag.filter(func(c): return c.is_player_owned() and not c.temporary and c.uid != b.slab_uid)
		if not candidates.is_empty():
			var picked: CharInstance = candidates[b.rng.randi_range(0, candidates.size() - 1)]
			# 同样保留永久实体，只用本场的临时副本
			var fruit := picked.clone()
			fruit.temporary = true
			fruit.temporary_uses = 0
			fruit.pinned = false
			fruit.pinned_exhausted = false
			b.bag[b.bag.find(picked)] = fruit
			b.fruit_uid = picked.uid
			b.temp_chars.append(fruit)


static func _bag_inst(b: BattleState, uid: int) -> CharInstance:
	if uid < 0:
		return null
	for inst in b.bag:
		if inst.uid == uid:
			return inst
	return null


## 第一回合开始（开局补字、begin_player_turn 之后）
static func on_battle_start(b: BattleState) -> void:
	if b.relics.has("barrier"):
		b.player.add_block(BattleBalance.i("barrier_block", 10))
		b._log("护身纸符：临时格挡 +%d" % BattleBalance.i("barrier_block", 10))
	if b.relics.has("buckler"):
		b.player.add_persistent_block(BattleBalance.i("buckler_block", 4))
		b._log("龟甲片：持久盾 +%d" % BattleBalance.i("buckler_block", 4))
	if b.relics.has("powerbank"):
		b.add_energy(BattleBalance.i("powerbank_energy", 4))
		b._log("藏雷珠：储能 +%d" % BattleBalance.i("powerbank_energy", 4))
	if b.relics.has("breach"):
		for e in b.alive_enemies():
			e.add_status("vulnerable", BattleBalance.i("breach_stacks", 2))
		b._log("定罪朱签：敌人获得 %d 层易伤" % BattleBalance.i("breach_stacks", 2))
	if b.relics.has("blitz"):
		b.blitz_turn = 1
		b._log("借时香：第一回合结束后，敌人跳过这一次行动")
	# 第一回合也按获得顺序发动一次重力（开局补字不走 begin_player_turn 的补字分支）
	apply_gravity_relics(b)


## 普通回合补字之后（第一回合不调用）
static func after_turn_draw(b: BattleState) -> void:
	if b.relics.has("clean") and not board_dirty(b):
		if b.draw_to_board(BattleBalance.i("clean_draw", 1)) > 0:
			b._log("无垢拓纸：盘面没有污染字，多补 %d 枚" % BattleBalance.i("clean_draw", 1))


## 回合结束：空铅盒按整行空置数给持久盾。
static func on_player_turn_end(b: BattleState) -> void:
	if not b.relics.has("empty_case"):
		return
	var empty_rows := 0
	for y in b.board.size:
		var empty := true
		for x in b.board.size:
			if b.board.get_cell(x, y) != null:
				empty = false
				break
		if empty:
			empty_rows += 1
	if empty_rows <= 0:
		return
	var gain := empty_rows * 2
	b.player.add_persistent_block(gain)
	b._log("空铅盒：%d 行空置，持久盾 +%d" % [empty_rows, gain])


static func board_dirty(b: BattleState) -> bool:
	for c in b.board.cells:
		if c != null and (not c.pollutions.is_empty() or (c.data != null and c.data.is_pollution)):
			return true
	return false


## 重力类遗物：同一时点按获得顺序依次发动，各自结算一次
static func apply_gravity_relics(b: BattleState) -> void:
	for id in b.relics:
		match id:
			"wheel":
				var dir: String = WHEEL_DIRS[b.wheel_step % WHEEL_DIRS.size()]
				b.wheel_step += 1
				match dir:
					"up": BattleOps.apply_gravity_up(b)
					"down": b.apply_gravity()
					"left": b.apply_gravity_left()
					"right": b.apply_gravity_right()
				b._log("四方轮：全盘向%s压" % WHEEL_TEXT[dir])
			"slab":
				slab_fall(b)


## 石板：只有绑定的那一枚往下落，落到本列最低的连续空格
static func slab_fall(b: BattleState) -> void:
	if b.slab_uid < 0:
		return
	var idx := -1
	for i in b.board.cells.size():
		var c: CharInstance = b.board.cells[i]
		if c != null and c.uid == b.slab_uid:
			idx = i
			break
	if idx < 0:
		return
	var inst: CharInstance = b.board.cells[idx]
	if inst.pinned:
		return
	var n := b.board.size
	var x := idx % n
	var y := idx / n
	var ny := y
	while ny + 1 < n and b.board.get_cell(x, ny + 1) == null:
		ny += 1
	if ny != y:
		b.board.set_cell(x, y, null)
		b.board.set_cell(x, ny, inst)


## 消耗石板时调用：还有额外次数就留在原格；用尽后本场移出循环。返回 item.kind
static func consume_slab(b: BattleState, inst: CharInstance) -> String:
	if b.slab_uses > 0:
		b.slab_uses -= 1
		b._log("坠字石：【%s】留在盘上（额外次数还剩 %d）" % [inst.glyph(), b.slab_uses])
		return "layer"
	b._log("坠字石：【%s】次数用尽，本场移出" % inst.glyph())
	return "exhausted"


## 留字蜡：普通永久字被打出后，5% 概率留在原位。
static func stay_wax(b: BattleState, inst: CharInstance) -> bool:
	if not b.relics.has("stay_wax") or inst == null:
		return false
	if not inst.is_player_owned() or inst.temporary or inst.is_enemy_owned():
		return false
	return b.rng.randf() < 0.05


## 补字鬼手：前 3 枚实际消耗的字立即补位。
static func on_cards_consumed(b: BattleState, consumed: Array) -> void:
	if not b.relics.has("ghost_hand") or b.magic_hand_left <= 0:
		return
	var refill := 0
	for item in consumed:
		if b.magic_hand_left <= 0:
			break
		if bool(item.get("shared", false)):
			continue
		if str(item.get("kind", "")) != "real":
			continue
		var inst: CharInstance = item.get("inst")
		if inst == null or not inst.is_player_owned() or inst.temporary:
			continue
		b.magic_hand_left -= 1
		refill += 1
	if refill > 0:
		var n := b.draw_to_board(refill)
		b._log("补字鬼手：补 %d 字（本场还剩 %d 次）" % [n, b.magic_hand_left])


## 回合结束（敌人行动前）：繁殖字向四邻空格生成临时复制；新生的下回合才繁殖
static func breed(b: BattleState) -> void:
	if b.breeders.is_empty():
		return
	var n := b.board.size
	var parents: Array = []
	for i in b.board.cells.size():
		var c: CharInstance = b.board.cells[i]
		if c != null and b.breeders.has(c.uid):
			parents.append(i)
	var born := 0
	for i in parents:
		var parent: CharInstance = b.board.cells[i]
		var x: int = i % n
		var y: int = i / n
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var p: Vector2i = Vector2i(x, y) + d
			if p.x < 0 or p.y < 0 or p.x >= n or p.y >= n or b.board.get_cell(p.x, p.y) != null:
				continue
			var child := CharInstance.new(parent.data)
			child.owner = CharInstance.Owner.PLAYER
			child.temporary = true
			b.board.set_cell(p.x, p.y, child)
			b.temp_chars.append(child)
			b.breeders[child.uid] = true
			born += 1
	if born > 0:
		b._log("寄字菌：繁殖出 %d 枚临时【%s】" % [born, b.board.cells[parents[0]].glyph() if b.board.cells[parents[0]] != null else ""])


## 一次出字是否带【击】（单字【击】或词里含【击】）
static func play_has_strike(glyphs: Array) -> bool:
	return glyphs.has("击")


static func strike_bonus(b: BattleState, target: Combatant) -> int:
	return BattleBalance.i("strike_damage", 2) if b.strike_active and b.relics.has("strike") and target != null and not target.is_player else 0


## 流火结算后
static func on_wash_heat(b: BattleState, target: Combatant) -> Array:
	if not b.relics.has("skyfire"):
		return []
	var e := target if target != null and not target.is_player and target.is_alive() else b.first_alive_enemy()
	if e == null:
		return []
	var real := b.deal_damage(e, BattleBalance.i("skyfire_damage", 50), false)
	b._log("天火遗诏：对%s造成 %d 伤害" % [e.display_name, real])
	return ["天火遗诏：造成 %d 伤害" % real]


# ---------------------------------------------------------------- 战外钩子

static func rest_bonus() -> int:
	return BattleBalance.i("sleep_heal", 20) if GameState.relics.has("sleep") else 0


## 拾取效果（绑定类在 GameState.bind_relic 里另外处理）
static func on_pickup(id: String) -> void:
	match id:
		"fireman":
			# 一局只给一次【火】：卖掉再买 / 再熔出来不重复给
			if GameState.relic_counters.get("fireman_claimed", false):
				return
			GameState.relic_counters["fireman_claimed"] = true
			for i in BattleBalance.i("fireman_count", 4):
				_grant_glyph("火", "余烬匣")
		"chaos_dice":
			_rebuild_deck_chaos()


## 乱文骨骰：字袋全部换成随机字，并在原数量上多补 3 枚。
## 旧的实体 uid 会消失，因此绑定类遗物需要重新绑到新字上。
static func _rebuild_deck_chaos() -> void:
	var pool: Array = []
	for cd: CharacterData in Database.characters.values():
		if cd.is_pollution or cd.pending_design or cd.tags.has("enemy") or cd.tags.has("event") or cd.tags.has("彩蛋"):
			continue
		pool.append(cd)
	if pool.is_empty():
		return
	var old_count := GameState.deck.size()
	var bind_ids: Array = GameState.relics.filter(func(id): return needs_bind(id))
	GameState.deck.clear()
	for _i in old_count + 3:
		var cd: CharacterData = pool[GameState.rng.randi_range(0, pool.size() - 1)]
		GameState.deck.append(CharInstance.new(cd))
	GameState.relic_binds.clear()
	for id in bind_ids:
		for inst: CharInstance in GameState.deck:
			if GameState.bind_relic(str(id), inst.id()):
				break
	EventBus.deck_changed.emit()


## 战斗胜利后
static func on_battle_won() -> void:
	if not GameState.relics.has("egg"):
		return
	var n := int(GameState.relic_counters.get("egg", 0)) + 1
	GameState.relic_counters["egg"] = n
	if n % BattleBalance.i("egg_interval", 4) == 0:
		var g := ""
		if GameState.expedition != null:
			g = GameState.expedition.roll_glyph(1, false, GameState.expedition.relic_rng)
		else:
			var pool: Array = Database.characters.values().filter(func(cd): return not cd.is_pollution and not cd.pending_design and cd.rarity <= 2 and not cd.tags.has("enemy") and not cd.tags.has("彩蛋"))
			if not pool.is_empty():
				g = pool[GameState.rng.randi_range(0, pool.size() - 1)].glyph
		if not g.is_empty():
			_grant_glyph(g, "孕字卵")


static func _grant_glyph(g: String, why: String) -> void:
	if GameState.expedition != null:
		GameState.expedition.gain_glyph(g, why)
	else:
		GameState.add_character(Database.get_character_by_glyph(g))
