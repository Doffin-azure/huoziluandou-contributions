extends "res://tests/achievement_system_test.gd"
const RUN = preload("res://src/expedition/room_run_state.gd")

func buy_offer(run: RefCounted, index: int) -> Dictionary:
	for action in run.legal_actions():
		if action.type == "shop_buy" and int(action.index) == index: return run.apply(action)
	return {"ok":false}

func _ready() -> void:
	Achievements.test_enabled = true
	Achievements.autosave = false
	storage = "user://achievement-run-test-%d.json" % Time.get_ticks_usec()
	Achievements.storage_path = storage
	var path := storage.trim_suffix(".json") + ".tres"
	fresh()
	var run := RUN.new()
	run.reset({"seed":17,"layout":"node_graph"})
	run.autosave = false
	Achievements.start_run("courtyard")
	var id: String = Achievements.run_id
	GameState.gold = 999
	run._start_shop()
	check(run.shop_offers.all(func(o): return o.has("achievement_offer")), "真实商店的商品有稳定交易ID")
	var rng_state: int = GameState.rng.state
	check(run.save_run(path) == OK, "真实冒险快照可保存")
	var purchase := buy_offer(run, 0)
	check(purchase.ok and Achievements.progress("shop_5") == 1, "真实商店买字提交后统计")
	Achievements.autosave = true
	check(Achievements.save_progress() == OK, "账号成就保存到独立测试文件")
	Achievements.autosave = false
	var loaded = RUN.restore(path, true)
	check(loaded != null and Achievements.run_id == id and GameState.rng.state == rng_state, "恢复冒险会话不改变玩法随机数")
	if loaded != null:
		loaded.autosave = false
		check(buy_offer(loaded, 0).ok and Achievements.progress("shop_5") == 1, "读取购买前旧档不会刷同一交易进度")
		check(buy_offer(loaded, 0).ok and Achievements.progress("shop_5") == 2, "另一件真实商品正常统计")
		var index: int = loaded.shop_offers.find_custom(func(o): return o.kind == "remove")
		check(buy_offer(loaded, index).ok and Achievements.progress("shop_5") == 2, "待选字服务尚未完成时不计购买")
		check(not loaded.apply({"type":"pick","glyph":"不存在"}).ok and Achievements.progress("shop_5") == 2, "失败服务选择不计购买")
		var glyph: String = str(loaded.pending_glyphs[0])
		check(loaded.apply({"type":"pick","glyph":glyph}).ok and Achievements.progress("shop_5") == 3, "实际完成删字服务计一件")
		var saved_stock: Array = loaded.shop_offers.duplicate(true)
		GameState.gold = 0
		check(not buy_offer(loaded, 0).ok and loaded.shop_offers == saved_stock and Achievements.progress("shop_5") == 3, "金币不足不统计也不移除商品")
		loaded.phase = "rest"
		check(loaded.apply({"type":"rest","kind":"upgrade"}).ok and loaded.phase == "rest_choose", "休整镀金先等待选字")
		check(Achievements.progress("first_gild") == 0, "尚未选字不记镀金")
		check(loaded.apply({"type":"pick","glyph":str(loaded.pending_glyphs[0])}).ok and Achievements.is_unlocked("first_gild"), "休整真实镀金入口接入")
		check(Achievements.progress("nodes_20") == 1, "休整实际结算记录节点")
		loaded.current_room = str(loaded.graph.rooms.start.next[0])
		loaded.phase = "event"
		loaded.event_data = {"id":"achievement_fixture_event","options":[{"text":"继续","effects":[]}]}
		check(not loaded.apply({"type":"event","index":9}).ok and Achievements.progress("events_10") == 0, "无效事件选择不统计")
		check(loaded.apply({"type":"event","index":0}).ok and Achievements.progress("events_10") == 1, "真实事件完成选择后统计不同事件")
		check(Achievements.progress("nodes_20") == 2, "事件完成同时统计旅途节点")
		loaded.phase = "act_end"; GameState.act_index = 3
		check(loaded.apply({"type":"next_act"}).ok and Achievements.is_unlocked("first_clear"), "最终幕真实完成入口解锁通关")
		loaded.phase = "act_end"
		loaded.apply({"type":"next_act"})
		check(Achievements.progress("first_clear") == 1, "重复通关回调不多计")
	# 接入前冒险存档：补存稳定会话，不补算已经过的节点。
	Achievements.suspend_run()
	var old := RUN.new()
	old.reset({"seed":19,"layout":"node_graph"}); old.autosave = false
	old._start_shop()
	check(old.save_run(path) == OK, "模拟无成就快照的旧冒险")
	var old_restored = RUN.restore(path, true)
	check(old_restored != null and Achievements.eligible(), "旧冒险恢复后可以正常取得成就")
	check(old_restored.shop_offers.all(func(o): return o.has("achievement_offer")), "旧档中的既有商品补发稳定交易ID")
	var migrated_id: String = Achievements.run_id
	var migrated_snapshot = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(migrated_snapshot.run.achievements.run_id == migrated_id, "旧存档立即补存稳定会话ID")
	check(Achievements.progress("nodes_20") == 2, "不补算旧版本无明细的历史")
	old_restored = RUN.restore(path, true)
	check(Achievements.run_id == migrated_id, "再次恢复旧档沿用同一会话")
	old_restored.autosave = false
	GameState.player_hp = 0
	old_restored._complete_node()
	check(old_restored.phase == "defeat" and not Achievements.eligible(), "事件失血死亡停止本局统计")
	# 从磁盘重建账号仍保留已解锁成果。
	Achievements.autosave = true
	check(Achievements.save_progress() == OK, "退出前写入最新账号进度")
	Achievements.profile = {"version":1,"unlocked":{},"lifetime":{},"best":{},"sessions":{}}
	Achievements.load_progress()
	check(Achievements.is_unlocked("first_gild") and Achievements.is_unlocked("first_clear"), "真正重载账号文件保留跨局成果")
	check(Achievements._valid_save(Achievements.profile), "嵌套会话与统计存档符合契约")
	Achievements.suspend_run()
	for file in [storage,storage+".tmp",storage+".bak",path]:
		if FileAccess.file_exists(file): DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("[achievement_run_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-failures,failures,checks])
	get_tree().quit(1 if failures else 0)
