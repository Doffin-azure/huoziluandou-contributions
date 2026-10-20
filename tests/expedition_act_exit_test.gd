extends Control
var checks := 0
var fails := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("[act_exit] " + label)

func fresh(act_no := 1) -> Expedition:
	var ex := Expedition.start(81)
	if act_no > 1: ex.load_act(act_no)
	GameState.player_hp = 20
	GameState.gold = 50
	ex.fight = {"kind":"boss","k":ex.boss,"name":"测试首领","g":"首","debuff":""}
	return ex

func labels(node: Node) -> String:
	var text := str(node.get("text")) if node is Label or node is Button else ""
	for child in node.get_children(): text += "\n" + labels(child)
	return text

func frames(n := 6) -> void:
	for i in n: await get_tree().process_frame

func _ready() -> void:
	await frames()
	var ex := fresh()
	ex.push_panel({"kind":"rest"}); ex.push_panel({"kind":"shop","offers":[]})
	var ink_before := ex.ink
	var result := ex.finish_battle(true)
	check(not result.reward and ex.boss_down and ex.top_panel().kind == "act_end", "首领胜利自动结算，不经过普通战利品")
	check(ex.panels.size() == 1 and ex.alerts.is_empty(), "清除旧休息商店面板和过时提示")
	check(ex.busy() and not ex.can_confront() and not ex.can_finish_act(), "封层时不可迎战或重复结幕")
	var at := ex.t; var original_pos := ex.pos; var original_gold := GameState.gold
	var moved := false
	for cell in MapGen.nbrs(ex.pos): moved = ex.move(cell) or moved
	ex.advance(30)
	check(not moved and ex.pos == original_pos and ex.t == at, "首领后移动与时间完全冻结")
	var taken := ex.taken.duplicate()
	for cell in ex.m.node:
		if ex.m.node[cell].t == "休": ex.pos = cell; ex.enter_cell(); break
	check(ex.top_panel().kind == "act_end" and ex.taken == taken and GameState.gold == original_gold, "不能用进入格子重新打开休息点或拿奖励")
	for cell in ex.m.glyph: ex.pos = cell; break
	check(not ex.pickup(), "不能直接拾取遗漏散字")
	GameState.add_character(Database.get_character_by_glyph("火"))
	var deck_before := GameState.deck.duplicate()
	check(not ex.has_method("tray_to_deck") and not ex.has_method("discard"), "字匣调配与丢弃接口已移除")
	ex.finish_battle(true)
	check(ex.panels.size() == 1 and GameState.gold == original_gold, "重复胜利回调不重复奖励")
	check(ex.act_supply() == {"gold":12,"heal":8,"ink":1}, "一幕有限补给数值")
	check(not ex.has_method("act_settlement"), "无版面利息返利入口")
	var old_theme: String = ex.m.tn
	ex.next_act()
	check(ex.act == 2 and not ex.boss_down and ex.m.tn != old_theme and ex.t == 0, "结算进入二层、解除封层、换地图")
	check(GameState.gold == 68 and GameState.player_hp == 28 and ex.ink == ink_before + 2, "首领铜钱6、回墨1与一幕补给各发放一次")
	check(GameState.deck == deck_before, "字袋实体跨层保留")
	var paid_gold := GameState.gold; var paid_hp := GameState.player_hp
	ex.next_act()
	check(ex.act == 2 and GameState.gold == paid_gold and GameState.player_hp == paid_hp, "双击进入下一幕不会重复补给")
	ex = fresh(2); ex.finish_battle(true)
	check(ex.act_supply() == {"gold":16,"heal":10,"ink":1}, "二幕有限补给数值")
	ex.next_act()
	check(ex.act == 3 and GameState.gold == 72 and GameState.player_hp == 30, "二层结算正确进入三层")
	ex = fresh(); ex.seals = ["镇纸","夜灯","更漏"]
	ex.finish_battle(true)
	check(ex.top_panel().kind == "seal_swap" and ex.panels[0].kind == "act_end", "印章满位先替换，结算面板保留在下方")
	ex.next_act()
	check(ex.act == 1 and GameState.gold == 56, "印章未处理时不能跳过并领取补给")
	ex.swap_seal(-1)
	check(ex.top_panel().kind == "act_end" and ex.busy(), "放弃新印章后仍封层，只能结算")
	ex.next_act()
	check(ex.act == 2 and GameState.gold == 68, "印章处理后进入二层并发补给")
	ex = fresh(); GameState.player_hp = GameState.player_max_hp - 1
	ex.finish_battle(true); ex.next_act()
	check(GameState.player_hp == GameState.player_max_hp, "幕间恢复不超过生命上限")
	ex = fresh(3); ex.finish_battle(true)
	check(ex.act_supply() == {"gold":0,"heal":0,"ink":0} and ex.over and ex.won and ex.panels.is_empty(), "第三幕直接通关，没有下一层补给或幕间面板")
	ex.next_act()
	check(ex.over and ex.won and ex.act == 3 and GameState.gold == 56, "第三幕直接完成远征，无第四层或重复补给")
	ex = fresh(); ex.finish_battle(false)
	check(ex.over and not ex.boss_down and ex.panels.is_empty(), "首领战败不发结算奖励")
	var wake_ok := true
	for seed_value in 24:
		var map := MapGen.generate(seed_value * 17 + 1)
		wake_ok = wake_ok and int(map.wake) >= 8 and int(map.wake) <= 11 and int(map.buffer) >= 7 and int(map.buffer) <= 10
	check(wake_ok, "自然惊动8–11步、缓冲7–10步")
	# Actual map screen must expose next layer immediately and disable map controls.
	ex = fresh(); ex.seals = ["朱笔","字印","镇纸"]
	ex.finish_battle(true)
	GameState.expedition = ex
	Router.host = self
	Router.goto("res://src/screens/expedition_map_screen.gd")
	await frames(10)
	var screen: Control = Router.current
	var body := labels(screen._event_box)
	var next_buttons: Array = screen._event_box.get_children().filter(func(c): return c is Button and c.text == "进入第 2 幕")
	check(body.contains("本层已结束") and body.contains("未拿") and next_buttons.size() == 1 and next_buttons[0].get_global_rect().end.y <= screen._event_box.get_parent().get_global_rect().end.y, "胜利后自动结算，进入二层按钮首屏可见")
	check(body.contains("12") and body.contains("8") and body.contains("补给仅发放一次"), "结算展示有限补给和一次性口径")
	check(screen._confront_btn.disabled and screen._map_grid.get_children().all(func(button): return button.disabled), "地图格与迎战按钮禁用")
	check(not body.contains("可以继续探索") and not labels(screen._boss_bar_label).contains("慢慢拿"), "当前界面不残留清图说明")
	if OS.get_cmdline_user_args().has("--capture"):
		RenderingServer.force_draw(false)
		check(get_viewport().get_texture().get_image().save_png("/private/tmp/huozi-act-exit.png") == OK, "保存封层结算截图")
	ex.next_act(); screen.refresh(); await frames()
	check(not ex.boss_down and screen._confront_btn.text == "迎战首领" and not labels(screen._event_box).contains("本层已结束"), "二层界面恢复探索")
	check(checks + 1 == (32 if OS.get_cmdline_user_args().has("--capture") else 31), "测试完整执行")
	print("[expedition_act_exit_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-fails,fails,checks])
	get_tree().quit(1 if fails else 0)
