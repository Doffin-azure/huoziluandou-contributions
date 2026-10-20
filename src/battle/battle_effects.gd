extends Control
class_name BattleEffects
## 所有瞬态节点都由本层拥有，离开战斗会连同 Tween 一起释放。
var _impact_targets: Array = []
var _impact_strength := 0.0
var _impact_time := 0.0
var _ui_scale := 1.0
const MAX_GLYPH_EFFECTS := 10


func enemy_attack(style: String, from: Vector2, to: Vector2) -> void:
	if Settings.reduced_motion: return
	var effect := EnemyAttackEffect.new()
	effect.attack_style = style
	effect.phase = "attack"
	effect.duration = 0.14
	effect.scale = Vector2.ONE * _ui_scale
	effect.origin = from / _ui_scale
	effect.destination = to / _ui_scale
	add_child(effect)


func enemy_ink(phase: String, from: Vector2, to: Vector2, glyph := "", delay := 0.0) -> void:
	if Settings.reduced_motion: return
	var effect := EnemyInkEffect.new()
	effect.phase = phase
	effect.scale = Vector2.ONE * _ui_scale
	effect.origin = from / _ui_scale
	effect.destination = to / _ui_scale
	effect.glyph = glyph
	effect.delay = delay
	effect.duration = {"attack": 0.14, "charge": 0.4, "pollution": 0.34, "land": 0.22}.get(phase, 0.22)
	add_child(effect)


func set_ui_scale(value: float) -> void:
	_ui_scale = value


func cast(profile: Dictionary, from: Vector2, to: Vector2) -> void:
	if Settings.reduced_motion:
		return
	_spawn_glyph(profile, from, to, "cast", 30.0)


func glyph_impact(profile: Dictionary, at: Vector2, radius := 42.0) -> void:
	_spawn_glyph(profile, at, at, "impact", radius)


func _spawn_glyph(profile: Dictionary, from: Vector2, to: Vector2, phase: String, radius: float) -> void:
	var live := get_children().filter(func(child): return child is GlyphEffect and not child.is_queued_for_deletion())
	if live.size() >= MAX_GLYPH_EFFECTS:
		live[0].queue_free()
	var effect := GlyphEffect.new()
	effect.profile = profile
	effect.phase = phase
	effect.scale = Vector2.ONE * _ui_scale
	effect.origin = from / _ui_scale
	effect.destination = to / _ui_scale
	effect.radius = radius
	effect.duration = 0.18 if phase == "cast" else 0.42
	add_child(effect)


func setup_impact(hud: Control, stage: Control) -> void:
	_apply_impact_offset(Vector2.ZERO)
	_impact_targets.clear()
	_impact_strength = 0.0
	for target in [hud, stage]:
		if is_instance_valid(target):
			_impact_targets.append({"target": weakref(target), "origin": target.position, "last_position": target.position})


func table_impact(strength := 6.0) -> void:
	if Settings.reduced_motion:
		return
	_impact_time = 0.0
	_impact_strength = maxf(_impact_strength, strength)


func _process(delta: float) -> void:
	if _impact_strength == 0.0:
		return
	_impact_time += delta
	var envelope := maxf(0.0, 1.0 - _impact_time / 0.24)
	var offset := Vector2(sin(_impact_time * 89.0) * 0.28, sin(_impact_time * 72.0)) * _impact_strength * envelope * envelope
	if Settings.reduced_motion or envelope <= 0.0:
		_impact_strength = 0.0
		offset = Vector2.ZERO
	_apply_impact_offset(offset)


func _apply_impact_offset(offset: Vector2) -> void:
	for entry in _impact_targets:
		var target: Control = entry.target.get_ref()
		if is_instance_valid(target):
			# Layout may finish after setup, or change while shaking (resize/safe area).
			# A position we did not write is the new rest pose, never another offset.
			if not target.position.is_equal_approx(entry.last_position):
				entry.origin = target.position
			target.position = entry.origin + offset
			entry.last_position = target.position


func _exit_tree() -> void:
	_apply_impact_offset(Vector2.ZERO)


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
	label.z_index = 1
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
