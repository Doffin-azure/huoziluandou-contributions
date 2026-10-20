extends RefCounted
class_name PlayRequest
## 只读出字预检；界面、AI、正式结算共用。

static func inspect(b: BattleState, path: Array, target: Dictionary = {}) -> Dictionary:
	target = EffectTargets.normalize_target(target)
	var result := {"ok": false, "word": null, "glyphs": [], "solo": false, "reason": "",
		"need_target": -1, "messages": [], "zero_effect": false, "not_implemented": false, "interaction": "", "target": target}
	if not b.can_play():
		result.reason = "本回合出字阶段已经结束"
		return result
	if path.is_empty():
		result.reason = "未选择任何字"
		return result
	if not b.board.valid_path(path):
		result.reason = "路径不合法"
		return result
	if not b.pending_choice.is_empty() and path != b.pending_choice.path:
		result.reason = "请先完成或取消当前选字"
		return result
	if b.formation_mode and path.any(func(p): return b.reserved_cells.has(p)):
		result.reason = "该字已用于本次结阵"
		return result
	var glyphs: Array = b.board.glyphs_of(path)
	result.glyphs = glyphs

	var word: WordData = null
	var required := EffectData.Target.NONE
	if glyphs.size() >= 2:
		word = Database.get_word_by_glyphs(glyphs)
		# 【过】：连线中的【过】可被跳过（桥接），扩大连接面积
		if word == null and glyphs.has("过"):
			var filtered: Array = []
			for g in glyphs:
				if g != "过":
					filtered.append(g)
			if filtered.size() >= 2:
				var bridged: WordData = Database.get_word_by_glyphs(filtered)
				if bridged != null:
					word = bridged
					result.glyphs = filtered
		if word == null:
			word = Relics.fallback_word(b, glyphs)
		if word == null:
			result.reason = "“%s”不成词" % b._join(glyphs)
			return result
		result.word = word
		result.interaction = EffectTargets.interaction_of(word)
		if not word.implemented and not b.rules.allow_zero_effect_words:
			result.reason = "“%s”效果待定，暂不能出" % word.word
			return result
		required = EffectTargets.required_for_word(word)
		if not BattleState.has_required_target(required, target):
			result.need_target = required
			result.reason = "需要选择目标"
			return result
	else:
		var peek: CharInstance = b.board.get_xy(path[0])
		if peek != null and peek.data != null and not peek.word_only:
			if peek.data.solo_handler == "precision_draw" and not target.has("bag_uid"):
				var candidates := b.solo_bag_candidates(peek)
				if candidates.size() == 1:
					target = target.duplicate()
					target["bag_uid"] = candidates[0].uid
			if peek.data.solo_handler == "throw_neighbor" and not b.solo_target_cells(peek, path[0]).is_empty():
				var throw_reason := b.validate_solo_throw(peek, path[0], target)
				if not throw_reason.is_empty():
					result.reason = throw_reason
					if not target.has("tile") or not target.has("tile2"):
						result.need_target = EffectData.Target.BOARD_TILE
					return result
			var need := b._solo_requires_target(peek.data, path)
			required = need
			if not BattleState.has_required_target(need, target):
				result.need_target = need
				result.reason = "需要选择目标"
				return result
			if peek.data.solo_handler in ["cleanse_adjacent", "wash_adjacent", "move_neighbor", "split_neighbor", "recast_neighbor", "refine_junk_neighbor"] and target.has("tile") and not b.solo_target_cells(peek, path[0]).has(target.tile):
				result.reason = "请选择原格四邻的有效目标字"
				return result
			if peek.data.solo_handler == "solo_release" and bool(target.get("release_energy", false)) and b.player.energy < BattleBalance.i("release_cost", 1):
				result.reason = "放：释放攻击需要 %d 点储能" % BattleBalance.i("release_cost", 1)
				return result
			if peek.data.solo_handler in ["precision_draw", "buy_bag_solo"]:
				var bag_reason := b.validate_solo_bag(peek, path[0], target)
				if not bag_reason.is_empty():
					result.reason = bag_reason
					return result

	if required == EffectData.Target.BOARD_ROW:
		var row := int(target.get("row", -1))
		if row < 0 or row >= b.board.size:
			result.reason = "请选择棋盘内的一行"
			return result
	# 三字选择先验证独立实体，避免无效或重复目标仍然消耗施词字。
	if word != null:
		for eff in word.effects:
			var target_reason := EffectRegistry.validate(eff, b, path, target)
			if not target_reason.is_empty():
				result.reason = target_reason
				return result
			if eff.handler in ["recast_three", "suspend_three"] and not EffectHandlersActions.valid_recast_targets(b, target.get("cells", []), path):
				result.reason = "%s：请选择三个不同的非固定目标字（不含施词字）" % word.word
				return result
	if word == null:
		var source := b.board.get_xy(path[0])
		if source != null and source.data != null and not source.word_only:
			for eff in source.data.solo_effects:
				var reason := EffectRegistry.validate(eff, b, path, target)
				if not reason.is_empty():
					result.reason = reason
					return result
	if not b.pending_choice.is_empty() and word != null and EffectTargets.REVEALS.has(result.interaction):
		if path != b.pending_choice.path or path.map(func(p): return b.board.get_xy(p).uid) != b.pending_choice.uids:
			result.reason = "选字：施词实体已改变，请取消后重新选择"
			return result
	result.ok = true
	result.word = word
	result.target = target
	return result
