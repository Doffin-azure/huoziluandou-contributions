extends Control
class_name GlyphEffect
## 有上限的一次性图标/粒子演出。形状与轨迹不同，随机数只用于表现。
var profile: Dictionary
var phase := "impact"
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var radius := 44.0
var duration := 0.42
var _age := 0.0
var _particles: Array = []
var _icons: Array[BattleSymbol] = []
var _random := RandomNumberGenerator.new()
var _still := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_random.seed = int(profile.get("seed", 0)) + (17 if phase == "cast" else 41)
	_still = Settings.reduced_motion
	if _still:
		duration = 0.18
	var parts: Array = profile.get("parts", [profile]) if phase == "cast" else [profile]
	# HUD 已有资源/防御图标，局部反馈只加粒子，避免再盖一枚大图标。
	if phase != "cast" and radius <= 20 and not _still:
		parts = []
	for part in parts:
		var icon := BattleSymbol.new()
		icon.symbol = part.symbol
		icon.ink = part.color
		icon.size = Vector2.ONE * (24 if phase == "cast" else 30)
		add_child(icon)
		_icons.append(icon)
	if not _still and phase != "cast":
		for index in (12 if profile.family == "draw" else 22):
			_particles.append({"angle": _random.randf_range(0, TAU), "speed": _random.randf_range(0.40, 1.0),
				"size": _random.randf_range(1.3, 3.0), "delay": index % 4 * 0.025})
	_update_icons()


func _process(delta: float) -> void:
	if Settings.reduced_motion and not _still:
		queue_free()
		return
	_age += delta
	if _age >= duration:
		queue_free()
		return
	_update_icons()
	queue_redraw()


func _cast_point(t: float) -> Vector2:
	var bend := (origin + destination) * 0.5 + Vector2(0, -minf(32, origin.distance_to(destination) * 0.15))
	return origin.lerp(bend, t).lerp(bend.lerp(destination, t), t)


func _update_icons() -> void:
	var t := clampf(_age / duration, 0, 1)
	var center := destination + Vector2(0, 16) if _still or phase != "cast" else _cast_point(t)
	for index in _icons.size():
		var icon: BattleSymbol = _icons[index]
		var offset := Vector2((index - (_icons.size() - 1) * 0.5) * 22, 0) if phase == "cast" else Vector2.ZERO
		icon.position = center + offset - icon.size * 0.5
		icon.pivot_offset = icon.size * 0.5
		icon.modulate.a = minf(1.0, (1.0 - t) * 4.0)
		icon.scale = Vector2.ONE * (1.0 if _still else (lerpf(0.82, 1.04, sin(t * PI)) if phase != "cast" else 1.0))
		if not _still and profile.style in ["swirl", "loop", "orbit"]:
			icon.rotation = t * TAU * 0.22


func _draw() -> void:
	if _still:
		return
	var t := clampf(_age / duration, 0, 1)
	var center := _cast_point(t) if phase == "cast" else destination
	var color: Color = profile.color
	var style: String = profile.style
	var fade := (1.0 - t) * 0.70
	if phase == "cast":
		for index in 7:
			var trail_t := maxf(0, t - index * 0.035)
			var p := _cast_point(trail_t)
			if profile.family == "electric":
				var next := _cast_point(maxf(0, trail_t - 0.035))
				draw_line(p + Vector2(0, sin(index * 3.1 + t * 24) * 3), next, Color(color, fade * (1 - index / 8.0)), 1.6, true)
			else:
				var c := Color(color, fade * (1 - index / 8.0))
				match profile.family:
					"ice": draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(2, 0), p + Vector2(0, 4), p - Vector2(2, 0)]), c)
					"shield", "draw": draw_rect(Rect2(p - Vector2(2, 3), Vector2(4, 6)), c, false, 1.0)
					"gravity": draw_rect(Rect2(p - Vector2(2, 3), Vector2(4, 6)), c, true)
					"gold": draw_arc(p, 2.5, 0, TAU, 10, c, 1.0, true)
					"heal", "clean":
						draw_line(p - Vector2(3, 0), p + Vector2(3, 0), c, 1.0, true)
						draw_line(p - Vector2(0, 3), p + Vector2(0, 3), c, 1.0, true)
					"fire": draw_line(p - Vector2(1, 4), p + Vector2(1, 2), c, 1.4, true)
					_: draw_circle(p, 1.5 + index * 0.15, c)
		return
	for index in _particles.size():
		var particle: Dictionary = _particles[index]
		var progress := clampf((t - particle.delay) / maxf(0.01, 1 - particle.delay), 0, 1)
		var direction := Vector2.from_angle(particle.angle)
		var reach: float = radius * float(particle.speed)
		var offset: Vector2 = direction * (5 + reach * progress)
		match style:
			"embers", "steam", "glow", "rise":
				offset = Vector2(direction.x * reach * 0.55 * progress, -reach * progress + sin(index) * 6)
			"charge", "split_charge", "gather", "merge":
				offset = direction.rotated(progress * 1.2) * reach * (1 - progress)
			"down":
				offset = Vector2(direction.x * reach * 0.6, lerpf(-reach, 18, progress * progress))
			"left", "right", "dash", "bridge":
				offset = Vector2(reach * progress * (-1 if style == "left" else 1), direction.y * 12)
			"loop", "swirl", "orbit", "echo", "ripple", "wash":
				offset = direction.rotated(progress * TAU * 0.6) * reach * sin(progress * PI * 0.5)
			"pulse", "settle":
				offset = Vector2(direction.x * reach * 0.5, -reach * progress * 0.7)
			"drip", "stain":
				offset.y = absf(offset.y) + progress * progress * 14
		var p: Vector2 = center + offset
		var c := Color(color, fade * (1 - particle.delay))
		var s: float = particle.size * (1 - progress * 0.5)
		if style == "steam":
			draw_arc(p, s * 2.5, progress * 3, progress * 3 + PI, 12, Color(color, fade * 0.5), 1.5, true)
			continue
		if style in ["charge", "split_charge", "settle"]:
			draw_circle(p, s * 1.2, c)
			continue
		if style == "barrier":
			draw_line(p - Vector2(0, 6), p + Vector2(0, 6), c, 1.5, true)
			continue
		match profile.family:
			"electric":
				var tip: Vector2 = p + direction * 11
				draw_polyline(PackedVector2Array([p - direction * 6, p + Vector2(-direction.y, direction.x) * 3, tip]), c, 1.3, true)
			"ice":
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 2.5), p + Vector2(s, 0), p + Vector2(0, s * 2.5), p - Vector2(s, 0)]), c)
			"draw": draw_rect(Rect2(p - Vector2(s, s * 1.8), Vector2(s * 2, s * 3.6)), c, false, 1.0)
			"gravity": draw_rect(Rect2(p - Vector2.ONE * s, Vector2.ONE * s * 2), c, true)
			"shield": draw_rect(Rect2(p - Vector2.ONE * s, Vector2.ONE * s * 2), c, false, 1.0)
			"gold": draw_arc(p, s * 1.8, 0, TAU, 10, c, 1.1, true)
			"heal", "clean":
				draw_line(p - Vector2(s * 1.7, 0), p + Vector2(s * 1.7, 0), c, 1.4, true)
				draw_line(p - Vector2(0, s * 1.7), p + Vector2(0, s * 1.7), c, 1.4, true)
			"poison": draw_circle(p, s * 1.7, c)
			_: draw_line(p - direction * s * 3, p + direction * s * 2, c, 1.2, true)
	if style in ["slash", "reverse", "fracture"]:
		var sign_value := -1 if style == "reverse" else 1
		draw_polyline(PackedVector2Array([center + Vector2(-radius * sign_value, 12), center + Vector2(-8 * sign_value, -6), center + Vector2(radius * sign_value, -16)]), Color(color, fade), 2.8, true)
	elif style in ["swirl", "loop", "orbit", "ward", "pulse", "charge", "ripple", "wash", "blast"]:
		draw_arc(center, (12 + radius * t) * 0.65, t * 2.5, t * 2.5 + PI * 1.5, 30, Color(color, fade * 0.6), 1.6, true)


func freeze_at(progress: float) -> void:
	set_process(false)
	_age = clampf(progress, 0, 0.99) * duration
	_update_icons()
	queue_redraw()
