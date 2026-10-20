extends "res://src/map/expedition_building_base.gd"
## Open rest pavilion: suspended hexagonal lamp, benches, heavy roof and foot stones.
var roof: MeshInstance3D
var _rest_tag: Node3D


func _build() -> void:
	name = "RestLanternPavilion"
	footprint = Vector2(1.65,1.35)
	map_scale = .50
	box(Vector3(0,.06,0),Vector3(1.65,.12,1.35),"architecture",1.0)
	box(Vector3(0,.15,-.035),Vector3(1.49,.07,1.17),"stone",.65)
	box(Vector3(0,.045,.75),Vector3(.78,.09,.23),"architecture",.7)
	inlay("休",Vector3(0,.093,.78),.34)
	for x in [-.59,.59]:
		for z in [-.43,.43]:
			box(Vector3(x,.235,z),Vector3(.23,.13,.23),"copper_dark",.5)
			cylinder(Vector3(x,.82,z),.068,1.07,"architecture",null,8)
			box(Vector3(x,1.35,z),Vector3(.21,.09,.21),"copper_dark",.45)
			beam(Vector3(x,1.1,z),Vector3(x*.7,1.4,z),.057,"architecture")
			ink([Vector3(x-.028,.36,z+.064),Vector3(x-.028,1.20,z+.064)],.24)
	# Open sides retain a clear silhouette and a view of the lamp through the building.
	box(Vector3(0,1.41,0),Vector3(1.55,.10,1.17),"architecture",.8)
	box(Vector3(0,1.47,0),Vector3(1.65,.035,1.27),"copper_dark",.4)
	roof = hip_roof(Vector3(0,1.53,0),1.98,1.61,.29,.22)
	cylinder(Vector3(0,1.88,0),.075,.09,"copper_dark",null,6)
	box(Vector3(0,1.06,-.51),Vector3(1.1,.16,.06),"roof",.55)
	for x in [-.42,.42]:
		box(Vector3(x,.45,-.30),Vector3(.31,.075,.44),"wood",.5)
		for z in [-.45,-.13]: box(Vector3(x,.30,z),Vector3(.075,.25,.075),"architecture",.4)
		box(Vector3(x,.63,-.51),Vector3(.34,.29,.055),"architecture",.5)
		ink([Vector3(x-.12,.493,-.39),Vector3(x+.11,.493,-.39)],.24)
	lantern(Vector3(0,.92,.22),1.02)
	beam(Vector3(0,1.30,.22),Vector3(0,1.41,.22),.02,"copper_dark")
	box(Vector3(0,1.35,.615),Vector3(.26,.13,.035),"copper_dark",.4)
	sign_text("息",Vector3(0,1.35,.637),.00125)
	# A few inset structural joints, not an all-over stone pattern.
	ink([Vector3(-.72,.187,-.23),Vector3(-.27,.187,-.23)],.25)
	ink([Vector3(.26,.187,.26),Vector3(.64,.187,.26)],.25)
	ink([Vector3(-.77,.12,.54),Vector3(-.71,.10,.54),Vector3(-.69,.07,.54)],.28)
	_rest_tag = Node3D.new()
	_rest_tag.position = Vector3(.48,.91,.48)
	add_child(_rest_tag)
	box(Vector3.ZERO,Vector3(.13,.25,.018),"bronze",.45,_rest_tag)
	sign_text("歇",Vector3(0,0,.015),.00105,_rest_tag)


func _apply_state() -> void:
	_rest_tag.visible = alternate_state
