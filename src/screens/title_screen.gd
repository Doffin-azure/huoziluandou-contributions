extends ScreenBase
## Courtyard title menu. Scenery owns presentation; this screen retains existing run entry.
const CourtyardView := preload("res://src/title/courtyard_view.gd")
var _courtyard: Control
var _menu: VBoxContainer
var _buttons: Array[Button] = []
var _title: Label
var _subtitle: Label
var _space: Control
var _expedition := false
var _entry_timer: Timer
var _menu_tween: Tween
var _starting := false
var _modal_count := 0
var _veil: ColorRect


func has_scene_background() -> bool:
	return true


func build(root: Control) -> void:
	_courtyard = CourtyardView.new()
	root.add_child(_courtyard)
	_menu = VBoxContainer.new()
	root.add_child(_menu)
	_title = _label("活字战斗", 54, Color("e6d9b4"))
	_menu.add_child(_title)
	_subtitle = _label("以字为剑 · 铸词为阵", 16, Color("97a79b"))
	_menu.add_child(_subtitle)
	_space = Control.new()
	_menu.add_child(_space)
	_menu.add_child(_button("开始新冒险", _on_start, true))
	for entries in [[["墨途远征", _on_expedition], ["自定义构筑", _on_custom]], [["字库图鉴", _on_library], ["字网图谱", _on_graph]], [["设置", _open_settings], ["离开", _quit]]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		for entry in entries:
			row.add_child(_button(entry[0], entry[1]))
		_menu.add_child(row)
	_veil = ColorRect.new()
	_veil.color = Color(0.025, 0.06, 0.075, 0.0)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_veil)
	_entry_timer = Timer.new()
	_entry_timer.one_shot = true
	_entry_timer.timeout.connect(_finish_start)
	add_child(_entry_timer)
	resized.connect(_layout)
	_menu.minimum_size_changed.connect(_layout.call_deferred)
	_layout.call_deferred()
	_buttons[0].grab_focus.call_deferred()


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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Ink.serif)
	var color := Color("e6d8ad") if primary else Color("a1b5ab")
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_disabled_color", color)
	button.add_theme_color_override("font_hover_color", Color("f1e6c5"))
	button.add_theme_color_override("font_focus_color", Color("f1e6c5"))
	button.add_theme_color_override("font_pressed_color", Color("c35843"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.content_margin_left = 14
		style.content_margin_right = 6
		style.border_width_left = 2 if state in ["hover", "focus"] or primary and state == "normal" else 0
		style.border_color = Color("b5503c")
		button.add_theme_stylebox_override(state, style)
	button.set_meta("primary", primary)
	button.pressed.connect(callback)
	_buttons.append(button)
	return button


func _layout() -> void:
	if _menu == null or size.y < 1: return
	# Reserve physical touch targets instead of scaling the entire menu down on phones.
	var physical_height := maxf(1.0, get_window().size.y)
	var touch_scale := maxf(1.0, size.y / physical_height)
	var compact := physical_height < 600
	_title.add_theme_font_size_override("font_size", int((42 if compact else 54) * touch_scale))
	_subtitle.add_theme_font_size_override("font_size", int((14 if compact else 16) * touch_scale))
	_space.custom_minimum_size.y = (16 if compact else 28) * touch_scale
	_menu.add_theme_constant_override("separation", int(4 * touch_scale))
	for button in _buttons:
		button.custom_minimum_size.y = 48 * touch_scale
		button.add_theme_font_size_override("font_size", int((23 if button.get_meta("primary") else 20) * touch_scale))
	var width := minf(360 * touch_scale, size.x - 40 * touch_scale)
	_menu.custom_minimum_size.x = width
	_menu.size.x = width
	_menu.reset_size()
	var height := _menu.get_combined_minimum_size().y
	var top := minf(size.y * 0.21, maxf(12 * touch_scale, (size.y - height) * 0.5))
	_menu.position = Vector2(maxf(20 * touch_scale, size.x * 0.075), top)


func _can_interact() -> bool:
	return not _starting and _modal_count == 0 and not is_queued_for_deletion()


func _lock_buttons() -> void:
	for button in _buttons:
		button.disabled = _starting or _modal_count > 0


func _on_start() -> void:
	if not _can_interact(): return
	_starting = true
	_lock_buttons()
	var duration: float = _courtyard.enter()
	if _menu_tween != null: _menu_tween.kill()
	_menu_tween = create_tween()
	_menu_tween.tween_property(_menu, "modulate:a", 0.0, minf(0.22, duration))
	if not Settings.reduced_motion:
		_menu_tween.tween_interval(maxf(0.0, duration - 0.40))
		_menu_tween.tween_property(_veil, "color:a", 1.0, 0.18)
	_entry_timer.start(duration)


func _finish_start() -> void:
	if not _starting or is_queued_for_deletion(): return
	if _expedition:
		Expedition.start()
		goto("res://src/screens/expedition_map_screen.gd")
		return
	GameState.start_new_run("v03")
	goto("res://src/screens/map_screen.gd")


func _on_expedition() -> void:
	if not _can_interact(): return
	_expedition = true
	_on_start()


func _cancel_entry() -> void:
	if not _starting: return
	_expedition = false
	_entry_timer.stop()
	_starting = false
	if _menu_tween != null: _menu_tween.kill()
	_menu.modulate.a = 1.0
	_veil.color.a = 0.0
	_courtyard.reset_camera()
	_lock_buttons()
	_buttons[0].grab_focus.call_deferred()


func _mount_overlay(overlay: Control) -> void:
	var previous_focus := get_viewport().gui_get_focus_owner()
	_modal_count += 1
	_lock_buttons()
	overlay.tree_exited.connect(func():
		_modal_count = maxi(0, _modal_count - 1)
		if is_inside_tree() and not is_queued_for_deletion():
			_lock_buttons()
			if is_instance_valid(previous_focus): previous_focus.grab_focus.call_deferred())
	add_child(overlay)


func _open_settings() -> void:
	if _can_interact(): _mount_overlay(SettingsOverlay.new())


func _on_custom() -> void:
	if _can_interact(): goto("res://src/screens/custom_deck_screen.gd")


func _on_library() -> void:
	if not _can_interact(): return
	var viewer := CollectionOverlay.new()
	viewer.setup({"title": "字库图鉴", "subtitle": "%d 种实体字 · %d 个词" % [Database.characters.size() - 1, Database.words.size()], "words": Database.words.values()})
	_mount_overlay(viewer)


func _on_graph() -> void:
	if _can_interact(): goto("res://src/screens/glyph_graph_screen.gd")


func _quit() -> void:
	if _can_interact(): get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if _starting and event.is_action_pressed("cancel_selection"):
		_cancel_entry()
		get_viewport().set_input_as_handled()
