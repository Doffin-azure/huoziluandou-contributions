extends "res://tests/monster_regression.gd"

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--invalid"):
		check(not Database.warnings.is_empty(), "损坏配置明确警告")
		check(Database.get_enemy("furnace_beast").max_hp == 44, "无效整表回退默认值，不部分应用")
	elif OS.get_cmdline_user_args().has("--tuned"):
		_tuned()
	else:
		_default_contract()
	print("[enemy_balance_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-failures, failures, checks])
	get_tree().quit(1 if failures else 0)

func _default_contract() -> void:
	check(Database.warnings.is_empty(), "默认配置无警告")
	var payload := {"version": EnemyBalance.schema.version, "tables": {}}
	for spec in EnemyBalance.schema.sheets: payload.tables[spec.name] = spec.rows.duplicate(true)
	check(EnemyBalance.validate_payload(payload).is_empty(), "默认配置通过运行时校验")
	var wrong := payload.duplicate(true)
	wrong.tables["怪物"][0][3] = -1
	check(not EnemyBalance.validate_payload(wrong).is_empty(), "运行时拒绝负生命")
	wrong = payload.duplicate(true); wrong.tables["怪物"][0][3] = "100"
	check(not EnemyBalance.validate_payload(wrong).is_empty(), "运行时拒绝文字代替数值")
	wrong = payload.duplicate(true); wrong.tables["怪物"].append(wrong.tables["怪物"][0])
	check(not EnemyBalance.validate_payload(wrong).is_empty(), "运行时拒绝重复ID")
	wrong = payload.duplicate(true); wrong.tables["机制参数"][0][4] = 999
	check(not EnemyBalance.validate_payload(wrong).is_empty(), "运行时使用参数专属范围")
	wrong = payload.duplicate(true); wrong.tables["行动"][0][2] = 999
	check(not EnemyBalance.validate_payload(wrong).is_empty(), "运行时拒绝行动序号变化")
	wrong = payload.duplicate(true); wrong.tables.erase("污染")
	check(not EnemyBalance.validate_payload(wrong).is_empty(), "运行时拒绝缺表")
	var ed: EnemyData = Database.get_enemy("furnace_beast")
	check(ed != load("res://resources/enemies/furnace_beast.tres"), "不修改缓存原资源")
	Database.reload()
	check(Database.get_enemy("furnace_beast").max_hp == ed.max_hp, "重载不叠加覆盖")
	for enemy in Database.enemies.values():
		check(not enemy.description.contains("{"), "说明无未替换参数：" + enemy.name)

func _tuned() -> void:
	check(Database.warnings.is_empty(), "已导入调参文件无警告")
	check(Database.get_enemy("furnace_beast").max_hp == 123, "Excel生命进入数据库")
	var b := make("furnace_beast", "heat6")
	check(b.enemies[0].hp == 123, "真实战斗采用Excel生命")
	var move := intent(b)
	check(move.damage == 17 and move.hits == 3 and move.kind == EnemyMoveData.Kind.MULTI, "伤害与段数均来自Excel")
	check(move.inject_count == 2, "塞字数量来自Excel")
	b._enemy_act(b.enemies[0])
	check(b.player.hp == 949, "实际三段攻击扣51生命")
	check(b.board.cells.filter(func(c): return c != null and c.glyph() == "热").size() == 2, "实际塞2枚热")
	check(b.player.heat == 5, "机制升热来自Excel")
	check(b.enemies[0].enemy_data.description.contains("热度+5"), "怪物说明同步机制数值")
	b = make("nest_moth")
	b.end_player_turn()
	check(b.board.free_count() == 14, "结巢注2连")
	b.enemies[0].move_index = 1
	b.end_player_turn()
	check(b.board.free_count() == 14, "延迟2回合不提前复制")
	b.end_player_turn()
	check(b.board.free_count() == 10, "每枚复制2枚且总量封顶6")
	check(b.enemies[0].enemy_data.description.contains("最多6枚"), "复制上限说明同步")
	b = make("copy_master", "copy")
	play(b, "击破")
	check(intent(b).damage == 19, "拓攻击分支读取独立参数")
	b = make("charge_badger", "arc")
	b.monster_net_energy = 3
	check(intent(b).damage == 10, "净储能门槛提高为4")
	b.monster_net_energy = 4
	check(intent(b).damage == 2, "完成任务伤害改为2")
	b = make("proof_boss", "proof")
	b.enemies[0].hp = 60
	check(EnemyMechanics.phase(b.enemies[0]) == 2, "首领阶段门槛改为75%")
	check(intent(b).damage == 21, "二阶段基础伤害来自Excel")
	check(Database.get_pollution("rush").hp_loss_on_play == 5, "污染扣血来自Excel")
	check(Database.get_pollution("block").draw_penalty_on_play == 2, "污染补字惩罚来自Excel")
	b = make("corrosion_beetle", "corrode")
	b._enemy_act(b.enemies[0])
	var card: CharInstance = b.board.cells.filter(func(c): return c != null)[0]
	var before := b.player.hp
	b.try_play([EnemyMechanics.pos(b, card)])
	check(b.player.hp == before - 5, "真实打出污染字扣Excel设置的5血")
