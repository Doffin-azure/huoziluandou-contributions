extends Control
## Native contact sheet of the actual idle actors. Does not edit source artwork.
var _saved_motion := false
var _saved_style: GameStyle
var _portraits: Array[InkSpirit] = []


func _ready() -> void:
	_saved_motion = Settings.reduced_motion
	_saved_style = Ink.style
	Settings.reduced_motion = true
	Ink.apply_style(GameStyle.taopunk())
	get_window().size = Vector2i(1980, 1200)
	_run.call_deferred()


func _run() -> void:
	for i in 6: await get_tree().process_frame
	var backdrop := ColorRect.new()
	backdrop.color = Color("0c2026")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var pitch := Vector2(size.x / 3, size.y / 3)
	for i in TaopunkArt.ENEMIES.size():
		var id: String = TaopunkArt.ENEMIES[i]
		var cell := Control.new()
		cell.position = Vector2(i % 3, i / 3) * pitch + Vector2(7, 7)
		cell.size = pitch - Vector2(14, 14)
		cell.clip_contents = true
		add_child(cell)
		var paper := ColorRect.new()
		paper.color = Color("183238")
		paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cell.add_child(paper)
		var art := InkSpirit.new()
		art.enemy_id = id
		art.position = Vector2(8, 35)
		art.size = cell.size - Vector2(16, 35)
		art.clip_contents = true
		cell.add_child(art)
		_portraits.append(art)
		var heading := Ink.label(Database.get_enemy(id).name, "", Color("e9debd"))
		heading.position = Vector2(12, 4)
		heading.add_theme_font_size_override("font_size", 21)
		cell.add_child(heading)
	for i in 12: await get_tree().process_frame
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png("res://shots/enemy-visual-audit.png")
	var records: Array = []
	for art in _portraits:
		var record := {"id": art.enemy_id, "canvas": [art.size.x, art.size.y]}
		if art._attack_actor != null:
			var actor: EnemyAttackActor = art._attack_actor
			var extent := actor._neutral_rect.size * actor.scale
			record["fitting"] = "contain_all_attack_poses"
			record["idle_extent"] = [extent.x, extent.y]
			record["idle_width_fraction"] = extent.x / art.size.x
			record["idle_height_fraction"] = extent.y / art.size.y
		else:
			record["fitting"] = "cover_cropped_portrait"
			var rect := InkSpirit.portrait_rect(TaopunkArt.portrait(art.enemy_id), art.size, art.enemy_id)
			record["idle_extent"] = [rect.size.x, rect.size.y]
		records.append(record)
	var file := FileAccess.open("res://shots/enemy-visual-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	Settings.reduced_motion = _saved_motion
	Ink.apply_style(_saved_style)
	print("[enemy_visual_audit] captured 9 actual actors; no artwork or gameplay state modified")
	get_tree().quit()
