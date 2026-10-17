extends "res://src/title/courtyard_view.gd"
## Standalone art review scene. Only previews the composition; never starts a run.

var _menu: VBoxContainer
var _settings: PanelContainer
var _return: Button
var _detail := false
var _key_slider: HSlider
var _accent_slider: HSlider
var _reflection_check: CheckButton
var _contour_check: CheckButton
var _fog_slider: HSlider
var _motion_check: CheckButton
var _library: CollectionOverlay


func _ready() -> void:
	follow_settings = false
	max_render_size = Vector2i.ZERO
	super._ready()
	_build_menu()
	_build_settings()
	_layout()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Ink.serif)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Ink.serif)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", Color("e6d8ad") if primary else Color("8fa9a2"))
	button.add_theme_color_override("font_hover_color", Color("f1e6c5"))
	button.add_theme_color_override("font_focus_color", Color("f1e6c5"))
	button.add_theme_color_override("font_pressed_color", Color("c35843"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.content_margin_left = 22
		style.border_width_left = 2 if state in ["hover", "focus"] or primary and state == "normal" else 0
		style.border_color = Color("b5503c")
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	return button


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 4)
	add_child(_menu)
	_menu.add_child(_label("活字战斗", 54, Color("e6d9b4")))
	_menu.add_child(_label("以字为剑 · 铸词为阵", 16, Color("97a79b")))
	var space := Control.new()
	space.custom_minimum_size.y = 45
	_menu.add_child(space)
	_menu.add_child(_button("开始新冒险", func(): set_detail(true), true))
	_menu.add_child(_button("字库图鉴", _open_library))
	_menu.add_child(_button("设置", func(): _settings.visible = not _settings.visible))
	_menu.add_child(_button("离开", func(): get_tree().quit()))
	_return = _button("返回", func(): set_detail(false), true)
	_return.hide()
	add_child(_return)
	var hint := _label("空格  进入庭院       F2  场景调节", 12, Color("c1c6b4"))
	hint.name = "Hint"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)


func _build_settings() -> void:
	_settings = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10252d")
	style.border_color = Color("47615c")
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	_settings.add_theme_stylebox_override("panel", style)
	add_child(_settings)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_settings.add_child(col)
	col.add_child(_label("样板 · 光照与氛围", 21, Color("e6d9b4")))
	_key_slider = _slider(col, "日光", stage.key.light_energy, 3.0, stage.set_key_strength)
	_accent_slider = _slider(col, "亭内补光", stage.accent.light_energy, 5.0, stage.set_accent_strength)
	_reflection_check = CheckButton.new()
	_reflection_check.text = "水面反射"
	_reflection_check.button_pressed = true
	_reflection_check.add_theme_color_override("font_color", Color("e6d9b4"))
	_reflection_check.toggled.connect(stage.set_reflections)
	col.add_child(_reflection_check)
	_contour_check = CheckButton.new()
	_contour_check.text = "建筑墨线"
	_contour_check.button_pressed = true
	_contour_check.add_theme_color_override("font_color", Color("e6d9b4"))
	_contour_check.toggled.connect(stage.set_contours)
	col.add_child(_contour_check)
	_fog_slider = _slider(col, "薄雾浓度", 1.0, 1.5, stage.atmosphere.set_fog_strength)
	_motion_check = CheckButton.new()
	_motion_check.text = "环境动态"
	_motion_check.button_pressed = true
	_motion_check.add_theme_color_override("font_color", Color("e6d9b4"))
	_motion_check.toggled.connect(stage.atmosphere.set_motion)
	col.add_child(_motion_check)
	col.add_child(_button("关闭", func(): _settings.hide()))
	_settings.hide()


func _slider(parent: VBoxContainer, caption: String, initial: float, maximum: float, callback: Callable) -> HSlider:
	parent.add_child(_label(caption, 16, Color("b9c9b6")))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(260, 32)
	slider.value_changed.connect(callback)
	parent.add_child(slider)
	return slider


func _layout() -> void:
	super._layout()
	if _menu == null: return
	var unit := minf(size.x / 1280.0, size.y / 720.0)
	_menu.scale = Vector2.ONE * unit
	_menu.position = Vector2(size.x * 0.075, size.y * 0.21)
	_menu.size.x = 350
	_return.scale = Vector2.ONE * unit
	_return.position = Vector2(size.x * 0.075, size.y * 0.82)
	_return.size = Vector2(180, 48)
	_settings.position = Vector2(size.x - 340, 40)
	_settings.size.x = 300
	get_node("Hint").position = Vector2(size.x * 0.075, size.y - 42)


func set_detail(enabled: bool) -> void:
	_detail = enabled
	_menu.visible = not enabled
	_scrim.visible = not enabled
	_return.visible = enabled
	_settings.hide()
	stage.show_detail(enabled)


func _open_library() -> void:
	if is_instance_valid(_library): return
	_library = CollectionOverlay.new()
	_library.setup({"title": "字库图鉴", "words": Database.words.values()})
	add_child(_library)


func _input(event: InputEvent) -> void:
	if is_instance_valid(_library): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			_settings.visible = not _settings.visible
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			set_detail(not _detail)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if _settings.visible: _settings.hide()
			elif _detail: set_detail(false)
			get_viewport().set_input_as_handled()
