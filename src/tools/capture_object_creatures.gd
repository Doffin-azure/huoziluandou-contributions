extends "res://src/tools/capture_enemy_completion.gd"
## Render the current nonhuman cast through the game's actual actor and layout.
const OUTPUT := "res://docs/qa/object-creatures-2026-10-20/"
const CREATURES := ["ink_creditor","copy_master","seal_officer","wheel_master","proof_boss","compiler_boss"]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT+"frames/")
	var canvas := _canvas(Vector2i(1800,1340),"炼字狱 · 器物成精")
	_grid(canvas,CREATURES,3,Vector2(590,620))
	await _capture(canvas,OUTPUT+"six-object-creatures.png")
	canvas.queue_free()
	_actors.clear(); _captions.clear()
	await get_tree().process_frame
	canvas = _canvas(Vector2i(1800,1460),"器物成精 · 留白童保留原样")
	var with_child: Array = CREATURES.duplicate()
	with_child.append("blank_child")
	_grid(canvas,with_child,4,Vector2(446,680))
	await _capture(canvas,OUTPUT+"all-seven.png")
	canvas.queue_free()
	_actors.clear(); _captions.clear()
	await get_tree().process_frame
	await _comparison()
	canvas = _canvas(Vector2i(1280,900),"器物形体 · 接入动作")
	_grid(canvas,CREATURES,3,Vector2(420,400))
	var labels := {"idle":"待机","attack":"攻击","special":"施术","hit":"受击","death":"死亡"}
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
			_captions[i].text = Database.get_enemy(CREATURES[i]).name+" · "+labels[clip]
		await _capture(canvas,OUTPUT+"frames/%03d.png"%frame)
		if frame in [4,13,28,38,52]: await _capture(canvas,OUTPUT+"motion-"+clip+".png")
	canvas.queue_free()
	await get_tree().process_frame
	var host := Control.new()
	add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Router.host = host
	for id in CREATURES:
		GameState.start_new_run()
		var fixture := MapNodeData.new()
		fixture.enemies = [Database.get_enemy(id)]
		get_window().size = Vector2i(1280,720)
		Router.goto("res://src/screens/battle_screen.gd",{"node":fixture,"seed":29})
		for i in 24: await get_tree().process_frame
		var deadline := Time.get_ticks_msec()+8000
		while Router.current._busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
		assert(not Router.current._busy,"Battle entrance did not finish")
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(OUTPUT+"battle-"+id+".png")
		get_window().size = Vector2i(640,360)
		for i in 18: await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(OUTPUT+"phone-"+id+".png")
	Router.release_host(host)
	print("[capture_object_creatures] exported six creatures, preserved child, comparison, motion and six live encounters")
	get_tree().quit()


func _comparison() -> void:
	var canvas := _canvas(Vector2i(1800,1400),"形体对照 · 上一版 / 器物成精")
	for i in CREATURES.size():
		var id: String = CREATURES[i]
		for variant in 2:
			var origin := Vector2((i%2)*890+variant*440,(i/2)*430+80)
			var label := Ink.label(Database.get_enemy(id).name+(" · 上一版" if variant == 0 else " · 新形体"),"",Color("ecdcbb"))
			label.position = origin+Vector2(20,0)
			label.add_theme_font_size_override("font_size",25)
			canvas.add_child(label)
			var picture := TextureRect.new()
			picture.texture = load("res://assets/taopunk/enemies/zodiac_masks/%s.png"%id) if variant == 0 else TaopunkArt.portrait(id)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.position = origin+Vector2(20,38)
			picture.size = Vector2(410,375)
			canvas.add_child(picture)
	await _capture(canvas,OUTPUT+"before-after.png")
	canvas.queue_free()
	await get_tree().process_frame
