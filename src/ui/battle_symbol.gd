extends Control
class_name BattleSymbol
## 实心墨印符号：重轮廓、切口与留白；单色构型，不依赖纹理和描边装饰。
const SPECS := {
	"health": ["heart", ""], "heat": ["flame", ""], "energy": ["bolt", ""], "gold": ["coin", ""],
	"block": ["shield", ""], "persistent_block": ["shield", "lock"], "temp_funds": ["coin", "clock"], "equity": ["chart", "coin"],
	"bag": ["bag", ""], "discard": ["cards", "return"],
	"armor_plating": ["armor", ""], "guard_inject": ["shield", "minus"], "prevent_interference": ["shield", "cross"],
	"convert_block": ["armor", "shield"], "counter": ["sword", "return"], "next_heat_to_block": ["snow", "shield"],
	"longword_draw": ["cards", "plus"], "electric_material": ["cards", "bolt"], "heat_to_energy": ["flame", "bolt"],
	"overheat_shield": ["snow", "flame"], "next_copy_layer": ["cards", "copy"], "double_next": ["sword", "copy"],
	"gold_to_shield": ["coin", "shield"], "inject_bounty": ["coin", "plus"], "instant_power": ["bolt", "arrow"],
	"heat_pollution_damage": ["flame", "sword"], "heart_layers": ["heart", "shield"], "heart_power": ["heart", "shield"], "next_diagonal": ["grid", "diagonal"],
	"flow": ["wave", "return"], "next_compound": ["chain", "plus"], "energy_idle": ["bolt", "clock"],
	"heat_overload_bonus_armed": ["flame", "plus"], "accel": ["arrow", "plus"], "next_rapid": ["arrow", "cards"],
	"next_double_draw": ["cards", "double"], "next_overfire": ["flame", "arrow"], "electric_overload": ["bolt", "flame"],
	"fireproof": ["shield", "flame"], "blastproof": ["shield", "star"], "joint_funding": ["chain", "coin"],
	"profit_share": ["fork", "coin"], "next_energy_bonus": ["sword", "bolt"], "gravity_always": ["grid", "down"],
	"compound_equity": ["chart", "return"], "ceasefire": ["sword", "stop"], "serial": ["chain", "arrow"],
	"repeat_zero": ["loop", "clock"], "split_mind": ["fork", "cross"], "vigor": ["leaf", ""],
	"vigor_next": ["leaf", "cards"], "auto_refill": ["cards", "flame"], "repeat": ["loop", "copy"],
	"next_serial_bonus": ["chain", "sword"], "next_draw_bonus": ["cards", "arrow"], "warm_heart": ["heart", "flame"],
	"strong_heart": ["heart", "plus"], "manual_draw": ["hand", "cards"], "shared_attack": ["sword", "chain"],
	"permanent_guard": ["armor", "lock"], "turn_guard": ["shield", "clock"], "guard_halve": ["heart", "half"],
	"damage_double": ["snow", "sword"], "no_block": ["shield", "stop"], "flow_row": ["grid", "arrow"],
	"reload": ["bag", "down"], "draw_penalty": ["cards", "minus"], "empowered": ["star", "plus"], "bounty": ["coin", "star"],
	"strength": ["sword", "plus"], "poison": ["drop", "cross"], "burn": ["flame", "clock"],
	"vulnerable": ["shield", "crack"], "next_extra": ["cards", "loop"], "next_double": ["sword", "double"],
	"next_bonus": ["sword", "up"], "heart_corrosion": ["heart", "crack"], "gold_burst": ["coin", "sword"],
	"more": ["more", ""], "unknown": ["star", ""],
	"hit": ["sword", ""], "fracture": ["shield", "crack"], "blast": ["star", "flame"], "frost": ["snow", ""],
	"move_left": ["arrow_left", ""], "move_right": ["arrow", ""], "return": ["loop", ""], "rotate": ["grid", "loop"],
	"cleanse": ["drop", "plus"], "lantern": ["lantern", ""], "unlock": ["shield", "arrow"],
	"intent_inject": ["cards", "drop"], "intent_buff": ["star", "up"], "intent_debuff": ["drop", "down"]
}


static func color_for(id: String, negative := false) -> Color:
	var key := id.trim_prefix("ability:")
	if negative or key in ["health", "heat", "hit", "blast", "strength", "poison", "burn", "vulnerable", "heart_corrosion"]:
		return Palette.VERMILION_DK
	if key in ["gold", "temp_funds", "equity", "bounty", "compound_equity", "joint_funding", "profit_share", "inject_bounty"]:
		return Palette.GOLD_DK
	return Palette.INK

var symbol := "unknown":
	set(value):
		symbol = value.trim_prefix("ability:")
		queue_redraw()
var ink := Color("40392e"):
	set(value):
		ink = value
		queue_redraw()
var level := -1.0:
	set(value):
		level = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _line(points: Array, color := Color.TRANSPARENT, width := 3.5) -> void:
	if color == Color.TRANSPARENT:
		color = ink
	var path := PackedVector2Array()
	for point in points:
		path.append(Vector2(point[0], point[1]))
	draw_polyline(path, color, width, true)


func _shape(points: Array, fill := true) -> void:
	var path := PackedVector2Array()
	for point in points:
		path.append(Vector2(point[0], point[1]))
	if fill:
		draw_colored_polygon(path, ink)
	else:
		path.append(path[0])
		draw_polyline(path, ink, 3.5, true)


func _circle(at: Vector2, radius: float, filled := false) -> void:
	if filled:
		draw_circle(at, radius, ink)
	else:
		draw_arc(at, radius, 0, TAU, 40, ink, 3.5, true)


func _draw() -> void:
	var scale_factor := minf(size.x, size.y) / 32.0
	draw_set_transform((size - Vector2.ONE * 32 * scale_factor) * 0.5, 0, Vector2.ONE * scale_factor)
	var spec: Array = SPECS.get(symbol, SPECS.unknown)
	# 带附记的图案主动留出右下角，使主形与小记共享一个构型。
	if not str(spec[1]).is_empty():
		draw_set_transform((size - Vector2.ONE * 32 * scale_factor) * 0.5, 0, Vector2.ONE * scale_factor * 0.80)
	_base(str(spec[0]))
	draw_set_transform((size - Vector2.ONE * 32 * scale_factor) * 0.5, 0, Vector2.ONE * scale_factor)
	if level >= 0.0:
		# 热量刻度围绕火焰，阈值清晰，过热时不依靠颜色单独传达。
		for index in 10:
			var angle := PI * 0.15 + index * PI * 0.075
			var a := Vector2(16, 14) + Vector2.from_angle(angle) * 14.0
			var b := Vector2(16, 14) + Vector2.from_angle(angle) * 16.0
			draw_line(a, b, ink if index < int(ceil(clampf(level, 0, 1) * 10)) else Color(ink, 0.22), 1.7, true)
	if not str(spec[1]).is_empty():
		_mark(str(spec[1]))


func _base(kind: String) -> void:
	match kind:
		"heart": _shape([[16, 27], [4, 16], [4, 10], [7, 6], [12, 6], [16, 10], [20, 6], [25, 6], [28, 10], [28, 16]], true)
		"flame":
			_shape([[17, 2], [22, 10], [21, 16], [27, 11], [28, 21], [24, 27], [18, 29], [20, 23], [16, 18], [12, 24], [14, 29], [7, 25], [4, 19], [9, 10], [10, 18], [14, 13]])
		"bolt": _shape([[18, 3], [7, 18], [14, 18], [12, 29], [26, 12], [18, 12]], true)
		"coin":
			# 四边形负形铜钱孔，留白是真透明，动效中也能直接叠在木面/墨灵上。
			for index in 32:
				var a := Vector2.from_angle(index * TAU / 32)
				var b := Vector2.from_angle((index + 1) * TAU / 32)
				var inner_a := a * (4.5 / maxf(absf(a.x), absf(a.y)))
				var inner_b := b * (4.5 / maxf(absf(b.x), absf(b.y)))
				draw_colored_polygon(PackedVector2Array([Vector2(16, 16) + a * 12, Vector2(16, 16) + b * 12, Vector2(16, 16) + inner_b, Vector2(16, 16) + inner_a]), ink)
		"shield":
			_shape([[4, 7], [14, 4], [14, 27], [6, 21]])
			_shape([[17, 4], [28, 7], [26, 21], [17, 29]])
		"armor":
			_shape([[10, 4], [13, 8], [19, 8], [22, 4], [28, 8], [28, 14], [24, 16], [8, 16], [4, 14], [4, 8]])
			_shape([[8, 19], [15, 19], [15, 27], [6, 27]])
			_shape([[18, 19], [24, 19], [26, 27], [18, 27]])
		"cards":
			_shape([[4, 7], [9, 5], [9, 24], [4, 26]])
			_shape([[12, 4], [28, 4], [28, 14], [12, 14]])
			_shape([[12, 17], [28, 17], [28, 28], [12, 28]])
		"drop":
			_shape([[16, 2], [26, 17], [27, 23], [23, 28], [17, 29], [10, 28], [5, 23], [6, 17], [12, 9], [10, 20], [13, 23], [16, 21], [17, 16]])
		"sword":
			_shape([[27, 2], [26, 10], [15, 21], [12, 18]])
			_shape([[8, 18], [15, 25], [12, 28], [5, 21]])
			_shape([[8, 24], [11, 27], [6, 31], [3, 28]])
		"snow":
			for index in 6:
				var d := Vector2.from_angle(index * PI / 3)
				var n := d.orthogonal()
				draw_colored_polygon(PackedVector2Array([Vector2(16, 16) + d * 4, Vector2(16, 16) + d * 8 + n * 2.5, Vector2(16, 16) + d * 14, Vector2(16, 16) + d * 8 - n * 2.5]), ink)
		"grid":
			for y in 2:
				for x in 2:
					draw_rect(Rect2(4 + x * 13, 4 + y * 13, 10, 10), ink)
		"wave":
			for row in 2:
				var y := row * 12
				_shape([[3, 10 + y], [10, 4 + y], [20, 8 + y], [29, 5 + y], [24, 12 + y], [13, 10 + y], [7, 15 + y]])
		"chain":
			_line([[13, 5], [8, 5], [4, 10], [5, 15], [10, 20], [15, 20], [19, 16]], ink, 4.5)
			_line([[19, 27], [24, 27], [28, 22], [27, 17], [22, 12], [17, 12], [13, 16]], ink, 4.5)
		"arrow":
			_shape([[3, 13], [17, 13], [17, 5], [29, 16], [17, 27], [17, 19], [3, 19]])
		"arrow_left":
			_shape([[29, 13], [15, 13], [15, 5], [3, 16], [15, 27], [15, 19], [29, 19]])
		"lantern":
			_shape([[11, 8], [14, 8], [14, 25], [10, 25], [5, 17]])
			_shape([[18, 8], [22, 8], [27, 17], [22, 25], [18, 25]])
			_line([[9, 4], [23, 4]])
			_line([[16, 27], [16, 31]])
		"chart":
			_shape([[5, 18], [11, 18], [11, 28], [5, 28]])
			_shape([[14, 12], [20, 12], [20, 28], [14, 28]])
			_shape([[23, 4], [29, 4], [29, 28], [23, 28]])
		"fork":
			_shape([[13, 29], [19, 29], [19, 18], [25, 12], [29, 16], [29, 3], [17, 3], [21, 7], [16, 12], [11, 7], [15, 3], [3, 3], [3, 16], [7, 12], [13, 18]])
		"loop":
			draw_arc(Vector2(16, 16), 10, -0.5, 4.5, 34, ink, 5.5, true)
			_shape([[10, 1], [18, 6], [10, 12]])
		"leaf":
			_shape([[5, 25], [5, 15], [11, 7], [28, 3], [23, 9], [12, 20]])
			_shape([[10, 27], [19, 27], [25, 21], [29, 8], [24, 13]])
			_line([[4, 29], [20, 13]], ink, 2.5)
		"hand":
			_shape([[4, 19], [10, 28], [21, 28], [28, 15], [27, 11], [24, 12], [21, 19], [19, 19], [19, 6], [15, 6], [13, 18], [9, 12], [5, 14], [10, 21]])
		"bag":
			_shape([[8, 3], [24, 3], [20, 9], [12, 9]])
			_shape([[12, 12], [20, 12], [26, 19], [27, 25], [22, 29], [9, 29], [5, 25], [6, 19]])
		"star": _shape([[16, 3], [19, 11], [28, 16], [19, 20], [16, 29], [12, 20], [4, 16], [12, 11]])
		"more":
			for x in [7, 16, 25]:
				_circle(Vector2(x, 16), 2.3, true)


func _mark(kind: String) -> void:
	match kind:
		"plus": _line([[20, 25], [30, 25]]); _line([[25, 20], [25, 30]])
		"minus": _line([[20, 25], [30, 25]])
		"cross": _line([[21, 21], [29, 29]]); _line([[29, 21], [21, 29]])
		"crack": _line([[27, 19], [23, 24], [27, 26], [22, 31]])
		"shield": _shape([[25, 19], [30, 21], [29, 27], [25, 31], [21, 27], [20, 21]])
		"lock": _shape([[21, 24], [29, 24], [29, 30], [21, 30]]); _line([[22, 24], [22, 20], [28, 20], [28, 24]])
		"clock": _circle(Vector2(25, 25), 5); _line([[25, 21], [25, 25], [28, 27]])
		"coin": _circle(Vector2(25, 25), 5); _shape([[23, 23], [27, 23], [27, 27], [23, 27]])
		"copy": _shape([[20, 20], [27, 20], [27, 27], [20, 27]]); _line([[29, 22], [29, 29], [22, 29]])
		"double": _line([[20, 21], [24, 25], [20, 29]]); _line([[26, 21], [30, 25], [26, 29]])
		"cards": _shape([[21, 20], [29, 20], [29, 30], [21, 30]]); _line([[24, 23], [27, 23]])
		"arrow": _line([[19, 25], [30, 25]]); _line([[25, 20], [30, 25], [25, 30]])
		"diagonal": _line([[20, 29], [29, 20], [29, 26]]); _line([[23, 20], [29, 20]])
		"down": _line([[25, 19], [25, 30]]); _line([[20, 25], [25, 30], [30, 25]])
		"up": _line([[25, 30], [25, 19]]); _line([[20, 24], [25, 19], [30, 24]])
		"bolt": _shape([[26, 19], [20, 26], [25, 26], [23, 31], [30, 23], [26, 23]], true)
		"flame": _shape([[25, 19], [30, 26], [28, 30], [22, 30], [20, 26]], true)
		"drop": _shape([[25, 18], [30, 26], [29, 30], [24, 31], [20, 28], [21, 24]])
		"star": _shape([[25, 19], [27, 23], [31, 25], [27, 27], [25, 31], [23, 27], [19, 25], [23, 23]])
		"sword": _line([[21, 29], [29, 20]], ink, 2.3); _line([[20, 25], [25, 30]])
		"return", "loop": draw_arc(Vector2(25, 25), 5, -0.7, 4.7, 20, ink, 2.8, true); _shape([[20, 18], [26, 20], [22, 24]])
		"stop": _circle(Vector2(25, 25), 5); _line([[21, 29], [29, 21]])
		"half": _circle(Vector2(25, 25), 5); _line([[25, 20], [25, 30]])
		"chain": _circle(Vector2(23, 23), 3); _circle(Vector2(27, 27), 3)
