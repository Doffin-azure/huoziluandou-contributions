extends Control
## Real status container minima and help cards must respect the same screen space.
var checks := 0
var failures := 0


func _ready() -> void:
	Settings.reduced_motion = true
	Ink.apply_style(GameStyle.taopunk())
	GameState.start_new_run("v03")
	var screen: Control = load("res://src/screens/battle_screen.gd").new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	for id in ["strength","vulnerable","regen","heart","counter"]: screen.battle.player.add_status(id,3)
	screen.battle.player.energy = 12
	screen._refresh_player()
	for resolution: Vector2i in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(844,390)]:
		get_window().size = resolution
		screen.params["touch_layout"] = resolution.y<540
		await frames()
		screen._layout()
		await frames()
		check(not screen._player_status.get_global_rect().intersects(screen._preview_panel.get_global_rect()),"status and preview separated at "+str(resolution))
		check(screen._bubble.size.y>0,"preview retains positive reading height")
		screen._bubble.body.set_effect_text("力量与反击")
		screen._bubble.body.meta_clicked.emit("term:counter")
		await frames()
		var card: PanelContainer = screen._bubble.body._cards[0]
		check(get_viewport_rect().encloses(card.get_global_rect()),"help stays inside screen")
		check(not screen._player_status.get_global_rect().intersects(card.get_global_rect()),"help avoids player status")
		screen._bubble.body.close_help()
	# Anchor a card directly over a status row, rather than relying on cursor position.
	var source: EffectText = screen._bubble.body
	var occupied: Rect2 = screen._player_status.get_global_rect()
	var dimensions := Vector2(250,160)
	var target: Vector2 = source._avoid_status(occupied.position,dimensions,get_viewport_rect().size,6)
	check(not Rect2(target,dimensions).intersects(occupied),"overlapping anchor is moved away from status")
	check("每回合开始减少1层" in EffectGlossary.entry("term:vulnerable").text,"configured vulnerability retains decay rule")
	check("仅移动或进入新回合不刷新" in EffectGlossary.entry("term:refined").text,"configured refined text retains refresh boundary")
	check("临时复制不继承" in EffectGlossary.entry("term:gilded").text,"configured gilded text retains temporary-copy boundary")
	print("[battle_help_layout_test] PASS=%d FAIL=%d" % [checks-failures,failures])
	get_tree().quit(1 if failures else 0)


func frames() -> void:
	for i in 8: await get_tree().process_frame


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
