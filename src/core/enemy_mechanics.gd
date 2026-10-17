extends RefCounted
class_name EnemyMechanics
## 怪物任务按玩家阶段开窗。预览只读，状态均挂在所属敌人的 status_data。

static func data(e: Combatant) -> Dictionary:
	return e.status_data.get("monster", {})

static func real_card(c: CharInstance) -> bool:
	return c != null and c.is_player_owned() and not c.temporary

static func pos(b: BattleState, c: CharInstance) -> Vector2i:
	var i := b.board.cells.find(c)
	return b.board.to_xy(i) if i >= 0 else Vector2i(-1, -1)

static func phase(e: Combatant) -> int:
	return 2 if e.hp * 2 <= e.max_hp else 1

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
				var limit := 1 if action == "fold" else 2
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
					d.targets = row.slice(0, 3 if phase(e) == 1 else 4)
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
			if used and multi: reward(b, e, "sign%d" % i, 3)
	if action == "pair" and d.targets.size() == 2 and not d.done:
		var a: CharInstance = d.targets[0]
		var c: CharInstance = d.targets[1]
		if (pos(b, a) == d.origins[1] and pos(b, c) == d.origins[0]) or (multi and instances.has(a) and instances.has(c)):
			d.done = true
			reward(b, e, "pair", 5)

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
						e.remove_block(6)
					if e.enemy_data.mechanic == "wheel" and int(d.used[c.uid]) >= 2:
						d.done = true
						reward(b, e, "wheel", 8)
		if e.enemy_data.mechanic == "glutton" and not d.stomach.is_empty():
			var material_count := 0
			for item in consumed:
				if item.kind == "real" and not item.get("shared", false): material_count += 1
			if e.largest_hp_hit >= 10 or (multi and material_count >= 3):
				var rescued: CharInstance = d.stomach.pop_front()
				b.bag.append(rescued)
				b._log("饕餮：吐回【%s】至袋顶" % rescued.glyph())
	release_dead(b)

static func task_done(b: BattleState, e: Combatant, action: String) -> bool:
	var d := data(e)
	match action:
		"arc": return b.monster_net_energy >= 2
		"bill": return b.monster_paid
		"nest", "wheel", "pair": return bool(d.get("done", false))
		"different": return d.get("words", {}).size() >= 2
		"repeat":
			for count in d.get("words", {}).values():
				if int(count) >= 2: return true
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
		"fold": mv.damage = 8 if unresolved(b, e, action) > 0 else 5
		"blank": pass
		"belly": mv.damage = 10 + mini(3, d.get("stomach", []).size())
		"heat6", "heat8": mv.damage += 4 if b.player.heat >= 8 else 0
		"arc", "bill": mv.damage = 6 if task_done(b, e, action) else 10
		"pair":
			mv.damage = 12
			if d.get("targets", []).size() < 2: mv.damage = 9
			elif task_done(b, e, action): mv.damage = 7
			elif d.targets.any(func(c): return pos(b, c).x < 0): mv.damage = 9
		"nest": mv.damage = 7 if task_done(b, e, action) else 11
		"wheel": mv.damage = 8 if task_done(b, e, action) else 14
		"seal":
			mv.damage = 8
			for cell in d.get("cells", []):
				if b.board.get_xy(cell) != null: mv.damage += 2
		"proof": mv.damage = (10 if second else 8) + 2 * unresolved(b, e, action)
		"rail": mv.damage = (12 if second else 10) + 2 * unresolved(b, e, action)
		"different", "repeat": mv.damage = (10 if second else 8) if task_done(b, e, action) else (14 if second else 12)
		"proof_shield": mv.block = 8 if second else 6
		"rail_shield": mv.block = 10 if second else 8
		"boss_multi": mv.damage = 7 if second else 6
		"copy":
			var word: WordData = d.get("last_word")
			var category := copy_category(word)
			if category == "attack":
				mv.kind = EnemyMoveData.Kind.ATTACK
				mv.damage = 10
			elif category == "space":
				mv.kind = EnemyMoveData.Kind.INJECT
				mv.inject_count = 1
				mv.pollution_id = "block"
			else:
				mv.kind = EnemyMoveData.Kind.BLOCK
				mv.block = {"defense": 8, "economy": 6, "other": 3}[category]
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
		e.remove_block(8 if action == "bill" else 6)
	if action == "blank":
		if b.board.free_count() >= 3: reward(b, e, "blank", 3)
		else: e.add_block(4)
	if action in ["different", "repeat"] and task_done(b, e, action): reward(b, e, action, 6)

static func special(b: BattleState, e: Combatant, mv: EnemyMoveData) -> void:
	var d := data(e)
	match mv.mechanic_action:
		"refill8": e.add_block(maxi(0, 8 - e.block))
		"gravity":
			if not blocked_interference(b): b.apply_gravity_left()
		"rotate":
			if not blocked_interference(b): b.rotate_2x2(Vector2i((b.board.size - 2) / 2, (b.board.size - 2) / 2))
		"corrode":
			var existing := b.board.cells.filter(func(c): return c != null and c.statuses.get("injected_by", -1) == e.get_instance_id()).size()
			var count := mini(2, 3 - existing)
			if count > 0 and not blocked_interference(b):
				var guard := mini(count, b.ability_value("guard_inject"))
				count -= guard
				if guard > 0:
					var left := b.ability_value("guard_inject") - guard
					if left > 0: b.abilities["guard_inject"] = left
					else: b.abilities.erase("guard_inject")
				for i in count:
					var empty := b.board.empty_indices()
					if empty.is_empty(): break
					var c := CharInstance.new(Database.get_character_by_glyph("蚀"))
					c.owner = CharInstance.Owner.ENEMY
					c.add_pollution("rush")
					c.statuses.injected_by = e.get_instance_id()
					b.board.set_xy(empty[b.rng.randi_range(0, empty.size() - 1)], c)
					b.temp_chars.append(c)
					if b.has_ability("inject_bounty"): b.earn_gold(2)
		"swallow":
			if d.stomach.size() < 3 and not d.targets.is_empty() and b.discard.has(d.targets[0]):
				var c: CharInstance = d.targets[0]
				b.discard.erase(c)
				d.stomach.append(c)
				e.add_block(4)
		"flip":
			var pairs: Array = []
			var candidates: Array = b.board.cells.filter(func(c): return real_card(c) and not c.pinned)
			for a in candidates:
				for c in candidates:
					if a.uid < c.uid and pos(b,a).y == pos(b,c).y: pairs.append([a,c])
			e.status_data.prepared_pair = [] if pairs.is_empty() else pairs[b.rng.randi_range(0,pairs.size()-1)]
			e.status_data.prepared_origins = []
			for c in e.status_data.prepared_pair: e.status_data.prepared_origins.append(pos(b,c))
			if pairs.is_empty(): e.add_block(4)

		"bomb_mark": e.add_block(maxi(0, 6 - e.block))
	b._log("%s：%s" % [e.display_name, mv.title])

static func blocked_interference(b: BattleState) -> bool:
	if not b.has_ability("prevent_interference"): return false
	b.abilities.erase("prevent_interference")
	b._log("防护：抵消本次敌方盘面干扰")
	return true

static func after_action(b: BattleState, e: Combatant, mv: EnemyMoveData) -> void:
	if e.enemy_data.mechanic.is_empty(): return
	var action := mv.mechanic_action
	if action in ["heat6", "heat8"] and b.player.is_alive() and e.is_alive(): b.add_heat(2)
	if action == "leech" and b.player.is_alive() and e.is_alive():
		# 吸能只认这一完整攻击实际造成的生命减少，心力免死/精分不触发。
		if int(e.status_data.get("attack_hp_before", b.player.hp)) > b.player.hp:
			var stolen := mini(2, b.player.energy)
			b.player.energy -= stolen
			e.add_block(mini(stolen * 2, maxi(0, 8 - e.block)))
	if action == "bomb" and e.is_alive() and b.player.is_alive() and not blocked_interference(b):
		for cell in data(e).get("cells", []):
			var c: CharInstance = b.board.get_xy(cell)
			if c == null or c.pinned: continue
			if real_card(c):
				if b.has_ability("blastproof"):
					b.bag.append(c)
					b.player.add_persistent_block(1)
				else: b.discard.append(c)
			else: b.temp_chars.erase(c)
			b.board.clear_xy(cell)
	if action == "rail" and e.is_alive() and not data(e).get("targets", []).is_empty() and unresolved(b, e, "rail") == 0: e.remove_block(8)
	if action in ["different", "repeat"] and e.is_alive() and b.player.is_alive() and not task_done(b, e, action): e.add_block(8 if phase(e) == 2 else 6)

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
		"charge": progress = "本阶段储能净消费：%d / 2" % b.monster_net_energy
		"credit": progress = "正价支付：" + ("已完成" if b.monster_paid else "未完成")
		"nest", "wheel", "pair": progress = "任务：" + ("已完成" if d.get("done", false) else "未完成")
		"compiler":
			progress = "本阶段不同词：%d种；最多同名词：%d次" % [d.get("words", {}).size(), d.get("words", {}).values().max() if not d.get("words", {}).is_empty() else 0]
	return e.enemy_data.description + ("\n预告：" + extra if not extra.is_empty() else "") + ("\n" + progress if not progress.is_empty() else "")

static func markers(b: BattleState) -> Array:
	var out: Array = []
	for e in b.alive_enemies():
		var d := data(e)
		if e.enemy_data != null and not e.enemy_data.moves.is_empty() and e.enemy_data.moves[e.move_index % e.enemy_data.moves.size()].mechanic_action == "rotate":
			var anchor := Vector2i((b.board.size - 2) / 2, (b.board.size - 2) / 2)
			for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]: out.append({"cell": anchor + offset, "label": "转"})
		for i in d.get("targets", []).size():
			var cell := pos(b, d.targets[i])
			if cell.x >= 0 and not (e.enemy_data.mechanic in ["fold", "proof"] and d.used.has(d.targets[i].uid)): out.append({"cell": cell, "label": "红" if e.enemy_data.mechanic == "proof" and i == 0 else ("蓝" if e.enemy_data.mechanic == "proof" else "签")})
		for cell in d.get("cells", []): out.append({"cell": cell, "label": "爆" if e.enemy_data.mechanic == "bomb" else "印"})
	return out
