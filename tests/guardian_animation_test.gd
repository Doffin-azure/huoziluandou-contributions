extends Control
## 原生演出验证：真实攻击、真实注入、抵消和满盘，另导出连续运行帧。
var _pass := 0
var _fail := 0
var _screen: Control
var _capture := false
var _old_motion := false
const GLYPHS := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]


func _ready() -> void:
	_capture = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _ok(value: bool, description: String) -> void:
	if value:
		_pass += 1
		print("  ✓ ", description)
	else:
		_fail += 1
		push_error(description)


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _record(name: String, count := 48) -> void:
	for i in count:
		await get_tree().process_frame
		if _capture:
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_png("res://shots/guardian-animation/%s-%03d.png" % [name, i])


func _fresh(move_index: int, hole := false) -> void:
	var battle: BattleState = _screen.battle
	battle.abilities.clear()
	battle.player.hp = battle.player.max_hp
	battle.player.statuses.clear()
	battle.player.block = 0
	battle.player.persistent_block = 0
	battle.enemies[0].move_index = move_index
	for i in 16: battle.board.cells[i] = GameState.deck[i]
	if hole: battle.board.cells[5] = null
	_screen._refresh_all()
	await _frames(8)


func _settled() -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while _screen._busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	_ok(not _screen._busy, "演出结束后释放输入锁")


func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	SaveManager.enabled = false
	Settings.storage_path = "user://guardian-test-settings.cfg"
	_old_motion = Settings.reduced_motion
	Settings.reduced_motion = false
	Ink.apply_style(GameStyle.taopunk())
	DirAccess.make_dir_recursive_absolute("res://shots/guardian-animation")
	get_window().size = Vector2i(1280, 720)
	await _frames(12)
	var stage := StudyStage.new()
	add_child(stage)
	Router.study_stage = stage
	Router.host = self
	GameState.start_new_run("v03", GLYPHS + GLYPHS)
	var data := MapNodeData.new()
	data.enemies = [Database.get_enemy("ink_spirit")]
	Router.goto("res://src/screens/battle_screen.gd", {"node": data, "seed": 17})
	_screen = Router.current
	await _frames(25)
	# 等待入场释放输入锁后再点击，不能把入场期间的禁用当作攻击丢失。
	await _settled()
	var visual: InkSpirit = _screen._enemy_widgets[0]._visual
	var actor: InkGuardianActor = visual._actor
	_ok(actor != null and actor.skeleton.get_bone_count() == 5, "墨灵使用五骨骼蒙皮，头部、背环、两侧披风独立运动")
	_ok(actor.mesh.get_bone_count() == 5 and actor.mesh.polygon.size() == 891, "UV 网格绑定实际骨骼")
	_ok(actor.mesh.texture.resource_path.ends_with("ink_guardian.png"), "蒙皮复用原立绘")
	_ok(FileAccess.get_sha256("res://assets/taopunk/ink_guardian.png") == "ae32f6668a72608b730ca0215f3a35541851a3657533d25c45dae11f2a9ce915", "原图逐字节不变")
	var normalized := true
	for p in actor.mesh.uv:
		var weights := InkGuardianActor.skin_weights(p / InkGuardianActor.SOURCE_SIZE)
		var total := 0.0
		for value in weights.values():
			normalized = normalized and value >= 0 and value <= 1
			total += value
		normalized = normalized and is_equal_approx(total, 1.0)
	_ok(normalized, "所有网格权重非负且归一，不产生无绑定顶点")
	var state: int = _screen.battle.rng.state
	await _frames(8)
	_ok(_screen.battle.rng.state == state, "待机不消耗战斗随机数")
	await _fresh(0)
	var hp: int = _screen.battle.player.hp
	_screen._on_end_turn()
	_ok(actor.player.current_animation == "attack", "溅墨触发攻击动作")
	await _record("attack")
	await _settled()
	_ok(_screen.battle.player.hp == hp - 6, "攻击保持实际 6 伤害")
	_ok(actor.player.current_animation == "idle", "攻击结束后回到待机")
	await _fresh(1, true)
	var before := EnemyActionCapture.board_snapshot(_screen.battle.board)
	_screen._on_end_turn()
	_ok(actor.player.current_animation == "inject", "落墨使用独立施法动作")
	var added := EnemyActionCapture.injected(before, EnemyActionCapture.board_snapshot(_screen.battle.board))
	_ok(added.size() == 1 and added[0].cell == Vector2i(1, 1), "只捕获实际注入位置和数量")
	_ok(_screen._events.any(func(event): return event.kind == "enemy_action" and event.get("injected", []).size() == 1), "注入快照进入表现队列")
	await _record("inject")
	await _settled()
	_ok(_screen.battle.board.cells[5].is_enemy_owned() and _screen.battle.board.cells[5].has_pollution("rush"), "落地字仍为敌方实体并带原规则污染")
	_ok(_screen._board_view.tiles[5].display_uid == _screen.battle.board.cells[5].uid, "落地演出与字盘实体一致")
	var first_snapshot := EnemyActionCapture.board_snapshot(_screen.battle.board)
	var next_snapshot := first_snapshot.duplicate(true)
	next_snapshot.append({"uid": -100, "enemy": false, "glyph": "击", "cell": Vector2i.ZERO})
	_ok(EnemyActionCapture.injected(first_snapshot, next_snapshot).is_empty(), "补入玩家字不会误认为敌人注入")
	next_snapshot.append({"uid": -101, "enemy": true, "glyph": "蚀", "cell": Vector2i.ZERO})
	_ok(EnemyActionCapture.injected(first_snapshot, next_snapshot).size() == 1, "后续敌人的快照不会重复归属已有污染字")
	await _fresh(1, true)
	_screen.battle.abilities["prevent_interference"] = 1
	_screen._on_end_turn()
	_ok(_screen._events.any(func(event): return event.kind == "enemy_action" and event.get("injected", []).is_empty()), "抵消注入不会捕获虚假落点")
	await _settled()
	await _fresh(1)
	_screen._on_end_turn()
	_ok(_screen._events.any(func(event): return event.kind == "enemy_action" and event.get("injected", []).is_empty()), "满盘不生成虚假的污染飞行")
	await _settled()
	Settings.reduced_motion = true
	await _frames(2)
	_ok(not actor.player.is_playing(), "减少动效即时停止骨骼动作")
	var resting := true
	for bone in actor.bones.values(): resting = resting and bone.transform.is_equal_approx(bone.rest)
	_ok(resting, "减少动效恢复原画姿态")
	await _fresh(0)
	_screen._on_end_turn()
	await _settled()
	_ok(not actor.player.is_playing() and _screen._effects.get_children().all(func(child): return not child is EnemyInkEffect), "减少动效仍结算战斗且不生成墨迹飞行")
	Settings.reduced_motion = false
	await _frames(2)
	actor.defeated = true
	await _frames(2)
	_ok(actor.player.current_animation == "death", "被击败后播放专属死亡动作而非继续待机")
	Settings.reduced_motion = _old_motion
	Router.study_stage = null
	print("GUARDIAN ANIMATION: %d passed, %d failed" % [_pass, _fail])
	get_tree().quit(0 if _fail == 0 else 1)
