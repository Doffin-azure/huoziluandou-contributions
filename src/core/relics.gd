extends RefCounted
class_name Relics
## 遗物：常驻被动，跨战斗生效；按获得顺序记录在 GameState.relics。
## 设计来源：docs/遗物设计清单_2026-10-15.md，清单条目已全部接入；
## 默认取值与未定项见 docs/遗物接入说明_第一批.md、docs/遗物接入说明_第二批.md。
##
## 与印章的分工：印章管地图（视野、字匣、首领），遗物管战斗；两者互不占位。
## 战斗侧所有钩子都只读 BattleState.relics（开战时从 GameState 复制），测试可直接改它。

## id -> [名称, 说明, 是否需要绑定一枚字]
## 名称取自活字印刷作坊里的器物；内部 id 不变（存档、测试都用 id）
const DEFS := {
	"strike": ["刻刀", "带【击】的单字、词，每段攻击伤害 +2", false],
	"breach": ["蚀刻", "每场开局，所有敌人获得 2 层易伤", false],
	"slab": ["压字石", "选一枚字：它在盘面上始终下落；本场额外使用 5 次，用尽后本场移出", true],
	"press": ["对开版", "字盘变为 5×5；开局多补 4 枚字", false],
	"sleep": ["安神香", "休息处治疗额外 +20", false],
	"clean": ["净版布", "回合补字后，若盘面没有污染字，多补 1 枚", false],
	"wheel": ["转轮架", "每回合按 上、下、左、右 轮流让全盘下落", false],
	"powerbank": ["蓄电瓶", "每场开局获得 4 储能", false],
	"fireman": ["火种", "拾取时获得 4 枚【火】", false],
	"fertilizer": ["蔓生墨", "选一枚字：本场它变为临时字，每回合结束向四邻空格繁殖临时复制", true],
	"skyfire": ["天火", "打出【流火】时，额外对敌人造成 50 点伤害", false],
	"blitz": ["急就章", "每场第一回合结束后，敌人跳过这一次行动", false],
	"egg": ["字种", "每赢 4 场战斗，获得 1 枚字", false],
	"buckler": ["铜护板", "每场开局获得 4 持久盾", false],
	"barrier": ["纸屏风", "每场开局获得 10 临时格挡（第一回合有效）", false],
	# ---- 第二批（清单其余条目，默认取值见 docs/遗物接入说明_第二批.md）
	"chain": ["连珠盘", "每次出字后全盘下落；每场开局自动打出盘上已连成的词，补字后接着找，直到连不出（要选目标、要付费的词留给你）", false],
	"question": ["问字签", "每场开局从 3 枚能配词的字里挑 1 枚，作为本场临时字落到盘上", false],
	"goldleaf": ["泥金", "拾取时选两枚字，永久镀金", false],
	"moon": ["望月砚", "每场开局盘上多一枚临时【月】：它在场时，每次出字后其他字向它聚拢；打出【月】再聚拢一次；下回合消失", false],
	"loose": ["松字模", "己方字打出后有 5% 概率留在原位（和流连的概率相加）", false],
	"slot": ["签筒", "可以连出三枚相连的相同字，获得 50 金币", false],
	"chaos": ["乱字匣", "拾取时把字袋换成随机字，总数比原来多 3 枚；镀金和强化随之丢失，绑着遗物的字保留", false],
	"death": ["判词", "拾取时获得 1 枚【死】", false],
	"ruin": ["佚卷", "拾取时获得 1 枚【亡】", false],
	"rubbing": ["拓包", "拾取时选一枚字复制，保留镀金和强化", false],
	"resin": ["胶矾", "溢出的治疗转为等量持久盾；战斗外溢出的部分留到下一场开局", false],
	"magichand": ["补版钳", "每场前 3 个因出字腾空的格子立即补字", false],
	"midas": ["点金笔", "所有己方字永久镀金，之后拿到的也镀金；一场战斗累计赚到 20 金币时，你化为金像，立即死去", false],
	"monkey": ["愿文", "拾取时许一个愿：从 3 个有代价的愿望里选 1 个", false],
	"battery": ["裂电瓶", "获得的储能翻倍；每回合结束清空储能", false],
	"expiry": ["陈墨", "每场开局多补 2 枚字，但随机一枚字本场变成临时字，打出后本场不再回来", false],
	"palindrome": ["回文镜", "二字词可以倒着连出，发动原词效果；正着本身成词时按正着算", false],
	"binding": ["装订线", "同一行最左和最右两格视作相邻，可以跨边连词", false],
	"proof": ["校对尺", "本场每净化 2 枚污染字，随机补 1 字", false],
	"leadbox": ["空铅盒", "回合结束时，每有一整行为空，获得 2 持久盾", false],
}
## 拾取时要从字袋挑字的遗物：[动作, 挑几枚]。绑定类（石板、化肥）另见 DEFS 第三项。
const PICK := {"goldleaf": ["gild", 2], "rubbing": ["copy", 1]}
## 猴爪的愿望：id -> [名称, 说明]
const WISHES := {
	"endless_glyph": ["千字同文", "选一个字：字袋全部变成它，之后拿到的字也都是它；它每场额外使用 +2"],
	"endless_gold": ["点石成金", "获得遗物「点金笔」"],
	"endless_guard": ["固若金汤", "生命上限变为 1；每场开局获得 2 倍于失去上限的持久盾"],
	"endless_life": ["生生不息", "每场开局回复 99 生命，溢出的部分反噬为对自己的伤害"],
}
const WISH_SHOWN := 3
## 档次：1 常见 / 2 少见 / 3 稀有。中赏最多2档，大赏包含3档；商店按档定价。
const TIER := {
	"strike": 2, "breach": 2, "slab": 3, "press": 3, "sleep": 1, "clean": 1, "wheel": 2, "powerbank": 1,
	"fireman": 1, "fertilizer": 3, "skyfire": 2, "blitz": 2, "egg": 2, "buckler": 1, "barrier": 1,
	"chain": 3, "question": 2, "goldleaf": 2, "moon": 2, "loose": 1, "slot": 2, "chaos": 2, "death": 1,
	"ruin": 1, "rubbing": 1, "resin": 2, "magichand": 2, "midas": 3, "monkey": 3, "battery": 2, "expiry": 1,
	"palindrome": 2, "binding": 2, "proof": 1, "leadbox": 1,
}
const PRICE := {1: 35, 2: 50, 3: 70}
const EGG_EVERY := 4
const WHEEL_DIRS := ["up", "down", "left", "right"]
const WHEEL_TEXT := {"up": "上", "down": "下", "left": "左", "right": "右"}


static func name_of(id: String) -> String:
	return DEFS[id][0] if DEFS.has(id) else id


static func desc_of(id: String) -> String:
	return BattleBalance.relic_description(id, DEFS[id][1]) if DEFS.has(id) else ""


static func needs_bind(id: String) -> bool:
	return DEFS.has(id) and bool(DEFS[id][2])


static func text(id: String) -> String:
	return "「%s」%s" % [name_of(id), desc_of(id)]


## 还没拥有的遗物里随机挑 n 个（商店货架）
static func roll_choices(owned: Array, rng: RandomNumberGenerator, n := 1) -> Array:
	var pool: Array = DEFS.keys().filter(func(id): return not owned.has(id))
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(n, pool.size()))


static func price(id: String) -> int:
	return PRICE[TIER.get(id, 2)]


static func sell_price(id: String) -> int:
	return int(price(id) / 2)


# ---------------------------------------------------------------- 战斗钩子

static func board_size(rules: BattleRules, relics: Array) -> int:
	return maxi(rules.board_size, BattleBalance.i("press_board", 5)) if relics.has("press") else rules.board_size


static func opening_draw(rules: BattleRules, relics: Array) -> int:
	return rules.opening_draw + (BattleBalance.i("press_draw", 4) if relics.has("press") else 0) 		+ (BattleBalance.i("expiry_draw", 2) if relics.has("expiry") else 0)


## 洗袋之前：化肥母本换成本场临时副本；石板记下绑定的实体。
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
	# 猴爪·用不完的字：许愿的字每场额外使用 +2
	var wish_glyph := wish_glyph_id()
	if not wish_glyph.is_empty():
		for inst in b.bag:
			if inst.id() == wish_glyph:
				inst.temporary_uses += BattleBalance.i("wish_glyph_uses", 2)
	# 临期食品：随机一枚己方永久字本场换成临时副本，打出后本场不再回来
	if b.relics.has("expiry"):
		var pool: Array = b.bag.filter(func(inst): return not inst.temporary and inst.uid != b.slab_uid)
		if not pool.is_empty():
			var src: CharInstance = pool[b.rng.randi_range(0, pool.size() - 1)]
			var expired := src.clone()
			expired.temporary = true
			expired.temporary_uses = src.temporary_uses
			b.bag[b.bag.find(src)] = expired
			b.expired_uid = src.uid
			b.temp_chars.append(expired)
			b._log(name_of("expiry") + "：【%s】本场变为临时字" % expired.glyph())
	b.magic_left = BattleBalance.i("magichand_cells", 3) if b.relics.has("magichand") else 0


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
		b._log(name_of("barrier") + "：临时格挡 +%d" % BattleBalance.i("barrier_block", 10))
	if b.relics.has("buckler"):
		b.player.add_persistent_block(BattleBalance.i("buckler_block", 4))
		b._log(name_of("buckler") + "：持久盾 +%d" % BattleBalance.i("buckler_block", 4))
	if b.relics.has("powerbank"):
		b.add_energy(BattleBalance.i("powerbank_energy", 4))
		b._log(name_of("powerbank") + "：储能 +%d" % BattleBalance.i("powerbank_energy", 4))
	if b.relics.has("breach"):
		for e in b.alive_enemies():
			e.add_status("vulnerable", BattleBalance.i("breach_stacks", 2))
		b._log(name_of("breach") + "：敌人获得 %d 层易伤" % BattleBalance.i("breach_stacks", 2))
	if b.relics.has("blitz"):
		b.blitz_turn = 1
		b._log(name_of("blitz") + "：第一回合结束后，敌人跳过这一次行动")
	_battle_start_batch2(b)
	# 第一回合也按获得顺序发动一次重力（开局补字不走 begin_player_turn 的补字分支）
	apply_gravity_relics(b)
	run_chain(b)


## 普通回合补字之后（第一回合不调用）
static func after_turn_draw(b: BattleState) -> void:
	if b.relics.has("clean") and not board_dirty(b):
		if b.draw_to_board(BattleBalance.i("clean_draw", 1)) > 0:
			b._log(name_of("clean") + "：盘面没有污染字，多补 %d 枚" % BattleBalance.i("clean_draw", 1))


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
				b._log(name_of("wheel") + "：全盘向%s压" % WHEEL_TEXT[dir])
			"slab":
				slab_fall(b)
			"chain":
				b.apply_gravity()


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
		b._log(name_of("slab") + "：【%s】留在盘上（额外次数还剩 %d）" % [inst.glyph(), b.slab_uses])
		return "layer"
	b._log(name_of("slab") + "：【%s】次数用尽，本场移出" % inst.glyph())
	return "exhausted"


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
		b._log(name_of("fertilizer") + "：繁殖出 %d 枚临时【%s】" % [born, b.board.cells[parents[0]].glyph() if b.board.cells[parents[0]] != null else ""])


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
	b._log(name_of("skyfire") + "：对%s造成 %d 伤害" % [e.display_name, real])
	return ["天火：造成 %d 伤害" % real]


# ---------------------------------------------------------------- 战外钩子

static func rest_bonus() -> int:
	return BattleBalance.i("sleep_heal", 20) if GameState.relics.has("sleep") else 0


## 拾取效果（绑定类在 GameState.bind_relic 里另外处理）
static func on_pickup(id: String) -> void:
	match id:
		"death":
			_grant_glyph("死", name_of("death"))
		"ruin":
			_grant_glyph("亡", name_of("ruin"))
		"chaos":
			chaos_deck()
		"midas":
			for inst in GameState.deck:
				inst.gilded = true
		"fireman":
			# 一局只给一次【火】：卖掉再买 / 再熔出来不重复给
			if GameState.relic_counters.get("fireman_claimed", false):
				return
			GameState.relic_counters["fireman_claimed"] = true
			for i in BattleBalance.i("fireman_count", 4):
				_grant_glyph("火", name_of("fireman"))


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
			_grant_glyph(g, name_of("egg"))


static func _grant_glyph(g: String, why: String) -> void:
	if GameState.expedition != null:
		GameState.expedition.gain_glyph(g, why)
	else:
		GameState.add_character(Database.get_character_by_glyph(g))


# ---------------------------------------------------------------- 第二批：战斗钩子

## 自动出词不碰的词：会让自己死掉的彩蛋词
const CHAIN_SKIP := ["死亡"]
const CHAIN_MAX := 30


## 开局：盾、回血类先结算，再放【月】、准备问字签
static func _battle_start_batch2(b: BattleState) -> void:
	if b.relics.has("resin"):
		b.player.overheal_to_persistent = true
		var carried := int(GameState.relic_counters.get("resin_block", 0))
		if carried > 0:
			GameState.relic_counters["resin_block"] = 0
			b.player.add_persistent_block(carried)
			b._log(name_of("resin") + "：带入上一段溢出的治疗，持久盾 +%d" % carried)
	var wish: Dictionary = GameState.relic_counters.get("monkey", {}) if b.relics.has("monkey") else {}
	match str(wish.get("wish", "")):
		"endless_guard":
			var guard := int(wish.get("guard", 0))
			if guard > 0:
				b.player.add_persistent_block(guard)
				b._log(WISHES.endless_guard[0] + "：持久盾 +%d" % guard)
		"endless_life":
			var amount := BattleBalance.i("wish_life_heal", 99)
			var overflow := maxi(0, b.player.hp + amount - b.player.max_hp)
			b.player.heal(amount)
			# 树脂先把溢出转成盾；没有树脂才反噬
			if overflow > 0 and not b.player.overheal_to_persistent:
				var lost := b.player.take_damage(overflow)
				b._log(WISHES.endless_life[0] + "：回复 %d，溢出 %d 反噬，实际失去 %d 生命" % [amount, overflow, lost])
			else:
				b._log(WISHES.endless_life[0] + "：回复 %d 生命" % amount)
	if b.relics.has("moon"):
		_place_moon(b)
	if b.relics.has("question"):
		b.question_choices = question_options(b)
	if b.relics.has("binding"):
		b.board.wrap_rows = true


## 每次成功出字后（含自动出词）：重力类遗物按获得顺序，再月聚拢，最后补版钳补位
static func after_play(b: BattleState) -> void:
	var changed := false
	for id in b.relics:
		match id:
			"slab":
				slab_fall(b)
				changed = true
			"chain":
				b.apply_gravity()
				changed = true
	var moon := moon_pos(b)
	if moon.x >= 0:
		var moved := b.converge_to(moon)
		if moved > 0:
			changed = true
			b._log(name_of("moon") + "：%d 枚字向【月】聚拢" % moved)
	if b.magic_left > 0:
		var filled := 0
		for pos in b.last_vacated:
			if b.magic_left <= 0:
				break
			if b.board.get_xy(pos) == null and b.draw_one_to(pos) != null:
				b.magic_left -= 1
				filled += 1
		if filled > 0:
			changed = true
			b._log(name_of("magichand") + "：立即补位 %d 格（本场还剩 %d）" % [filled, b.magic_left])
	if changed:
		for e in b.alive_enemies():
			EnemyMechanics.update_targets(b, e)


## 回合开局补字之前：上回合的【月】消失
static func on_turn_start(b: BattleState) -> void:
	if b.moon_uid < 0 or b.turn <= b.moon_turn:
		return
	for i in b.board.cells.size():
		var c: CharInstance = b.board.cells[i]
		if c != null and c.uid == b.moon_uid:
			b.board.cells[i] = null
			b.temp_chars.erase(c)
			b._log(name_of("moon") + "：【月】消失")
	b.moon_uid = -1


## 回合结束、敌人行动之前：空铅盒结算空行；坏电池清空储能
static func on_turn_end(b: BattleState) -> void:
	if b.relics.has("leadbox"):
		var rows := 0
		var n := b.board.size
		for y in n:
			var empty := true
			for x in n:
				if b.board.get_cell(x, y) != null:
					empty = false
					break
			if empty:
				rows += 1
		if rows > 0:
			b.player.add_persistent_block(rows * BattleBalance.i("leadbox_block", 2))
			b._log(name_of("leadbox") + "：%d 整行为空，持久盾 +%d" % [rows, rows * BattleBalance.i("leadbox_block", 2)])
	if b.relics.has("battery") and b.player.energy > 0:
		b._log(name_of("battery") + "：储能 %d 清空" % b.player.energy)
		b.player.energy = 0


## 坏电池：获得的储能翻倍
static func energy_gain(b: BattleState, amount: int) -> int:
	return amount * 2 if amount > 0 and b.relics.has("battery") else amount


## 不稳定字模（+5%）与流连（+50%）相加，只算己方字
static func retain_chance(b: BattleState, inst: CharInstance) -> float:
	var chance := 0.5 if b.has_ability("linger_chance") else 0.0
	if b.relics.has("loose") and not inst.is_enemy_owned():
		chance += BattleBalance.i("loose_percent", 5) / 100.0
	return chance


## 迈达斯之手：本场累计收入达到 20 金币就化为金像
static func on_gold_earned(b: BattleState) -> void:
	if b.relics.has("midas") and b.player.is_alive() and b.gold_earned >= BattleBalance.i("midas_gold", 20):
		b.player.hp = 0
		b._log(name_of("midas") + "：本场已赚 %d 金币，你化为了金像" % b.gold_earned)


## 校对尺：本场每净化 2 枚污染字，随机补 1 字
static func on_cleansed(b: BattleState, count: int) -> void:
	if count <= 0 or not b.relics.has("proof"):
		return
	b.cleansed_count += count
	var need := BattleBalance.i("proof_every", 2)
	while b.cleansed_count >= need:
		b.cleansed_count -= need
		if b.draw_to_board(1) > 0:
			b._log(name_of("proof") + "：净化满 %d 枚，补 1 字" % need)


## 查不到词时的遗物补充：回文镜（二字倒连）、老虎机（三枚相同字）
static func fallback_word(b: BattleState, glyphs: Array) -> WordData:
	if glyphs.size() == 2 and b.relics.has("palindrome"):
		var reversed := Database.get_word_by_glyphs([glyphs[1], glyphs[0]])
		if reversed != null:
			return reversed
	if glyphs.size() == 3 and b.relics.has("slot") and glyphs[0] == glyphs[1] and glyphs[1] == glyphs[2]:
		return slot_word(glyphs[0])
	return null


static func slot_word(glyph: String) -> WordData:
	var gold := BattleBalance.i("slot_gold", 50)
	var eff := EffectData.new()
	eff.kind = EffectData.Kind.GAIN_GOLD
	eff.handler = "gold"
	eff.amount = gold
	eff.note = "获得 %d 金币" % gold
	var w := WordData.new()
	w.id = "relic_slot"
	w.word = glyph.repeat(3)
	var gs: Array[String] = [glyph, glyph, glyph]
	w.glyphs = gs
	w.description = name_of("slot") + "：三连【%s】，获得 %d 金币" % [glyph, gold]
	w.effect_summary = w.description
	var list: Array[EffectData] = [eff]
	w.effects = list
	w.effect_handler_id = "gold"
	w.implemented = true
	return w


# ---- 月

static func _place_moon(b: BattleState) -> void:
	var cd := Database.get_character_by_glyph("月")
	var empties: Array = b.board.empty_indices()
	if cd == null or empties.is_empty():
		return
	var inst := CharInstance.new(cd)
	inst.owner = CharInstance.Owner.PLAYER
	inst.temporary = true
	var pos: Vector2i = empties[b.rng.randi_range(0, empties.size() - 1)]
	b.board.set_xy(pos, inst)
	b.temp_chars.append(inst)
	b.moon_uid = inst.uid
	b.moon_turn = b.turn
	b._log(name_of("moon") + "：盘上出现一枚【月】")


static func moon_pos(b: BattleState) -> Vector2i:
	if b.moon_uid < 0:
		return Vector2i(-1, -1)
	for i in b.board.cells.size():
		var c: CharInstance = b.board.cells[i]
		if c != null and c.uid == b.moon_uid:
			return b.board.to_xy(i)
	return Vector2i(-1, -1)


# ---- 问字签

## 三枚候选：优先能和盘上字组成二字词的字
static func question_options(b: BattleState) -> Array:
	var allowed := {}
	for cd in Database.characters.values():
		if not cd.is_pollution and not cd.pending_design and not cd.tags.has("enemy") and not cd.tags.has("彩蛋") and cd.rarity <= 3:
			allowed[cd.glyph] = true
	var on_board := {}
	for c in b.board.cells:
		if c != null:
			on_board[c.glyph()] = true
	var fits: Array = []
	for w in Database.words.values():
		if not w.implemented or w.glyphs.size() != 2:
			continue
		for i in 2:
			var other: String = w.glyphs[1 - i]
			if on_board.has(w.glyphs[i]) and allowed.has(other) and not fits.has(other):
				fits.append(other)
	var rest: Array = allowed.keys().filter(func(g): return not fits.has(g))
	var out: Array = []
	for list in [fits, rest]:
		while out.size() < 3 and not list.is_empty():
			out.append(list.pop_at(b.rng.randi_range(0, list.size() - 1)))
	return out


## 选中的字作为本场临时字落到随机空格；盘满就放到袋顶，下一次补字先出它
static func take_question(b: BattleState, glyph: String) -> bool:
	if not b.question_choices.has(glyph):
		return false
	b.question_choices.clear()
	var inst := CharInstance.new(Database.get_character_by_glyph(glyph))
	inst.owner = CharInstance.Owner.PLAYER
	inst.temporary = true
	b.temp_chars.append(inst)
	var empties: Array = b.board.empty_indices()
	if empties.is_empty():
		b.bag.push_back(inst)
	else:
		b.board.set_xy(empties[b.rng.randi_range(0, empties.size() - 1)], inst)
	b._log(name_of("question") + "：本场加入临时【%s】" % glyph)
	return true


# ---- 消消乐

## 开局自动出词：长词优先，同长按左上起点；每打一个，补回腾空的格子再找
static func run_chain(b: BattleState) -> void:
	if not b.relics.has("chain"):
		return
	for step in CHAIN_MAX:
		var found := chain_words(b)
		if found.is_empty():
			return
		found.sort_custom(func(x, y):
			if x.path.size() != y.path.size():
				return x.path.size() > y.path.size()
			return b.board.from_xy(x.path[0]) < b.board.from_xy(y.path[0]))
		var played := false
		var empty_before: int = b.board.empty_indices().size()
		for f in found:
			if b.try_play(f.path).get("ok", false):
				b._log(name_of("chain") + "：自动打出【%s】" % f.word.word)
				played = true
				break
		if not played or b.is_over():
			return
		var refill: int = b.board.empty_indices().size() - empty_before
		if refill > 0:
			b.draw_to_board(refill)


## 盘上当前能自动打出的词：[{word, path}]，同一个词只留一条路径
static func chain_words(b: BattleState) -> Array:
	var trie := {}
	for w in Database.words.values():
		if not _chain_ok(w):
			continue
		var node: Dictionary = trie
		for g in w.glyphs:
			if not node.has(g):
				node[g] = {}
			node = node[g]
		node["#"] = w
	var found: Array = []
	var seen := {}
	for i in b.board.cells.size():
		var c: CharInstance = b.board.cells[i]
		if c != null and trie.has(c.glyph()):
			_chain_dfs(b, [b.board.to_xy(i)], trie[c.glyph()], found, seen)
	return found


## 要选目标、要付费、要额外交互的词不自动打
static func _chain_ok(w: WordData) -> bool:
	if not w.implemented or w.glyphs.size() < 2 or CHAIN_SKIP.has(w.word) or not w.interaction.is_empty():
		return false
	if not BattleState.has_required_target(w.requires_target, {}):
		return false
	for eff in w.effects:
		if eff.args.keys().any(func(k): return str(k).contains("cost")):
			return false
		if eff.target in [EffectData.Target.BOARD_TILE, EffectData.Target.BOARD_ROW, EffectData.Target.BOARD_2X2, EffectData.Target.BOARD_3X3, EffectData.Target.EMPTY_TILE, EffectData.Target.DISCARD_GLYPH, EffectData.Target.BAG_GLYPH, EffectData.Target.ENEMY_GLYPH]:
			return false
	return true


static func _chain_dfs(b: BattleState, path: Array, node: Dictionary, found: Array, seen: Dictionary) -> void:
	if node.has("#") and not seen.has(node["#"].id):
		seen[node["#"].id] = true
		found.append({"word": node["#"], "path": path.duplicate()})
	for nxt in b.board.path_extensions(path):
		if path.has(nxt) or not b.board.in_bounds(nxt.x, nxt.y):
			continue
		var c: CharInstance = b.board.get_xy(nxt)
		if c == null or not node.has(c.glyph()) or not b.board.valid_path(path + [nxt]):
			continue
		_chain_dfs(b, path + [nxt], node[c.glyph()], found, seen)


# ---------------------------------------------------------------- 第二批：战外

## 拾取时要挑字的遗物：返回 [动作, 枚数]；不需要时为空
static func pick_spec(id: String) -> Array:
	return PICK.get(id, [])


## 泥金 / 拓板：对字袋里一枚该字形的永久实体执行动作；镀金跳过已镀金的
static func apply_pick(id: String, glyph_id: String) -> bool:
	var spec := pick_spec(id)
	if spec.is_empty():
		return false
	for inst in GameState.deck:
		if inst.id() != glyph_id or inst.temporary:
			continue
		match str(spec[0]):
			"gild":
				if inst.gilded:
					continue
				inst.gilded = true
				return true
			"copy":
				var copy: CharInstance = inst.clone()
				copy.temporary = false
				copy.temporary_uses = 0
				copy.pinned = false
				GameState.deck.append(copy)
				EventBus.deck_changed.emit()
				return true
	return false


## 字袋里还能被该遗物挑中的字形 -> 枚数
static func pick_candidates(id: String) -> Dictionary:
	var spec := pick_spec(id)
	var out := {}
	for inst in GameState.deck:
		if inst.temporary or (not spec.is_empty() and spec[0] == "gild" and inst.gilded):
			continue
		out[inst.id()] = int(out.get(inst.id(), 0)) + 1
	return out


## 混乱转化：总数 N 变成 N+3，绑着遗物的字原样保留，其余换成随机字
static func chaos_deck() -> void:
	var bound: Array = GameState.relic_binds.values()
	var keep: Array = GameState.deck.filter(func(inst): return bound.has(inst.uid))
	var total: int = GameState.deck.size() + BattleBalance.i("chaos_extra", 3)
	var pool: Array = Database.characters.values().filter(func(cd): return not cd.is_pollution and not cd.pending_design and cd.rarity <= 2 and not cd.tags.has("enemy") and not cd.tags.has("彩蛋"))
	GameState.deck.assign(keep)
	while GameState.deck.size() < total and not pool.is_empty():
		GameState.deck.append(CharInstance.new(pool[GameState.rng.randi_range(0, pool.size() - 1)]))
	EventBus.deck_changed.emit()


## 猴爪：可许的愿望（已有金身就不出「花不完的钱」），随机给 3 个
static func wish_options(rng: RandomNumberGenerator) -> Array:
	var pool: Array = WISHES.keys().filter(func(w): return w != "endless_gold" or not GameState.has_relic("midas"))
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(WISH_SHOWN, pool.size()))


static func wish_text(wish: String) -> String:
	return "「%s」%s" % [WISHES[wish][0], WISHES[wish][1]] if WISHES.has(wish) else ""


## 许愿（一件猴爪只许一次）；用不完的字要带上选中的字形 id
static func grant_wish(wish: String, glyph_id := "") -> bool:
	if not GameState.has_relic("monkey") or not WISHES.has(wish) or GameState.relic_counters.has("monkey"):
		return false
	var record := {"wish": wish}
	match wish:
		"endless_glyph":
			var cd := Database.get_character(glyph_id)
			if cd == null:
				return false
			record["glyph"] = cd.id
			for inst in GameState.deck:
				inst.data = cd
				inst.fusion.clear()
			EventBus.deck_changed.emit()
		"endless_gold":
			GameState.relic_counters["monkey"] = record
			GameState.add_relic("midas")
			return true
		"endless_guard":
			var lost := maxi(0, GameState.player_max_hp - 1)
			record["guard"] = lost * BattleBalance.i("wish_guard_mult", 2)
			GameState.player_max_hp = 1
			GameState.player_hp = 1
			EventBus.hp_changed.emit(GameState.player_hp, GameState.player_max_hp)
	GameState.relic_counters["monkey"] = record
	return true


static func wish_glyph_id() -> String:
	if not GameState.relics.has("monkey"):
		return ""
	return str(GameState.relic_counters.get("monkey", {}).get("glyph", ""))


## 之后拿到的字：用不完的字把它换成许愿的字
static func redirect_glyph(cd: CharacterData) -> CharacterData:
	var id := wish_glyph_id()
	if id.is_empty() or Database.get_character(id) == null:
		return cd
	return Database.get_character(id)


## 战斗外的治疗溢出：树脂记下来，下一场开局转成持久盾
static func store_overheal(amount: int) -> void:
	if amount > 0 and GameState.relics.has("resin"):
		GameState.relic_counters["resin_block"] = int(GameState.relic_counters.get("resin_block", 0)) + amount
