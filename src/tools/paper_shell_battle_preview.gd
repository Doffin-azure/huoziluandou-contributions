extends Control
## Art-only preview: real battle UI with a concept cutout; no database replacement.
const GLYPHS := ["击", "破", "回", "流", "防", "御", "加", "速", "充", "电", "火", "爆", "金", "币", "冷", "转"]
const ART := "res://docs/art-concepts/2026-10-17/paper-shell-soldier/"
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
	for i in 8: await get_tree().process_frame
	var stage := StudyStage.new()
	add_child(stage)
	Router.study_stage = stage
	Router.host = self
	GameState.start_new_run("v03", GLYPHS + GLYPHS)
	var enemy := EnemyData.new()
	enemy.id = "paper_shell_soldier" if OS.get_cmdline_user_args().has("--animate") else "paper_shell_concept"
	enemy.name = "纸壳兵"
	enemy.glyph = "纸"
	enemy.max_hp = 32
	var attack := EnemyMoveData.new()
	attack.kind = EnemyMoveData.Kind.ATTACK
	attack.damage = 6
	var guard := EnemyMoveData.new()
	guard.kind = EnemyMoveData.Kind.BLOCK
	guard.block = 8
	enemy.moves = [attack, guard]
	var node := MapNodeData.new()
	node.enemies = [enemy]
	Router.goto("res://src/screens/battle_screen.gd", {"node": node, "seed": 17})
	var screen: Control = Router.current
	screen.battle.bag.clear()
	for i in 16: screen.battle.board.cells[i] = GameState.deck[i]
	for i in range(16, 32): screen.battle.bag.append(GameState.deck[i])
	screen.battle.enemies[0].block = 8
	screen._refresh_all()
	screen._board_view.path = [Vector2i(0, 0), Vector2i(1, 0)]
	screen._board_view._sync_selection()
	for i in 20: await get_tree().process_frame
	var view: EnemyView = screen._enemy_widgets[0]
	if OS.get_cmdline_user_args().has("--animate"):
		await _capture_animation(screen, view, stage)
		return
	view._visual.hide()
	var image := Image.load_from_file(ART + "v05-cutout.png")
	if image == null or image.is_empty() or not image.detect_alpha():
		push_error("Paper soldier preview requires a transparent cutout")
		get_tree().quit(1)
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	# Crop transparent margins only in the native texture view; source PNG is untouched.
	atlas.region = Rect2(223, 61, 578, 1380)
	var portrait := TextureRect.new()
	portrait.texture = atlas
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var height := view._portrait.size.y * 0.94
	portrait.size = Vector2(height * atlas.region.size.x / atlas.region.size.y, height)
	portrait.position = Vector2((view._portrait.size.x - portrait.size.x) * 0.5, view._portrait.size.y - height)
	view._portrait.add_child(portrait)
	for i in 6: await get_tree().process_frame
	RenderingServer.force_draw(false)
	var frame := get_viewport().get_texture().get_image()
	var result: Error
	if OS.get_cmdline_user_args().has("--mute-background"):
		result = frame.save_png(ART + "v05-battle-background-before.png")
		if result != OK:
			get_tree().quit(1)
			return
		var treatment := ShaderMaterial.new()
		treatment.shader = load("res://src/art_samples/paper_shell_backdrop.gdshader")
		stage._illustrated_backdrop.material = treatment
		for i in 6: await get_tree().process_frame
		RenderingServer.force_draw(false)
		frame = get_viewport().get_texture().get_image()
		result = frame.save_png(ART + "v05-battle-background-muted.png")
	else:
		result = frame.save_png(ART + "v05-battle-preview.png")
	if result == OK and OS.get_cmdline_user_args().has("--compact-enemy-header"):
		result = frame.save_png(ART + "v05-battle-compact-header-before.png")
		if result != OK:
			get_tree().quit(1)
			return
		_compact_enemy_header(screen, view)
		for i in 6: await get_tree().process_frame
		RenderingServer.force_draw(false)
		frame = get_viewport().get_texture().get_image()
		result = frame.save_png(ART + "v05-battle-compact-header.png")
	print("[paper_shell_battle_preview] image=", frame.get_size(), " portrait=", portrait.size, " result=", result)
	Router.study_stage = null
	Settings.reduced_motion = _saved_motion
	Ink.apply_style(_saved_style)
	get_tree().quit(0 if result == OK else 1)


func _compact_enemy_header(screen: Control, view: EnemyView) -> void:
	# Preview-only layout: keep the character's framing and position identical.
	var paper: ArtPaper = screen._enemy_paper
	paper.open_scene = false
	paper.strip = true
	paper.material.set_shader_parameter("strip", true)
	paper.size = Vector2(view.size.x + 24.0, 164.0)
	paper.global_position = view.global_position - Vector2(12.0, 10.0)
	view._intent.position.y = 86.0
	view._intent.size.y = 58.0
	view._intent.set_ui_scale(1.2)


func _capture_animation(screen: Control, view: EnemyView, stage: StudyStage) -> void:
	var treatment := ShaderMaterial.new()
	treatment.shader = load("res://src/art_samples/paper_shell_backdrop.gdshader")
	stage._illustrated_backdrop.material = treatment
	_compact_enemy_header(screen, view)
	var actor: PaperShellActor = view._visual._paper_actor
	actor.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	actor.set_process(false)
	var caption := Ink.label("", "", Palette.PAPER_WARM)
	caption.add_theme_font_size_override("font_size", 22)
	caption.position = Vector2(1330, 302)
	caption.size = Vector2(400, 28)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	var directory := "res://shots/paper-shell-animation/"
	DirAccess.make_dir_recursive_absolute(directory)
	var samples_only := OS.get_cmdline_user_args().has("--animation-samples")
	var clips := [
		{"id":"idle", "title":"待机", "length":1.2, "key":0.0},
		{"id":"attack", "title":"攻击 · 收折后展开刺出", "length":1.3, "key":0.40},
		{"id":"guard", "title":"补盾 · 双臂合折", "length":1.3, "key":0.34},
		{"id":"hit", "title":"受击 · 纸片错动回弹", "length":0.85, "key":0.12},
		{"id":"death", "title":"退场 · 失去支撑后折落", "length":1.45, "key":0.65},
	]
	var frame_index := 0
	for clip in clips:
		caption.text = clip.title
		var count := 1 if samples_only else ceili(float(clip.length) * 30.0)
		for i in count:
			var seconds: float = clip.key if samples_only else float(i) / 30.0
			if seconds > float(PaperShellActor.LENGTH[clip.id]) and clip.id != "death":
				actor.sample("idle", seconds - float(PaperShellActor.LENGTH[clip.id]))
			else: actor.sample(clip.id, seconds)
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			var image := get_viewport().get_texture().get_image()
			if samples_only:
				image.save_png(ART + "animation-%s.png" % clip.id)
			else:
				image.save_png(directory + "frame-%04d.png" % frame_index)
				frame_index += 1
		print("[paper_shell_animation] captured ", clip.id)
	print("[paper_shell_animation] frames=", frame_index, " samples_only=", samples_only)
	Router.study_stage = null
	Settings.reduced_motion = _saved_motion
	Ink.apply_style(_saved_style)
	get_tree().quit()
