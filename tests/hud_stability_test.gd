extends Control

var checks: Array = []
var screen: Control
var capture := false
var phase := "after"
const QA := "res://docs/qa/hud-stability-2026-10-19/"


func _ok(ok: bool, text: String) -> void:
	checks.append(ok)
	print("%s %s" % ["PASS" if ok else "FAIL", text])


func _frames(n := 5) -> void:
	for i in n: await get_tree().process_frame


func _shot(label: String) -> void:
	if not capture: return
	await _frames()
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(QA + phase + "-" + label + ".png")


func _ready() -> void:
	Settings.storage_path = "user://hud_stability_test-settings.cfg"
	capture = OS.get_cmdline_user_args().has("--capture")
	phase = "before" if OS.get_cmdline_user_args().has("--before") else "after"
	SaveManager.enabled = false
	Settings.reduced_motion = true
	Router.host = self
	GameState.start_new_run("v03")
	Router.goto("res://src/screens/battle_screen.gd", {"seed": 7})
	screen = Router.current
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(844, 390), Vector2i(1280, 540)]:
		get_window().size = resolution
		await _frames(12)
		var b: BattleState = screen.battle
		b.player.block = 0
		b.player.persistent_block = 0
		b.player.heat = 0
		b.player.energy = 0
		b.player.statuses.clear()
		b.abilities.clear()
		b.enemies[0].block = 0
		b.enemies[0].persistent_block = 0
		screen._refresh_all()
		await _frames()
		var enemy: EnemyView = screen._enemy_widgets[0]
		var player_hp: Rect2 = screen._player_hp.get_global_rect()
		var player_number: Rect2 = screen._player_hp_value.get_global_rect()
		var enemy_hp: Rect2 = enemy._hp.get_global_rect()
		var enemy_number: Rect2 = enemy._hp_number.get_global_rect()
		await _shot("%dx%d-empty" % [resolution.x, resolution.y])
		for shields in [Vector2i(10, 0), Vector2i(0, 4), Vector2i(128, 256), Vector2i.ZERO]:
			b.player.block = shields.x
			b.player.persistent_block = shields.y
			b.enemies[0].block = shields.x
			b.enemies[0].persistent_block = shields.y
			screen._refresh_all()
			await _frames()
			_ok(screen._player_hp.get_global_rect().is_equal_approx(player_hp) and screen._player_hp_value.get_global_rect().is_equal_approx(player_number), "%s 玩家盾%s：血条与生命数字位置、宽度固定" % [resolution, shields])
			_ok(enemy._hp.get_global_rect().is_equal_approx(enemy_hp) and enemy._hp_number.get_global_rect().is_equal_approx(enemy_number), "%s 敌方盾%s：血条与生命数字位置、宽度固定" % [resolution, shields])
			_ok(not screen._player_defense.get_global_rect().intersects(screen._player_hp_value.get_global_rect()) and screen._player_hp.size.x > 0 and enemy._hp.size.x > 0, "%s 盾%s：盾不遮生命数字，血条宽度为正" % [resolution, shields])
			if shields == Vector2i(128, 256):
				await _shot("%dx%d-shields" % [resolution.x, resolution.y])
		var strip: StatusStrip = screen._player_status
		var height := strip.size.y
		b.player.heat = 3
		b.player.energy = 4
		for id in StatusDisplay.ABILITY_NAMES:
			if id not in StatusDisplay.ABILITY_PARAMETERS:
				b.enable_ability(id, 1)
		screen._refresh_all()
		await _frames()
		_ok(strip.entries.size() >= 10 and strip.item_for("more") != strip and absf(height - strip.size.y) <= 1.0, "%s 状态过多：单行高度固定，显示更多入口（高度%.2f→%.2f，容许像素取整）" % [resolution, height, strip.size.y])
		var all_inside := true
		for button in strip._buttons:
			all_inside = all_inside and strip.get_global_rect().encloses(button.get_global_rect())
		_ok(all_inside, "%s 状态图标全部留在预留区域，不越界或换行" % resolution)
		var more := strip.item_for("more")
		if more is Button: more.pressed.emit()
		await _frames()
		_ok(screen._modal_count == 1, "%s 更多状态可点击打开完整详情" % resolution)
		for child in screen.get_children():
			if child is ChoiceOverlay: child._on_choose(0)
		await _frames()
		await _shot("%dx%d-overflow" % [resolution.x, resolution.y])
	Router.current = null
	var failures := checks.count(false)
	if checks.size() != 60:
		failures += 1
		push_error("检查未完整执行：%d/60" % checks.size())
	print("[hud_stability_test] PASS=%d FAIL=%d TOTAL=%d" % [checks.count(true), failures, checks.size()])
	get_tree().quit(1 if failures else 0)
