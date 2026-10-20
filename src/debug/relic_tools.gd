extends RefCounted
## 控制台遗物工具；自检同步运行在临时状态中，不切场景、不触发全局信号。


static func resolve(key: String) -> String:
	for id in Relics.DEFS:
		if key == id or key == Relics.name_of(id):
			return id
	return ""


static func bind(args: Array) -> Array:
	if args.size() != 2:
		return ["用法：/relic-bind 遗物名或id 字形或#实体uid（如 /relic-bind slab 击）"]
	var id := resolve(str(args[0]))
	if id.is_empty():
		return ["未知遗物：%s" % args[0]]
	if not Relics.needs_bind(id):
		return ["「%s」不需要绑字" % Relics.name_of(id)]
	if not GameState.has_relic(id):
		return ["尚未拥有「%s」，先用 /relic %s 领取" % [Relics.name_of(id), id]]
	var key := str(args[1])
	var uid_text := key.trim_prefix("#")
	if key.begins_with("#") and not uid_text.is_valid_int():
		return ["实体 uid 必须是整数，例如 #123"]
	for c in GameState.deck:
		if (key.begins_with("#") and c.uid == int(uid_text)) or (not key.begins_with("#") and (c.glyph() == key or c.id() == key)):
			var occupied := false
			for other in GameState.relic_binds:
				if other != id and GameState.relic_binds[other] == c.uid:
					occupied = true
			if occupied:
				continue
			GameState.relic_binds[id] = c.uid
			return ["「%s」绑定【%s】#%d；下一场战斗生效" % [Relics.name_of(id), c.glyph(), c.uid]]
	return ["找不到可绑定的「%s」（需在永久字袋中，且未被其他遗物占用）" % key]


static func status(b: BattleState) -> Array:
	var out: Array = ["持有遗物：%d 件；战斗中增删或换绑，下一场生效" % GameState.relics.size()]
	for id in GameState.relics:
		var line := "%s「%s」" % [id, Relics.name_of(id)]
		if Relics.needs_bind(id):
			var c := GameState.relic_bound_inst(id)
			line += " → 【%s】#%d" % [c.glyph(), c.uid] if c != null else " → 未绑定或实体已移除"
		if id == "egg":
			var wins := int(GameState.relic_counters.get(id, 0))
			line += "；胜场 %d，下次奖励还需 %d 胜" % [wins, Relics.EGG_EVERY - wins % Relics.EGG_EVERY]
		if id == "fireman":
			line += "；本局赠字%s领取" % ("已" if GameState.relic_counters.get("fireman_claimed", false) else "未")
		out.append(line)
	if b != null:
		var active: Array = b.relics.map(func(id): return Relics.name_of(id))
		out.append("本场实际遗物：%s" % ("、".join(active) if not active.is_empty() else "无"))
		for id in b.relic_binds:
			out.append("本场绑定 %s → #%d" % [Relics.name_of(id), b.relic_binds[id]])
		if b.relics.has("slab"):
			out.append("压字石：实体 #%d，剩余额外次数 %d" % [b.slab_uid, b.slab_uses])
		if b.relics.has("fertilizer"):
			out.append("蔓生墨：盘上母本 %d" % b.board.cells.filter(func(c): return c != null and b.breeders.has(c.uid)).size())
		if b.relics.has("wheel"):
			out.append("转轮架：下次向%s" % Relics.WHEEL_TEXT[Relics.WHEEL_DIRS[b.wheel_step % 4]])
		if b.relics.has("blitz"):
			out.append("急就章：%s" % ("本回合敌人跳过行动" if b.turn == b.blitz_turn else "本场已用过"))
	return out


static func run_checks(args: Array) -> Array:
	if args.size() > 1:
		return ["用法：/relic-test [all|遗物名或id]"]
	var key := str(args[0]) if not args.is_empty() else "all"
	var ids: Array = Relics.DEFS.keys() if key == "all" else [resolve(key)]
	if ids.has(""):
		return ["未知遗物：%s；/relic 查看列表" % key]
	# 保存原对象引用，沙盒只操作新数组、字实例和随机数发生器。
	# 无 await：恢复之前主循环和自动存档没有机会读取临时状态。
	var snapshot := {}
	for field in SaveManager.STATE_FIELDS:
		snapshot[field] = GameState.get(field)
	var next_uid := CharInstance._next_uid
	var was_blocked := EventBus.is_blocking_signals()
	EventBus.set_block_signals(true)
	var out: Array = []
	var passed := 0
	for id in ids:
		_reset()
		var result: Variant = _check_one(str(id))
		if not result is Dictionary:
			result = _result(false, "测试未返回结果，请查看引擎错误日志")
		if result.ok:
			passed += 1
		out.append("%s「%s」：%s" % ["通过" if result.ok else "失败", Relics.name_of(id), result.detail])
	for field in snapshot:
		GameState.set(field, snapshot[field])
	CharInstance._next_uid = next_uid
	EventBus.set_block_signals(was_blocked)
	out.push_front("遗物自检：%d/%d 通过（当前对局与存档未改动）" % [passed, ids.size()])
	return out


static func _reset() -> void:
	GameState.deck = []
	GameState.relics = []
	GameState.relic_binds = {}
	GameState.relic_counters = {}
	GameState.expedition = null
	GameState.rng = RandomNumberGenerator.new()
	GameState.rng.seed = 7
	GameState.player_hp = 60
	GameState.player_max_hp = 60
	GameState.permanent_damage_reduction = 0
	GameState.battle_sequence = 0
	GameState.gold = 0


static func _inst(g: String) -> CharInstance:
	return CharInstance.new(Database.get_character_by_glyph(g))


static func _battle(id: String, opening := 0, turn_draw := 0) -> BattleState:
	GameState.relics = [id]
	var rules := BattleRules.new()
	rules.plays_per_turn = 0
	rules.opening_draw = opening
	rules.turn_draw = turn_draw
	var enemy := EnemyData.new()
	enemy.name = "遗物测试木桩"
	enemy.max_hp = 999
	var move := EnemyMoveData.new()
	move.kind = EnemyMoveData.Kind.ATTACK
	move.damage = 5
	enemy.moves.append(move)
	var b := BattleState.new(rules)
	b.start(GameState.deck.duplicate(), [enemy, enemy], 7)
	return b


static func _filled(b: BattleState) -> int:
	return b.board.cells.filter(func(c): return c != null).size()


static func _result(ok: bool, detail: String) -> Dictionary:
	return {"ok": ok, "detail": detail}


static func _check_one(id: String) -> Dictionary:
	match id:
		"fireman":
			GameState.add_relic(id)
			var count := GameState.deck.size()
			GameState.remove_relic(id)
			GameState.add_relic(id)
			return _result(count == 4 and GameState.deck.size() == 4 and GameState.glyph_counts().get("火", 0) == 4, "拾取赠火 %d 枚，重领后 %d 枚（应为 4/4）" % [count, GameState.deck.size()])
		"egg":
			GameState.relics = [id]
			for i in 3:
				Relics.on_battle_won()
			var before := GameState.deck.size()
			Relics.on_battle_won()
			return _result(before == 0 and GameState.deck.size() == 1 and GameState.relic_counters.get(id) == 4, "前 3 胜获字 %d，第 4 胜累计 %d（应为 0/1）" % [before, GameState.deck.size()])
		"sleep":
			var base := Relics.rest_bonus()
			GameState.relics = [id]
			return _result(base == 0 and Relics.rest_bonus() == 20, "额外治疗 %d → %d（应为 0 → 20）" % [base, Relics.rest_bonus()])
		"press", "clean":
			for i in 30:
				GameState.deck.append(_inst("火"))
		"slab", "fertilizer":
			GameState.deck = [_inst("击")]
			GameState.relic_binds = {id: GameState.deck[0].uid}
	var b := _battle(id, 10 if id == "press" else 0, 3 if id == "clean" else 0)
	match id:
		"strike":
			b.board.set_cell(0, 0, _inst("击"))
			var play := b.try_play([Vector2i.ZERO])
			var damage: int = 999 - b.enemies[0].hp
			return _result(play.ok and damage == 6 and not b.strike_active, "单字击伤害 %d（应为 6），出字标记复位" % damage)
		"breach":
			return _result(b.enemies.all(func(e): return e.status_stacks("vulnerable") == 2), "全体木桩易伤 %s（应全为 2）" % str(b.enemies.map(func(e): return e.status_stacks("vulnerable"))))
		"barrier":
			var block := b.player.block
			b.end_player_turn()
			return _result(block == 10 and b.player.block == 0 and b.player.hp == 60, "开局格挡 %d，抵挡两次 5 伤后生命 %d（应为 10/60）" % [block, b.player.hp])
		"buckler":
			var shield := b.player.persistent_block
			b.end_player_turn()
			return _result(shield == 4 and b.player.hp == 54, "开局持久盾 %d，受到共 10 伤后生命 %d（应为 4/54）" % [shield, b.player.hp])
		"powerbank":
			return _result(b.player.energy == 4, "开局储能 %d（应为 4）" % b.player.energy)
		"press":
			return _result(b.board.size == 5 and _filled(b) == 14, "盘面 %d×%d，开局补字 %d（应为 5×5/14）" % [b.board.size, b.board.size, _filled(b)])
		"blitz":
			b.end_player_turn()
			var first_hp := b.player.hp
			b.end_player_turn()
			return _result(first_hp == 60 and b.player.hp == 50, "第一/二回合后生命 %d/%d（应为 60/50）" % [first_hp, b.player.hp])
		"skyfire":
			b.board.set_cell(0, 0, _inst("流"))
			b.board.set_cell(1, 0, _inst("火"))
			var play := b.try_play([Vector2i.ZERO, Vector2i(1, 0)])
			var damage: int = 999 - b.enemies[0].hp
			return _result(play.ok and damage == 50, "打出流火，额外伤害 %d（应为 50）" % damage)
		"slab":
			var c: CharInstance = b.bag.pop_back()
			b.board.set_cell(1, 0, c)
			Relics.slab_fall(b)
			var fell: bool = b.board.get_cell(1, 3) == c
			var plays := 0
			for i in 6:
				if b.try_play([Vector2i(1, 3)]).ok:
					plays += 1
			return _result(fell and plays == 6 and b.slab_uses == 0 and b.removed_this_battle.has(c), "自动落底 %s，可用 %d 次，用尽移出 %s" % [fell, plays, b.removed_this_battle.has(c)])
		"fertilizer":
			var c: CharInstance = b.bag.pop_back()
			b.board.set_cell(0, 0, c)
			b.end_player_turn()
			return _result(c.temporary and _filled(b) == 3 and b.board.cells.all(func(cell): return cell == null or cell.temporary) and not GameState.deck[0].temporary, "角落母本繁殖后 %d 枚临时字（应为 3），永久字保留" % _filled(b))
		"clean":
			b.end_player_turn()
			var clean_count := _filled(b)
			var dirty := _inst("火")
			dirty.add_pollution("ink")
			b.board.set_cell(3, 3, dirty)
			var before := _filled(b)
			b.end_player_turn()
			return _result(clean_count == 4 and _filled(b) - before == 3, "干净盘面补 %d，有污染补 %d（应为 4/3）" % [clean_count, _filled(b) - before])
		"wheel":
			var c := _inst("击")
			b.board.set_cell(1, 1, c)
			b.wheel_step = 0
			var positions := [Vector2i(1, 0), Vector2i(1, 3), Vector2i(0, 3), Vector2i(3, 3)]
			var correct := true
			for pos in positions:
				Relics.apply_gravity_relics(b)
				correct = correct and b.board.get_xy(pos) == c
			return _result(correct and b.wheel_step == 4, "按上、下、左、右完成 %d 次重力，位置正确 %s" % [b.wheel_step, correct])
	return _result(false, "尚未实现此遗物的自检")
