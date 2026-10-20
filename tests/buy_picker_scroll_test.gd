extends Control
var checks := 0
var failures := 0
var screen: Control

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames(count := 8) -> void:
	for i in count: await get_tree().process_frame

func new_screen() -> void:
	GameState.start_new_run("v03")
	GameState.gold = 20
	var node := MapNodeData.new()
	node.enemies.append(Database.get_enemy("iron_seal"))
	screen = load("res://src/screens/battle_screen.gd").new()
	screen.setup({"node":node,"seed":7})
	size = get_viewport_rect().size
	screen.size = size
	add_child(screen)
	await frames()
	screen.battle.board.cells.fill(null)
	screen.battle.bag.clear(); screen.battle.discard.clear()

func picker() -> ChoiceOverlay:
	for child in screen.get_children():
		if child is ChoiceOverlay: return child
	return null

func place(glyph: String, x := 0) -> CharInstance:
	var inst := CharInstance.new(Database.get_character_by_glyph(glyph))
	screen.battle.board.set_xy(Vector2i(x,0),inst)
	return inst

func check_layout(overlay: ChoiceOverlay, count: int) -> void:
	var scroll: ScrollContainer = overlay.find_child("OptionsScroll",true,false)
	check(scroll != null and scroll.get_child(0).get_child_count() == count, "全部候选均保留在滚动区")
	check(overlay.get_viewport_rect().encloses(overlay._panel.get_global_rect()), "完整弹窗位于屏幕内")
	var cancel: Button = overlay.find_child("Option_%d" % count,true,false)
	check(not scroll.is_ancestor_of(cancel) and overlay.get_viewport_rect().encloses(cancel.get_global_rect()), "取消固定在滚动区外且始终可见")
	check(scroll.get_v_scroll_bar().visible and scroll.get_v_scroll_bar().max_value > scroll.size.y, "候选超出高度时显示可用滚动条")
	var last: Button = overlay.find_child("Option_%d" % (count-1),true,false)
	last.grab_focus()
	await frames()
	check(scroll.scroll_vertical > 0 and scroll.get_global_rect().intersects(last.get_global_rect()), "键盘焦点可滚动到最后一个候选")
	scroll.scroll_vertical = 0
	await frames()
	for i in 5:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = scroll.get_global_rect().get_center()
		get_viewport().push_input(wheel, true)
	await frames()
	check(scroll.scroll_vertical > 0, "鼠标滚轮可以下滑候选列表")
	scroll.scroll_vertical = 999999
	await frames()
	check(scroll.get_global_rect().intersection(last.get_global_rect()).size.y >= last.size.y - 2, "列表末尾候选可完整显示")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameState.set_meta("courtyard_preview", true)
	Settings.reduced_motion = true
	for window_size in [Vector2i(1280,720),Vector2i(844,390)]:
		get_window().size = window_size
		await frames()
		await new_screen()
		var source := place("购")
		for i in 50:
			var card := CharInstance.new(Database.get_character_by_glyph("火" if i % 2 == 0 else "击"))
			card.gilded = i % 3 == 0
			screen.battle.bag.append(card)
		screen._refresh_all()
		var before: Array = screen.battle.bag.duplicate()
		check(screen._choose_solo_bag([Vector2i.ZERO],{}), "购打开真实选字浮层")
		await frames()
		var overlay := picker()
		await check_layout(overlay,50)
		if OS.get_cmdline_user_args().has("--capture"):
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_png("/tmp/huozi-buy-picker-%d.png" % window_size.x)
		overlay.find_child("Option_50",true,false).pressed.emit()
		await frames()
		check(screen.battle.bag == before and screen.battle.board.get_xy(Vector2i.ZERO) == source and GameState.gold == 20 and screen._modal_count == 0 and not screen._solo_bag_picker_active, "取消不消耗字和金币，并恢复战斗交互")
		# 最后一个候选依然按原索引购买正确实体。
		var candidates: Array = screen.battle.solo_bag_candidates(source)
		var chosen: CharInstance = candidates.back()
		screen._choose_solo_bag([Vector2i.ZERO],{})
		await frames()
		overlay = picker()
		overlay.find_child("Option_49",true,false).pressed.emit()
		var deadline := Time.get_ticks_msec()+4000
		while screen._busy and Time.get_ticks_msec()<deadline: await frames(1)
		check(screen.battle.board.get_xy(Vector2i.ZERO) == chosen and not screen.battle.bag.has(chosen) and GameState.gold == 18 and screen._modal_count == 0, "滚动后选择末尾候选，实际购买正确实体且只支付一次")
		screen.queue_free(); await frames()
	# 购字从弃字堆选实体，也使用同样的限高列表。
	await new_screen()
	place("回"); place("购",1)
	for i in 40: screen.battle.discard.append(CharInstance.new(Database.get_character_by_glyph("防")))
	screen._refresh_all()
	var before_discard: Array = screen.battle.discard.duplicate()
	check(screen._choose_word_transfer([Vector2i.ZERO,Vector2i(1,0)],{}), "回购打开弃字实体列表")
	await frames()
	var overlay := picker()
	await check_layout(overlay,40)
	var cancel_event := InputEventKey.new()
	cancel_event.keycode = KEY_ESCAPE; cancel_event.pressed = true
	overlay._unhandled_key_input(cancel_event)
	await frames()
	check(screen.battle.discard == before_discard and GameState.gold == 20 and screen._modal_count == 0 and not screen._solo_bag_picker_active, "ESC取消回购不消耗资源或锁住战斗")
	screen.queue_free(); await frames()
	print("[buy_picker_scroll_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-failures,failures,checks])
	get_tree().quit(1 if failures else 0)
