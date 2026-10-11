extends RefCounted
class_name BattleOps
## 战斗中的【牌堆】与【盘面】操作（从 BattleState 抽出，降低单文件体积）。
## 均为 static；第一个参数是 BattleState。BattleState 保留同名薄封装以稳定外部 API。

static func draw_to_board(b: BattleState, count: int) -> int:
	if count <= 0:
		return 0
	var drawn := 0
	for i in count:
		if b.board.free_count() <= 0:
			break
		if _draw_one(b):
			drawn += 1
	b.drawn_this_turn += drawn
	return drawn

static func _draw_one(b: BattleState) -> bool:
	if b.bag.is_empty():
		if b.discard.is_empty():
			return false
		b.bag = b.discard.duplicate()
		b.discard.clear()
		b._shuffle(b.bag)
	if b.bag.is_empty():
		return false
	var empties := b.board.empty_indices()
	if empties.is_empty():
		return false
	var pos: Vector2i = empties[b.rng.randi_range(0, empties.size() - 1)]
	b.board.set_xy(pos, b.bag.pop_back())
	return true


## 在指定空格补一枚字（用于“回”“反复”等原位补字）

static func draw_one_to(b: BattleState, pos: Vector2i) -> CharInstance:
	if b.board.get_xy(pos) != null:
		return null
	if b.bag.is_empty():
		if b.discard.is_empty():
			return null
		b.bag = b.discard.duplicate()
		b.discard.clear()
		b._shuffle(b.bag)
	if b.bag.is_empty():
		return null
	var inst: CharInstance = b.bag.pop_back()
	b.board.set_xy(pos, inst)
	return inst


# ---------------------------------------------------------------- 揭示/选择（转化）

static func ensure_bag(b: BattleState) -> void:
	if b.bag.is_empty() and not b.discard.is_empty():
		b.bag = b.discard.duplicate()
		b.discard.clear()
		b._shuffle(b.bag)


## 从字袋随机取出至多 count 枚（不放回），存入 pending_reveal 供选择。

static func reveal_from_bag(b: BattleState, count: int) -> Array:
	ensure_bag(b)
	b.pending_reveal.clear()
	var n: int = min(count, b.bag.size())
	for i in n:
		b.pending_reveal.append(b.bag.pop_back())
	return b.pending_reveal.duplicate()


## 把未被选中的揭示字全部放回字袋。

static func return_pending_reveal(b: BattleState) -> void:
	for inst in b.pending_reveal:
		b.bag.append(inst)
	b.pending_reveal.clear()
	b._shuffle(b.bag)


## 从揭示结果中取出被选的一枚（其余留在 pending_reveal，由 return_pending_reveal 处理）。

static func take_revealed(b: BattleState, uid: int) -> CharInstance:
	for i in b.pending_reveal.size():
		var inst: CharInstance = b.pending_reveal[i]
		if inst.uid == uid:
			b.pending_reveal.remove_at(i)
			return inst
	return null


## 敌人注入：owner=ENEMY，带污染，可被玩家组词但打出要付代价；消耗后消失。

static func inject_enemy_glyphs(b: BattleState, count: int, pollution_id: String) -> int:
	var pool := ["蚀", "障", "灰", "碍", "秽"]
	var added := 0
	for i in count:
		if b.board.free_count() <= 0:
			break
		var glyph: String = pool[b.rng.randi_range(0, pool.size() - 1)]
		var cd: CharacterData = Database.get_character_by_glyph(glyph)
		if cd == null:
			continue
		var ci := CharInstance.new(cd)
		ci.owner = CharInstance.Owner.ENEMY
		if not pollution_id.is_empty():
			ci.add_pollution(pollution_id)
		var empties := b.board.empty_indices()
		var pos: Vector2i = empties[b.rng.randi_range(0, empties.size() - 1)]
		b.board.set_xy(pos, ci)
		b.temp_chars.append(ci)
		added += 1
	return added


## 自我过热：每点溢出向本场抽字袋塞 1 枚带灼热的【热】。

static func spawn_scorch_into_bag(b: BattleState, count: int) -> int:
	var cd: CharacterData = Database.get_character_by_glyph("热")
	if cd == null:
		return 0
	for i in count:
		var ci := CharInstance.new(cd)
		ci.owner = CharInstance.Owner.SELF_GENERATED
		ci.add_pollution("scorch")
		b.bag.insert(b.rng.randi_range(0, b.bag.size()), ci)
		b.temp_chars.append(ci)
	return count


# ---------------------------------------------------------------- 分化（临时生长）


## 删除 center，并在其上下左右的空格生长能组词的临时字。返回生长的实例。

static func discard_instances(b: BattleState) -> Array:
	var out: Array = []
	for inst in b.discard:
		out.append({"glyph": inst.glyph(), "uid": inst.uid})
	return out

static func take_from_discard_by_uid(b: BattleState, uid: int) -> CharInstance:
	for i in b.discard.size():
		var inst: CharInstance = b.discard[i]
		if inst.uid == uid:
			b.discard.remove_at(i)
			return inst
	return null

static func get_discard_by_uid(b: BattleState, uid: int) -> CharInstance:
	for inst in b.discard:
		if inst.uid == uid:
			return inst
	return null


## 急停：移除本回合溢热生成、仍在字袋/弃字堆/盘面的灼热【热】

static func battle_card_counts(b: BattleState) -> Dictionary:
	var counts: Dictionary = {}
	for arr in [b.bag, b.discard]:
		for inst in arr:
			var g: String = inst.glyph()
			counts[g] = int(counts.get(g, 0)) + 1
	return counts

static func apply_gravity(b: BattleState) -> void:
	for x in b.board.size:
		var column: Array = []
		for y in b.board.size:
			var c := b.board.get_cell(x, y)
			if c != null:
				column.append(c)
		var y2 := b.board.size - 1
		for i in range(column.size() - 1, -1, -1):
			b.board.set_cell(x, y2, column[i])
			y2 -= 1
		while y2 >= 0:
			b.board.set_cell(x, y2, null)
			y2 -= 1

static func apply_gravity_count(b: BattleState) -> int:
	# 记录移动前的列高度，计算真实移动的实体数
	var before: Dictionary = {}
	for x in b.board.size:
		for y in b.board.size:
			var c := b.board.get_cell(x, y)
			if c != null:
				before[c.uid] = Vector2i(x, y)
	apply_gravity(b)
	var moved := 0
	for x in b.board.size:
		for y in b.board.size:
			var c := b.board.get_cell(x, y)
			if c != null and before.has(c.uid):
				if before[c.uid] != Vector2i(x, y):
					moved += 1
	return moved

static func rotate_2x2(b: BattleState, top_left: Vector2i) -> void:
	var ta := b.board.get_xy(top_left)
	var tb := b.board.get_xy(top_left + Vector2i(1, 0))
	var tc := b.board.get_xy(top_left + Vector2i(1, 1))
	var td := b.board.get_xy(top_left + Vector2i(0, 1))
	b.board.set_xy(top_left, td)
	b.board.set_xy(top_left + Vector2i(1, 0), ta)
	b.board.set_xy(top_left + Vector2i(1, 1), tb)
	b.board.set_xy(top_left + Vector2i(0, 1), tc)

## 整行循环位移：dir = -1 向左 / +1 向右（每格移动 1 步，出界回绕）。
static func shift_row(b: BattleState, row: int, dir: int) -> void:
	var n: int = b.board.size
	if row < 0 or row >= n or dir == 0:
		return
	var line: Array = []
	for x in n:
		line.append(b.board.get_xy(Vector2i(x, row)))
	for x in n:
		b.board.set_xy(Vector2i(x, row), line[(x - dir + n) % n])


## 3×3 区域旋转：dir = -1 逆时针（左转）/ +1 顺时针（右转）。
static func rotate_3x3(b: BattleState, anchor: Vector2i, dir: int) -> void:
	var region: Array = []
	for dy in 3:
		for dx in 3:
			region.append(b.board.get_xy(anchor + Vector2i(dx, dy)))
	for dy in 3:
		for dx in 3:
			var sx: int
			var sy: int
			if dir > 0:
				sx = dy
				sy = 2 - dx
			else:
				sx = 2 - dy
				sy = dx
			b.board.set_xy(anchor + Vector2i(dx, dy), region[sy * 3 + sx])


## 交换两格的内容（同行换位）。
static func swap_cells(b: BattleState, a: Vector2i, c: Vector2i) -> void:
	var ta: CharInstance = b.board.get_xy(a)
	var tc: CharInstance = b.board.get_xy(c)
	b.board.set_xy(a, tc)
	b.board.set_xy(c, ta)


static func destroy_2x2(b: BattleState, top_left: Vector2i) -> int:
	var destroyed := 0
	for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var pos: Vector2i = top_left + off
		var inst: CharInstance = b.board.get_xy(pos)
		if inst == null:
			continue
		destroyed += 1
		if inst.is_player_owned() and not inst.temporary:
			if b.has_ability("blastproof"):
				b.bag.append(inst)
				b.player.add_persistent_block(1)
				b._log("防爆：救回【%s】回字袋，持久盾 +1" % inst.glyph())
			else:
				b.discard.append(inst)
		else:
			b.temp_chars.erase(inst)
		b.board.clear_xy(pos)
	return destroyed


## 化合：把两张相邻的己方牌融合成一个占 1 格的复合单位（本场有效）。
## 返回 {ok, msg}。
## 精炼：两个相同己方字“一直重合”——第一张多一层可重复使用，第二张回字袋。

static func cleanse_board(b: BattleState) -> int:
	var n := 0
	for c in b.board.cells:
		if c != null and not c.pollutions.is_empty():
			c.clear_pollutions()
			n += 1
	return n

static func cleanse_scorch(b: BattleState) -> int:
	var n := 0
	for c in b.board.cells:
		if c != null and c.has_pollution("scorch"):
			c.remove_pollution("scorch")
			n += 1
	return n

static func spawn_word_neighbors(b: BattleState, center: Vector2i, max_count: int = 4) -> Array:
	var out: Array = []
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if out.size() >= max_count:
			break
		var cell: Vector2i = center + dir
		if not b.board.in_bounds(cell.x, cell.y):
			continue
		if b.board.get_xy(cell) != null:
			continue
		var glyph := _pick_word_glyph_for(b, cell, center)
		if glyph.is_empty():
			continue
		var cd: CharacterData = Database.get_character_by_glyph(glyph)
		if cd == null:
			continue
		var inst := CharInstance.new(cd)
		inst.owner = CharInstance.Owner.PLAYER
		inst.temporary = true
		b.board.set_xy(cell, inst)
		b.temp_chars.append(inst)
		out.append(inst)
	return out


## 生成一枚临时字实例（未上盘）。

static func create_temp_glyph(b: BattleState, glyph: String) -> CharInstance:
	var cd: CharacterData = Database.get_character_by_glyph(glyph)
	if cd == null:
		return null
	var inst := CharInstance.new(cd)
	inst.owner = CharInstance.Owner.PLAYER
	inst.temporary = true
	b.temp_chars.append(inst)
	return inst


## 为格 cell 选一个能与它周围（除 center）已有字组成合法词的字。

static func _pick_word_glyph_for(b: BattleState, cell: Vector2i, center: Vector2i) -> String:
	var neighbor_glyphs: Array = []
	for off in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n: Vector2i = cell + off
		if n == center or not b.board.in_bounds(n.x, n.y):
			continue
		var c: CharInstance = b.board.get_xy(n)
		if c != null:
			neighbor_glyphs.append(c.glyph())
	if not neighbor_glyphs.is_empty():
		var candidates: Array = []
		for w in Database.words.values():
			if not w.implemented or w.length() != 2:
				continue
			var ga: String = w.glyphs[0]
			var gb: String = w.glyphs[1]
			if neighbor_glyphs.has(ga):
				candidates.append(gb)
			if neighbor_glyphs.has(gb):
				candidates.append(ga)
		if not candidates.is_empty():
			return candidates[b.rng.randi_range(0, candidates.size() - 1)]
	return _spawn_pool_pick(b)


## 炼化：把一枚指定字的牌从本场循环移出（字袋/弃字堆/盘面）。战后自然回归。

static func _spawn_pool_pick(b: BattleState) -> String:
	if b._spawn_pool.is_empty():
		for w in Database.words.values():
			if not w.implemented:
				continue
			for g in w.glyphs:
				if not b._spawn_pool.has(g):
					b._spawn_pool.append(g)
	if b._spawn_pool.is_empty():
		return ""
	return b._spawn_pool[b.rng.randi_range(0, b._spawn_pool.size() - 1)]

static func fuse_cards(b: BattleState, p1: Vector2i, p2: Vector2i) -> Dictionary:
	var c1: CharInstance = b.board.get_xy(p1)
	var c2: CharInstance = b.board.get_xy(p2)
	if c1 == null or c2 == null:
		return {"ok": false, "msg": "化合：需要两张盘面上的牌"}
	if not c1.is_player_owned() or not c2.is_player_owned():
		return {"ok": false, "msg": "化合：只能融合己方牌"}
	if not b.board.is_adjacent(p1, p2):
		return {"ok": false, "msg": "化合：两张牌必须相邻"}
	var seq: Array[String] = []
	for g in c1.glyph_list():
		seq.append(str(g))
	for g in c2.glyph_list():
		seq.append(str(g))
	var fused := CharInstance.new(c1.data)
	fused.owner = CharInstance.Owner.PLAYER
	fused.fusion.assign(seq.slice(1))
	fused.pollutions = c1.pollutions.duplicate()
	for p in c2.pollutions:
		fused.add_pollution(p)
	fused.temporary = c1.temporary or c2.temporary
	b.temp_chars.erase(c1)
	b.temp_chars.erase(c2)
	if fused.temporary:
		b.temp_chars.append(fused)
	b.board.set_xy(p1, fused)
	b.board.clear_xy(p2)
	return {"ok": true, "msg": "化合：将【%s】融为一体（占 1 格，本场不可拆）" % "".join(seq), "fused": fused}

static func refine_pair(b: BattleState, p1: Vector2i, p2: Vector2i) -> Dictionary:
	var c1: CharInstance = b.board.get_xy(p1)
	var c2: CharInstance = b.board.get_xy(p2)
	if c1 == null or c2 == null or p1 == p2:
		return {"ok": false, "msg": "精炼：需要两个盘面上的不同格子"}
	if not c1.is_player_owned() or not c2.is_player_owned():
		return {"ok": false, "msg": "精炼：只能作用于己方字"}
	if c1.glyph() != c2.glyph():
		return {"ok": false, "msg": "精炼：两个字必须相同"}
	c1.temporary_uses += 1
	if c2.temporary_uses < 0:
		c2.temporary_uses = 0
	b.board.clear_xy(p2)
	b.bag.append(c2)
	b._shuffle(b.bag)
	return {"ok": true, "msg": "精炼：【%s】两张重合，本场可重复使用 %d 次" % [c1.glyph(), c1.temporary_uses + 1]}


## 精铸：弃字堆中的可选项

static func remove_scorch_in_circulation(b: BattleState) -> int:
	var removed := 0
	var new_bag: Array = []
	for c in b.bag:
		if c.owner == CharInstance.Owner.SELF_GENERATED and c.glyph() == "热":
			b.temp_chars.erase(c)
			removed += 1
		else:
			new_bag.append(c)
	b.bag = new_bag
	var new_disc: Array = []
	for c in b.discard:
		if c.owner == CharInstance.Owner.SELF_GENERATED and c.glyph() == "热":
			b.temp_chars.erase(c)
			removed += 1
		else:
			new_disc.append(c)
	b.discard = new_disc
	for i in b.board.cells.size():
		var c2: CharInstance = b.board.cells[i]
		if c2 != null and c2.owner == CharInstance.Owner.SELF_GENERATED and c2.glyph() == "热":
			b.board.cells[i] = null
			b.temp_chars.erase(c2)
			removed += 1
	return removed


## 是否存在两个相邻的空格（合流用）

static func has_adjacent_empty_pair(b: BattleState) -> bool:
	for i in b.board.cells.size():
		if b.board.cells[i] != null:
			continue
		var v: Vector2i = b.board.to_xy(i)
		for n in b.board.neighbors(v):
			if b.board.get_xy(n) == null:
				return true
	return false

static func _has_any_word_on_board(b: BattleState) -> bool:
	for c in b.board.cells:
		if c == null:
			continue
		for n in b.board.neighbors(b.board.to_xy(b.board.cells.find(c))):
			var o := b.board.get_xy(n)
			if o != null and Database.get_word_by_glyphs([c.glyph(), o.glyph()]) != null:
				return true
	return false
