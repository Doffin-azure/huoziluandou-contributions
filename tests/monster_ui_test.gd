extends Control
## 新怪物真实场景回归；-- --capture 可保存3张原生截图。
var checks := 0
var fails := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("[monster_ui] " + label)

func frames(n := 6) -> void:
	for i in n: await get_tree().process_frame

func _ready() -> void:
	await frames()
	GameState.start_new_run("v03")
	Router.host = self
	var fixture := MapNodeData.new()
	fixture.enemies.append(Database.get_enemy("proof_boss"))
	Router.goto("res://src/screens/battle_screen.gd", {"node":fixture,"seed":7})
	await frames()
	var screen: Control = Router.current
	var b: BattleState = screen.battle
	var e: Combatant = b.enemies[0]
	for id in ["proof_boss", "bomb_press", "rail_boss"]:
		e.enemy_data = Database.get_enemy(id)
		e.display_name = e.enemy_data.name
		e.max_hp = e.enemy_data.max_hp
		e.hp = e.max_hp
		e.move_index = 1 if id in ["proof_boss","bomb_press"] else 0
		b.board.cells.fill(null)
		for i in 16:
			var c := CharInstance.new(Database.get_character_by_glyph(["击","破","防","御"][i%4]))
			b.board.cells[i] = c
		EnemyMechanics.begin_phase(b)
		screen._refresh_all()
		await frames()
		var view: EnemyView = screen._enemy_widgets[0]
		check(screen._board_view.enemy_markers.size() >= 2, id + "有可见任务标记")
		check(view._intent.tooltip_text.contains("预告"), id + "详情写明标记坐标")
		check(view._intent._move.damage == b.current_intent(e).damage, id + "UI伤害与逻辑一致")
		check(view._intent.entries[0].value == str(b.current_intent(e).damage), id + "意图图标显示当前数值")
		if OS.get_cmdline_user_args().has("--capture"):
			RenderingServer.force_draw(false)
			var saved := get_viewport().get_texture().get_image().save_png("/private/tmp/huozi-monster-"+id+".png")
			check(saved == OK, "保存截图")
	check(checks == (15 if OS.get_cmdline_user_args().has("--capture") else 12), "所有界面用例完整执行")
	print("[monster_ui_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-fails,fails,checks])
	get_tree().quit(1 if fails else 0)
