extends "res://src/map/expedition_garden_asset_base.gd"
## Quiet underworld garden architecture. Production scale matches existing assets.
enum Building { MOON_GATE, SCREEN_WALL, COVERED_WALK, STONE_BRIDGE }
const BOUNDARY = preload("res://src/map/expedition_garden_boundary.gd")
@export var building: Building = Building.MOON_GATE
@export var open_floor_passage := false
var connections: Array[Vector3] = []


func _build() -> void:
	map_scale = .5
	set_meta("decorative_only",true)
	match building:
		Building.MOON_GATE: _moon_gate()
		Building.SCREEN_WALL: _screen_wall()
		Building.COVERED_WALK: _covered_walk()
		Building.STONE_BRIDGE: _stone_bridge()
	set_meta("connections",connections)


func _moon_gate() -> void:
	name = "UnderworldMoonGate"
	footprint = Vector2(4,.65)
	connections = [Vector3(-2,0,0),Vector3(2,0,0)]
	var center := Vector2(0,.93 if open_floor_passage else 1.10)
	var radius := 1.10
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var angles: Array[float] = []
	for n in 48: angles.append(TAU*n/48.0)
	for corner in [Vector2(-2,0),Vector2(2,0),Vector2(2,2.72),Vector2(-2,2.72)]:
		angles.append(fposmod((corner-center).angle(),TAU))
	angles.sort()
	for n in angles.size():
		var outer: Array[Vector2] = []
		var inner: Array[Vector2] = []
		for angle in [angles[n],angles[(n+1)%angles.size()]]:
			var direction := Vector2(cos(angle),sin(angle))
			var horizontal := 2.0/maxf(absf(direction.x),.00001)
			var vertical := (2.72-center.y)/maxf(direction.y,.00001) if direction.y>=0 else center.y/maxf(-direction.y,.00001)
			outer.append(center+direction*minf(horizontal,vertical))
			inner.append(center+direction*radius)
		for side in [-1.0,1.0]:
			_quad(surface,[Vector3(outer[0].x,outer[0].y,side*.19),Vector3(outer[1].x,outer[1].y,side*.19),Vector3(inner[1].x,inner[1].y,side*.19),Vector3(inner[0].x,inner[0].y,side*.19)],Vector3(0,0,side))
		var midpoint := (inner[0]+inner[1])*.5-center
		_quad(surface,[Vector3(inner[0].x,inner[0].y,-.19),Vector3(inner[1].x,inner[1].y,-.19),Vector3(inner[1].x,inner[1].y,.19),Vector3(inner[0].x,inner[0].y,.19)],Vector3(-midpoint.x,-midpoint.y,0).normalized())
		var outward := ((outer[0]+outer[1])*.5-center).normalized()
		_quad(surface,[Vector3(outer[0].x,outer[0].y,-.19),Vector3(outer[1].x,outer[1].y,-.19),Vector3(outer[1].x,outer[1].y,.19),Vector3(outer[0].x,outer[0].y,.19)],Vector3(outward.x,outward.y,0))
	style.mesh(self,surface.commit(),Vector3.ZERO,"stone",1.0)
	# A continuous cut-stone ring has real depth and radial masonry joints.
	_ring(center,radius+.065,.07,.23,"architecture")
	for n in 12:
		var angle := TAU*n/12.0
		for side in [-1.0,1.0]:
			ink([Vector3(cos(angle)*(radius+.012),center.y+sin(angle)*(radius+.012),side*.236),Vector3(cos(angle)*(radius+.125),center.y+sin(angle)*(radius+.125),side*.236)],.32)
	for x in [-1.69,1.69]:
		box(Vector3(x,.08,0),Vector3(.62,.16,.57),"architecture",.7)
		box(Vector3(x,1.04,.204),Vector3(.14,.83,.028),"patina",.35)
		ink([Vector3(x-.045,1.28,.222),Vector3(x+.045,1.28,.222),Vector3(x+.045,.88,.222),Vector3(x-.045,.88,.222)],.24)
		hip_roof(Vector3(x,2.78,0),.68,.72,.12,.22)
	hip_roof(Vector3(0,2.77,0),4.18,.72,.23,.68)
	box(Vector3(0,2.54,.207),Vector3(.44,.20,.035),"patina",.45)
	ink([Vector3(-.14,2.58,.228),Vector3(.14,2.58,.228),Vector3(.14,2.49,.228),Vector3(-.14,2.49,.228),Vector3(-.14,2.58,.228)],.28)
	# One small seal is an accent; the stone opening remains the focal point.
	box(Vector3(1.48,.69,.215),Vector3(.10,.27,.025),"seal",.4)
	ink([Vector3(-1.76,1.90,.194),Vector3(-1.66,1.78,.194),Vector3(-1.72,1.59,.194)],.30)
	lantern(Vector3(-1.71,1.62,.42),.42)


func _ring(center: Vector2, radius: float, half_width: float, depth: float, role: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in 48:
		var a := TAU*n/48.0
		var b := TAU*(n+1)/48.0
		for side in [-1.0,1.0]:
			_quad(surface,[Vector3(cos(a)*(radius-half_width),maxf(0,center.y+sin(a)*(radius-half_width)),side*depth),Vector3(cos(b)*(radius-half_width),maxf(0,center.y+sin(b)*(radius-half_width)),side*depth),Vector3(cos(b)*(radius+half_width),maxf(0,center.y+sin(b)*(radius+half_width)),side*depth),Vector3(cos(a)*(radius+half_width),maxf(0,center.y+sin(a)*(radius+half_width)),side*depth)],Vector3(0,0,side))
		for r in [radius-half_width,radius+half_width]:
			var normal := Vector3(cos((a+b)*.5),sin((a+b)*.5),0)*(1 if r>radius else -1)
			_quad(surface,[Vector3(cos(a)*r,maxf(0,center.y+sin(a)*r),-depth),Vector3(cos(b)*r,maxf(0,center.y+sin(b)*r),-depth),Vector3(cos(b)*r,maxf(0,center.y+sin(b)*r),depth),Vector3(cos(a)*r,maxf(0,center.y+sin(a)*r),depth)],normal)
	style.mesh(self,surface.commit(),Vector3.ZERO,role,.55)


func _screen_wall() -> void:
	name = "SteleGardenScreen"
	footprint = Vector2(3.5,.95)
	box(Vector3(0,.09,0),Vector3(3.48,.18,.91),"architecture",1.0)
	box(Vector3(0,.24,0),Vector3(3.23,.12,.68),"stone",.65)
	box(Vector3(0,1.23,0),Vector3(3.06,1.88,.34),"stone",.9)
	for side in [-1.0,1.0]:
		box(Vector3(0,1.24,side*.188),Vector3(2.52,1.23,.04),"architecture",.55)
		box(Vector3(0,1.24,side*.214),Vector3(2.26,1.01,.022),"stone",.4)
		var z: float = side*.229
		# A broad mountain/stele motif; avoid dense all-over filigree.
		ink([Vector3(-.86,.86,z),Vector3(-.86,1.18,z),Vector3(-.48,1.18,z),Vector3(-.48,1.48,z),Vector3(-.17,1.48,z),Vector3(-.17,1.67,z),Vector3(.11,1.67,z),Vector3(.11,1.36,z),Vector3(.46,1.36,z),Vector3(.46,1.07,z),Vector3(.85,1.07,z),Vector3(.85,.86,z)],.85)
		ink([Vector3(-.89,.78,z),Vector3(.89,.78,z)],.4,"bronze")
		for x in [-1.02,1.02]:
			ink([Vector3(x,.89,z),Vector3(x,1.56,z),Vector3(x-signf(x)*.20,1.56,z)],.30)
	for x in [-1.44,1.44]:
		box(Vector3(x,1.23,0),Vector3(.16,1.91,.43),"architecture",.65)
		box(Vector3(x,.48,0),Vector3(.25,.17,.52),"patina",.45)
	box(Vector3(0,2.17,0),Vector3(3.22,.10,.48),"architecture",.65)
	hip_roof(Vector3(0,2.23,0),3.65,.92,.29,.63)
	for x in [-1.61,1.61]:
		box(Vector3(x,.075,.63),Vector3(.25,.15,.48),"stone",.55)
	ink([Vector3(.93,.28,.344),Vector3(.89,.36,.344),Vector3(.97,.48,.344)],.28)


func _covered_walk() -> void:
	name = "SteleGardenCoveredWalk"
	footprint = Vector2(4.32,1.74)
	connections = [Vector3(-2,0,0),Vector3(2,0,0)]
	box(Vector3(0,.07,0),Vector3(4.26,.14,1.62),"architecture",1.0)
	box(Vector3(0,.155,0),Vector3(4.08,.03,1.42),"stone",.5)
	for x in [-1.91,0.0,1.91]:
		for z in [-.61,.61]:
			box(Vector3(x,.22,z),Vector3(.26,.12,.26),"stone",.55)
			box(Vector3(x,1.15,z),Vector3(.13,1.75,.13),"architecture",.75)
			box(Vector3(x,.41,z),Vector3(.19,.18,.19),"patina",.45)
			box(Vector3(x,1.99,z),Vector3(.24,.12,.25),"copper_dark",.45)
			beam(Vector3(x,1.73,z),Vector3(x+(.30 if x<1 else -.30),2.05,z),.065,"architecture")
			ink([Vector3(x-.032,.53,z+.068),Vector3(x-.032,1.82,z+.068)],.26)
	for z in [-.63,.63]:
		box(Vector3(0,2.05,z),Vector3(4.24,.15,.15),"architecture",.75)
		box(Vector3(0,2.15,z),Vector3(4.38,.045,.21),"copper_dark",.4)
	for x in [-1.91,0.0,1.91]: box(Vector3(x,2.05,0),Vector3(.15,.15,1.50),"architecture",.6)
	hip_roof(Vector3(0,2.21,0),4.68,2.03,.37,.57)
	for x in [-.99,.99]:
		box(Vector3(x,.45,-.54),Vector3(1.55,.09,.28),"wood",.55)
		for dx in [-.55,.55]: box(Vector3(x+dx,.30,-.54),Vector3(.09,.24,.18),"architecture",.4)
		box(Vector3(x,.86,-.66),Vector3(1.67,.10,.09),"stone",.55)
		for dx in [-.51,0.0,.51]: box(Vector3(x+dx,.68,-.66),Vector3(.045,.29,.045),"patina",.32)
	lantern(Vector3(-.97,1.56,.04),.61)
	lantern(Vector3(1.00,1.56,.04),.61)
	box(Vector3(0,1.98,.72),Vector3(.36,.18,.035),"patina",.45)
	ink([Vector3(-.11,2.02,.741),Vector3(.11,2.02,.741),Vector3(.11,1.94,.741),Vector3(-.11,1.94,.741)],.3)
	for x in [-.84,.64]: ink([Vector3(x,.173,.16),Vector3(x+.25,.173,.16)],.23)


func _stone_bridge() -> void:
	name = "InkChannelStoneBridge"
	footprint = Vector2(4.25,2.05)
	connections = [Vector3(-2,0,0),Vector3(2,0,0)]
	# Local deck is y=0. The runtime adapter raises it above terrain and adds
	# short stone approaches; grounding it at world y=0 causes coplanar flicker.
	box(Vector3(0,-.09,0),Vector3(4.18,.18,1.70),"stone",.9)
	for z in [-.77,.77]:
		profile(PackedVector2Array([Vector2(-2.08,-.04),Vector2(2.08,-.04),Vector2(2.08,-.72),Vector2(1.71,-.72),Vector2(1.30,-.43),Vector2(.76,-.29),Vector2(0,-.24),Vector2(-.76,-.29),Vector2(-1.30,-.43),Vector2(-1.71,-.72),Vector2(-2.08,-.72)]),.16,Vector3(0,0,z),"architecture",.8)
		for x in [-1.81,1.81]: box(Vector3(x,-.43,z),Vector3(.45,.86,.32),"architecture",.65)
		var path: Array[Vector3] = [Vector3(-2,0,z),Vector3(0,0,z),Vector3(2,0,z)]
		BOUNDARY.assemble(self,style,path)
	for x in [-1.34,-.66,0.0,.66,1.34]:
		ink([Vector3(x,.002,-.65),Vector3(x,.002,.65)],.32)
	for z in [-.86,.86]:
		ink([Vector3(-1.55,-.34,z),Vector3(-.75,-.21,z),Vector3(0,-.17,z),Vector3(.75,-.21,z),Vector3(1.55,-.34,z)],.30)
