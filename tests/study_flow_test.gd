extends Control
var _pass := 0
var _fail := 0
var _started := 0
var _capture := false
var _recording := false
var _frame_number := 0
var _render_ticks := 0
var _stage: StudyStage
var _saved_motion := false
var _saved_style := ""


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture")
	_saved_motion = Settings.reduced_motion
	_saved_style = Settings.visual_style
	Settings.reduced_motion = false
	Ink.apply_style(GameStyle.paper())
	if _capture:
		DirAccess.make_dir_recursive_absolute("res://shots/study-frames")
		RenderingServer.frame_post_draw.connect(_capture_frame)
	EventBus.run_started.connect(func(): _started += 1)
	_run.call_deferred()


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


func _capture_frame() -> void:
	_render_ticks += 1
	if _recording and _render_ticks % 2 == 0:
		get_viewport().get_texture().get_image().save_png("res://shots/study-frames/%03d.png" % _frame_number)
		_frame_number += 1


func _shot(name: String) -> void:
	if not _capture:
		return
	await _frames()
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("res://shots/" + name + ".png")


func _wait_for_map() -> void:
	var frames := 0
	while Router.current_path.contains("title_screen") and frames < 180:
		await get_tree().process_frame
		frames += 1
	_ok(Router.current_path.contains("map_screen"), "镜头过渡结束后进入地图")


func _run() -> void:
	var rng_state: int = GameState.rng.state
	var main: Control = load("res://src/screens/main.gd").new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)
	await _frames(15)
	_stage = Router.study_stage
	_ok(is_instance_valid(_stage) and is_instance_valid(_stage.camera), "真实主场景创建独立 3D 书房和相机")
	_ok(_stage._sun.shadow_enabled and _stage._trees.size() == 2, "窗外树木与投影光源存在")
	_ok(GameState.rng.state == rng_state, "场景建模和树影不使用游戏随机数")
	_ok(_stage.camera_blend == 0, "标题页从书房全景开始")
	await _shot("study-room-live")
	var title: Control = Router.current
	title._open_settings()
	await _frames()
	title._on_start()
	_ok(not title._starting, "设置浮层阻断开始操作")
	for child in title.get_children():
		if child is SettingsOverlay:
			child.queue_free()
	await _frames()
	_recording = _capture
	title._on_start()
	title._on_start()
	_ok(title._starting and _started == 0, "连点开始只启动一次过渡，未提前重置冒险")
	await get_tree().create_timer(0.65).timeout
	_ok(_stage.camera_blend > 0 and _stage.camera_blend < 1, "真实相机在两端之间连续推进")
	await _shot("study-push-live")
	await _wait_for_map()
	await _frames()
	_ok(_started == 1 and GameState.node_index == 1, "只创建一次冒险并保留首个地图节点")
	_ok(is_equal_approx(_stage.camera_blend, 1), "进入地图后相机精确落在桌面机位")
	PauseMenu.open()
	await _frames()
	_ok(is_instance_valid(PauseMenu._instance), "地图界面也能使用统一菜单，没有战斗字段依赖")
	PauseMenu._instance._close()
	await _frames()
	await _shot("study-desk-map-live")
	if _capture:
		await get_tree().create_timer(0.35).timeout
		_recording = false
		var count := FileAccess.open("res://shots/study-frames/count.txt", FileAccess.WRITE)
		count.store_string(str(_frame_number))
	var stage_id := _stage.get_instance_id()
	var map: Control = Router.current
	map._on_node_pressed(0, map.act.nodes[0])
	await _frames()
	_ok(Router.current_path.contains("battle_screen") and _stage.get_instance_id() == stage_id, "从桌面地图进入战斗，复用同一书房")
	_ok(Router.current.battle.turn == 1, "战斗仍使用现有规则与首回合")
	if _capture:
		await get_tree().create_timer(0.30).timeout
	await _shot("study-desk-battle-live")
	Router.goto("res://src/screens/title_screen.gd")
	await _frames()
	_ok(_stage.camera_blend == 0, "返回标题恢复书房全景")
	title = Router.current
	title._on_start()
	await _frames()
	title._cancel_entry()
	await get_tree().create_timer(1.55).timeout
	_ok(Router.current_path.contains("title_screen") and _started == 1, "取消入场后定时器不会再跳地图或重置冒险")
	_ok(_stage.camera_blend == 0 and title._menu.modulate.a == 1, "取消后恢复相机和菜单")
	Settings.reduced_motion = true
	title._on_start()
	_ok(_stage.camera_blend == 1, "减少动效时相机直接切到桌面")
	await _wait_for_map()
	_ok(_started == 2, "减少动效仍只创建一次冒险")
	Router.goto("res://src/screens/title_screen.gd")
	await _frames()
	title = Router.current
	title._on_start()
	Router.goto("res://src/screens/glyph_graph_screen.gd")
	await _frames(8)
	_ok(Router.current_path.contains("glyph_graph_screen"), "中途切屏不会被旧开始定时器跳回地图")
	Settings.reduced_motion = _saved_motion
	Settings.visual_style = _saved_style
	Ink.apply_style(GameStyle.get_style(_saved_style))
	main.queue_free()
	await _frames()
	_ok(not is_instance_valid(Router.study_stage), "退出主场景释放持续书房")
	print("[study_flow_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
