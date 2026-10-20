extends Control
class_name EnemyView
## 敌人视图长期复用；受击只动墨团，战况文字保持稳定。
signal clicked(index)
signal details_requested(title: String, body: String, scroll_body: bool)
var index := 0
var combatant: Combatant
var compact := false
var ui_scale := 1.0
var show_compact_portrait := false
var illustrated_scale := 0.0
var _heading: Label
var _name: Label
var _hp: StatBar
var _hp_number: Label
var _intent: EnemyIntent
var _defense: DefenseDisplay
var _status: StatusStrip
var _status_rule: ColorRect
var _portrait: Control
var _visual: InkSpirit
var _motion: Tween
var _tap := TouchTap.new()


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
	_intent = EnemyIntent.new()
	_defense = DefenseDisplay.new()
	_defense.is_player = false
	_status = StatusStrip.new()
	for source in [_intent, _defense, _status]:
		source.details_requested.connect(details_requested.emit)
	_status_rule = Ink.hline()
	_portrait = Control.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visual = InkSpirit.new()
	_visual.enemy_id = combatant.enemy_data.id if combatant != null and combatant.enemy_data != null else ""
	_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.add_child(_visual)
	for item in [_heading, _name, _hp, _hp_number, _defense, _portrait, _intent, _status_rule, _status]:
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(item)
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	_defense.mouse_filter = Control.MOUSE_FILTER_PASS
	_intent.mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	gui_input.connect(_on_gui_input)
	refresh(false)
	_layout()


func _on_gui_input(event: InputEvent) -> void:
	if _tap.matches(event, self) and combatant.is_alive():
		clicked.emit(index)
		accept_event()


func set_compact(value: bool) -> void:
	compact = value
	custom_minimum_size.y = 112 if value else 270
	if is_node_ready():
		_layout()


func _layout() -> void:
	if _visual == null:
		return
	var w := size.x
	_heading.position = Vector2.ZERO
	_heading.visible = not compact
	var factor := ui_scale if compact else 1.0
	_heading.size = Vector2(w, 20 * factor)
	_heading.add_theme_font_size_override("font_size", int(14 * factor))
	_name.position = Vector2(0, 20 * factor)
	_name.size = Vector2(w, 34 * factor if compact else 54)
	_name.add_theme_font_size_override("font_size", int(24 * factor) if compact else 42)
	_hp.position = Vector2(0, 52 * factor if compact else 82)
	var number_font := int(18 * factor) if compact else 22
	_hp_number.clip_text = true
	var number_face := _hp_number.get_theme_font("font")
	while number_font > int(12 * factor) and number_face.get_string_size(_hp_number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_font).x > w * 0.62:
		number_font -= 1
	_hp_number.add_theme_font_size_override("font_size", number_font)
	var number_width := minf(w * 0.62, maxf(w * 0.38, number_face.get_string_size(_hp_number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_font).x + 2 * factor))
	_hp.custom_minimum_size.y = 12
	_hp.size = Vector2(w - number_width - 10, 14 * factor)
	_hp_number.position = Vector2(w - number_width, _hp.position.y - 8 * factor)
	_hp_number.size = Vector2(number_width, 32 * factor)
	_name.clip_text = true
	var art_top := 196.0
	var art_side := minf(w + 18, maxf(64, size.y - art_top - 44))
	_portrait.visible = not compact
	_portrait.position = Vector2((w - art_side) * 0.5, art_top)
	_portrait.size = Vector2(art_side, art_side)
	_intent.position = Vector2(0, 108)
	_intent.size = Vector2(w, 76 * factor)
	_intent.set_ui_scale(factor)
	_status.position = Vector2(0, 124 * factor if compact else size.y - 36)
	_status.size = Vector2(w, 36 * factor)
	_status.set_ui_scale(factor)
	_status.visible = not _status.entries.is_empty()
	if compact:
		_heading.size.y = 16 * factor
		_name.position.y = 0
		_name.size.y = 28 * factor
		_name.add_theme_font_size_override("font_size", int(22 * factor))
		_hp.position.y = 30 * factor
		_hp.size.y = 10 * factor
		_hp_number.position.y = 24 * factor
		_hp_number.size.y = 24 * factor
		_name.clip_text = true
		_intent.position.y = 48 * factor
		_intent.size.y = EnemyIntent.ROW_HEIGHT * factor
		_status.position.y = 116 * factor
		if show_compact_portrait:
			art_top = 156 * factor
			art_side = minf(w, maxf(0, size.y - art_top - 4 * factor))
			_portrait.visible = art_side >= 48 * factor
			_portrait.position = Vector2((w - art_side) * 0.5, art_top)
			_portrait.size = Vector2.ONE * art_side
	_defense.set_cell_size((24.0 if compact else 36.0) * factor)
	if Palette.STYLE_ID == "taopunk" and (not compact or show_compact_portrait):
		_portrait.clip_contents = true
		_portrait.position = Vector2(0, art_top)
		var bottom := (44.0 if not compact else 4.0) * factor
		_portrait.size = Vector2(w, maxf(0, size.y - art_top - bottom))
	var defense_width := _defense.display_width()
	_defense.position = Vector2(0, _hp.position.y + (_hp.size.y - _defense.cell_size) * 0.5)
	_defense.size = Vector2(defense_width, _defense.cell_size)
	_hp.position.x = maxf(0, defense_width - 2 * factor)
	_hp.size.x -= _hp.position.x
	_status_rule.visible = _status.visible
	_status_rule.position = Vector2(0, _status.position.y - 4 * factor)
	_status_rule.size = Vector2(w, 1)
	if illustrated_scale > 0.0 and Palette.STYLE_ID == "taopunk":
		_layout_illustrated(illustrated_scale)


func _layout_illustrated(unit: float) -> void:
	var w := size.x
	_heading.hide()
	_name.position = Vector2.ZERO
	_name.size = Vector2(w, 48 * unit)
	_name.add_theme_font_size_override("font_size", int(40 * unit))
	var number_font := int(28 * unit)
	var number_face := _hp_number.get_theme_font("font")
	while number_font > int(12 * unit) and number_face.get_string_size(_hp_number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_font).x > w * 0.62:
		number_font -= 1
	_hp_number.add_theme_font_size_override("font_size", number_font)
	var number_width := minf(w * 0.62, maxf(120 * unit, number_face.get_string_size(_hp_number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_font).x + 2 * unit))
	_hp.position = Vector2(0, 54 * unit)
	_hp.size = Vector2(w - number_width - 12 * unit, 21 * unit)
	_hp_number.position = Vector2(w - number_width, 44 * unit)
	_hp_number.size = Vector2(number_width, 40 * unit)
	_intent.position = Vector2(0, 88 * unit)
	_intent.size = Vector2(w, 88 * unit)
	_intent.set_ui_scale(1.5 * unit)
	_status.position = Vector2(0, 180 * unit)
	_status.size = Vector2(w, 42 * unit)
	_status.set_ui_scale(unit)
	_status_rule.position.y = _status.position.y - 2 * unit
	# 状态出现或耗尽只更新图标，立绘始终使用同一占位。
	var art_y := 220 * unit
	_portrait.show()
	_portrait.position = Vector2(-20 * unit, art_y)
	_portrait.size = Vector2(w + 40 * unit, maxf(0, size.y - art_y))
	_portrait.clip_contents = true
	_defense.set_cell_size(32 * unit)
	var defense_width := _defense.display_width()
	_defense.position = Vector2(0, _hp.position.y + (_hp.size.y - _defense.cell_size) * 0.5)
	_defense.size = Vector2(defense_width, _defense.cell_size)
	_hp.position.x = maxf(0, defense_width - 2 * unit)
	_hp.size.x -= _hp.position.x


func refresh(animate := true) -> void:
	if combatant == null or _hp == null:
		return
	var ed: EnemyData = combatant.enemy_data
	_visual.glyph = ed.glyph if ed != null else "敌"
	_visual.enemy_id = ed.id if ed != null else ""
	_visual.set_defeated(not combatant.is_alive())
	if ed != null and ed.is_boss: _visual.set_combat_phase(EnemyMechanics.phase(combatant))
	_visual.queue_redraw()
	_name.text = combatant.display_name
	_hp.setup_bar(combatant.hp, combatant.max_hp, Palette.HP, "", animate)
	_hp_number.text = "%d / %d" % [combatant.hp, combatant.max_hp]
	_defense.set_values(combatant.block, combatant.persistent_block)
	_status.set_entries(StatusDisplay.collect(combatant))
	_layout()
	if not combatant.is_alive():
		_heading.text = "已击败"
		_intent.set_move(null, combatant)
		if not _visual.has_character_actor(): _visual.modulate.a = 0.18


func set_intent(move: EnemyMoveData) -> void:
	_intent.set_move(move, combatant)


func set_targeted(value: bool) -> void:
	_heading.text = ("当前目标" if value else "点击选择目标") if combatant.is_alive() else "已击败"
	_heading.add_theme_color_override("font_color", Palette.VERMILION_DK if value else Palette.INK_FAINT)


func impact_point() -> Vector2:
	return _portrait.get_global_rect().get_center() if _portrait.visible else _hp.get_global_rect().get_center()


func apply_feedback(event: Dictionary) -> void:
	if event.has("hp"):
		_hp.setup_bar(int(event.hp), int(event.max_hp), Palette.HP)
		_hp_number.text = "%d / %d" % [int(event.hp), int(event.max_hp)]
		_visual.set_defeated(int(event.hp) <= 0)
	if event.has("block"):
		_defense.set_values(int(event.block), int(event.persistent_block))
		_layout()
	if _visual.apply_character_feedback(event): return
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


func play_action(move: EnemyMoveData) -> Dictionary:
	var timing := _visual.play_action(move)
	if not timing.is_empty(): return timing
	anticipate()
	return {"release": 0.12, "duration": 0.22}


func action_origin() -> Vector2:
	return _visual.action_origin()


func has_attack_actor() -> bool:
	return _visual.has_attack_actor()


func attack_effect() -> String:
	return _visual.attack_effect()


func play_attack_hit(move: EnemyMoveData, hit_index: int) -> Dictionary:
	return _visual.play_attack_hit(move, hit_index)
