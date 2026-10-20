extends Control
## 经过战斗页和字盘输入的回归，不直接调用旋转规则绕过目标选择。
var _screen: Control
var _pass := 0
var _fail := 0
var _capture := false
var _saved_motion := false
var _saved_volume := 0.65
const PATH := [Vector2i(0, 0), Vector2i(1, 0)]
const GLYPHS := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]


func _ready() -> void:
	Settings.storage_path = "user://battle_presentation_regression-settings.cfg"
	_capture = OS.get_cmdline_user_args().has("--capture")
	_saved_motion = Settings.reduced_motion
	_saved_volume = Settings.sfx_volume
	Settings.reduced_motion = false
	Settings.sfx_volume = 0.65
	_run.call_deferred()


func _ok(condition: bool, description: String) -> void:
	if condition:
		_pass += 1
		print("  ✓ ", description)
	else:
		_fail += 1
		push_error(description)


func _frames(count := 3) -> void:
	for index in count:
		await get_tree().process_frame


func _idle() -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while _screen._busy and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_ok(not _screen._busy, "演出完成并解锁输入")


func _fresh(word: String) -> void:
	_screen._on_clear_cancel()
	var battle: BattleState = _screen.battle
	battle.abilities.clear()
	battle.player.statuses.clear()
	battle.player.heat = 0
	battle.player.energy = 0
	battle.player.heat_capacity = 10
	battle.bag.clear()
	battle.discard.clear()
	for index in 16:
		var glyph: String = word.substr(index, 1) if index < word.length() else GLYPHS[index]
		battle.board.cells[index] = CharInstance.new(Database.get_character_by_glyph(glyph))
	_screen._refresh_all()
	_screen._board_view.path = PATH.duplicate() if word.length() > 1 else [Vector2i.ZERO]
	_screen._board_view._sync_selection()


func _tap(cell: Vector2i, touch := false) -> void:
	var board: BoardView = _screen._board_view
	var point: Vector2 = board.tiles[board.board.from_xy(cell)].get_global_rect().get_center()
	if touch:
		var event := InputEventScreenTouch.new()
		event.index = 4
		event.position = point
		event.pressed = true
		board._input(event)
		event.pressed = false
		board._input(event)
	else:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = true
		board._input(event)
		event.pressed = false
		board._input(event)


func _shot(name: String) -> void:
	if _capture:
		await _frames(12)
		RenderingServer.force_draw(false)
		DirAccess.make_dir_recursive_absolute("res://shots")
		_ok(get_viewport().get_texture().get_image().save_png("res://shots/" + name + ".png") == OK, "保存实际渲染 " + name)


func _choose_card(index := 0) -> void:
	for child in _screen.get_children():
		if child is ChoiceOverlay:
			child._on_choose(index)
			break
	await _frames()


func _run() -> void:
	GameState.start_new_run("v03")
	if _capture:
		var stage := StudyStage.new()
		add_child(stage)
		Router.study_stage = stage
	Router.host = self
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 7})
	await _frames()
	_screen = Router.current
	var battle: BattleState = _screen.battle
	var board: BoardView = _screen._board_view
	_fresh("击破")
	battle.player.heat = 4
	battle.player.energy = 3
	battle.enable_ability("longword_draw", 1)
	battle.enable_ability("counter", 3)
	_screen._refresh_all()
	_ok(_screen._player_status.entries.any(func(item): return item.id == "heat" and item.stacks == 4) and _screen._player_status.entries.any(func(item): return item.id == "energy" and item.stacks == 3), "资源并入状态栏，读取真实热度与储能数值")
	_ok(_screen._player_status._buttons.all(func(button): return button.get_node("Glyph") is Label and not button.get_node("Glyph").text.is_empty()), "能力按钮显示汉字方牌，不使用图形符号")
	var descriptions_available := _screen._player_status.entries.all(func(entry): return str(entry.glyph).length() == 1 and not str(entry.description).is_empty())
	_ok(descriptions_available, "每个活动状态都有单字标签和完整说明")
	_screen._player_status.item_for("heat").pressed.emit()
	await _frames()
	_ok(_screen._modal_count == 1 and not board._interactable, "点击资源符号可查看热度说明，浮层不穿透战斗")
	await _choose_card()
	await _shot("battle-symbol-hud-desktop")
	await _shot("battle-refined-desktop")
	_ok(_screen._selection_actions.get_parent() == _screen.content and _screen._selection_actions.position.y >= board.position.y + board.size.y, "主操作放在字盘下方，脱离左侧预览纸")
	_ok(not _screen._selection_actions.get_global_rect().intersects(_screen._end_btn.get_global_rect()), "出字与结束回合不会重叠")
	_ok(_screen._audio._streams.size() == 6 and _screen._audio._voices.size() == 8, "六种音色、三种变化预先缓存，八路复用播放器")
	var wav: AudioStreamWAV = _screen._audio._streams.hit[0]
	_ok(wav.get_length() > 0.2 and wav.data.size() > 1000, "受击音效有真实 PCM 波形")
	var random_state := battle.rng.state
	_screen._audio.play_cue("hit")
	_ok(battle.rng.state == random_state, "音效变化不消耗战斗随机数")
	Settings.sfx_volume = 0.0
	_screen._audio._on_settings_changed()
	_screen._audio.play_cue("gravity")
	_ok(_screen._audio._voices.all(func(voice): return not voice.playing), "静音立即停止旧声音，并阻止新声音")
	Settings.sfx_volume = 0.65

	# UI 发起需要目标的词，保持四格预览，可改选，回车再执行。
	_fresh("回转")
	_screen._on_primary()
	_ok(board.pick_mode == "2x2" and _screen._confirm_btn.disabled and _screen._bubble.body.get_parsed_text().contains("左上格"), "回转显示选区指引，未选目标不能发动")
	_tap(Vector2i(3, 3))
	_ok(_screen._ready_action.is_empty(), "越界锚点不能选择 2×2")
	_tap(Vector2i(0, 2))
	_tap(Vector2i(2, 2), true)
	_ok(board.pick_anchor == Vector2i(2, 2) and board.pick_region(board.pick_anchor).size() == 4 and _screen._ready_action.target.tile == Vector2i(2, 2), "鼠标选择后可触屏改选，四格目标完整保留")
	_ok(battle.board.fill_count() == 16 and not _screen._busy and not _screen._confirm_btn.disabled, "待发动阶段不消耗字，主按钮可用")
	await _shot("battle-region-2x2")
	var before: Array = battle.board.cells.duplicate()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await _frames()
	await _idle()
	_ok(battle.board.get_xy(Vector2i(2, 2)) == before[14] and battle.board.get_xy(Vector2i(3, 2)) == before[10] and battle.board.fill_count() == 14, "回车发动真实旋转目标四格，仅消耗回转两字")
	_ok(board.pick_mode.is_empty() and _screen._ready_action.is_empty(), "发动后退出目标模式，没有残留待发动动作")

	_fresh("右转")
	_screen._on_primary()
	_ok(board.pick_mode == "3x3", "新增 3×3 旋转接入目标选择")
	_tap(Vector2i(2, 2))
	_ok(_screen._ready_action.is_empty(), "3×3 不接受越界锚点")
	_tap(Vector2i(1, 1))
	before = battle.board.cells.duplicate()
	_ok(board.pick_region(board.pick_anchor).size() == 9, "3×3 预览包含九格")
	_screen._on_primary()
	await _idle()
	_ok(battle.board.get_xy(Vector2i(1, 1)) == before[13] and battle.board.get_xy(Vector2i(3, 1)) == before[5], "右转 UI 发动后九格顺时针旋转")

	_fresh("左击")
	_screen._on_primary()
	_tap(Vector2i(2, 3))
	_ok(board.pick_mode == "row" and board.pick_region(board.pick_anchor).size() == 4 and _screen._ready_action.target.row == 3, "整行定向效果显示整行预览并传递 row 参数")
	before = battle.board.cells.duplicate()
	_screen._on_primary()
	await _idle()
	_ok(battle.board.get_xy(Vector2i(0, 3)) == before[13] and battle.board.get_xy(Vector2i(3, 3)) == before[12], "左击实际向左循环移动指定行")

	_fresh("回转")
	_screen._on_primary()
	_tap(Vector2i(2, 2))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await _frames()
	_ok(board.pick_mode.is_empty() and _screen._ready_action.is_empty() and battle.board.fill_count() == 16 and _screen._confirm_btn.disabled, "ESC 撤销待发动选区，没有消费或幽灵发动")

	_fresh("转速")
	_screen._on_primary()
	_tap(Vector2i(2, 2))
	_screen._on_primary()
	await _idle()
	_screen._on_primary()
	_screen._on_primary()
	_ok(battle.repeat_rotate_tile.x == -1 and _screen._ready_action.is_empty() and battle.player.heat == 2, "转速选区发动三次后自动结束，第 2/3 次各升温 1")

	_fresh("急转")
	_screen._on_primary()
	_tap(Vector2i(2, 1))
	_tap(Vector2i(3, 3))
	_tap(Vector2i(2, 0))
	_ok(_screen._ready_action.is_empty() and board.picked_cells.is_empty() and battle.board.fill_count() == 16, "待发动后重新连字会撤销旧动作，不误发动旧目标")
	_fresh("急转")
	_screen._on_primary()
	_tap(Vector2i(2, 1))
	_tap(Vector2i(3, 3))
	_screen._on_end_turn()
	await _idle()
	_ok(_screen._ready_action.is_empty() and board.picked_cells.is_empty(), "结束回合取消待发动动作，下一回合不会发动旧目标")
	_fresh("急转")
	_screen._on_primary()
	_ok(board.pick_mode == "slot" and battle.board.fill_count() == 16, "急转先选两格，不能无目标直接消费")
	before = battle.board.cells.duplicate()
	_tap(Vector2i(2, 1))
	_tap(Vector2i(3, 3))
	_screen._on_primary()
	await _idle()
	_ok(battle.board.get_xy(Vector2i(2, 1)) == before[15] and battle.board.get_xy(Vector2i(3, 3)) == before[6], "急转交换任意两格")

	_fresh("左右")
	_screen._on_primary()
	_tap(Vector2i(0, 3))
	_tap(Vector2i(1, 2))
	_ok(_screen._ready_action.is_empty(), "左右换位拒绝跨行第二格，保留选择流程")
	before = battle.board.cells.duplicate()
	_tap(Vector2i(2, 3))
	_screen._on_primary()
	await _idle()
	_ok(battle.board.get_xy(Vector2i(0, 3)) == before[14] and battle.board.get_xy(Vector2i(2, 3)) == before[12], "左右只交换选定同行两格")

	_fresh("收放")
	battle.board.clear_xy(Vector2i(3, 3))
	_screen._refresh_all()
	var moving: CharInstance = battle.board.get_xy(Vector2i(2, 1))
	_screen._on_primary()
	_tap(Vector2i(2, 1))
	_tap(Vector2i(3, 3))
	_screen._on_primary()
	await _idle()
	_ok(battle.board.get_xy(Vector2i(3, 3)) == moving and battle.board.get_xy(Vector2i(2, 1)) == null, "收放移动指定字到指定空格，保留实体身份")

	_fresh("火急")
	battle.board.clear_xy(Vector2i(2, 3))
	battle.board.clear_xy(Vector2i(3, 3))
	var supply := [CharInstance.new(Database.get_character_by_glyph("防")), CharInstance.new(Database.get_character_by_glyph("盾"))]
	battle.bag.assign(supply)
	_screen._refresh_all()
	_screen._on_primary()
	_ok(battle.pending_reveal.size() == 2 and battle.board.fill_count() == 14, "火急先揭示两字并等待空格选择，不直接消费")
	_tap(Vector2i(2, 3))
	_tap(Vector2i(3, 3))
	_screen._on_primary()
	await _idle()
	_ok(supply.has(battle.board.get_xy(Vector2i(2, 3))) and supply.has(battle.board.get_xy(Vector2i(3, 3))) and battle.pending_reveal.is_empty(), "火急把揭示实体放入两个指定空格")
	_fresh("火急")
	battle.board.clear_xy(Vector2i(2, 3))
	battle.bag.assign(supply)
	_screen._refresh_all()
	_screen._on_primary()
	_screen._on_clear_cancel()
	_ok(battle.pending_reveal.is_empty() and battle.bag.size() == 2 and battle.board.fill_count() == 15, "取消火急完整退还揭示字，不消费发动材料")
	_screen._refresh_all()
	board.path = PATH.duplicate()
	board._sync_selection()
	_screen._on_primary()
	_tap(Vector2i(2, 3))
	_tap(Vector2i(2, 0))
	_ok(battle.pending_reveal.is_empty() and battle.bag.size() == 2 and _screen._ready_action.is_empty(), "火急待发动时改为连字，也完整退还揭示字")

	_fresh("收复")
	battle.board.clear_xy(Vector2i(2, 3))
	battle.board.clear_xy(Vector2i(3, 3))
	battle.discard.assign(supply)
	_screen._refresh_all()
	_screen._on_primary()
	await _choose_card()
	_tap(Vector2i(2, 3))
	await _choose_card()
	_tap(Vector2i(3, 3))
	_screen._on_primary()
	await _idle()
	_ok(supply.has(battle.board.get_xy(Vector2i(2, 3))) and supply.has(battle.board.get_xy(Vector2i(3, 3))), "收复先选弃字实体，再放入相邻空格")

	_fresh("收回")
	battle.discard = [supply[0]]
	var returned: CharInstance = battle.board.get_xy(Vector2i(2, 1))
	_screen._on_primary()
	await _choose_card()
	_tap(Vector2i(2, 1))
	_screen._on_primary()
	await _idle()
	_ok(battle.board.get_xy(Vector2i(2, 1)) == supply[0] and battle.bag.has(returned), "收回按 UID 指定弃字填入原格，原盘面字回袋")

	_fresh("合击")
	battle.board.set_xy(Vector2i(2, 0), CharInstance.new(Database.get_character_by_glyph("破")))
	_screen._on_primary()
	_ok(battle.formation_queue.size() == 1 and not _screen._confirm_btn.disabled, "结阵登记后空路径的发动按钮可用")
	var health: int = battle.enemies[0].hp
	board.path = [Vector2i(1, 0), Vector2i(2, 0)]
	board._sync_selection()
	_screen._on_primary()
	_ok(battle.formation_queue.size() == 2 and battle.enemies[0].hp == health, "结阵中再次连词会登记新词，不提前发动旧队列")
	_screen._on_primary()
	await _idle()
	_ok(battle.formation_queue.is_empty() and battle.enemies[0].hp == health - 8 and battle.board.fill_count() == 13, "结阵发动有序播放真实反馈，共用击字只消费一次")

	# 能力页通过同一只读适配器，显示层数和取消后的状态。
	_fresh("能力")
	_screen._on_primary()
	await _idle()
	_ok(_screen._player_status.entries.any(func(entry): return entry.id == "ability:longword_draw"), "实际打出能力牌后出现能力 Buff 图标")
	battle.enable_ability("counter", 3)
	battle.enable_ability("manual_draw", 1)
	battle.player.add_status("poison", 2)
	_screen._refresh_all()
	_ok(_screen._player_status.entries.any(func(entry): return entry.id == "ability:counter" and entry.stacks == 3 and entry.description.replace(" ", "").contains("+9")), "反击层数与详情中的实际伤害加成一致，精心也有能力图标")
	await _shot("battle-buffs-desktop")
	_screen._player_status._show_details()
	await _frames()
	_ok(_screen._modal_count == 1 and not board._interactable, "点击图标打开全部说明，并阻断战斗输入")
	for child in _screen.get_children():
		if child is ChoiceOverlay:
			child._on_choose(0)
	await _frames()
	_ok(_screen._modal_count == 0 and board._interactable, "关闭 Buff 说明释放输入锁")
	battle.abilities.erase("counter")
	_screen._refresh_all()
	_ok(not _screen._player_status.entries.any(func(entry): return entry.id == "ability:counter"), "能力耗尽后图标立即移除")

	_fresh("重")
	var stage_origin: Vector2 = Router.study_stage.position if _capture else Vector2.ZERO
	_screen._on_primary()
	await _idle()
	_ok(_screen._effects._impact_strength > 0.0, "单字重在真实重力结算后触发震动")
	var effects: BattleEffects = _screen._effects
	effects._process(0.025)
	_ok(_screen.content.position.length() > 0.01, "震动实际位移 HUD，与 3D 桌面一起移动")
	if _capture:
		_ok(Router.study_stage.position.distance_to(stage_origin) > 0.01, "真实 3D 场景参与同一次震动")
	effects._process(0.5)
	_ok(_screen.content.position == Vector2.ZERO and effects._impact_strength == 0.0, "短震动结束回到原位，不修改全局时间流速")
	Settings.reduced_motion = true
	effects.table_impact(7.0)
	_ok(effects._impact_strength == 0.0, "减少动效关闭整桌震动")
	Settings.reduced_motion = false

	# 保存音效串联样本：选字 / 出字 / 受击 / 格挡 / 重落 / 回复。
	if _capture:
		var pcm := PackedByteArray()
		for cue in ["select", "play", "hit", "block", "gravity", "heal"]:
			pcm.append_array((_screen._audio._streams[cue][0] as AudioStreamWAV).data)
			var silence := PackedByteArray()
			silence.resize(BattleAudio.RATE)
			pcm.append_array(silence)
		var preview := AudioStreamWAV.new()
		preview.format = AudioStreamWAV.FORMAT_16_BITS
		preview.mix_rate = BattleAudio.RATE
		preview.data = pcm
		_ok(preview.save_to_wav("res://shots/battle-audio-preview.wav") == OK, "导出六种实际音效试听")
		_fresh("击破")
		battle.enable_ability("longword_draw", 1)
		battle.enable_ability("counter", 2)
		battle.player.heat = 4
		battle.player.energy = 3
		_screen.params["touch_layout"] = true
		get_window().size = Vector2i(844, 390)
		await _frames(5)
		_screen._refresh_all()
		await _shot("battle-refined-phone")
		await _shot("battle-symbol-hud-phone")
		var factor := float(DisplayServer.window_get_size().y) / get_viewport_rect().size.y
		_ok(_screen._confirm_btn.size.y * factor >= 47.5 and not _screen._selection_actions.get_global_rect().intersects(_screen._end_btn.get_global_rect()), "小手机字盘下方主操作仍有 48 像素，无按钮重叠")
		_ok(not _screen._player_status.get_global_rect().intersects(_screen._enemy_panel.get_global_rect()) and _screen._player_status.get_global_rect().end.y <= _screen.get_global_rect().end.y, "手机 Buff 区不覆盖敌人信息且在屏幕内")
		_ok(_screen._player_status.get_parent() == _screen._player_panel and _screen._player_status.get_global_rect().end.y <= _screen._enemy_panel.get_global_rect().position.y, "手机能力紧跟玩家气血与护盾，不散落在底栏")
		_ok(not _screen._player_status.get_global_rect().intersects(board.get_global_rect()) and not _screen._player_status.get_global_rect().intersects(_screen._menu_btn.get_global_rect()), "资源随状态栏靠近气血，不遮挡字盘或菜单")
		_screen._player_status._buttons[0].pressed.emit()
		await _frames()
		var close_height := 0.0
		for child in _screen.get_children():
			if child is ChoiceOverlay:
				var close: Button = child.find_children("*", "Button", true, false)[0]
				close_height = close.size.y * factor
		_ok(close_height >= 47.5 and _screen._modal_count == 1, "手机单项能力详情有 48 像素关闭区域，并保持输入锁")
		await _shot("battle-symbol-detail-phone")
		await _choose_card()
		GameState.gold = 1234
		battle.player.block = 128
		battle.player.persistent_block = 256
		_screen._refresh_all()
		await _frames()
		_ok(not _screen._gold_strip.get_global_rect().intersects(_screen._player_status.get_global_rect()) and not _screen._gold_strip.get_global_rect().intersects(_screen._turn_label.get_global_rect()), "手机只显示普通铜钱，不与回合或状态挤在一起")
		_ok(not _screen._player_hp_value.get_global_rect().intersects(_screen._player_status.get_global_rect()), "三位数护盾不覆盖手机气血数值")
		await _shot("battle-symbol-hud-phone-resources")
		battle.player.block = 0
		battle.player.persistent_block = 0
		GameState.gold = 6
		_screen._refresh_all()
		_screen._open_menu()
		await _frames()
		PauseMenu._instance._open_settings()
		await _shot("battle-refined-settings-phone")
		var settings: SettingsOverlay = PauseMenu._instance._settings
		_ok(settings._panel.get_global_rect().size.y <= _screen.size.y - 20, "音量设置在小手机可滚动访问，不溢出屏幕")
		PauseMenu._instance._close()
		await _frames()

	# 场景退出必须撤销整桌位移，下一屏不能带着偏移。
	effects.table_impact(7.0)
	effects._process(0.025)
	Router.goto("res://src/screens/title_screen.gd")
	await _frames(6)
	if _capture:
		_ok(Router.study_stage.position == stage_origin, "震动中退出战斗会复位共享书房")
	Settings.reduced_motion = _saved_motion
	Settings.sfx_volume = _saved_volume
	# 无渲染模式帧推进很快，给音频后端一次真实更新来释放旧播放资源。
	await get_tree().create_timer(0.15).timeout
	print("[battle_presentation_regression] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
