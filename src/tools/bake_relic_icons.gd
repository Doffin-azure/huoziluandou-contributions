extends Node
## Bake the actual shop specimens into transparent UI textures. Requires a GPU renderer.
const Stage := preload("res://src/ui/object_stage/object_stage.gd")
const Specimen := preload("res://src/ui/object_stage/relic_specimen.gd")
const OUTPUT := "res://assets/relics/icons/"
const GALLERY := "res://docs/qa/relic-expansion-2026-10-19/all-relics.png"
var _pictures: Dictionary = {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DirAccess.make_dir_recursive_absolute(GALLERY.get_base_dir())
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1536, 1536)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("598579")
	environment.ambient_light_energy = 0.45
	var backdrop := WorldEnvironment.new()
	backdrop.environment = environment
	world.add_child(backdrop)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -34, -12)
	sun.light_color = Color("ffe1ad")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_bias = 0.015
	sun.shadow_normal_bias = 0.3
	world.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 4, 4)
	fill.light_color = Color("ffdcaa")
	fill.light_energy = 1.8
	fill.omni_range = 12
	world.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(2.8, 4.8, 6.8)
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.56, 0))
	camera.current = true
	var provider := Stage.new()
	provider.mode = "shop" # Reuse the exact pigments without building the room.
	var manifest: Array = []
	for id in Specimen.IDS:
		var path: String = OUTPUT + id + ".png"
		if FileAccess.file_exists(path) and OS.get_cmdline_user_args().has("--missing-only"):
			var preserved := Image.new()
			preserved.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
			_pictures[id] = preserved
			manifest.append({"id": id, "name": Relics.name_of(id), "path": path, "size": [1024, 1024], "sha256": FileAccess.get_sha256(path)})
			continue
		var item := Specimen.build(provider, id, Relics.price(id))
		if item == null or item.get_child_count() == 0:
			push_error("Cannot render missing specimen: " + id)
			get_tree().quit(1)
			return
		world.add_child(item)
		# Frame the actual object, including wide cloths and narrow tools, without
		# retaining the empty footprint formerly occupied by display bases.
		var bounds := Specimen.bounds_of(item)
		var center := bounds.get_center()
		camera.position = center + Vector3(2.8, 4.8, 6.8).normalized() * 8.0
		camera.look_at(center)
		var in_view: AABB = camera.global_transform.affine_inverse() * bounds
		camera.size = maxf(in_view.size.x, in_view.size.y) * 1.17
		for frame in 4: await get_tree().process_frame
		RenderingServer.force_draw(false)
		var picture := viewport.get_texture().get_image()
		picture.convert(Image.FORMAT_RGBA8)
		picture.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
		if picture.save_png(path) != OK:
			push_error("Cannot save relic icon: " + path)
			get_tree().quit(1)
			return
		_pictures[id] = picture
		manifest.append({"id": id, "name": Relics.name_of(id), "path": path, "size": [1024, 1024], "sha256": FileAccess.get_sha256(path)})
		print("BAKED ", id, " ", path)
		world.remove_child(item)
		item.free()
	provider.free()
	var sources := {}
	for source in ["relic_specimen.gd", "relic_expansion.gd", "relic_mesh.gd", "relic_pigment.gdshader"]:
		var source_path: String = "res://src/ui/object_stage/" + source
		sources[source_path] = FileAccess.get_sha256(source_path)
	var file := FileAccess.open(OUTPUT + "manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"source": "res://src/ui/object_stage/relic_specimen.gd", "source_sha256": FileAccess.get_sha256("res://src/ui/object_stage/relic_specimen.gd"), "sources": sources, "renderer": "Godot orthographic shop pigments", "icons": manifest}, "\t"))
	file.close()
	if not OS.get_cmdline_user_args().has("--skip-gallery"):
		await _gallery(Specimen.IDS, GALLERY, "遗物 · %d 件实体模型" % Specimen.IDS.size())
		await _gallery(Specimen.IDS.slice(15, 38), GALLERY.get_base_dir() + "/new-23-relics.png", "遗物 · 新增二十三件")
	print("[bake_relic_icons] exported %d transparent textures" % _pictures.size())
	get_tree().quit()


func _gallery(ids: Array = Specimen.IDS, path: String = GALLERY, heading := "遗物 · 三十八件实体模型") -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 100 + ceili(ids.size() / 5.0) * 290)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("10262f")
	background.size = Vector2(viewport.size)
	viewport.add_child(background)
	var title := Label.new()
	title.text = heading
	title.position = Vector2(36, 20)
	title.add_theme_font_override("font", Ink.serif)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ecdcbb"))
	viewport.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(36, 76)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	viewport.add_child(grid)
	for id in ids:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(224, 246)
		grid.add_child(cell)
		var icon := TextureRect.new()
		icon.texture = ImageTexture.create_from_image(_pictures[id])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(224, 196)
		cell.add_child(icon)
		var name_label := Label.new()
		name_label.text = Relics.name_of(id)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", Ink.serif)
		name_label.add_theme_font_size_override("font_size", 21)
		name_label.add_theme_color_override("font_color", Color("ecdcbb"))
		cell.add_child(name_label)
		var tier := Label.new()
		tier.text = {1: "常见", 2: "少见", 3: "稀有"}[Relics.TIER[id]]
		tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier.add_theme_font_override("font", Ink.sans)
		tier.add_theme_font_size_override("font_size", 14)
		tier.add_theme_color_override("font_color", Color("a6b5a5"))
		cell.add_child(tier)
	for frame in 4: await get_tree().process_frame
	RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(path)
	viewport.queue_free()
