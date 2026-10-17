extends Control
## 在原生渲染器中验证定稿素材、字体切换和真实输入；配置使用独立临时文件。
var _pass := 0
var _fail := 0
var _screen: Control
var _capture := false
var _old_style := ""
var _old_font := ""
var _old_path := ""
var _old_cfg: ConfigFile
var _old_release := false
var _settings_path := "user://taopunk_art_test_%d.cfg" % Time.get_ticks_usec()
const GLYPHS := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_run.call_deferred()


func _ok(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("  ✓ ", message)
	else:
		_fail += 1
		push_error(message)


func _frames(count := 12) -> void:
	for i in count: await get_tree().process_frame


func _shot(name: String) -> void:
	if not _capture or DisplayServer.get_name() == "headless": return
	await _frames(4)
	RenderingServer.force_draw(false)
	_ok(get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % name) == OK, "实际截图 " + name)


func _run() -> void:
	_old_style = Settings.visual_style
	_old_font = Settings.board_font_path
	_old_path = Settings.storage_path
	_old_cfg = Settings._cfg
	_old_release = Settings.drag_release_play
	Settings._cfg = ConfigFile.new()
	Settings.storage_path = _settings_path
	Settings.visual_style = "taopunk"
	Settings.drag_release_play = false
	Ink.apply_style(GameStyle.taopunk())
	get_window().size = Vector2i(1280, 720)
	await _frames()
	var stage := StudyStage.new()
	add_child(stage)
	Router.study_stage = stage
	Router.host = self
	GameState.start_new_run("v03", GLYPHS + GLYPHS)
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 17})
	_screen = Router.current
	_screen.battle.bag.clear()
	for i in 16: _screen.battle.board.cells[i] = GameState.deck[i]
	for i in range(16, 32): _screen.battle.bag.append(GameState.deck[i])
	_screen._refresh_all()
	await _frames(25)
	_ok(Palette.STYLE_ID == "taopunk" and Palette.WOOD == Color("1f4946"), "青铜绘卷使用独立风格令牌")
	_ok(stage._illustrated_backdrop.visible and not stage._display.visible and not stage.shared_table_active(), "定稿环境为独立手绘背景，保留书房场景供切换")
	_ok(stage.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "手绘战斗中停用隐藏的书房 3D 渲染")
	var board: BoardView = _screen._board_view
	var presentation: BoardPresentation3D = board._presentation
	_ok(presentation != null and presentation.actors.size() == 16 and presentation._shared_stage == null, "16 个字块仍有真实独立 3D 命中与动效")
	_ok(presentation.get_children().any(func(child): return child is BronzeFrame), "青铜框独立于实时字块")
	_ok(FileAccess.get_sha256("res://assets/taopunk/ink_guardian.png") == "ae32f6668a72608b730ca0215f3a35541851a3657533d25c45dae11f2a9ce915", "墨灵素材保持原版本，未采用精简或重绘稿")
	var paths := []
	for id in TaopunkArt.ENEMIES:
		if id == "ink_spirit":
			var guardian := TaopunkArt.portrait(id)
			_ok(guardian != null and guardian.resource_path.ends_with("ink_guardian.png"), "墨灵使用从定稿提取的独立角色")
			continue
		var portrait: AtlasTexture = TaopunkArt.portrait(id)
		_ok(portrait != null and portrait.atlas.resource_path.ends_with("enemies/%s.png" % id) and not paths.has(portrait.atlas.resource_path), "敌人 %s 映射独立场景插画" % id)
		paths.append(portrait.atlas.resource_path)
		_ok(Rect2(Vector2.ZERO, portrait.atlas.get_size()).encloses(portrait.region) and portrait.get_image().detect_alpha() != Image.ALPHA_NONE, "%s 取区有效且保留透明通道" % id)
		var contained := true
		for area in [Vector2(450, 342), Vector2(220, 150)]:
			contained = contained and Rect2(Vector2.ZERO, area).grow(0.1).encloses(InkSpirit.portrait_rect(portrait, area, id))
		_ok(contained, "%s 在桌面和手机中完整显示并贴住台面" % id)
	_ok(TaopunkArt.portrait("unknown") == null, "未知敌人保留旧有绘制回退")
	var frame := TaopunkArt.frame().get_image()
	_ok(frame.get_pixel(frame.get_width() / 2, frame.get_height() / 2).a < 0.01, "边框中央透明，不遮挡实时汉字")
	board.path = [Vector2i(0, 0), Vector2i(1, 0)]
	board._sync_selection()
	get_window().size = Vector2i(1980, 792)
	await _frames()
	_ok(_screen._preview_panel.size.aspect() > 0.9 and _screen._preview_panel.size.aspect() < 1.1, "宽屏纸面保留定稿近方形构图")
	_ok(board.size.x < _screen.size.x * 0.32 and _screen._topbar.size.x < _screen.size.x * 0.85, "桌面字盘与顶栏留出场景空间")
	await _shot("taopunk-battle-reference-aspect")
	_ok(not _screen._bubble._scroll.get_v_scroll_bar().visible, "定稿击破词效完整呈现，无需滚动")
	get_window().size = Vector2i(1280, 720)
	await _frames()
	await _shot("taopunk-battle-desktop")
	var rng_state: int = _screen.battle.rng.state
	var battle_id: int = _screen.battle.get_instance_id()
	var picker := BoardFontPicker.new()
	_screen.add_child(picker)
	var original_font: Font = Ink.board_font
	picker._choose("res://assets/fonts/NotoSerifSC-VF.ttf")
	_ok(Ink.board_font != original_font and presentation.actors[0].glyph.font == Ink.board_font, "字体选择实时更新 3D 字盘字形")
	_ok(board.tiles[0]._glyph.get_theme_font("font") == Ink.board_font, "2D 字盘回退也使用自定义字体")
	var preferences := ConfigFile.new()
	_ok(preferences.load(_settings_path) == OK and preferences.get_value("visual", "board_font") == "res://assets/fonts/NotoSerifSC-VF.ttf", "字体路径保存到配置")
	picker._choose("res://missing-font.ttf")
	_ok(Ink.board_font == presentation.actors[0].glyph.font and Settings.board_font_path == "res://assets/fonts/NotoSerifSC-VF.ttf", "无效字体不覆盖当前选择")
	_ok(BoardTypography.load_font("res://project.godot", Ink.serif) == null, "非字体文件被拒绝")
	Settings.set_board_font_path("")
	_ok(Ink.board_font == Ink.serif, "恢复默认字体")
	picker.queue_free()
	_ok(_screen.battle.get_instance_id() == battle_id and _screen.battle.rng.state == rng_state and board.path.size() == 2, "字体切换不重置战斗、连线或随机数")
	var old_hp: int = _screen.battle.enemies[0].hp
	await _screen._on_primary()
	while _screen._busy: await get_tree().process_frame
	_ok(_screen.battle.enemies[0].hp == old_hp - 8, "定稿字盘仍能打出击破并结算 8 伤害")
	get_window().size = Vector2i(844, 390)
	await _frames()
	_screen._layout()
	board.path = []
	await _shot("taopunk-battle-phone")
	var factor := float(get_window().size.y) / _screen.size.y
	_ok(_screen._enemy_panel.position.x > board.position.x + board.size.x and _screen._preview_panel.position.x < board.position.x, "手机保持左词效、中央字盘、右敌人")
	var all_targets := true
	for i in 16:
		var bounds := presentation.cell_rect(i)
		all_targets = all_targets and bounds.size.x * factor >= 48 and bounds.size.y * factor >= 48
	_ok(all_targets, "手绘风格保留手机 48×48 字块触控尺寸")
	_screen._open_menu()
	await _frames()
	PauseMenu._instance._open_settings()
	await _frames()
	var settings: SettingsOverlay = PauseMenu._instance._settings
	_ok(settings.find_children("*", "Control", true, false).any(func(child): return child is BoardFontPicker), "真实设置页提供字体入口")
	await _shot("taopunk-settings-phone")
	settings.find_children("*", "Button", true, false).filter(func(b): return b.text == "关闭")[0].pressed.emit()
	_ok(Palette.STYLE_ID == "taopunk" and _screen.battle.get_instance_id() == battle_id, "关闭设置保留青铜绘卷与当前战斗")
	Router.goto("res://src/screens/map_screen.gd")
	await _frames()
	_ok(Palette.STYLE_ID == "taopunk", "离开战斗后仍使用青铜绘卷")
	Settings.visual_style = _old_style
	Settings.board_font_path = _old_font
	Settings.storage_path = _old_path
	Settings._cfg = _old_cfg
	Settings.drag_release_play = _old_release
	Ink._reload_board_font(_old_font)
	Ink.apply_style(GameStyle.get_style(_old_style))
	if FileAccess.file_exists(_settings_path): DirAccess.remove_absolute(_settings_path)
	Router.study_stage = null
	print("TAOPUNK ART: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(1 if _fail else 0)
