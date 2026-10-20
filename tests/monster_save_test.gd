extends Node
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func _ready() -> void:
	for act in Database.acts.values():
		for node in act.nodes:
			for enemy in node.enemy_pool:
				check(enemy == Database.get_enemy(enemy.id), "map candidate uses configured monster " + enemy.id)
	check(Database.get_act(1).nodes[0].enemy_pool[0].tuning.get("shield_target", 0) == 8, "mainline paper shell uses configured shield refill target")
	GameState.start_new_run()
	var rules: BattleRules = Database.rules.duplicate()
	rules.opening_draw = 0
	var b := BattleState.new(rules)
	b.start([], [Database.get_enemy("corrosion_beetle")], 17)
	var e: Combatant = b.enemies[0]
	e.move_index = 1
	b._enemy_act(e)
	check(EnemyMechanics.injected_count(b, 0, "蚀") == 2, "first injection records stable battle enemy index")
	var saved := SaveCodec.new().pack({"battle": b})
	var decoded := SaveCodec.new().unpack(saved)
	check(decoded.has("battle"), "new monster battle saves and restores")
	if decoded.has("battle"):
		var restored: BattleState = decoded.battle
		var enemy: Combatant = restored.enemies[0]
		enemy.move_index = 1
		restored._enemy_act(enemy)
		check(EnemyMechanics.injected_count(restored, 0, "蚀") == 3, "injection cap survives new object IDs after resume")
	# Simulate the exact pre-roster schema, retaining all original fields.
	var legacy := saved.duplicate(true)
	for node in legacy.nodes:
		for key in SaveCodec.MONSTER_DEFAULT_FIELDS.get(node.type, []): node.fields.erase(key)
	var old := SaveCodec.new().unpack(legacy)
	check(old.has("battle"), "pre-roster save fields migrate with defaults")
	if old.has("battle"):
		check(old.battle.player.hp == b.player.hp and old.battle.turn == b.turn and old.battle.rng.state == b.rng.state, "legacy migration preserves HP, turn and RNG")
	var corrupt := saved.duplicate(true)
	for node in corrupt.nodes:
		if node.type == "battle": node.fields.erase("player")
	check(SaveCodec.new().unpack(corrupt).is_empty(), "missing original gameplay fields remain rejected")
	print("[monster_save_test] PASS=%d FAIL=%d" % [checks-failures, failures])
	get_tree().quit(1 if failures else 0)
