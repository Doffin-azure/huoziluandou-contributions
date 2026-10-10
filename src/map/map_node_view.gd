extends Control
class_name MapNodeView
## 地图上的一个节点——圆形朱印。

signal pressed

enum State { LOCKED, AVAILABLE, COMPLETED, OFFER }

var node: MapNodeData
var state: int = State.LOCKED
var _pulse := 0.0

static func type_color(t: int) -> Color:
	match t:
		MapNodeData.Type.BOSS: return Palette.VERMILION
		MapNodeData.Type.ELITE: return Palette.PLUM
		MapNodeData.Type.SHOP: return Palette.GOLD
		MapNodeData.Type.REST: return Palette.JADE
		MapNodeData.Type.EVENT: return Palette.INDIGO
		MapNodeData.Type.FORK: return Palette.GOLD_DK
		_: return Palette.INK_SOFT


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
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func(): _scale_to(1.12))
	mouse_exited.connect(func(): _scale_to(1.0))
	pivot_offset = size * 0.5
	resized.connect(func(): pivot_offset = size * 0.5)
	queue_redraw()


func _process(delta: float) -> void:
	if state == State.AVAILABLE or state == State.OFFER:
		_pulse = fmod(_pulse + delta, TAU)
		queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == State.AVAILABLE or state == State.OFFER:
			pressed.emit()


func _scale_to(s: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(s, s), 0.08)


func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.34
	var col := type_color(node.type if node else 0)
	var dim := state == State.LOCKED

	if state == State.AVAILABLE or state == State.OFFER:
		var glow := 0.5 + 0.5 * sin(_pulse)
		draw_circle(c, r + 6 + glow * 4.0, Color(col.r, col.g, col.b, 0.18 + 0.12 * glow))
		draw_arc(c, r + 5, 0, TAU, 48, Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.8), 2.0, true)

	var fill := col
	if dim:
		fill = Color(0.55, 0.53, 0.49, 0.5)
	draw_circle(c, r, fill)
	draw_arc(c, r - 2, 0, TAU, 48, Palette.PAPER * Color(1, 1, 1, 0.55 if not dim else 0.3), 1.5, true)

	if state == State.COMPLETED:
		draw_circle(c, r - 6, Color(0.1, 0.09, 0.08, 0.35))

	var fs := int(r * 1.1)
	var font: Font = Ink.serif
	var g := type_glyph(node.type if node else 0)
	var tw2 := font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ascent := font.get_ascent(fs)
	var text_col := Palette.PAPER if not dim else Color(0.85, 0.84, 0.8, 0.7)
	draw_string(font, Vector2(c.x - tw2 * 0.5, c.y + ascent * 0.5 - fs * 0.08), g,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_col)

	if state == State.COMPLETED:
		draw_string(font, Vector2(c.x - 8, c.y + r + 18), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.JADE)
