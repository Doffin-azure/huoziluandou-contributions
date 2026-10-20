extends Control
var checks := 0
var failures := 0
const SLOT := "user://achievement-checkpoint-test.save"
var profile_path := ""
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func frames(count := 8) -> void:
	for i in count: await get_tree().process_frame
func _ready() -> void:
	GameState.set_meta("courtyard_preview", false)
	Settings.reduced_motion = true
	Achievements.test_enabled = true
	Achievements.autosave = false
	profile_path = "user://checkpoint-achievements-%d.json" % Time.get_ticks_usec()
	Achievements.storage_path = profile_path
	SaveManager.activate(SLOT); SaveManager.clear_run()
	GameState.start_new_run("v03")
	Achievements.start_run("classic")
	var id := Achievements.run_id
	Router.host = self
	var node := MapNodeData.new()
	node.enemies.append(Database.get_enemy("iron_seal"))
	Router.goto("res://src/screens/battle_screen.gd", {"node":node,"seed":7})
	await frames()
	var screen: Control = Router.current
	var deadline := Time.get_ticks_msec()+5000
	while screen._busy and Time.get_ticks_msec()<deadline: await frames(1)
	var b: BattleState = screen.battle
	check(b.achievement != null, "正式战斗创建成就观察器")
	b.add_ability("heat_pollution_damage",2)
	GameState.gild_character(GameState.deck[0])
	var observer_serial: int = b.achievement.serial
	var observer_key: String = b.achievement.key
	check(SaveManager.checkpoint(), "带成就观察器的战斗可以序列化存档")
	SaveManager.flush()
	check(SaveManager.has_save(), "成就战斗存档写入成功")
	Achievements.suspend_run(); GameState.last_run_result = {"victory":false}; GameState._run_end_emitted = true
	check(SaveManager.resume_run(), "可恢复含成就进度的战斗")
	await frames()
	screen = Router.current; b = screen.battle
	check(Achievements.run_id == id and b.achievement != null, "读档恢复同一局成就与观察器")
	check(b.achievement.key == observer_key and b.achievement.serial >= observer_serial and b.ability_value("heat_pollution_damage") == 2, "读档保留去重游标和两层火热")
	check(GameState.last_run_result.is_empty() and not GameState._run_end_emitted, "读档清除旧结算快照与结束标记")
	b.player.heat = b.player.heat_capacity
	var hp: int = b.enemies[0].hp
	b.add_heat(1)
	check(hp - b.enemies[0].hp == 2 * BattleBalance.i("overheat_damage",5) and b.achievement.serial > observer_serial, "恢复后叠层伤害与成就记录继续生效")
	Router.goto("res://src/screens/run_result_screen.gd", {"victory":true})
	await frames()
	check(not SaveManager.has_save(), "统一结算清除自动存档")
	SaveManager.clear_run(); SaveManager.enabled = false
	Router.current.queue_free(); Router.current=null; Router.host=null
	await frames()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path+suffix))
	print("[achievement_checkpoint_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-failures,failures,checks])
	get_tree().quit(1 if failures else 0)
