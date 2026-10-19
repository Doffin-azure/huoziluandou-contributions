extends "res://src/map/expedition_building_base.gd"
## Heavy beast-mask gate with solid pivoted doors and removable central seal.
var roof: MeshInstance3D
var left_door: Node3D
var right_door: Node3D
var _seal: Node3D


func _build() -> void:
	name = "BeastMaskGate"
	footprint = Vector2(1.98,1.05)
	map_scale = .45
	lamps_when_alternate = true
	box(Vector3(0,.065,0),Vector3(1.98,.13,1.05),"architecture",1.0)
	box(Vector3(0,.15,0),Vector3(1.82,.04,.92),"stone",.6)
	box(Vector3(0,.035,.64),Vector3(.98,.07,.26),"architecture",.6)
	for side in [-1.0,1.0]:
		var x: float = side*.72
		box(Vector3(x,.24,0),Vector3(.43,.15,.66),"architecture",.7)
		box(Vector3(x,.89,0),Vector3(.32,1.16,.42),"architecture",.8)
		box(Vector3(x,.43,0),Vector3(.38,.09,.49),"copper_dark",.45)
		box(Vector3(x,1.39,0),Vector3(.42,.13,.54),"copper_dark",.55)
		box(Vector3(x,.93,.223),Vector3(.13,.64,.026),"roof",.45)
		ink([Vector3(x-side*.10,.54,.218),Vector3(x-side*.10,1.26,.218)],.26)
		ink([Vector3(x-.035,1.15,.241),Vector3(x+.035,1.15,.241),Vector3(x+.035,1.00,.241),Vector3(x-.035,1.00,.241),Vector3(x-.035,.85,.241)],.25,"bronze")
		# Projecting copper lamp arms sit outside the doorway silhouette.
		beam(Vector3(x,1.12,.05),Vector3(x+side*.23,1.12,.05),.045,"copper_dark")
		lantern(Vector3(x+side*.23,.84,.05),.57)
	box(Vector3(0,1.51,0),Vector3(1.97,.17,.59),"architecture",.9)
	box(Vector3(0,1.61,0),Vector3(2.07,.035,.65),"copper_dark",.4)
	roof = hip_roof(Vector3(0,1.68,0),2.30,.96,.25,.50)
	_beast_mask()
	left_door = _door(-1.0)
	right_door = _door(1.0)
	_seal = Node3D.new()
	_seal.name = "IntactCinnabarSeal"
	add_child(_seal)
	box(Vector3(0,.85,.128),Vector3(.16,.43,.028),"seal",.45,_seal)
	sign_text("封",Vector3(0,.85,.148),.00145,_seal)
	# A low threshold keeps the opening connected to the common ground plane.
	ink([Vector3(-.48,.173,.43),Vector3(.48,.173,.43)],.30)
	ink([Vector3(-.91,.13,.46),Vector3(-.85,.10,.46),Vector3(-.86,.06,.46)],.28)


func _door(side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side*.535,.18,0)
	pivot.name = "LeftDoor" if side<0 else "RightDoor"
	add_child(pivot)
	var center := -side*.265
	box(Vector3(center,.59,0),Vector3(.52,1.15,.10),"wood",.6,pivot)
	for y in [.20,.98]: box(Vector3(center,y,.058),Vector3(.52,.052,.026),"copper_dark",.28,pivot)
	for dx in [-.16,0.0,.16]:
		ink([Vector3(center+dx,.08,.052),Vector3(center+dx,1.10,.052)],.22,"ink",pivot)
	var ring := TorusMesh.new()
	ring.inner_radius = .045
	ring.outer_radius = .065
	ring.rings = 12
	ring.ring_segments = 6
	var handle := style.mesh(pivot,ring,Vector3(-side*.08,.56,.092),"copper_dark",.2)
	handle.rotation.x = PI*.5
	for y in [.16,1.02]: cylinder(Vector3(0,y,0),.043,.14,"copper_dark",pivot,6)
	return pivot


func _beast_mask() -> void:
	# Project the mask beyond the eave: the eyes and horns must survive the map angle.
	box(Vector3(0,1.48,.39),Vector3(.56,.14,.21),"copper_dark",.45)
	var origin := Vector3(0,1.39,.515)
	profile(PackedVector2Array([Vector2(-.30,.12),Vector2(-.18,.22),Vector2(0,.19),Vector2(.18,.22),Vector2(.30,.12),Vector2(.23,-.10),Vector2(0,-.20),Vector2(-.23,-.10)]),.065,origin,"copper_dark",.7)
	for side in [-1.0,1.0]:
		profile(PackedVector2Array([Vector2(side*.17,.13),Vector2(side*.25,.24),Vector2(side*.39,.23),Vector2(side*.34,.34),Vector2(side*.43,.29),Vector2(side*.45,.12),Vector2(side*.29,.06)]),.04,origin+Vector3(0,0,-.02),"bronze",.45)
		var brow := box(origin+Vector3(side*.125,.035,.043),Vector3(.17,.045,.035),"bronze",.25)
		brow.rotation.z = -side*.22
		ink([origin+Vector3(side*.06,-.01,.063),origin+Vector3(side*.18,-.025,.063)],.48)
	profile(PackedVector2Array([Vector2(-.045,.03),Vector2(.045,.03),Vector2(.07,-.045),Vector2(0,-.075),Vector2(-.07,-.045)]),.05,origin+Vector3(0,0,.055),"bronze",.4)
	box(origin+Vector3(0,-.125,.066),Vector3(.17,.047,.022),"foreground",.25)
	for side in [-1.0,1.0]:
		profile(PackedVector2Array([Vector2(side*.07,-.10),Vector2(side*.03,-.10),Vector2(side*.04,-.145)]),.012,origin+Vector3(0,0,.084),"bronze",.22)
		ink([origin+Vector3(side*.21,.02,.036),origin+Vector3(side*.20,-.055,.036),origin+Vector3(side*.13,-.09,.050)],.25)
	box(origin+Vector3(0,.13,.055),Vector3(.045,.07,.02),"seal",.22)
	ink([origin+Vector3(-.14,-.09,.044),origin+Vector3(0,-.145,.08),origin+Vector3(.14,-.09,.044)],.30)


func _apply_state() -> void:
	left_door.rotation.y = -PI*.55 if alternate_state else 0.0
	right_door.rotation.y = PI*.55 if alternate_state else 0.0
	_seal.visible = not alternate_state
