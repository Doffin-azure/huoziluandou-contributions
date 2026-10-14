extends Control
class_name EnemyView
## 敌人视图长期复用；受击只动墨团，战况文字保持稳定。
signal clicked(index)
var index := 0
var combatant: Combatant
var compact := false
var ui_scale := 1.0
var _heading: Label
var _name: Label
var _hp: StatBar
var _hp_number: Label
var _intent: Label
var _block: Label
var _status: StatusStrip
var _portrait: Control
var _visual: InkSpirit
var _motion: Tween


func setup(p_index: int, p_combatant: Combatant) -> void:
	index = p_index
	combatant = p_combatant


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_heading = Ink.label("敌人", "Muted")
	_name = Ink.label("", "Heading")
	_hp = StatBar.new()
	_hp.show_text = false
	_hp_number = Ink.label("", "", Palette.VERMILION_DK)
	_hp_number.add_theme_font_override("font", Ink.serif)
	_block = Ink.label("", "Muted")
	_intent = Ink.label("", "", Palette.INK)
	_intent.add_theme_font_override("font", Ink.serif)
	_intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status = StatusStrip.new()
	_portrait = Control.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual = InkSpirit.new()
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.add_child(_visual)
	for item in [_heading, _name, _hp, _hp_number, _block, _portrait, _intent, _status]:
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(item)
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout)
	gui_input.connect(_on_gui_input)
	refresh(false)
	_layout()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and combatant.is_alive():
		clicked.emit(index)
		accept_event()


func set_compact(value: bool) -> void:
	compact = value
	custom_minimum_size.y = 132 if value else 270
	if is_node_ready():
		_layout()


func _layout() -> void:
	if _visual == null:
		return
	var w := size.x
	_heading.position = Vector2.ZERO
	var factor := ui_scale if compact else 1.0
	_heading.size = Vector2(w, 20 * factor)
	_heading.add_theme_font_size_override("font_size", int(14 * factor))
	_name.position = Vector2(0, 20 * factor)
	_name.size = Vector2(w, 34 * factor if compact else 54)
	_name.add_theme_font_size_override("font_size", int(24 * factor) if compact else 42)
	_hp.position = Vector2(0, 52 * factor if compact else 82)
	var number_width := minf(w * 0.38, 94 * factor)
	_hp.custom_minimum_size.y = 12
	_hp.size = Vector2(w - number_width - 10, 14 * factor)
	_hp_number.position = Vector2(w - number_width, _hp.position.y - 8 * factor)
	_hp_number.size = Vector2(number_width, 32 * factor)
	_hp_number.add_theme_font_size_override("font_size", int(18 * factor) if compact else 22)
	_block.position = Vector2(0, 72 * factor if compact else 108)
	_block.size = Vector2(w, 28 * factor)
	_block.add_theme_font_override("font", Ink.serif)
	_block.add_theme_font_size_override("font_size", int(16 * factor) if compact else 19)
	_block.add_theme_color_override("font_color", Palette.INK)
	var art_side := minf(w + 18, maxf(64, size.y - 186))
	_portrait.visible = not compact
	_portrait.position = Vector2((w - art_side) * 0.5, 132)
	_portrait.size = Vector2(art_side, art_side)
	_intent.position = Vector2(0, 94 * factor if compact else size.y - 48)
	_intent.size = Vector2(w, 30 * factor)
	_intent.add_theme_font_size_override("font_size", int(16 * factor) if compact else 21)
	_status.position = Vector2(0, 124 * factor if compact else size.y - 36)
	_status.size = Vector2(w, 36 * factor)
	_status.set_ui_scale(factor)
	_status.visible = not _status.entries.is_empty()
	if compact:
		_heading.size.y = 16 * factor
		_name.position.y = 18 * factor
		_name.size.y = 28 * factor
		_name.add_theme_font_size_override("font_size", int(22 * factor))
		_hp.position.y = 48 * factor
		_hp.size.y = 10 * factor
		_hp_number.position.y = 42 * factor
		_hp_number.size.y = 24 * factor
		_block.position.y = 62 * factor
		_block.size.y = 18 * factor
		_block.add_theme_font_size_override("font_size", int(14 * factor))
		_intent.position.y = 84 * factor
		_intent.size.y = 24 * factor
		_intent.add_theme_font_size_override("font_size", int(14 * factor))
		_status.position.y = 112 * factor


func refresh(animate := true) -> void:
	if combatant == null or _hp == null:
		return
	var ed: EnemyData = combatant.enemy_data
	_visual.glyph = ed.glyph if ed != null else "敌"
	_visual.queue_redraw()
	_name.text = combatant.display_name
	_hp.setup_bar(combatant.hp, combatant.max_hp, Palette.HP, "", animate)
	_hp_number.text = "%d / %d" % [combatant.hp, combatant.max_hp]
	_block.text = "护盾 %d" % (combatant.block + combatant.persistent_block)
	_status.set_entries(StatusDisplay.collect(combatant))
	_layout()
	if not combatant.is_alive():
		_heading.text = "已击败"
		_intent.text = ""
		_visual.modulate.a = 0.18


func set_intent(move: EnemyMoveData) -> void:
	_intent.text = move.title + " · " + move.intent_text() if move != null and combatant.is_alive() else ""


func set_targeted(value: bool) -> void:
	_heading.text = ("当前目标" if value else "点击选择目标") if combatant.is_alive() else "已击败"
	_heading.add_theme_color_override("font_color", Palette.VERMILION_DK if value else Palette.INK_FAINT)


func impact_point() -> Vector2:
	return _hp.get_global_rect().get_center() if compact else _portrait.get_global_rect().get_center()


func apply_feedback(event: Dictionary) -> void:
	if event.has("hp"):
		_hp.setup_bar(int(event.hp), int(event.max_hp), Palette.HP)
		_hp_number.text = "%d / %d" % [int(event.hp), int(event.max_hp)]
	if event.has("block"):
		_block.text = "护盾 %d" % (int(event.block) + int(event.persistent_block))
	if Settings.reduced_motion:
		return
	if _motion != null:
		_motion.kill()
	_visual.position = Vector2.ZERO
	_visual.scale = Vector2.ONE
	_visual.pivot_offset = _portrait.size * 0.5
	var loss := int(event.get("hp_loss", 0))
	var dead := event.has("hp") and int(event.hp) <= 0
	_motion = create_tween()
	if dead:
		_motion.set_parallel(true)
		_motion.tween_property(_visual, "scale", Vector2(0.88, 0.88), 0.24)
		_motion.tween_property(_visual, "modulate:a", 0.18, 0.24)
	else:
		var kick := 6.0 if loss > 0 else 2.0
		_motion.tween_property(_visual, "position:x", kick, 0.035)
		_motion.parallel().tween_property(_visual, "scale", Vector2(0.96, 1.03), 0.035)
		_motion.tween_property(_visual, "position:x", -kick * 0.3, 0.06)
		_motion.tween_property(_visual, "position", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_motion.parallel().tween_property(_visual, "scale", Vector2.ONE, 0.12)


func anticipate() -> void:
	if Settings.reduced_motion or compact:
		return
	if _motion != null:
		_motion.kill()
	_visual.pivot_offset = _portrait.size * 0.5
	_motion = create_tween()
	_motion.tween_property(_visual, "scale", Vector2(1.035, 1.035), 0.10)
	_motion.tween_property(_visual, "scale", Vector2.ONE, 0.12)
