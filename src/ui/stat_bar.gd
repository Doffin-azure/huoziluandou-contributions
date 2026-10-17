extends Control
class_name StatBar
## 前景立即收缩，旧血量用一道延迟追上的残影表达。

var value := 0
var max_value := 1
var bar_color := Palette.HP
var bg_color := Palette.PANEL_DARK
var label_text := ""
var show_text := true
var font_size := 15
var _ratio := 0.0
var _trail := 0.0
var _initialized := false
var _front_tween: Tween
var _trail_tween: Tween
var _journey := false


func _ready() -> void:
	custom_minimum_size.y = 24
	_journey = JourneyStyle.is_active(self)
	if _journey:
		var factor := JourneyStyle.touch_scale(self)
		custom_minimum_size.y = 24 * factor
		font_size = int(15 * factor)
		bg_color = JourneyStyle.INK
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup_bar(v: int, m: int, c: Color, label := "", animate := true) -> void:
	var changed := v != value or m != max_value
	value = v
	max_value = maxi(1, m)
	bar_color = c
	label_text = "%d / %d" % [value, max_value] if label.is_empty() else label
	var target := clampf(float(value) / max_value, 0.0, 1.0)
	if not _initialized or not is_inside_tree() or not animate or Settings.reduced_motion:
		_stop_tweens()
		_ratio = target
		_trail = target
	elif changed:
		_stop_tweens()
		_trail = maxf(_trail, _ratio)
		_front_tween = create_tween()
		_front_tween.tween_method(_set_ratio, _ratio, target, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_trail_tween = create_tween()
		_trail_tween.tween_interval(0.10)
		_trail_tween.tween_method(_set_trail, _trail, target, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_initialized = true
	queue_redraw()


func _stop_tweens() -> void:
	if _front_tween != null:
		_front_tween.kill()
	if _trail_tween != null:
		_trail_tween.kill()


func _set_ratio(v: float) -> void:
	_ratio = v
	queue_redraw()


func _set_trail(v: float) -> void:
	_trail = v
	queue_redraw()


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(3)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	if _trail > _ratio:
		sb.bg_color = (JourneyStyle.GOLD if _journey else Palette.GOLD).darkened(0.15)
		draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(size.x * _trail, size.y)))
	if _ratio > 0.0:
		sb.bg_color = bar_color
		draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(size.x * _ratio, size.y)))
	if show_text:
		var font: Font = Ink.serif
		var baseline := (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
		draw_string(font, Vector2(0, baseline), label_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, JourneyStyle.TEXT if _journey else Palette.PAPER)
