extends Control
## Native coverage of every loaded enemy and real battle animation routing.
const QA := "res://docs/qa/enemy-completion-2026-10-20/"
var passed := 0
var failed := 0
var _capture := false


func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS ",message)
	else: failed += 1; push_error(message)


func frames(n := 5) -> void:
	for i in n: await get_tree().process_frame


func _ready() -> void:
	SaveManager.enabled = false
	Settings.reduced_motion = false
	Ink.apply_style(GameStyle.taopunk())
	get_window().size = Vector2i(1280,720)
	_capture = OS.get_cmdline_user_args().has("--capture")
	DirAccess.make_dir_recursive_absolute(QA)
	Router.host = self
	_run.call_deferred()


func body_actor(art: InkSpirit) -> Node2D:
	if art.has_character_actor(): return art._character_actor
	if art._actor != null: return art._actor
	if art._attack_actor != null: return art._attack_actor._rest_actor
	return null


func _run() -> void:
	check(Database.enemies.size() == 29 and TaopunkArt.ENEMIES.size() == 29,"all twenty-nine loaded enemies are mapped")
	var texture_paths: Array = []
	for id in Database.enemies:
		var portrait := TaopunkArt.portrait(id)
		check(portrait != null and portrait.get_width() >= 500 and portrait.get_height() >= 500,id + " owns a full-resolution portrait")
		var texture: Texture2D = portrait.atlas if portrait is AtlasTexture else portrait
		check(not texture_paths.has(texture.resource_path),id + " does not borrow another enemy texture")
		texture_paths.append(texture.resource_path)
		var art := InkSpirit.new()
		art.enemy_id = id
		art.size = Vector2(430,400)
		add_child(art)
		await frames(2)
		var actor := body_actor(art)
		check(actor != null and (art.has_attack_actor() or art._actor != null),id + " mounts an actual animated actor")
		if actor == null: art.queue_free(); continue
		var player: AnimationPlayer = actor.get("player")
		check(player.has_animation("idle") and player.has_animation("hit") and player.has_animation("death"),id + " has idle, hit and death clips")
		var state := GameState.rng.state
		for move in Database.get_enemy(id).moves:
			var timing: Dictionary = art.play_attack_hit(move,0) if move.kind in [EnemyMoveData.Kind.ATTACK,EnemyMoveData.Kind.MULTI,EnemyMoveData.Kind.ATTACK_BLOCK] and art.has_attack_actor() else art.play_action(move)
			check(timing.has("release") and timing.has("duration") and float(timing.duration) >= float(timing.release),id + " animates " + move.title + " with valid impact timing")
			await frames()
		check(GameState.rng.state == state,id + " animation does not consume gameplay RNG")
		if actor is RosterEnemyActor:
			var normalized := true
			for y in 11:
				for x in 11:
					var weights: Dictionary = actor.skin_weights(Vector2(x,y)/10.0)
					var total := 0.0
					for weight in weights.values():
						normalized = normalized and float(weight) >= 0.0
						total += float(weight)
					normalized = normalized and absf(total-1.0) < 0.001
			check(normalized,id + " skin weights stay normalized over the whole artwork")
			check(player.get_animation("attack").get_track_count() >= 7,id + " attack moves independent anatomical joints")
		art.apply_character_feedback({"hp":20,"hp_loss":2})
		await frames(2)
		check(player.current_animation == "hit",id + " real feedback enters the hit clip")
		art.set_defeated(true)
		await frames(2)
		check(player.current_animation == "death",id + " defeat enters the death clip")
		await get_tree().create_timer(1.30).timeout
		check(player.current_animation != "idle" and actor.modulate.a <= 0.20,id + " death settles without restarting idle")
		Settings.reduced_motion = true
		await frames(2)
		check(not player.is_playing(),id + " reduced motion stops animated playback")
		Settings.reduced_motion = false
		art.queue_free()
		await frames(2)
	# Use real enemy turn replays for one member of each motion family.
	for id in ["blank_child","corrosion_beetle","glutton","furnace_beast","charge_badger","ink_creditor","double_slip","nest_moth","bomb_press","copy_master","seal_officer","wheel_master","leech","proof_boss","rail_boss","compiler_boss"]:
		GameState.start_new_run()
		var node := MapNodeData.new()
		node.enemies = [Database.get_enemy(id)]
		Router.goto("res://src/screens/battle_screen.gd",{"node":node,"seed":29})
		await frames(14)
		var screen = Router.current
		var entry_deadline := Time.get_ticks_msec()+8000
		while screen._busy and Time.get_ticks_msec() < entry_deadline: await get_tree().process_frame
		var actor: RosterEnemyActor = screen._enemy_widgets[0]._visual._character_actor
		var started: Array = []
		actor.player.animation_started.connect(func(action): started.append(str(action)))
		var before: int = screen.battle.player.hp
		screen._on_end_turn()
		var deadline := Time.get_ticks_msec()+18000
		while screen._busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
		check(not screen._busy and started.any(func(action):return action in ["attack","guard","special"]),id + " actual battle turn routes into its own animation")
		check(screen.battle.player.hp <= before and screen._enemy_attack_context.is_empty(),id + " actual settlement completes and clears replay context")
		if id in ["proof_boss","rail_boss","compiler_boss"]:
			screen.battle.enemies[0].hp = screen.battle.enemies[0].max_hp/2
			screen._refresh_all()
			check(actor._phase == 2 and actor.player.current_animation == "phase",id + " actual half-health refresh triggers its phase transition")
		if _capture and id in ["blank_child","glutton","bomb_press","proof_boss","rail_boss","compiler_boss"]:
			await frames(8)
			RenderingServer.force_draw(false)
			check(get_viewport().get_texture().get_image().save_png(QA+"battle-"+id+".png") == OK,"capture " + id)
		if id in ["blank_child","proof_boss","rail_boss","compiler_boss"]:
			get_window().size = Vector2i(640,360)
			await frames(14)
			var view: EnemyView = screen._enemy_widgets[0]
			var extent: Rect2 = actor.global_transform * actor.framing().rect
			check(view._portrait.get_global_rect().grow(2).encloses(extent),id + " whole illustration fits the phone portrait area")
			if _capture:
				RenderingServer.force_draw(false)
				get_viewport().get_texture().get_image().save_png(QA+"phone-"+id+".png")
			get_window().size = Vector2i(1280,720)
			await frames(10)
	Router.release_host(self)
	print("[enemy_art_completion_test] PASS=%d FAIL=%d TOTAL=%d" % [passed,failed,passed+failed])
	get_tree().quit(1 if failed else 0)
