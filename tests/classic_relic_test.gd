extends Node
## 经典模式遗物：精英给 1 件、首领回血后二选一、事件可能出遗物、商店 45 金币 1 件候选。

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[classic_relic_test] FAIL: " + message)


func _frames(n := 4) -> void:
	for i in n: await get_tree().process_frame


func _overlay(of: Node, type) -> Node:
	for c in of.get_children():
		if is_instance_of(c, type):
			return c
	return null


func _node(type: MapNodeData.Type) -> MapNodeData:
	var n := MapNodeData.new()
	n.type = type
	return n


## 只留下 keep 里的遗物没拥有，方便控制候选
func _own_all_but(keep: Array) -> void:
	GameState.relics.clear()
	GameState.relic_binds.clear()
	for id in Relics.DEFS:
		if not keep.has(id):
			GameState.relics.append(id)


func _ready() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	Router.host = host

	# 精英：直接给 1 件
	GameState.start_new_run("v03")
	Router.goto("res://src/screens/reward_screen.gd", {"node": _node(MapNodeData.Type.ELITE)})
	await _frames()
	var choice: ChoiceOverlay = _overlay(Router.current, ChoiceOverlay)
	check(choice != null and choice.cfg.options.size() == 1, "精英战后弹出 1 件遗物")
	var before := GameState.relics.size()
	choice._on_choose(0)
	await _frames()
	if _overlay(Router.current, CollectionOverlay) != null:
		_overlay(Router.current, CollectionOverlay)._close()
		await _frames()
	check(GameState.relics.size() == before + 1, "精英遗物入手")
	check(Router.current_path.ends_with("reward_screen.gd") and not Router.current._options.is_empty(), "拿完遗物照常选字")

	# 首领：回 30% 气血，二选一
	GameState.start_new_run("v03")
	GameState.player_hp = GameState.player_max_hp - 50
	var hp := GameState.player_hp
	Router.goto("res://src/screens/reward_screen.gd", {"node": _node(MapNodeData.Type.BOSS)})
	await _frames()
	check(GameState.player_hp == hp + int(round(GameState.player_max_hp * 0.3)), "首领战后回复 30% 气血")
	choice = _overlay(Router.current, ChoiceOverlay)
	check(choice != null and choice.cfg.options.size() == 2, "首领战后遗物二选一")
	choice._on_choose(1)
	await _frames()
	if _overlay(Router.current, CollectionOverlay) != null:
		_overlay(Router.current, CollectionOverlay)._close()
		await _frames()
	check(GameState.relics.size() == 1, "首领遗物入手 1 件")
	Router.goto("res://src/screens/reward_screen.gd", {"node": _node(MapNodeData.Type.BOSS), "relic_done": true})
	await _frames()
	check(_overlay(Router.current, ChoiceOverlay) == null, "已发过遗物的奖励页不重复发")

	# 第三幕首领后直接通关，不再发遗物、不回血
	GameState.start_new_run("v03")
	GameState.act_index = 3
	GameState.player_hp = 10
	Router.goto("res://src/screens/reward_screen.gd", {"node": _node(MapNodeData.Type.BOSS)})
	await _frames()
	check(_overlay(Router.current, ChoiceOverlay) == null and GameState.player_hp == 10, "最后一幕首领不发遗物")

	# 绑定类遗物：关掉选择窗就随机绑定
	GameState.start_new_run("v03")
	_own_all_but(["slab"])
	var done := {"id": "-"}
	RelicRewardFlow.grant(Router.current, "slab", func(id): done.id = id)
	await _frames()
	var picker: CollectionOverlay = _overlay(Router.current, CollectionOverlay)
	check(picker != null, "绑定类遗物弹出字袋选择")
	picker._close()
	await _frames()
	check(done.id == "slab" and GameState.relic_binds.has("slab"), "关闭选择窗时随机绑定")

	# 商店：1 件遗物，45 金币
	GameState.start_new_run("v03")
	_own_all_but(["strike", "breach"])
	GameState.gold = 100
	Router.goto("res://src/screens/shop_screen.gd")
	await _frames()
	var shop: Control = Router.current
	var relics: Array = shop._offers.filter(func(o): return o.kind == "relic")
	check(relics.size() == 1 and relics[0].price == 45, "商店有 1 件遗物，45 金币")
	var index: int = shop._offers.find(relics[0])
	var id: String = relics[0].relic
	shop._buy(index)
	await _frames()
	check(GameState.has_relic(id) and GameState.gold == 55 and not shop._offers.any(func(o): return o.kind == "relic"), "买下遗物扣 45 金币，货架清空")
	shop._refresh_stock()
	var refreshed: Array = shop._offers.filter(func(o): return o.kind == "relic")
	check(refreshed.size() == 1 and refreshed[0].relic != id, "刷新补上一件没有的遗物")

	# 事件：有时多一个遗物选项，选了就入手并离开
	var found := false
	for seed_value in 40:
		GameState.start_new_run("v03")
		GameState.rng.seed = seed_value
		Router.goto("res://src/screens/event_screen.gd")
		await _frames(2)
		var ev: Control = Router.current
		var at: int = ev._event.options.find_custom(func(o): return o.has("relic"))
		if at < 0:
			continue
		found = true
		var relic: String = ev._event.options[at].relic
		ev._choose(at)
		await _frames()
		if _overlay(Router.current, CollectionOverlay) != null:
			_overlay(Router.current, CollectionOverlay)._close()
			await _frames()
		check(GameState.has_relic(relic) and Router.current_path.ends_with("map_screen.gd"), "事件遗物入手并回到地图")
		break
	check(found, "事件会出现遗物选项")

	if is_instance_valid(Router.current): Router.current.queue_free()
	Music.stop()
	# 音频线程下一次混音才释放播放实例
	await get_tree().create_timer(0.3).timeout
	print("[classic_relic_test] PASS=%d FAIL=%d TOTAL=%d" % [checks - failures, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
