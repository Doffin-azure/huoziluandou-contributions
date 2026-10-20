extends RefCounted
class_name EffectTargets
## 界面、战斗确认与无头驱动共用的目标规则；候选查询始终只读。

const NEEDS := {
	"choose_bag_deploy": "deploy", "choose_buyback": "buyback", "choose_junk_tiles": "junk",
	"choose_same_pair": "same_pair", "reveal_pick_board": "tile", "choose_glyph_empower": "glyph",
	"choose_glyph_gild": "gild", "choose_battle_card_remove": "battle_card", "choose_fuse_pair": "pair",
	"choose_any_pair": "pair", "choose_row_pair": "row_pair", "choose_place_two": "place_two",
	"choose_recover_two": "recover_two", "choose_recover_to_bag": "recover_to_bag", "choose_move": "move",
	"choose_discard_place": "discard", "choose_line": "line", "choose_merge_flow": "merge",
	"choose_three_tiles": "three", "choose_own_tiles": "own",
}
const REVEALS := {"reveal_pick_board": 5, "choose_place_two": 2, "choose_merge_flow": 1}


static func interaction_of(word: WordData) -> String:
	if word == null:
		return ""
	if not word.interaction.is_empty():
		return word.interaction
	for effect in word.effects:
		var interaction := str(EffectRegistry.metadata(effect.handler).get("interaction", ""))
		if not interaction.is_empty():
			return interaction
	return ""


static func required_for_word(word: WordData) -> int:
	if word.requires_target != EffectData.Target.NONE:
		return word.requires_target
	for effect in word.effects:
		var kind := int(EffectRegistry.metadata(effect.handler).get("required_target", EffectData.Target.NONE))
		if kind != EffectData.Target.NONE:
			return kind
	return EffectData.Target.NONE


static func to_xy(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() == 2 and _integer_component(value[0]) and _integer_component(value[1]):
		return Vector2i(int(value[0]), int(value[1]))
	var parts := str(value).replace("(", "").replace(")", "").replace(",", " ").split(" ", false)
	if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i(-1, -1)


static func _integer_component(value: Variant) -> bool:
	if value is int:
		return value >= -2147483648 and value <= 2147483647
	if value is float:
		return is_finite(value) and value == floorf(value) and value >= -2147483648.0 and value <= 2147483647.0
	return str(value).is_valid_int()


static func normalize_path(raw: Variant) -> Array:
	var path: Array = []
	if raw is Array:
		for p in raw:
			path.append(to_xy(p))
	return path


static func normalize_target(raw: Dictionary) -> Dictionary:
	var target := raw.duplicate(true)
	for key in ["tile", "tile2", "enemy_glyph", "cell1", "cell2"]:
		if target.has(key):
			target[key] = to_xy(target[key])
	if target.has("cells"):
		target.cells = normalize_path(target.cells)
	if target.has("places"):
		var places: Array = []
		if target.places is Array:
			for place in target.places:
				if place is Array and place.size() == 2:
					places.append([int(place[0]), to_xy(place[1])])
				else:
					places.append([-1, Vector2i(-1, -1)])
		target.places = places
	return target


static func request(b: BattleState, path: Array) -> Dictionary:
	var glyphs := b.board.glyphs_of(path) if b.board.valid_path(path) else []
	var word := EffectDescriptions.word_for(glyphs) if glyphs.size() >= 2 else null
	var source := b.board.get_xy(path[0]) if path.size() == 1 else null
	var interaction := interaction_of(word)
	var required := required_for_word(word) if word != null else (solo_requires_target(b, source.data, path) if source != null else EffectData.Target.NONE)
	var needs := needs_of(word) if word != null else "none"
	if source != null and not source.word_only:
		if required == EffectData.Target.BAG_GLYPH:
			needs = "bag"
		elif required == EffectData.Target.BOARD_TILE:
			needs = "throw" if source.data.solo_handler == "throw_neighbor" else "tile"
		elif required == EffectData.Target.EMPTY_TILE:
			needs = "empty"
	return {"word": word, "glyphs": glyphs, "interaction": interaction, "needs": needs,
		"required_target": required, "reveal_count": int(REVEALS.get(interaction, 0))}


static func transfer_candidates(b: BattleState, path: Array) -> Array:
	var spec := request(b, path)
	if spec.needs == "deploy":
		return deploy_candidates(b)
	if spec.needs == "buyback":
		return b.discard.filter(func(c): return c.is_player_owned() and not c.temporary)
	return []


static func transfer_spaces(b: BattleState, path: Array) -> Array:
	var spaces := b.board.empty_indices()
	for pos in path:
		var inst := b.board.get_xy(pos)
		if inst != null and not inst.pinned and inst.temporary_uses == 0 and not spaces.has(pos):
			spaces.append(pos)
	return spaces


static func recast_candidates(b: BattleState, path: Array) -> Array:
	var cells: Array = []
	var seen := {}
	for i in b.board.cells.size():
		var inst: CharInstance = b.board.cells[i]
		var pos := b.board.to_xy(i)
		if inst != null and not inst.pinned and not path.has(pos) and not seen.has(inst.uid):
			seen[inst.uid] = true
			cells.append(pos)
	return cells


static func options(b: BattleState, path: Array) -> Dictionary:
	var spec := request(b, path)
	var effects: Array = spec.word.effects if spec.word != null else []
	if spec.word == null and path.size() == 1:
		var source := b.board.get_xy(path[0])
		if source != null and source.data != null and not source.word_only:
			effects = source.data.solo_effects
			if source.data.solo_handler in EffectRegistry.SOLO_NEIGHBOR:
				spec.cells = b.solo_target_cells(source, path[0])
			if source.data.solo_handler in EffectRegistry.SOLO_BAG:
				spec.cards = b.solo_bag_candidates(source)
	if spec.needs in ["deploy", "buyback"]:
		spec.cards = transfer_candidates(b, path)
		spec.cells = transfer_spaces(b, path)
	elif spec.needs == "three":
		spec.cells = recast_candidates(b, path)
	for effect in effects:
		var candidates := EffectRegistry.targets(effect, b, path)
		for field in ["cells", "cards", "default"]:
			if candidates.has(field):
				spec[field] = candidates[field]
	return spec


static func prepare(b: BattleState, path: Array) -> Dictionary:
	var reason := preparation_error(b, path)
	if not reason.is_empty():
		return {"ok": false, "reason": reason}
	if not b.pending_reveal.is_empty():
		return {"ok": true, "cards": b.pending_reveal.duplicate(), "interaction": request(b, path).interaction}
	var spec := request(b, path)
	var count: int = spec.reveal_count
	if spec.needs == "place_two":
		count = mini(count, b.board.free_count())
	var cards := b.reveal_from_bag(count)
	b.pending_choice = {"path": path.duplicate(), "uids": path.map(func(p): return b.board.get_xy(p).uid), "interaction": spec.interaction}
	return {"ok": true, "cards": cards, "interaction": spec.interaction}


static func preparation_error(b: BattleState, path: Array) -> String:
	if not b.can_play() or not b.board.valid_path(path):
		return "无法为当前路径开始选字"
	if b.formation_mode and path.any(func(p): return b.reserved_cells.has(p)):
		return "该字已用于本次结阵"
	var spec := request(b, path)
	var count: int = spec.reveal_count
	if count <= 0:
		return "该效果不需要预先揭示字"
	if not b.pending_reveal.is_empty():
		return "" if b.pending_choice.is_empty() or b.pending_choice.path == path else "请先完成或取消上一次选字"
	if spec.needs == "place_two":
		count = mini(count, b.board.free_count())
		if count <= 0:
			return "火急需要盘面空格"
	if spec.needs == "merge" and (not b.has_adjacent_empty_pair() or b.bag.is_empty() or b.discard_instances().is_empty()):
		return "合流需要两个相邻空格、字袋字和弃字"
	if b.bag.is_empty() and b.discard.is_empty():
		return "字袋与弃字堆没有可揭示的字"
	if spec.interaction == "reveal_pick_board" and not b.board.cells.any(func(c): return c != null and not c.pinned and not path.has(b.board.to_xy(b.board.cells.find(c)))):
		return "转化需要施词以外的非固定目标字"
	return ""


static func _empty(b: BattleState, p: Vector2i) -> bool:
	return b.board.in_bounds(p.x, p.y) and b.board.get_xy(p) == null

static func deploy_candidates(b: BattleState) -> Array:
	var out: Array = []
	for i in range(b.bag.size() - 1, -1, -1):
		var inst: CharInstance = b.bag[i]
		if inst.is_player_owned() and not inst.temporary:
			out.append(inst)
			if out.size() >= BattleBalance.i("deploy_choices", 3):
				break
	return out


static func discard_candidate(b: BattleState, target: Dictionary) -> CharInstance:
	var uid := int(target.get("place_uid", target.get("discard_uid", -1)))
	for inst in b.discard:
		if inst.uid == uid and inst.is_player_owned() and not inst.temporary:
			return inst
	return null


static func validate_builtin(b: BattleState, handler: String, path: Array, target: Dictionary) -> String:
	if handler == "gild_glyph":
		var candidate := EffectHandlersActions.gild_candidate(target)
		if candidate == null:
			return "镀金：请选择字袋中一枚未镀金的实体字"
		var word: WordData = Database.get_word_by_glyphs_string("".join(b.board.glyphs_of(path)))
		var cost := int(word.effects[0].args.get("cost", 0)) if word != null else 0
		if EffectUtil.available(b) < EffectUtil.discounted_cost(b, cost):
			return "镀金：铜钱不足（需%d）" % cost
	if handler == "anchor_self":
		var anchor_tile: Vector2i = target.get("tile", Vector2i(-1, -1))
		if not _empty(b, anchor_tile): return "础：请选择棋盘内的空格"
		return ""
	if handler in ["reveal_place", "buyback"]:
		var candidates := deploy_candidates(b) if handler == "reveal_place" else b.discard.filter(func(c): return c.is_player_owned() and not c.temporary)
		if candidates.is_empty():
			return ""
		var name := "投放" if handler == "reveal_place" else "回购"
		var chosen: CharInstance = null
		if handler == "buyback":
			chosen = discard_candidate(b, target)
		else:
			for inst in candidates:
				if inst.uid == int(target.get("bag_uid", -1)):
					chosen = inst
		if chosen == null:
			return "%s：请选择有效的原实体" % name
		var pos: Vector2i = target.get("tile", Vector2i(-1, -1))
		if not b.board.in_bounds(pos.x, pos.y):
			return "%s：请选择棋盘内的落点" % name
		var occupied := b.board.get_xy(pos)
		if occupied != null and (not path.has(pos) or occupied.pinned or occupied.temporary_uses > 0):
			return "%s：落点没有可用空格" % name
		if EffectUtil.available(b) < EffectUtil.discounted_cost(b, BattleBalance.i("buy_cost", 2)):
			return "%s：支付额不足（需 2）" % name
	elif handler == "divert":
		var cells: Array = target.get("cells", [])
		if cells.size() > BattleBalance.i("divert_limit", 2):
			return "分流：至多选择两枚杂字"
		var seen := {}
		for pos in cells:
			var inst := b.board.get_xy(pos)
			if path.has(pos) or not BattleState.is_refinable_junk(inst) or seen.has(inst.uid):
				return "分流：请选择施词以外的不同杂字"
			seen[inst.uid] = true
	elif handler == "refine_layer":
		var a: Vector2i = target.get("tile", Vector2i(-1, -1))
		var c: Vector2i = target.get("tile2", Vector2i(-1, -1))
		var first := b.board.get_xy(a)
		var second := b.board.get_xy(c)
		if a == c or path.has(a) or path.has(c) or first == null or second == null:
			return "精炼：请选择施词以外的两个不同实体"
		if not first.is_player_owned() or not second.is_player_owned() or first.temporary or second.temporary or first.pinned or second.pinned or first.glyph_list() != second.glyph_list():
			return "精炼：需要两枚字形相同、非固定的己方原实体"
	elif handler == "place_two":
		if b.pending_reveal.is_empty():
			return "火急：请先揭示待放入的字"
		var first: Vector2i = target.get("cell1", Vector2i(-1, -1))
		var second: Vector2i = target.get("cell2", Vector2i(-1, -1))
		if not _empty(b, first) or (b.pending_reveal.size() > 1 and (first == second or not _empty(b, second))):
			return "火急：请选择不同的有效空格"
	elif handler == "transform_board":
		var cell: Vector2i = target.get("tile", Vector2i(-1, -1))
		var current := b.board.get_xy(cell)
		if current == null or current.pinned or path.has(cell):
			return "转化：请选择施词以外的非固定盘面字"
		if not b.pending_reveal.any(func(c): return c.uid == int(target.get("transform_uid", -1))):
			return "转化：请选择当前揭示的实体字"
	elif handler == "merge_flow":
		var first: Vector2i = target.get("cell1", Vector2i(-1, -1))
		var second: Vector2i = target.get("cell2", Vector2i(-1, -1))
		if first == second or not b.board.is_adjacent(first, second) or not _empty(b, first) or not _empty(b, second):
			return "合流：需要两个不同的相邻空格"
		if not b.pending_reveal.any(func(c): return c.uid == int(target.get("merge_bag_uid", -1))) or not b.discard_instances().any(func(c): return int(c.uid) == int(target.get("merge_discard_uid", -1))):
			return "合流：请选择有效的揭示字与弃字"
	elif handler == "recover_two":
		var places: Array = target.get("places", [])
		if places.is_empty() or places.size() > 2:
			return "收复：请选择一至两枚弃字与落点"
		var uids := {}
		var cells := {}
		for place in places:
			var uid := int(place[0])
			var cell: Vector2i = place[1]
			if uids.has(uid) or cells.has(cell) or not _empty(b, cell) or not b.discard_instances().any(func(c): return int(c.uid) == uid):
				return "收复：目标必须是不同的己方弃字与有效空格"
			uids[uid] = true
			cells[cell] = true
		if places.size() == 2 and not b.board.is_adjacent(places[0][1], places[1][1]):
			return "收复：两个落点必须相邻"
	return ""


static func solo_target_cells(b: BattleState, inst: CharInstance, origin: Vector2i) -> Array:
	var out: Array = []
	if inst == null or inst.data == null or inst.word_only:
		return out
	for pos in b.board.neighbors(origin):
		var candidate := b.board.get_xy(pos)
		if candidate == null:
			continue
		if inst.data.solo_handler in ["cleanse_adjacent", "wash_adjacent"] and not candidate.pollutions.is_empty():
			out.append(pos)
		elif inst.data.solo_handler == "move_neighbor" and not candidate.pinned and not inst.pinned and inst.temporary_uses == 0:
			out.append(pos)
		elif inst.data.solo_handler == "throw_neighbor" and not candidate.pinned:
			out.append(pos)
		elif inst.data.solo_handler == "split_neighbor" and candidate.is_player_owned() and not inst.pinned and inst.temporary_uses == 0:
			out.append(pos)
		elif inst.data.solo_handler == "recast_neighbor" and candidate.is_player_owned() and not candidate.temporary and not candidate.pinned:
			out.append(pos)
		elif inst.data.solo_handler == "refine_junk_neighbor" and BattleState.is_refinable_junk(candidate):
			out.append(pos)
	return out


static func solo_throw_destinations(b: BattleState, inst: CharInstance, origin: Vector2i) -> Array:
	var out := b.board.empty_indices()
	if inst != null and not inst.pinned and inst.temporary_uses == 0 and b.board.get_xy(origin) == inst:
		out.append(origin) # 发动时本字会腾空，允许投回这里。
	return out


static func validate_solo_throw(b: BattleState, inst: CharInstance, origin: Vector2i, target: Dictionary) -> String:
	if not target.has("tile") or not target.has("tile2"):
		return "投：请选择一枚四邻非固定字和一个空格"
	if not b.solo_target_cells(inst, origin).has(target.tile):
		return "投：目标必须是原格四邻的非固定字"
	var chosen := b.board.get_xy(target.tile)
	if target.has("throw_uid") and chosen.uid != int(target.throw_uid):
		return "投：所选实体已改变，请重新选择"
	if not b.solo_throw_destinations(inst, origin).has(target.tile2):
		return "投：落点必须为空格"
	if EffectUtil.available(b) < EffectUtil.discounted_cost(b, BattleBalance.i("throw_cost", 1)):
		return "投：支付额不足（需支付 1 铜钱）"
	return ""


static func solo_requires_target(b: BattleState, cd: CharacterData, path: Array = []) -> int:
	if not path.is_empty() and b.board.get_xy(path[0]) != null and b.board.get_xy(path[0]).word_only:
		return EffectData.Target.NONE
	if cd.solo_handler in EffectRegistry.SOLO_BAG:
		return EffectData.Target.NONE if not path.is_empty() and b.solo_bag_candidates(b.board.get_xy(path[0])).is_empty() else EffectData.Target.BAG_GLYPH
	if cd.solo_handler in EffectRegistry.SOLO_NEIGHBOR:
		if not path.is_empty() and b.solo_target_cells(b.board.get_xy(path[0]), path[0]).is_empty():
			return EffectData.Target.NONE
		return EffectData.Target.BOARD_TILE
	for e in cd.solo_effects:
		var registered := int(EffectRegistry.metadata(e.handler).get("required_target", EffectData.Target.NONE))
		if registered != EffectData.Target.NONE:
			return registered
		if e.target in [EffectData.Target.BOARD_TILE, EffectData.Target.BOARD_2X2, EffectData.Target.BOARD_3X3, EffectData.Target.BOARD_ROW, EffectData.Target.EMPTY_TILE, EffectData.Target.ENEMY_GLYPH, EffectData.Target.DISCARD_GLYPH]:
			return e.target
	return EffectData.Target.NONE

## 只查看字袋，不提前取牌、洗牌、消费原字或扣费；同字形以实体身份区分。


static func solo_bag_candidates(b: BattleState, source: CharInstance, handler_override: String = "") -> Array:
	var out: Array = []
	if source == null or source.data == null or (source.word_only and handler_override.is_empty()) or source.pinned or source.temporary_uses > 0:
		return out
	var handler := handler_override if not handler_override.is_empty() else source.data.solo_handler
	var seen := {}
	for i in range(b.bag.size() - 1, -1, -1):
		var inst: CharInstance = b.bag[i]
		if inst == source or seen.has(inst.uid):
			continue
		if handler == "buy_bag_solo" and (not inst.is_player_owned() or inst.temporary or inst.pinned):
			continue
		seen[inst.uid] = true
		out.append(inst)
		if handler == "precision_draw" and out.size() >= BattleBalance.i("precision_choices", 2):
			break
	return out


static func validate_solo_bag(b: BattleState, source: CharInstance, origin: Vector2i, target: Dictionary) -> String:
	var candidates := b.solo_bag_candidates(source)
	if candidates.is_empty() and not target.has("bag_uid"):
		return ""
	if b.board.get_xy(origin) != source or (target.has("bag_source_uid") and source.uid != int(target.bag_source_uid)):
		return "选字：原字已改变，请重新选择"
	if not candidates.any(func(inst): return inst.uid == int(target.get("bag_uid", -1))):
		return "选字：所选实体不在当前候选字袋中"
	if source.data.solo_handler == "buy_bag_solo" and EffectUtil.available(b) < EffectUtil.discounted_cost(b, BattleBalance.i("buy_cost", 2)):
		return "购：支付额不足（需支付 2 铜钱）"
	return ""


static func default_target(b: BattleState, needs: String, path: Array = []) -> Dictionary:
	if needs == "gild":
		for card: CharInstance in GameState.deck:
			if card.is_player_owned() and not card.temporary and not card.gilded:
				return {"gild_uid": card.uid}
		return {}
	var spec := options(b, path)
	if spec.has("default"):
		return normalize_target(spec.default)
	if spec.has("cells") and needs == "tile" and not spec.cells.is_empty():
		return {"tile": spec.cells[0]}
	if spec.interaction == "reveal_pick_board":
		for i in b.board.cells.size():
			var cell := b.board.to_xy(i)
			var inst: CharInstance = b.board.cells[i]
			if inst != null and not inst.pinned and not path.has(cell) and not b.pending_reveal.is_empty():
				return {"tile": cell, "transform_uid": b.pending_reveal[0].uid}
		return {}
	if needs in ["deploy", "buyback"]:
		var cards := transfer_candidates(b, path)
		if cards.is_empty():
			return {"skip_transfer": true}
		var spaces := transfer_spaces(b, path)
		if spaces.is_empty():
			return {}
		return {"tile": spaces[0], "bag_uid": cards[0].uid} if needs == "deploy" else {"tile": spaces[0], "place_uid": cards[0].uid}
	if needs == "junk":
		var cells: Array = []
		for i in b.board.cells.size():
			var pos := b.board.to_xy(i)
			if not path.has(pos) and BattleState.is_refinable_junk(b.board.cells[i]) and cells.size() < BattleBalance.i("divert_limit", 2):
				cells.append(pos)
		return {"cells": cells}
	if needs == "same_pair":
		for i in b.board.cells.size():
			var first: CharInstance = b.board.cells[i]
			if first == null or path.has(b.board.to_xy(i)) or first.pinned or first.temporary or not first.is_player_owned():
				continue
			for j in range(i + 1, b.board.cells.size()):
				var second: CharInstance = b.board.cells[j]
				if second != null and not path.has(b.board.to_xy(j)) and second.is_player_owned() and not second.pinned and not second.temporary and second.glyph_list() == first.glyph_list():
					return {"tile": b.board.to_xy(i), "tile2": b.board.to_xy(j)}
		return {}
	if needs == "bag" and path.size() == 1:
		var source := b.board.get_xy(path[0])
		var candidates := b.solo_bag_candidates(source)
		return {"bag_uid": candidates[0].uid, "bag_source_uid": source.uid} if not candidates.is_empty() else {}
	if needs == "tile" and path.size() == 1:
		var source := b.board.get_xy(path[0])
		if source != null and source.glyph_list().size() == 1 and source.data.solo_handler in ["cleanse_adjacent", "wash_adjacent", "move_neighbor", "split_neighbor", "recast_neighbor", "refine_junk_neighbor"]:
			var candidates := b.solo_target_cells(source, path[0])
			return {"tile": candidates[0]} if not candidates.is_empty() else {}
	match needs:
		"throw":
			if path.size() == 1:
				var source := b.board.get_xy(path[0])
				var candidates := b.solo_target_cells(source, path[0])
				var destinations := b.solo_throw_destinations(source, path[0])
				if not candidates.is_empty() and not destinations.is_empty():
					return {"tile": candidates[0], "tile2": destinations[0], "throw_uid": b.board.get_xy(candidates[0]).uid}
		"three":
			var candidates := recast_candidates(b, path)
			return {"cells": candidates.slice(0, BattleBalance.i("recast_target_count", 3))} if candidates.size() >= BattleBalance.i("recast_target_count", 3) else {}
		"tile", "enemy":
			for i in b.board.cells.size():
				var inst: CharInstance = b.board.cells[i]
				if inst != null and (needs == "tile" or inst.is_enemy_owned()):
					var p: Vector2i = b.board.to_xy(i)
					return {"tile": p, "enemy_glyph": p}
		"empty":
			var empties: Array = b.board.empty_indices()
			if not empties.is_empty():
				return {"tile": empties[0]}
		"2x2", "3x3":
			return {"tile": Vector2i(0, 0)}
		"row", "line":
			return {"tile": Vector2i(0, 0), "row": 0}
		"row_pair":
			for y in b.board.size:
				var first: int = -1
				for x in b.board.size:
					if b.board.get_xy(Vector2i(x, y)) == null:
						first = -1
						continue
					if first < 0:
						first = x
					else:
						return {"tile": Vector2i(first, y), "tile2": Vector2i(x, y)}
		"place_two":
			var em: Array = b.board.empty_indices()
			if not em.is_empty():
				return {"cell1": em[0], "cell2": em[1]} if em.size() >= 2 and b.pending_reveal.size() >= 2 else {"cell1": em[0]}
		"recover_two":
			var dl: Array = b.discard_instances()
			var em2: Array = b.board.empty_indices()
			if not dl.is_empty() and not em2.is_empty():
				return {"places": [[int(dl[0]["uid"]), em2[0]]]}
		"recover_to_bag":
			var dl2: Array = b.discard_instances()
			if not dl2.is_empty():
				for i in b.board.cells.size():
					var c: CharInstance = b.board.cells[i]
					var pos := b.board.to_xy(i)
					if c != null and c.is_player_owned() and not c.temporary and not c.pinned and not path.has(pos):
						return {"tile": pos, "place_uid": int(dl2[0].uid)}
		"move":
			var em4: Array = b.board.empty_indices()
			if not em4.is_empty():
				for i in b.board.cells.size():
					var source: CharInstance = b.board.cells[i]
					var pos := b.board.to_xy(i)
					if source != null and not source.pinned and not path.has(pos):
						return {"tile": pos, "tile2": em4[0]}
		"discard":
			var list: Array = b.discard_instances()
			if not list.is_empty():
				var spaces := b.board.empty_indices()
				if not spaces.is_empty():
					return {"discard_index": 0, "place_uid": int(list[0]["uid"]), "tile": spaces[0]}
		"pair":
			for i in b.board.cells.size():
				var c1: CharInstance = b.board.cells[i]
				if c1 == null or not c1.is_player_owned():
					continue
				for n in b.board.neighbors(b.board.to_xy(i)):
					var c2: CharInstance = b.board.get_xy(n)
					if c2 != null and c2.is_player_owned():
						return {"tile": b.board.to_xy(i), "tile2": n}
		"glyph":
			var counts := GameState.glyph_counts()
			if not counts.is_empty():
				return {"empower_glyph": str(counts.keys()[0]), "gild_glyph": str(counts.keys()[0])}
		"battle_card":
			var bc: Dictionary = b.battle_card_counts()
			if not bc.is_empty():
				return {"remove_glyph": str(bc.keys()[0])}
		"merge":
			if not b.pending_reveal.is_empty() and not b.discard_instances().is_empty():
				for first in b.board.empty_indices():
					for second in b.board.neighbors(first):
						if _empty(b, second):
							return {"cell1": first, "cell2": second, "merge_bag_uid": b.pending_reveal[0].uid,
								"merge_discard_uid": int(b.discard_instances()[0].uid)}
		"own":
			return {"cells": []}
		"enemy_target":
			return {"target_index": 0} if not b.alive_enemies().is_empty() else {}
	return {}


static func needs_of(w: WordData) -> String:
	var interaction := interaction_of(w)
	if NEEDS.has(interaction):
		return NEEDS[interaction]
	for effect in w.effects:
		var needs := str(EffectRegistry.metadata(effect.handler).get("needs", ""))
		if not needs.is_empty():
			return needs
	return {EffectData.Target.BOARD_TILE: "tile", EffectData.Target.BOARD_2X2: "2x2",
		EffectData.Target.BOARD_3X3: "3x3", EffectData.Target.BOARD_ROW: "row",
		EffectData.Target.EMPTY_TILE: "empty", EffectData.Target.ENEMY_GLYPH: "enemy",
		EffectData.Target.DISCARD_GLYPH: "discard", EffectData.Target.ENEMY: "enemy_target"}.get(required_for_word(w), "none")
