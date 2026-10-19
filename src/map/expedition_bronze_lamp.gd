extends "res://src/map/expedition_building_base.gd"
## Verdigris shaft, six-sided cage, closed snuffer and warm native local light.
var _snuffer: Node3D


func _build() -> void:
	name = "BronzeGuideLamp"
	footprint = Vector2(.58,.54)
	map_scale = .46
	var foot := cylinder(Vector3(0,.07,0),.29,.14,"tombstone",null,8)
	foot.rotation.y = PI/8
	cylinder(Vector3(0,.18,0),.18,.085,"patina",null,8)
	cylinder(Vector3(0,.265,0),.13,.095,"copper_dark",null,8)
	cylinder(Vector3(0,.61,0),.095,.65,"patina",null,8)
	cylinder(Vector3(0,.92,0),.13,.075,"copper_dark",null,8)
	cylinder(Vector3(0,.985,0),.17,.07,"patina",null,6)
	box(Vector3(0,.61,.096),Vector3(.105,.27,.016),"copper_dark",.35)
	var glyph := sign_text("引",Vector3(0,.61,.107),.0010)
	glyph.set_meta("incised",true)
	ink([Vector3(-.041,.38,.089),Vector3(-.041,.78,.089)],.23)
	ink([Vector3(.041,.37,.089),Vector3(.041,.45,.089)],.23)
	var head := lantern(Vector3(0,1.22,0),1.45,false)
	_lamps[0].light_energy = .55
	_lamps[0].omni_range = 1.0
	var roof := CylinderMesh.new()
	roof.top_radius = .095
	roof.bottom_radius = .31
	roof.height = .115
	roof.radial_segments = 6
	style.mesh(self,roof,Vector3(0,1.49,0),"roof",.75)
	cylinder(Vector3(0,1.57,0),.045,.08,"copper_dark",null,6)
	# An actual opaque shutter sleeve closes inside the cage when the lamp is off.
	_snuffer = Node3D.new()
	_snuffer.name = "ClosedShutterSleeve"
	head.add_child(_snuffer)
	cylinder(Vector3.ZERO,.095,.235,"patina",_snuffer,6)
	for y in [-.065,0.0,.065]:
		ink([Vector3(-.055,y,.084),Vector3(.055,y,.084)],.27,"ink",_snuffer)
	ink([Vector3(-.18,.145,.20),Vector3(-.07,.145,.20)],.27)


func _apply_state() -> void:
	_snuffer.visible = alternate_state


func refresh_palette() -> void:
	super.refresh_palette()
	for label in _labels:
		if label.has_meta("incised"): label.modulate = style.palette.ink
