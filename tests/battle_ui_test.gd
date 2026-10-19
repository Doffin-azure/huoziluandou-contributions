extends Control
## 真实场景/输入/异步队列回归。加 -- --capture 在有渲染器时保存截图。
var _pass := 0
var _fail := 0
var _screen: Control
var _capture := false
var _saved_motion := false
var _saved_release := false
var _saved_style := ""
var _recording := false
var _recorded := 0
const GLYPHS := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]


func _ready() -> void:
	# Headless windows can start at a dummy size; use the production desktop size
	# before measuring physical touch targets and dispatching pointer events.
	get_window().size = Vector2i(1440, 810)
	_capture = OS.get_cmdline_user_args().has("--capture")
	_saved_motion = Settings.reduced_motion
	_saved_release = Settings.drag_release_play
	_saved_style = Palette.STYLE_ID
	Ink.apply_style(GameStyle.paper())
	Settings.reduced_motion = false
	Settings.drag_release_play = false
	if _capture:
		DirAccess.make_dir_recursive_absolute("res://shots/motion-frames")
		RenderingServer.frame_post_draw.connect(_capture_frame)
	_run.call_deferred()


func _capture_frame() -> void:
	if _recording:
		var image := get_viewport().get_texture().get_image()
		image.save_png("res://shots/motion-frames/%03d.png" % _recorded)
		_recorded += 1


func _ok(condition: bool, description: String) -> void:
	if condition:
		_pass += 1
		print("  ✓ ", description)
	else:
		_fail += 1
		push_error(description)


func _frames(count := 3) -> void:
	for i in count:
		await get_tree().process_frame


func _prepare_board() -> void:
	var b: BattleState = _screen.battle
	_screen._board_view.clear_selection()
	for i in 16:
		b.board.cells[i] = CharInstance.new(Database.get_character_by_glyph(GLYPHS[i]))
	_screen._refresh_all()


func _idle() -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while is_instance_valid(_screen) and _screen._busy and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_ok(not _screen._busy, "动效队列在限定时间内完成并恢复输入")


func _mouse_tap_cell(cell: Vector2i, jitter := false) -> void:
	var board: BoardView = _screen._board_view
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	pointer.position = board.tiles[board.board.from_xy(cell)].get_global_rect().get_center()
	board._input(pointer)
	if jitter:
		var motion := InputEventMouseMotion.new()
		motion.position = pointer.position + Vector2(0.5, 0.5)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		board._input(motion)
	pointer.pressed = false
	board._input(pointer)


func _shot(name: String) -> void:
	if not _capture:
		return
	await _frames()
	# 隐藏窗口或切换尺寸时，主动提交一帧，避免等待被节流的绘制通知。
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute("res://shots")
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png("res://shots/" + name + ".png")
	_ok(error == OK, "保存 " + name + " 实际渲染截图")


func _paper_luminance(stage: StudyStage) -> float:
	var image := stage.viewport.get_texture().get_image()
	var rect: Rect2 = _screen._preview_panel.get_global_rect().grow(-32)
	var total := 0.0
	for row in 12:
		for col in 8:
			var canvas_point := rect.position + rect.size * Vector2((col + 0.5) / 8.0, (row + 0.5) / 12.0)
			var local := stage.get_global_transform().affine_inverse() * canvas_point
			var pixel := Vector2i(local * Vector2(image.get_size()) / stage.size)
			var color := image.get_pixel(clampi(pixel.x, 0, image.get_width() - 1), clampi(pixel.y, 0, image.get_height() - 1))
			total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return total / 96.0


func _run() -> void:
	GameState.start_new_run("v03")
	if _capture:
		var stage := StudyStage.new()
		add_child(stage)
		Router.study_stage = stage
	Router.host = self
	var fixture := MapNodeData.new()
	fixture.enemies.append(Database.get_enemy("ink_spirit"))
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 7, "node": fixture})
	await _frames()
	_screen = Router.current
	_ok(_screen._board_view.tiles.size() == 16, "真实战斗场景有 16 枚固定视图")
	var presentation: BoardPresentation3D = _screen._board_view._presentation
	_ok(presentation != null and presentation.actors.size() == 16, "宣纸主题创建 16 个真实 3D 字块")
	_ok(presentation._body_mesh.get_surface_count() == 1 and presentation._body_mesh.surface_get_array_len(0) > 0, "倒角木块几何有效")
	if _capture:
		_ok(presentation._tray.get_viewport() == Router.study_stage.viewport and presentation.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "字盘与桌面共享相机、灯光和投影世界，停用重复渲染视口")
		_ok(Router.study_stage.battle_table.papers.size() == 2, "左右纸面在相同 3D 世界接收场景投影")
		var all_cells_match := true
		for index in 16:
			var screen_point: Vector2 = _screen._board_view.get_global_transform() * presentation.cell_rect(index).get_center()
			all_cells_match = all_cells_match and _screen._board_view._cell_at(screen_point) == _screen._board_view.tiles[index].grid_pos
		_ok(all_cells_match, "每个 3D 字块的投影命中对应的逻辑格子")
	_ok(not _screen._log_overlay.visible, "战报默认收起")
	var enemy: Combatant = _screen.battle.enemies[0]
	var enemy_id: int = _screen._enemy_widgets[0].get_instance_id()
	_prepare_board()
	_mouse_tap_cell(Vector2i(0, 0))
	_ok(_screen._board_view.path == [Vector2i(0, 0)], "单击选中一枚字")
	_mouse_tap_cell(Vector2i(0, 0), true)
	_ok(_screen._board_view.path.is_empty() and _screen._confirm_btn.disabled, "再次点击取消，鼠标微动不会立即重新选中")
	_mouse_tap_cell(Vector2i(0, 0))
	_mouse_tap_cell(Vector2i(1, 0))
	_mouse_tap_cell(Vector2i(1, 0))
	_ok(_screen._board_view.path == [Vector2i(0, 0)], "再次点击路径末字只撤销末字")
	_mouse_tap_cell(Vector2i(1, 0))
	_mouse_tap_cell(Vector2i(2, 0))
	_mouse_tap_cell(Vector2i(1, 0))
	_ok(_screen._board_view.path == [Vector2i(0, 0)], "点击中间字撤销该字及后续，保留合法路径前缀")
	_screen._board_view._on_tile_pressed(Vector2i(1, 0))
	_screen._board_view._extend_path(Vector2i(2, 0))
	_screen._board_view._extend_path(Vector2i(1, 0))
	_ok(_screen._board_view.path == [Vector2i(0, 0), Vector2i(1, 0)], "拖动回退仍保留经过的字")
	_screen._board_view.clear_selection()
	var first_tile: TileView = _screen._board_view.tiles[0]
	first_tile.enter(Vector2(0, -10), true, 0.05)
	_screen._board_view._on_tile_pressed(Vector2i(0, 0))
	_ok(first_tile._visual.modulate.a == 1.0 and first_tile._visual.scale == Vector2.ONE, "落字期间选中会取消入场并恢复完整可见状态")
	_screen._board_view.clear_selection()
	var selected := [Vector2i(0, 0), Vector2i(1, 0)]
	_screen._board_view.path = selected.duplicate()
	_screen._board_view._sync_selection()
	if _capture:
		await _frames(20)
	await _shot("battle-desktop-live")
	if _capture:
		_ok(not _screen._bubble._scroll.get_v_scroll_bar().visible, "桌面击破预览完整显示词效、目标和污染代价，无需滚动")
		var stage: StudyStage = Router.study_stage
		var shadowed := _paper_luminance(stage)
		stage._sun.shadow_enabled = false
		await _frames(12)
		RenderingServer.force_draw(false)
		var unshadowed := _paper_luminance(stage)
		_ok(unshadowed - shadowed > 0.007, "纸面实际像素随场景投影开关改变亮度，阴影未烘焙进贴图")
		stage._sun.shadow_enabled = true
		await _frames(16)

	_screen._open_menu()
	await _frames()
	var menu: PauseOverlay = PauseMenu._instance
	_screen._open_menu()
	_ok(PauseMenu._instance == menu and _screen._modal_count == 1 and not _screen._board_view._interactable, "唯一菜单入口不重复创建浮层，并阻断字盘")
	await _shot("battle-menu-live")
	menu._open_settings()
	menu._open_settings()
	await _frames()
	_ok(is_instance_valid(menu._settings) and not menu._main_layer.visible and _screen._modal_count == 1, "设置在菜单内打开，不重复叠加菜单页")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await _frames()
	_ok(is_instance_valid(menu) and not is_instance_valid(menu._settings) and menu._main_layer.visible and _screen._modal_count == 1, "ESC 关闭设置后回到菜单，战斗仍锁定")
	menu._open_tool("_open_deck")
	await _frames()
	_ok(_screen._modal_count == 1 and not _screen._board_view._interactable, "从菜单打开字袋后维持单个浮层的输入锁")
	for child in _screen.get_children():
		if child is CollectionOverlay:
			child._close()
	await _frames()
	_screen._open_menu()
	await _frames()
	PauseMenu._instance._open_tool("_toggle_log")
	await _frames()
	_ok(_screen._log_overlay.visible and _screen._modal_count == 1, "战报从菜单进入且不留下旧菜单")
	_screen._toggle_log()
	await _frames()
	_ok(_screen._modal_count == 0 and _screen._board_view._interactable, "关闭菜单工具后恢复战斗输入")

	var invalid := [Vector2i(2, 0), Vector2i(2, 1)]
	var hp := enemy.hp
	var rng_state: int = _screen.battle.rng.state
	_screen._on_commit(invalid)
	await _frames()
	_ok(enemy.hp == hp and _screen.battle.board.fill_count() == 16, "无效词不消费字、不伤害、不进入结算队列")
	_screen._board_view.path = selected.duplicate()
	_screen._board_view._sync_selection()
	_recording = _capture
	if _capture:
		await _frames(2)
	_screen._on_commit(selected)
	_ok(_screen._busy and _screen._confirm_btn.disabled and _screen._end_btn.disabled, "出字期间锁住出字及结束回合")
	_screen._on_commit(selected)
	_screen._on_end_turn()
	_ok(_screen.battle.turn == 1 and enemy.hp == 22, "连点和抢结束回合不会重复结算")
	if _capture:
		await get_tree().create_timer(0.39).timeout
		await _shot("battle-impact-live")
		await get_tree().create_timer(0.45).timeout
		_recording = false
		var frame_count := FileAccess.open("res://shots/motion-frames/count.txt", FileAccess.WRITE)
		frame_count.store_string(str(_recorded))
	await _idle()
	_ok(enemy.hp == 22 and _screen.battle.board.fill_count() == 14, "击破实际造成 8 伤、消耗 2 字")
	_ok(_screen.battle.rng.state == rng_state, "无补字攻击的全部动效不消耗战斗随机数")
	_ok(_screen._enemy_widgets[0].get_instance_id() == enemy_id, "受击前后敌人视图未重建")
	_ok(_screen._enemy_widgets[0]._hp.value == 22 and _screen._enemy_widgets[0]._hp_number.text == "22 / 30", "表现血条及独立生命数值与逻辑最终生命一致")
	_ok(_screen._board_view._interactable, "结算后字盘恢复交互")

	# 模态浏览时，原生触屏/键盘路径不能穿透到字盘。
	_screen._open_deck()
	await _frames()
	_ok(_screen._modal_count == 1 and not _screen._board_view._interactable, "字袋浮层阻断战斗输入")
	var touch := InputEventScreenTouch.new()
	touch.index = 3
	touch.pressed = true
	touch.position = _screen._board_view.tiles[2].get_global_rect().get_center()
	_screen._board_view._input(touch)
	_ok(_screen._board_view.path.is_empty(), "触屏不会穿透字袋浮层")
	for child in _screen.get_children():
		if child is CollectionOverlay:
			child._close()
	await _frames()
	_ok(_screen._modal_count == 0 and _screen._board_view._interactable, "关闭字袋恢复输入")

	# 切到宽屏手机布局，并通过触点移动跨过间隙连出正确路径。
	_screen.params["touch_layout"] = true
	get_window().size = Vector2i(1870, 841)
	await _frames(5)
	_screen._layout()
	_prepare_board()
	var board: BoardView = _screen._board_view
	touch.position = board.tiles[0].get_global_rect().get_center()
	board._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = board.tiles[1].get_global_rect().get_center()
	board._input(drag)
	touch.pressed = false
	touch.position = drag.position
	board._input(touch)
	_ok(board.path == selected and not _screen._busy, "触屏松手保留合法选择")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	board.tiles[0]._on_gui_input(emulated)
	_ok(board.path == selected, "模拟鼠标事件不会重复触屏选择")
	_ok(_screen._end_btn.position.x >= board.get_rect().end.x and _screen._preview_panel.get_rect().end.x <= board.position.x and not _screen._end_btn.get_global_rect().intersects(_screen._selection_actions.get_global_rect()), "手机词效在左、结束回合在右，与字盘下方出字操作分开")
	_ok(_screen._confirm_btn.custom_minimum_size.y >= 48, "手机主操作有至少 48 逻辑像素的触控区域")
	await _shot("battle-mobile-live")
	if _capture:
		get_window().size = Vector2i(844, 390)
		await _frames(5)
		_screen._layout()
		await _frames()
		var factor := float(DisplayServer.window_get_size().y) / get_viewport_rect().size.y
		_ok(_screen._confirm_btn.size.y * factor >= 48, "小手机出字按钮至少 48 屏幕像素")
		_ok(_screen._end_btn.size.y * factor >= 47.5, "小手机结束回合按钮至少 48 屏幕像素")
		await _shot("battle-phone-small-live")
		_ok(get_viewport().get_texture().get_image().get_size() == Vector2i(844, 390), "小手机验证使用真实 844×390 渲染尺寸")
		_ok(not _screen._bubble._scroll.get_v_scroll_bar().visible, "小手机击破预览完整显示词效、目标和污染，无需滚动")
		_ok(_screen._menu_btn.size.y * factor >= 48, "小手机右上菜单入口至少 48 屏幕像素")
		_screen._open_menu()
		await _frames()
		await _shot("battle-menu-phone-live")
		PauseMenu._instance._close()
		await _frames()
		get_window().size = Vector2i(1870, 841)
		await _frames(5)
		_screen._layout()

	# 原生触屏再次点击同一字撤销，不触发松手出字。
	Settings.drag_release_play = true
	touch.pressed = true
	touch.position = board.tiles[1].get_global_rect().get_center()
	board._input(touch)
	touch.pressed = false
	board._input(touch)
	_ok(board.path == [Vector2i(0, 0)] and not _screen._busy, "触屏再次点末字撤销，松手不会出字")
	touch.pressed = true
	touch.position = board.tiles[0].get_global_rect().get_center()
	board._input(touch)
	touch.pressed = false
	board._input(touch)
	_ok(board.path.is_empty() and _screen._confirm_btn.disabled, "触屏再次点首字取消整条选择")

	Settings.drag_release_play = true
	board.clear_selection()
	touch.pressed = true
	touch.position = board.tiles[0].get_global_rect().get_center()
	board._input(touch)
	board._input(drag)
	touch.pressed = false
	touch.position = drag.position
	board._input(touch)
	_ok(_screen._busy, "触屏松手即出字设置生效")
	await _idle()
	Settings.drag_release_play = false

	# 固定列表中前面的敌人死亡后，目标映射仍指向被点击的活敌人。
	Settings.reduced_motion = true
	var other := Combatant.new("第二敌人", 40)
	other.enemy_data = Database.get_enemy("ink_spirit")
	var chosen := Combatant.new("第三敌人", 40)
	chosen.enemy_data = Database.get_enemy("ink_spirit")
	_screen.battle.enemies.append(other)
	_screen.battle.enemies.append(chosen)
	enemy.hp = 0
	_screen._refresh_all()
	_screen._on_enemy_clicked(2)
	_prepare_board()
	_screen._on_commit(selected)
	await _idle()
	_ok(other.hp == 40 and chosen.hp == 32, "前置敌人死亡时，出字仍命中选定目标")

	# 全格挡、破盾补字与防御获得不能伪装成生命伤害。
	_prepare_board()
	chosen.block = 20
	_screen._refresh_all()
	_screen._on_commit(selected)
	await _idle()
	_ok(chosen.block == 4 and chosen.hp == 32, "击破全格挡只拆 16 盾，不扣生命")
	_prepare_board()
	chosen.block = 12
	_screen.battle.bag = [CharInstance.new(Database.get_character_by_glyph("防"))]
	_screen._refresh_all()
	_screen._on_commit(selected)
	await _idle()
	_ok(chosen.block == 0 and chosen.hp == 30, "击破破盾后剩余 2 点伤害正确落定")
	_ok(_screen.battle.board.fill_count() == 15, "破盾奖励只补 1 字")
	_prepare_board()
	_screen.battle.player.block = 0
	_screen._on_commit([Vector2i(0, 1), Vector2i(1, 1)])
	await _idle()
	_ok(_screen.battle.player.block == 10, "防御词获得 10 临挡")

	# 敌人多段行动保留每一击的真实反馈，不把三击合并。
	var moves := EnemyData.new()
	moves.name = "连击敌人"
	var move := EnemyMoveData.new()
	move.kind = EnemyMoveData.Kind.MULTI
	move.damage = 3
	move.hits = 3
	moves.moves = [move]
	chosen.enemy_data = moves
	other.hp = 0
	_screen.battle.player.hp = 60
	_screen.battle.player.block = 5
	var recorded: Array = []
	var listener := func(event: Dictionary): recorded.append(event.duplicate())
	_screen.battle.player.feedback.connect(listener)
	_screen._on_end_turn()
	await _idle()
	_screen.battle.player.feedback.disconnect(listener)
	var damage_events := recorded.filter(func(event): return event.kind == "damage")
	_ok(damage_events.size() == 3, "敌方三连击产生三个有序反馈")
	_ok(_screen.battle.player.hp == 56 and _screen._player_hp.value == 56 and _screen._player_hp_value.text == "56 / 60", "三连击后生命条及大号气血数值同步为 56 / 60")

	# 浮层的选择回调先发出，浮层随后退出，期间仍能提交选中目标。
	_prepare_board()
	_screen.battle.board.set_cell(0, 0, CharInstance.new(Database.get_character_by_glyph("反")))
	_screen.battle.board.set_cell(1, 0, CharInstance.new(Database.get_character_by_glyph("转")))
	_screen._refresh_all()
	board.path = selected.duplicate()
	board._sync_selection()
	_screen._on_commit(selected)
	await _frames()
	_ok(_screen._modal_count == 1, "需要选择行列的词打开选择浮层")
	for child in _screen.get_children():
		if child is ChoiceOverlay:
			child._on_choose(0)
	await _idle()
	await _frames()
	_ok(_screen._modal_count == 0 and board.path.is_empty(), "浮层选择可以结算，并释放输入锁")

	# 离开场景时停止队列并解除 RefCounted 信号绑定。
	_prepare_board()
	Settings.reduced_motion = false
	_screen._on_commit(selected)
	var shared_tray: Node3D = _screen._board_view._presentation._tray
	Router.goto("res://src/screens/title_screen.gd")
	await _frames(10)
	_ok(Router.current_path.contains("title_screen"), "动画中切换界面无遗留输入锁")
	if _capture:
		_ok(not is_instance_valid(shared_tray) and Router.study_stage.battle_table.papers.is_empty(), "退出战斗释放共享字盘与纸面，不把表现节点留在书房")
	await _verify_relic_board()
	Settings.reduced_motion = _saved_motion
	Settings.drag_release_play = _saved_release
	Ink.apply_style(GameStyle.get_style(_saved_style))
	print("[battle_ui_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _verify_relic_board() -> void:
	var saved_style: String = Palette.STYLE_ID
	Ink.apply_style(GameStyle.get_style("taopunk"))
	GameState.start_new_run("v03")
	GameState.add_relic("press")
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 7})
	await _frames(12)
	_screen = Router.current
	var board: BoardView = _screen._board_view
	_ok(_screen.battle.board.size == 5 and board.tiles.size() == 25 and board._presentation.actors.size() == 25, "续碑座遗物在当前美术下构建 5×5 字盘与全部字块")
	for i in 25:
		_screen.battle.board.cells[i] = CharInstance.new(Database.get_character_by_glyph(GLYPHS[i % GLYPHS.size()]))
	_screen.battle.board.set_cell(3, 4, CharInstance.new(Database.get_character_by_glyph("击")))
	_screen.battle.board.set_cell(4, 4, CharInstance.new(Database.get_character_by_glyph("破")))
	_screen._refresh_all()
	await _frames(12)
	var projected := true
	for i in 25:
		projected = projected and board._cell_at(board.tiles[i].get_global_rect().get_center()) == board.tiles[i].grid_pos
	_ok(projected, "扩大字盘后所有 25 枚字块的投影与点击位置一致")
	_ok(_screen._turn_label.tooltip_text.contains(Relics.desc_of("press")), "战斗回合入口保留远端遗物说明")
	var hp: int = _screen.battle.enemies[0].hp
	_mouse_tap_cell(Vector2i(3, 4))
	_mouse_tap_cell(Vector2i(4, 4))
	_ok(board.path == [Vector2i(3, 4), Vector2i(4, 4)] and not _screen._confirm_btn.disabled, "新增第五行仍能连字并激活出字")
	_screen._confirm_btn.pressed.emit()
	await _idle()
	_ok(_screen.battle.enemies[0].hp == hp - 8, "扩大字盘的击破正常结算 8 伤害")
	await _shot("battle-merged-relic-board")
	Router.goto("res://src/screens/title_screen.gd")
	await _frames(10)
	Ink.apply_style(GameStyle.get_style(saved_style))
