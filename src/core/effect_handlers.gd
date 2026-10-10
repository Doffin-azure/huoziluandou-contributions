extends RefCounted
class_name EffectHandlers
## V0.2 逐词效果处理器。每个 handler id 对应一个可测试的小规则。
## 未定稿的词没有 handler，由 UI 提示“待定”，不会悄悄套通用数值。

const CREMATE_FLAVOR := [
	"……走好。",
	"烧得很干净。",
	"这词到底有什么用？",
	"尘归尘，土归土。",
	"至少它很上镜。",
	"建议配合【热】一起使用（开玩笑的）。",
	"亡者安息。",
]

static func run(handler: String, eff: EffectData, ctx: Dictionary) -> Array:
	var b: BattleState = ctx.get("battle")
	if b == null:
		return []
	var src: Combatant = ctx.get("source")
	var enemy := _enemy(b, ctx)
	var g: int = (ctx.get("glyphs", []) as Array).size()
	var extra: int = max(0, g - 2)
	var amount: int = eff.amount + eff.amount_per_extra_glyph * extra

	match handler:
		"damage":
			return _dmg(b, enemy, amount)
		"damage_all":
			var out: Array = []
			for e in b.alive_enemies():
				out.append_array(_dmg(b, e, amount))
			return out
		"block_temp":
			src.add_block(amount)
			return ["获得 %d 点临时格挡" % amount]
		"block_persist":
			src.add_persistent_block(amount)
			return ["获得 %d 点持久盾" % amount]
		"heal":
			src.heal(amount)
			return ["回复 %d 点生命" % amount]
		"draw_random":
			var n := b.draw_to_board(amount)
			return ["随机补 %d 字" % n]
		"draw_penalty_next":
			b.next_draw_penalty += amount
			return ["下次补字 -%d" % amount]
		"gold":
			_add_gold(b, amount)
			return ["获得 %d 金币（本战累计 %d）" % [amount, b.gold_earned]]
		"temp_funds":
			src.temp_funds += amount
			return ["获得 %d 临时资金（本回合有效）" % amount]
		"energy":
			b.add_energy(amount)
			return ["储能 +%d（当前 %d）" % [amount, src.energy]]
		"heat":
			if amount >= 0:
				b.add_heat(amount)
				return ["热度 +%d（当前 %d/%d）" % [amount, src.heat, src.heat_capacity]]
			else:
				src.add_heat(amount)
				return ["热度 %d（当前 %d）" % [amount, src.heat]]
		"heat_clear":
			var lost := src.heat
			src.heat = 0
			return ["清空热度（-%d）" % lost]
		"apply_status_self":
			src.add_status(eff.status_id, amount if amount != 0 else 1)
			return ["获得状态 %s" % eff.status_id]
		"apply_status_enemy":
			if enemy != null:
				enemy.add_status(eff.status_id, amount if amount != 0 else 1)
				return ["使敌人获得 %s" % eff.status_id]
			return []
		"permanent_damage_reduction":
			if GameState.permanent_damage_reduction <= 0:
				GameState.permanent_damage_reduction = amount
				return ["获得永久能力：每次实际生命伤害 -%d" % amount]
			return ["防御力已生效，不重复叠加"]
		"permanent_gold_growth":
			if GameState.gold_growth_percent <= 0:
				GameState.gold_growth_percent = amount
				return ["获得永久能力：每场胜利后金币 +%d%%" % amount]
			return ["复利投资已生效"]

		# --- 防反 ---
		"ability_prevent_interference":
			b.enable_ability("prevent_interference", amount)
			return ["防护：抵消下一次敌方盘面干扰"]
		"ability_convert_block":
			b.enable_ability("convert_block", int(eff.args.get("percent", 50)))
			return ["护甲：回合结束把临挡转为持久盾"]
		"counter":
			b.enable_ability("counter", b.ability_value("counter") + (amount if amount != 0 else 1))
			return ["反击：预留 %d 层" % (amount if amount != 0 else 1)]
		"shield_smash":
			var dmg2: int = amount
			var per: int = int(eff.args.get("per", 2))
			var bonus: int = int(eff.args.get("bonus", 3))
			if per > 0:
				dmg2 += int(floor(src.persistent_block / per)) * bonus
			src.persistent_block = 0
			return _dmg(b, enemy, dmg2) + ["盾击消耗全部持久盾"]
		"break_shield_damage":
			var out2: Array = []
			if enemy == null:
				return out2
			var dmg3: int = amount
			var broke := false
			if enemy.block > 0:
				var mult: int = int(eff.args.get("mult", 2))
				var absorbed: int = min(enemy.block, dmg3 * mult)
				enemy.block -= absorbed
				var leftover: int = int(ceil((dmg3 * mult - absorbed) / float(mult)))
				if enemy.block <= 0:
					broke = true
				dmg3 = leftover
			if dmg3 > 0:
				out2.append_array(_dmg(b, enemy, dmg3))
			else:
				out2.append("击破：拆掉护盾")
			if broke:
				var n3 := b.draw_to_board(int(eff.args.get("draw", 1)))
				out2.append("击破护盾：补 %d 字" % n3)
			return out2
		"remove_enemy_block":
			if enemy != null:
				var removed := enemy.block
				enemy.block = 0
				return ["移除敌方 %d 点护盾" % removed]
			return []
		"conditional_draw_after_attack":
			if b.attack_words_this_turn > 0:
				var n4 := b.draw_to_board(amount)
				return ["连招奖励：补 %d 字" % n4]
			return ["（此前无即时攻击，未补字）"]
		"conditional_draw_half_hp":
			var low: bool = src.hp * 2 < src.max_hp
			var n5 := b.draw_to_board(int(eff.args.get("low", amount)) if low else int(eff.args.get("high", 1)))
			return ["反超：%s，补 %d 字" % ["低血" if low else "常态", n5]]

		# --- 连携 / 空间 ---
		"gravity":
			b.apply_gravity()
			return ["全盘向下重力"]
		"gravity_damage":
			var moved := b.apply_gravity_count()
			var dmg4: int = amount + int(eff.args.get("per", 2)) * moved
			return _dmg(b, enemy, dmg4) + ["重力移动 %d 枚字块" % moved]
		"merge_duplicates":
			return _merge_duplicates(b, ctx)
		"replay_last_attack":
			return _replay_last_attack(b)
		"ability_shared_attack":
			b.enable_ability("shared_attack", amount)
			return ["合击：本回合攻击词共享【击】，每词 +%d 伤" % amount]
		"rotate_2x2":
			var tile := _tile(ctx)
			b.rotate_2x2(tile)
			return ["回转 2×2"]
		"destroy_2x2":
			var tile2 := _tile(ctx)
			var destroyed := b.destroy_2x2(tile2)
			var dmg5: int = amount * destroyed
			return _dmg(b, enemy, dmg5) + ["爆破摧毁 %d 枚字块" % destroyed]
		"ability_diagonal_next":
			b.enable_ability("next_diagonal", 1)
			return ["流利：下一次组词允许一步对角线（原型：仅记录）"]

		# --- 流转 ---
		"recover_consumed":
			return _recover_consumed(b, ctx)
		"cleanse_all":
			var cn := b.cleanse_board()
			return ["清洗：净化 %d 枚字的污染标记" % cn]
		"cleanse_adjacent":
			return _cleanse_adjacent(b, ctx)
		"ability_flow":
			b.enable_ability("flow", amount)
			return ["流转：本回合每 2 种不同多字词补 %d 字" % amount]
		"ability_compound_next":
			b.enable_ability("next_compound", amount)
			return ["复合：下一次长词保留临时层（原型占位）"]

		# --- 蓄放 ---
		"ability_energy_idle":
			b.enable_ability("energy_idle", amount)
			return ["蓄能：回合结束若有可用多字词，储能 +%d" % amount]
		"energy_around_tail":
			var tail_n: int = int(ctx.get("tail_neighbors_own", 0))
			var total: int = amount + tail_n
			b.add_energy(total)
			return ["蓄电：储能 +%d（基础 %d + 词尾周围 %d）" % [total, amount, tail_n]]
		"energy_discharge":
			var spent: int = src.energy
			src.energy = 0
			var msgs: Array = []
			if spent > 0:
				msgs.append_array(_dmg(b, enemy, amount * spent))
			msgs.append("放电：消耗 %d 储能，每点 %d 伤" % [spent, amount])
			if int(eff.args.get("draw_per", 0)) > 0:
				var n6 := b.draw_to_board(spent * int(eff.args.get("draw_per", 1)))
				msgs.append("充放电：补 %d 字" % n6)
			return msgs

		# --- 热暴 ---
		"ability_heat_overload_bonus":
			b.enable_ability("heat_overload_bonus", amount)
			b.enable_ability("heat_overload_bonus_armed", 1)
			return ["过热：本回合首次溢热后，下一次多字词额外补 %d 字" % amount]
		"ability_accel":
			b.enable_ability("accel", amount)
			return ["加速：本回合每次多字词补 1 字并升温 1"]
		"ability_rapid_next":
			b.enable_ability("next_rapid", amount)
			b.enable_ability("next_rapid_heat", int(eff.args.get("heat", 0)))
			return ["急速：下一次多字词后补至多 %d 字" % amount]
		"ability_double_draw_next":
			b.enable_ability("next_double_draw", amount)
			return ["超速：本回合下一次补字最多额外 %d 字" % amount]
		"heat_burst":
			var heat_spent: int = src.heat
			src.heat = 0
			var dmg6: int = amount + int(eff.args.get("per", 4)) * heat_spent
			return _dmg(b, enemy, dmg6) + ["火爆：消耗 %d 热度" % heat_spent]
		"heat_cleanse":
			src.add_heat(-amount)
			var sc := b.cleanse_scorch()
			return ["清热：热度 -%d，清除 %d 处灼热" % [amount, sc]]
		"heat_to_damage_flow":
			var maxh: int = int(eff.args.get("max", 4))
			var reduce: int = min(maxh, b.drawn_this_turn)
			src.add_heat(-reduce)
			var dmg7: int = amount * reduce
			return _dmg(b, enemy, dmg7) + ["热流：降热 %d" % reduce]
		"ability_reload":
			src.heat_capacity += amount
			b.base_draw_penalty += int(eff.args.get("draw_penalty", 1))
			return ["重载：热容 +%d，此后每回合补字 -%d" % [amount, int(eff.args.get("draw_penalty", 1))]]
		"ability_overfire":
			b.enable_ability("next_overfire", 1)
			src.add_heat(int(eff.args.get("heat", 2)))
			b.enable_ability("next_overfire_per", int(eff.args.get("per", 3)))
			return ["过火：下一次攻击附加热度×%d 伤" % int(eff.args.get("per", 3))]
		"ability_electric_overload":
			b.enable_ability("electric_overload", amount)
			return ["电流过载：本战每次溢热生成热字并 +储能/+伤害"]

		# --- 经济 ---
		"spend_gold_damage":
			var maxg: int = int(eff.args.get("max", 3))
			var pay: int = min(_available(b), maxg)
			_pay(b, pay)
			return _dmg(b, enemy, amount * pay) + ["投币：支付 %d（临时资金优先）" % pay]
		"capture_glyph":
			return _capture_glyph(b, ctx, amount)
		"reveal_place":
			return _reveal_place(b, ctx, amount)
		"replace_self":
			return _replace_self(b, ctx)
		"transform_board":
			return _transform_board(b, ctx)
		"split_grow":
			return _split_grow(b, ctx)
		"empower_glyph":
			return _empower_glyph(b, ctx)
		"refine_remove":
			return _refine_remove(b, ctx, eff)
		"cremate":
			return _cremate(b, ctx, eff)
		"fuse_cards":
			return _fuse_cards(b, ctx)
		"refine_layer":
			return _refine_layer(b, ctx)
		"gild_glyph":
			return _gild_glyph(b, ctx)
		"precision_place":
			return _precision_place(b, ctx, eff)
		"split_mind":
			return _split_mind(b)
		"vigor":
			return _vigor(b)
		"blackout":
			b.blackout_requested = true
			return ["停电了……（拖动连出「开灯」恢复）"]
		"lights_on":
			return ["来电了。"]
		"charge_overheat":
			return _charge_overheat(b, eff)
		"recast_board":
			return _recast_board(b)
		"recast_copy":
			return _recast_copy(b, ctx)
		"repeat_last":
			return _repeat_last(b, ctx)
		"reverse_line":
			return _reverse_line(b, ctx)
		"merge_flow":
			return _merge_flow(b, ctx)
		"hard_stop":
			return _hard_stop(b)
		"repeat_word":
			return _repeat_word(b)
		"fireproof":
			return _simple_ability(b, "fireproof", "防火：本场自己打出的灼热【热】不再扣血")
		"blastproof":
			return _simple_ability(b, "blastproof", "防爆：本场被摧毁的己方字改为回字袋并获得持久盾")
		"joint_funding":
			return _simple_ability(b, "joint_funding", "合资：本场支付金币时可用 2 储能抵 1 金币（可混合）")
		"profit_share":
			return _simple_ability(b, "profit_share", "分利：本回合每当实际获得金币，同时获得等量储能")
		"suspend":
			return _suspend(b)

		# ---- 蓄放进阶 ----
		"energy_to_bonus":
			var spent_e: int = src.energy
			src.energy = 0
			b.abilities["next_energy_bonus"] = int(b.abilities.get("next_energy_bonus", 0)) + spent_e * int(eff.args.get("per", 2))
			return ["蓄力：消耗 %d 储能，下一次攻击 +%d 伤" % [spent_e, spent_e * int(eff.args.get("per", 2))]]
		"energy_to_heat_damage":
			var spent_e2: int = src.energy
			src.energy = 0
			b.add_heat(spent_e2)
			return _dmg(b, enemy, int(eff.args.get("per", 2)) * spent_e2) + ["放热：储能 %d 转为热度" % spent_e2]
		"heat_to_energy":
			var h2e: int = src.heat
			src.heat = 0
			b.add_energy(h2e)
			return ["热能：热度 %d 转为储能" % h2e]
		"heat_to_bonus":
			var h2b: int = src.heat
			src.heat = 0
			src.add_status("next_bonus", h2b * int(eff.args.get("per", 2)))
			return ["热力：热度 %d 转为下一次攻击强化" % h2b]
		"flow_energy_or_draw":
			if b.drawn_this_turn > 0:
				b.add_energy(amount)
				return ["电流：本回合已补字，储能 +%d" % amount]
			var ncf := b.draw_to_board(amount)
			return ["电流：补 %d 字" % ncf]
		"ability_gravity_always":
			b.enable_ability("gravity_always", 1)
			return ["重力：本战每次有效出字后自动全盘下落"]

		# ---- 经济 / 股权 ----
		"invest_equity":
			if _available(b) < amount:
				return ["投资：支付额不足（需 %d）" % amount]
			_pay(b, amount)
			var eq: int = amount
			if b.has_ability("compound_equity"):
				eq += 1
				b.abilities.erase("compound_equity")
			src.equity += eq
			return ["投资：锁定 %d 金币为 %d 股权（当前 %d）" % [amount, eq, src.equity]]
		"compound_equity":
			b.enable_ability("compound_equity", amount)
			return ["复利：本回合首次存股权额外 +1"]
		"equity_interest":
			if src.equity < 2:
				return ["利息：需持有至少 2 股权（当前 %d）" % src.equity]
			src.equity -= 1
			_add_gold(b, 2)
			var nint := b.draw_to_board(1)
			return ["利息：消耗 1 股权，+2 金币，补 %d 字" % nint]
		"alchemy":
			var spent_eq: int = src.equity
			src.equity = 0
			_add_gold(b, spent_eq * int(eff.args.get("per", 3)))
			var nalc := b.draw_to_board(spent_eq)
			return ["炼金：消耗 %d 股权，+%d 金币，补 %d 字" % [spent_eq, spent_eq * int(eff.args.get("per", 3)), nalc]]
		"pure_gold":
			var tf: int = src.temp_funds
			src.temp_funds = 0
			_add_gold(b, tf)
			return ["纯金：临时资金 %d 转为正式金币" % tf]
		"alloy":
			src.add_persistent_block(amount)
			_add_gold(b, int(eff.args.get("gold", 2)))
			return ["合金：获得 %d 持久盾与 %d 金币" % [amount, int(eff.args.get("gold", 2))]]
		"mint":
			_add_gold(b, amount)
			var cd_mint: CharacterData = Database.get_character_by_glyph("币")
			var path_m: Array = ctx.get("path", [])
			if cd_mint != null and not path_m.is_empty():
				var pos_m: Vector2i = path_m[path_m.size() - 1]
				if b.board.get_xy(pos_m) == null:
					var inst_m := CharInstance.new(cd_mint)
					inst_m.owner = CharInstance.Owner.SELF_GENERATED
					b.board.set_xy(pos_m, inst_m)
					b.temp_chars.append(inst_m)
			return ["铸币：+%d 金币并生成临时【币】" % amount]
		"reinvest":
			var lock: int = min(GameState.gold, int(eff.args.get("max", 6)))
			if lock <= 0:
				return ["再投资：没有可锁定的金币"]
			GameState.add_gold(-lock)
			GameState.reinvest_gold += lock
			return ["再投资：锁定 %d 金币，下战胜利返还 %d" % [lock, lock * 2]]
		"bounty":
			var bcost: int = int(eff.args.get("cost", 5))
			if not _pay(b, bcost):
				return ["重金：支付额不足（需 %d）" % bcost]
			b.bounty_paid = true
			b.bounty_reward = amount
			return ["重金：悬赏 %d，本回合击杀后返还" % amount]

		# ---- 热暴 P3 ----
		"cold_snap":
			var dmg_c: int = amount + int(eff.args.get("per", 2)) * b.damage_taken_last_turn
			src.heat = 0
			return _dmg(b, enemy, dmg_c) + ["爆冷：清空热度"]
		"ceasefire":
			b.enable_ability("ceasefire", 1)
			return ["停火：本回合未造成敌伤则免疫敌方攻击"]
		"ignite":
			if enemy != null:
				var burn_dmg: int = amount + src.heat
				enemy.add_status("burn", 2)
				b.abilities["burn_dmg"] = burn_dmg
				return ["放火：敌方灼烧 2 次，每次 %d 伤" % burn_dmg]
			return []

		# ---- 连携 P3 ----
		"electric_strike":
			return _dmg(b, enemy, amount + int(eff.args.get("per", 2)) * src.energy)
		"fire_power":
			return _dmg(b, enemy, amount + int(eff.args.get("per", 2)) * src.heat)
		"joint_force":
			src.add_block(amount)
			b.add_energy(int(eff.args.get("energy", 2)))
			return ["合力：获得 %d 临挡与 %d 储能" % [amount, int(eff.args.get("energy", 2))]]
		"serial":
			b.enable_ability("serial", int(eff.args.get("bonus", 6)))
			return ["连载：本战每 3 种不同多字词强化下一次攻击"]
		"repeat_zero":
			b.enable_ability("repeat_zero", 1)
			return ["反复：本回合首次无效果单字出牌时原位补 1 字"]

		# ---- 流转 P3 ----
		"divert":
			var tile_d: Vector2i = _tile(ctx)
			var nd := 0
			for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var c_d: CharInstance = b.board.get_xy(tile_d + off)
				if c_d != null and not c_d.pollutions.is_empty():
					c_d.clear_pollutions()
					nd += 1
			return ["分流：净化所选区域 %d 处污染" % nd]
		"clear_flow":
			var sc2 := b.cleanse_scorch()
			var ncf2 := b.draw_to_board(amount)
			return ["清流：清除 %d 处灼热，补 %d 字" % [sc2, ncf2]]
		"buyback":
			var cost_bb: int = int(eff.args.get("cost", 3))
			if b.consumed_this_turn.is_empty():
				return ["回购：本回合没有消耗过字"]
			if not _pay(b, cost_bb):
				return ["回购：支付额不足（需 %d）" % cost_bb]
			var idx_bb: int = int(ctx.get("target", {}).get("discard_index", b.consumed_this_turn.size() - 1))
			idx_bb = clampi(idx_bb, 0, b.consumed_this_turn.size() - 1)
			var inst_bb: CharInstance = b.consumed_this_turn[idx_bb]
			b.consumed_this_turn.remove_at(idx_bb)
			b.bag.append(inst_bb)
			return ["回购：支付 %d 金币，回收【%s】到袋顶" % [cost_bb, inst_bb.glyph()]]

	return ["（未实现的效果 %s）" % handler]


# ---------------------------------------------------------------- helpers
static func _enemy(b: BattleState, ctx: Dictionary) -> Combatant:
	var idx: int = int(ctx.get("target_index", 0))
	var alive := b.alive_enemies()
	if alive.is_empty():
		return null
	return alive[clampi(idx, 0, alive.size() - 1)]


static func _dmg(b: BattleState, target: Combatant, amount: int) -> Array:
	if target == null:
		return ["（无目标）"]
	var real := b.deal_damage(target, amount, true)
	return ["造成 %d 点伤害" % real]


static func _tile(ctx: Dictionary) -> Vector2i:
	var t: Dictionary = ctx.get("target", {})
	return t.get("tile", Vector2i.ZERO)


static func _add_gold(b: BattleState, amount: int) -> void:
	b.earn_gold(amount)


## 可用支付额 = 临时资金 + 金币（“资金”可直接用于经济效果）
static func _available(b: BattleState) -> int:
	var avail: int = b.player.temp_funds + GameState.gold
	if b.has_ability("joint_funding"):
		avail += int(b.player.energy / 2)
	return avail


## 先花临时资金，再（合资）用 2 储能抵 1 金币，最后花金币。成功返回 true。
static func _pay(b: BattleState, cost: int) -> bool:
	if cost < 0 or _available(b) < cost:
		return false
	var from_temp: int = mini(b.player.temp_funds, cost)
	b.player.temp_funds -= from_temp
	var remain: int = cost - from_temp
	if remain > 0 and b.has_ability("joint_funding"):
		var sub: int = mini(int(b.player.energy / 2), remain)
		b.player.energy -= sub * 2
		remain -= sub
	if remain > 0:
		GameState.add_gold(-remain)
	return true


static func _merge_duplicates(b: BattleState, ctx: Dictionary) -> Array:
	var anchor: Vector2i = _tile(ctx)
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
	var tile: Vector2i = _tile(ctx)
	var n := 0
	for pos in [tile] + b.board.neighbors(tile):
		var c: CharInstance = b.board.get_xy(pos)
		if c != null and not c.pollutions.is_empty():
			c.clear_pollutions()
			n += 1
	return ["清：净化 %d 处污染（所有权不变）" % n]


static func _capture_glyph(b: BattleState, ctx: Dictionary, cost: int) -> Array:
	var tile: Vector2i = ctx.get("target", {}).get("enemy_glyph", _tile(ctx))
	var inst: CharInstance = b.board.get_xy(tile)
	if inst == null or not inst.is_enemy_owned():
		return ["收购：请选择一枚敌方实体字"]
	if not _pay(b, cost):
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
	_add_gold(b, gold_up)
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


static func _precision_place(b: BattleState, ctx: Dictionary, eff: EffectData) -> Array:
	var cost: int = eff.amount
	var tile: Vector2i = _tile(ctx)
	if b.board.get_xy(tile) != null:
		return ["精铸：目标格已被占用"]
	if _available(b) < cost:
		return ["精铸：支付额不足（需 %d）" % cost]
	var uid: int = int(ctx.get("target", {}).get("place_uid", -1))
	var inst: CharInstance = b.take_from_discard_by_uid(uid)
	if inst == null:
		return ["精铸：请选择弃字堆中的一枚己方字"]
	_pay(b, cost)
	inst.owner = CharInstance.Owner.PLAYER
	b.board.set_xy(tile, inst)
	return ["精铸：支付 %d，将【%s】放入指定空格" % [cost, inst.glyph()]]


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
	var tile: Vector2i = _tile(ctx)
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
	b.player.heat = 0
	var removed := b.remove_scorch_in_circulation()
	b.end_turn_requested = true
	return ["急停：清空热度，移除 %d 枚未打出的灼热【热】；立即结束出字阶段" % removed]


static func _repeat_word(b: BattleState) -> Array:
	b.enable_ability("repeat", 1)
	return ["重复：开启，每回合第一次多字词将再执行一次"]


static func _simple_ability(b: BattleState, id: String, msg: String) -> Array:
	b.enable_ability(id, 1)
	return [msg]


static func _suspend(b: BattleState) -> Array:
	var h: int = b.player.heat
	b.player.heat = 0
	b.player.add_persistent_block(h * 2)
	b.end_turn_requested = true
	return ["停息：清零 %d 热度，获得 %d 持久盾；立即结束出字阶段" % [h, h * 2]]


static func _split_grow(b: BattleState, ctx: Dictionary) -> Array:
	var tile: Vector2i = _tile(ctx)
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
	var tile: Vector2i = _tile(ctx)
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
	var tile: Vector2i = _tile(ctx)
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
	var tile: Vector2i = _tile(ctx)
	if b.board.get_xy(tile) != null:
		return ["投放：目标格已被占用"]
	if b.bag.is_empty() and b.discard.is_empty():
		return ["投放：字袋为空"]
	if not _pay(b, cost):
		return ["投放：支付额不足（需 %d）" % cost]
	if b.bag.is_empty():
		b.bag = b.discard.duplicate()
		b.discard.clear()
		b._shuffle(b.bag)
	var inst: CharInstance = b.bag.pop_back()
	b.board.set_xy(tile, inst)
	return ["投放：支付 %d 金币，落下【%s】" % [cost, inst.glyph()]]
