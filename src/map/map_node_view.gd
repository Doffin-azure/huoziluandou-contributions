extends Control
class_name MapNodeView
## 地图上的一个节点——圆形朱印。

signal pressed

enum State { LOCKED, AVAILABLE, COMPLETED, OFFER }

var node: MapNodeData
var state: int = State.LOCKED
var _pulse := 0.0
var _unit := 1.0
var _tap := TouchTap.new()

static func type_color(t: int) -> Color:
	return JourneyStyle.RED if t in [MapNodeData.Type.BATTLE, MapNodeData.Type.ELITE, MapNodeData.Type.BOSS] else JourneyStyle.GOLD



static func type_glyph(t: int) -> String:
	match t:
		MapNodeData.Type.BATTLE: return "战"
		MapNodeData.Type.BOSS: return "首"
		MapNodeData.Type.ELITE: return "精"
		MapNodeData.Type.SHOP: return "商"
		MapNodeData.Type.REST: return "休"
		MapNodeData.Type.EVENT: return "事"
		MapNodeData.Type.FORK: return "岔"
		_: return "?"


func setup(p_node: MapNodeData) -> void:
	node = p_node
	custom_minimum_size = Vector2(96, 112)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_mobile_unit(unit: float) -> void:
	_unit = unit
	custom_minimum_size = Vector2(64, 88) * unit
	size = custom_minimum_size
	queue_redraw()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(func(): _scale_to(1.035))
	mouse_exited.connect(func(): _scale_to(1.0))
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)
	queue_redraw()


func _process(delta: float) -> void:
	if not Settings.reduced_motion and (state == State.AVAILABLE or state == State.OFFER):
		_pulse = fmod(_pulse + delta, TAU)
		queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if _tap.matches(event, self):
		pressed.emit()


func _scale_to(s: float) -> void:
	if Settings.reduced_motion: return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(s, s), 0.08)


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	var active := state in [State.AVAILABLE, State.OFFER]
	var done := state == State.COMPLETED
	var r := minf(size.x * 0.40, size.y * 0.35)
	var outline := JourneyStyle.GOLD if active or done else JourneyStyle.EDGE
	var fill := JourneyStyle.INK if not active else Color("873c34")
	var points := PackedVector2Array()
	for i in 8:
		points.append(c + Vector2.from_angle(PI / 8.0 + TAU * i / 8.0) * r)
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, outline, 2 if active else 1, true)
	var inner := PackedVector2Array()
	for point in points: inner.append(c + (point - c) * 0.84)
	inner.append(inner[0])
	draw_polyline(inner, Color(outline, 0.45), 1, true)
	if active:
		var intensity := 0.45 if Settings.reduced_motion else 0.45 + 0.2 * sin(_pulse * 2)
		draw_arc(c, r + 7, -PI * 0.77, -PI * 0.23, 24, Color(JourneyStyle.GOLD, intensity), 2, true)
		draw_arc(c, r + 7, PI * 0.23, PI * 0.77, 24, Color(JourneyStyle.GOLD, intensity), 2, true)
	if has_focus(): draw_rect(Rect2(Vector2.ONE * 2, size - Vector2.ONE * 4), JourneyStyle.GOLD, false, 1)
	var font: Font = Ink.serif
	var glyph := type_glyph(node.type if node else 0)
	var fs := int(28 * _unit) if _unit > 1 else 34
	var width := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - width * 0.5, c.y + font.get_ascent(fs) * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, JourneyStyle.TEXT if active or done else JourneyStyle.MUTED)
	var caption := "已行" if done else ("当前" if active else "%02d" % (node.order if node else 0))
	var caption_size := int(12 * _unit)
	var small_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
	draw_string(font, Vector2(c.x - small_width * 0.5, size.y - 3 * _unit), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, outline)
