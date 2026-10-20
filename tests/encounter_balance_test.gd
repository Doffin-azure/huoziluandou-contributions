extends Node
## 从经典地图真实候选池开战，避免只测 Database.get_enemy() 而漏掉嵌套资源引用。
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[encounter_balance_test] " + message)

func fold_node() -> MapNodeData:
	for act in Database.acts.values():
		for node in act.nodes:
			for ed in node.enemy_pool:
				if ed.id == "fold_moth": return node
	return null

func make_fold() -> BattleState:
	GameState.start_new_run("v03")
	var node := fold_node()
	var seed_value := 0
	while node.select_enemies(seed_value)[0].id != "fold_moth": seed_value += 1
	var rules: BattleRules = Database.rules.duplicate()
	rules.opening_draw = 0
	rules.turn_draw = 0
	var b := BattleState.new(rules)
	b.start([], node.select_enemies(seed_value), seed_value)
	return b

func resolve_fold() -> void:
	var expected: EnemyData = Database.get_enemy("fold_moth")
	var damage: int = expected.tuning.resolved_damage
	var b := make_fold()
	var c := CharInstance.new(Database.get_character_by_glyph("击"))
	b.board.set_xy(Vector2i.ZERO, c)
	EnemyMechanics.begin_phase(b)
	check(b.current_intent(b.enemies[0]).damage == expected.moves[0].damage, "解签前显示已配置的折页伤害")
	var result := b.try_play([Vector2i.ZERO])
	check(result.ok, "从经典地图进入后，真实打出带签字")
	var intent := b.current_intent(b.enemies[0])
	print("[fold_repro] expected=%d after_play=%d tuning=%s" % [damage, intent.damage, b.enemies[0].enemy_data.tuning])
	check(intent.damage == damage, "解签后伤害应为%d，实际%d" % [damage, intent.damage])
	check(EnemyIntent.describe(intent, b.enemies[0])[0].value == str(damage), "意图组件与配置一致")
	var hp := b.player.hp
	b._enemy_act(b.enemies[0])
	check(hp - b.player.hp == damage, "真实攻击应扣%d生命，实际%d" % [damage, hp - b.player.hp])
	# 成词解签、原实体因额外使用留盘也必须继承相同的任务参数。
	b = make_fold()
	c = CharInstance.new(Database.get_character_by_glyph("击"))
	c.temporary_uses = 1
	b.board.set_xy(Vector2i.ZERO, c)
	b.board.set_xy(Vector2i.RIGHT, CharInstance.new(Database.get_character_by_glyph("反")))
	EnemyMechanics.begin_phase(b)
	var task := EnemyMechanics.data(b.enemies[0])
	task.targets = [c]
	task.origins = [Vector2i.ZERO]
	var enemy_hp: int = b.enemies[0].hp
	result = b.try_play([Vector2i.RIGHT, Vector2i.ZERO])
	check(result.ok and b.board.cells.has(c), "成词留盘仍算成功处理")
	check(b.current_intent(b.enemies[0]).damage == damage, "成词解签同样应用配置降伤")
	check(enemy_hp - b.enemies[0].hp == int(expected.tuning.reward), "成词解签奖励也来自配置")

func _ready() -> void:
	resolve_fold()
	if not OS.get_cmdline_user_args().has("--repro"):
		for act in Database.acts.values():
			for node in act.nodes:
				for ed in node.enemy_pool + node.enemies:
					check(ed == Database.get_enemy(ed.id), "所有经典候选/固定敌人引用完成数值绑定：" + ed.id)
		var raw_act := load("res://resources/acts/act_1.tres") as ActData
		for node in raw_act.nodes:
			for ed in node.enemy_pool:
				if ed.id == "fold_moth": check(ed.tuning.is_empty(), "不污染缓存中的原始地图或怪物资源")
		var original_path := BattleBalance.config_path
		var test_path := "user://encounter_balance_test.json"
		var payload := BattleBalance.payload.duplicate(true)
		for row in payload.tables["机制参数"]:
			if row[0] == "fold_moth" and row[2] == "resolved_damage": row[4] = 11
		var file := FileAccess.open(test_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(payload))
		file.close()
		BattleBalance.config_path = test_path
		Database.reload()
		check(Database.warnings.is_empty(), "有效自定义配置通过校验")
		resolve_fold()
		# 0是合法策划数值：修复引用丢失，而不是把所有0强行改成5。
		for row in payload.tables["机制参数"]:
			if row[0] == "fold_moth" and row[2] == "resolved_damage": row[4] = 0
		file = FileAccess.open(test_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(payload))
		file.close()
		Database.reload()
		resolve_fold()
		BattleBalance.config_path = original_path
		Database.reload()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
		check(fold_node().enemy_pool.all(func(ed): return ed == Database.get_enemy(ed.id)), "重载后地图绑定新配置，无旧引用残留")
	print("[encounter_balance_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-failures, failures, checks])
	get_tree().quit(1 if failures else 0)
