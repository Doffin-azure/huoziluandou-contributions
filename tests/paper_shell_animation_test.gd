extends Control
var _pass := 0
var _fail := 0
var _screen: Control
var _saved_motion := false
var _saved_style: GameStyle
const GLYPHS := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]


func _ready() -> void:
	_run.call_deferred()


func _ok(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("PASS ", message)
	else:
		_fail += 1
		push_error(message)


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _settled() -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while _screen._busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	_ok(not _screen._busy, "battle input released after animation")


func _run() -> void:
	_saved_motion = Settings.reduced_motion
	_saved_style = Ink.style
	Settings.reduced_motion = false
	Ink.apply_style(GameStyle.taopunk())
	AudioServer.set_bus_mute(0, true)
	get_window().size = Vector2i(1980,792)
	await _frames(8)
	GameState.start_new_run("v03", GLYPHS + GLYPHS)
	var data := EnemyData.new()
	data.id = "paper_shell_soldier"
	data.name = "纸壳兵"
	data.max_hp = 32
	var attack := EnemyMoveData.new()
	attack.damage = 6
	var guard := EnemyMoveData.new()
	guard.kind = EnemyMoveData.Kind.BLOCK
	guard.block = 8
	data.moves = [attack,guard]
	var node := MapNodeData.new()
	node.enemies = [data]
	Router.host = self
	Router.goto("res://src/screens/battle_screen.gd", {"node":node,"seed":17})
	_screen = Router.current
	await _frames(12)
	var view: EnemyView = _screen._enemy_widgets[0]
	var actor: PaperShellActor = view._visual._paper_actor
	_ok(actor != null and view.has_attack_actor(), "native EnemyView routes paper attacks to the articulated actor")
	_ok(FileAccess.get_sha256(PaperShellActor.TEXTURE_PATH) == FileAccess.get_sha256("res://docs/art-concepts/2026-10-17/paper-shell-soldier/v05-cutout.png"), "approved concept texture stays byte-identical")
	_ok(actor.joints.size() == 15, "fifteen independent rigid paper joints")
	for id in actor.surfaces:
		var surface: Polygon2D = actor.surfaces[id]
		_ok(Geometry2D.triangulate_polygon(surface.polygon).size() > 0, id + " paper polygon triangulates")
	var state: int = _screen.battle.rng.state
	await _frames(20)
	_ok(_screen.battle.rng.state == state, "idle animation never consumes combat RNG")
	actor.sample("attack",0.40)
	_ok(actor.joints.UpperL.rotation > 1.0 and actor.joints.ForeL.rotation < 0.2, "attack unfolds shoulder and elbow separately")
	var heel: Vector2 = actor.to_local(actor.joints.FootR.global_position)
	_ok(heel.distance_to(Vector2(651,1320)) < 1.0, "supporting foot remains planted during the lunge")
	actor.sample("guard",0.34)
	_ok(actor.joints.ForeL.rotation < -1.5 and actor.joints.ForeR.rotation > 1.5, "guard folds both forearms across the chest")
	var foot_error := 0.0
	for clip in ["idle","attack","guard","hit"]:
		for i in 21:
			actor.sample(clip, float(PaperShellActor.LENGTH[clip]) * float(i) / 20.0)
			var left: Vector2 = actor.to_local(actor.joints.FootL.global_position)
			var right: Vector2 = actor.to_local(actor.joints.FootR.global_position)
			foot_error = maxf(foot_error, left.distance_to(Vector2(375,1340) + actor.left_step))
			foot_error = maxf(foot_error, right.distance_to(Vector2(651,1320) + actor.right_step))
	_ok(foot_error < 1.0, "both ankles follow planted or explicitly stepping targets throughout clips")
	actor._reset_pose()
	actor.player.play("idle")
	var hp: int = _screen.battle.player.hp
	_screen._on_end_turn()
	await _frames(3)
	_ok(actor.player.current_animation == "attack", "real enemy turn starts paper attack")
	await _settled()
	_ok(_screen.battle.player.hp == hp - 6, "real attack deals exactly six damage")
	_ok(actor.player.current_animation == "idle", "attack returns to idle")
	_screen.battle.enemies[0].block = 0
	_screen._refresh_all()
	_screen._on_end_turn()
	await _frames(3)
	_ok(actor.player.current_animation == "guard", "real block move starts the separate fold animation")
	await _settled()
	_ok(_screen.battle.enemies[0].block == 8, "real block feedback shows eight shield")
	view.apply_feedback({"kind":"damage","hp":28,"max_hp":32,"hp_loss":4,"blocked":0,"block":0,"persistent_block":0})
	_ok(actor.player.current_animation == "hit" and view._visual.scale == Vector2.ONE, "hit uses paper joints rather than whole-image squash")
	await _frames(40)
	_ok(actor.player.current_animation == "idle", "hit recovers to idle")
	view.apply_feedback({"kind":"damage","hp":0,"max_hp":32,"hp_loss":28,"blocked":0,"block":0,"persistent_block":0})
	_ok(actor.player.current_animation == "death" and view._visual.modulate.a == 1.0, "death starts a fold collapse without generic immediate dimming")
	await _frames(90)
	_ok(actor.defeated and not actor.player.is_playing() and actor.modulate.a < 0.01, "death finishes without restarting idle")
	actor.defeated = false
	Settings.reduced_motion = true
	await _frames(3)
	_ok(not actor.player.is_playing() and actor.joints.Body.scale == Vector2.ONE, "reduced motion restores the rigid rest pose")
	var timing := actor.play_action(attack)
	_ok(timing.duration == 0.04 and not actor.player.is_playing(), "reduced motion keeps brief combat timings")
	actor.defeated = true
	_ok(is_equal_approx(actor.modulate.a,0.18), "reduced-motion defeat is readable and static")
	Settings.reduced_motion = _saved_motion
	Ink.apply_style(_saved_style)
	_screen.queue_free()
	Router.current = null
	await _frames(2)
	print("PAPER SHELL ANIMATION: %d passed, %d failed" % [_pass,_fail])
	get_tree().quit(0 if _fail == 0 else 1)
