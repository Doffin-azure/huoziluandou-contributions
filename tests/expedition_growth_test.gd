extends Control
var checks := 0
var fails := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("[growth] " + label)

func labels(n: Node) -> String:
	var text := str(n.get("text")) if n is Label or n is Button else ""
	for child in n.get_children(): text += "\n" + labels(child)
	return text

func frames(n := 5) -> void:
	for i in n: await get_tree().process_frame

func signature(ed: EnemyData) -> String:
	return ed.id + ":" + str(ed.max_hp) + ":" + str(ed.initial_block) + ":" + ",".join(ed.moves.map(func(m): return str(m.damage) + "/" + str(m.hits)))

func _ready() -> void:
	await frames()
	var source_hp := {}
	for ed in Database.enemies.values(): source_hp[ed.id] = ed.max_hp
	for seed_value in 12:
		var ex := Expedition.start(700 + seed_value)
		for act_no in [1, 2, 3]:
			ex.load_act(act_no)
			var stages: Dictionary = ex.m.encounter_stages
			var present := {}
			var walk := MapGen.mask_of(func(k): return ex.m.ink[k] == 0)
			var d := MapGen.bfs(walk, ex.m.start)
			var positions: Array = stages.keys().filter(func(k): return ex.m.node.get(k, {}).get("t", "") != "险")
			positions.sort_custom(func(a,b): return d[a] < d[b] if d[a] != d[b] else a < b)
			var last := -1
			var monotone := true
			for k in positions:
				var stage := int(stages[k])
				present[stage] = true
				monotone = monotone and stage >= last
				last = stage
			check(monotone and present.size() == 3, "按起点路径深度递进，三段均有投放")
			var states: Array = [ex.rng.state, ex.boss_rng.state, ex.relic_rng.state]
			for k in stages:
				var kind := "elite" if ex.m.node.get(k, {}).get("t", "") == "险" else "foe"
				var ed := ex.encounter_enemy(kind, k)
				var stage := ex.encounter_stage(kind, k)
				var pool: Array = Expedition.ELITE_STAGES[act_no][stage] if kind == "elite" else Expedition.NORMAL_STAGES[act_no][stage]
				var source: EnemyData = Database.get_enemy(ed.id)
				check(pool.has(ed.id), "怪物来自对应幕/阶段的候选池")
				var expected := ceili(source_hp[ed.id] * (100 + 4 * stage + (12 if act_no == 3 else 0)) / 100.0)
				check(ed.max_hp == expected and ed.max_hp >= source_hp[ed.id], "生命倍率为前0%、中4%、深8%，三幕再加12%")
				check(ed.moves.size() == source.moves.size() and ed.moves.map(func(m): return m.damage) == source.moves.map(func(m): return m.damage), "原始招式伤害不暗增")
				var before := signature(ed)
				ex.t += 30; ex.steps += 10; ex.explored[k] = true
				check(signature(ex.encounter_enemy(kind, k)) == before, "等待、绕路、探索不会变换敌人")
				ex.fight = {"kind":kind,"k":k,"name":"测试","g":"测"}
				var info := ex.encounter_info(ex.fight)
				var node := ex.battle_node()
				var b := BattleState.new(Database.rules)
				b.start(GameState.make_battle_deck(), node.enemies, 33)
				ex.apply_battle_setup(b)
				check(signature(info.enemy) == signature(node.enemies[0]) and b.enemies[0].max_hp == int(info.hp) and info.stage == ex.stage_text(kind,k), "战前怪物/生命/阶段与实际战斗一致")
			for amb in ex.m.ambush:
				var reference := signature(ex.encounter_enemy("ambush", amb.k))
				check(amb.cells.all(func(k): return signature(ex.encounter_enemy("ambush", k)) == reference), "同一伏兵领地任何入口遇到同一只怪物")
			var boss := ex.encounter_enemy("boss", ex.boss)
			check(boss.max_hp == [88,124,168][act_no-1], "幕末首领生命保持88/124/168")
			check(states == [ex.rng.state,ex.boss_rng.state,ex.relic_rng.state], "投放、预览、构建战斗不消耗地图/首领/遗物随机序列")
			check(Database.enemies.values().all(func(e): return source_hp[e.id] == e.max_hp), "阶段成长不改写全局资源，不影响标准冒险")
	var ex := Expedition.start(888)
	var first_map: Dictionary = ex.m.encounter_stages.duplicate()
	var again := Expedition.start(888)
	check(first_map == again.m.encounter_stages, "同种子阶段投放可复现")
	# Combat word mechanics are still executable on the 4×4 board (covered in detail by monster_regression).
	check(Database.get_word_by_glyphs(["加", "速"]) != null and not ex.has_method("place"), "只移除地图版面，战斗组词保留")
	# UI shows growth and offers combat construction instead of a layout mini-game.
	ex = Expedition.start(1001)
	ex.load_act(3)
	GameState.expedition = ex
	Router.host = self
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await frames(8)
	var screen: Control = Router.current
	var text := labels(screen)
	check(text.contains("战斗构筑") and text.contains("兑现") and not text.contains("词谱") and not text.contains("版面") and not text.contains("超能力"), "地图无版面、词谱与探索超能力按钮")
	var deep := -1
	for k in ex.m.encounter_stages:
		if ex.m.encounter_stages[k] == 2 and ex.m.node.get(k,{}).get("t","") == "敌": deep = k; break
	if deep < 0:
		for amb in ex.m.ambush:
			if ex.encounter_stage("ambush",amb.k) == 2: deep = amb.k; break
	check(deep >= 0, "有深区怪物可展示")
	var kind := "foe" if ex.m.node.get(deep,{}).get("t","") == "敌" else "ambush"
	ex.fight = {"kind":kind,"k":deep,"name":"测试","g":"测","amb":0}
	screen.refresh(); await frames()
	text = labels(screen._event_box)
	check(text.contains("兑现·终局考验") and text.contains("铜钱+2") and text.contains("墨+1") and text.contains("行动循环"), "战前显示阶段、真实奖励与行动")
	var buttons: Array = screen._event_box.get_children().filter(func(c): return c is Button and c.text == "开战")
	check(buttons.size() == 1 and buttons[0].get_global_rect().end.y <= screen._event_box.get_parent().get_global_rect().end.y, "加入阶段说明后开战按钮仍在首屏")
	if OS.get_cmdline_user_args().has("--capture"):
		RenderingServer.force_draw(false)
		check(get_viewport().get_texture().get_image().save_png("/private/tmp/huozi-growth-deep.png") == OK,"保存深区战前画面")
	print("[expedition_growth_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-fails,fails,checks])
	get_tree().quit(1 if fails else 0)
