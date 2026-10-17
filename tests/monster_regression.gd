extends Node
## 真实出词、伤害结算、实体身份、任务窗口与投放集成回归。
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[monster] " + message)

func make(id: String, action := "") -> BattleState:
	GameState.player_max_hp = 1000
	GameState.player_hp = 1000
	GameState.permanent_damage_reduction = 0
	GameState.relics.clear()
	GameState.relic_binds.clear()
	GameState.gold = 100
	var rules: BattleRules = Database.rules.duplicate()
	rules.opening_draw = 0
	rules.turn_draw = 0
	var b := BattleState.new(rules)
	b.start([], [Database.get_enemy(id)], 121)
	if not action.is_empty():
		var e: Combatant = b.enemies[0]
		for i in e.enemy_data.moves.size():
			if e.enemy_data.moves[i].mechanic_action == action: e.move_index = i
		EnemyMechanics.begin_phase(b)
	return b

func put(b: BattleState, glyph: String, x: int, y := 0) -> CharInstance:
	var c := CharInstance.new(Database.get_character_by_glyph(glyph))
	b.board.set_xy(Vector2i(x, y), c)
	return c

func prepare(b: BattleState) -> void:
	EnemyMechanics.begin_phase(b)

func play(b: BattleState, text: String, row := 0) -> Dictionary:
	var path: Array = []
	for x in text.length():
		put(b, text.substr(x, 1), x, row)
		path.append(Vector2i(x, row))
	var result := b.try_play(path)
	check(result.ok, "真实出词成功：" + text)
	return result

func intent(b: BattleState) -> EnemyMoveData:
	return b.current_intent(b.enemies[0])

func _ready() -> void:
	for spec in EnemyRoster.DEFINITIONS:
		var b := make(spec.id)
		var e: Combatant = b.enemies[0]
		check(e.hp == spec.hp and e.block == spec.block, "初始数值 " + spec.name)
		var state := b.rng.state
		for i in 4: intent(b)
		check(state == b.rng.state, "意图只读 " + spec.name)
		for i in 9:
			if not b.is_over(): b.end_player_turn()
		check(b.player.hp > 0, "全循环无异常 " + spec.name)
	_shell_bee_tilt()
	_signs_blank_corrosion()
	_energy_payment()
	_identity_tasks()
	_bomb_seal_leech()
	_bosses()
	_copy_glutton()
	_pools()
	_extra_boundaries()
	check(checks + 1 == 240, "测试完整执行")
	print("[monster_regression] PASS=%d FAIL=%d TOTAL=%d" % [checks - failures, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)

func _shell_bee_tilt() -> void:
	var b := make("paper_shell")
	play(b, "击破")
	check(b.enemies[0].hp == 28 and b.enemies[0].block == 0, "击破8盾后剩4生命伤")
	b.enemies[0].block = 3
	b.enemies[0].move_index = 1
	b._enemy_act(b.enemies[0])
	check(b.enemies[0].block == 8, "补至8而非增加8")
	b._enemy_act(b.enemies[0])
	b.enemies[0].move_index = 1
	b._enemy_act(b.enemies[0])
	check(b.enemies[0].block == 8, "满盾不叠加")
	b = make("needle_bee")
	put(b, "御", 0)
	b.try_play([Vector2i.ZERO])
	b.end_player_turn()
	check(b.player.hp == 993, "御只减第一段2，连针损7血")
	b = make("needle_bee")
	b.player.permanent_damage_reduction = 1
	b.end_player_turn()
	check(b.player.hp == 994, "永久减伤逐段生效")
	b = make("needle_bee")
	put(b, "反", 0)
	b.try_play([Vector2i.ZERO])
	b.end_player_turn()
	check(b.enemies[0].hp == 28, "反仅完整行动后反6一次")
	b = make("tilting_inkwell")
	var a := put(b, "击", 0)
	var c := put(b, "破", 3)
	b._enemy_act(b.enemies[0])
	check(b.board.get_xy(Vector2i.ZERO) == a and b.board.get_xy(Vector2i(1,0)) == c, "左重力保序创造击破")
	b.enemies[0].move_index = 2
	var pin := put(b, "防", 1,1)
	pin.pinned = true
	var before := b.board.cells.duplicate()
	b._enemy_act(b.enemies[0])
	check(b.board.cells == before, "中央旋转遇固定跳过")

func _signs_blank_corrosion() -> void:
	var b := make("fold_moth")
	var c := put(b, "击", 0)
	put(b, "反", 1)
	prepare(b)
	# 只保留确定目标，测试额外使用留盘。
	var d := EnemyMechanics.data(b.enemies[0])
	d.targets = [c]; d.origins = [Vector2i.ZERO]
	c.temporary_uses = 1
	b.try_play([Vector2i(1,0), Vector2i.ZERO])
	check(b.board.cells.has(c) and intent(b).damage == 5, "折页成词留盘仍解除")
	check(d.rewarded.has("sign0"), "折页成词奖3")
	b = make("fold_moth")
	c = put(b, "击", 0)
	prepare(b)
	b.swap_cells(Vector2i.ZERO, Vector2i(3,0))
	EnemyMechanics.update_targets(b, b.enemies[0])
	check(intent(b).damage == 8, "折页只移动不解除")
	b.try_play([Vector2i(3,0)])
	check(intent(b).damage == 5 and EnemyMechanics.data(b.enemies[0]).rewarded.is_empty(), "折页单打降伤无奖")
	b = make("blank_child")
	for i in 14: put(b, "防", i % 4, i / 4)
	b._enemy_act(b.enemies[0])
	check(b.enemies[0].block == 4, "留白不足加4盾")
	b = make("blank_child")
	for i in 13: put(b, "防", i % 4, i / 4)
	b._enemy_act(b.enemies[0])
	check(b.enemies[0].hp == 33 and b.player.hp == 994, "留3空格奖3仍攻击6")
	b = make("corrosion_beetle", "corrode")
	b._enemy_act(b.enemies[0]); b.enemies[0].move_index = 1; b._enemy_act(b.enemies[0])
	var injected: Array = b.board.cells.filter(func(x): return x != null)
	check(injected.size() == 3 and injected.all(func(x): return x.glyph() == "蚀" and x.is_enemy_owned() and x.has_pollution("rush")), "指定蚀、刺痛、敌有、上限3")
	b = make("corrosion_beetle", "corrode")
	b.enable_ability("prevent_interference")
	b._enemy_act(b.enemies[0])
	check(b.board.free_count() == 16 and not b.has_ability("prevent_interference"), "防护阻止指定注字")
	b = make("furnace_beast", "heat6")
	b.player.heat = 8
	check(intent(b).damage == 10, "高热攻击预览+4")
	play(b, "火爆")
	check(b.enemies[0].hp == 4 and intent(b).damage == 6, "火爆耗8热打40，意图即时降6")
	b._enemy_act(b.enemies[0])
	check(b.player.hp == 994 and b.player.heat == 2, "攻击后升热不追溯")

func _energy_payment() -> void:
	var b := make("charge_badger", "arc")
	b.player.energy = 10
	b.spend_energy(4); b.refund_half_energy()
	b.enemies[0].block = 9
	check(b.monster_net_energy == 2 and intent(b).damage == 6, "消费4退款2净2")
	b._enemy_act(b.enemies[0])
	check(b.enemies[0].block == 3 and b.player.hp == 994, "放弧先拆最多6盾再打6")
	b = make("charge_badger", "arc")
	b.player.energy = 10
	b.spend_energy(3); b.refund_half_energy()
	check(intent(b).damage == 10, "消费3退款2不达标")
	b = make("charge_badger", "arc")
	b.player.energy = 10; b.spend_energy(4)
	b.begin_player_turn(false); b.refund_half_energy()
	check(b.monster_net_energy == 0, "旧消费跨阶段退款不反扣当前阶段")
	b.spend_energy(2); b.add_energy(8)
	check(b.monster_net_energy == 2, "普通储能收益不抵消消费")
	b = make("ink_creditor", "bill")
	b.player.temp_funds = 5
	check(EffectUtil.pay(b, 2) and b.monster_paid and intent(b).damage == 6, "临时资金正价支付有效")
	b.enemies[0].block = 12; b._enemy_act(b.enemies[0])
	check(b.enemies[0].block == 4, "催账最多拆8普通盾")
	b = make("ink_creditor", "bill")
	b.enable_ability("payment_discount_once", 1)
	check(EffectUtil.pay(b, 1) and not b.monster_paid, "折后0费不算支付")
	GameState.gold = 0
	check(not EffectUtil.pay(b, 1) and not b.monster_paid, "失败支付无收讫")
	b.player.energy = 4; b.enable_ability("joint_funding")
	check(EffectUtil.pay(b, 2) and b.monster_paid and b.player.energy == 0, "合资储能支付有效")
	b.begin_player_turn(false)
	check(not b.monster_paid, "支付记录不跨阶段")

func _identity_tasks() -> void:
	var b := make("double_slip", "pair")
	var a := put(b, "充", 0)
	var c := put(b, "电", 3)
	prepare(b)
	b.swap_cells(Vector2i.ZERO, Vector2i(3,0)); EnemyMechanics.update_targets(b, b.enemies[0])
	check(intent(b).damage == 7 and b.enemies[0].hp == 45, "双面简互换奖5降7")
	EnemyMechanics.update_targets(b, b.enemies[0])
	check(b.enemies[0].hp == 45, "双面奖励不重复")
	b = make("double_slip", "pair")
	put(b, "充", 0); put(b, "电", 1); prepare(b)
	b.try_play([Vector2i.ZERO, Vector2i(1,0)])
	check(intent(b).damage == 7, "同词消耗两枚优先完整解，不误判9")
	b = make("double_slip", "pair")
	put(b, "击", 0); put(b, "防", 1); prepare(b)
	b.try_play([Vector2i.ZERO])
	check(intent(b).damage == 9, "仅单打一枚降至9")
	b = make("double_slip", "pair")
	check(intent(b).damage == 9, "无目标固定9")
	b = make("nest_moth", "nest")
	a = put(b, "充", 0); c = put(b, "电", 1); prepare(b)
	b.enemies[0].block = 6
	b.try_play([Vector2i.ZERO, Vector2i(1,0)])
	check(intent(b).damage == 11, "开窗前盘面不算重新入盘")
	b = make("nest_moth", "nest")
	a = put(b, "充", 0); c = put(b, "电", 1); prepare(b)
	b.board.clear_xy(Vector2i.ZERO); b.place_from_pool(Vector2i.ZERO, a)
	b.enemies[0].block = 6
	b.try_play([Vector2i.ZERO, Vector2i(1,0)])
	check(intent(b).damage == 7 and b.enemies[0].block == 0, "真实重新入盘成词拆盾降7")
	b = make("nest_moth", "nest")
	a = put(b, "充", 0); c = put(b, "电", 1); prepare(b)
	b.board.clear_xy(Vector2i.ZERO)
	b.reconnect_pending.append({"inst":a,"pos":Vector2i.ZERO,"return_turn":b.turn})
	b.restore_reconnect_tiles(); b.try_play([Vector2i.ZERO, Vector2i(1,0)])
	check(intent(b).damage == 11, "重连返还不算铸巢入盘")
	b = make("wheel_master", "wheel")
	a = put(b, "充", 0); c = put(b, "电", 1); a.temporary_uses = 1; prepare(b)
	b.try_play([Vector2i.ZERO, Vector2i(1,0)])
	put(b, "电", 1)
	b.try_play([Vector2i.ZERO, Vector2i(1,0)])
	check(intent(b).damage == 8 and b.enemies[0].hp == 58, "同一实体两词奖8降伤")
	b = make("wheel_master", "wheel")
	play(b, "充电"); play(b, "充电")
	check(intent(b).damage == 14, "同字形不同实体不代替")

func _bomb_seal_leech() -> void:
	var b := make("bomb_press", "bomb")
	var d := EnemyMechanics.data(b.enemies[0]); d.cells = [Vector2i.ZERO, Vector2i(1,0)]
	var a := put(b, "击", 0); var c := put(b, "防", 1)
	b.swap_cells(Vector2i.ZERO, Vector2i(2,0))
	var replacement := put(b, "电", 0)
	b._enemy_act(b.enemies[0])
	check(b.board.cells.has(a) and b.discard.has(c) and b.discard.has(replacement), "炸坐标新字，移走原字不追踪")
	b = make("bomb_press", "bomb")
	d = EnemyMechanics.data(b.enemies[0]); d.cells = [Vector2i.ZERO, Vector2i(1,0)]
	a = put(b, "击", 0); c = put(b, "防", 1); b.enable_ability("blastproof")
	b._enemy_act(b.enemies[0])
	check(b.bag.has(a) and b.bag.has(c) and b.player.persistent_block == 2, "防爆逐实体回袋并给2盾")
	b = make("bomb_press", "bomb")
	d = EnemyMechanics.data(b.enemies[0]); d.cells = [Vector2i.ZERO]
	a = put(b, "击", 0); a.pinned = true
	b._enemy_act(b.enemies[0])
	check(b.board.cells.has(a), "爆印不摧毁固定字")
	b = make("seal_officer", "seal")
	d = EnemyMechanics.data(b.enemies[0]); d.cells = [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]
	put(b, "防", 0); put(b, "御", 1)
	check(intent(b).damage == 12, "印区两占格为12")
	put(b, "充", 0,1); put(b, "电", 1,1)
	check(intent(b).damage == 16, "流速补满也占格16")
	b = make("leech"); b.player.energy = 3; b.player.block = 6
	b._enemy_act(b.enemies[0])
	check(b.player.hp == 998 and b.player.energy == 1 and b.enemies[0].block == 4, "漏电穿透扣血后偷2得4盾")
	b = make("leech"); b.player.energy = 3; b.player.block = 8
	b._enemy_act(b.enemies[0])
	check(b.player.energy == 3 and b.enemies[0].block == 0, "全挡阻断吸能")
	b = make("leech"); b.player.energy = 3; b.player.hp = 1; b.player.heart_power = 1
	b._enemy_act(b.enemies[0])
	check(b.player.energy == 3 and b.player.hp == 1, "心力抵致命无实际扣血不偷")
	b = make("leech"); b.player.energy = 3; b.enemies[0].block = 8
	b._enemy_act(b.enemies[0])
	check(b.player.energy == 1 and b.enemies[0].block == 8, "满盾仍偷，上限8")

func _bosses() -> void:
	var b := make("proof_boss", "proof")
	put(b, "防", 0); put(b, "御", 1); prepare(b)
	b.enemies[0].block = 6
	b.try_play([Vector2i.ZERO,Vector2i(1,0)])
	check(b.enemies[0].block == 0 and intent(b).damage == 8, "防御同词解两签，6奖励拆6盾")
	b._enemy_act(b.enemies[0])
	check(b.player.hp == 1000 and b.player.block == 2, "防御10挡朱批8")
	b = make("proof_boss", "proof")
	put(b, "击", 0); prepare(b)
	check(intent(b).damage == 10, "只有一签最多+2")
	b.enemies[0].hp = 44
	check(intent(b).damage == 12, "半血线按当前上限切二阶段")
	b.enemies[0].max_hp = 100; b.enemies[0].hp = 50
	check(intent(b).damage == 12, "最大生命改变后使用当前半血线")
	b = make("rail_boss", "rail")
	for x in 4: put(b, "防", x)
	b.enemies[0].hp = 62; prepare(b)
	check(intent(b).damage == 20, "二阶压轨最多4枚为20")
	var d := EnemyMechanics.data(b.enemies[0])
	for c in d.targets:
		b.board.clear_xy(EnemyMechanics.pos(b,c)); b.bag.append(c)
	for x in 4: put(b, "击", x)
	b.enemies[0].block = 10
	check(intent(b).damage == 12, "原格补新字不算旧实体")
	b._enemy_act(b.enemies[0])
	check(b.enemies[0].block == 2, "全撤离攻击后拆8盾")
	b = make("rail_boss", "rail"); b.enemies[0].block = 10
	b._enemy_act(b.enemies[0])
	check(b.enemies[0].block == 10, "空题不发拆盾奖励")
	b = make("compiler_boss", "different")
	play(b, "防御"); play(b, "充电")
	check(intent(b).damage == 8, "异文2种完成意图8")
	b._enemy_act(b.enemies[0])
	check(b.enemies[0].hp == 162 and b.enemies[0].block == 0, "异文先奖6且不加盾")
	b = make("compiler_boss", "repeat")
	play(b, "击破"); play(b, "连击")
	check(intent(b).damage == 12, "连击重演不算主动重复提交")
	b = make("compiler_boss", "repeat")
	play(b, "充电"); play(b, "充电")
	check(intent(b).damage == 8, "同名词主动两次完成")
	b.begin_player_turn(false)
	check(intent(b).damage == 12, "任务计数阶段清空")

func _copy_glutton() -> void:
	var b := make("copy_master", "copy")
	b.enemies[0].hp = 62
	play(b, "充电"); play(b, "防御")
	check(intent(b).kind == EnemyMoveData.Kind.BLOCK and intent(b).block == 8, "拓只看最后多字防御")
	put(b, "击", 0); b.try_play([Vector2i.ZERO])
	check(intent(b).block == 8, "单字不改最后多字词")
	play(b, "火爆")
	check(intent(b).kind == EnemyMoveData.Kind.ATTACK and intent(b).damage == 10, "拓攻击固定10不复制爆发")
	b.enable_ability("split_mind")
	var hp: int = b.enemies[0].hp
	b._enemy_act(b.enemies[0])
	check(b.enemies[0].hp == hp - 10, "拓攻击支持精分")
	b = make("glutton", "swallow")
	var a := CharInstance.new(Database.get_character_by_glyph("击"))
	b.discard.append(a); prepare(b); b._enemy_act(b.enemies[0])
	var d := EnemyMechanics.data(b.enemies[0])
	check(d.stomach.has(a) and not b.discard.has(a) and b.enemies[0].block == 4, "吞字保存原实体只加4盾")
	play(b, "重击")
	check(d.stomach.has(a), "打进HP不足10不吐")
	b.enemies[0].block = 100
	play(b, "火爆")
	check(d.stomach.has(a), "全被盾挡不满足HP阈值")
	b.enemies[0].block = 0; b.player.heat = 2
	play(b, "火爆")
	check(d.stomach.is_empty() and b.bag.has(a), "单段真实生命伤>=10吐原字")
	b = make("glutton", "swallow")
	b.discard.append(a); prepare(b); b._enemy_act(b.enemies[0]); b.enemies[0].hp = 0
	EnemyMechanics.release_dead(b); EnemyMechanics.release_dead(b)
	check(b.bag.count(a) == 1, "战后归还只一次")

func _pools() -> void:
	check(EnemyRoster.DEFINITIONS.size() == 20, "注册20种")
	for act in [1,2,3]:
		var ids: Array = []
		for node in Database.acts[act].nodes:
			if node.is_combat() or node.type == MapNodeData.Type.FORK:
				check(node.select_enemies(17).size() == 1, "每节点单敌，不把候选同时投放")
				for e in node.enemy_pool: ids.append(e.id)
		for id in EnemyRoster.NORMAL[act] + EnemyRoster.ELITES[act] + [EnemyRoster.BOSSES[act]]:
			check(ids.has(id), "关卡池可达 " + id)
	var ex := Expedition.new()
	ex.run_seed = 7
	for act in [1,2,3]:
		ex.act = act
		for kind in ["foe","elite","boss","ambush"]:
			ex.fight = {"kind":kind,"k":12,"name":"旧主题名","g":"旧"}
			var first := ex.battle_node()
			var again := ex.battle_node()
			check(first.enemies[0].id == again.enemies[0].id and first.enemies[0].name != "旧主题名", "远征确定投放保留机制怪名")

func _extra_boundaries() -> void:
	var b := make("proof_boss", "proof")
	var a := put(b, "充", 0); var c := put(b, "电", 1); prepare(b)
	var d := EnemyMechanics.data(b.enemies[0])
	# 确定红蓝，确认蓝签移动无成词奖励且红签移动无效。
	d.targets = [a,c]; d.origins = [Vector2i.ZERO,Vector2i(1,0)]
	b.swap_cells(Vector2i.ZERO,Vector2i(2,0)); b.swap_cells(Vector2i(1,0),Vector2i(3,0))
	EnemyMechanics.update_targets(b,b.enemies[0])
	check(intent(b).damage == 10 and d.rewarded.is_empty(), "红签移动不解，蓝签移动解且无奖励")
	b.board.clear_xy(Vector2i(2,0)); b.discard.append(a)
	check(intent(b).damage == 8, "阶段外开局效果离盘也反映预览")
	b = make("fold_moth"); a = put(b,"击",0); prepare(b)
	check(EnemyMechanics.markers(b).size() == 1, "实体标记可见")
	b.try_play([Vector2i.ZERO])
	check(EnemyMechanics.markers(b).is_empty(), "已解除实体标记消失")
	b = make("bomb_press", "bomb")
	var cells: Array = EnemyMechanics.data(b.enemies[0]).cells
	check(cells.size() == 2 and cells[0] != cells[1] and abs(cells[0].x - cells[1].x) <= 1 and abs(cells[0].y-cells[1].y) <= 1, "爆印两不同坐标属于同一2x2")
	check(EnemyMechanics.markers(b).size() == 2, "爆印坐标高亮两格")
	b = make("tilting_inkwell", "rotate")
	check(EnemyMechanics.markers(b).size() == 4 and intent(b).description.contains("中央2×2"), "旋转区域和方向明确预告")
	b = make("compiler_boss", "different"); b.enemies[0].hp = 84
	check(intent(b).damage == 14, "编纂者二阶段未完成14")
	play(b,"充电"); play(b,"防御")
	check(intent(b).damage == 10, "编纂者二阶段完成10")
	b = make("proof_boss", "boss_multi"); b.enemies[0].hp = 44
	check(intent(b).damage == 7 and intent(b).hits == 2, "对校二阶7x2")
	b = make("rail_boss", "boss_multi"); b.enemies[0].hp = 62
	check(intent(b).damage == 7 and intent(b).hits == 2, "铅轨二阶7x2")
	b = make("compiler_boss", "boss_multi"); b.enemies[0].hp = 84
	check(intent(b).damage == 7 and intent(b).hits == 3, "终局二阶7x3")
	b = make("nest_moth", "nest")
	a = put(b,"充",0); c = put(b,"电",1); a.temporary = true; prepare(b)
	b.board.clear_xy(Vector2i.ZERO); b.place_from_pool(Vector2i.ZERO,a)
	b.try_play([Vector2i.ZERO,Vector2i(1,0)])
	check(intent(b).damage == 11, "临时复制不满足真实重新入盘")
	b = make("wheel_master", "wheel")
	b.enable_ability("repeat"); b.repeat_armed = true
	play(b,"充电")
	check(intent(b).damage == 14, "词效重演不追加实体使用次数")
	b = make("glutton", "swallow")
	a = CharInstance.new(Database.get_character_by_glyph("击")); b.discard.append(a); prepare(b)
	b._enemy_act(b.enemies[0]); b.enemies[0].block = 0
	play(b,"防御力")
	check(b.bag.has(a), "实际消耗三枚材料的长词可以吐字")
	b = make("charge_badger", "arc"); b.player.energy = 10
	b.enable_ability("energy_refund_once",2); b.spend_energy(3)
	check(b.monster_net_energy == 1 and intent(b).damage == 10, "单字复即时退款计入同笔净消费")
	b = make("proof_boss")
	b.enemies[0].status_data.first_shield_discount = 8
	b.enemies[0].status_data.first_shield_cancel = true
	b.enemies[0].add_block(6)
	check(b.enemies[0].block == 0 and b.enemies[0].status_data.has("first_shield_cancel"), "破甲先抵完首次盾，破防机会留存")
	b.enemies[0].add_block(8); b.enemies[0].add_block(8)
	check(b.enemies[0].block == 8 and not b.enemies[0].status_data.has("first_shield_cancel"), "破防一次生效后恢复正常补盾")
	var ex := Expedition.new(); ex.act = 1; ex.run_seed = 4
	ex.fight = {"kind":"boss","k":1,"name":"首领","g":"首"}
	b = make("proof_boss"); b.enemies[0].hp -= 6; ex.seals = ["朱笔"]
	ex.apply_battle_setup(b)
	check(b.enemies[0].max_hp == 82 and b.enemies[0].hp == 76, "朱笔降低上限与当前生命，保留已有开场伤害")
	# 任务奖励击杀时不继续攻击；固定盾不被最多普通盾奖励移除。
	b = make("blank_child"); b.enemies[0].hp = 3
	b._enemy_act(b.enemies[0])
	check(b.player.hp == 1000 and b.enemies[0].hp == 0, "机制奖励先击杀则中止本次敌方攻击")
	b = make("charge_badger", "arc"); b.monster_net_energy = 2
	b.enemies[0].persistent_block = 9; b._enemy_act(b.enemies[0])
	check(b.enemies[0].persistent_block == 9, "净消费任务只拆普通盾")

	b = make("double_slip", "flip")
	b._enemy_act(b.enemies[0])
	put(b,"充",0); put(b,"电",1); prepare(b)
	check(intent(b).damage == 9 and b.enemies[0].block == 4, "翻签空题得4盾，随后新补字不改变固定9")
	b = make("copy_master", "copy")
	play(b,"防护")
	check(intent(b).kind == EnemyMoveData.Kind.BLOCK and intent(b).block == 8, "防护等纯防御能力分类为防御")
	check(EnemyMechanics.copy_category(Database.get_word_by_glyphs(["投","放"])) == "space", "带经济支付的空间词优先空间类")

	b = make("double_slip")
	put(b,"充",0); put(b,"电",1); prepare(b)
	ex = Expedition.new(); ex.act = 2; ex.fight = {"kind":"ambush","k":1,"name":"伏兵","g":"伏"}
	ex.apply_battle_setup(b)
	check(b.enemies[0].move_index == 1 and EnemyMechanics.data(b.enemies[0]).targets.size() == 2 and intent(b).damage == 12, "伏兵先手翻签后下一招正确开两目标题")
	b = make("proof_boss")
	put(b,"击",0); put(b,"防",1); prepare(b)
	ex = Expedition.new(); ex.act = 1; ex.fight = {"kind":"boss","k":1,"name":"首领","g":"首","debuff":"先手"}
	ex.apply_battle_setup(b)
	check(b.enemies[0].move_index == 1 and intent(b).damage == 12, "首领先手后朱批正确预告两签")
