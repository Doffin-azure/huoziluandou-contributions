extends "res://src/map/expedition_building_base.gd"
## Obsidian-like ink slabs bound with crossed cinnabar seals; clearing leaves low rubble.
var intact: Node3D
var cleared: Node3D
var floor_marker: Node3D


func _build() -> void:
	name = "CinnabarInkBarrier"
	footprint = Vector2(1.40,.78)
	map_scale = .59
	intact = Node3D.new()
	intact.name = "SealedStoneCluster"
	add_child(intact)
	cleared = Node3D.new()
	cleared.name = "ClearedLowRubble"
	add_child(cleared)
	# Three unequal slabs read as a blocked passage rather than another tombstone.
	var shapes := [
		PackedVector2Array([Vector2(-.27,0),Vector2(.25,0),Vector2(.28,.66),Vector2(.16,.91),Vector2(-.10,1.16),Vector2(-.25,.95)]),
		PackedVector2Array([Vector2(-.24,0),Vector2(.23,0),Vector2(.28,.49),Vector2(.11,.80),Vector2(-.11,.72),Vector2(-.24,.43)]),
		PackedVector2Array([Vector2(-.23,0),Vector2(.24,0),Vector2(.27,.47),Vector2(.15,.69),Vector2(-.11,.84),Vector2(-.25,.60)])]
	var centers := [Vector3(0,0,0),Vector3(-.43,0,-.035),Vector3(.43,0,-.055)]
	for index in 3:
		var stone := profile(shapes[index],.34 if index==0 else .29,centers[index],"roof",.85,intact)
		stone.rotation.z = [0.0,.14,-.12][index]
	# The cloth bridges the slabs; its slight separation from the stone is intentional.
	for side in [-1.0,1.0]:
		var strip := box(Vector3(0,.55,.226),Vector3(1.19,.105,.018),"cloth",.45,intact)
		strip.rotation.z = side*.48
	for x in [-.50,.50]: cylinder(Vector3(x,.10,-.13),.045,.065,"copper_dark",intact,6)
	box(Vector3(0,.55,.254),Vector3(.21,.27,.025),"seal",.45,intact)
	sign_text("封",Vector3(0,.55,.271),.00145,intact)
	ink([Vector3(-.09,1.09,.173),Vector3(-.01,.93,.173),Vector3(-.07,.80,.173)],.34,"worn",intact)
	ink([Vector3(.15,.32,.173),Vector3(.08,.24,.173),Vector3(.13,.11,.173)],.33,"ink",intact)
	# Remains are individually solid and sit on the floor after the obstruction is gone.
	for entry in [[-.44,.23,.27,.15,.1],[.00,.16,.32,.22,-.2],[.43,.19,.24,.17,.3]]:
		var width: float = entry[2]
		var height: float = entry[3]
		var rock := profile(PackedVector2Array([Vector2(-width*.5,0),Vector2(width*.5,0),Vector2(width*.40,height*.65),Vector2(-width*.14,height)]),.31,Vector3(entry[0],0,entry[1]),"tombstone",.5,cleared)
		rock.rotation.y = entry[4]
	for x in [-.20,.24]:
		var scrap := box(Vector3(x,.012,.32),Vector3(.15,.015,.09),"cloth",.25,cleared)
		scrap.rotation.y = -.4
	floor_marker = inlay("障",Vector3(0,.003,.61),.31)


func _apply_state() -> void:
	intact.visible = not alternate_state
	cleared.visible = alternate_state
	floor_marker.set_spent(alternate_state)
