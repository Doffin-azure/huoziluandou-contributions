extends Control
class_name BattleEffects
## 所有瞬态节点都由本层拥有，离开战斗会连同 Tween 一起释放。


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func point_of(control: Control) -> Vector2:
	return get_global_transform().affine_inverse() * control.get_global_rect().get_center()


func fly_word(text: String, from: Vector2, to: Vector2) -> void:
	if Settings.reduced_motion:
		return
	var word := Ink.label(text, "", Palette.VERMILION_DK)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	word.add_theme_font_size_override("font_size", 28)
	word.add_theme_color_override("font_shadow_color", Palette.PAPER)
	word.add_theme_constant_override("shadow_offset_y", 2)
	add_child(word)
	word.position = from - word.get_combined_minimum_size() * 0.5
	var half := word.get_combined_minimum_size() * 0.5
	var bend := (from + to) * 0.5 + Vector2(0, -35)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		word.position = from.lerp(bend, t).lerp(bend.lerp(to, t), t) - half, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(word, "modulate:a", 0.0, 0.06)
	tw.tween_callback(word.queue_free)


func number(text: String, pos: Vector2, color: Color) -> void:
	var label := Ink.label(text, "", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_shadow_color", Palette.PAPER)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	label.position = pos - label.get_combined_minimum_size() * 0.5
	var tw := create_tween().set_parallel(true)
	if not Settings.reduced_motion:
		tw.tween_property(label, "position:y", label.position.y - 28, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.18).set_delay(0.30)
	tw.chain().tween_callback(label.queue_free)


func burst(pos: Vector2, shield := false, heavy := false) -> void:
	if Settings.reduced_motion:
		return
	var impact := InkImpact.new()
	impact.position = pos
	impact.ink_color = Palette.BLOCK if shield else Palette.VERMILION_DK
	impact.heavy = heavy
	add_child(impact)
	var tw := create_tween()
	tw.tween_property(impact, "progress", 1.0, 0.30 if heavy else 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(impact.queue_free)
