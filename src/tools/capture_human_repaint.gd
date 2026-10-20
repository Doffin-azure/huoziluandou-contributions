extends "res://src/tools/capture_enemy_completion.gd"
## Render the user's requested repaint through the real animated actor.
var OUTPUT := "res://docs/qa/human-repaint-2026-10-20/"
const HUMANS := ["ink_creditor","copy_master","seal_officer","wheel_master","proof_boss","compiler_boss","blank_child"]
const ZODIAC_NAMES := {"ink_creditor":"鼠", "copy_master":"牛", "seal_officer":"虎", "wheel_master":"马", "proof_boss":"蛇", "compiler_boss":"龙"}
const FACE_CROPS := {
	"ink_creditor":Rect2(0.22,0.06,0.23,0.18), "copy_master":Rect2(0.40,0.10,0.24,0.25),
	"seal_officer":Rect2(0.37,0.015,0.32,0.29), "wheel_master":Rect2(0.25,0.12,0.25,0.21),
	"proof_boss":Rect2(0.44,0.08,0.20,0.22), "compiler_boss":Rect2(0.43,0.06,0.20,0.22),
	"blank_child":Rect2(0.32,0.06,0.28,0.22),
}


func _run() -> void:
	var zodiac := OS.get_cmdline_user_args().has("--zodiac-masks")
	var masked := zodiac or OS.get_cmdline_user_args().has("--bronze-masks")
	if zodiac: OUTPUT = "res://docs/qa/zodiac-masks-2026-10-20/"
	elif masked: OUTPUT = "res://docs/qa/bronze-masks-2026-10-20/"
	DirAccess.make_dir_recursive_absolute(OUTPUT+"frames/")
	var title := "人形敌人 · 青铜面具" if masked else "人形敌人 · 参考改绘"
	if zodiac: title = "生肖青铜面具 · 留白童保留原样"
	var canvas := _canvas(Vector2i(1800,1460),title)
	_grid(canvas,HUMANS,4,Vector2(446,680))
	await _capture(canvas,OUTPUT+"all-seven.png")
	canvas.queue_free()
	_actors.clear(); _captions.clear()
	await get_tree().process_frame
	if zodiac: await _zodiac_gallery()
	canvas = _canvas(Vector2i(1200,1640),"面具对照 · 上一版 / 青铜覆面" if masked else "脸部对照 · 原版 / 改绘")
	for row in HUMANS.size():
		var id: String = HUMANS[row]
		var label := Ink.label(Database.get_enemy(id).name,"",Color("ecdcbb"))
		label.position = Vector2(20,145+row*220)
		label.add_theme_font_size_override("font_size",26)
		canvas.add_child(label)
		for variant in 2:
			var previous := "res://assets/taopunk/enemies/human_repaint/%s.png"%id if masked else "res://assets/taopunk/enemies/%s.png"%id
			var texture: Texture2D = load(previous) if variant == 0 else TaopunkArt.portrait(id)
			var crop: Rect2 = _zodiac_crop(id) if zodiac else FACE_CROPS[id]
			var region := Rect2(crop.position*texture.get_size(),crop.size*texture.get_size())
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region.intersection(Rect2(Vector2.ZERO,texture.get_size()))
			var picture := TextureRect.new()
			picture.texture = atlas
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.position = Vector2(200+variant*475,80+row*220)
			picture.size = Vector2(440,210)
			canvas.add_child(picture)
	await _capture(canvas,OUTPUT+("mask-comparison.png" if masked else "face-comparison.png"))
	canvas.queue_free()
	await get_tree().process_frame
	canvas = _canvas(Vector2i(1280,900),"青铜面具动作 · 沿用独立骨骼" if masked else "改绘后的动作 · 沿用独立骨骼")
	var adults: Array = HUMANS.slice(0,6)
	_grid(canvas,adults,3,Vector2(420,400))
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
			_captions[i].text = Database.get_enemy(adults[i]).name+" · "+labels[clip]
		await _capture(canvas,OUTPUT+"frames/%03d.png"%frame)
		if frame in [4,13,28,38,52]: await _capture(canvas,OUTPUT+"motion-"+clip+".png")
	canvas.queue_free()
	await get_tree().process_frame
	var host := Control.new()
	add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Router.host = host
	for id in ["proof_boss","compiler_boss"]:
		GameState.start_new_run()
		var fixture := MapNodeData.new()
		fixture.enemies = [Database.get_enemy(id)]
		get_window().size = Vector2i(1280,720)
		Router.goto("res://src/screens/battle_screen.gd",{"node":fixture,"seed":29})
		for i in 24: await get_tree().process_frame
		var deadline := Time.get_ticks_msec()+8000
		while Router.current._busy and Time.get_ticks_msec() < deadline: await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(OUTPUT+"battle-"+id+".png")
		get_window().size = Vector2i(640,360)
		for i in 18: await get_tree().process_frame
		RenderingServer.force_draw(false)
		get_viewport().get_texture().get_image().save_png(OUTPUT+"phone-"+id+".png")
	Router.release_host(host)
	print("[capture_human_repaint] exported seven repaints, face comparison, motion frames and live battle views")
	get_tree().quit()


func _zodiac_crop(id: String) -> Rect2:
	return {
		"ink_creditor":Rect2(0.18,0.02,0.32,0.25), "copy_master":Rect2(0.31,0.02,0.41,0.34),
		"seal_officer":Rect2(0.38,0.03,0.28,0.24), "wheel_master":Rect2(0.22,0.02,0.35,0.30),
		"proof_boss":Rect2(0.44,0.08,0.20,0.22), "compiler_boss":Rect2(0.34,0.0,0.31,0.27),
	}.get(id,FACE_CROPS[id])


func _zodiac_gallery() -> void:
	var canvas := _canvas(Vector2i(1200,860),"生肖青铜面具 · 六种独立造型")
	for i in 6:
		var id: String = HUMANS[i]
		var origin := Vector2((i%3)*400,(i/3)*380)
		var label := Ink.label(Database.get_enemy(id).name+" · "+ZODIAC_NAMES[id],"",Color("ecdcbb"))
		label.position = origin+Vector2(25,85)
		label.add_theme_font_size_override("font_size",27)
		canvas.add_child(label)
		var texture := TaopunkArt.portrait(id)
		var crop := _zodiac_crop(id)
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(crop.position*texture.get_size(),crop.size*texture.get_size())
		var picture := TextureRect.new()
		picture.texture = atlas
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = origin+Vector2(25,125)
		picture.size = Vector2(350,300)
		canvas.add_child(picture)
	await _capture(canvas,OUTPUT+"six-zodiac-masks.png")
	canvas.queue_free()
	await get_tree().process_frame
