extends Control
## 真实牌堆浏览、排序保密与桌面/触屏底栏回归。
var _pass := 0
var _fail := 0
var _screen: Control


func _ready() -> void:
	_run.call_deferred()


func _ok(value: bool, message: String) -> void:
	if value:
		_pass += 1
		print("  ✓ ", message)
	else:
		_fail += 1
		push_error(message)


func _frames(count := 8) -> void:
	for index in count: await get_tree().process_frame


func _overlay() -> BattlePileOverlay:
	for child in _screen.get_children():
		if child is BattlePileOverlay and not child.is_queued_for_deletion(): return child
	return null


func _shot(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await _frames()
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % name)


func _browse(id: String) -> BattlePileOverlay:
	await _frames(2) # 资源数量变化后，等待容器重新分配按钮命中区域。
	var position: Vector2 = _screen._pile_label.item_for(id).get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await _frames(1)
	await _frames()
	return _overlay()


func _run() -> void:
	get_window().size = Vector2i(1280, 720)
	await _frames()
	Router.host = self
	var stage := StudyStage.new()
	add_child(stage)
	Router.study_stage = stage
	GameState.start_new_run("v03")
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 7})
	_screen = Router.current
	await _frames(24)
	var hit := CharInstance.new(Database.get_character_by_glyph("击"))
	var hit2 := CharInstance.new(hit.data)
	var broken := CharInstance.new(Database.get_character_by_glyph("破"))
	var polluted := CharInstance.new(hit.data)
	polluted.pollutions.append("rush")
	var fused := CharInstance.new(hit.data)
	fused.fusion.append("破")
	fused.gilded = true
	_screen.battle.bag = [broken, hit, polluted, hit2, fused]
	_screen.battle.discard = [CharInstance.new(Database.get_character_by_glyph("火"))]
	_screen._refresh_all()
	await _frames()
	var before: Array = _screen.battle.bag.duplicate()
	var description_before: String = hit.data.description
	var rng_state: int = _screen.battle.rng.state
	_ok(_screen._footer.position.x < _screen._board_view.position.x and _screen._end_btn.position.x > _screen._board_view.get_rect().end.x, "桌面牌堆换到左侧，结束回合换到右侧")
	await _shot("pile-battle-desktop")
	var overlay := await _browse("bag")
	_ok(overlay != null and overlay.total == 5 and overlay.groups.size() == 4, "抽牌堆显示实际 5 枚字，普通重复字合并，污染及融合字分开")
	_ok(_screen._modal_count == 1 and not _screen._board_view._interactable and _screen._end_btn.disabled, "查看牌堆锁住战斗操作")
	_screen._pile_label.item_for("discard").pressed.emit()
	_ok(_screen._modal_count == 1, "重复点击不叠加牌堆弹窗")
	var signature := str(overlay.groups.map(func(group): return [group.character.glyph, group.character.description, group.count]))
	var reverse: Array = before.duplicate()
	reverse.reverse()
	var other := BattlePileOverlay.new()
	other.setup("抽牌堆", reverse)
	_ok(signature == str(other.groups.map(func(group): return [group.character.glyph, group.character.description, group.count])), "不同牌堆顺序得到完全相同的展示，不泄露抽取顺序")
	other.free()
	await _shot("pile-contents-desktop")
	overlay.close()
	await _frames()
	_ok(_screen._modal_count == 0 and _screen._board_view._interactable, "关闭浏览恢复战斗输入")
	overlay = await _browse("discard")
	_ok(overlay.total == 1 and overlay.groups[0].character.glyph == "火", "弃牌堆只显示实际弃置字，不混入抽牌堆或永久牌组")
	overlay.close()
	await _frames()
	_screen.battle.discard.clear()
	_screen._refresh_piles()
	overlay = await _browse("discard")
	_ok(overlay.total == 0 and overlay.groups.is_empty() and overlay._grid.get_child_count() == 1, "空牌堆显示空状态，不回退展示全部字库")
	var escape := InputEventAction.new()
	escape.action = "cancel_selection"
	escape.pressed = true
	overlay._unhandled_input(escape)
	await _frames()
	_ok(_overlay() == null and _screen._modal_count == 0, "ESC 关闭空牌堆并释放输入锁")
	_screen._set_busy(true)
	_ok(await _browse("bag") == null, "演出期间拒绝打开牌堆快照")
	_screen._set_busy(false)
	_ok(_screen.battle.bag == before and _screen.battle.rng.state == rng_state and hit.data.description == description_before, "查看不修改牌堆、字数据或战斗随机数")
	for window_size in [Vector2i(844, 390), Vector2i(640, 360)]:
		get_window().size = window_size
		await _frames(16)
		_screen._layout()
		await _frames()
		var factor := float(window_size.y) / _screen.size.y
		_ok(_screen._footer.position.x < _screen._board_view.position.x and _screen._end_btn.position.x > _screen._board_view.get_rect().end.x, str(window_size) + " 手机完成换位")
		for id in ["bag", "discard"]:
			var button: Button = _screen._pile_label.item_for(id)
			_ok(button.size.x * factor >= 47.5 and button.size.y * factor >= 47.5, str(window_size) + " " + id + " 触控区至少 48×48")
		await _shot("pile-battle-phone-%d" % window_size.x)
		overlay = await _browse("bag")
		_ok(not overlay._scroll.get_h_scroll_bar().visible and overlay._grid.columns >= 2, "手机牌堆两列阅读，无横向滚动")
		_ok(overlay._close_button.size.y * overlay._canvas.scale.y * factor >= 47.5, "手机返回按钮至少 48 触控像素")
		await _shot("pile-contents-phone-%d" % window_size.x)
		overlay._close_button.pressed.emit()
		await _frames()
	Router.goto("res://src/screens/title_screen.gd")
	await _frames()
	Router.study_stage = null
	print("[battle_pile_ui_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
