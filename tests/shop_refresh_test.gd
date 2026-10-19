extends Node
## 商店刷新：花 5 金币换一批字和遗物，服务保留；金币不够不能刷。远征商店与旧版商店都测。

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[shop_refresh_test] FAIL: " + message)


func _ready() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	add_child(host)
	Router.host = host

	var ex := Expedition.start(11)
	ex.push_panel({"kind": "shop"})
	var before: Array = ex.shop_offers().duplicate(true)
	var heal_index := before.find_custom(func(o): return o.kind == "heal")
	GameState.gold = 100
	check(ex.buy(heal_index), "先买掉治疗")
	var gold := GameState.gold
	var refreshed := 0
	var changed := false
	for i in 4:
		var old_glyphs: Array = ex.shop_offers().filter(func(o): return o.kind == "glyph").map(func(o): return o.glyph)
		check(ex.refresh_shop(), "刷新成功")
		refreshed += 1
		var new_glyphs: Array = ex.shop_offers().filter(func(o): return o.kind == "glyph").map(func(o): return o.glyph)
		changed = changed or new_glyphs != old_glyphs
	var offers: Array = ex.shop_offers()
	check(GameState.gold == gold - Expedition.SHOP_REFRESH_COST * refreshed, "每次刷新扣 %d 金币" % Expedition.SHOP_REFRESH_COST)
	check(changed, "刷新后换了字")
	check(offers.filter(func(o): return o.kind == "glyph").size() == 3, "刷新后补满三枚字")
	check(not offers.any(func(o): return o.kind == "heal") and offers.any(func(o): return o.kind == "remove") and offers.any(func(o): return o.kind == "gild"), "已买的服务不会被刷回来，没买的保留")
	GameState.gold = Expedition.SHOP_REFRESH_COST - 1
	check(not ex.refresh_shop() and GameState.gold == Expedition.SHOP_REFRESH_COST - 1, "金币不够不能刷新")
	ex.pop_panel()
	GameState.gold = 100
	check(not ex.refresh_shop(), "不在商店里不能刷新")

	GameState.start_new_run("v03")
	GameState.gold = 20
	Router.goto("res://src/screens/shop_screen.gd")
	await get_tree().process_frame
	var shop: Control = Router.current
	check(shop._hud.tertiary_button != null and not shop._hud.tertiary_button.disabled, "旧版商店有刷新按钮")
	var services: Array = shop._offers.filter(func(o): return o.kind != "buy_char")
	shop._refresh_stock()
	check(GameState.gold == 20 - Expedition.SHOP_REFRESH_COST, "旧版商店刷新扣 5 金币")
	check(shop._offers.filter(func(o): return o.kind == "buy_char").size() == 3, "旧版商店刷出三枚字")
	check(shop._offers.filter(func(o): return o.kind != "buy_char") == services, "旧版商店服务原样保留")
	GameState.gold = 4
	shop._refresh()
	check(shop._hud.tertiary_button.disabled, "金币不够时刷新按钮变灰")
	shop._refresh_stock()
	check(GameState.gold == 4, "金币不够点了也不扣钱")
	shop.queue_free()
	Music.stop()
	# 音频线程下一次混音才释放播放实例
	await get_tree().create_timer(0.3).timeout
	print("[shop_refresh_test] PASS=%d FAIL=%d TOTAL=%d" % [checks - failures, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
