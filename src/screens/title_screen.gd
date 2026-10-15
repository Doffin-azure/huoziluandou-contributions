extends ScreenBase
## 书房标题菜单；开始后淡出菜单，镜头推进桌面，再开启地图。
var _menu: VBoxContainer
var _buttons: Array[Button] = []
var _entry_timer: Timer
var _menu_tween: Tween
var _starting := false
var _modal_count := 0


func build(root: Control) -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://src/shaders/study_scrim.gdshader")
	scrim.material = material
	root.add_child(scrim)
	_menu = Ink.vbox(18)
	root.add_child(_menu)
	var title := Ink.label("活字战斗", "Title", Color("f0e4c7"))
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_font_override("font", Ink.serif)
	_menu.add_child(title)
	var subtitle := Ink.label("以字为剑 · 铸词为阵", "", Color("dbccb0"))
	subtitle.add_theme_font_size_override("font_size", 20)
	_menu.add_child(subtitle)
	var tip := Ink.caption("相邻成词，在字袋中构筑你的冒险。")
	tip.add_theme_color_override("font_color", Color("b8aa91"))
	_menu.add_child(tip)
	_menu.add_child(Ink.spacer(12))
	var start := _button("开始新冒险", _on_start, true)
	start.custom_minimum_size.y = 64
	start.add_theme_font_size_override("font_size", 24)
	_menu.add_child(start)
	for entries in [[["自定义构筑", _on_custom], ["字库图鉴", _on_library]], [["字网图谱", _on_graph], ["设置", _open_settings]], [["离开", _quit]]]:
		var row := Ink.hbox(12)
		for entry in entries:
			row.add_child(_button(entry[0], entry[1]))
		_menu.add_child(row)
	_entry_timer = Timer.new()
	_entry_timer.one_shot = true
	_entry_timer.timeout.connect(_finish_start)
	add_child(_entry_timer)
	resized.connect(_layout)
	_layout.call_deferred()


func _button(text: String, callback: Callable, primary := false) -> Button:
	var button := Ink.button(text, primary)
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	if not primary:
		button.theme_type_variation = "GhostButton"
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", Color("e1d1b2"))
		button.add_theme_color_override("font_hover_color", Palette.PAPER)
	button.pressed.connect(callback)
	_buttons.append(button)
	return button


func _layout() -> void:
	if _menu == null:
		return
	var width := clampf(size.x * 0.28, 300, 400)
	_menu.size.x = width
	var height := _menu.get_combined_minimum_size().y
	_menu.position = Vector2(size.x - width - maxf(38, size.x * 0.065), maxf(32, (size.y - height) * 0.50))


func _lock_buttons() -> void:
	for button in _buttons:
		button.disabled = _starting or _modal_count > 0


func _on_start() -> void:
	if _starting or _modal_count > 0:
		return
	_starting = true
	_lock_buttons()
	var duration := 0.05
	if is_instance_valid(Router.study_stage) and Router.study_stage.visible:
		duration = Router.study_stage.enter_desk()
	if _menu_tween != null:
		_menu_tween.kill()
	_menu_tween = create_tween()
	_menu_tween.tween_property(_menu, "modulate:a", 0.0, minf(0.22, duration))
	_entry_timer.start(duration)


func _finish_start() -> void:
	if not _starting:
		return
	GameState.start_new_run("v03")
	goto("res://src/screens/map_screen.gd")


func _cancel_entry() -> void:
	_entry_timer.stop()
	_starting = false
	if _menu_tween != null:
		_menu_tween.kill()
	_menu.modulate.a = 1.0
	if is_instance_valid(Router.study_stage):
		Router.study_stage.show_room()
	_lock_buttons()


func _mount_overlay(overlay: Control) -> void:
	_modal_count += 1
	_lock_buttons()
	overlay.tree_exited.connect(func():
		_modal_count = maxi(0, _modal_count - 1)
		if is_inside_tree():
			_lock_buttons())
	add_child(overlay)


func _open_settings() -> void:
	if _starting or _modal_count > 0:
		return
	_mount_overlay(SettingsOverlay.new())


func _on_custom() -> void:
	goto("res://src/screens/custom_deck_screen.gd")


func _on_library() -> void:
	if _starting or _modal_count > 0:
		return
	var viewer := CollectionOverlay.new()
	viewer.setup({
		"title": "字库图鉴",
		"subtitle": "%d 种实体字 · %d 个词" % [Database.characters.size() - 1, Database.words.size()],
		"words": Database.words.values(),
	})
	_mount_overlay(viewer)


func _on_graph() -> void:
	if not _starting and _modal_count == 0:
		goto("res://src/screens/glyph_graph_screen.gd")


func _quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _starting and event.is_action_pressed("cancel_selection"):
		_cancel_entry()
		get_viewport().set_input_as_handled()
