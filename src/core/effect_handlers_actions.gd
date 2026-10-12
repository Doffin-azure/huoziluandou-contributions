extends RefCounted
class_name EffectHandlersActions
## 复杂词效的具体实现：盘面改造、融合/叠层、揭示与回收、持续能力等。

const CREMATE_FLAVOR := [
	"……走好。",
	"烧得很干净。",
	"这词到底有什么用？",
	"尘归尘，土归土。",
	"至少它很上镜。",
	"建议配合【热】一起使用（开玩笑的）。",
	"亡者安息。",
]

static func _merge_duplicates(b: BattleState, ctx: Dictionary) -> Array:
	var anchor: Vector2i = EffectUtil.tile(ctx)
	var inst: CharInstance = b.board.get_xy(anchor)
	if inst == null:
		return ["重合：目标格没有字"]
	var glyph := inst.glyph()
	var tiles: Array = []
	for i in b.board.cells.size():
		var c: CharInstance = b.board.cells[i]
		if c != null and c.glyph() == glyph and c.is_player_owned():
			tiles.append(b.board.to_xy(i))
	if tiles.size() < 2:
		return ["重合：没有重复的己方【%s】" % glyph]
	var total := 0
	for pos in tiles:
		var c: CharInstance = b.board.get_xy(pos)
		total += 1 + c.temporary_uses
	for pos in tiles:
		if pos == anchor:
			continue
		var c: CharInstance = b.board.get_xy(pos)
		b.bag.append(c)
		b.board.clear_xy(pos)
	inst.temporary_uses = total - 1
	b._shuffle(b.bag)
	return ["重合：保留 1 枚【%s】，获得 %d 次临时使用，其余 %d 枚回字袋" % [glyph, total - 1, tiles.size() - 1]]

static func _replay_last_attack(b: BattleState) -> Array:
	if b.last_attack_word == null or b.last_attack_effects.is_empty():
		return ["连击：此前没有可重演的即时攻击"]
	var msgs: Array = []
	for e in b.last_attack_effects:
		if e.handler == "replay_last_attack":
			continue  # 禁止递归
		var sub := {"battle": b, "source": b.player, "glyphs": b.last_attack_glyphs,
			"target": {"target_index": b.last_attack_target}, "target_index": b.last_attack_target}
		msgs.append_array(EffectHandlers.run(e.handler, e, sub))
	if msgs.is_empty():
		msgs.append("连击：重演【%s】" % b.last_attack_word.word)
	return msgs


## 回放：把上一个词用过的字放回盘面（原格优先，被占则找空格）。
static func _replay_word(b: BattleState) -> Array:
	if b.last_played_consumed.is_empty():
		return ["回放：此前没有可回放的词"]
	var placed := 0
	for item in b.last_played_consumed:
		var inst: CharInstance = item["inst"]
		var pos: Vector2i = item["pos"]
		if b.board.get_xy(pos) != null:
			var empties: Array = b.board.empty_indices()
			if empties.is_empty():
				break
			pos = empties[0]
		b.discard.erase(inst)
		b.consumed_this_turn.erase(inst)
		inst.owner = CharInstance.Owner.PLAYER
		b.board.set_xy(pos, inst)
		placed += 1
	return ["回放：将上一个词用过的 %d 枚字放回盘面" % placed]


## 放回：移除字盘上一枚敌方实体字，将其退回（不造成伤害、不触发污染）。
static func _return_enemy(b: BattleState, ctx: Dictionary) -> Array:
	var pos: Vector2i = EffectUtil.tile(ctx)
	var inst: CharInstance = b.board.get_xy(pos)
	if inst == null or not inst.is_enemy_owned():
		return ["放回：请选择一枚敌方实体字"]
	b.temp_chars.erase(inst)
	b.board.set_xy(pos, null)
	return ["放回：将敌方【%s】退回" % inst.glyph()]

static func _recover_consumed(b: BattleState, ctx: Dictionary) -> Array:
	if b.consumed_this_turn.is_empty():
		return ["回收：本回合没有消耗过实体字"]
	var idx: int = int(ctx.get("target", {}).get("discard_index", b.consumed_this_turn.size() - 1))
	idx = clampi(idx, 0, b.consumed_this_turn.size() - 1)
	var inst: CharInstance = b.consumed_this_turn[idx]
	b.consumed_this_turn.remove_at(idx)
	b.bag.append(inst)   # 放回抽字袋顶（原型：袋顶=数组尾）
	return ["回收：把【%s】放回抽字袋顶" % inst.glyph()]

static func _cleanse_adjacent(b: BattleState, ctx: Dictionary) -> Array:
	var tile: Vector2i = EffectUtil.tile(ctx)
	var n := 0
	for pos in [tile] + b.board.neighbors(tile):
		var c: CharInstance = b.board.get_xy(pos)
		if c != null and not c.pollutions.is_empty():
			c.clear_pollutions()
			n += 1
	return ["清：净化 %d 处污染（所有权不变）" % n]

static func _capture_glyph(b: BattleState, ctx: Dictionary, cost: int) -> Array:
	var tile: Vector2i = ctx.get("target", {}).get("enemy_glyph", EffectUtil.tile(ctx))
	var inst: CharInstance = b.board.get_xy(tile)
	if inst == null or not inst.is_enemy_owned():
		return ["收购：请选择一枚敌方实体字"]
	if not EffectUtil.pay(b, cost):
		return ["收购：支付额不足（需 %d）" % cost]
	inst.owner = CharInstance.Owner.PLAYER
	inst.clear_pollutions()
	b.board.clear_xy(tile)
	b.captured_chars.append(inst)
	return ["收购：支付 %d 金币，永久收编【%s】" % [cost, inst.glyph()]]

static func _empower_glyph(b: BattleState, ctx: Dictionary) -> Array:
	var g: String = str(ctx.get("target", {}).get("empower_glyph", ""))
	if g.is_empty():
		return ["强化：请选择一个字"]
	b.empowered_glyphs[g] = true
	return ["强化：本场【%s】被打出时额外触发其单字效果" % g]

static func _refine_remove(b: BattleState, ctx: Dictionary, eff: EffectData) -> Array:
	var heat_down: int = int(eff.args.get("heat", 3))
	var gold_up: int = int(eff.args.get("gold", 4))
	b.player.add_heat(-heat_down)
	EffectUtil.add_gold(b, gold_up)
	var msgs: Array = ["炼化：热度 -%d，获得 %d 金币" % [heat_down, gold_up]]
	var g: String = str(ctx.get("target", {}).get("remove_glyph", ""))
	var removed: CharInstance = b.remove_from_battle_glyph(g)
	if removed != null:
		msgs.append("将【%s】移出本场战斗循环（战后回归）" % g)
	else:
		msgs.append("（未指定要移除的牌）")
	return msgs

static func _cremate(b: BattleState, ctx: Dictionary, _eff: EffectData) -> Array:
	var path: Array = ctx.get("path", [])
	var glyphs: Array = ctx.get("glyphs", [])
	if path.is_empty():
		return ["火化：无处安放骨灰"]
	var new_glyphs: Array = ["骨", "灰"]
	var placed: Array = []
	for i in path.size():
		var pos: Vector2i = path[i]
		if i >= new_glyphs.size():
			continue
		if b.board.get_xy(pos) != null:
			continue
		var ci: CharInstance = b.create_temp_glyph(new_glyphs[i])
		if ci == null:
			continue
		b.board.set_xy(pos, ci)
		placed.append(new_glyphs[i])
	if placed.is_empty():
		return ["火化：没有留下骨灰"]
	var line: String = CREMATE_FLAVOR[b.visual_rng.randi_range(0, CREMATE_FLAVOR.size() - 1)]
	return ["火化：【%s】原地化为【%s】。%s" % ["".join(glyphs), "".join(placed), line]]

static func _fuse_cards(b: BattleState, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx.get("target", {})
	var p1: Vector2i = t.get("tile", Vector2i(-1, -1))
	var p2: Vector2i = t.get("tile2", Vector2i(-1, -1))
	var res: Dictionary = b.fuse_cards(p1, p2)
	return [str(res.get("msg", "化合失败"))]

static func _refine_layer(b: BattleState, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx.get("target", {})
	var p1: Vector2i = t.get("tile", Vector2i(-1, -1))
	var p2: Vector2i = t.get("tile2", Vector2i(-1, -1))
	var res: Dictionary = b.refine_pair(p1, p2)
	return [str(res.get("msg", "精炼失败"))]

static func _gild_glyph(b: BattleState, ctx: Dictionary) -> Array:
	var g: String = str(ctx.get("target", {}).get("gild_glyph", ""))
	if g.is_empty():
		return ["精金：请选择一枚己方字"]
	var n := 0
	for inst in GameState.deck:
		if inst.glyph() == g:
			inst.gilded = true
			n += 1
	for c in b.board.cells:
		if c != null and c.is_player_owned() and c.glyph() == g:
			c.gilded = true
	if n == 0:
		return ["精金：字袋中没有【%s】" % g]
	return ["精金：【%s】×%d 被永久镀金（每次参与多字词 +1 金币）" % [g, n]]


## 精铸：把盘面一枚己方实体字固定（本场不消耗、可反复使用；不可移动/换字）。
static func _pin_glyph(b: BattleState, ctx: Dictionary) -> Array:
	var pos: Vector2i = EffectUtil.tile(ctx)
	var inst: CharInstance = b.board.get_xy(pos)
	if inst == null or not inst.is_player_owned() or inst.temporary:
		return ["精铸：请选择一枚己方实体字"]
	if inst.pinned:
		return ["精铸：【%s】已经固定" % inst.glyph()]
	inst.pinned = true
	return ["精铸：将【%s】固定（本场可反复使用，不可移动/换字）" % inst.glyph()]

static func _precision_place(b: BattleState, ctx: Dictionary, eff: EffectData) -> Array:
	var cost: int = eff.amount
	var tile: Vector2i = EffectUtil.tile(ctx)
	if b.board.get_xy(tile) != null:
		return ["精铸：目标格已被占用"]
	if EffectUtil.available(b) < cost:
		return ["精铸：支付额不足（需 %d）" % cost]
	var uid: int = int(ctx.get("target", {}).get("place_uid", -1))
	var inst: CharInstance = b.take_from_discard_by_uid(uid)
	if inst == null:
		return ["精铸：请选择弃字堆中的一枚己方字"]
	EffectUtil.pay(b, cost)
	inst.owner = CharInstance.Owner.PLAYER
	b.board.set_xy(tile, inst)
	return ["精铸：支付 %d，将【%s】放入指定空格" % [cost, inst.glyph()]]

## 急流：选一行/列，将己方实体字洗回字袋，再向原位置随机补入相同数量。
static func _reshuffle_line(b: BattleState, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx.get("target", {})
	var positions: Array = []
	if t.has("row"):
		var row: int = int(t["row"])
		for x in b.board.size:
			positions.append(Vector2i(x, row))
	elif t.has("col"):
		var col: int = int(t["col"])
		for y in b.board.size:
			positions.append(Vector2i(col, y))
	else:
		return ["急流：请选择一行或一列"]
	var returned: Array = []
	for p in positions:
		var inst: CharInstance = b.board.get_xy(p)
		if inst != null and inst.is_player_owned() and not inst.temporary:
			returned.append(inst)
			b.board.clear_xy(p)
	for inst2 in returned:
		b.bag.append(inst2)
	if not returned.is_empty():
		b._shuffle(b.bag)
	var filled := 0
	for p2 in positions:
		if b.board.get_xy(p2) != null:
			continue
		if b.bag.is_empty():
			break
		b.board.set_xy(p2, b.bag.pop_back())
		filled += 1
	return ["急流：洗回 %d 枚，原格补入 %d 枚" % [returned.size(), filled]]


## 火急：把揭示的 2 枚字放进指定空格。
static func _place_two(b: BattleState, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx.get("target", {})
	var cells: Array = [t.get("cell1", Vector2i(-1, -1)), t.get("cell2", Vector2i(-1, -1))]
	var reveal: Array = b.pending_reveal
	var placed := 0
	for i in mini(reveal.size(), 2):
		var inst: CharInstance = reveal[i]
		if inst == null:
			continue
		if b.board.get_xy(cells[i]) != null:
			continue
		inst.owner = CharInstance.Owner.PLAYER
		b.board.set_xy(cells[i], inst)
		placed += 1
	b.pending_reveal = []
	return ["火急：补入 %d 字（热度 +2）" % placed]


## 收复：把弃字堆中的 1～2 枚己方实体字放回指定空格。
static func _recover_two(b: BattleState, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx.get("target", {})
	var places: Array = t.get("places", [])
	var placed := 0
	for item in places:
		var uid: int = int(item[0])
		var cell: Vector2i = item[1]
		if b.board.get_xy(cell) != null:
			continue
		var inst: CharInstance = b.take_from_discard_by_uid(uid)
		if inst == null:
			continue
		inst.owner = CharInstance.Owner.PLAYER
		b.board.set_xy(cell, inst)
		placed += 1
	return ["收复：从弃字堆放回 %d 枚" % placed]


## 收回：把盘上一枚己方实体字置于字袋顶，再从弃字堆放一枚到原格。
static func _recover_to_bag(b: BattleState, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx.get("target", {})
	var tile: Vector2i = t.get("tile", Vector2i(-1, -1))
	var inst: CharInstance = b.board.get_xy(tile)
	if inst == null or not inst.is_player_owned():
		return ["收回：请选择一枚己方实体字"]
	b.board.clear_xy(tile)
	b.bag.append(inst)
	var uid: int = int(t.get("place_uid", -1))
	var di: CharInstance = b.take_from_discard_by_uid(uid)
	if di != null:
		di.owner = CharInstance.Owner.PLAYER
		b.board.set_xy(tile, di)
		return ["收回：【%s】回袋顶，从弃字堆放入【%s】" % [inst.glyph(), di.glyph()]]
	return ["收回：【%s】回袋顶" % inst.glyph()]


## 收放：把盘上一枚字移动到任意空格。
static func _move_cell(b: BattleState, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx.get("target", {})
	var a: Vector2i = t.get("tile", Vector2i(-1, -1))
	var c: Vector2i = t.get("tile2", Vector2i(-1, -1))
	var inst: CharInstance = b.board.get_xy(a)
	if inst == null:
		return ["收放：请选择要移动的字"]
	if inst.pinned:
		return ["收放：固定的字不可移动"]
	if b.board.get_xy(c) != null:
		return ["收放：目标格已被占用"]
	b.board.clear_xy(a)
	b.board.set_xy(c, inst)
	return ["收放：将【%s】移动一格" % inst.glyph()]


static func _split_mind(b: BattleState) -> Array:
	b.enable_ability("split_mind", 1)
	return ["精分：本回合敌我攻击都打向自己……"]

static func _vigor(b: BattleState) -> Array:
	b.enable_ability("vigor", 1)
	return ["精力：本回合每种不同多字词，使下回合基础补字 +1"]

static func _charge_overheat(b: BattleState, eff: EffectData) -> Array:
	var en: int = int(eff.args.get("energy", 8))
	var ht: int = int(eff.args.get("heat", 8))
	b.add_energy(en)
	b.add_heat(ht)
	b.enable_ability("auto_refill", 1)
	return ["充电过热：获得 %d 储能 + %d 热度；此后每次出字立即补位" % [en, ht]]

static func _recast_board(b: BattleState) -> Array:
	var count := b.board.fill_count()
	if count == 0:
		return ["重铸：盘面没有字"]
	for i in b.board.cells.size():
		var c: CharInstance = b.board.cells[i]
		if c == null:
			continue
		if c.temporary or not c.is_player_owned():
			b.temp_chars.erase(c)
		else:
			b.bag.append(c)
		b.board.cells[i] = null
	b._shuffle(b.bag)
	var drawn := b.draw_to_board(count)
	return ["重铸：盘面 %d 枚字全部重新替换（补回 %d）" % [count, drawn]]

static func _recast_copy(b: BattleState, ctx: Dictionary) -> Array:
	var tile: Vector2i = EffectUtil.tile(ctx)
	if b.board.get_xy(tile) != null:
		return ["再铸：目标格已被占用"]
	var uid: int = int(ctx.get("target", {}).get("place_uid", -1))
	var src: CharInstance = b.get_discard_by_uid(uid)
	if src == null:
		return ["再铸：请选择弃字堆中的一枚字"]
	var copy: CharInstance = src.clone()
	copy.owner = CharInstance.Owner.PLAYER
	copy.temporary = true
	b.temp_chars.append(copy)
	b.board.set_xy(tile, copy)
	return ["再铸：将【%s】的临时复制放入指定空格（原牌留在弃字堆）" % src.glyph()]


## 收心：将所选盘面己方牌放回抽字袋，每选 1 枚回复 1 生命（可 0 张）。
static func _collect_own(b: BattleState, ctx: Dictionary) -> Array:
	var cells: Array = ctx.get("target", {}).get("cells", [])
	var n := 0
	for cell in cells:
		var pos: Vector2i = cell
		var inst: CharInstance = b.board.get_xy(pos)
		if inst == null or not inst.is_player_owned() or inst.temporary or inst.pinned:
			continue
		b.board.set_xy(pos, null)
		b.bag.append(inst)
		n += 1
	if n > 0:
		b.player.heal(n)
	return ["收心：将 %d 枚字放回抽字袋，回复 %d 生命" % [n, n]]


## 再铸：将所选 3 个盘面字替换为随机临时字（随机字不一定在玩家牌组里）。
static func _recast_three(b: BattleState, ctx: Dictionary) -> Array:
	var cells: Array = ctx.get("target", {}).get("cells", [])
	if cells.size() < 3:
		return ["再铸：请选择 3 个盘面字"]
	var pool: Array = []
	for c in Database.characters.values():
		if not c.is_pollution and not c.pending_design and not c.tags.has("enemy"):
			pool.append(c)
	if pool.is_empty():
		return ["再铸：无可用随机字"]
	var replaced := 0
	for cell in cells:
		var pos: Vector2i = cell
		if b.board.get_xy(pos) == null:
			continue
		var cd: CharacterData = pool[b.rng.randi_range(0, pool.size() - 1)]
		var copy := CharInstance.new(cd)
		copy.owner = CharInstance.Owner.PLAYER
		copy.temporary = true
		b.temp_chars.append(copy)
		b.board.set_xy(pos, copy)
		replaced += 1
	return ["再铸：将 %d 枚字替换为随机临时字" % replaced]

static func _repeat_last(b: BattleState, ctx: Dictionary) -> Array:
	if b.last_played_glyphs.is_empty():
		return ["再：此前没有可重复的字"]
	var g: String = str(b.last_played_glyphs[b.last_played_glyphs.size() - 1])
	var copy: CharInstance = b.create_temp_glyph(g)
	if copy == null:
		return ["再：无法重复【%s】" % g]
	var path: Array = ctx.get("path", [])
	var placed_pos := Vector2i(-1, -1)
	if not path.is_empty() and b.board.get_xy(path[0]) == null:
		placed_pos = path[0]
	else:
		var empties := b.board.empty_indices()
		if not empties.is_empty():
			placed_pos = empties[0]
	if placed_pos == Vector2i(-1, -1):
		return ["再：没有空格放置重复的字"]
	b.board.set_xy(placed_pos, copy)
	return ["再：重复上一个字的【%s】（临时）" % g]

static func _reverse_line(b: BattleState, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx.get("target", {})
	var n := b.board.size
	if t.has("row"):
		var y: int = int(t["row"])
		if y < 0 or y >= n:
			return ["反转：无效行"]
		for x0 in n:
			var c0 := b.board.get_cell(x0, y)
			if c0 != null and c0.pinned:
				return ["反转：该行有固定字，不可移动"]
		for x in n / 2:
			var a := Vector2i(x, y)
			var c := Vector2i(n - 1 - x, y)
			var ta = b.board.get_xy(a)
			var tc = b.board.get_xy(c)
			b.board.set_xy(a, tc)
			b.board.set_xy(c, ta)
		return ["反转：倒转第 %d 行（含空格与叠层）" % (y + 1)]
	if t.has("col"):
		var x2: int = int(t["col"])
		if x2 < 0 or x2 >= n:
			return ["反转：无效列"]
		for y0 in n:
			var c3 := b.board.get_cell(x2, y0)
			if c3 != null and c3.pinned:
				return ["反转：该列有固定字，不可移动"]
		for y2 in n / 2:
			var a2 := Vector2i(x2, y2)
			var c2 := Vector2i(x2, n - 1 - y2)
			var ta2 = b.board.get_xy(a2)
			var tc2 = b.board.get_xy(c2)
			b.board.set_xy(a2, tc2)
			b.board.set_xy(c2, ta2)
		return ["反转：倒转第 %d 列（含空格与叠层）" % (x2 + 1)]
	return ["反转：请选择一行或一列"]

static func _merge_flow(b: BattleState, ctx: Dictionary) -> Array:
	var t: Dictionary = ctx.get("target", {})
	var c1: Vector2i = t.get("cell1", Vector2i(-1, -1))
	var c2: Vector2i = t.get("cell2", Vector2i(-1, -1))
	var bag_uid: int = int(t.get("merge_bag_uid", -1))
	var disc_uid: int = int(t.get("merge_discard_uid", -1))
	if c1 == c2 or not b.board.is_adjacent(c1, c2) or b.board.get_xy(c1) != null or b.board.get_xy(c2) != null:
		b.return_pending_reveal()
		return ["合流：需要两个相邻空格，未移动"]
	var bag_card: CharInstance = b.take_revealed(bag_uid)
	var disc_card: CharInstance = b.take_from_discard_by_uid(disc_uid)
	if bag_card == null or disc_card == null:
		if bag_card != null:
			b.pending_reveal.append(bag_card)
		if disc_card != null:
			b.discard.append(disc_card)
		b.return_pending_reveal()
		return ["合流：选择无效"]
	b.return_pending_reveal()
	b.board.set_xy(c1, bag_card)
	b.board.set_xy(c2, disc_card)
	return ["合流：将【%s】【%s】放入相邻空格" % [bag_card.glyph(), disc_card.glyph()]]

static func _hard_stop(b: BattleState) -> Array:
	b.clear_heat()
	var removed := b.remove_scorch_in_circulation()
	b.end_turn_requested = true
	return ["急停：清空热度，移除 %d 枚未打出的灼热【热】；立即结束出字阶段" % removed]

static func _repeat_word(b: BattleState) -> Array:
	b.enable_ability("repeat", 1)
	return ["重复：开启，每回合第一次多字词将再执行一次"]

static func _suspend(b: BattleState) -> Array:
	var h: int = b.player.heat
	b.clear_heat()
	b.player.add_persistent_block(h * 2)
	b.end_turn_requested = true
	return ["停息：清零 %d 热度，获得 %d 持久盾；立即结束出字阶段" % [h, h * 2]]

static func _split_grow(b: BattleState, ctx: Dictionary) -> Array:
	var tile: Vector2i = EffectUtil.tile(ctx)
	var center: CharInstance = b.board.get_xy(tile)
	if center == null:
		return ["分化：请选择一个盘面字"]
	var old_glyph: String = center.glyph()
	b.temp_chars.erase(center)
	b.board.clear_xy(tile)   # 删除该字（不入弃字堆）
	var spawned := b.spawn_word_neighbors(tile, 4)
	var glyphs: Array = []
	for s in spawned:
		glyphs.append(s.glyph())
	if spawned.is_empty():
		return ["分化：删除【%s】，但周围没有空格" % old_glyph]
	return ["分化：删除【%s】，周围生长 %d 枚临时字：%s" % [old_glyph, spawned.size(), "、".join(glyphs)]]

static func _transform_board(b: BattleState, ctx: Dictionary) -> Array:
	var tile: Vector2i = EffectUtil.tile(ctx)
	if b.board.get_xy(tile) == null:
		b.return_pending_reveal()
		return ["转化：请选择一个盘面字"]
	var uid: int = int(ctx.get("target", {}).get("transform_uid", -1))
	var chosen: CharInstance = b.take_revealed(uid)
	if chosen == null:
		b.return_pending_reveal()
		return ["转化：未选择要变成的字"]
	b.return_pending_reveal()
	var old: CharInstance = b.board.get_xy(tile)
	if old != null:
		if old.is_player_owned():
			b.discard.append(old)
		else:
			b.temp_chars.erase(old)
	var old_glyph: String = old.glyph() if old != null else "空"
	chosen.owner = CharInstance.Owner.PLAYER
	b.board.set_xy(tile, chosen)
	return ["转化：将【%s】定向改为【%s】" % [old_glyph, chosen.glyph()]]

static func _replace_self(b: BattleState, ctx: Dictionary) -> Array:
	# 【回】固定用在它自己被打出的那一格（原位），不需要选目标
	var tile: Vector2i = EffectUtil.tile(ctx)
	var path: Array = ctx.get("path", [])
	if not path.is_empty():
		tile = path[0]
	if b.board.get_xy(tile) != null:
		return ["回：目标格已被占用"]
	if b.bag.is_empty():
		if b.discard.is_empty():
			return ["回：字袋为空，无法换字"]
		b.bag = b.discard.duplicate()
		b.discard.clear()
		b._shuffle(b.bag)
	var inst: CharInstance = b.bag.pop_back()
	b.board.set_xy(tile, inst)
	return ["回：原位换成【%s】" % inst.glyph()]

static func _reveal_place(b: BattleState, ctx: Dictionary, cost: int) -> Array:
	var tile: Vector2i = EffectUtil.tile(ctx)
	if b.board.get_xy(tile) != null:
		return ["投放：目标格已被占用"]
	if b.bag.is_empty() and b.discard.is_empty():
		return ["投放：字袋为空"]
	if not EffectUtil.pay(b, cost):
		return ["投放：支付额不足（需 %d）" % cost]
	if b.bag.is_empty():
		b.bag = b.discard.duplicate()
		b.discard.clear()
		b._shuffle(b.bag)
	var inst: CharInstance = b.bag.pop_back()
	b.board.set_xy(tile, inst)
	return ["投放：支付 %d 金币，落下【%s】" % [cost, inst.glyph()]]
