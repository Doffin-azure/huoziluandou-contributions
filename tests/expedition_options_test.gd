extends Control
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[expedition_options] " + label)

func fresh(seed_value := 1) -> Expedition:
	return Expedition.start(seed_value)

func labels(node: Node) -> String:
	var result := str(node.get("text")) if node is Label or node is Button else ""
	for child in node.get_children(): result += "\n" + labels(child)
	return result

func frames(n := 4) -> void:
	for i in n: await get_tree().process_frame

func _ready() -> void:
	await frames()
	var diversity := {}
	for tier in ["小","中","大"]:
		var all_valid := true
		var extra_valid := true
		var different := {}
		for seed_value in 40:
			var ex := fresh(seed_value)

			var options := ex.loot_options(tier)
			all_valid = all_valid and options.size() == (2 if tier == "小" else 3) and options.any(func(o): return o.kind == "gold") and options.any(func(o): return o.kind == "glyphs")
			var seen := {}
			for o in options:
				var key := ex._loot_key(o)
				all_valid = all_valid and not seen.has(key)
				seen[key] = true
				diversity[str(o.kind)] = true
				different[JSON.stringify(options)] = true
			if tier == "大": all_valid = all_valid and options.any(func(o): return o.kind in ["seal", "relic"])
			ex.seals = ["拓本"]
			var extra := ex.loot_options(tier)
			extra_valid = extra_valid and extra.size() == (3 if tier == "小" else 4)
		check(all_valid, tier + "赏保证金币/字、数量、去重和大赏特色")
		check(extra_valid, tier + "赏拓本额外选项完整")
		check(different.size() > 1, tier + "赏跨种子有变化")
	check(diversity.has("intel") and not diversity.has("plate4") and diversity.has("seal"), "情报与印章可达，没有无效扩版奖励")
	var a := fresh(81); var ao := a.loot_options("大")
	var b := fresh(81)
	check(JSON.stringify(ao) == JSON.stringify(b.loot_options("大")), "同种子奖励可复现")
	a = fresh(10); a.seals.assign(Expedition.SEALS.keys()); GameState.relics.assign(Relics.DEFS.keys())
	var exhausted := a.loot_options("大")
	check(exhausted.size() == 4 and not exhausted.any(func(o): return o.kind in ["seal", "relic"]), "印章遗物集齐后有有效候补，拓本仍加一项")
	check(a.loot_options("无效").is_empty(), "无效赏级别不生成奖励")
	a = fresh(21)
	var loot_cell := -1
	for k in a.m.node:
		if a.m.node[k].t == "小" and not a.sealed(k): loot_cell = k; break
	check(loot_cell >= 0, "有可测试的赏")
	a.pos = loot_cell; a.enter_cell()
	var snapshot := JSON.stringify(a.top_panel().options)
	var state: int = a.rng.state
	for i in 8: a.top_panel()
	check(JSON.stringify(a.top_panel().options) == snapshot and a.rng.state == state, "已打开的奖励不会刷新重抽")
	var gold_before := GameState.gold
	var index: int = a.top_panel().options.map(func(o): return o.kind).find("gold")
	a.choose_loot(index)
	check(GameState.gold == gold_before + 8 and a.taken.has(loot_cell), "实际可选金币并正确结算8")
	for act in [1,2,3]:
		a = fresh(19); a.act = act
		for kind in ["foe","elite","boss","ambush"]:
			var f := {"kind":kind,"k":12,"name":"旧主题名","g":"旧","debuff":""}
			a.fight = f.duplicate(true)
			var old_fight := a.fight.duplicate(true)
			var rng_state: int = a.rng.state; var boss_state: int = a.boss_rng.state; var relic_state: int = a.relic_rng.state
			var info := a.encounter_info(f)
			check(info.enemy.id == a.battle_node().enemies[0].id, "预告等于实际开战：%d/%s" % [act,kind])
			a.fight = old_fight.duplicate(true)
			for i in 6: a.encounter_info(f)
			check(a.fight == old_fight and a.rng.state == rng_state and a.boss_rng.state == boss_state and a.relic_rng.state == relic_state, "预览只读：%d/%s" % [act,kind])
			check(info.time.contains("%d步" % (1 if kind == "ambush" else 2)) if kind != "boss" else info.time.contains("不能再探索"), "耗时/首领封层说明准确")
	a = fresh(55)
	a.seals = ["朱笔","镇纸","蒲团"]
	var boss := {"kind":"boss","k":a.boss,"name":"旧首领","g":"旧","debuff":"热度"}
	var info := a.encounter_info(boss)
	check(info.hp == 82 and info.rewards.contains("金币+6") and info.rewards.contains("墨+1"), "首领朱笔生命与胜利额外收益")
	check(info.rewards.contains("印章位已满") and not info.rewards.contains("战利品"), "首领满印章提示替换且不虚报三选一")
	check(a.encounter_info({"kind":"elite","k":12}).rewards.contains("3选1"), "战利品三选一")
	b = fresh(34); b.fight = boss.duplicate()
	var old_gold := GameState.gold; var old_ink := b.ink
	var payout := b.encounter_rewards(b.fight)
	b.finish_battle(true)
	check(GameState.gold == old_gold + int(payout.gold) and b.ink == old_ink + int(payout.ink), "预告额外金币与回墨等于实际胜利结算")
	check(b.boss_down and b.busy() and b.panels.any(func(panel): return panel.kind == "act_end"), "首领胜利直接封层结算")
	# Real map and encounter panel exercise all three visual states.
	Router.host = self
	GameState.expedition = a
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await frames(8)
	var screen: Control = Router.current
	a.fight = boss
	screen.refresh(); await frames()
	var foe_cell := -1
	for k in a.m.node:
		if a.m.node[k].t == "敌" and not a.m.mech.has(k) and not a.m.obst.has(k): foe_cell = k; break
	check(foe_cell >= 0, "找到明敌格")
	a.explored[foe_cell] = true; a.visible[foe_cell] = true
	var enemy := a.encounter_enemy("foe", foe_cell)
	var button: Button = screen._map_cell(foe_cell)
	check(button.text == enemy.glyph and button.tooltip_text.contains(enemy.name) and button.tooltip_text.contains("耗2步"), "明敌格显示实际字形、怪名和耗时")
	button.free()
	a.visible.erase(foe_cell)
	button = screen._map_cell(foe_cell)
	check(button.tooltip_text.contains(enemy.name), "已探索明敌保留信息")
	button.free(); a.explored.erase(foe_cell)
	button = screen._map_cell(foe_cell)
	check(not button.tooltip_text.contains(enemy.name), "未探索迷雾不泄漏怪物身份")
	button.free()
	var body := labels(screen._event_box)
	check(body.contains("对校官") and body.contains("82") and body.contains("朱笔") and body.contains("位置减益"), "战前显示实际首领、生命与位置减益")
	check(not body.contains("首领词条：") and not body.contains("本幕结束。"), "战前不显示旧词条和立即结幕说明")
	var start_buttons: Array = screen._event_box.get_children().filter(func(c): return c is Button and c.text == "开战")
	check(start_buttons.size() == 1 and start_buttons[0].get_global_rect().end.y <= screen._event_box.get_parent().get_global_rect().end.y and body.contains("行动循环") and body.contains("红签"), "开战按钮首屏可见且机制说明完整")
	if OS.get_cmdline_user_args().has("--capture"):
		RenderingServer.force_draw(false)
		check(get_viewport().get_texture().get_image().save_png("/private/tmp/huozi-options-boss.png") == OK, "保存首领战前截图")
	a.fight = {"kind":"ambush","k":12,"amb":0,"name":"伏兵","g":"伏"}
	screen.refresh(); await frames()
	body = labels(screen._event_box)
	check(body.contains("敌人先手") and body.contains("耗1步") and body.contains("解封"), "伏兵准确显示开场行动、耗时与解封收益")
	a.fight = {}; a.seals.clear(); a.panels.clear()
	a.push_panel({"kind":"loot","tier":"小","options":a.loot_options("小")})
	screen.refresh(); await frames()
	body = labels(screen._event_box)
	check(body.contains("+8") and body.contains("字："), "奖励真界面同时展示字和金币")
	if OS.get_cmdline_user_args().has("--capture"):
		RenderingServer.force_draw(false)
		check(get_viewport().get_texture().get_image().save_png("/private/tmp/huozi-options-loot.png") == OK, "保存奖励截图")
	check(checks + 1 == (69 if OS.get_cmdline_user_args().has("--capture") else 67), "测试完整执行")
	print("[expedition_options_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-failures,failures,checks])
	get_tree().quit(1 if failures > 0 else 0)
