extends Control
## Configured concept preview and deterministic actor capture, outside official encounters.
const GLYPHS := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]
var _saved_motion := false
var _saved_style: GameStyle


func _ready() -> void:
	_saved_motion = Settings.reduced_motion
	_saved_style = Ink.style
	Settings.reduced_motion = not OS.get_cmdline_user_args().has("--animate")
	Ink.apply_style(GameStyle.taopunk())
	get_window().size = Vector2i(1980, 792)
	_run.call_deferred()


func _run() -> void:
	var config_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="): config_path = argument.trim_prefix("--study=")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	var image := Image.load_from_file(config.image)
	if image == null or image.is_empty() or not image.detect_alpha():
		push_error("Concept preview requires a transparent PNG")
		get_tree().quit(1)
		return
	for i in 8: await get_tree().process_frame
	var stage := StudyStage.new()
	add_child(stage)
	Router.study_stage = stage
	Router.host = self
	GameState.start_new_run("v03", GLYPHS + GLYPHS)
	var enemy := EnemyData.new()
	enemy.id = config.id
	if OS.get_cmdline_user_args().has("--animate"): enemy.id = config.animation_id
	enemy.name = config.name
	enemy.glyph = config.glyph
	enemy.max_hp = int(config.hp)
	var move := EnemyMoveData.new()
	move.kind = EnemyMoveData.Kind.MULTI if int(config.hits) > 1 else EnemyMoveData.Kind.ATTACK
	move.damage = int(config.attack)
	move.hits = int(config.hits)
	enemy.moves = [move]
	var node := MapNodeData.new()
	node.enemies = [enemy]
	Router.goto("res://src/screens/battle_screen.gd", {"node":node,"seed":17})
	var screen: Control = Router.current
	screen.battle.bag.clear()
	for i in 16: screen.battle.board.cells[i] = GameState.deck[i]
	for i in range(16,32): screen.battle.bag.append(GameState.deck[i])
	screen.battle.enemies[0].block = int(config.shield)
	screen._refresh_all()
	screen._board_view.path = [Vector2i(0,0),Vector2i(1,0)]
	screen._board_view._sync_selection()
	for i in 20: await get_tree().process_frame
	var treatment := ShaderMaterial.new()
	treatment.shader = load("res://src/art_samples/paper_shell_backdrop.gdshader")
	stage._illustrated_backdrop.material = treatment
	var view: EnemyView = screen._enemy_widgets[0]
	var paper: ArtPaper = screen._enemy_paper
	paper.open_scene = false
	paper.strip = true
	paper.material.set_shader_parameter("strip",true)
	paper.size = Vector2(view.size.x + 24.0,164.0)
	paper.global_position = view.global_position - Vector2(12.0,10.0)
	view._intent.position.y = 86.0
	view._intent.size.y = 58.0
	view._intent.set_ui_scale(1.2)
	if OS.get_cmdline_user_args().has("--animate"):
		await _capture_animation(view,config)
		return
	view._visual.hide()
	var texture := AtlasTexture.new()
	texture.atlas = ImageTexture.create_from_image(image)
	texture.region = image.get_used_rect()
	var portrait := TextureRect.new()
	portrait.texture = texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var factor := minf(view._portrait.size.x * 0.80 / texture.region.size.x,view._portrait.size.y * 0.80 / texture.region.size.y)
	portrait.size = texture.region.size * factor
	var bottom_pad := 24.0 if bool(config.get("hover",false)) else 0.0
	portrait.position = Vector2((view._portrait.size.x - portrait.size.x) * 0.5,view._portrait.size.y - portrait.size.y - bottom_pad)
	view._portrait.add_child(portrait)
	for i in 6: await get_tree().process_frame
	RenderingServer.force_draw(false)
	var result := get_viewport().get_texture().get_image().save_png(config.output)
	print("[enemy_concept_preview] id=",config.id," size=",portrait.size," result=",result)
	Router.study_stage = null
	Settings.reduced_motion = _saved_motion
	Ink.apply_style(_saved_style)
	get_tree().quit(0 if result == OK else 1)


func _capture_animation(view: EnemyView, config: Dictionary) -> void:
	var actor: Node2D = view._visual._character_actor
	var player: AnimationPlayer = actor.get("player")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.set_process(false)
	if OS.get_cmdline_user_args().has("--freeze-scene"):
		await _freeze_capture_scene(actor)
	var caption := Ink.label("", "", Palette.PAPER_WARM)
	caption.add_theme_font_size_override("font_size",22)
	caption.position = Vector2(1330,286)
	caption.size = Vector2(400,28)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	var directory: String = config.capture_directory
	DirAccess.make_dir_recursive_absolute(directory)
	var samples_only := OS.get_cmdline_user_args().has("--animation-samples")
	var fps := float(config.get("capture_fps",30.0))
	var frame_index := 0
	for clip in config.animation_clips:
		caption.text = clip.title
		var count := 1 if samples_only else ceili(float(clip.length) * fps)
		for i in count:
			var seconds: float = clip.key if samples_only else float(i) / fps
			var duration: float = actor.call("animation_length",clip.id)
			if seconds > duration and clip.id != "death":
				actor.call("capture_sample","idle",seconds - duration,1.0 / fps)
			else: actor.call("capture_sample",clip.id,seconds,1.0 / fps)
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			var image := get_viewport().get_texture().get_image()
			if samples_only:
				image.save_png(config.animation_output + "animation-%s.png" % clip.id)
			else:
				image.save_png(directory + "frame-%04d.png" % frame_index)
				frame_index += 1
		print("[enemy_animation_preview] captured ",clip.id)
	print("[enemy_animation_preview] frames=",frame_index)
	Router.study_stage = null
	Settings.reduced_motion = _saved_motion
	Ink.apply_style(_saved_style)
	get_tree().quit()


func _freeze_capture_scene(actor: Node2D) -> void:
	# Review movie: render the native UI once, then animate on that unchanged image.
	# The battle integration and actual damage are verified separately in real turns.
	actor.hide()
	await get_tree().process_frame
	RenderingServer.force_draw(false)
	var background := get_viewport().get_texture().get_image()
	var pose := actor.global_transform
	actor.reparent(self,false)
	actor.transform = pose
	Router.current.queue_free()
	Router.current = null
	Router.study_stage.queue_free()
	Router.study_stage = null
	var frozen := TextureRect.new()
	frozen.texture = ImageTexture.create_from_image(background)
	frozen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frozen.stretch_mode = TextureRect.STRETCH_SCALE
	frozen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frozen.z_index = -50
	add_child(frozen)
	actor.show()
	for i in 2: await get_tree().process_frame
