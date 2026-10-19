extends Control
var checks := 0
var fails := 0
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("[relic_loot] " + note)

func frames(n := 5) -> void:
	for i in n: await get_tree().process_frame

func labels(n: Node) -> String:
	var text := str(n.get("text")) if n is Label or n is Button else ""
	for child in n.get_children(): text += "\n" + labels(child)
	return text

func _ready() -> void:
	await frames()
	var ex := Expedition.start(91)
	check(not ex.has_method("open_wish") and not ex.has_method("can_wish") and not ex.get_property_list().any(func(p): return p.name == "wish_used"), "许愿机接口、状态一并移除")
	check(ex.loot_relic_pool("小").is_empty() and ex.loot_relic_pool("无效").is_empty(), "小赏与无效赏级不投放遗物")
	check(ex.loot_relic_pool("中").all(func(id): return Relics.TIER[id] <= 2) and ex.loot_relic_pool("大").size() == Relics.DEFS.size(), "中赏常见/少见，大赏全部档次")
	var reached := {"中":{},"大":{}}
	for bonus in [false,true]:
		ex.seals = ["拓本"] if bonus else []
		for tier in ["小","中","大"]:
			var hits := 0
			var missing := 0
			for seed_value in 80:
				ex.rng.seed = seed_value * 7 + 13
				ex.relic_rng.seed = seed_value * 31 + 91
				var opts := ex.loot_options(tier)
				check(opts.size() == (2 if tier == "小" else 3) + (1 if bonus else 0) and opts.any(func(o): return o.kind == "gold") and opts.any(func(o): return o.kind == "glyphs"), "赏选项数、金币与字保底保持")
				var unique := {}
				for o in opts: unique[ex._loot_key(o)] = true
				check(unique.size() == opts.size(), "每份奖励去重")
				if tier == "大": check(opts.any(func(o): return o.kind in ["seal","relic"]), "大赏保证遗物/印章特色位")
				for o in opts:
					if o.kind == "relic":
						hits += 1
						check(tier != "小" and not GameState.has_relic(o.relic) and ex.loot_relic_pool(tier).has(o.relic), "遗物候选符合赏档次且未拥有")
						reached[tier][o.relic] = true
				if not opts.any(func(o): return o.kind == "relic"): missing += 1
			if tier == "小": check(hits == 0, "小赏从不出遗物")
			else: check(hits > 0 and missing > 0, "遗物真正可出现，也允许其他奖励而非必选")
	check(reached["中"].size() >= 8 and reached["大"].keys().any(func(id): return Relics.TIER[id] == 3), "中赏遗物类型多样，大赏稀有档实际可达")
	# Isolated relic RNG and repeated rendering must not change an opened chest.
	ex.seals.clear(); ex.rng.seed = 81; ex.relic_rng.seed = 123
	var a := ex.loot_options("大")
	ex.rng.seed = 81; ex.relic_rng.seed = 123
	check(a == ex.loot_options("大"), "两条种子相同，完整奖励可复现")
	var a_key := ex._loot_key({"kind":"relic","relic":"slab"})
	check(a_key != ex._loot_key({"kind":"relic","relic":"press"}), "不同遗物拥有不同去重键")
	GameState.relics.assign(Relics.DEFS.keys())
	for tier in ["小","中","大"]:
		var options := ex.loot_options(tier)
		check(options.size() == (2 if tier == "小" else 3) and not options.any(func(o): return o.kind == "relic"), "全遗物持有后自动回退到有效奖励")
	GameState.relics.clear()
	GameState.relics.assign(ex.loot_relic_pool("中"))
	check(ex.loot_relic_pool("中").is_empty() and ex.loot_relic_pool("大").size() == Relics.TIER.values().filter(func(t): return int(t) == 3).size() and not ex.loot_options("中").any(func(o): return o.kind == "relic"), "中档耗尽不越级给稀有，大赏仍可给稀有")
	# Opening loot grants the chosen relic exactly once and handles bind/pickup effects.
	ex = Expedition.start(32)
	var cell := ex.pos
	var gold := GameState.gold
	ex.panels = [{"kind":"loot","tier":"大","options":[{"kind":"relic","relic":"slab"},{"kind":"gold","gold":25}]}]
	ex.choose_loot(0)
	check(GameState.has_relic("slab") and GameState.gold == gold and ex.taken.has(cell) and ex.top_panel().get("kind","") == "relic_bind", "只领取所选遗物，奖励格消耗，绑定面板正常")
	check(ex.bind_relic(GameState.deck[0].id()) and GameState.relic_bound_inst("slab") != null and ex.panels.is_empty(), "绑定完成后回到探索")
	ex.choose_loot(0)
	check(GameState.relics.count("slab") == 1, "重复点击不重复发放")
	ex.panels = [{"kind":"loot","tier":"大","options":[{"kind":"relic","relic":"slab"},{"kind":"gold","gold":25}]}]
	ex.choose_loot(0)
	check(ex.top_panel().kind == "loot", "过期重复遗物不会吞掉整份奖励")
	ex.choose_loot(1)
	check(GameState.gold == gold + 25 and ex.panels.is_empty(), "过期遗物仍能改选其他奖励")
	ex.panels = [{"kind":"loot","tier":"中","options":[{"kind":"relic","relic":"fireman"}]}]
	ex.choose_loot(0)
	check(GameState.has_relic("fireman") and ex.tray.count("火") == 4, "开赏触发火种四枚火的拾取效果")
	# Only real on-map furnaces can convert two characters, and never grant a relic.
	ex.m = MapGen.generate(17,"熔铸坊")
	for k in ex.m.mech:
		if ex.m.mech[k].g == "炉": ex.pos = k; break
	var forge_cell := ex.pos
	ex.tray = ["击","强","力"]; ex.panels = [{"kind":"forge","k":forge_cell}]
	var before: Array = GameState.relics.duplicate()
	check(not ex.forge(0,0) and not ex.forge(-1,1) and ex.tray == ["击","强","力"], "非法选择不消耗材料")
	check(ex.forge(0,1) and ex.tray.size() == 2 and ex.tray[0] == "力" and GameState.relics == before and ex.used[forge_cell] == 1, "熔炉仅消耗两字，保留第三枚，不产遗物")
	ex.panels = [{"kind":"forge","k":forge_cell}]
	check(not ex.forge(0,1), "熔炉一次性且不可绕过")
	ex.panels = [{"kind":"forge","k":-1}]
	check(not ex.forge(0,1), "旧许愿机虚拟熔炉编号失效")
	ex.panels.clear()
	# Actual map/reward UI, including the relic option description and bind flow.
	GameState.expedition = ex
	Router.host = self
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await frames(8)
	var screen: Control = Router.current
	check(not labels(screen).contains("许愿"), "实际地图不存在许愿机入口或残留提示")
	ex.panels = [{"kind":"loot","tier":"大","options":[{"kind":"glyphs","glyphs":["击"]},{"kind":"relic","relic":"fertilizer"},{"kind":"gold","gold":25}]}]
	screen.refresh(); await frames()
	var body := labels(screen._event_box)
	check(body.contains("遗物「蔓生墨」") and body.contains("繁殖") and body.contains("+25") and body.contains("字："), "奖励界面显示遗物名字、完整效果与其他候选")
	var relic_buttons: Array = screen._event_box.get_children().filter(func(c): return c is Button and c.text.contains("蔓生墨"))
	check(relic_buttons.size() == 1 and not relic_buttons[0].disabled, "遗物奖励按钮可选")
	var viewport_width := get_viewport_rect().size.x
	check(screen._event_box.get_global_rect().end.x <= viewport_width and relic_buttons[0].get_global_rect().end.x <= viewport_width, "遗物长说明换行，不撑宽右侧面板")
	var saved: Array = GameState.relics.duplicate()
	GameState.relics.assign(Relics.DEFS.keys()); screen._on_stats_changed(); await frames()
	check(screen._relic_label.text.contains("15件") and screen._relic_label.tooltip_text.contains("蔓生墨") and screen._relic_label.get_global_rect().end.x <= viewport_width, "遗物数量多时摘要显示、完整效果可悬停阅读")
	GameState.relics.assign(saved); screen.refresh(); await frames()
	# Refresh rebuilt reward controls.
	relic_buttons = screen._event_box.get_children().filter(func(c): return c is Button and c.text.contains("蔓生墨"))
	if OS.get_cmdline_user_args().has("--capture"):
		RenderingServer.force_draw(false)
		check(get_viewport().get_texture().get_image().save_png("/private/tmp/huozi-relic-loot.png") == OK,"保存大赏遗物界面截图")
	relic_buttons[0].pressed.emit(); await frames()
	check(GameState.has_relic("fertilizer") and ex.top_panel().kind == "relic_bind" and labels(screen._event_box).contains("蔓生墨"), "真实点击奖励转到正确的绑定面板")
	print("[expedition_relic_loot_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-fails,fails,checks])
	get_tree().quit(1 if fails else 0)
