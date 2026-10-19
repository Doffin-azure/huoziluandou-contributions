extends Control
var _screen: Control
var _pass := 0
var _fail := 0
var _capture := false
var _recording := false
var _frame := 0
var _saved_motion := false
const GRID := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_saved_motion = Settings.reduced_motion
	Settings.reduced_motion = false
	if _capture:
		DirAccess.make_dir_recursive_absolute("res://shots/glyph-vfx-frames")
		RenderingServer.frame_post_draw.connect(_capture_frame)
	_run.call_deferred()


func _capture_frame() -> void:
	if _recording:
		get_viewport().get_texture().get_image().save_png("res://shots/glyph-vfx-frames/%04d.png" % _frame)
		_frame += 1


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


func _live(phase := "") -> Array:
	return _screen._effects.get_children().filter(func(child): return child is GlyphEffect and not child.is_queued_for_deletion() and (phase.is_empty() or child.phase == phase))


func _prepare(word: String) -> void:
	var battle: BattleState = _screen.battle
	battle.player.heat = 0
	if word == "冷": battle.player.heat = 5
	battle.player.energy = 0
	battle.player.hp = 45
	battle.player.block = 0
	battle.player.persistent_block = 0
	battle.abilities.clear()
	battle.bag.clear()
	battle.discard.clear()
	for index in 16:
		var glyph: String = word.substr(index, 1) if index < word.length() else GRID[index]
		battle.board.cells[index] = CharInstance.new(Database.get_character_by_glyph(glyph))
	_screen._refresh_all()
	_screen._board_view.path = [Vector2i.ZERO] if word.length() == 1 else [Vector2i.ZERO, Vector2i(1, 0)]
	_screen._board_view._sync_selection()


func _idle() -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while _screen._busy and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_ok(not _screen._busy, "演出完成，输入恢复")


func _run() -> void:
	GameState.start_new_run("v03")
	if _capture:
		var stage := StudyStage.new()
		add_child(stage)
		Router.study_stage = stage
	Router.host = self
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 7})
	await _frames(8)
	_screen = Router.current
	var battle: BattleState = _screen.battle
	var all_mapped := Database.characters.values().all(func(data): return GlyphVfxProfile.GLYPHS.has(data.glyph) and BattleSymbol.SPECS.has(GlyphVfxProfile.for_glyph(data.glyph).symbol))
	_ok(all_mapped, "词库全部 %d 个字均有图标、粒子形状和轨迹配置" % Database.characters.size())
	_ok(GlyphVfxProfile.for_glyph("火").style != GlyphVfxProfile.for_glyph("热").style and GlyphVfxProfile.for_glyph("电").style != GlyphVfxProfile.for_glyph("蓄").style, "同字系也区分火星/热气、电弧/蓄能聚点")
	var combined := GlyphVfxProfile.for_play(["电", "火"], Database.get_word_by_glyphs_string("电火"))
	_ok(combined.parts.size() == 2 and combined.parts[0].symbol != combined.parts[1].symbol, "组合词保留不同字的独立符号")
	var names := ["火", "电", "冷", "防", "重", "金", "心", "击破"]
	var families := ["fire", "electric", "ice", "shield", "gravity", "gold", "heal", "hit"]
	for index in names.size():
		_prepare(names[index])
		if names[index] == "防":
			_ok(_screen._selection_context([Vector2i.ZERO]).contains("自身护盾"), "防御预览明确指向自身护盾，不误标为敌人")
		elif names[index] == "火":
			_ok(_screen._selection_context([Vector2i.ZERO]).contains("热度"), "资源预览目标与图标投送终点一致")
		var rng_before: int = battle.rng.state
		var enemy_before: int = battle.enemies[0].hp
		_recording = _capture
		_screen._on_primary()
		var deadline := Time.get_ticks_msec() + 3000
		while _live("cast").is_empty() and _screen._busy and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		var flights := _live("cast")
		_ok(not flights.is_empty() and flights[0].profile.family == families[index], "真实出字 %s 使用自己的符号与表现家族" % names[index])
		if names[index] == "火" or names[index] == "电":
			var focus := "heat" if names[index] == "火" else "energy"
			_ok(flights[0].destination.distance_to(_screen._status_point(focus) / _screen._effects._ui_scale) < 1, "资源字飞向状态栏对应资源，不误飞向气血")
		elif names[index] == "防":
			_ok(flights[0].destination.distance_to(_screen._defense_point("block") / _screen._effects._ui_scale) < 1, "防御字飞向血条护盾位置，不落在能力栏")
		await _idle()
		if names[index] != "击破":
			_ok(battle.enemies[0].hp == enemy_before, "非攻击字 %s 不伪造敌方受击" % names[index])
		_ok(battle.rng.state == rng_before, "%s 的图标与粒子不使用战斗随机数" % names[index])
		if _capture:
			await get_tree().create_timer(0.34).timeout
			_recording = false
			await get_tree().create_timer(0.16).timeout
	if _capture:
		_recording = false
		var count := FileAccess.open("res://shots/glyph-vfx-frames/count.txt", FileAccess.WRITE)
		count.store_string(str(_frame))
	# 明确目标词的图标终点与区域选择相同。
	_prepare("回转")
	_screen._on_primary()
	_screen._board_view._on_tile_pressed(Vector2i(2, 2))
	_screen._on_primary()
	await _idle()
	_ok(_live().any(func(effect): return effect.profile.style == "swirl"), "回转在选定区域出现旋转轨迹")
	# 多段伤害仍逐段使用实际反馈；格挡不会冒充生命损失。
	_prepare("击破")
	battle.enemies[0].block = 20
	_screen._on_primary()
	await _idle()
	_ok(_live().any(func(effect): return effect.profile.family == "shield"), "全格挡显示盾形粒子，不冒充生命受伤")
	# 控制效果节点总量，切屏与减少动效均能清理。
	for index in 30:
		_screen._effects.glyph_impact(GlyphVfxProfile.for_glyph("爆"), Vector2(400, 300))
	_ok(_live().size() <= BattleEffects.MAX_GLYPH_EFFECTS, "高频多段演出最多保留 10 个图标/粒子节点")
	await _frames()
	Settings.reduced_motion = true
	await _frames()
	_screen._effects.glyph_impact(GlyphVfxProfile.for_glyph("电"), Vector2(400, 300))
	_ok(_live().size() == 1 and _live()[0]._particles.is_empty(), "减少动效只保留短暂静态图标，不产生粒子")
	Settings.reduced_motion = false
	_prepare("急停")
	var turn_before: int = battle.turn
	_screen._on_primary()
	await _idle()
	_ok(battle.turn == turn_before + 1, "急停立即结束回合，并释放出字锁")
	if _capture:
		await _gallery()
	_screen._effects.glyph_impact(GlyphVfxProfile.for_glyph("爆"), Vector2(400, 300))
	var owned: Array = _live().duplicate()
	Router.goto("res://src/screens/title_screen.gd")
	await _frames(8)
	_ok(not owned.is_empty() and owned.all(func(effect): return not is_instance_valid(effect)), "退出战斗释放全部图标与粒子")
	Settings.reduced_motion = _saved_motion
	await get_tree().create_timer(0.15).timeout
	print("[glyph_vfx_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _gallery() -> void:
	var page := Control.new()
	page.z_index = 100
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	var backdrop := ColorRect.new()
	backdrop.color = Palette.PAPER
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(backdrop)
	var title := Ink.h2("出字表现 · 实际引擎渲染")
	title.position = Vector2(42, 20)
	page.add_child(title)
	var examples := ["火", "热", "电", "蓄", "冷", "盾", "重", "回", "金", "心", "蚀", "爆"]
	for index in examples.size():
		var cell := Vector2(index % 4, index / 4) * Vector2(305, 206) + Vector2(42, 78)
		var heading := Ink.label(examples[index], "Heading")
		heading.position = cell
		page.add_child(heading)
		var effect := GlyphEffect.new()
		effect.profile = GlyphVfxProfile.for_glyph(examples[index])
		effect.scale = Vector2.ONE * 1.5
		effect.destination = (cell + Vector2(134, 110)) / 1.5
		effect.radius = 48
		page.add_child(effect)
		effect.freeze_at(0.46)
	await _frames(3)
	RenderingServer.force_draw(false)
	_ok(get_viewport().get_texture().get_image().save_png("res://shots/glyph-vfx-gallery.png") == OK, "导出十二种图标和粒子形态对照")
	page.queue_free()
