extends Button
class_name EnemyIntent
## 只读意图：常驻形状与数值，完整名称和说明通过悬停/点击查看。
signal details_requested(title: String, body: String, scroll_body: bool)
var entries: Array = []
var _move: EnemyMoveData
var _unit: Combatant
var _ui_scale := 1.0
var _row: HBoxContainer
const ROW_HEIGHT := 64.0


func _ready() -> void:
	text = ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	resized.connect(_layout)
	pressed.connect(_show_details)
	_rebuild()


func set_move(move: EnemyMoveData, unit: Combatant) -> void:
	_move = move
	_unit = unit
	entries = describe(move, unit)
	visible = not entries.is_empty()
	tooltip_text = _details()
	if is_node_ready(): _rebuild()


func set_ui_scale(value: float) -> void:
	if is_equal_approx(value, _ui_scale): return
	_ui_scale = value
	if is_node_ready(): _rebuild()


static func describe(move: EnemyMoveData, unit: Combatant) -> Array:
	if move == null or unit == null or not unit.is_alive(): return []
	var result: Array = []
	match move.kind:
		EnemyMoveData.Kind.ATTACK, EnemyMoveData.Kind.MULTI:
			var damage := maxi(0, move.damage + unit.status_stacks("strength"))
			var number := "%d × %d" % [damage, move.hits] if move.kind == EnemyMoveData.Kind.MULTI else str(damage)
			result.append({"symbol": "hit", "value": number, "negative": true})
		EnemyMoveData.Kind.BLOCK:
			result.append({"symbol": "block", "value": str(move.block), "negative": false})
		EnemyMoveData.Kind.ATTACK_BLOCK:
			result.append({"symbol": "hit", "value": str(maxi(0, move.damage)), "negative": true})
			result.append({"symbol": "block", "value": str(move.block), "negative": false})
		EnemyMoveData.Kind.BUFF, EnemyMoveData.Kind.DEBUFF:
			var harmful := move.kind == EnemyMoveData.Kind.DEBUFF
			var symbol := move.status_id if BattleSymbol.SPECS.has(move.status_id) else ("intent_debuff" if harmful else "intent_buff")
			result.append({"symbol": symbol, "value": str(move.status_stacks), "negative": harmful})
		EnemyMoveData.Kind.INJECT:
			result.append({"symbol": "intent_inject", "value": str(move.inject_count), "negative": true})
		EnemyMoveData.Kind.SPECIAL:
			result.append({"symbol": "unknown", "value": "", "negative": false})
	if move.kind != EnemyMoveData.Kind.INJECT and move.inject_count > 0:
		result.append({"symbol": "intent_inject", "value": str(move.inject_count), "negative": true})
	return result


func _rebuild() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(Palette.PAPER_WARM, 0.65)
	normal.border_color = Palette.VERMILION_DK if entries.any(func(entry): return entry.negative) else Palette.INK_FAINT
	normal.border_width_left = 3
	normal.set_corner_radius_all(2)
	add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Palette.PAPER_WARM
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_row.add_theme_constant_override("separation", int(16 * _ui_scale))
	for entry in entries:
		var group := HBoxContainer.new()
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_theme_constant_override("separation", int(6 * _ui_scale))
		_row.add_child(group)
		var icon := BattleSymbol.new()
		icon.symbol = entry.symbol
		icon.ink = BattleSymbol.color_for(entry.symbol, entry.negative)
		icon.custom_minimum_size = Vector2.ONE * 44 * _ui_scale
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		group.add_child(icon)
		var number := Ink.label(entry.value, "", Palette.INK)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.add_theme_font_override("font", Ink.serif)
		number.add_theme_font_size_override("font_size", int(36 * _ui_scale))
		number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		group.add_child(number)
	_layout.call_deferred()


func _layout() -> void:
	if _row == null: return
	var wanted := _row.get_combined_minimum_size()
	# 组合意图占一行；受限宽度时仍完整显示两项与次数。
	var factor := minf(1.0, size.x / maxf(1, wanted.x))
	_row.scale = Vector2.ONE * factor
	_row.size = wanted
	_row.position = Vector2(maxf(0, (size.x - wanted.x * factor) * 0.5), maxf(0, (size.y - wanted.y * factor) * 0.5))


func _make_custom_tooltip(for_text: String) -> Object:
	return Ink.tooltip(for_text)


func _details(link_pollution := false) -> String:
	if _move == null or entries.is_empty(): return ""
	var lines: Array[String] = [_move.title]
	if _move.kind in [EnemyMoveData.Kind.ATTACK, EnemyMoveData.Kind.MULTI]:
		var attacks := _move.hits if _move.kind == EnemyMoveData.Kind.MULTI else 1
		lines.append("攻击%d次，每次%d伤害，尚未扣除你的防御。" % [attacks, maxi(0, _move.damage + _unit.status_stacks("strength"))])
	else:
		lines.append(BattleText.enemy_move(_move))
	if _move.kind in [EnemyMoveData.Kind.BUFF, EnemyMoveData.Kind.DEBUFF]:
		var status := Database.get_status(_move.status_id)
		if status != null:
			lines.append(str(EffectGlossary.entry("status:" + status.id).get("text", "")))
	if _move.inject_count > 0:
		if not _move.inject_glyph.is_empty() and _move.kind != EnemyMoveData.Kind.INJECT: lines.append("向空格塞入%d枚【%s】。" % [_move.inject_count, _move.inject_glyph])
		var pollution := Database.get_pollution(_move.pollution_id)
		if pollution != null:
			lines.append(pollution.name + "污染" if link_pollution else "污染：%s\n%s" % [pollution.name, pollution.description])
	return "\n".join(lines)


func _show_details() -> void:
	if not entries.is_empty():
		details_requested.emit("敌方意图", _details(true), true)
