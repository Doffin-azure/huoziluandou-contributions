extends RefCounted
class_name EffectHandlers
## 词效调度器：按 EffectData.handler 分发。
## 复杂实现见 EffectHandlersActions；共享工具见 EffectUtil。

static func run(handler: String, eff: EffectData, ctx: Dictionary) -> Array:
	var b: BattleState = ctx.get("battle")
	if b == null:
		return []
	var src: Combatant = ctx.get("source")
	var enemy := EffectUtil.enemy(b, ctx)
	var g: int = (ctx.get("glyphs", []) as Array).size()
	var extra: int = max(0, g - 2)
	var amount: int = eff.amount + eff.amount_per_extra_glyph * extra

	match handler:
		"damage":
			return EffectUtil.damage(b, enemy, amount)
		"overdo":
			b.overdo_count += 1
			var overdo_dmg: int = amount * b.overdo_count
			return EffectUtil.damage(b, enemy, overdo_dmg) + ["过分：第 %d 次，共 %d 伤" % [b.overdo_count, overdo_dmg]]
		"damage_all":
			var out: Array = []
			b.begin_attack_sequence()
			for e in b.alive_enemies():
				out.append_array(EffectUtil.damage(b, e, amount))
			b.end_attack_sequence()
			return out
		"block_temp":
			src.add_block(amount)
			return ["获得 %d 点临时格挡" % amount]
		"block_persist":
			src.add_persistent_block(amount)
			return ["获得 %d 点持久盾" % amount]
		"guard_reduce":
			src.turn_damage_reduction += amount
			return ["御：本回合每次受伤 -%d" % amount]
		"guard_halve":
			src.turn_damage_halve = true
			return ["放心：本回合受到伤害减半（向上取整，再 -1）"]
		"ability_warm_heart":
			b.enable_ability("warm_heart", 1)
			return ["热心：本场持续——每获得 1 热度回复 1 生命，每失去 1 热度扣 1 生命"]
		"ability_strong_heart":
			b.enable_ability("strong_heart", 1)
			return ["强心：本场持续——每回合回复已触发心力层数的生命"]
		"collect_own":
			return EffectHandlersActions._collect_own(b, ctx)
		"cold_heart":
			src.turn_damage_double = true
			src.no_block_turns = 2
			return ["冷心：本回合伤害翻倍；接下来 2 回合不能获得防御"]
		"cleanse_status":
			var removed: Array = []
			for sid in src.statuses.keys():
				var sd: StatusData = Database.get_status(str(sid))
				if sd != null and sd.kind == StatusData.Kind.DEBUFF:
					removed.append(sd.name)
					src.statuses.erase(sid)
			if removed.is_empty():
				return ["清心：没有可清除的负面状态"]
			return ["清心：清除了 %s" % ", ".join(removed)]
		"ability_armor_plating":
			b.enable_ability("armor_plating", 1)
			return ["甲：每回合获得 1 点格挡，格挡被击穿则碎裂"]
		"ability_guard_inject":
			b.enable_ability("guard_inject", b.ability_value("guard_inject") + amount)
			return ["护：下次敌方塞字减少 %d 个" % amount]
		"heal":
			src.heal(amount)
			return ["回复 %d 点生命" % amount]
		"draw_random":
			var n := b.draw_to_board(amount)
			return ["随机补 %d 字" % n]
		"draw_penalty_next":
			b.next_draw_penalty += amount
			return ["下次补字 -%d" % amount]
		"draw_bonus_next":
			b.next_draw_penalty -= amount
			return ["下回合多抽 %d 字" % amount]
		"manual_draw_next":
			b.next_draw_penalty += amount
			b.enable_ability("manual_draw", 1)
			return ["精心：下回合补字 -%d，但可从字袋定向选字（随机落地）" % amount]
		"gold":
			EffectUtil.add_gold(b, amount)
			return ["获得 %d 金币（本战累计 %d）" % [amount, b.gold_earned]]
		"temp_funds":
			src.temp_funds += amount
			return ["获得 %d 临时资金（本回合有效）" % amount]
		"energy":
			b.add_energy(amount)
			return ["储能 +%d（当前 %d）" % [amount, src.energy]]
		"heat":
			b.add_heat(amount)
			if amount >= 0:
				return ["热度 +%d（当前 %d/%d）" % [amount, src.heat, src.heat_capacity]]
			return ["热度 %d（当前 %d）" % [amount, src.heat]]
		"heat_clear":
			var lost := src.heat
			b.clear_heat()
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
			return EffectUtil.damage(b, enemy, dmg2) + ["盾击消耗全部持久盾"]
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
				out2.append_array(EffectUtil.damage(b, enemy, dmg3))
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
		"gravity_left":
			b.apply_gravity_left()
			return ["全盘向左重力"]
		"gravity_right":
			b.apply_gravity_right()
			return ["全盘向右重力"]
		"gravity_damage":
			var moved := b.apply_gravity_count()
			var dmg4: int = amount + int(eff.args.get("per", 2)) * moved
			return EffectUtil.damage(b, enemy, dmg4) + ["重力移动 %d 枚字块" % moved]
		"merge_duplicates":
			return EffectHandlersActions._merge_duplicates(b, ctx)
		"replay_last_attack":
			return EffectHandlersActions._replay_last_attack(b)
		"replay_word":
			return EffectHandlersActions._replay_word(b)
		"return_enemy":
			return EffectHandlersActions._return_enemy(b, ctx)
		"ability_shared_attack":
			b.enable_ability("shared_attack", 1)
			b.begin_formation()
			return ["合击：进入结阵——之后打出的词只登记，点「发动」一起结算（多词可共享同一枚【击】）"]
		"rotate_2x2":
			var tile := EffectUtil.tile(ctx)
			b.rotate_2x2(tile)
			return ["回转 2×2"]
		"shift_row":
			var row := int((ctx.get("target", {}) as Dictionary).get("row", -1))
			var sdir := int(eff.args.get("dir", -1))
			b.shift_row(row, sdir)
			return ["第 %d 行向%s循环移动一格" % [row + 1, "左" if sdir < 0 else "右"]]
		"rotate_3x3":
			var a3 := EffectUtil.tile(ctx)
			var rdir := int(eff.args.get("dir", 1))
			b.rotate_3x3(a3, rdir)
			return ["3×3 区域%s旋转 90°" % ("顺时" if rdir > 0 else "逆时")]
		"swap_cells":
			var tt: Dictionary = ctx.get("target", {})
			b.swap_cells(tt.get("tile", Vector2i.ZERO), tt.get("tile2", Vector2i.ZERO))
			return ["交换两格"]
		"overcool":
			b.clear_heat()
			b.enable_ability("next_heat_to_block", 2)
			return ["过冷：热量清零；下次获得的热度转为每点 +2 持久盾"]
		"rotate_repeat":
			var rt := EffectUtil.tile(ctx)
			b.start_repeat_rotate(rt)
			return ["转速：旋转一次（可继续「发动」，最多 3 次）"]
		"reshuffle_line":
			return EffectHandlersActions._reshuffle_line(b, ctx)
		"place_two":
			return EffectHandlersActions._place_two(b, ctx)
		"recover_two":
			return EffectHandlersActions._recover_two(b, ctx)
		"ability_longword_draw":
			return EffectUtil.simple_ability(b, "longword_draw", "能力：本场持续——每打出 3 字及以上的词，额外补 1 字")
		"ability_electric_material":
			return EffectUtil.simple_ability(b, "electric_material", "电能：本场持续——每消耗 2 储能，随机空格生成临时【电】")
		"ability_heat_to_energy":
			return EffectUtil.simple_ability(b, "heat_to_energy", "蓄热：本场持续——回合结束热度 -2，每点转 1 储能")
		"flow_row":
			var frow := int((ctx.get("target", {}) as Dictionary).get("row", -1))
			b.flow_row = frow
			return ["流速：本回合第 %d 行腾出的空格立即补回" % (frow + 1)]
		"fill_board_heat":
			var placed := 0
			while b.board.fill_count() < 12:
				if not b._draw_one():
					break
				placed += 1
			placed = b.record_draw(placed)
			if placed > 0:
				b.add_heat(placed)
			return ["火速：补至 %d 字（+%d 枚，热度 +%d）" % [12, placed, placed]]
		"next_draw_bonus_two":
			var nb2 := b.draw_to_board(2)
			return ["加急：立即多补 %d 字" % nb2]
		"overheat_shield":
			b.enable_ability("overheat_shield", 4)
			return ["蓄冷：下次过热可抵消 4 点污染【热】"]
		"heat_to_persist_block":
			var hb: int = src.heat
			b.clear_heat()
			src.add_persistent_block(hb * 2)
			return ["冷热：消耗 %d 热度，获得 %d 持久盾" % [hb, hb * 2]]
		"energy_to_heat_block":
			var e2: int = src.energy
			b.spend_energy(e2)
			b.add_heat(e2)
			src.add_block(e2 * 3)
			return ["电热：消耗 %d 储能，热度 +%d，临挡 +%d" % [e2, e2, e2 * 3]]
		"heat_to_energy_damage":
			var h2: int = int(src.heat / 2)
			b.clear_heat()
			b.add_energy(h2)
			return EffectUtil.damage(b, enemy, 5) + ["火电：热度转 %d 储能" % h2]
		"refund_energy_half":
			var half: int = int(b.last_energy_spent / 2)
			b.add_energy(half)
			return ["复电：恢复 %d 储能" % half]
		"wash_heat":
			var washed := 0
			for wi in b.board.cells.size():
				var wi_inst: CharInstance = b.board.cells[wi]
				if wi_inst != null and wi_inst.glyph() == "热":
					b.board.cells[wi] = null
					b.bag.append(wi_inst)
					washed += 1
			if washed > 0:
				b._shuffle(b.bag)
			b.add_heat(-2)
			return ["流火：洗回 %d 枚【热】，热度 -2" % washed]
		"next_copy_layer":
			return EffectUtil.simple_ability(b, "next_copy_layer", "超能：下一条 3+ 字词可消耗储能保留临时复制层")
		"double_next_ability":
			b.abilities["double_next"] = 1
			return ["超能力：本回合下一次持续能力触发结算两遍"]
		"gold_to_shield":
			return EffectUtil.simple_ability(b, "gold_to_shield", "收息：本回合每次花金币发动词效，同时获得等额持久盾")
		"inject_bounty":
			return EffectUtil.simple_ability(b, "inject_bounty", "加收：本回合敌人每注入 1 枚污染字，获得 2 金币")
		"instant_power":
			return EffectUtil.simple_ability(b, "instant_power", "电力：本场持续——行列位移后可耗 1 储能额外位移一次")
		"heat_pollution_damage":
			return EffectUtil.simple_ability(b, "heat_pollution_damage", "火热：本场持续——每枚污染【热】造成 5 伤")
		"recover_to_bag":
			return EffectHandlersActions._recover_to_bag(b, ctx)
		"move_cell":
			return EffectHandlersActions._move_cell(b, ctx)
		"destroy_2x2":
			var tile2 := EffectUtil.tile(ctx)
			var destroyed := b.destroy_2x2(tile2)
			var dmg5: int = amount * destroyed
			return EffectUtil.damage(b, enemy, dmg5) + ["爆破摧毁 %d 枚字块" % destroyed]
		"clear_board":
			var cleared := b.clear_board()
			var dmg_cb: int = amount * cleared
			return EffectUtil.damage(b, enemy, dmg_cb) + ["超重：清空字盘 %d 枚，每枚 %d 伤" % [cleared, amount]]
		"converge":
			var anchor := EffectUtil.tile(ctx)
			var moved := b.converge_to(anchor)
			return ["重心：%d 枚字向锚点聚拢" % moved]
		"ability_heart_power":
			b.enable_ability("heart_power", 1)
			return ["心力：本场持续——每打出一颗【心】叠加一层心力，可抵挡致命伤害"]
		"fill_board_full":
			var placed_fb := 0
			while b.board.fill_count() < b.board.size * b.board.size:
				if not b._draw_one():
					break
				placed_fb += 1
			placed_fb = b.record_draw(placed_fb)
			return ["心急：补满盘面（+%d 枚）" % placed_fb]
		"heart_link":
			if enemy == null:
				return ["（无目标）"]
			var avg_max := int((src.max_hp + enemy.max_hp) / 2)
			src.max_hp = avg_max
			enemy.max_hp = avg_max
			GameState.player_max_hp = avg_max
			var avg_hp := int((src.hp + enemy.hp) / 2)
			src.hp = avg_hp
			enemy.hp = avg_hp
			GameState.player_hp = avg_hp
			return ["心连心：双方生命上限与当前生命都平均为 %d（上限 %d，跨战保留）" % [avg_hp, avg_max]]
		"ability_diagonal_next":
			b.enable_ability("next_diagonal", 1)
			return ["流利：下一次组词允许一步对角线"]

		# --- 流转 ---
		"recover_consumed":
			return EffectHandlersActions._recover_consumed(b, ctx)
		"cleanse_all":
			var cn := b.cleanse_board()
			return ["清洗：净化 %d 枚字的污染标记" % cn]
		"cleanse_adjacent":
			return EffectHandlersActions._cleanse_adjacent(b, ctx)
		"ability_flow":
			b.enable_ability("flow", amount)
			return ["流转：本回合每 2 种不同多字词补 %d 字" % amount]
		"ability_compound_next":
			b.enable_ability("next_compound", amount)
			return ["复合：下一次 3 字及以上的词保留一枚临时复制"]

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
			b.spend_energy(spent)
			var msgs: Array = []
			b.begin_attack_sequence()
			for hit in spent:
				if not src.is_alive():
					break
				if enemy == null or not enemy.is_alive():
					enemy = b.first_alive_enemy()
				if enemy == null:
					break
				msgs.append_array(EffectUtil.damage(b, enemy, amount))
			b.end_attack_sequence()
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
			b.clear_heat()
			var dmg6: int = amount + int(eff.args.get("per", 4)) * heat_spent
			return EffectUtil.damage(b, enemy, dmg6) + ["火爆：消耗 %d 热度" % heat_spent]
		"heat_cleanse":
			b.add_heat(-amount)
			var sc := b.cleanse_scorch()
			return ["清热：热度 -%d，清除 %d 处灼热" % [amount, sc]]
		"heat_to_damage_flow":
			var maxh: int = int(eff.args.get("max", 4))
			var reduce: int = mini(src.heat, mini(maxh, b.drawn_this_turn))
			b.add_heat(-reduce)
			var dmg7: int = amount * reduce
			return EffectUtil.damage(b, enemy, dmg7) + ["热流：降热 %d" % reduce]
		"ability_reload":
			src.heat_capacity += amount
			b.add_heat(0)
			b.base_draw_penalty += int(eff.args.get("draw_penalty", 1))
			return ["重载：热容 +%d，此后每回合补字 -%d" % [amount, int(eff.args.get("draw_penalty", 1))]]
		"ability_overfire":
			b.enable_ability("next_overfire", 1)
			b.add_heat(int(eff.args.get("heat", 2)))
			b.enable_ability("next_overfire_per", int(eff.args.get("per", 3)))
			return ["过火：下一次攻击附加热度×%d 伤" % int(eff.args.get("per", 3))]
		"ability_electric_overload":
			b.enable_ability("electric_overload", amount)
			return ["电流过载：本战每次溢热生成热字并 +储能/+伤害"]

		# --- 经济 ---
		"spend_gold_damage":
			var maxg: int = int(eff.args.get("max", 3))
			var pay: int = min(EffectUtil.available(b), maxg)
			EffectUtil.pay(b, pay)
			return EffectUtil.damage(b, enemy, amount * pay) + ["投币：支付 %d（临时资金优先）" % pay]
		"capture_glyph":
			return EffectHandlersActions._capture_glyph(b, ctx, amount)
		"reveal_place":
			return EffectHandlersActions._reveal_place(b, ctx, amount)
		"replace_self":
			return EffectHandlersActions._replace_self(b, ctx)
		"transform_board":
			return EffectHandlersActions._transform_board(b, ctx)
		"split_grow":
			return EffectHandlersActions._split_grow(b, ctx)
		"empower_glyph":
			return EffectHandlersActions._empower_glyph(b, ctx)
		"refine_remove":
			return EffectHandlersActions._refine_remove(b, ctx, eff)
		"cremate":
			return EffectHandlersActions._cremate(b, ctx, eff)
		"fuse_cards":
			return EffectHandlersActions._fuse_cards(b, ctx)
		"refine_layer":
			return EffectHandlersActions._refine_layer(b, ctx)
		"gild_glyph":
			return EffectHandlersActions._gild_glyph(b, ctx)
		"pin_glyph":
			return EffectHandlersActions._pin_glyph(b, ctx)
		"precision_place":
			return EffectHandlersActions._precision_place(b, ctx, eff)
		"split_mind":
			return EffectHandlersActions._split_mind(b)
		"vigor":
			return EffectHandlersActions._vigor(b)
		"blackout":
			b.blackout_requested = true
			return ["停电了……（拖动连出「开灯」恢复）"]
		"lights_on":
			return ["来电了。"]
		"charge_overheat":
			return EffectHandlersActions._charge_overheat(b, eff)
		"recast_board":
			return EffectHandlersActions._recast_board(b)
		"recast_copy":
			return EffectHandlersActions._recast_copy(b, ctx)
		"recast_three":
			return EffectHandlersActions._recast_three(b, ctx)
		"repeat_last":
			return EffectHandlersActions._repeat_last(b, ctx)
		"reverse_line":
			return EffectHandlersActions._reverse_line(b, ctx)
		"merge_flow":
			return EffectHandlersActions._merge_flow(b, ctx)
		"hard_stop":
			return EffectHandlersActions._hard_stop(b)
		"repeat_word":
			return EffectHandlersActions._repeat_word(b)
		"fireproof":
			return EffectUtil.simple_ability(b, "fireproof", "防火：本场自己打出的灼热【热】不再扣血")
		"blastproof":
			return EffectUtil.simple_ability(b, "blastproof", "防爆：本场被摧毁的己方字改为回字袋并获得持久盾")
		"joint_funding":
			return EffectUtil.simple_ability(b, "joint_funding", "合资：本场支付金币时可用 2 储能抵 1 金币（可混合）")
		"profit_share":
			return EffectUtil.simple_ability(b, "profit_share", "分利：本回合每当实际获得金币，同时获得等量储能")
		"suspend":
			return EffectHandlersActions._suspend(b)

		# ---- 蓄放进阶 ----
		"energy_to_bonus":
			var spent_e: int = src.energy
			b.spend_energy(spent_e)
			b.abilities["next_energy_bonus"] = int(b.abilities.get("next_energy_bonus", 0)) + spent_e * int(eff.args.get("per", 2))
			return ["蓄力：消耗 %d 储能，下一次攻击 +%d 伤" % [spent_e, spent_e * int(eff.args.get("per", 2))]]
		"energy_to_heat_damage":
			var spent_e2: int = src.energy
			b.spend_energy(spent_e2)
			b.add_heat(spent_e2)
			return EffectUtil.damage(b, enemy, int(eff.args.get("per", 2)) * spent_e2) + ["放热：储能 %d 转为热度" % spent_e2]
		"heat_to_energy":
			var h2e: int = src.heat
			b.clear_heat()
			b.add_energy(h2e)
			return ["热能：热度 %d 转为储能" % h2e]
		"heat_to_bonus":
			var h2b: int = src.heat
			b.clear_heat()
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
			if EffectUtil.available(b) < amount:
				return ["投资：支付额不足（需 %d）" % amount]
			EffectUtil.pay(b, amount)
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
			EffectUtil.add_gold(b, 2)
			var nint := b.draw_to_board(1)
			return ["利息：消耗 1 股权，+2 金币，补 %d 字" % nint]
		"alchemy":
			var spent_eq: int = src.equity
			src.equity = 0
			EffectUtil.add_gold(b, spent_eq * int(eff.args.get("per", 3)))
			var nalc := b.draw_to_board(spent_eq)
			return ["炼金：消耗 %d 股权，+%d 金币，补 %d 字" % [spent_eq, spent_eq * int(eff.args.get("per", 3)), nalc]]
		"pure_gold":
			var tf: int = src.temp_funds
			src.temp_funds = 0
			EffectUtil.add_gold(b, tf)
			return ["纯金：临时资金 %d 转为正式金币" % tf]
		"alloy":
			src.add_persistent_block(amount)
			EffectUtil.add_gold(b, int(eff.args.get("gold", 2)))
			return ["合金：获得 %d 持久盾与 %d 金币" % [amount, int(eff.args.get("gold", 2))]]
		"mint":
			EffectUtil.add_gold(b, amount)
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
			GameState.lock_reinvestment(lock)
			return ["再投资：锁定 %d 金币，下战胜利返还 %d" % [lock, lock * 2]]
		"bounty":
			var bcost: int = int(eff.args.get("cost", 5))
			if not EffectUtil.pay(b, bcost):
				return ["重金：支付额不足（需 %d）" % bcost]
			b.bounty_paid = true
			b.bounty_reward = amount
			return ["重金：悬赏 %d，本回合击杀后返还" % amount]

		# ---- 热暴 P3 ----
		"cold_snap":
			var dmg_c: int = amount + int(eff.args.get("per", 2)) * b.damage_taken_last_turn
			b.clear_heat()
			return EffectUtil.damage(b, enemy, dmg_c) + ["爆冷：清空热度"]
		"ceasefire":
			b.enable_ability("ceasefire", 1)
			return ["停火：本回合未造成敌伤则免疫敌方攻击"]
		"ignite":
			if enemy != null:
				var burn_dmg: int = amount + src.heat
				enemy.statuses["burn"] = 2
				enemy.status_data["burn_damage"] = burn_dmg
				return ["放火：敌方灼烧 2 次，每次 %d 伤" % burn_dmg]
			return []

		# ---- 连携 P3 ----
		"electric_strike":
			return EffectUtil.damage(b, enemy, amount + int(eff.args.get("per", 2)) * src.energy)
		"fire_power":
			return EffectUtil.damage(b, enemy, amount + int(eff.args.get("per", 2)) * src.heat)
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
			var tile_d: Vector2i = EffectUtil.tile(ctx)
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
			var inst_bb: CharInstance = b.recoverable_card(ctx.get("target", {}))
			if inst_bb == null:
				return ["回购：所选字已不在弃字堆中"]
			if not EffectUtil.pay(b, cost_bb):
				return ["回购：支付额不足（需 %d）" % cost_bb]
			b.take_from_discard_by_uid(inst_bb.uid)
			b.bag.append(inst_bb)
			return ["回购：支付 %d 金币，回收【%s】到袋顶" % [cost_bb, inst_bb.glyph()]]

	return ["（未实现的效果 %s）" % handler]


# ---------------------------------------------------------------- helpers
