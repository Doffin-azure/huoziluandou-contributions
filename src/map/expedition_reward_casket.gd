extends "res://src/map/expedition_building_base.gd"
## A restrained hollow type casket; lid, seal and hinge share the same 3D projection.
var lid_pivot: Node3D
var floor_marker: Node3D
var _seal: Node3D
var _torn_seal: Node3D


func _build() -> void:
	name = "SealedRewardCasket"
	footprint = Vector2(1.06,.78)
	map_scale = .68
	for x in [-.40,.40]:
		for z in [-.25,.25]: box(Vector3(x,.035,z),Vector3(.15,.07,.16),"copper_dark",.45)
	box(Vector3(0,.125,0),Vector3(1.02,.12,.73),"wood",.8)
	# Four walls and a floor leave real empty space after the lid opens.
	box(Vector3(0,.185,0),Vector3(.88,.04,.60),"foreground",.25)
	for x in [-.47,.47]: box(Vector3(x,.37,0),Vector3(.075,.40,.70),"wood",.75)
	for z in [-.315,.315]: box(Vector3(0,.37,z),Vector3(.87,.40,.07),"wood",.65)
	for x in [-.34,.34]:
		box(Vector3(x,.37,.356),Vector3(.045,.39,.018),"copper_dark",.28)
		box(Vector3(x,.37,-.356),Vector3(.045,.39,.018),"copper_dark",.28)
		# Two simple side grips, rather than ornamental hardware over every face.
	for side in [-1.0,1.0]:
		box(Vector3(side*.515,.37,0),Vector3(.035,.08,.24),"copper_dark",.35)
		box(Vector3(side*.539,.35,0),Vector3(.018,.035,.15),"roof",.20)
	box(Vector3(0,.35,.363),Vector3(.18,.15,.024),"copper_dark",.45)
	var title := sign_text("赏",Vector3(0,.35,.381),.00118)
	title.set_meta("incised",true)
	ink([Vector3(-.27,.29,.352),Vector3(-.09,.29,.352)],.23)
	ink([Vector3(.09,.47,.352),Vector3(.27,.47,.352)],.23)
	ink([Vector3(-.50,.24,.17),Vector3(-.50,.27,.03),Vector3(-.50,.24,-.13)],.24)
	lid_pivot = Node3D.new()
	lid_pivot.name = "RearHingedLid"
	lid_pivot.position = Vector3(0,.57,-.35)
	add_child(lid_pivot)
	var section := PackedVector2Array([Vector2(-.37,0),Vector2(.37,0),Vector2(.35,.09),Vector2(.28,.125),Vector2(-.28,.125),Vector2(-.35,.09)])
	var lid := profile(section,1.035,Vector3(0,.025,.35),"wood",.85,lid_pivot)
	lid.rotation.y = -PI*.5
	for x in [-.34,.34]:
		var band := profile(section,.042,Vector3(x,.036,.35),"copper_dark",.28,lid_pivot)
		band.rotation.y = -PI*.5
		var hinge := cylinder(Vector3(x,0,.01),.04,.115,"copper_dark",lid_pivot,8)
		hinge.rotation.z = PI*.5
	ink([Vector3(-.23,.153,.17),Vector3(-.23,.153,.51)],.24,"ink",lid_pivot)
	ink([Vector3(.24,.153,.18),Vector3(.24,.153,.46)],.24,"ink",lid_pivot)
	_seal = Node3D.new()
	_seal.name = "IntactCinnabarStrip"
	lid_pivot.add_child(_seal)
	box(Vector3(0,.165,.35),Vector3(.13,.018,.51),"cloth",.35,_seal)
	var wrap_section := PackedVector2Array([Vector2(.595,.155),Vector2(.63,.155),Vector2(.71,.119),Vector2(.737,.022),Vector2(.725,.015),Vector2(.697,.108),Vector2(.628,.143),Vector2(.595,.143)])
	wrap_section.reverse()
	var wrap := profile(wrap_section,.13,Vector3.ZERO,"cloth",.25,_seal)
	wrap.rotation.y = -PI*.5
	box(Vector3(0,-.062,.726),Vector3(.13,.18,.014),"cloth",.35,_seal)
	var stamp := sign_text("封",Vector3(0,.176,.35),.0011,_seal)
	stamp.rotation.x = -PI*.5
	_torn_seal = Node3D.new()
	_torn_seal.name = "BrokenSealEnds"
	add_child(_torn_seal)
	for x in [-.045,.045]:
		profile(PackedVector2Array([Vector2(-.025,0),Vector2(.025,0),Vector2(.018,-.08),Vector2(-.003,-.055),Vector2(-.022,-.095)]),.006,Vector3(x,.55,.358),"cloth",.22,_torn_seal)
	floor_marker = inlay("赏",Vector3(0,.003,.59),.31)


func _apply_state() -> void:
	lid_pivot.rotation.x = deg_to_rad(-105) if alternate_state else 0.0
	_seal.visible = not alternate_state
	_torn_seal.visible = alternate_state
	floor_marker.set_spent(alternate_state)


func refresh_palette() -> void:
	super.refresh_palette()
	for label in _labels:
		if label.has_meta("incised"): label.modulate = style.palette.ink
