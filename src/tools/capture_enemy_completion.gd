extends Node
## Render the actual actors for the coverage gallery and a deterministic motion reel.
const QA := "res://docs/qa/enemy-completion-2026-10-20/"
var _actors: Array = []
var _captions: Array[Label] = []


func _ready() -> void:
	SaveManager.enabled = false
	Settings.reduced_motion = false
	Ink.apply_style(GameStyle.taopunk())
	DirAccess.make_dir_recursive_absolute(QA)
	_run.call_deferred()


func _canvas(extent: Vector2i, title: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = extent
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("10262f")
	background.size = Vector2(extent)
	viewport.add_child(background)
	var label := Ink.label(title,"",Color("ecdcbb"))
	label.add_theme_font_size_override("font_size",34)
	label.position = Vector2(30,16)
	viewport.add_child(label)
	return viewport


func _actor(art: InkSpirit) -> Node2D:
	if art.has_character_actor(): return art._character_actor
	if art._actor != null: return art._actor
	if art._attack_actor != null:
		art._attack_actor.set_process(false)
		art._attack_actor.player.stop()
		art._attack_actor.pose_index = -1
		return art._attack_actor._rest_actor
	return null


func _grid(viewport: SubViewport, ids: Array, columns: int, cell: Vector2) -> void:
	for i in ids.size():
		var host := Control.new()
		host.position = Vector2(i%columns,i/columns)*cell+Vector2(16,76)
		host.size = cell-Vector2(16,16)
		host.clip_contents = true
		viewport.add_child(host)
		var name_label := Ink.label(Database.get_enemy(ids[i]).name,"",Color("ecdcbb"))
		name_label.add_theme_font_size_override("font_size",24)
		name_label.position = Vector2(12,2)
		host.add_child(name_label)
		var art := InkSpirit.new()
		art.enemy_id = ids[i]
		art.position = Vector2(4,38)
		art.size = host.size-Vector2(8,54)
		host.add_child(art)
		var actor := _actor(art)
		actor.set_process(false)
		var player: AnimationPlayer = actor.get("player")
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play("idle")
		player.advance(0)
		_actors.append(actor)
		_captions.append(name_label)


func _capture(viewport: SubViewport, path: String) -> void:
	for i in 3: await get_tree().process_frame
	RenderingServer.force_draw(false)
	var error := viewport.get_texture().get_image().save_png(path)
	assert(error == OK,"Cannot capture " + path)


func _sample(actor: RosterEnemyActor, clip: String, at: float) -> void:
	actor._reset_pose()
	actor.player.play(clip)
	actor.player.advance(minf(at,actor.player.get_animation(clip).length-0.001))


func _run() -> void:
	var ids: Array = TaopunkArt.ENEMIES.duplicate()
	var canvas := _canvas(Vector2i(1800,2240),"敌人 · 全部二十九种")
	_grid(canvas,ids,5,Vector2(357,354))
	await _capture(canvas,QA+"all-29-enemies.png")
	canvas.queue_free()
	_actors.clear(); _captions.clear()
	await get_tree().process_frame
	canvas = _canvas(Vector2i(1600,1740),"敌人 · 新增十六张专属贴图")
	_grid(canvas,EnemyAnimationCatalog.DATA.keys(),4,Vector2(396,412))
	await _capture(canvas,QA+"new-16-enemies.png")
	canvas.queue_free()
	_actors.clear(); _captions.clear()
	await get_tree().process_frame
	canvas = _canvas(Vector2i(1280,900),"敌人 · 动作预览")
	ids = ["blank_child","glutton","bomb_press","leech","proof_boss","compiler_boss"]
	_grid(canvas,ids,3,Vector2(420,400))
	var labels := {"idle":"待机","attack":"攻击","special":"施术","hit":"受击","death":"死亡"}
	var folder := QA+"frames/"
	DirAccess.make_dir_recursive_absolute(folder)
	for frame in 60:
		var t := frame/12.0
		var clip := "idle"
		var at := t
		if t >= 3.5: clip = "death"; at = t-3.5
		elif t >= 3.0: clip = "hit"; at = t-3.0
		elif t >= 1.8: clip = "special"; at = t-1.8
		elif t >= 0.7: clip = "attack"; at = t-0.7
		for i in _actors.size():
			_sample(_actors[i],clip,at)
			_captions[i].text = Database.get_enemy(ids[i]).name+" · "+labels[clip]
		await _capture(canvas,folder+"%03d.png"%frame)
		if frame in [4,13,28,38,52]:
			await _capture(canvas,QA+"motion-"+clip+".png")
	print("[capture_enemy_completion] exported 29 portraits, 16 new portraits and 60 animation frames")
	get_tree().quit()
