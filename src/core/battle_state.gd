extends RefCounted
class_name BattleState
signal enemy_acting(enemy: Combatant, move: EnemyMoveData)
## 单场战斗的完整逻辑状态（V0.2）。
## UI 只读取它并渲染；EffectHandlers 通过它公开的方法改状态。

var rules: BattleRules
var player: Combatant
var enemies: Array = []        ## Array[Combatant]
var board: BoardState
var bag: Array = []            ## 抽字袋
var discard: Array = []        ## 弃字堆
var turn: int = 0
var log: Array[String] = []
var rng := RandomNumberGenerator.new()
var visual_rng := RandomNumberGenerator.new()   ## 仅特效/台词，不消耗战斗 RNG

# --- 本场持续能力 / 下一词标记 ---
var abilities: Dictionary = {}
# --- 每回合统计 ---
var words_played_this_turn: Array = []
var attack_words_this_turn: int = 0
var drawn_this_turn: int = 0
var consumed_this_turn: Array = []
var next_draw_penalty: int = 0
var base_draw_penalty: int = 0
var last_attack_word: WordData = null
var last_attack_glyphs: Array = []
var last_attack_effects: Array = []
var last_attack_target: int = 0
# --- 本场临时/收编 ---
var temp_chars: Array = []      ## 敌人注入 + 自我灼热，战后清理
var captured_chars: Array = []  ## 收购得到的实体字，战后加入永久字袋
var damage_taken_last_turn: int = 0
var damage_dealt_this_turn: int = 0
var gold_earned: int = 0
var zero_effect_count: int = 0
var pending_place: CharInstance = null
var pending_reveal: Array = []   ## 转化等：已从字袋取出待选的实体字
var empowered_glyphs: Dictionary = {}   ## 强化：本场额外触发单字效果的字
var removed_this_battle: Array = []     ## 炼化：本场移出循环的牌
var bounty_paid: bool = false
var bounty_reward: int = 0
var words_played_all: Array = []
var last_played_glyphs: Array = []   ## 上一个出字的字形序列（供【再】重复）
var blackout_requested: bool = false   ## 停电彩蛋：请求黑屏
var end_turn_requested: bool = false    ## 急停：请求立即结束出字阶段
var repeat_armed: bool = false          ## 重复：本回合第一次多字词是否可重演

func _init(p_rules: BattleRules) -> void:
	rules = p_rules
	board = BoardState.new(p_rules.board_size)

func start(deck: Array, enemy_datas: Array, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	visual_rng.seed = rng.seed ^ 0x9E3779B9
	bag.clear()
	discard.clear()
	temp_chars.clear()
	captured_chars.clear()
	abilities.clear()
	empowered_glyphs.clear()
	removed_this_battle.clear()
	blackout_requested = false
	end_turn_requested = false
	repeat_armed = false
	last_played_glyphs.clear()
	board = BoardState.new(rules.board_size)
	for c in deck:
		c.owner = CharInstance.Owner.PLAYER
		c.temporary_uses = 0
		c.fusion.clear()
		bag.append(c)
	_shuffle(bag)
	player = Combatant.new("玩家", GameState.player_max_hp, true)
	player.hp = GameState.player_hp
	player.permanent_damage_reduction = GameState.permanent_damage_reduction
	player.heat_capacity = rules.heat_capacity
	enemies.clear()
	for ed in enemy_datas:
		var e := Combatant.new(ed.name, ed.max_hp, false)
		e.enemy_data = ed
		enemies.append(e)
	turn = 0
	draw_to_board(rules.opening_draw)
	begin_player_turn(false)

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func alive_enemies() -> Array:
	return enemies.filter(func(e): return e.is_alive())

func first_alive_enemy() -> Combatant:
	for e in enemies:
		if e.is_alive():
			return e
	return null

func is_over() -> bool:
	return not player.is_alive() or first_alive_enemy() == null

func is_victory() -> bool:
	return player.is_alive() and first_alive_enemy() == null


# ---------------------------------------------------------------- 补字

func remove_from_battle_glyph(glyph: String) -> CharInstance:
	if glyph.is_empty():
		return null
	for arr in [bag, discard]:
		for i in arr.size():
			var inst: CharInstance = arr[i]
			if inst.glyph() == glyph:
				arr.remove_at(i)
				removed_this_battle.append(inst)
				return inst
	for i in board.cells.size():
		var c: CharInstance = board.cells[i]
		if c != null and c.glyph() == glyph and c.is_player_owned():
			board.cells[i] = null
			removed_this_battle.append(c)
			return c
	return null


## 本场还在循环中的牌（字袋 + 弃字堆）的字形计数，供炼化选牌。

func add_heat(amount: int) -> int:
	player.add_heat(amount)
	if amount > 0 and player.heat > player.heat_capacity:
		var overflow: int = player.heat - player.heat_capacity
		# 只在“主动升温超过上限”时结算一次溢出（对应当前热量的超出量）
		var already: int = int(abilities.get("_overflow_paid", 0))
		var new_overflow: int = max(0, overflow - already)
		if new_overflow > 0:
			abilities["_overflow_paid"] = overflow
			spawn_scorch_into_bag(new_overflow)
			if has_ability("electric_overload"):
				add_energy(new_overflow)
				deal_damage(first_alive_enemy(), 3 * new_overflow, false)
				_log("电流过载：溢热 %d，储能 +%d，造成 %d 伤" % [new_overflow, new_overflow, 3 * new_overflow])
			if has_ability("heat_overload_bonus"):
				abilities["next_draw_bonus"] = int(abilities.get("next_draw_bonus", 0)) + 2
				abilities.erase("heat_overload_bonus")  # 每回合首次
			_log("过热：向字袋塞入 %d 枚灼热【热】" % new_overflow)
	if player.heat < player.heat_capacity:
		abilities["_overflow_paid"] = 0
	return player.heat

func add_energy(amount: int) -> void:
	player.add_energy(amount)


## 战内获得金币（受安全阀限制）。返回实际获得。

func earn_gold(amount: int) -> int:
	var allowed: int = amount
	if gold_earned + amount > rules.gold_cap_per_battle:
		allowed = max(0, rules.gold_cap_per_battle - gold_earned)
	gold_earned += allowed
	GameState.add_gold(allowed)
	if allowed > 0 and has_ability("profit_share"):
		add_energy(allowed)
		_log("分利：获得 %d 金币，同时储能 +%d" % [allowed, allowed])
	return allowed


# ---------------------------------------------------------------- 能力

func has_ability(id: String) -> bool:
	return abilities.has(id)

func enable_ability(id: String, value: int = 1) -> void:
	abilities[id] = value

func ability_value(id: String, default_value: int = 0) -> int:
	return int(abilities.get(id, default_value))


# ---------------------------------------------------------------- 伤害

func deal_damage(target: Combatant, amount: int, is_attack: bool = true) -> int:
	if target == null or amount <= 0:
		return 0
	var dmg := amount
	if is_attack:
		dmg += player.status_stacks("strength")
		dmg += player.status_stacks("next_bonus")
		if player.status_stacks("next_double") > 0:
			dmg *= 2
			player.add_status("next_double", -1)
		if player.status_stacks("next_bonus") > 0:
			player.add_status("next_bonus", -player.status_stacks("next_bonus"))
		var neb := ability_value("next_energy_bonus")
		if neb > 0:
			dmg += neb
			abilities.erase("next_energy_bonus")
		var sb := ability_value("next_serial_bonus")
		if sb > 0:
			dmg += sb
			abilities.erase("next_serial_bonus")
		if has_ability("split_mind") and not target.is_player:
			target = player   # 精分：自己的攻击也打自己
	var real := target.take_damage(dmg)
	if not target.is_player:
		damage_dealt_this_turn += real
		_check_bounty()
	return real

func _check_bounty() -> void:
	if bounty_paid and first_alive_enemy() == null:
		bounty_paid = false
		GameState.add_gold(bounty_reward)
		_log("重金：悬赏达成，获得 %d 金币" % bounty_reward)


# ---------------------------------------------------------------- 出字

func can_play() -> bool:
	return true   # V0.2：无固定出字次数上限


## target: {tile: Vector2i} / {discard_index:int} / {enemy_glyph:Vector2i}

func try_play(path: Array, target: Dictionary = {}) -> Dictionary:
	var result := {"ok": false, "word": null, "glyphs": [], "solo": false, "reason": "",
		"need_target": -1, "messages": [], "zero_effect": false, "not_implemented": false}
	if path.is_empty():
		result.reason = "未选择任何字"
		return result
	if not board.valid_path(path):
		result.reason = "路径不合法"
		return result
	var glyphs: Array = board.glyphs_of(path)
	result.glyphs = glyphs

	var word: WordData = null
	if glyphs.size() >= 2:
		word = Database.get_word_by_glyphs(glyphs)
		if word == null:
			result.reason = "“%s”不成词" % _join(glyphs)
			return result
		if not word.implemented and not rules.allow_zero_effect_words:
			result.reason = "“%s”效果待定，暂不能出" % word.word
			return result
		if word.requires_target != EffectData.Target.NONE and target.is_empty():
			result.need_target = word.requires_target
			result.reason = "需要选择目标"
			return result
	else:
		var peek: CharInstance = board.get_xy(path[0])
		if peek != null and peek.data != null:
			var need := _solo_requires_target(peek.data)
			if need != EffectData.Target.NONE and target.is_empty():
				result.need_target = need
				result.reason = "需要选择目标"
				return result

	# 采集消耗前的盘面信息（供蓄电等读取）
	var tail_neighbors_own := 0
	if path.size() > 0:
		var tail: Vector2i = path[path.size() - 1]
		for n in board.neighbors(tail):
			var c: CharInstance = board.get_xy(n)
			if c != null and c.is_player_owned() and not path.has(n):
				tail_neighbors_own += 1

	# 消耗
	var consumed := _consume_path(path)

	result.ok = true
	result.word = word
	result.solo = glyphs.size() == 1
	result.not_implemented = word != null and not word.implemented

	var effects: Array = []
	if word != null:
		effects = word.effects
	else:
		var first: CharInstance = consumed[0].inst if not consumed.is_empty() else null
		if first != null and first.data != null:
			effects = first.data.solo_effects
			if first.data.solo_handler == "replace_self":
				effects = [_synthetic("replace_self", 1, EffectData.Target.BOARD_TILE)]

	# 污染代价
	var pollution_msgs := _apply_pollution(consumed)
	result.messages.append_array(pollution_msgs)

	var ctx := {
		"battle": self,
		"source": player,
		"glyphs": glyphs,
		"target": target,
		"target_index": int(target.get("target_index", 0)),
		"word": word,
		"path": path,
		"tail_neighbors_own": tail_neighbors_own,
		"consumed": consumed,
	}
	var msgs := EffectResolver.resolve_all(effects, ctx)
	result.messages.append_array(msgs)
	for m in msgs:
		_log(m)

	# 重复：本回合第一次有效多字词，再执行一次其即时效果（不重复消耗字）
	if word != null and word.length() >= 2 and has_ability("repeat") and repeat_armed:
		repeat_armed = false
		var rep_msgs := EffectResolver.resolve_all(effects, ctx)
		for rm in rep_msgs:
			result.messages.append(rm)
			_log("重复：%s" % rm)

	# 强化：被强化的字作为词的一部分打出时，额外触发它的单字效果
	if word != null and not empowered_glyphs.is_empty():
		for c in consumed:
			var inst_e: CharInstance = c.inst
			if inst_e.data == null or not empowered_glyphs.has(inst_e.glyph()):
				continue
			var solo := _filter_targetless(inst_e.data.solo_effects)
			if solo.is_empty():
				continue
			var solo_ctx := {"battle": self, "source": player, "glyphs": [inst_e.glyph()],
				"target": target, "target_index": int(target.get("target_index", 0)), "word": word}
			var solo_msgs := EffectResolver.resolve_all(solo, solo_ctx)
			for sm in solo_msgs:
				result.messages.append(sm)
				_log("强化【%s】：%s" % [inst_e.glyph(), sm])

	# 精金：镀金字参与有效多字词 → +1 金币
	if word != null and word.length() >= 2:
		for c in consumed:
			var inst_g: CharInstance = c.inst
			if inst_g.gilded and earn_gold(1) > 0:
				result.messages.append("精金：【%s】+1 金币" % inst_g.glyph())
				_log("精金：【%s】+1 金币" % inst_g.glyph())

	# 反复：本回合首次无效果单字出牌，在原格补 1 字
	if glyphs.size() == 1 and effects.is_empty() and has_ability("repeat_zero") and ability_value("_repeat_used") == 0:
		abilities["_repeat_used"] = 1
		var back := draw_one_to(path[0])
		if back != null:
			_log("反复：在原格补 1 枚【%s】" % back.glyph())

	# 记录 / 持续能力触发
	if word != null:
		words_played_this_turn.append(word.id)
		if has_ability("vigor"):
			var distinct: Dictionary = {}
			for wid in words_played_this_turn:
				distinct[wid] = true
			abilities["vigor_next"] = distinct.size()
		if _is_attack_word(word):
			attack_words_this_turn += 1
			last_attack_word = word
			last_attack_glyphs = glyphs.duplicate()
			last_attack_effects = effects.duplicate()
			last_attack_target = int(target.get("target_index", 0))
		_trigger_on_word_abilities(word)
		EventBus.word_played.emit(word, _join(glyphs))
	else:
		var first2: CharInstance = consumed[0].inst if not consumed.is_empty() else null
		if first2 != null and first2.data != null:
			EventBus.character_played.emit(first2.data)

	# 重力（持续能力）：每次有效出字后自动全盘向下重力
	if has_ability("gravity_always"):
		apply_gravity()
		_log("重力：全盘下落")

	# 充电过热：此后每次出字后立即补满盘面
	if has_ability("auto_refill"):
		var filled := draw_to_board(board.size * board.size)
		if filled > 0:
			_log("充电过热：立即补位 %d 枚" % filled)

	if effects.is_empty():
		result.zero_effect = true
		zero_effect_count += 1

	_apply_next_word_flags(word)
	last_played_glyphs = glyphs.duplicate()
	return result


## 强化触发：过滤掉需要选目标/改盘面的单字效果，避免在成词时误触发

func _filter_targetless(effects: Array) -> Array:
	var out: Array = []
	for e in effects:
		if e.target in [EffectData.Target.BOARD_TILE, EffectData.Target.BOARD_2X2, EffectData.Target.EMPTY_TILE, EffectData.Target.DISCARD_GLYPH, EffectData.Target.ENEMY_GLYPH]:
			continue
		out.append(e)
	return out

func _solo_requires_target(cd: CharacterData) -> int:
	for e in cd.solo_effects:
		if e.target in [EffectData.Target.BOARD_TILE, EffectData.Target.BOARD_2X2, EffectData.Target.EMPTY_TILE, EffectData.Target.ENEMY_GLYPH, EffectData.Target.DISCARD_GLYPH]:
			return e.target
	return EffectData.Target.NONE

func _synthetic(handler: String, amount: int, target_kind: int) -> EffectData:
	var e := EffectData.new()
	e.handler = handler
	e.amount = amount
	e.target = target_kind
	return e

func _is_attack_word(word: WordData) -> bool:
	if word == null:
		return false
	for e in word.effects:
		if e.kind == EffectData.Kind.DAMAGE or e.kind == EffectData.Kind.DAMAGE_ALL:
			return true
		if e.handler in ["damage", "gravity_damage", "shield_smash", "break_shield_damage",
				"energy_discharge", "heat_burst", "destroy_2x2", "heat_to_damage_flow", "spend_gold_damage"]:
			return true
	return false


## 消耗一个路径；返回 [{inst, kind}]，kind = "real" / "layer"

func _consume_path(path: Array) -> Array:
	var out: Array = []
	for pos in path:
		var inst: CharInstance = board.get_xy(pos)
		if inst == null:
			continue
		if inst.temporary_uses > 0:
			inst.temporary_uses -= 1
			out.append({"inst": inst, "kind": "layer"})
		else:
			if inst.is_enemy_owned() or inst.temporary:
				temp_chars.erase(inst)
			else:
				discard.append(inst)
				consumed_this_turn.append(inst)
			board.clear_xy(pos)
			out.append({"inst": inst, "kind": "real"})
	return out

func _apply_pollution(consumed: Array) -> Array:
	var msgs: Array = []
	for c in consumed:
		var inst: CharInstance = c.inst
		for pid in inst.pollutions:
			var pd: PollutionData = Database.get_pollution(pid)
			if pd == null:
				continue
			if pd.hp_loss_on_play > 0:
				if has_ability("fireproof") and inst.glyph() == "热":
					msgs.append("防火：【热】的污染不再扣血")
				else:
					var real := player.take_damage(pd.hp_loss_on_play)
					msgs.append("污染【%s】：失去 %d 生命" % [pd.name, real])
			if pd.draw_penalty_on_play > 0:
				next_draw_penalty += pd.draw_penalty_on_play
				msgs.append("污染【%s】：下次补字 -%d" % [pd.name, pd.draw_penalty_on_play])
	return msgs

func _join(glyphs: Array) -> String:
	var s := ""
	for g in glyphs:
		s += str(g)
	return s


# ---------------------------------------------------------------- 持续能力 / 每回合

func _trigger_on_word_abilities(word: WordData) -> void:
	if word == null:
		return
	if has_ability("accel"):
		var n := draw_to_board(1)
		add_heat(1)
		_log("加速：补 %d 字，热度 +1" % n)
	if has_ability("flow"):
		var distinct := {}
		for id in words_played_this_turn:
			distinct[id] = true
		if distinct.size() >= 2 and distinct.size() % 2 == 0:
			var n2 := draw_to_board(2)
			_log("流转：补 %d 字" % n2)
	if has_ability("serial"):
		if not words_played_all.has(word.id):
			words_played_all.append(word.id)
			if words_played_all.size() % 3 == 0:
				var sb := ability_value("serial", 6)
				abilities["next_serial_bonus"] = sb
				_log("连载：下一次攻击 +%d 伤" % sb)

func _apply_next_word_flags(word: WordData) -> void:
	if word == null:
		return
	# 只对“多字词”生效的下一词标记
	if word.length() < 2:
		return
	if ability_value("next_rapid") > 0:
		var n := draw_to_board(ability_value("next_rapid"))
		add_heat(int(abilities.get("next_rapid_heat", 0)))
		_log("急速：补 %d 字" % n)
		abilities.erase("next_rapid")
		abilities.erase("next_rapid_heat")
	if ability_value("next_double_draw") > 0:
		var n2 := draw_to_board(ability_value("next_double_draw"))
		add_heat(n2)
		_log("超速：补 %d 字" % n2)
		abilities.erase("next_double_draw")
	if ability_value("next_compound") > 0:
		_log("复合：保留临时层（原型：已在消耗时处理）")
		abilities.erase("next_compound")
	if ability_value("next_draw_bonus") > 0:
		var n3 := draw_to_board(ability_value("next_draw_bonus"))
		_log("过热：额外补 %d 字" % n3)
		abilities.erase("next_draw_bonus")
	if ability_value("next_diagonal") > 0:
		abilities.erase("next_diagonal")

func begin_player_turn(draw: bool = true) -> void:
	turn += 1
	player.clear_block()
	player.temp_funds = 0
	words_played_this_turn.clear()
	attack_words_this_turn = 0
	drawn_this_turn = 0
	consumed_this_turn.clear()
	damage_taken_last_turn = 0
	damage_dealt_this_turn = 0
	bounty_paid = false
	bounty_reward = 0
	abilities.erase("_repeat_used")
	# 每回合重置“下一词”类标记（持续能力与 _overflow_paid 保留）
	for k in abilities.keys():
		if str(k).begins_with("next_"):
			abilities.erase(k)
	if has_ability("heat_overload_bonus_armed") and not has_ability("heat_overload_bonus"):
		abilities["heat_overload_bonus"] = 1
	if draw:
		var vigor := ability_value("vigor_next")
		abilities.erase("vigor_next")
		var amount: int = max(0, rules.turn_draw - base_draw_penalty - next_draw_penalty) + vigor
		next_draw_penalty = 0
		if vigor > 0:
			_log("精力：本回合基础补字 +%d" % vigor)
		draw_to_board(amount)
	abilities.erase("split_mind")
	abilities.erase("profit_share")
	repeat_armed = has_ability("repeat")
	_tick_player_statuses()
	_log("—— 第 %d 回合 ——" % turn)
	EventBus.turn_ended.emit(turn)

func _tick_player_statuses() -> void:
	var poison := player.status_stacks("poison")
	if poison > 0:
		var real := player.take_damage(poison)
		_log("中毒：失去 %d 生命" % real)
	for sid in ["vulnerable", "poison"]:
		if player.status_stacks(sid) > 0:
			var sd: StatusData = Database.get_status(sid)
			if sd != null and sd.decay_per_turn > 0:
				player.add_status(sid, -sd.decay_per_turn)

func end_player_turn() -> void:
	# 蓄能：回合结束若仍有可用多字词留在盘上
	if has_ability("energy_idle") and _has_any_word_on_board():
		add_energy(ability_value("energy_idle", 1))
		_log("蓄能：储能 +%d" % ability_value("energy_idle", 1))

	_log("玩家结束回合")
	for e in enemies:
		if not e.is_alive():
			continue
		_enemy_act(e)
		if not player.is_alive():
			break

	# 持续能力：护甲（把部分临挡转持久盾）
	if has_ability("convert_block") and player.block > 0:
		var pct := ability_value("convert_block", 50)
		var conv: int = int(floor(player.block * pct / 100.0))
		player.add_persistent_block(conv)
		if conv > 0:
			_log("护甲：将 %d 点临挡转为持久盾" % conv)

	# 后置结算：反击
	if player.is_alive():
		_resolve_counter()
	# 临时格挡默认敌行动后清除
	player.clear_block()
	player.temp_funds = 0

	if player.is_alive() and not is_over():
		begin_player_turn(true)

func _resolve_counter() -> void:
	var stacks := ability_value("counter")
	if stacks <= 0:
		return
	var dmg: int = player.block + 3 * stacks
	var target := first_alive_enemy()
	if target != null and dmg > 0:
		var real := target.take_damage(dmg)
		_log("反击：造成 %d 伤害" % real)
	abilities.erase("counter")

func _enemy_act(e: Combatant) -> void:
	var ed: EnemyData = e.enemy_data
	if ed == null or ed.moves.is_empty():
		return
	var mv: EnemyMoveData = ed.moves[e.move_index % ed.moves.size()]
	enemy_acting.emit(e, mv)
	e.move_index += 1
	var immune := has_ability("ceasefire") and damage_dealt_this_turn <= 0
	var split := has_ability("split_mind")
	match mv.kind:
		EnemyMoveData.Kind.ATTACK, EnemyMoveData.Kind.MULTI:
			var hits: int = mv.hits if mv.kind == EnemyMoveData.Kind.MULTI else 1
			for i in hits:
				var dmg := mv.damage + e.status_stacks("strength")
				if immune:
					dmg = 0
				if split:
					var real_s := e.take_damage(max(0, dmg))
					_log("精分：%s 攻击了自己，造成 %d 伤害" % [e.display_name, real_s])
				else:
					var before := player.hp
					var real := player.take_damage(max(0, dmg))
					damage_taken_last_turn += (before - player.hp)
					if immune:
						_log("停火：免疫 %s 的攻击" % e.display_name)
					else:
						_log("%s 攻击，造成 %d 伤害" % [e.display_name, real])
		EnemyMoveData.Kind.BLOCK:
			e.add_block(mv.block)
			_log("%s 获得 %d 护盾" % [e.display_name, mv.block])
		EnemyMoveData.Kind.ATTACK_BLOCK:
			e.add_block(mv.block)
			if split:
				var real_sb := e.take_damage(max(0, mv.damage))
				_log("精分：%s 攻击了自己 %d" % [e.display_name, real_sb])
			else:
				var before2 := player.hp
				var real2 := player.take_damage(0 if immune else max(0, mv.damage))
				damage_taken_last_turn += (before2 - player.hp)
				_log("%s 攻击 %d 并获得 %d 护盾" % [e.display_name, real2, mv.block])
		EnemyMoveData.Kind.BUFF:
			e.add_status(mv.status_id, mv.status_stacks)
		EnemyMoveData.Kind.DEBUFF:
			player.add_status(mv.status_id, mv.status_stacks)
			_log("%s 施加减益 %s" % [e.display_name, mv.status_id])
		EnemyMoveData.Kind.INJECT:
			var n := inject_enemy_glyphs(mv.inject_count, mv.pollution_id)
			_log("%s 注入 %d 个污染字" % [e.display_name, n])
		EnemyMoveData.Kind.SPECIAL:
			pass

	# 灼烧：敌方每次行动后扣一层
	if e.is_alive() and e.status_stacks("burn") > 0:
		var bd := ability_value("burn_dmg", 3)
		var real_b := e.take_damage(bd)
		e.add_status("burn", -1)
		_log("灼烧：对 %s 造成 %d 伤害" % [e.display_name, real_b])
		damage_dealt_this_turn += real_b
		_check_bounty()


# ---------------------------------------------------------------- 盘面操作（供 handler 调用）

func current_intent(e: Combatant) -> EnemyMoveData:
	if e.enemy_data == null or e.enemy_data.moves.is_empty():
		return null
	return e.enemy_data.moves[e.move_index % e.enemy_data.moves.size()]

func _log(text: String) -> void:
	log.append(text)
	if log.size() > 120:
		log.pop_front()
	EventBus.log_message.emit(text)


## 战斗结束，把盘面/弃字堆中的己方与自我污染字归还永久字袋；敌方字清除。

func collect_back(owner_deck: Array) -> void:
	pass

var _spawn_pool: Array = []   ## 【分化】生长的字池缓存（BattleOps 使用）

# ---------------------------------------------------------------- 转发到 BattleOps（保持外部 API 不变）

func draw_to_board(count: int) -> int:
	return BattleOps.draw_to_board(self, count)

func _draw_one() -> bool:
	return BattleOps._draw_one(self)

func draw_one_to(pos: Vector2i) -> CharInstance:
	return BattleOps.draw_one_to(self, pos)

func ensure_bag() -> void:
	return BattleOps.ensure_bag(self)

func reveal_from_bag(count: int) -> Array:
	return BattleOps.reveal_from_bag(self, count)

func return_pending_reveal() -> void:
	return BattleOps.return_pending_reveal(self)

func take_revealed(uid: int) -> CharInstance:
	return BattleOps.take_revealed(self, uid)

func inject_enemy_glyphs(count: int, pollution_id: String) -> int:
	return BattleOps.inject_enemy_glyphs(self, count, pollution_id)

func spawn_scorch_into_bag(count: int) -> int:
	return BattleOps.spawn_scorch_into_bag(self, count)

func discard_instances() -> Array:
	return BattleOps.discard_instances(self)

func take_from_discard_by_uid(uid: int) -> CharInstance:
	return BattleOps.take_from_discard_by_uid(self, uid)

func get_discard_by_uid(uid: int) -> CharInstance:
	return BattleOps.get_discard_by_uid(self, uid)

func battle_card_counts() -> Dictionary:
	return BattleOps.battle_card_counts(self)

func apply_gravity() -> void:
	return BattleOps.apply_gravity(self)

func apply_gravity_count() -> int:
	return BattleOps.apply_gravity_count(self)

func rotate_2x2(top_left: Vector2i) -> void:
	return BattleOps.rotate_2x2(self, top_left)

func destroy_2x2(top_left: Vector2i) -> int:
	return BattleOps.destroy_2x2(self, top_left)

func cleanse_board() -> int:
	return BattleOps.cleanse_board(self)

func cleanse_scorch() -> int:
	return BattleOps.cleanse_scorch(self)

func spawn_word_neighbors(center: Vector2i, max_count: int = 4) -> Array:
	return BattleOps.spawn_word_neighbors(self, center, max_count)

func create_temp_glyph(glyph: String) -> CharInstance:
	return BattleOps.create_temp_glyph(self, glyph)

func _pick_word_glyph_for(cell: Vector2i, center: Vector2i) -> String:
	return BattleOps._pick_word_glyph_for(self, cell, center)

func _spawn_pool_pick() -> String:
	return BattleOps._spawn_pool_pick(self)

func fuse_cards(p1: Vector2i, p2: Vector2i) -> Dictionary:
	return BattleOps.fuse_cards(self, p1, p2)

func refine_pair(p1: Vector2i, p2: Vector2i) -> Dictionary:
	return BattleOps.refine_pair(self, p1, p2)

func remove_scorch_in_circulation() -> int:
	return BattleOps.remove_scorch_in_circulation(self)

func has_adjacent_empty_pair() -> bool:
	return BattleOps.has_adjacent_empty_pair(self)

func _has_any_word_on_board() -> bool:
	return BattleOps._has_any_word_on_board(self)
