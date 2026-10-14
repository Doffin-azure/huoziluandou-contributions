extends Control
class_name BattleSymbol
## 统一的刻印线条符号：无汉字、无字体依赖，基础轮廓与附记共同表达能力。
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
	"cleanse": ["drop", "plus"], "lantern": ["lantern", ""], "unlock": ["shield", "arrow"]
}
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


func _line(points: Array, color := Color.TRANSPARENT, width := 1.8) -> void:
	if color == Color.TRANSPARENT:
		color = ink
	var path := PackedVector2Array()
	for point in points:
		path.append(Vector2(point[0], point[1]))
	draw_polyline(path, color, width, true)


func _shape(points: Array, fill := false) -> void:
	var path := PackedVector2Array()
	for point in points:
		path.append(Vector2(point[0], point[1]))
	if fill:
		draw_colored_polygon(path, ink)
	else:
		path.append(path[0])
		draw_polyline(path, ink, 1.8, true)


func _circle(at: Vector2, radius: float, filled := false) -> void:
	if filled:
		draw_circle(at, radius, ink)
	else:
		draw_arc(at, radius, 0, TAU, 40, ink, 1.8, true)


func _draw() -> void:
	var scale_factor := minf(size.x, size.y) / 32.0
	draw_set_transform((size - Vector2.ONE * 32 * scale_factor) * 0.5, 0, Vector2.ONE * scale_factor)
	var spec: Array = SPECS.get(symbol, SPECS.unknown)
	_base(str(spec[0]))
	if level >= 0.0:
		# 热量刻度围绕火焰，阈值清晰，过热时不依靠颜色单独传达。
		for index in 10:
			var angle := PI * 0.15 + index * PI * 0.075
			var a := Vector2(16, 14) + Vector2.from_angle(angle) * 14.0
			var b := Vector2(16, 14) + Vector2.from_angle(angle) * 16.0
			draw_line(a, b, ink if index < int(ceil(clampf(level, 0, 1) * 10)) else Color(ink, 0.22), 1.7, true)
	if not str(spec[1]).is_empty():
		draw_circle(Vector2(25, 25), 7.0, Palette.PAPER)
		_mark(str(spec[1]))


func _base(kind: String) -> void:
	match kind:
		"heart": _shape([[16, 27], [4, 16], [4, 10], [7, 6], [12, 6], [16, 10], [20, 6], [25, 6], [28, 10], [28, 16]], true)
		"flame":
			_shape([[16, 3], [21, 10], [20, 14], [25, 10], [28, 19], [25, 26], [16, 29], [7, 25], [5, 19], [10, 10], [11, 16], [15, 12]], true)
			_line([[15, 23], [16, 17], [20, 23]], Palette.PAPER, 1.6)
		"bolt": _shape([[18, 3], [7, 18], [14, 18], [12, 29], [26, 12], [18, 12]], true)
		"coin":
			_circle(Vector2(16, 16), 12)
			_circle(Vector2(16, 16), 9)
			_shape([[12, 12], [20, 12], [20, 20], [12, 20]])
		"shield":
			_shape([[16, 4], [27, 8], [25, 21], [16, 28], [7, 21], [5, 8]])
			_line([[16, 8], [16, 23]])
		"armor":
			_shape([[11, 4], [7, 8], [4, 7], [4, 14], [8, 16], [7, 27], [25, 27], [24, 16], [28, 14], [28, 7], [25, 8], [21, 4], [20, 8], [12, 8]])
			_line([[10, 17], [22, 17]])
		"cards":
			_shape([[4, 7], [20, 4], [23, 24], [7, 27]])
			_shape([[10, 7], [27, 7], [27, 28], [10, 28]], true)
			_line([[14, 12], [23, 12]], Palette.PAPER)
			_line([[14, 17], [20, 17]], Palette.PAPER)
		"drop":
			_shape([[16, 3], [7, 16], [6, 22], [10, 27], [17, 28], [24, 24], [25, 18]])
			_line([[10, 20], [12, 24], [16, 25]])
		"sword":
			_shape([[22, 3], [28, 4], [27, 10], [13, 23], [9, 19]])
			_line([[6, 17], [16, 27]])
			_line([[11, 22], [5, 28]], ink, 3)
		"snow":
			for index in 3:
				var direction := Vector2.from_angle(index * PI / 3)
				draw_line(Vector2(16, 16) - direction * 12, Vector2(16, 16) + direction * 12, ink, 1.8, true)
			for index in 6:
				var d := Vector2.from_angle(index * PI / 3)
				var p := Vector2(16, 16) + d * 8
				draw_line(p, p - d.rotated(0.9) * 4, ink, 1.6, true)
		"grid":
			_shape([[5, 5], [26, 5], [26, 26], [5, 26]])
			_line([[5, 15], [26, 15]])
			_line([[15, 5], [15, 26]])
		"wave":
			for row in 3:
				_line([[4, 9 + row * 7], [9, 6 + row * 7], [15, 9 + row * 7], [21, 6 + row * 7], [28, 9 + row * 7]])
		"chain":
			_line([[15, 8], [11, 4], [5, 5], [3, 11], [12, 20], [18, 18], [20, 13]])
			_line([[17, 24], [21, 28], [27, 27], [29, 21], [20, 12], [14, 14], [12, 19]])
		"arrow":
			_line([[4, 16], [27, 16]])
			_line([[18, 7], [27, 16], [18, 25]])
		"arrow_left":
			_line([[28, 16], [5, 16]])
			_line([[14, 7], [5, 16], [14, 25]])
		"lantern":
			_shape([[9, 7], [23, 7], [27, 16], [23, 25], [9, 25], [5, 16]])
			_line([[10, 3], [22, 3]])
			_line([[16, 25], [16, 30]])
		"chart":
			_line([[5, 4], [5, 27], [28, 27]])
			_line([[9, 21], [15, 16], [19, 18], [26, 8]])
			_line([[20, 8], [26, 8], [26, 14]])
		"fork":
			_line([[16, 28], [16, 16], [7, 7]])
			_line([[16, 16], [25, 7]])
			_line([[7, 14], [7, 7], [14, 7]])
			_line([[18, 7], [25, 7], [25, 14]])
		"loop":
			draw_arc(Vector2(16, 16), 10, -0.8, 4.7, 34, ink, 1.8, true)
			_line([[12, 3], [16, 6], [12, 10]])
		"leaf":
			_shape([[6, 27], [5, 15], [11, 7], [27, 4], [25, 19], [18, 26]])
			_line([[6, 27], [22, 10]])
			_line([[12, 21], [12, 14]])
		"hand":
			_line([[4, 19], [9, 26], [21, 26], [28, 15], [26, 11], [23, 14], [20, 18], [18, 18], [19, 8], [16, 7], [13, 16], [9, 12], [6, 14], [10, 21]])
		"bag":
			_shape([[10, 4], [22, 4], [20, 10], [26, 17], [27, 24], [23, 28], [9, 28], [5, 24], [6, 17], [12, 10]])
			_line([[10, 10], [22, 10]])
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
		"star": _shape([[25, 19], [27, 23], [31, 25], [27, 27], [25, 31], [23, 27], [19, 25], [23, 23]])
		"sword": _line([[21, 29], [29, 20]], ink, 2.3); _line([[20, 25], [25, 30]])
		"return", "loop": draw_arc(Vector2(25, 25), 5, -0.7, 4.7, 20, ink, 1.8, true); _line([[21, 18], [25, 20], [23, 23]])
		"stop": _circle(Vector2(25, 25), 5); _line([[21, 29], [29, 21]])
		"half": _circle(Vector2(25, 25), 5); _line([[25, 20], [25, 30]])
		"chain": _circle(Vector2(23, 23), 3); _circle(Vector2(27, 27), 3)
