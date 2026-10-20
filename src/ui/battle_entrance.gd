extends Control
class_name BattleEntrance
## 活字落印、青铜屏风展开；只负责表现，不读取或改变战斗随机数。

signal stamp_hit
signal reveal_started
signal finished

const DURATION := 0.96
const REVEAL_AT := 0.58
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()
var inscription := "活字入阵"
var encounter := ""
var enemies := ""
var accent := JourneyStyle.GOLD
var _tween: Tween
var _stamped := false
var _revealed := false
var _finished := false


func setup(node: MapNodeData, elite := false) -> void:
	if node.type == MapNodeData.Type.BOSS:
		inscription = "首领现身"
		accent = JourneyStyle.RED
	elif node.type == MapNodeData.Type.ELITE or elite:
		inscription = "精英临阵"
		accent = JourneyStyle.RED
	encounter = node.title.strip_edges()
	if encounter.is_empty(): encounter = "狭路相逢"
	enemies = " · ".join(node.enemies.map(func(enemy): return enemy.name))
	if enemies.is_empty(): enemies = "墨灵"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)
	_tween = create_tween()
	_tween.tween_method(_advance, 0.0, 1.0, DURATION)
	_tween.tween_callback(finish)
	Settings.changed.connect(_on_settings_changed)


func _exit_tree() -> void:
	if _tween != null: _tween.kill()
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)


func _on_settings_changed() -> void:
	if Settings.reduced_motion: finish()


func _input(event: InputEvent) -> void:
	if _finished: return
	# Block both native touch and keyboard shortcuts before the board's global input.
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventKey or event is InputEventAction or event is InputEventGesture:
		get_viewport().set_input_as_handled()


func _advance(value: float) -> void:
	progress = value
	if value >= 0.24 and not _stamped:
		_stamped = true
		stamp_hit.emit()
	if value >= REVEAL_AT and not _revealed:
		_revealed = true
		reveal_started.emit()


func finish() -> void:
	if _finished: return
	_finished = true
	if _tween != null: _tween.kill()
	_advance(1.0)
	hide()
	finished.emit()
	queue_free()


func _draw() -> void:
	if size.x < 1 or size.y < 1: return
	var unit := JourneyStyle.touch_scale(self)
	var opening := smoothstep(REVEAL_AT, 1.0, progress)
	var offset := size.x * 0.52 * opening
	var half := size.x * 0.5
	_draw_gate(Rect2(-offset, 0, half + 1, size.y), unit)
	_draw_gate(Rect2(half + offset, 0, half + 1, size.y), unit)
	var opacity := 1.0 - smoothstep(REVEAL_AT, 0.78, progress)
	if opacity <= 0: return
	# Keep the stamp legible in both a compact phone viewport and an ultrawide window.
	var tile_size := minf(82 * unit, minf(size.y * 0.19, size.x * 0.15))
	var gap := tile_size * 0.20
	var row_width := 4 * tile_size + 3 * gap
	var center := size * 0.5
	var top := center.y - tile_size * 0.55
	for i in 4:
		var landing := clampf((progress - 0.055 - i * 0.045) / 0.15, 0, 1)
		if landing <= 0: continue
		var eased := 1.0 - pow(1.0 - landing, 3)
		var scale_factor := lerpf(1.28, 1.0, eased)
		var rect := Rect2(Vector2(center.x - row_width * 0.5 + i * (tile_size + gap), top - (1 - eased) * tile_size * 0.4), Vector2.ONE * tile_size)
		rect = rect.grow(tile_size * (scale_factor - 1) * 0.5)
		_draw_type(rect, inscription[i], opacity * eased, unit)
	var text_alpha := opacity * smoothstep(0.20, 0.36, progress)
	var title_font := int(minf(21 * unit, tile_size * 0.30))
	var subtitle_font := int(minf(15 * unit, tile_size * 0.23))
	var title_y := top + tile_size + tile_size * 0.50
	_center_text(encounter, title_y, title_font, Color(JourneyStyle.TEXT, text_alpha), size.x * 0.78)
	_center_text(enemies, title_y + tile_size * 0.44, subtitle_font, Color(JourneyStyle.MUTED, text_alpha * 0.85), size.x * 0.78)
	var rule_y := top - tile_size * 0.42
	var rule_width := row_width * 0.35
	var rule_color := Color(accent, opacity * 0.55)
	draw_line(Vector2(center.x - rule_width, rule_y), Vector2(center.x - 12 * unit, rule_y), rule_color, unit, true)
	draw_line(Vector2(center.x + 12 * unit, rule_y), Vector2(center.x + rule_width, rule_y), rule_color, unit, true)
	var diamond := PackedVector2Array([Vector2(0,-4),Vector2(4,0),Vector2(0,4),Vector2(-4,0)])
	for i in diamond.size(): diamond[i] = diamond[i] * unit + Vector2(center.x, rule_y)
	draw_colored_polygon(diamond, rule_color)


func _draw_gate(rect: Rect2, unit: float) -> void:
	draw_rect(rect, JourneyStyle.INK)
	var inset := 12 * unit
	var frame := rect.grow(-inset)
	draw_rect(frame, Color(JourneyStyle.GOLD, 0.32), false, unit)
	draw_rect(frame.grow(-5 * unit), Color(JourneyStyle.GOLD, 0.12), false, unit)
	# Corner brackets echo the existing bronze panel ornament.
	for corner in [frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]:
		var direction := Vector2(1 if corner.x == frame.position.x else -1, 1 if corner.y == frame.position.y else -1)
		var start: Vector2 = corner + direction * 6 * unit
		draw_polyline(PackedVector2Array([start + Vector2(direction.x * 18 * unit, 0), start, start + Vector2(0, direction.y * 18 * unit)]), Color(JourneyStyle.GOLD, 0.60), 2 * unit, true)
	var y := size.y * 0.5
	for delta in [-1, 1]:
		draw_line(Vector2(rect.position.x, y + delta * size.y * 0.28), Vector2(rect.end.x, y + delta * size.y * 0.28), Color(JourneyStyle.EDGE, 0.22), unit, true)


func _draw_type(rect: Rect2, glyph: String, opacity: float, unit: float) -> void:
	draw_rect(Rect2(rect.position + Vector2(0, 5 * unit), rect.size), Color(0.02, 0.05, 0.06, opacity * 0.65))
	draw_rect(rect, Color(JourneyStyle.SURFACE, opacity))
	draw_rect(rect, Color(accent, opacity * 0.80), false, 2 * unit)
	draw_rect(rect.grow(-5 * unit), Color(accent, opacity * 0.30), false, unit)
	var font_size := int(rect.size.x * 0.64)
	var width := Ink.serif.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := rect.get_center() + Vector2(-width * 0.5, (Ink.serif.get_ascent(font_size) - Ink.serif.get_descent(font_size)) * 0.5)
	draw_string(Ink.serif, baseline, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(JourneyStyle.TEXT, opacity))


func _center_text(text: String, baseline: float, font_size: int, color: Color, max_width: float) -> void:
	var line := TextLine.new()
	line.add_string(text, Ink.serif, maxi(1, font_size))
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.width = max_width
	line.alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.draw(get_canvas_item(), Vector2((size.x - max_width) * 0.5, baseline - line.get_line_ascent()), color)
