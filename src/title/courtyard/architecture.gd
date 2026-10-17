extends Node3D
const Workshop := preload("res://src/title/courtyard/mesh_workshop.gd")
const Materials := preload("res://src/title/courtyard/material_library.gd")
var model := Workshop.new()
var palette := Materials.new()


func _ready() -> void:
	_ground()
	_hall(Vector3(-1.0, 0.46, -15.0), 8.4, 5.4, 3.8)
	_hall(Vector3(-8.5, 0.46, -4.7), 4.3, 4.6, 3.25, true)
	_right_wing()
	_entrance()
	_bridge()
	_furniture()
	model.finish(self)
	_signboard()


func _ground() -> void:
	model.box(Vector3(0, -1.1, -7), Vector3(45, 1, 52), palette.stone, Vector3.ZERO, "Foundation")
	for floor in [[Vector3(0, 0.0, 5.8), Vector3(20, 0.42, 7.6)],
		[Vector3(-8.6, 0, -4.2), Vector3(4.4, 0.42, 15.0)],
		[Vector3(8.6, 0, -4.2), Vector3(4.4, 0.42, 15.0)],
		[Vector3(0, 0, -14.2), Vector3(21.6, 0.42, 6.0)]]:
		model.box(floor[0], floor[1], palette.stone, Vector3.ZERO, "Walkways")
	# Coping stones with real seams catch light at the water edge.
	for side in [-1.0, 1.0]:
		for i in 19:
			model.box(Vector3(side * 6.44, 0.20, 1.7 - i * 0.70), Vector3(0.32, 0.26, 0.66), palette.stone, Vector3.ZERO, "PoolCoping")
	for i in 28:
		model.box(Vector3(-9.7 + i * 0.72, 0.26, 2.05), Vector3(0.68, 0.22, 0.32), palette.stone, Vector3.ZERO, "PoolCoping")
	# Front terrace: individual timber boards between perimeter stone bands.
	for i in 42:
		model.box(Vector3(-7.4 + i * 0.36, 0.235, 5.4), Vector3(0.345, 0.07, 5.7), palette.wood, Vector3.ZERO, "TerraceBoards")
	for x in [-6.5, 6.5]:
		for z in [-3.0, -8.0]: _railing(Vector3(x, 0.25, z), Vector3(x, 0.25, z - 3.6))


func _column(at: Vector3, height: float) -> void:
	model.box(at + Vector3(0, 0.15, 0), Vector3(0.56, 0.30, 0.56), palette.stone, Vector3.ZERO, "ColumnPlinths")
	model.cylinder(at + Vector3(0, 0.39, 0), 0.24, 0.20, palette.stone, 0.85)
	model.cylinder(at + Vector3(0, height * 0.5 + 0.36, 0), 0.17, height - 0.36, palette.paint, 0.92)
	model.cylinder(at + Vector3(0, height - 0.06, 0), 0.205, 0.17, palette.dark_paint)
	# Three crossed bracket tiers support the eave; dimensions follow the column diameter.
	for tier in 3:
		var y := height + 0.03 + tier * 0.13
		var length := 0.55 + tier * 0.25
		model.box(at + Vector3(0, y, 0), Vector3(length, 0.12, 0.18), palette.wood, Vector3.ZERO, "BracketArms")
		model.box(at + Vector3(0, y + 0.06, 0), Vector3(0.18, 0.12, length), palette.paint, Vector3.ZERO, "BracketArms")


func _railing(a: Vector3, b: Vector3) -> void:
	var span := b - a
	var count := maxi(1, roundi(span.length() / 0.95))
	var along := span.normalized()
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		model.box(p + Vector3(0, 0.48, 0), Vector3(0.11, 0.98, 0.11), palette.dark_paint, Vector3.ZERO, "RailingPosts")
		model.box(p + Vector3(0, 1.0, 0), Vector3(0.17, 0.08, 0.17), palette.wood, Vector3.ZERO, "PostCaps")
	model.beam(a + Vector3.UP * 0.91, b + Vector3.UP * 0.91, 0.10, 0.13, palette.wood, "Handrails")
	model.beam(a + Vector3.UP * 0.16, b + Vector3.UP * 0.16, 0.09, 0.11, palette.dark_paint, "Handrails")
	for i in count:
		var p := a.lerp(b, (i + 0.5) / count)
		var half := along * span.length() / count * 0.40
		# A stepped rectangular meander, with both lower and upper open spaces.
		model.beam(p - half + Vector3.UP * 0.52, p + half + Vector3.UP * 0.52, 0.035, 0.045, palette.paint, "RailingLattice")
		for side in [-1.0, 1.0]:
			model.beam(p + half * side + Vector3.UP * 0.25, p + half * side + Vector3.UP * 0.78, 0.035, 0.045, palette.paint, "RailingLattice")
			model.beam(p + half * side * 0.35 + Vector3.UP * 0.25, p + half * side * 0.35 + Vector3.UP * 0.78, 0.035, 0.045, palette.paint, "RailingLattice")


func _window(center: Vector3, width: float, height: float) -> void:
	model.box(center + Vector3(0, 0, -0.025), Vector3(width, height, 0.035), palette.paper, Vector3.ZERO, "WindowPaper")
	for x in [-width * 0.5, width * 0.5]:
		model.box(center + Vector3(x, 0, 0.03), Vector3(0.085, height + 0.12, 0.12), palette.dark_paint, Vector3.ZERO, "WindowFrames")
	for y in [-height * 0.5, height * 0.5]:
		model.box(center + Vector3(0, y, 0.03), Vector3(width + 0.10, 0.085, 0.12), palette.dark_paint, Vector3.ZERO, "WindowFrames")
	var columns := maxi(1, floori(width / 0.24))
	var rows := maxi(1, floori(height / 0.30))
	for i in columns + 1:
		model.box(center + Vector3(-width * 0.5 + width * i / columns, 0, 0.08), Vector3(0.027, height, 0.035), palette.wood, Vector3.ZERO, "WindowLattice")
	for j in rows + 1:
		model.box(center + Vector3(0, -height * 0.5 + height * j / rows, 0.08), Vector3(width, 0.027, 0.035), palette.wood, Vector3.ZERO, "WindowLattice")
	# Sparse diamonds establish a designed rhythm over the fine rectangular grid.
	for i in range(1, columns, 2):
		for j in range(1, rows, 2):
			var p := center + Vector3(-width * 0.5 + width * i / columns, -height * 0.5 + height * j / rows, 0.105)
			var dx := width / columns * 0.70
			var dy := height / rows * 0.70
			for pair in [[Vector3(-dx, 0, 0), Vector3(0, dy, 0)], [Vector3(0, dy, 0), Vector3(dx, 0, 0)], [Vector3(dx, 0, 0), Vector3(0, -dy, 0)], [Vector3(0, -dy, 0), Vector3(-dx, 0, 0)]]:
				model.beam(p + pair[0], p + pair[1], 0.023, 0.023, palette.dark_paint, "WindowDiamonds")


func _hall(origin: Vector3, width: float, depth: float, height: float, open := false, with_roof := true) -> void:
	model.box(origin + Vector3(0, -0.05, 0), Vector3(width + 0.6, 0.25, depth + 0.6), palette.wood, Vector3.ZERO, "HallFloors")
	var bays := maxi(2, roundi(width / 2.5))
	for i in bays + 1:
		var x := -width * 0.5 + width * i / bays
		for z in [-depth * 0.5, depth * 0.5]: _column(origin + Vector3(x, 0, z), height)
	for z in [-depth * 0.5, depth * 0.5]:
		model.box(origin + Vector3(0, height - 0.14, z), Vector3(width + 0.55, 0.28, 0.27), palette.dark_paint, Vector3.ZERO, "TieBeams")
		model.box(origin + Vector3(0, height + 0.35, z), Vector3(width + 0.85, 0.16, 0.23), palette.paint, Vector3.ZERO, "TieBeams")
	for x in [-width * 0.5, width * 0.5]:
		model.box(origin + Vector3(x, height - 0.04, 0), Vector3(0.25, 0.25, depth), palette.dark_paint, Vector3.ZERO, "TieBeams")
	if not open:
		model.box(origin + Vector3(0, 1.5, -depth * 0.5), Vector3(width, 3.0, 0.18), palette.plaster, Vector3.ZERO, "PlasterWalls")
		for i in bays:
			var x := -width * 0.5 + width * (i + 0.5) / bays
			_window(origin + Vector3(x, 1.95, -depth * 0.5 + 0.14), width / bays - 0.35, 1.8)
		model.box(origin + Vector3(0, 0.42, -depth * 0.5 + 0.12), Vector3(width, 0.82, 0.12), palette.dark_paint, Vector3.ZERO, "WallWainscots")
		for i in 2:
			model.box(origin + Vector3(0, 1.95 + i * 0.9, -depth * 0.5 + 0.22), Vector3(width, 0.07, 0.08), palette.paint, Vector3.ZERO, "WallRails")
	if with_roof: model.roof(origin + Vector3(0, height + 0.52, 0), width + 1.8, depth + 1.9, 1.35, palette.roof, palette.wood)
	if open:
		_railing(origin + Vector3(-width * 0.5, 0.1, -depth * 0.5), origin + Vector3(width * 0.5, 0.1, -depth * 0.5))
		_railing(origin + Vector3(-width * 0.5, 0.1, -depth * 0.5), origin + Vector3(-width * 0.5, 0.1, depth * 0.5))


func _right_wing() -> void:
	# This wing runs along the water; its front face remains readable from the entry view.
	_hall(Vector3(8.6, 0.5, -5.7), 5.0, 10.0, 3.25, false, false)
	model.box(Vector3(8.6, 3.75, -5.7), Vector3(5.35, 0.25, 10.4), palette.wood, Vector3.ZERO, "UpperFloor")
	for z in [-10.4, -7.3, -4.0, -0.8]:
		for x in [6.25, 10.95]: _column(Vector3(x, 3.85, z), 2.75)
	for z in [-10.4, -7.3, -4.0]:
		_railing(Vector3(6.15, 3.94, z), Vector3(6.15, 3.94, z + 2.95))
	model.box(Vector3(8.65, 5.1, -10.65), Vector3(4.8, 2.5, 0.15), palette.plaster, Vector3.ZERO, "UpperWall")
	for x in [7.3, 9.85]: _window(Vector3(x, 5.25, -10.5), 2.1, 1.75)
	model.roof(Vector3(8.6, 7.06, -5.7), 6.6, 11.6, 1.4, palette.roof, palette.wood)


func _entrance() -> void:
	for x in [-4.5, 4.5]:
		for z in [3.35, 8.5]: _column(Vector3(x, 0.27, z), 4.8)
	for z in [3.35, 8.5]:
		model.box(Vector3(0, 5.0, z), Vector3(9.9, 0.36, 0.38), palette.dark_paint, Vector3.ZERO, "EntryLintels")
		model.box(Vector3(0, 4.72, z), Vector3(9.6, 0.13, 0.19), palette.wood, Vector3.ZERO, "EntryMouldings")
	for i in 14:
		var x := -4.15 + i * 0.64
		for sign in [-1.0, 1.0]:
			model.box(Vector3(x + sign * 0.20, 4.98, 3.57), Vector3(0.028, 0.20, 0.035), palette.wood, Vector3.ZERO, "LintelCarving")
			model.box(Vector3(x, 4.98 + sign * 0.10, 3.57), Vector3(0.42, 0.028, 0.035), palette.wood, Vector3.ZERO, "LintelCarving")
	for x in range(-4, 5):
		model.box(Vector3(x, 5.15, 5.9), Vector3(0.12, 0.22, 5.8), palette.wood, Vector3.ZERO, "EntryCeilingRafters")
	# Close door panels and header carving provide near-field detail at the screen edges.
	for side in [-1.0, 1.0]:
		var x: float = side * 5.4
		model.box(Vector3(x, 2.5, 3.5), Vector3(1.55, 4.6, 0.20), palette.dark_paint, Vector3.ZERO, "EntryDoorPanels")
		_window(Vector3(x, 3.2, 3.64), 1.20, 1.8)
		for y in [0.65, 1.65, 4.55]:
			model.box(Vector3(x, y, 3.65), Vector3(1.48, 0.10, 0.10), palette.wood, Vector3.ZERO, "DoorPanelRails")
		for row in 3:
			model.box(Vector3(x, 0.9 + row * 0.20, 3.66), Vector3(1.18, 0.06, 0.06), palette.paint, Vector3.ZERO, "DoorPanelInlay")
	model.roof(Vector3(0, 5.33, 5.9), 10.8, 6.8, 1.65, palette.roof, palette.wood)


func _bridge() -> void:
	for i in 42:
		var z := 1.65 - i * 0.31
		var arch := 0.18 * sin(PI * i / 41.0)
		model.box(Vector3(-0.8, 0.32 + arch, z), Vector3(2.7, 0.13, 0.29), palette.wood, Vector3.ZERO, "BridgeDeckBoards")
	for side in [-1.0, 1.0]:
		for i in 4:
			var z0 := 1.65 - i * 3.17
			_railing(Vector3(-0.8 + side * 1.37, 0.36, z0), Vector3(-0.8 + side * 1.37, 0.36, z0 - 3.15))
		for z in [-1.0, -6.0, -10.0]:
			model.box(Vector3(-0.8 + side * 1.12, -0.45, z), Vector3(0.22, 1.6, 0.24), palette.dark_paint, Vector3.ZERO, "BridgePiers")


func _furniture() -> void:
	for x in [-3.4, 1.5]:
		model.box(Vector3(x, 0.95, -14.0), Vector3(1.7, 0.12, 0.7), palette.wood, Vector3.ZERO, "Tables")
		for dx in [-0.67, 0.67]:
			for dz in [-0.25, 0.25]: model.box(Vector3(x + dx, 0.68, -14.0 + dz), Vector3(0.09, 0.52, 0.09), palette.dark_paint, Vector3.ZERO, "TableLegs")
		for book in 4:
			model.box(Vector3(x - 0.4, 1.05 + book * 0.045, -14), Vector3(0.48, 0.04, 0.31), palette.paper, Vector3(0, book * 0.035, 0), "FoldedBooks")
	for x in [-5.0, 4.4]:
		model.cylinder(Vector3(x, 0.63, -12.4), 0.48, 0.60, palette.stone, 1.1, "Planters")
		model.cylinder(Vector3(x, 0.94, -12.4), 0.51, 0.10, palette.dark_paint, 1.0, "PlanterRims")


func _signboard() -> void:
	var board := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = Vector3(2.05, 0.60, 0.14)
	board.mesh = block
	board.material_override = palette.dark_paint
	board.position = Vector3(-1, 3.83, -12.06)
	board.name = "ArchivePlaque"
	add_child(board)
	board.owner = self
	var letters := Label3D.new()
	letters.text = "藏字阁"
	letters.font = load("res://assets/fonts/NotoSerifSC-VF.ttf")
	letters.font_size = 96
	letters.pixel_size = 0.0052
	letters.outline_size = 0
	letters.modulate = Color("c2b18a")
	letters.shaded = true
	letters.position = Vector3(-1, 3.83, -11.98)
	letters.name = "ArchiveLettering"
	add_child(letters)
	letters.owner = self
