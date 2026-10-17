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
	_ok(not _screen._busy,"battle releases input after action")
	return effects.size()


func _mesh_valid(actor: TiltingInkstoneActor) -> bool:
	var vertices := actor.surface.polygon
	for triangle in actor.surface.polygons:
		var a: Vector2 = vertices[triangle[0]]
		var b: Vector2 = vertices[triangle[1]]
		var c: Vector2 = vertices[triangle[2]]
		if (b - a).cross(c - a) <= 0.01: return false
	return true


func _render_liquid_probe() -> void:
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1375,1144)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var probe := TiltingInkstoneActor.new()
	viewport.add_child(probe)
	probe.set_process(false)
	probe._reset_pose()
	probe.liquid_gain = 0.0
	probe._sync_surface()
	await _frames(2)
	RenderingServer.force_draw(false)
	var rest := viewport.get_texture().get_image()
	var original := probe.surface.texture.get_image()
	var unchanged := true
	for point in [Vector2i(500,200),Vector2i(790,100),Vector2i(650,650)]:
		var actual := rest.get_pixelv(point)
		var expected := original.get_pixelv(point)
		unchanged = unchanged and absf(actual.r - expected.r) < 0.04 and absf(actual.g - expected.g) < 0.04 and absf(actual.b - expected.b) < 0.04
	_ok(unchanged,"native shader preserves original stone, gold and ink colors at rest")
	probe.liquid_gain = 2.0
	probe.liquid_time = 0.9
	probe._sync_surface()
	await _frames(2)
	RenderingServer.force_draw(false)
	var a := viewport.get_texture().get_image()
	probe.liquid_time = 2.7
	probe._sync_surface()
	await _frames(2)
	RenderingServer.force_draw(false)
	var b := viewport.get_texture().get_image()
	_ok(a.get_region(Rect2i(320,440,530,140)).get_data() != b.get_region(Rect2i(320,440,530,140)).get_data(),"native liquid pixels move independently of a stationary body")
	_ok(a.get_region(Rect2i(410,150,180,90)).get_data() == b.get_region(Rect2i(410,150,180,90)).get_data(),"liquid shader leaves face pixels unchanged")
	viewport.queue_free()
	await _frames(2)


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
	data.id = "tilting_inkstone"
	data.name = "倾砚"
	data.max_hp = 34
	var tilt := EnemyMoveData.new()
	tilt.kind = EnemyMoveData.Kind.SPECIAL
	tilt.title = "全盘左倾"
	tilt.set_meta("visual_action","tilt")
	var attack := EnemyMoveData.new()
	attack.damage = 7
	var rotate := EnemyMoveData.new()
	rotate.kind = EnemyMoveData.Kind.SPECIAL
	rotate.title = "中央2×2旋转"
	rotate.set_meta("visual_action","rotate")
	data.moves = [tilt,attack,rotate,attack]
	var node := MapNodeData.new()
	node.enemies = [data]
	Router.host = self
	Router.goto("res://src/screens/battle_screen.gd",{"node":node,"seed":17})
	_screen = Router.current
	_screen.battle.bag.clear()
	for i in 16: _screen.battle.board.cells[i] = GameState.deck[i]
	_screen._refresh_all()
	await _frames(12)
	var view: EnemyView = _screen._enemy_widgets[0]
	var actor: TiltingInkstoneActor = view._visual._character_actor as TiltingInkstoneActor
	_ok(actor != null and view.has_attack_actor(),"battle selects the inkstone actor")
	_ok(view.attack_effect() == "press","stone attack uses a blunt impact trail")
	_ok(FileAccess.get_sha256(TiltingInkstoneActor.TEXTURE_PATH) == FileAccess.get_sha256("res://docs/art-concepts/2026-10-17/tilting-inkstone/v01.png"),"original v01 painting is byte-identical; v02 recolor is unused")
	var state: int = _screen.battle.rng.state
	await _frames(20)
	_ok(_screen.battle.rng.state == state,"idle consumes no combat random numbers")
	actor.sample("idle",0.9,0.9)
	var right: float = actor.body.rotation
	var right_liquid := actor.liquid_angle
	actor.sample("idle",2.7,2.7)
	_ok(right > 0.07 and actor.body.rotation < -0.07,"idle rocks visibly in both directions")
	_ok(right_liquid < 0.0 and actor.liquid_angle > 0.0,"ink surface tilts against the stone")
	actor.sample("idle",1.8,1.8)
	_ok(absf(actor.body.rotation) < 0.01 and absf(actor.liquid_angle) > 0.03,"liquid still moves as stone passes through upright")
	_ok(actor.liquid.get_shader_parameter("ripple_size") > 0.0,"liquid shader also carries a restrained surface wave")
	var planted := true
	for clip in ["idle","tilt","rotate","attack","hit"]:
		for i in 21:
			actor.sample(clip,float(TiltingInkstoneActor.LENGTH[clip]) * float(i) / 20.0,float(i) / 20.0)
			planted = planted and actor.transformed_point(Vector2(300,1030)).distance_to(Vector2(300,1030)) < 0.01
			planted = planted and actor.transformed_point(Vector2(1200,1100)).distance_to(Vector2(1200,1100)) < 0.01
	_ok(planted,"both ink soles remain planted throughout living actions")
	for clip in TiltingInkstoneActor.LENGTH:
		var valid := true
		for i in 25:
			actor.sample(clip,float(TiltingInkstoneActor.LENGTH[clip]) * float(i) / 24.0,float(i) / 24.0)
			valid = valid and _mesh_valid(actor)
		_ok(valid,clip + " mesh never folds over or inverts")
	actor.sample("rotate",0.45,0.45)
	_ok(actor.body.scale.x < 0.85,"twist briefly narrows the stone in perspective")
	actor.sample("attack",0.40,0.40)
	_ok(actor.body.rotation < -0.2 and actor.body.position.x < TiltingInkstoneActor.PIVOT.x - 70,"attack has a distinct anticipatory body slam")
	_ok(actor.action_global_position().distance_to(actor.to_global(actor.transformed_point(Vector2(265,600)))) < 0.01,"impact follows the moving stone edge")
	await _render_liquid_probe()
	actor._reset_pose()
	actor.player.play("idle")
	var started: Array[StringName] = []
	actor.player.animation_started.connect(func(clip: StringName): started.append(clip))
	var hp: int = _screen.battle.player.hp
	var board: Array = _screen.battle.board.cells.duplicate()
	var effects: int = await _turn()
	_ok(started.has("tilt") and _screen.battle.player.hp == hp and effects == 0,"tilt presentation does not invent damage")
	_ok(_screen.battle.board.cells == board,"visual sample does not pretend to implement the future gravity rule")
	started.clear()
	effects = await _turn()
	_ok(started.has("attack") and _screen.battle.player.hp == hp - 7 and effects == 1,"real slam deals exactly seven damage with one trail")
	started.clear()
	hp = _screen.battle.player.hp
	effects = await _turn()
	_ok(started.has("rotate") and _screen.battle.player.hp == hp and effects == 0,"rotation presentation has a distinct action without phantom damage")
	_ok(actor.player.current_animation == "idle","actions recover to rocking idle")
	view.apply_feedback({"kind":"damage","hp":30,"max_hp":34,"hp_loss":4,"blocked":0,"block":0,"persistent_block":0})
	_ok(actor.player.current_animation == "hit" and view._visual.scale == Vector2.ONE,"hit uses articulated stone and liquid without whole-image squeeze")
	await _frames(30)
	_ok(actor.player.current_animation == "idle","hit returns to idle")
	view.apply_feedback({"kind":"damage","hp":0,"max_hp":34,"hp_loss":30,"blocked":0,"block":0,"persistent_block":0})
	_ok(actor.player.current_animation == "death" and view._visual.modulate.a == 1.0,"defeat begins its complete fall")
	await _frames(55)
	_ok(actor.defeated and not actor.player.is_playing() and actor.modulate.a < 0.01,"death fades and never restarts idle")
	actor.defeated = false
	Settings.reduced_motion = true
	await _frames(3)
	_ok(not actor.player.is_playing() and actor.body.rotation == 0.0 and actor.liquid_angle == 0.0,"reduced motion restores static stone and liquid")
	_ok(actor.surface.polygon == actor.rest_vertices,"reduced motion leaves the original mesh undeformed")
	_ok(actor.liquid.get_shader_parameter("ripple_size") == 0.0,"reduced motion stops liquid ripples")
	var timing := actor.play_action(attack)
	_ok(timing.duration == 0.04 and not actor.player.is_playing(),"reduced motion keeps brief action timings")
	actor.defeated = true
	_ok(is_equal_approx(actor.modulate.a,0.18),"reduced-motion death stays static")
	Settings.reduced_motion = saved_motion
	Ink.apply_style(saved_style)
	_screen.queue_free()
	Router.current = null
	await _frames(2)
	print("TILTING INKSTONE ANIMATION: %d passed, %d failed" % [_pass,_fail])
	get_tree().quit(0 if _fail == 0 else 1)
