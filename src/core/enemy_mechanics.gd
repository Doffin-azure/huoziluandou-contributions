extends RefCounted
class_name EnemyMechanics
## 怪物任务按玩家阶段开窗。预览只读，状态均挂在所属敌人的 status_data。

static func data(e: Combatant) -> Dictionary:
	return e.status_data.get("monster", {})

static func parameter(e: Combatant, key: String) -> int:
	return int(e.enemy_data.tuning.get(key, 0))

static func real_card(c: CharInstance) -> bool:
	return c != null and c.is_player_owned() and not c.temporary

static func pos(b: BattleState, c: CharInstance) -> Vector2i:
	var i := b.board.cells.find(c)
	return b.board.to_xy(i) if i >= 0 else Vector2i(-1, -1)

static func phase(e: Combatant) -> int:
	return 2 if e.hp * 100 <= e.max_hp * int(e.enemy_data.tuning.get("phase_percent", 50)) else 1

static func begin_phase(b: BattleState) -> void:
	for e in b.alive_enemies():
		if e.enemy_data == null or e.enemy_data.mechanic.is_empty(): continue
		var d := data(e)
		var stomach: Array = d.get("stomach", [])
		d = {"stomach": stomach, "targets": [], "origins": [], "done": false,
			"used": {}, "words": {}, "rewarded": [], "last_word": null,
			"cells": [], "move": e.move_index, "turn": b.turn}
		e.status_data.monster = d
		var action: String = e.enemy_data.moves[e.move_index % e.enemy_data.moves.size()].mechanic_action
		var candidates: Array = b.board.cells.filter(func(c): return real_card(c) and not c.pinned)
		match action:
			"fold", "proof":
				var limit := 1 if action == "fold" else parameter(e, "target_count")
				for i in mini(limit, candidates.size()):
					var c: CharInstance = candidates.pop_at(b.rng.randi_range(0, candidates.size() - 1))
					d.targets.append(c)
					d.origins.append(pos(b, c))
			"pair":
				if e.status_data.has("prepared_pair"):
					d.targets = e.status_data.prepared_pair
					d.origins = e.status_data.prepared_origins
					e.status_data.erase("prepared_pair")
					e.status_data.erase("prepared_origins")
					continue
				var pairs: Array = []
				for a in candidates:
					for c in candidates:
						if a.uid < c.uid and pos(b, a).y == pos(b, c).y: pairs.append([a, c])
				if not pairs.is_empty():
					d.targets = pairs[b.rng.randi_range(0, pairs.size() - 1)]
					for c in d.targets: d.origins.append(pos(b, c))
			"rail":
				var rows: Array = []
				for y in b.board.size:
					var row: Array = candidates.filter(func(c): return pos(b, c).y == y)
					if not row.is_empty(): rows.append(row)
				if not rows.is_empty():
					var row: Array = rows[b.rng.randi_range(0, rows.size() - 1)]
					d.targets = row.slice(0, parameter(e, "target_count") if phase(e) == 1 else parameter(e, "phase2_target_count"))
					for c in d.targets: d.origins.append(pos(b, c))
			"bomb", "seal":
				var anchor := Vector2i(b.rng.randi_range(0, b.board.size - 2), b.rng.randi_range(0, b.board.size - 2))
				d.cells = [anchor, anchor + Vector2i.RIGHT, anchor + Vector2i.DOWN, anchor + Vector2i.ONE]
				if action == "bomb":
					var first := b.rng.randi_range(0, 3)
					d.cells = [d.cells[first], d.cells[(first + 1 + b.rng.randi_range(0, 2)) % 4]]
			"swallow":
				var cards: Array = b.discard.filter(func(c): return real_card(c))
				if not cards.is_empty(): d.targets = [cards.back()]
		# 跳过预备动作时也要有题目；双面简无合法目标的护盾只在翻签动作发。

static func reward(b: BattleState, e: Combatant, key: String, amount: int) -> void:
	var d := data(e)
	if d.rewarded.has(key): return
	d.rewarded.append(key)
	if b.achievement != null and e.enemy_data.mechanic == "fold" and key.begins_with("sign"):
		b.achievement.emit_metrics([{"metric": "fold_tasks", "amount": 1}])
	if e.is_alive():
		var before := e.hp
		e.take_damage(amount) # 机制伤害仍正常扣盾，不吃攻击增幅、不被精分重定向。
		b.damage_dealt_this_turn += before - e.hp
		b._check_bounty()
		b._log("%s：任务奖励，造成 %d 机制伤害" % [e.display_name, amount])

static func update_targets(b: BattleState, e: Combatant, word: WordData = null, instances: Array = []) -> void:
	var d := data(e)
	if d.is_empty(): return
	var action: String = e.enemy_data.moves[e.move_index % e.enemy_data.moves.size()].mechanic_action
	var multi := word != null and word.length() >= 2
	for i in d.targets.size():
		var c: CharInstance = d.targets[i]
		if action not in ["fold", "proof"]: break
		var used := instances.has(c)
		var left := pos(b, c).x < 0
		var moved: bool = action == "proof" and i == 1 and pos(b, c) != d.origins[i]
		if (used or left or moved) and not d.used.has(c.uid):
			d.used[c.uid] = true
			if used and multi: reward(b, e, "sign%d" % i, parameter(e, "reward"))
	if action == "proof" and d.targets.size() >= 2 and unresolved(b, e, action) == 0 and not bool(d.get("achievement_proof", false)):
		d.achievement_proof = true
		if b.achievement != null: b.achievement.emit_metrics([{"metric": "proof_tasks", "amount": 1}])
	if action == "pair" and d.targets.size() == 2 and not d.done:
		var a: CharInstance = d.targets[0]
		var c: CharInstance = d.targets[1]
		if (pos(b, a) == d.origins[1] and pos(b, c) == d.origins[0]) or (multi and instances.has(a) and instances.has(c)):
			d.done = true
			reward(b, e, "pair", parameter(e, "reward"))

static func on_play(b: BattleState, word: WordData, instances: Array, consumed: Array, entered_before: Dictionary) -> void:
	for e in b.alive_enemies():
		if e.enemy_data == null or e.enemy_data.mechanic.is_empty(): continue
		var d := data(e)
		if d.is_empty(): continue
		update_targets(b, e, word, instances)
		var multi := word != null and word.length() >= 2
		if multi:
			d.last_word = word
			d.words[word.id] = int(d.words.get(word.id, 0)) + 1
			var unique := {}
			for c in instances:
				if real_card(c) and not unique.has(c.uid):
					unique[c.uid] = true
					d.used[c.uid] = int(d.used.get(c.uid, 0)) + 1 if e.enemy_data.mechanic == "wheel" else d.used.get(c.uid, 0)
					if e.enemy_data.mechanic == "nest" and entered_before.has(c.uid) and not d.done:
						d.done = true
						e.remove_block(parameter(e, "break_block"))
					if e.enemy_data.mechanic == "wheel" and int(d.used[c.uid]) >= parameter(e, "required_uses"):
						d.done = true
						reward(b, e, "wheel", parameter(e, "reward"))
		if e.enemy_data.mechanic == "glutton" and not d.stomach.is_empty():
			var material_count := 0
			for item in consumed:
				if item.kind == "real" and not item.get("shared", false): material_count += 1
			if e.largest_hp_hit >= parameter(e, "release_hit") or (multi and material_count >= parameter(e, "release_material")):
				var rescued: CharInstance = d.stomach.pop_front()
				b.bag.append(rescued)
				b._log("饕餮：吐回【%s】至袋顶" % rescued.glyph())
	release_dead(b)

static func task_done(b: BattleState, e: Combatant, action: String) -> bool:
	var d := data(e)
	match action:
		"arc": return b.monster_net_energy >= parameter(e, "energy_required")
		"bill": return b.monster_paid
		"nest", "wheel", "pair": return bool(d.get("done", false))
		"different": return d.get("words", {}).size() >= parameter(e, "distinct_required")
		"repeat":
			for count in d.get("words", {}).values():
				if int(count) >= parameter(e, "repeat_required"): return true
	return false

static func unresolved(b: BattleState, e: Combatant, action: String) -> int:
	var d := data(e)
	var count := 0
	for i in d.get("targets", []).size():
		var c: CharInstance = d.targets[i]
		if action == "rail":
			if pos(b, c).x >= 0 and pos(b, c).y == d.origins[i].y: count += 1
		elif not d.used.has(c.uid) and pos(b, c).x >= 0:
			if action != "proof" or i != 1 or pos(b, c) == d.origins[i]: count += 1
	return count

static func preview(b: BattleState, e: Combatant) -> EnemyMoveData:
	var base: EnemyMoveData = e.enemy_data.moves[e.move_index % e.enemy_data.moves.size()]
	if e.enemy_data.mechanic.is_empty(): return base
	var mv: EnemyMoveData = base.duplicate()
	var d := data(e)
	var action := mv.mechanic_action
	var second := phase(e) == 2
	match action:
		"gravity": mv.description += "\n全盘向左压缩，固定字不移动。"
		"rotate": mv.description += "\n中央2×2顺时针旋转；遇固定字整次跳过。"
		"fold": mv.damage = base.damage if unresolved(b, e, action) > 0 else parameter(e, "resolved_damage")
		"blank": pass
		"corrode":
			mv.kind = EnemyMoveData.Kind.INJECT
		"belly": mv.damage = base.damage + mini(parameter(e, "belly_bonus_cap"), d.get("stomach", []).size())
		"heat6", "heat8":
			mv.damage += parameter(e, "heat_bonus") if b.player.heat >= parameter(e, "heat_threshold") else 0
		"arc", "bill": mv.damage = parameter(e, "resolved_damage") if task_done(b, e, action) else base.damage
		"pair":
			mv.damage = base.damage
			if d.get("targets", []).size() < 2: mv.damage = parameter(e, "partial_damage")
			elif task_done(b, e, action): mv.damage = parameter(e, "resolved_damage")
			elif d.targets.any(func(c): return pos(b, c).x < 0): mv.damage = parameter(e, "partial_damage")
		"nest": mv.damage = parameter(e, "resolved_damage") if task_done(b, e, action) else base.damage
		"wheel": mv.damage = parameter(e, "resolved_damage") if task_done(b, e, action) else base.damage
		"seal":
			mv.damage = base.damage
			for cell in d.get("cells", []):
				if b.board.get_xy(cell) != null: mv.damage += parameter(e, "occupied_bonus")
		"proof": mv.damage = (parameter(e, "phase2_damage") if second else base.damage) + parameter(e, "unresolved_bonus") * unresolved(b, e, action)
		"rail": mv.damage = (parameter(e, "phase2_damage") if second else base.damage) + parameter(e, "unresolved_bonus") * unresolved(b, e, action)
		"different", "repeat": mv.damage = (parameter(e, "phase2_resolved_damage") if second else parameter(e, "resolved_damage")) if task_done(b, e, action) else (parameter(e, "phase2_damage") if second else base.damage)
		"proof_shield": mv.block = parameter(e, "phase2_block") if second else base.block
		"rail_shield": mv.block = parameter(e, "phase2_block") if second else base.block
		"boss_multi": mv.damage = parameter(e, "phase2_multi_damage") if second else base.damage
		"copy":
			mv.inject_count = 0 # 只有空间分支塞字，其他分支不会继承配置里的数量。
			var word: WordData = d.get("last_word")
			var category := copy_category(word)
			if category == "attack":
				mv.kind = EnemyMoveData.Kind.MULTI if mv.hits > 1 else EnemyMoveData.Kind.ATTACK
				mv.damage = parameter(e, "attack_damage")
			elif category == "space":
				mv.kind = EnemyMoveData.Kind.INJECT
				mv.inject_count = base.inject_count
			else:
				mv.kind = EnemyMoveData.Kind.BLOCK
				mv.block = parameter(e, category + "_block")
	mv.description += "\n" + task_text(b, e)
	return mv

static func copy_category(word: WordData) -> String:
	if word == null: return "other"
	# 词分组只是展示；按实际效果语义分类，固定攻击 > 防御 > 补字/空间 > 经济。
	for effect in word.effects:
		if effect.semantic_kind() in [EffectData.Kind.DAMAGE, EffectData.Kind.DAMAGE_ALL] or effect.handler in ["shield_break_attack", "heat_burst", "energy_attack"]: return "attack"
	for effect in word.effects:
		if effect.semantic_kind() in [EffectData.Kind.BLOCK, EffectData.Kind.PERSISTENT_BLOCK] or effect.handler in ["counter", "guard_halve", "guard_next"]: return "defense"
	if word.group == "防反": return "defense"
	for effect in word.effects:
		if effect.semantic_kind() in [EffectData.Kind.DRAW_CHARS, EffectData.Kind.GRAVITY] or effect.handler in ["replay_word", "precision_place", "deploy_from_bag", "buyback_place", "rotate_2x2", "swap_row_pair", "shift_row", "suspend_three"]: return "space"
	if word.group in ["空间", "流转"] or not word.interaction.is_empty(): return "space"
	if word.group == "经济": return "economy"
	return "other"

static func before_action(b: BattleState, e: Combatant, mv: EnemyMoveData) -> void:
	if e.enemy_data.mechanic.is_empty(): return
	var action := mv.mechanic_action
	e.status_data.attack_hp_before = b.player.hp
	var d := data(e)
	if action in ["arc", "bill"] and task_done(b, e, action):
		e.remove_block(parameter(e, "break_block"))
	if action == "blank":
		if b.board.free_count() >= parameter(e, "empty_required"): reward(b, e, "blank", parameter(e, "reward"))
		else: e.add_block(parameter(e, "shield_gain"))
	if action in ["different", "repeat"] and task_done(b, e, action): reward(b, e, action, parameter(e, "reward"))

static func special(b: BattleState, e: Combatant, mv: EnemyMoveData) -> void:
	var d := data(e)
	match mv.mechanic_action:
		"refill8": e.add_block(maxi(0, parameter(e, "shield_target") - e.block))
		"gravity":
			if not blocked_interference(b): b.apply_gravity_left()
		"rotate":
			if not blocked_interference(b): b.rotate_2x2(Vector2i((b.board.size - 2) / 2, (b.board.size - 2) / 2))
		"swallow":
			if d.stomach.size() < parameter(e, "stomach_capacity") and not d.targets.is_empty() and b.discard.has(d.targets[0]):
				var c: CharInstance = d.targets[0]
				b.discard.erase(c)
				d.stomach.append(c)
				e.add_block(parameter(e, "swallow_block"))
		"flip":
			var pairs: Array = []
			var candidates: Array = b.board.cells.filter(func(c): return real_card(c) and not c.pinned)
			for a in candidates:
				for c in candidates:
					if a.uid < c.uid and pos(b,a).y == pos(b,c).y: pairs.append([a,c])
			e.status_data.prepared_pair = [] if pairs.is_empty() else pairs[b.rng.randi_range(0,pairs.size()-1)]
			e.status_data.prepared_origins = []
			for c in e.status_data.prepared_pair: e.status_data.prepared_origins.append(pos(b,c))
			if pairs.is_empty(): e.add_block(parameter(e, "empty_block"))

		"bomb_mark": e.add_block(maxi(0, parameter(e, "mark_block") - e.block))
	b._log("%s：%s" % [e.display_name, mv.title])

## 所有指定塞字共用防护、护、加收与空格检查；同源字限制仅计算盘面实体。
static func injected_count(b: BattleState, source_id: int, glyph: String) -> int:
	return b.board.cells.filter(func(c): return c != null and c.is_enemy_owned() and c.glyph() == glyph and c.statuses.get("injected_by", -1) == source_id).size()

static func inject_move(b: BattleState, e: Combatant, mv: EnemyMoveData) -> int:
	var count := mv.inject_count
	var cap := parameter(e, "inject_cap")
	# The enemy array is saved in battle order; runtime ObjectIDs change on load.
	var source_id := b.enemies.find(e)
	if source_id < 0: return 0
	if cap > 0: count = mini(count, maxi(0, cap - injected_count(b, source_id, mv.inject_glyph)))
	if count <= 0 or b.board.free_count() <= 0: return 0
	var before := b.temp_chars.size()
	var added := b.inject_enemy_glyphs(count, mv.pollution_id, mv.inject_glyph, source_id)
	for c in b.temp_chars.slice(before):
		c.statuses.inject_cap = cap
		c.statuses.replicate_count = parameter(e, "replicate_count")
		c.statuses.replicate_delay = parameter(e, "replicate_delay")
	return added

## 玩家完整获得一个操作阶段后，未净化的连在回合结束复制；按快照分批，子代不在本次继续繁殖。
static func replicate_glyphs(b: BattleState) -> void:
	if b.is_over(): return
	var waves := {}
	for c in b.board.cells.duplicate():
		if c == null or not c.is_enemy_owned() or not c.has_pollution("replicate"): continue
		var delay: int = maxi(1, int(c.statuses.get("replicate_delay", 1)))
		if b.turn - int(c.statuses.get("injected_turn", b.turn)) < delay: continue
		if int(c.statuses.get("replicated_turn", -1)) == b.turn: continue
		c.statuses.replicated_turn = b.turn
		var source_id: int = c.statuses.get("injected_by", -1)
		var wave: Dictionary = waves.get(source_id, {"count": 0, "parent": c, "parents": []})
		wave.parents.append(c)
		wave.count += int(c.statuses.get("replicate_count", 1))
		waves[source_id] = wave
	for source_id in waves:
		var parent: CharInstance = waves[source_id].parent
		var cap: int = int(parent.statuses.get("inject_cap", 4))
		var count := mini(int(waves[source_id].count), maxi(0, cap - injected_count(b, source_id, parent.glyph())))
		if count <= 0 or b.board.free_count() <= 0: continue
		var before := b.temp_chars.size()
		var added := b.inject_enemy_glyphs(count, "replicate", parent.glyph(), source_id)
		if added > 0:
			for original in waves[source_id].parents: original.statuses.achievement_replicated = true
		for c in b.temp_chars.slice(before):
			for key in ["inject_cap", "replicate_count", "replicate_delay"]:
				c.statuses[key] = parent.statuses.get(key, 1)
		b._log("蔓生【%s】：复制%d枚，同源盘面上限%d；单打、组词或净化可阻止复制" % [parent.glyph(), added, cap])

static func blocked_interference(b: BattleState) -> bool:
	if not b.has_ability("prevent_interference"): return false
	b.abilities.erase("prevent_interference")
	b._log("防护：抵消本次敌方盘面干扰")
	return true

static func after_action(b: BattleState, e: Combatant, mv: EnemyMoveData) -> void:
	if e.enemy_data.mechanic.is_empty(): return
	var action := mv.mechanic_action
	if action in ["heat6", "heat8"] and b.player.is_alive() and e.is_alive(): b.add_heat(parameter(e, "heat_gain"))
	if action == "leech" and b.player.is_alive() and e.is_alive():
		# 吸能只认这一完整攻击实际造成的生命减少，心力免死/精分不触发。
		if int(e.status_data.get("attack_hp_before", b.player.hp)) > b.player.hp:
			var stolen := mini(parameter(e, "steal"), b.player.energy)
			b.player.energy -= stolen
			e.add_block(mini(stolen * parameter(e, "shield_per_energy"), maxi(0, parameter(e, "shield_cap") - e.block)))
	if action == "bomb" and e.is_alive() and b.player.is_alive() and not blocked_interference(b):
		for cell in data(e).get("cells", []):
			var c: CharInstance = b.board.get_xy(cell)
			if c == null or c.pinned: continue
			if real_card(c):
				if b.has_ability("blastproof"):
					b.bag.append(c)
					b.player.add_persistent_block(parameter(e, "protect_block"))
				else: b.discard.append(c)
			else: b.temp_chars.erase(c)
			b.board.clear_xy(cell)
	if action == "rail" and e.is_alive() and not data(e).get("targets", []).is_empty() and unresolved(b, e, "rail") == 0:
		e.remove_block(parameter(e, "clear_break"))
		if b.achievement != null and not bool(data(e).get("achievement_rail", false)):
			data(e).achievement_rail = true
			b.achievement.emit_metrics([{"metric": "rail_tasks", "amount": 1}])
	if action in ["different", "repeat"] and e.is_alive() and b.player.is_alive() and not task_done(b, e, action): e.add_block(parameter(e, "phase2_fail_block") if phase(e) == 2 else parameter(e, "fail_block"))

static func release_dead(b: BattleState) -> void:
	for e in b.enemies:
		if e.is_alive() and b.player.is_alive(): continue
		var d := data(e)
		for c in d.get("stomach", []): b.bag.append(c)
		if d.has("stomach"): d.stomach.clear()

static func task_text(b: BattleState, e: Combatant) -> String:
	var d := data(e)
	var targets: Array[String] = []
	for i in d.get("targets", []).size():
		var c: CharInstance = d.targets[i]
		var origin: Vector2i = d.origins[i] if i < d.origins.size() else pos(b, c)
		targets.append("%s【%s】（原第%d行%d列）" % ["红签" if e.enemy_data.mechanic == "proof" and i == 0 else ("蓝签" if e.enemy_data.mechanic == "proof" else "目标"), c.glyph(), origin.y + 1, origin.x + 1])
	for cell in d.get("cells", []): targets.append("第%d行%d列" % [cell.y + 1, cell.x + 1])
	var extra := "；".join(targets)
	var progress := ""
	match e.enemy_data.mechanic:
		"charge": progress = "本阶段储能净消费：%d / %d" % [b.monster_net_energy, parameter(e, "energy_required")]
		"credit": progress = "正价支付：" + ("已完成" if b.monster_paid else "未完成")
		"nest", "wheel", "pair": progress = "任务：" + ("已完成" if d.get("done", false) else "未完成")
		"compiler":
			progress = "本阶段不同词：%d种；最多同名词：%d次" % [d.get("words", {}).size(), d.get("words", {}).values().max() if not d.get("words", {}).is_empty() else 0]
	return e.enemy_data.description + ("\n预告：" + extra if not extra.is_empty() else "") + ("\n" + progress if not progress.is_empty() else "")

static func markers(b: BattleState) -> Array:
	var out: Array = []
	for e in b.alive_enemies():
		var first_marker := out.size()
		var d := data(e)
		if e.enemy_data != null and not e.enemy_data.moves.is_empty() and e.enemy_data.moves[e.move_index % e.enemy_data.moves.size()].mechanic_action == "rotate":
			var anchor := Vector2i((b.board.size - 2) / 2, (b.board.size - 2) / 2)
			for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]: out.append({"cell": anchor + offset, "label": "转"})
		for i in d.get("targets", []).size():
			var cell := pos(b, d.targets[i])
			if cell.x >= 0 and not (e.enemy_data.mechanic in ["fold", "proof"] and d.used.has(d.targets[i].uid)): out.append({"cell": cell, "label": "红" if e.enemy_data.mechanic == "proof" and i == 0 else ("蓝" if e.enemy_data.mechanic == "proof" else "签")})
		for cell in d.get("cells", []): out.append({"cell": cell, "label": "爆" if e.enemy_data.mechanic == "bomb" else "印"})
		for index in range(first_marker, out.size()):
			out[index]["source"] = e.display_name
			out[index]["description"] = marker_description(e, str(out[index].label))
			out[index]["name"] = marker_name(e, str(out[index].label))
	return out


static func marker_name(e: Combatant, label: String) -> String:
	if label == "转": return "旋转预告"
	if label == "爆": return "爆破预告"
	if label == "印": return "印区"
	if label == "红": return "红签"
	if label == "蓝": return "蓝签"
	return {"fold": "折页签", "pair": "双面签", "rail": "压轨签"}.get(e.enemy_data.mechanic, "目标标记")

static func marker_description(e: Combatant, label: String) -> String:
	var template := ""
	if label == "转": return "下次行动将中央2×2顺时针旋转90°。区域内有固定字时，不旋转。"
	match e.enemy_data.mechanic:
		"fold": template = "打出或移出此字可解签，单纯移动无效。解签后折页伤害降至{resolved_damage}；组词解签再对怪物造成{reward}伤害。"
		"pair": template = "两枚签字互换原位，或同词使用两字：怪物受{reward}伤害，合简降至{resolved_damage}。未完成上述条件时，有字离盘则降至{partial_damage}。"
		"rail": template = "将此字移出原行。每枚仍在原行的签字使压轨伤害+{unresolved_bonus}；全部撤离后，攻击结束拆除{clear_break}格挡。"
		"proof": template = ("打出或移出此字可解签，单纯移动无效。" if label == "红" else "打出、移出或移动此字都可解签。") + "每枚未解签使朱批伤害+{unresolved_bonus}；组词解签再对怪物造成{reward}伤害。"
		"bomb": template = "引爆时摧毁此格内未固定的字。把字移走即可避开；己方原字进弃字堆，敌方字和临时字消失。"
		"seal": template = "朱批时，此格每有1字，伤害+{occupied_bonus}。清空此格可避免加伤。"
	return template.format(EnemyBalance.parameters(e.enemy_data)) if not template.is_empty() else e.enemy_data.description
