extends Control
## Capture the existing copper-seal battle as the unedited art-study input.
const GLYPHS := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]
var _saved_motion := false
var _saved_style: GameStyle


func _ready() -> void:
	_saved_motion = Settings.reduced_motion
	_saved_style = Ink.style
	Settings.reduced_motion = true
	Ink.apply_style(GameStyle.taopunk())
	get_window().size = Vector2i(1980, 792)
	_run.call_deferred()


func _run() -> void:
	for i in 8: await get_tree().process_frame
	var stage := StudyStage.new()
	add_child(stage)
	Router.study_stage = stage
	Router.host = self
	GameState.start_new_run("v03", GLYPHS + GLYPHS)
	var node := MapNodeData.new()
	node.enemies = [Database.get_enemy("bronze_seal")]
	Router.goto("res://src/screens/battle_screen.gd", {"node": node, "seed": 17})
	var screen: Control = Router.current
	screen.battle.bag.clear()
	for i in 16: screen.battle.board.cells[i] = GameState.deck[i]
	for i in range(16, 32): screen.battle.bag.append(GameState.deck[i])
	screen.battle.enemies[0].move_index = 1
	screen._refresh_all()
	screen._board_view.path = [Vector2i(0, 0), Vector2i(1, 0)]
	screen._board_view._sync_selection()
	for i in 20: await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("res://shots/bronze-seal-before.png")
	if OS.get_cmdline_user_args().has("--blank-enemy"):
		screen._enemy_widgets[0]._portrait.hide()
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png("res://shots/bronze-seal-empty-stage.png")
	Router.study_stage = null
	Settings.reduced_motion = _saved_motion
	Ink.apply_style(_saved_style)
	print("[bronze_seal_sample] captured original runtime as art-study input")
	get_tree().quit()
