extends Control
class_name HitFX
## 打击感效果层：屏幕震动（trauma 模型）、顿帧（hit-stop）、伤害数字、受击闪白。
## 纯程序化、零外部资源；通过 setup() 指定被震动的根节点（通常是 content）。

const MAX_SHAKE := 18.0          # 满创伤时的最大位移（px）
const TRAUMA_DECAY := 1.9        # 创伤每秒衰减速度（越大震得越干脆）
const TRAUMA_PER_DMG := 0.05     # 每点伤害贡献的创伤
const HITSTOP_THRESHOLD := 9     # 达到该伤害才触发顿帧
const HITSTOP_DURATION := 0.06   # 顿帧真实时长（秒）

var _shake_target: Control = null
var _trauma := 0.0
var _rng := RandomNumberGenerator.new()
var _hit_stopping := false
var _flash_overlay: ColorRect = null
var _splats: Array = []


func setup(shake_target: Control) -> void:
	_shake_target = shake_target
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 全屏红/白闪覆盖层（玩家受击时用）
	_flash_overlay = ColorRect.new()
	_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.color = Color(1, 1, 1, 0)
	_flash_overlay.visible = false
	add_child(_flash_overlay)


func _process(delta: float) -> void:
	for i in range(_splats.size() - 1, -1, -1):
		_splats[i].life -= delta
		_splats[i].pos += _splats[i].velocity * delta
		_splats[i].velocity *= 0.92
		if _splats[i].life <= 0.0:
			_splats.remove_at(i)
	queue_redraw()
	if _shake_target == null:
		return
	if _trauma > 0.001:
		_trauma = max(0.0, _trauma - delta * TRAUMA_DECAY)
		var s := _trauma * _trauma
		var off := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * MAX_SHAKE * s
		_shake_target.position = off
	else:
		_trauma = 0.0
		_shake_target.position = Vector2.ZERO


## 按伤害大小累积创伤（封顶 1.0）
func add_trauma(dmg: int) -> void:
	_trauma = min(1.0, _trauma + dmg * TRAUMA_PER_DMG)


## 顿帧：短暂把引擎时间几乎停住，制造“命中卡一下”。防重入。
func hit_stop(duration := HITSTOP_DURATION) -> void:
	if _hit_stopping:
		return
	_hit_stopping = true
	Engine.time_scale = 0.06
	get_tree().create_timer(duration, true, false, true).timeout.connect(_end_hit_stop, CONNECT_ONE_SHOT)


func _end_hit_stop() -> void:
	Engine.time_scale = 1.0
	_hit_stopping = false


## 伤害数字：字号/颜色随伤害分级，弹入（overshoot）→ 上浮减速 → 淡出，带随机偏移与描边。
func damage_popup(pos: Vector2, amount: int, player_hit: bool) -> void:
	var fs := 26
	var color := Palette.VERMILION
	var outline_w := 3
	if player_hit:
		color = Color(0.92, 0.34, 0.28)
	else:
		if amount >= 15:
			fs = 44
			color = Palette.GOLD
			outline_w = 7
		elif amount >= 8:
			fs = 34
		elif amount <= 2:
			fs = 21

	var p := pos + Vector2(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-6.0, 10.0))
	var l := Ink.label(str(amount), "", color)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_color_override("font_outline_color", Color(1.0, 0.96, 0.86, 0.95 if amount >= 15 else 0.55))
	l.add_theme_constant_override("outline_size", outline_w)
	l.position = p
	l.scale = Vector2(0.35, 0.35)
	add_child(l)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", p.y - 64.0, 0.78).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.46).set_delay(0.38)
	get_tree().create_timer(0.95).timeout.connect(l.queue_free)


## 目标闪白：直接置白，再平滑恢复（Tween 挂在目标上，目标销毁时自动中止）。
func flash_target(target: Control, color := Color(2.6, 2.6, 2.6, 1.0)) -> void:
	if target == null or not is_instance_valid(target):
		return
	splash(target.global_position + target.size * 0.5, 1.0)
	var base := target.modulate
	target.modulate = color
	var tw := target.create_tween()
	tw.tween_interval(0.045)
	tw.tween_property(target, "modulate", base, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## 全屏受击闪（玩家受伤时，红光一闪）。
func splash(pos: Vector2, intensity := 1.0) -> void:
	for i in 14:
		var angle := _rng.randf_range(0.0, TAU)
		var speed := _rng.randf_range(45.0, 150.0) * intensity
		_splats.append({"pos": pos, "velocity": Vector2.from_angle(angle) * speed, "radius": _rng.randf_range(2.0, 6.0) * intensity, "life": _rng.randf_range(0.18, 0.42), "max_life": 0.42})
	queue_redraw()

func shake(strength: float = 8.0, duration: float = 0.18) -> void:
	if _shake_target == null:
		return
	var origin := _shake_target.position
	var tw := create_tween()
	for i in 5:
		var decay := 1.0 - float(i) / 5.0
		tw.tween_property(_shake_target, "position", Vector2(_rng.randf_range(-strength, strength) * decay, _rng.randf_range(-strength, strength) * decay), duration / 5.0)
	tw.tween_property(_shake_target, "position", origin, 0.05)


func word_slam(word: String, pos: Vector2) -> void:
	if word.is_empty():
		return
	var l := Ink.label(word, "", Palette.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 48 if word.length() <= 2 else 38)
	l.add_theme_color_override("font_shadow_color", Palette.PLUM)
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.position = pos - Vector2(90, 30)
	l.size = Vector2(180, 64)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(1.65, 1.65)
	l.modulate.a = 0.0
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "modulate:a", 1.0, 0.06)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.22)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.24)
	tw.chain().tween_callback(l.queue_free)
	shake(4.0, 0.12)

func _draw() -> void:
	for s in _splats:
		var alpha: float = clampf(s.life / s.max_life, 0.0, 1.0)
		draw_circle(s.pos, s.radius, Color(Palette.VERMILION.r, Palette.VERMILION.g, Palette.VERMILION.b, alpha * 0.8))


func flash_screen(color := Color(0.9, 0.24, 0.2, 0.3), duration := 0.24) -> void:
	if _flash_overlay == null:
		return
	_flash_overlay.color = color
	_flash_overlay.modulate = Color.WHITE
	_flash_overlay.visible = true
	var tw := create_tween()
	tw.tween_property(_flash_overlay, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _flash_overlay.visible = false)
