extends RefCounted
## The second relic collection: individual objects, with no display bases.
const FONT := preload("res://assets/fonts/LXGWWenKai-Regular.ttf")


static func build(w, m: Dictionary, id: String) -> void:
	match id:
		"empty_case": _case(w, m)
		"stay_wax": _wax(w, m)
		"amber": _amber(w, m)
		"ghost_hand": _hand(w, m)
		"cracked_bottle": _bottle(w, m, false)
		"rotting_fruit": _fruit(w, m)
		"chaos_dice": _dice(w, m)
		"black_water": _bottle(w, m, true)
		"life_lantern": _lantern(w, m)
		"life_debt": _contract(w, m)
		"chain": _chain(w, m)
		"question": _question(w, m)
		"goldleaf": _goldleaf(w, m)
		"moon": _moon(w, m)
		"slot": _stones(w, m)
		"death": _brush(w, m)
		"ruin": _book(w, m)
		"rubbing": _doll(w, m)
		"midas": _robe(w, m)
		"monkey": _petition(w, m)
		"palindrome": _mirror(w, m)
		"binding": _rope(w, m)
		"proof": _ruler(w, m)


static func _glyph(w, text: String, at: Vector3, size: float, material: Material, rotation := Vector3.ZERO) -> void:
	var mesh := TextMesh.new()
	mesh.font = FONT
	mesh.text = text
	mesh.font_size = 64
	mesh.pixel_size = size / 64.0
	mesh.depth = 0.007
	w.add(mesh, material, Transform3D(Basis.from_euler(rotation), at), "RelicInscription")


static func _path(w, points: Array, radius: float, material: Material) -> void:
	for i in range(1, points.size()):
		w.rod(points[i - 1], points[i], radius, material)
	for p in points: w.orb(p, Vector3.ONE * radius * 1.95, material)


static func _tassel(w, at: Vector3, m: Dictionary, length := 0.28) -> void:
	w.orb(at, Vector3(0.10, 0.08, 0.08), m.red)
	w.ring(at, 0.047, 0.012, m.edge)
	for i in 9:
		var angle := TAU * i / 9.0
		var d := Vector3(cos(angle), 0, sin(angle))
		_path(w, [at + d * 0.025, at + d * 0.04 + Vector3(0, -length * 0.5, 0), at + d * 0.07 + Vector3(0.025, -length, 0)], 0.009, m.red)


static func _case(w, m: Dictionary) -> void:
	# The dark open cavity and divided type slots distinguish the empty lead case.
	w.rounded(Vector3(0, 0.08, 0), Vector3(1.02, 0.13, 0.68), 0.035, m.dark)
	for x in [-0.48, 0.48]: w.rounded(Vector3(x, 0.22, 0), Vector3(0.07, 0.29, 0.68), 0.018, m.silver)
	for z in [-0.31, 0.31]: w.rounded(Vector3(0, 0.22, z), Vector3(0.98, 0.29, 0.065), 0.015, m.silver)
	for x in [-0.23, 0.0, 0.23]: w.rounded(Vector3(x, 0.17, 0), Vector3(0.022, 0.15, 0.56), 0.005, m.bronze)
	w.rounded(Vector3(0, 0.64, -0.39), Vector3(1.01, 0.64, 0.065), 0.028, m.dark, Vector3(-0.15, 0, 0))
	for x in [-0.43, 0.43]: w.rod(Vector3(x, 0.38, -0.31), Vector3(x, 0.90, -0.39), 0.013, m.silver)
	for y in [0.39, 0.89]: w.rod(Vector3(-0.43, y, -0.34), Vector3(0.43, y, -0.34), 0.014, m.silver)
	for x in [-0.3, 0.3]: w.ring(Vector3(x, 0.35, -0.31), 0.045, 0.018, m.bronze, Vector3(0, 0, PI / 2))
	w.rounded(Vector3(0, 0.26, 0.355), Vector3(0.16, 0.16, 0.03), 0.018, m.bronze)
	_glyph(w, "空", Vector3(0, 0.64, -0.335), 0.28, m.silver)
	for x in [-0.42, 0.42]:
		for y in [0.12, 0.30]: w.orb(Vector3(x, y, 0.35), Vector3.ONE * 0.038, m.edge)


static func _wax(w, m: Dictionary) -> void:
	w.lathe([Vector2(0, 0.025), Vector2(0.32, 0.025), Vector2(0.39, 0.07), Vector2(0.36, 0.17), Vector2(0.30, 0.26), Vector2(0.26, 0.29), Vector2(0, 0.29)], m.red)
	for i in 11:
		var a := TAU * i / 11.0
		w.orb(Vector3(cos(a) * 0.30, 0.065, sin(a) * 0.30), Vector3(0.20, 0.10, 0.18), m.red)
	w.lathe([Vector2(0, 0.26), Vector2(0.18, 0.26), Vector2(0.19, 0.40), Vector2(0.13, 0.44), Vector2(0.06, 0.42), Vector2(0, 0.42)], m.red)
	w.rod(Vector3(0.015, 0.42, 0), Vector3(-0.018, 0.52, 0.005), 0.016, m.dark)
	w.ring(Vector3(0.02, 0.19, 0.25), 0.13, 0.012, m.edge, Vector3(PI / 2, 0, 0))
	_glyph(w, "留", Vector3(0.02, 0.14, 0.29), 0.18, m.edge)
	_path(w, [Vector3(-0.3, 0.13, 0.20), Vector3(-0.42, 0.11, 0.28), Vector3(-0.50, 0.07, 0.24)], 0.026, m.red)


static func _amber(w, m: Dictionary) -> void:
	w.orb(Vector3(0, 0.50, 0), Vector3(0.71, 0.93, 0.40), m.amber, Vector3(0, 0, -0.17))
	w.orb(Vector3(-0.07, 0.74, 0.11), Vector3(0.25, 0.35, 0.12), m.flame, Vector3(0, 0, -0.35))
	# A trapped cicada on the polished face, with six legs and veined wings.
	w.orb(Vector3(0.025, 0.48, 0.201), Vector3(0.085, 0.24, 0.025), m.dark, Vector3(0, 0, -0.20))
	for side in [-1.0, 1.0]:
		w.leaf(Vector3(0.02, 0.56, 0.206), Vector3(side * 0.18, 0.38, 0.20), 0.075, m.bronze, m.dark)
		for i in 3: _path(w, [Vector3(0.02, 0.52 - i * 0.05, 0.215), Vector3(side * 0.10, 0.49 - i * 0.055, 0.22), Vector3(side * 0.15, 0.53 - i * 0.075, 0.215)], 0.007, m.dark)
		_path(w, [Vector3(side * 0.19, 0.11, 0), Vector3(side * 0.29, 0.25, 0.13), Vector3(side * 0.29, 0.43, 0.10)], 0.021, m.bronze)
	w.ring(Vector3(-0.06, 1.00, 0), 0.075, 0.018, m.edge, Vector3(PI / 2, 0, 0))


static func _hand(w, m: Dictionary) -> void:
	w.rounded(Vector3(0, 0.18, 0), Vector3(0.34, 0.30, 0.22), 0.05, m.jade)
	w.ring(Vector3(0, 0.13, 0), 0.19, 0.022, m.bronze)
	w.orb(Vector3(0, 0.49, 0), Vector3(0.39, 0.42, 0.16), m.bone)
	for i in 4:
		var x := -0.15 + i * 0.10
		var h: float = [0.28, 0.40, 0.43, 0.34][i]
		var points := [Vector3(x, 0.48, 0.045), Vector3(x * 1.12, 0.70, 0.01), Vector3(x * 1.25, 0.70 + h * 0.6, 0.07), Vector3(x * 1.18, 0.70 + h, 0.18)]
		for j in range(1, points.size()):
			w.rod(points[j - 1], points[j], 0.027 if j < 3 else 0.022, m.bone)
			w.orb(points[j - 1], Vector3.ONE * 0.072, m.bone)
		w.orb(points[3], Vector3(0.04, 0.08, 0.024), m.dark, Vector3(0.3, 0, 0))
	_path(w, [Vector3(-0.13, 0.42, 0), Vector3(-0.31, 0.54, 0.03), Vector3(-0.39, 0.72, 0.13), Vector3(-0.29, 0.82, 0.20)], 0.035, m.bone)
	for i in 4: w.rod(Vector3(-0.12 + i * 0.075, 0.34, 0.079), Vector3(-0.14 + i * 0.09, 0.61, 0.079), 0.012, m.dark)
	_glyph(w, "补", Vector3(0, 0.15, 0.125), 0.14, m.edge)


static func _bottle(w, m: Dictionary, black: bool) -> void:
	var glaze: Material = m.dark if black else m.jade
	var profile := [Vector2(0, 0.03), Vector2(0.22, 0.03), Vector2(0.32, 0.13), Vector2(0.35, 0.35), Vector2(0.29, 0.58), Vector2(0.17, 0.72), Vector2(0.12, 0.84), Vector2(0.12, 1.0), Vector2(0.16, 1.0), Vector2(0.16, 1.06), Vector2(0.10, 1.08), Vector2(0.08, 1.0)]
	if black:
		profile = [Vector2(0, 0.025), Vector2(0.19, 0.025), Vector2(0.32, 0.16), Vector2(0.34, 0.34), Vector2(0.26, 0.49), Vector2(0.13, 0.56), Vector2(0.24, 0.69), Vector2(0.25, 0.83), Vector2(0.14, 0.96), Vector2(0.10, 1.06), Vector2(0.10, 1.12), Vector2(0, 1.12)]
	w.lathe(profile, glaze)
	if black:
		w.rounded(Vector3(0, 1.13, 0), Vector3(0.18, 0.14, 0.18), 0.025, m.wood)
		for y in [0.54, 0.575]: w.ring(Vector3(0, y, 0), 0.15, 0.016, m.red)
		_path(w, [Vector3(0.12, 0.57, 0.07), Vector3(0.25, 0.47, 0.26), Vector3(0.20, 0.24, 0.32)], 0.016, m.red)
		_glyph(w, "幽", Vector3(0, 0.26, 0.343), 0.22, m.silver)
		_tassel(w, Vector3(0.21, 0.28, 0.32), m, 0.18)
	else:
		for y in [0.08, 0.68, 1.04]: w.ring(Vector3(0, y, 0), 0.27 if y < 0.1 else 0.18 if y < 0.8 else 0.15, 0.014, m.bronze)
		_path(w, [Vector3(-0.08, 0.85, 0.135), Vector3(-0.02, 0.65, 0.23), Vector3(-0.15, 0.48, 0.31), Vector3(0.04, 0.29, 0.35), Vector3(-0.06, 0.10, 0.28)], 0.012, m.dark)
		_path(w, [Vector3(-0.15, 0.48, 0.31), Vector3(-0.26, 0.41, 0.26), Vector3(-0.23, 0.26, 0.27)], 0.009, m.dark)
		_path(w, [Vector3(0.04, 0.29, 0.35), Vector3(0.21, 0.40, 0.29), Vector3(0.27, 0.54, 0.21)], 0.009, m.dark)
		_glyph(w, "雷", Vector3(0.12, 0.48, 0.32), 0.17, m.edge)


static func _fruit(w, m: Dictionary) -> void:
	for side in [-1.0, 1.0]: w.orb(Vector3(side * 0.11, 0.38, 0), Vector3(0.58, 0.66, 0.60), m.amber, Vector3(0, 0, side * -0.17))
	_path(w, [Vector3(0, 0.65, 0), Vector3(0.01, 0.81, -0.035), Vector3(-0.09, 0.87, -0.07)], 0.027, m.wood)
	w.leaf(Vector3(0, 0.78, 0), Vector3(0.38, 0.86, -0.09), 0.16, m.jade, m.edge)
	for i in 13:
		var a := i * 2.39996
		var r := sqrt(float(i) / 13.0) * 0.15
		w.orb(Vector3(-0.13 + cos(a) * r, 0.38 + sin(a) * r, 0.275), Vector3(0.11, 0.10, 0.025), m.dark if i % 3 else m.stone)
	for i in 5: w.orb(Vector3(-0.20 + i * 0.045, 0.29 + (i % 2) * 0.09, 0.30), Vector3(0.035, 0.035, 0.025), m.cloth)
	_path(w, [Vector3(0, 0.17, 0.22), Vector3(0.025, 0.37, 0.31), Vector3(0, 0.63, 0.15)], 0.008, m.red)


static func _dice(w, m: Dictionary) -> void:
	var centers := [Vector3(-0.27, 0.25, 0.12), Vector3(0.26, 0.25, -0.09), Vector3(0.04, 0.72, -0.04)]
	var angles := [Vector3(0, -0.2, 0), Vector3(0, 0.32, 0), Vector3(0.08, -0.15, -0.08)]
	for i in 3:
		var c: Vector3 = centers[i]
		var basis := Basis.from_euler(angles[i])
		w.rounded(c, Vector3.ONE * 0.47, 0.045, m.bone, angles[i])
		_glyph(w, ["乱", "文", "命"][i], c + basis * Vector3(0, -0.065, 0.24), 0.23, m.red, angles[i])
		for x in [-0.11, 0.11]:
			for z in [-0.11, 0.11]: w.orb(c + basis * Vector3(x, 0.235, z), Vector3(0.055, 0.012, 0.055), m.dark)
		w.orb(c + basis * Vector3(0.238, 0, 0), Vector3(0.012, 0.075, 0.075), m.red)


static func _lantern(w, m: Dictionary) -> void:
	w.lathe([Vector2(0, 0.04), Vector2(0.30, 0.04), Vector2(0.34, 0.10), Vector2(0.29, 0.17), Vector2(0, 0.17)], m.bronze)
	for i in 6:
		var a := TAU * i / 6.0
		var p := Vector3(cos(a) * 0.29, 0, sin(a) * 0.29)
		w.rod(p + Vector3.UP * 0.12, p + Vector3.UP * 0.86, 0.022, m.dark)
		w.orb(p + Vector3.UP * 0.15, Vector3.ONE * 0.055, m.edge)
		# Rear panels leave the flame visible through the open front.
		if sin(a) < 0.1:
			w.rounded(p * 0.86 + Vector3.UP * 0.49, Vector3(0.24, 0.58, 0.015), 0.015, m.paper, Vector3(0, -a + PI / 2, 0))
	for y in [0.19, 0.80]: w.ring(Vector3(0, y, 0), 0.285, 0.022, m.bronze)
	w.lathe([Vector2(0.35, 0.84), Vector2(0.37, 0.88), Vector2(0.28, 0.94), Vector2(0.20, 1.03), Vector2(0.07, 1.07), Vector2(0, 1.12)], m.jade)
	for i in 12:
		var a := i * TAU / 12
		w.rod(Vector3(cos(a) * 0.35, 0.89, sin(a) * 0.35), Vector3(cos(a) * 0.09, 1.065, sin(a) * 0.09), 0.007, m.edge)
	w.ring(Vector3(0, 1.23, 0), 0.16, 0.021, m.bronze, Vector3(PI / 2, 0, 0))
	w.tongue(Vector3(0, 0.22, 0), 0.47, 0.17, 0.07, m.flame)
	w.tongue(Vector3(0, 0.22, 0.02), 0.25, 0.075, -0.025, m.paper)
	w.rounded(Vector3(0, 0.72, 0.29), Vector3(0.21, 0.16, 0.015), 0.015, m.red)
	_glyph(w, "命", Vector3(0, 0.66, 0.305), 0.14, m.edge)


static func _contract(w, m: Dictionary) -> void:
	w.rounded(Vector3(0, 0.075, 0), Vector3(0.88, 0.022, 0.94), 0.012, m.paper, Vector3(0.10, 0, -0.04))
	for x in [-0.45, 0.45]:
		w.lathe([Vector2(0, -0.46), Vector2(0.075, -0.46), Vector2(0.075, 0.46), Vector2(0, 0.46)], m.paper, Vector3(x, 0.12, 0), Vector3(PI / 2, 0, 0))
		for z in [-0.47, 0.47]: w.orb(Vector3(x, 0.12, z), Vector3(0.10, 0.10, 0.035), m.wood)
	_glyph(w, "寿契", Vector3(0, 0.12, -0.23), 0.22, m.dark, Vector3(-PI / 2, 0, 0))
	for i in 7:
		var z := -0.07 + i * 0.06
		w.rod(Vector3(-0.27, 0.115, z), Vector3(0.25 - (i % 3) * 0.08, 0.115, z), 0.004, m.dark)
	w.orb(Vector3(0.24, 0.13, 0.30), Vector3(0.17, 0.012, 0.23), m.red, Vector3(0, -0.3, 0))
	for i in 6: w.ring(Vector3(0.24, 0.14, 0.30), 0.014 + i * 0.010, 0.002, m.paper)
	_path(w, [Vector3(-0.43, 0.20, -0.12), Vector3(-0.52, 0.18, 0.23), Vector3(-0.39, 0.09, 0.53)], 0.012, m.red)


static func _chain(w, m: Dictionary) -> void:
	for i in 9:
		var x := (i - 4) * 0.145
		var y := 0.22 + 0.12 * sin(i * 0.65)
		w.ring(Vector3(x, y, 0.06 * cos(i * 0.8)), 0.13, 0.018, m.silver if i % 3 else m.bronze, Vector3(PI / 2 if i % 2 == 0 else PI / 7, 0, i * 0.08))
	_path(w, [Vector3(-0.74, 0.23, 0.06), Vector3(-0.84, 0.36, 0.06), Vector3(-0.81, 0.47, 0.06)], 0.028, m.bronze)
	w.rounded(Vector3(0.74, 0.20, 0), Vector3(0.19, 0.20, 0.08), 0.024, m.jade)
	_glyph(w, "九", Vector3(0.74, 0.14, 0.05), 0.14, m.edge)


static func _question(w, m: Dictionary) -> void:
	w.lathe([Vector2(0, 0.02), Vector2(0.24, 0.02), Vector2(0.27, 0.08), Vector2(0.28, 0.61), Vector2(0.29, 0.64), Vector2(0.23, 0.64), Vector2(0.22, 0.18)], m.wood)
	for i in 20:
		var a := i * TAU / 20
		w.rod(Vector3(cos(a) * 0.265, 0.09, sin(a) * 0.265), Vector3(cos(a) * 0.28, 0.61, sin(a) * 0.28), 0.008, m.bronze)
	for y in [0.12, 0.54, 0.62]: w.ring(Vector3(0, y, 0), 0.28, 0.014, m.red)
	for i in 5:
		var x := (i - 2) * 0.086
		var y := 0.85 + (i % 3) * 0.08
		var angle := (2 - i) * 0.10
		w.rounded(Vector3(x, y, -0.07), Vector3(0.072, 0.86, 0.035), 0.012, m.paper, Vector3(0, 0, angle))
		w.orb(Vector3(x * 1.5, y + 0.31, -0.043), Vector3(0.026, 0.035, 0.01), m.red)
	_glyph(w, "问冥", Vector3(0, 0.26, 0.29), 0.21, m.edge)


static func _goldleaf(w, m: Dictionary) -> void:
	for i in 5:
		w.cloth_surface(Vector3(i * 0.018, 0.055 + i * 0.025, 0), 0.86, 0.72, m.edge if i % 2 == 0 else m.paper)
	for i in 9:
		var x := -0.35 + i * 0.078
		_path(w, [Vector3(x, 0.19, -0.28), Vector3(x + 0.025, 0.18, 0.03), Vector3(x - 0.02, 0.19, 0.29)], 0.0025, m.bronze)
	w.silhouette(PackedVector2Array([Vector2(0.18, 0.19), Vector2(0.50, 0.20), Vector2(0.39, 0.46), Vector2(0.28, 0.37)]), 0.012, m.edge, Vector3(0, 0, 0.23))
	w.rounded(Vector3(-0.24, 0.195, 0.11), Vector3(0.22, 0.013, 0.24), 0.015, m.red)
	_glyph(w, "金", Vector3(-0.24, 0.205, 0.11), 0.17, m.edge, Vector3(-PI / 2, 0, 0))


static func _moon(w, m: Dictionary) -> void:
	var outline := PackedVector2Array()
	for i in 49:
		var a := deg_to_rad(68.0 + i * 224.0 / 48)
		outline.append(Vector2(cos(a) * 0.47, 0.57 + sin(a) * 0.47))
	var end := outline[-1]
	var start := outline[0]
	for i in range(1, 33):
		var t := i / 32.0
		outline.append((1 - t) * (1 - t) * end + 2 * (1 - t) * t * Vector2(-0.44, 0.57) + t * t * start)
	w.silhouette(outline, 0.09, m.jade)
	for i in range(1, 48):
		w.rod(Vector3(outline[i - 1].x, outline[i - 1].y, 0.052), Vector3(outline[i].x, outline[i].y, 0.052), 0.012, m.silver)
	w.ring(Vector3(0.16, 1.06, 0), 0.06, 0.014, m.bronze, Vector3(PI / 2, 0, 0))
	_path(w, [Vector3(0.16, 1.09, 0), Vector3(0.30, 1.21, 0.02), Vector3(0.44, 1.09, 0.04), Vector3(0.35, 0.86, 0.05)], 0.012, m.red)
	_tassel(w, Vector3(0.35, 0.87, 0.05), m, 0.24)
	for i in 5: w.orb(Vector3(-0.29 - 0.04 * sin(i), 0.33 + i * 0.11, 0.054), Vector3.ONE * 0.027, m.edge)


static func _stones(w, m: Dictionary) -> void:
	for i in 3:
		var x := (i - 1) * 0.37
		var height: float = [0.52, 0.77, 0.61][i]
		w.rounded(Vector3(x, height * 0.5, 0), Vector3(0.35, height, 0.39), 0.10, m.stone, Vector3(0, (i - 1) * 0.15, (i - 1) * -0.07))
		_glyph(w, "生", Vector3(x, height * 0.48, 0.205), 0.23, m.edge)
		for j in 3: w.rod(Vector3(x - 0.09, 0.12 + j * 0.07, 0.20), Vector3(x - 0.03 + (j % 2) * 0.08, 0.13 + j * 0.07, 0.20), 0.004, m.dark)
	w.leaf(Vector3(-0.31, 0.08, 0.20), Vector3(-0.47, 0.24, 0.19), 0.06, m.jade, m.bronze)


static func _brush(w, m: Dictionary) -> void:
	w.lathe([Vector2(0, 0.05), Vector2(0.075, 0.16), Vector2(0.095, 0.29), Vector2(0.075, 0.42), Vector2(0, 0.42)], m.dark)
	w.lathe([Vector2(0, 0.37), Vector2(0.085, 0.37), Vector2(0.085, 0.51), Vector2(0.043, 0.55), Vector2(0.043, 1.40), Vector2(0.065, 1.43), Vector2(0.065, 1.49), Vector2(0, 1.49)], m.wood)
	for y in [0.40, 0.48, 0.58, 1.30, 1.43]: w.ring(Vector3(0, y, 0), 0.087 if y < 0.52 else 0.048, 0.012, m.bronze)
	for i in 16:
		var a := i * TAU / 16
		_path(w, [Vector3(cos(a) * 0.076, 0.38, sin(a) * 0.076), Vector3(cos(a) * 0.065, 0.21, sin(a) * 0.065), Vector3(0.012, 0.05, 0.01)], 0.004, m.silver)
	_glyph(w, "判", Vector3(0, 0.91, 0.049), 0.10, m.edge)
	w.ring(Vector3(0, 1.53, 0), 0.045, 0.01, m.bronze, Vector3(PI / 2, 0, 0))
	_path(w, [Vector3(0, 1.56, 0), Vector3(0.16, 1.52, 0.02), Vector3(0.21, 1.32, 0.04)], 0.012, m.red)
	_tassel(w, Vector3(0.21, 1.34, 0.04), m)


static func _book(w, m: Dictionary) -> void:
	w.rounded(Vector3(0, 0.55, 0), Vector3(0.79, 1.05, 0.19), 0.018, m.paper)
	for z in [-0.115, 0.115]: w.rounded(Vector3(0, 0.55, z), Vector3(0.85, 1.11, 0.04), 0.018, m.dark)
	w.rounded(Vector3(-0.36, 0.55, 0), Vector3(0.12, 1.12, 0.27), 0.024, m.red)
	for y in [0.15, 0.36, 0.57, 0.78, 0.99]:
		w.rod(Vector3(-0.40, y, 0.14), Vector3(-0.27, y + 0.035, 0.14), 0.012, m.paper)
	for i in 14: w.rod(Vector3(0.397, 0.07 + i * 0.074, -0.085), Vector3(0.397, 0.07 + i * 0.074, 0.08), 0.003, m.wood)
	for x in [-0.20, 0.34]:
		for y in [0.06, 1.04]:
			w.rod(Vector3(x - 0.035, y, 0.145), Vector3(x + 0.035, y, 0.145), 0.016, m.edge)
			w.rod(Vector3(x, y - 0.035, 0.145), Vector3(x, y + 0.035, 0.145), 0.016, m.edge)
	w.rounded(Vector3(0.15, 0.67, 0.144), Vector3(0.24, 0.69, 0.012), 0.006, m.paper)
	for i in 3: _glyph(w, ["生", "死", "簿"][i], Vector3(0.15, 0.80 - i * 0.21, 0.156), 0.19, m.dark)
	w.rounded(Vector3(0.32, 0.40, 0.148), Vector3(0.20, 0.13, 0.03), 0.015, m.bronze)


static func _doll(w, m: Dictionary) -> void:
	var limbs := [[Vector3(0, 0.45, 0), Vector3(0, 0.87, 0), 0.09], [Vector3(-0.10, 0.73, 0), Vector3(-0.40, 0.87, 0.02), 0.05], [Vector3(0.10, 0.73, 0), Vector3(0.40, 0.87, 0.02), 0.05], [Vector3(-0.06, 0.46, 0), Vector3(-0.23, 0.10, 0.04), 0.055], [Vector3(0.06, 0.46, 0), Vector3(0.23, 0.10, 0.04), 0.055]]
	for limb in limbs:
		for i in 11:
			var a := i * TAU / 11
			var d := Vector3(cos(a), 0, sin(a)) * float(limb[2])
			w.rod(limb[0] + d, limb[1] + d * 1.25, 0.013, m.paper if i % 3 else m.wood)
	w.orb(Vector3(0, 1.02, 0), Vector3(0.23, 0.27, 0.20), m.paper)
	for i in 9: w.ring(Vector3(0, 0.91 + i * 0.022, 0), 0.065 + sin(i * PI / 9) * 0.045, 0.007, m.wood)
	for y in [0.49, 0.55, 0.78, 0.84]: w.ring(Vector3(0, y, 0), 0.10, 0.013, m.red)
	_path(w, [Vector3(-0.095, 0.84, 0.09), Vector3(0.09, 0.53, 0.10), Vector3(-0.09, 0.53, 0.10), Vector3(0.095, 0.84, 0.09)], 0.012, m.red)
	w.rounded(Vector3(0, 0.67, 0.12), Vector3(0.13, 0.25, 0.015), 0.01, m.paper)
	_glyph(w, "替", Vector3(0, 0.62, 0.134), 0.12, m.red)
	w.rod(Vector3(0.025, 0.73, 0.13), Vector3(0.20, 0.81, 0.30), 0.009, m.dark)
	w.orb(Vector3(0.20, 0.81, 0.30), Vector3.ONE * 0.055, m.red)


static func _robe(w, m: Dictionary) -> void:
	var outline := PackedVector2Array([Vector2(-0.33, 0.02), Vector2(0.33, 0.02), Vector2(0.26, 0.64), Vector2(0.55, 0.47), Vector2(0.69, 0.77), Vector2(0.27, 1.04), Vector2(0.13, 1.06), Vector2(0, 0.86), Vector2(-0.13, 1.06), Vector2(-0.27, 1.04), Vector2(-0.69, 0.77), Vector2(-0.55, 0.47), Vector2(-0.26, 0.64)])
	w.silhouette(outline, 0.14, m.bronze)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		w.rod(Vector3(a.x, a.y, 0.075), Vector3(b.x, b.y, 0.075), 0.017, m.edge)
	for row in 8:
		for col in 5:
			var x := (col - 2) * 0.11 + (row % 2) * 0.025
			var y := 0.10 + row * 0.10
			w.ring(Vector3(x, y, 0.079), 0.039, 0.007, m.edge, Vector3(PI / 2, 0, 0))
	_path(w, [Vector3(-0.12, 1.03, 0.083), Vector3(0.14, 0.66, 0.086), Vector3(0.16, 0.15, 0.086)], 0.016, m.dark)
	w.rounded(Vector3(0, 0.53, 0.105), Vector3(0.56, 0.09, 0.035), 0.012, m.red)
	w.rounded(Vector3(0.025, 0.53, 0.128), Vector3(0.13, 0.11, 0.02), 0.015, m.edge)
	_tassel(w, Vector3(0.23, 0.51, 0.14), m, 0.29)


static func _petition(w, m: Dictionary) -> void:
	for i in 3: w.rounded(Vector3(i * 0.018, 0.58, -i * 0.014), Vector3(0.58, 1.08, 0.018), 0.008, m.paper, Vector3(0, 0, i * -0.025))
	for y in [0.12, 1.08]: w.rod(Vector3(-0.32, y, -0.045), Vector3(0.34, y, -0.045), 0.025, m.wood)
	for y in [0.25, 0.46, 0.68, 0.90]: w.rod(Vector3(-0.23, y, 0.018), Vector3(0.23, y, 0.018), 0.004, m.red)
	for i in 3: _glyph(w, ["阴", "司", "愿"][i], Vector3(0, 0.87 - i * 0.23, 0.025), 0.22, m.dark)
	w.rounded(Vector3(0.18, 0.22, 0.025), Vector3(0.17, 0.17, 0.015), 0.006, m.red, Vector3(0, 0, -0.17))
	_glyph(w, "允", Vector3(0.18, 0.17, 0.04), 0.13, m.edge)
	_path(w, [Vector3(-0.29, 1.07, 0.02), Vector3(0, 1.28, 0.01), Vector3(0.29, 1.07, 0.02)], 0.012, m.red)
	_tassel(w, Vector3(-0.26, 0.36, 0.04), m, 0.24)


static func _mirror(w, m: Dictionary) -> void:
	w.lathe([Vector2(0, -0.04), Vector2(0.37, -0.04), Vector2(0.41, 0), Vector2(0.38, 0.05), Vector2(0, 0.05)], m.bronze, Vector3(0, 0.78, 0), Vector3(PI / 2, 0, 0))
	w.lathe([Vector2(0, 0), Vector2(0.33, 0), Vector2(0.33, 0.016), Vector2(0, 0.016)], m.silver, Vector3(0, 0.78, 0.052), Vector3(PI / 2, 0, 0))
	w.ring(Vector3(0, 0.78, 0.064), 0.36, 0.018, m.edge, Vector3(PI / 2, 0, 0))
	var yin := PackedVector2Array()
	for i in 25:
		var a := PI / 2 + i * PI / 24
		yin.append(Vector2(cos(a) * 0.29, 0.78 + sin(a) * 0.29))
	for i in 33:
		var t := i / 32.0
		yin.append(Vector2(sin(t * TAU) * 0.145, 0.49 + t * 0.58))
	w.silhouette(yin, 0.008, m.dark, Vector3(0, 0, 0.075))
	w.orb(Vector3(0, 0.925, 0.088), Vector3(0.075, 0.075, 0.012), m.dark)
	w.orb(Vector3(0, 0.635, 0.088), Vector3(0.075, 0.075, 0.012), m.silver)
	for i in 16:
		var a := i * TAU / 16
		w.orb(Vector3(cos(a) * 0.385, 0.78 + sin(a) * 0.385, 0.055), Vector3.ONE * 0.026, m.edge)
	w.rounded(Vector3(0, 0.25, 0), Vector3(0.13, 0.47, 0.12), 0.035, m.jade)
	for y in [0.09, 0.17, 0.25, 0.33]: w.ring(Vector3(0, y, 0), 0.071, 0.012, m.bronze)
	w.ring(Vector3(0, 0.035, 0), 0.045, 0.012, m.edge, Vector3(PI / 2, 0, 0))
	_tassel(w, Vector3(0, 0.01, 0), m, 0.25)


static func _rope(w, m: Dictionary) -> void:
	# Two braided strands trace an actual spatial figure-eight knot.
	for strand in 2:
		var points: Array = []
		for i in 161:
			var t := i * TAU / 160
			var center := Vector3(sin(t) * 0.43, 0.62 + sin(t * 2) * 0.38, cos(t * 2) * 0.09)
			var offset := Vector3(cos(t * 20 + strand * PI), sin(t * 20 + strand * PI), 0) * 0.012
			points.append(center + offset)
		_path(w, points, 0.018, m.red if strand == 0 else m.bronze)
	for side in [-1.0, 1.0]:
		_path(w, [Vector3(0, 0.61, 0.12), Vector3(side * 0.20, 0.35, 0.13), Vector3(side * 0.25, 0.26, 0.13)], 0.025, m.red)
		_tassel(w, Vector3(side * 0.25, 0.27, 0.13), m, 0.24)
	w.orb(Vector3(0, 0.61, 0.135), Vector3(0.13, 0.10, 0.055), m.jade)


static func _ruler(w, m: Dictionary) -> void:
	w.rounded(Vector3(0, 0.65, 0), Vector3(0.25, 1.21, 0.08), 0.025, m.jade)
	for y in [0.08, 1.22]: w.rounded(Vector3(0, y, 0), Vector3(0.26, 0.09, 0.095), 0.016, m.bronze)
	for i in 19:
		var y := 0.17 + i * 0.05
		w.rod(Vector3(-0.11, y, 0.046), Vector3(-0.02 if i % 5 == 0 else -0.055, y, 0.046), 0.005, m.edge)
	for i in 2: _glyph(w, ["辟", "邪"][i], Vector3(0.025, 0.75 - i * 0.24, 0.05), 0.17, m.edge)
	w.ring(Vector3(0, 1.31, 0), 0.06, 0.013, m.bronze, Vector3(PI / 2, 0, 0))
	_path(w, [Vector3(0, 1.35, 0), Vector3(0.23, 1.34, 0), Vector3(0.29, 1.15, 0.03)], 0.012, m.red)
	_tassel(w, Vector3(0.29, 1.17, 0.03), m, 0.34)
