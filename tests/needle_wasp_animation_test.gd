extends Control
var _pass := 0
var _fail := 0
var _screen: Control
const GLYPHS := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]


func _ready() -> void:
	_run.call_deferred()


func _ok(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("PASS ",message)
	else:
		_fail += 1
		push_error(message)


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _turn() -> int:
	var effects := {}
	_screen._on_end_turn()
	var deadline := Time.get_ticks_msec() + 6000
	while _screen._busy and Time.get_ticks_msec() < deadline:
		for child in _screen._effects.get_children():
			if child is EnemyAttackEffect: effects[child.get_instance_id()] = true
		await get_tree().process_frame
	_ok(not _screen._busy,"battle input released after animation")
	return effects.size()


func _run() -> void:
	var saved_motion := Settings.reduced_motion
	var saved_style := Ink.style
	Settings.reduced_motion = false
	Ink.apply_style(GameStyle.taopunk())
	AudioServer.set_bus_mute(0,true)
	get_window().size = Vector2i(1980,792)
	await _frames(8)
	GameState.start_new_run("v03",GLYPHS + GLYPHS)
	var data := EnemyData.new()
	data.id = "needle_wasp"
	data.name = "连针蜂"
	data.max_hp = 34
	var multi := EnemyMoveData.new()
	multi.kind = EnemyMoveData.Kind.MULTI
	multi.damage = 3
	multi.hits = 3
	var charge := EnemyMoveData.new()
	charge.kind = EnemyMoveData.Kind.SPECIAL
	charge.title = "蓄势"
	var heavy := EnemyMoveData.new()
	heavy.damage = 10
	data.moves = [multi,charge,heavy]
	var node := MapNodeData.new()
	node.enemies = [data]
	Router.host = self
	Router.goto("res://src/screens/battle_screen.gd",{"node":node,"seed":17})
	_screen = Router.current
	await _frames(12)
	var view: EnemyView = _screen._enemy_widgets[0]
	var actor: NeedleWaspActor = view._visual._character_actor as NeedleWaspActor
	_ok(actor != null and view.has_attack_actor(),"native battle selects the wasp articulated actor")
	_ok(view.attack_effect() == "blade","needle strikes use narrow blade trails")
	_ok(FileAccess.get_sha256(NeedleWaspActor.TEXTURE_PATH) == FileAccess.get_sha256("res://docs/art-concepts/2026-10-17/needle-wasp/v01.png"),"approved artwork stays byte-identical")
	_ok(actor.joints.size() == 11,"eleven independent rigid pieces")
	for id in actor.surfaces:
		var surface: Polygon2D = actor.surfaces[id]
		_ok(Geometry2D.triangulate_polygon(surface.polygon).size() > 0,id + " polygon triangulates")
	var state: int = _screen.battle.rng.state
	await _frames(20)
	_ok(_screen.battle.rng.state == state,"continuous idle never consumes combat RNG")
	actor.sample("idle",0.0,0.25)
	var open: Vector2 = actor.joints.WingNear.scale
	var body: Vector2 = actor.joints.Body.position
	actor.sample("idle",0.0,0.75)
	_ok(open.y - actor.joints.WingNear.scale.y > 0.5,"idle wings visibly open and fold")
	_ok(actor.joints.Body.position == body and actor.surfaces.WingNear.modulate.a == 1.0,"wing motion is independent of torso and uses no opacity flashing")
	_ok(not is_equal_approx(actor.joints.WingNear.rotation,actor.joints.WingFar.rotation),"near and far wings have distinct phases")
	var clock_before := actor.wing_clock
	actor.play_action(multi)
	_ok(actor.wing_clock == clock_before,"attacks preserve continuous wing phase")
	actor.sample("sting_a",0.16,0.25)
	var jab_angle: float = actor.joints.Abdomen.rotation
	var jab_origin := actor.action_global_position()
	actor.sample("heavy",0.48,0.25)
	_ok(actor.joints.Abdomen.rotation > jab_angle + 0.2 and actor.action_global_position().distance_to(jab_origin) > 10,"heavy strike articulates tail more deeply than short jabs")
	var tip: Vector2 = actor.joints.Needle.to_global(Vector2(583,1096) - Vector2(1117,819))
	_ok(actor.action_global_position().distance_to(tip) < 0.01,"damage trajectory follows the transformed needle tip")
	actor._reset_pose()
	actor.player.play("idle")
	var started: Array[StringName] = []
	actor.player.animation_started.connect(func(clip: StringName): started.append(clip))
	var hp: int = _screen.battle.player.hp
	var effects: int = await _turn()
	_ok(_screen.battle.player.hp == hp - 9,"real triple strike deals exactly three times three damage")
	_ok(started.has("sting_a") and started.has("sting_b") and started.has("sting_c"),"each actual hit receives its own jab")
	_ok(effects == 3,"all three real hits emit independent needle trails")
	_ok(actor.player.current_animation == "idle","triple strike returns to flapping idle")
	started.clear()
	hp = _screen.battle.player.hp
	effects = await _turn()
	_ok(started.has("charge") and _screen.battle.player.hp == hp and effects == 0,"real charge plays a preparation pose without phantom damage")
	started.clear()
	effects = await _turn()
	_ok(started.has("heavy") and _screen.battle.player.hp == hp - 10 and effects == 1,"real heavy strike releases once for ten damage")
	view.apply_feedback({"kind":"damage","hp":30,"max_hp":34,"hp_loss":4,"blocked":0,"block":0,"persistent_block":0})
	_ok(actor.player.current_animation == "hit" and view._visual.scale == Vector2.ONE,"hit bends the rig without generic whole-image squash")
	await _frames(30)
	_ok(actor.player.current_animation == "idle","hit recovers to idle")
	view.apply_feedback({"kind":"damage","hp":0,"max_hp":34,"hp_loss":30,"blocked":0,"block":0,"persistent_block":0})
	_ok(actor.player.current_animation == "death" and view._visual.modulate.a == 1.0,"death keeps the articulated wing-fold and fall readable")
	await _frames(50)
	_ok(actor.defeated and not actor.player.is_playing() and actor.modulate.a < 0.01 and actor.wing_rate == 0.0,"defeat stops the wings, fades and never restarts idle")
	actor.defeated = false
	Settings.reduced_motion = true
	await _frames(3)
	_ok(not actor.player.is_playing() and actor.joints.WingNear.scale == Vector2.ONE and actor.flight.position == Vector2.ZERO,"reduced motion restores a static spread-wing pose")
	var timing := actor.play_action(multi)
	_ok(timing.duration == 0.04 and not actor.player.is_playing(),"reduced motion uses brief battle timings")
	actor.defeated = true
	_ok(is_equal_approx(actor.modulate.a,0.18),"reduced-motion defeat stays static")
	view._visual.enemy_id = "paper_shell_soldier"
	_ok(view._visual._paper_actor != null and view._visual._character_actor is PaperShellActor,"switching enemy replaces the wasp rig rather than reusing it")
	view._visual.enemy_id = "ink_spirit"
	_ok(view._visual._character_actor == null and view._visual._actor != null,"switching to guardian restores its original actor")
	Settings.reduced_motion = saved_motion
	Ink.apply_style(saved_style)
	_screen.queue_free()
	Router.current = null
	await _frames(2)
	print("NEEDLE WASP ANIMATION: %d passed, %d failed" % [_pass,_fail])
	get_tree().quit(0 if _fail == 0 else 1)
