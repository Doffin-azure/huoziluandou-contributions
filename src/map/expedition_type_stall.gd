extends "res://src/map/expedition_building_base.gd"
## Bronze type stall: print drawers, a low cinnabar awning and a working press.
var _shutters: Node3D
var _wares: Node3D
var _sign: Label3D


func _build() -> void:
	name = "BronzeTypeStall"
	footprint = Vector2(1.8,1.28)
	map_scale = .49
	box(Vector3(0,.055,0),Vector3(1.80,.11,1.28),"architecture",1.0)
	box(Vector3(0,.125,-.02),Vector3(1.65,.035,1.10),"stone",.55)
	box(Vector3(0,.035,.73),Vector3(.82,.07,.25),"architecture",.6)
	inlay("市",Vector3(0,.074,.75),.32)
	box(Vector3(0,.765,-.43),Vector3(1.45,1.25,.12),"roof",.8)
	for x in [-.71,.71]:
		box(Vector3(x,.80,.16),Vector3(.095,1.36,.11),"architecture",.7)
		box(Vector3(x,.24,.17),Vector3(.17,.13,.17),"copper_dark",.4)
		box(Vector3(x,1.46,.13),Vector3(.17,.09,.18),"copper_dark",.4)
		beam(Vector3(x,1.48,-.35),Vector3(x,1.48,.42),.065,"copper_dark")
	box(Vector3(0,1.47,-.37),Vector3(1.49,.07,.08),"copper_dark",.4)
	# Only six drawers: the grid is concentrated on the goods, away from the floor.
	for x in [-.47,0.0,.47]:
		for y in [.47,.78]:
			box(Vector3(x,y,-.344),Vector3(.42,.26,.06),"wood",.35)
			box(Vector3(x,y,-.304),Vector3(.12,.045,.02),"copper_dark",.22)
			ink([Vector3(x-.17,y+.09,-.307),Vector3(x+.17,y+.09,-.307)],.20)
	box(Vector3(0,.43,.30),Vector3(1.48,.55,.43),"wood",.7)
	box(Vector3(0,.727,.30),Vector3(1.63,.07,.56),"architecture",.7)
	box(Vector3(0,.50,.526),Vector3(1.37,.25,.026),"roof",.45)
	for x in [-.61,.61]: box(Vector3(x,.50,.550),Vector3(.05,.26,.018),"copper_dark",.25)
	# The press is small but has a recognizable screw, platen and an ink tray.
	box(Vector3(.48,.81,-.10),Vector3(.29,.07,.25),"copper_dark",.4)
	for x in [.36,.60]: box(Vector3(x,1.0,-.12),Vector3(.035,.36,.035),"architecture",.28)
	box(Vector3(.48,1.18,-.12),Vector3(.34,.055,.10),"copper_dark",.3)
	cylinder(Vector3(.48,1.08,-.12),.022,.26,"bronze",null,6)
	box(Vector3(.48,.93,-.12),Vector3(.20,.04,.19),"roof",.3)
	box(Vector3(.48,1.24,-.12),Vector3(.24,.025,.025),"copper_dark",.25)
	_wares = Node3D.new()
	_wares.name = "OpenTypeCases"
	add_child(_wares)
	for index in 3:
		var x := -.48+index*.27
		box(Vector3(x,.798,.31),Vector3(.235,.075,.28),"copper_dark",.38,_wares)
		box(Vector3(x,.84,.31),Vector3(.19,.018,.23),"roof",.2,_wares)
		for n in 2:
			var block := box(Vector3(x-.045+n*.09,.87,.31),Vector3(.073,.05,.14),"bronze",.2,_wares)
			# Top strokes suggest the printing faces, avoiding tiny unreadable labels.
			ink([block.position+Vector3(-.023,.026,-.04),block.position+Vector3(.023,.026,-.04)],.19,"ink",_wares)
	# Sloped cloth is one closed low-poly volume; its projection shares the building.
	# Build the awning in the Y/Z section, then turn that section across the stall.
	var canopy := profile(PackedVector2Array([Vector2(-.44,1.62),Vector2(.42,1.49),Vector2(.42,1.44),Vector2(-.44,1.57)]),1.72,Vector3.ZERO,"cloth",.8)
	canopy.rotation.y = -PI*.5
	box(Vector3(0,1.46,.42),Vector3(1.76,.10,.045),"cloth",.6)
	for x in [-.58,0.0,.58]:
		ink([Vector3(x,1.622,-.44),Vector3(x,1.492,.42)],.25)
	# Short asymmetrical hem tails, rather than a repeated decorative fringe.
	for x in [-.68,.68]:
		profile(PackedVector2Array([Vector2(-.06,0),Vector2(.06,0),Vector2(.04,-.19),Vector2(-.02,-.14),Vector2(-.05,-.21)]),.012,Vector3(x,1.41,.424),"cloth",.42)
	box(Vector3(-.46,.50,.555),Vector3(.22,.29,.035),"copper_dark",.55)
	_sign = sign_text("字",Vector3(-.46,.50,.578),.00165)
	# A restrained copper inlay gives the broad counter front a structural focal point.
	ink([Vector3(-.22,.58,.543),Vector3(.40,.58,.543),Vector3(.40,.44,.543),Vector3(.08,.44,.543),Vector3(.08,.51,.543),Vector3(.29,.51,.543)],.27,"bronze")
	lantern(Vector3(-.88,.58,.21),.65)
	_shutters = Node3D.new()
	_shutters.name = "ClosedShutters"
	add_child(_shutters)
	for x in [-.35,.35]:
		box(Vector3(x,.96,.22),Vector3(.68,.43,.055),"wood",.6,_shutters)
		for dx in [-.22,0.0,.22]: ink([Vector3(x+dx,.77,.251),Vector3(x+dx,1.15,.251)],.25,"ink",_shutters)
	box(Vector3(0,.96,.263),Vector3(.10,.17,.018),"seal",.3,_shutters)
	ink([Vector3(-.69,.13,.45),Vector3(-.60,.10,.45),Vector3(-.59,.06,.45)],.26)


func _apply_state() -> void:
	_shutters.visible = alternate_state
	_wares.visible = not alternate_state
	_sign.text = "歇" if alternate_state else "字"
