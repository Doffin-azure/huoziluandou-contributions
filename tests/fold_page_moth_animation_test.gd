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
	_ok(not _screen._busy,"battle releases input after complete recovery")
	return effects.size()


func _leaf_mesh_valid(actor: FoldPageMothActor, id: String) -> bool:
	var surface: Polygon2D = actor.surfaces[id]
	var vertices := surface.polygon
	for triangle in surface.polygons:
		var a: Vector2 = vertices[triangle[0]]
		var b: Vector2 = vertices[triangle[1]]
		var c: Vector2 = vertices[triangle[2]]
		if (b - a).cross(c - a) <= 0.001: return false
	return true


func _render_probe() -> void:
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1402,1122)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var probe := FoldPageMothActor.new()
	viewport.add_child(probe)
	probe.set_process(false)
	probe._reset_pose()
	probe._sync_pose()
	await _frames(2)
	RenderingServer.force_draw(false)
	var original: Image = probe.surfaces.WingNear.texture.get_image()
	var rest := viewport.get_texture().get_image()
	var unchanged := true
	for point in [Vector2i(1100,220),Vector2i(440,300),Vector2i(1190,560),Vector2i(430,704)]:
		var actual := rest.get_pixelv(point)
		var expected: Color = original.get_pixelv(point)
		unchanged = unchanged and absf(actual.r - expected.r) < 0.04 and absf(actual.g - expected.g) < 0.04 and absf(actual.b - expected.b) < 0.04
	_ok(unchanged,"native rest pose preserves approved paper, gold and body colors")
	probe.corner_fold = 1.0
	probe._sync_pose()
	await _frames(2)
	RenderingServer.force_draw(false)
	var folded := viewport.get_texture().get_image()
	_ok(rest.get_region(Rect2i(1100,470,270,240)).get_data() != folded.get_region(Rect2i(1100,470,270,240)).get_data(),"native corner pixels fold and shade independently")
	_ok(rest.get_region(Rect2i(650,240,200,150)).get_data() == folded.get_region(Rect2i(650,240,200,150)).get_data(),"corner fold leaves the uncreased paper unchanged")
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
	data.id = "fold_page_moth"
	data.name = "折页蛾"
	data.max_hp = 32
	var mark := EnemyMoveData.new()
	mark.kind = EnemyMoveData.Kind.SPECIAL
	mark.title = "折页标记"
	mark.set_meta("visual_action","mark")
	var strong := EnemyMoveData.new()
	strong.damage = 8
	strong.set_meta("visual_action","fold_attack")
	var weak := EnemyMoveData.new()
	weak.damage = 5
	weak.set_meta("visual_action","fold_attack")
	var attack := EnemyMoveData.new()
	attack.damage = 7
	data.moves = [mark,strong,weak,attack]
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
	var actor: FoldPageMothActor = view._visual._character_actor as FoldPageMothActor
	_ok(actor != null and view.has_attack_actor(),"battle selects the articulated left-facing moth")
	_ok(view.attack_effect() == "paper","moth emits paper trails")
	_ok(FileAccess.get_sha256(FoldPageMothActor.TEXTURE_PATH) == FileAccess.get_sha256("res://docs/art-concepts/2026-10-17/fold-page-moth/v02.png"),"approved left-facing v02 stays byte-identical")
	_ok(actor.joints.size() == 7,"seven independently articulated parts")
	for id in actor.surfaces:
		var surface: Polygon2D = actor.surfaces[id]
		var valid := _leaf_mesh_valid(actor,id) if actor.wing_vertices.has(id) else Geometry2D.triangulate_polygon(surface.polygon).size() > 0
		_ok(valid,id + " has valid painting geometry")
	var state: int = _screen.battle.rng.state
	await _frames(20)
	_ok(_screen.battle.rng.state == state,"idle consumes no combat RNG")
	actor.sample("idle",0.0,0.0)
	var open: PackedVector2Array = actor.surfaces.WingNear.polygon.duplicate()
	actor.sample("idle",0.75,0.75)
	_ok(actor.surfaces.WingNear.polygon != open and actor.near_close > actor.far_close,"idle pages open and close with separate phases")
	_ok(not is_equal_approx(actor.joints.RibbonRed.rotation,actor.joints.RibbonIvory.rotation),"bookmark strips trail with different phases")
	actor.sample("mark",0.55,0.55)
	_ok(actor.corner_fold > 0.99 and actor.near_close < 0.2,"mark folds only the outer corner while keeping pages spread")
	_ok(actor.folded_source_point(Vector2(1306,615)).distance_to(Vector2(1306,615)) > 40.0,"corner fold has a readable inward movement")
	_ok(actor.folded_source_point(Vector2(800,250)) == Vector2(800,250),"uncreased page area remains rigid")
	actor.sample("fold_attack",0.50,0.50)
	_ok(actor.near_close > 0.9 and actor.far_close > 0.8 and actor.corner_fold > 0.9,"fold attack snaps both leaves together after folding")
	actor.sample("attack",0.34,0.34)
	_ok(actor.corner_fold == 0.0 and actor.near_close > 0.9,"ordinary attack has a separate faster unmarked clap")
	_ok(actor.action_global_position().distance_to(actor.joints.WingFar.to_global(actor.leaf_point("WingFar",Vector2(374,70)))) < 0.01,"paper trail starts at the moving leading page edge")
	for clip in FoldPageMothActor.LENGTH:
		var valid := true
		var readable := true
		for i in 21:
			actor.sample(clip,float(FoldPageMothActor.LENGTH[clip]) * float(i) / 20.0,float(i) / 20.0)
			for id in actor.wing_vertices:
				valid = valid and _leaf_mesh_valid(actor,id)
				var surface: Polygon2D = actor.surfaces[id]
				for point in surface.polygon:
					readable = readable and surface.to_global(point).y > view._intent.get_global_rect().end.y + 8.0
		_ok(valid,clip + " leaf mesh remains finite and never inverts")
		_ok(readable,clip + " pages stay below the intent UI")
	await _render_probe()
	actor._reset_pose()
	actor.player.play("idle")
	var started: Array[StringName] = []
	actor.player.animation_started.connect(func(clip: StringName): started.append(clip))
	var hp: int = _screen.battle.player.hp
	var board: Array = _screen.battle.board.cells.duplicate()
	var effects: int = await _turn()
	_ok(started.has("mark") and _screen.battle.player.hp == hp and effects == 0,"mark presentation has no phantom damage")
	_ok(_screen.battle.board.cells == board,"visual sample leaves future entity-mark rules untouched")
	_ok(actor.player.current_animation == "idle","mark finishes before input resumes")
	for move in [strong,weak,attack]:
		started.clear()
		hp = _screen.battle.player.hp
		effects = await _turn()
		var expected := "attack" if move == attack else "fold_attack"
		_ok(started.has(expected) and hp - _screen.battle.player.hp == move.damage and effects == 1,"real %s deals exactly %d once" % [expected,move.damage])
		_ok(actor.player.current_animation == "idle","attack recovers to book-page idle")
	view.apply_feedback({"kind":"damage","hp":28,"max_hp":32,"hp_loss":4,"blocked":0,"block":0,"persistent_block":0})
	_ok(actor.player.current_animation == "hit" and view._visual.scale == Vector2.ONE,"hit separates the leaves instead of squeezing the whole image")
	await _frames(30)
	_ok(actor.player.current_animation == "idle","hit recovers to idle")
	view.apply_feedback({"kind":"damage","hp":0,"max_hp":32,"hp_loss":28,"blocked":0,"block":0,"persistent_block":0})
	_ok(actor.player.current_animation == "death" and view._visual.modulate.a == 1.0,"death keeps its complete fold and fall")
	await _frames(55)
	_ok(actor.defeated and not actor.player.is_playing() and actor.modulate.a < 0.01,"death finishes without restarting idle")
	actor.defeated = false
	Settings.reduced_motion = true
	await _frames(3)
	_ok(not actor.player.is_playing() and actor.near_close == 0.0 and actor.corner_fold == 0.0,"reduced motion restores spread pages and original corner")
	_ok(actor.joints.RibbonRed.rotation == 0.0 and actor.joints.AntennaNear.rotation == 0.0,"reduced motion also stops bookmarks and antennae")
	var timing := actor.play_action(strong)
	_ok(timing.duration == 0.04 and not actor.player.is_playing(),"reduced motion keeps brief combat timings")
	actor.defeated = true
	_ok(is_equal_approx(actor.modulate.a,0.18),"reduced-motion defeat is static")
	Settings.reduced_motion = saved_motion
	Ink.apply_style(saved_style)
	_screen.queue_free()
	Router.current = null
	await _frames(2)
	print("FOLD PAGE MOTH ANIMATION: %d passed, %d failed" % [_pass,_fail])
	get_tree().quit(0 if _fail == 0 else 1)
