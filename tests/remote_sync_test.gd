extends Control
## Verify local relic art and shop controls against the new remote route owner.
const RUN := preload("res://src/expedition/room_run_state.gd")
const SAVE := "user://remote-sync-regression.tres"
const QA := "res://docs/qa/remote-sync-2026-10-19/"
var passed := 0
var failed := 0


func check(ok: bool, text: String) -> void:
	if ok: passed += 1; print("PASS ", text)
	else: failed += 1; push_error(text)


func frames(n := 10) -> void:
	for _i in n: await get_tree().process_frame


func dialog() -> ChoiceOverlay:
	for child in Router.current.get_children():
		if child is ChoiceOverlay and not child.is_queued_for_deletion(): return child
	return null


func _ready() -> void:
	GameState.set_meta("courtyard_preview", true)
	Settings.reduced_motion = true
	SaveManager.enabled = false
	Router.host = self
	_run.call_deferred()


func _run() -> void:
	check(Relics.DEFS.size() == 38, "remote thirty-eight relic definitions remain available")
	check(RelicArt.TEXTURES.size() == 38, "thirty-eight authored icons are registered")
	for path in ["battle", "reward", "event", "rest", "shop", "title", "room_map", "event_board", "expedition_map", "glyph_graph"]:
		var script: GDScript = load("res://src/screens/%s_screen.gd" % path)
		check(script != null and script.can_instantiate(), path + " screen compiles after merge")
	var run := RUN.new()
	run.reset({"seed": 29})
	GameState.gold = 200
	for id in run.graph.rooms:
		if run.graph.rooms[id].kind == "shop":
			run.current_room = id
			break
	if not run.contents.has(run.current_room): run.contents[run.current_room] = {}
	run._start_shop()
	var stock: Array = run.shop_offers.filter(func(o): return o.kind == "relic")
	stock[0].relic = "buckler"
	stock[0].price = Relics.price("buckler")
	stock[1].relic = "chain"
	stock[1].price = Relics.price("chain")
	run._sync_content()
	Router.goto("res://src/screens/shop_screen.gd", {"room_run": true})
	await frames(20)
	var shop = Router.current
	check(shop._offers.filter(func(o): return o.kind == "buy_char").size() == 5, "new route shop retains five cards")
	check(shop._offers.filter(func(o): return o.kind == "relic").size() == 3, "new route shop retains three stocked relics")
	check(shop._showcase.stage.objects.size() == shop._offers.size(), "all stocked relic models render without empty shelf entries")
	var index: int = shop._offers.find_custom(func(o): return o.kind == "relic" and o.relic == "buckler")
	shop._open_relic_purchase(index)
	await frames()
	check(dialog() != null and dialog().cfg.relic_id == "buckler", "new route purchase confirmation uses preserved icon ID")
	dialog()._on_choose(1)
	await frames()
	check(GameState.has_relic("buckler") and GameState.gold == 165, "new route controller charges tier price and grants exactly the chosen relic")
	check(not run.shop_offers.any(func(o): return o.kind == "relic" and o.relic == "buckler"), "purchase removes the saved stock entry")
	shop._refresh_stock()
	await frames()
	check(GameState.gold == 160 and shop.refresh_cost() == 10 and run.shop_refresh_cost() == 10, "first physical refresh charges five in both UI and run controller")
	shop._refresh_stock()
	await frames()
	check(GameState.gold == 150 and shop.refresh_cost() == 15 and run.shop_refresh_cost() == 15, "second refresh charges ten and advances both next fees to fifteen")
	GameState.revive_charges = 1
	check(run.save_run(SAVE) == OK, "updated route saves with preserved inventory and shop fee")
	GameState.revive_charges = 0
	var restored = RUN.restore(SAVE)
	check(restored != null and restored.shop_refresh_cost() == 15 and GameState.has_relic("buckler"), "route resume preserves owned relic and refresh progression")
	check(GameState.revive_charges == 1, "new remote revival charges survive route resume")
	if OS.get_cmdline_user_args().has("--capture"):
		DirAccess.make_dir_recursive_absolute(QA)
		await frames()
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(QA + "shop.png") == OK, "archive merged physical shop")
	DirAccess.remove_absolute(SAVE)
	Router.release_host(self)
	print("[remote_sync_test] PASS=%d FAIL=%d TOTAL=%d" % [passed, failed, passed + failed])
	get_tree().quit(1 if failed else 0)
