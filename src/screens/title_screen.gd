extends ScreenBase
## 标题界面。

func build(root: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var col := Ink.vbox(18)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	# —— 标题：四枚木活字 ——
	var title_row := Ink.hbox(14)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(title_row)
	var chars := ["活", "字", "战", "斗"]
	var rots := [-0.06, 0.03, -0.04, 0.07]
	var offsets := [6.0, -4.0, 8.0, -2.0]
	for i in chars.size():
		var t := _title_tile(chars[i], rots[i], offsets[i])
		title_row.add_child(t)

	col.add_child(Ink.spacer(6))
	var sub := Ink.label("以字为剑 · 铸词为阵", "Subheading", Palette.INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	var tip := Ink.label("4×4 字盘 · 相邻成词 · 字袋构筑", "Muted")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tip)

	col.add_child(Ink.spacer(24))

	var btns := Ink.vbox(10)
	btns.custom_minimum_size.x = 300
	col.add_child(btns)
	var start := Ink.button("开始新冒险", true)
	start.pressed.connect(_on_start)
	btns.add_child(start)

	var library := Ink.button("字库图鉴")
	library.pressed.connect(_on_library)
	btns.add_child(library)

	var graph := Ink.button("字网图谱")
	graph.pressed.connect(func(): goto("res://src/screens/glyph_graph_screen.gd"))
	btns.add_child(graph)

	var settings_btn := Ink.button("设置")
	settings_btn.pressed.connect(_open_settings)
	btns.add_child(settings_btn)

	var quit := Ink.button("离开")
	quit.theme_type_variation = "GhostButton"
	quit.pressed.connect(func(): get_tree().quit())
	btns.add_child(quit)

	var footer := Ink.label("GDD V0.3 脚手架 · Godot 4.7", "Muted")
	footer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.position = Vector2(-220, -34)
	root.add_child(footer)


func _title_tile(ch: String, rot: float, y_off: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(112, 112)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := Ink.make_wood_material()
	mat.set_shader_parameter("tile_size", Vector2(112, 112))
	mat.set_shader_parameter("corner_radius", 14.0)
	rect.material = mat
	holder.add_child(rect)
	var lab := Ink.label(ch, "", Palette.INK)
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 62)
	lab.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.2))
	holder.add_child(lab)
	holder.rotation = rot
	holder.position.y = y_off
	holder.pivot_offset = Vector2(56, 56 + y_off)
	return holder


func _on_start() -> void:
	GameState.start_new_run("v03")
	goto("res://src/screens/map_screen.gd")


func _open_settings() -> void:
	var ov := SettingsOverlay.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)


func _on_library() -> void:
	var viewer: CollectionOverlay = load("res://src/ui/collection_overlay.gd").new()
	viewer.setup({
		"title": "字库图鉴",
		"subtitle": "%d 种实体字 · %d 个词" % [Database.characters.size() - 1, Database.words.size()],
		"words": Database.words.values(),
	})
	viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(viewer)
