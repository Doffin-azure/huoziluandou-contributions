extends Control
class_name GlyphOffer
## A hit target projected onto a real stage object, with a small loose price label.
signal clicked
signal hovered
var character: CharacterData
var caption := ""
var selected := false
var _caption: Label
var _tap := TouchTap.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	_caption = JourneyStyle.label(caption, "Muted", JourneyStyle.GOLD)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", int(16 * JourneyStyle.touch_scale(self)))
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = 6
	_caption.offset_bottom = 42
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func(): hovered.emit())
	focus_entered.connect(func(): hovered.emit(); queue_redraw())
	focus_exited.connect(queue_redraw)


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if _tap.matches(event, self):
		clicked.emit()
		accept_event()


func _draw() -> void:
	if not selected and not has_focus(): return
	var center := Vector2(size.x * 0.5, size.y + 3)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -5), center + Vector2(5, -5), center + Vector2(0, -10)]), JourneyStyle.RED)
	if has_focus(): draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(JourneyStyle.GOLD, 0.45), false, 1)
