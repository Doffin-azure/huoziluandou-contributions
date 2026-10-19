extends Control
var checks := 0
var fails := 0
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error(note)
func frames(n := 8) -> void:
	for i in n: await get_tree().process_frame
func _ready() -> void:
	await frames()
	Ink.apply_style(GameStyle.taopunk())
	Settings.reduced_motion = false
	Router.host = self
	var classes := {"paper_shell":"PaperShellActor", "needle_bee":"NeedleWaspActor", "tilting_inkwell":"TiltingInkstoneActor", "fold_moth":"FoldPageMothActor"}
	for id in classes:
		GameState.start_new_run("v03")
		var fixture := MapNodeData.new()
		fixture.enemies.append(Database.get_enemy(id))
		Router.goto("res://src/screens/battle_screen.gd", {"node":fixture,"seed":71})
		await frames(12)
		var screen: Control = Router.current
		var b: BattleState = screen.battle
		var e: Combatant = b.enemies[0]
		var visual: InkSpirit = screen._enemy_widgets[0]._visual
		check(e.enemy_data.id == id and visual.has_character_actor(), id + " production resource uses approved animated art")
		check(visual._character_actor.get_script().get_global_name() == classes[id], id + " selects the correct character")
		var rng := b.rng.state
		for index in e.enemy_data.moves.size():
			e.move_index = index
			EnemyMechanics.begin_phase(b)
			var intent := b.current_intent(e)
			var action_rng := b.rng.state
			var before := var_to_str([intent.kind,intent.damage,intent.hits,intent.block,intent.mechanic_action])
			var timing := visual.play_action(intent)
			check(not timing.is_empty(), id + " animates production action " + intent.title)
			if intent.mechanic_action == "gravity": check(timing.get("action") == "tilt", "left gravity plays tilt")
			if intent.mechanic_action == "rotate": check(timing.get("action") == "rotate", "rotation plays rotation")
			if intent.mechanic_action == "fold": check(timing.get("action") == "fold_attack", "fold task plays the fold attack")
			check(before == var_to_str([intent.kind,intent.damage,intent.hits,intent.block,intent.mechanic_action]) and not intent.has_meta("visual_action") and b.rng.state == action_rng, "visual mapping preserves mechanics and RNG")
			if intent.kind == EnemyMoveData.Kind.MULTI:
				for hit in intent.hits: check(visual.play_attack_hit(intent,hit).get("action") == ["sting_a","sting_b","sting_c"][hit%3], "bee keeps three distinct hit animations")
			e.move_index = 0
		EnemyMechanics.begin_phase(b)
		screen._refresh_all()
		await frames(12)
		check(b.rng.state != rng or id != "fold_moth", "fold mechanics still chooses a real target")
		if OS.get_cmdline_user_args().has("--capture"):
			RenderingServer.force_draw(false)
			check(get_viewport().get_texture().get_image().save_png("res://shots/merged-" + id + ".png") == OK, "capture " + id)
	print("[art_design_merge_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-fails,fails,checks])
	get_tree().quit(1 if fails else 0)
