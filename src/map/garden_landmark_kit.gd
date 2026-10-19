extends "res://src/map/expedition_garden_asset_base.gd"
## Native garden landmarks. Broad silhouettes and a few carved lines share the
## existing palette / lighting; no baked perspective or bitmap building cards.
enum Kind { SQUARE_PAVILION, HEX_PAVILION, LOW_ROCKERY, HOLLOW_ROCKERY, SMALL_LOFT }
@export var kind: Kind = Kind.SQUARE_PAVILION
var _roof_geometry: Array[GeometryInstance3D] = []


func _build() -> void:
	map_scale = 1.0
	set_meta("decorative_only",true)
	match kind:
		Kind.SQUARE_PAVILION: _square_pavilion()
		Kind.HEX_PAVILION: _hex_pavilion()
		Kind.LOW_ROCKERY: _low_rockery()
		Kind.HOLLOW_ROCKERY: _hollow_rockery()
		Kind.SMALL_LOFT: _small_loft()
	set_meta("ground_contact",Vector3.ZERO)
	set_meta("footprint",footprint)
	set_meta("sockets",[Vector3(0,0,footprint.y*.5)])
	_collect_roof_geometry(self,false)


func _column(at: Vector3, height: float) -> void:
	box(at+Vector3.UP*.06,Vector3(.25,.12,.25),"stone",.8)
	box(at+Vector3.UP*(.12+height*.5),Vector3(.115,height,.115),"architecture",.9)
	box(at+Vector3.UP*.26,Vector3(.155,.16,.155),"patina",.5)
	box(at+Vector3.UP*(height+.10),Vector3(.23,.14,.23),"copper_dark",.55)
	ink([at+Vector3(-.027,.36,.06),at+Vector3(-.027,height+.02,.06)],.34)


func _seat(a: Vector3, b: Vector3, rail := true) -> void:
	var direction := (b-a).normalized()
	var center := (a+b)*.5
	var length := a.distance_to(b)
	var seat := box(center+Vector3.UP*.44,Vector3(length,.085,.27),"wood",.65)
	seat.rotation.y = -atan2(direction.z,direction.x)
	for at: Vector3 in [a+direction*.16,b-direction*.16]:
		box(at+Vector3.UP*.28,Vector3(.085,.28,.12),"architecture",.45)
	if not rail: return
	beam(a+Vector3.UP*.82,b+Vector3.UP*.82,.075,"architecture")
	for fraction in [.14,.5,.86]:
		var at: Vector3 = a.lerp(b,fraction)
		beam(at+Vector3.UP*.49,at+Vector3.UP*.79,.04,"patina")


func _hip(center: Vector3, width: float, depth: float, rise: float, ridge_ratio := .38) -> void:
	hip_roof(center,width,depth,rise,ridge_ratio)
	var hw := width*.5
	var hd := depth*.5
	# Three quiet tile courses and a few standing seams, readable at map scale.
	for side in [-1.0,1.0]:
		for n in range(1,4):
			var z: float = side*hd*n/4.0
			var course: Array[Vector3] = []
			for i in 17:
				var x := lerpf(-hw,hw,i/16.0)
				course.append(center+Vector3(x,_roof_y(x,z,hw,hd,hw*ridge_ratio,rise)+.004,z))
			ink(course,.24).set_meta("roof_occluder",true)
		for x in [-hw*.90,hw*.90]:
			box(center+Vector3(x,.018,side*hd*.92),Vector3(.052,.07,.15),"copper_dark",.4).set_meta("roof_occluder",true)


func _square_pavilion() -> void:
	name = "QuietSquarePavilion"
	footprint = Vector2(2.7,2.9)
	box(Vector3(0,.07,0),Vector3(2.64,.14,2.52),"architecture",.9)
	box(Vector3(0,.155,0),Vector3(2.48,.03,2.36),"stone",.65)
	box(Vector3(0,.035,1.35),Vector3(1.30,.07,.24),"stone",.6)
	box(Vector3(0,.10,1.23),Vector3(1.30,.06,.22),"stone",.55)
	for x in [-1.02,1.02]:
		for z in [-.98,.98]:
			_column(Vector3(x,.17,z),1.55)
			beam(Vector3(x,1.48,z),Vector3(x-signf(x)*.28,1.88,z),.06)
	for z in [-.98,.98]:
		box(Vector3(0,1.89,z),Vector3(2.40,.15,.16),"architecture",.75)
		for x in [-.68,0.0,.68]:
			ink([Vector3(x-.19,1.80,z),Vector3(x-.19,1.65,z),Vector3(x,1.65,z),Vector3(x,1.80,z),Vector3(x+.19,1.80,z)],.5)
	for x in [-1.02,1.02]:
		box(Vector3(x,1.89,0),Vector3(.16,.15,2.25),"architecture",.7)
		_seat(Vector3(x,.17,-.78),Vector3(x,.17,.66))
	_seat(Vector3(-.81,.17,-.99),Vector3(.81,.17,-.99))
	_hip(Vector3(0,2.04,0),3.16,3.02,.46,.31)
	box(Vector3(0,1.86,1.075),Vector3(.47,.20,.035),"patina",.55)
	ink([Vector3(-.16,1.92,1.096),Vector3(.16,1.92,1.096),Vector3(.16,1.81,1.096),Vector3(-.16,1.81,1.096)],.35,"bronze")
	lantern(Vector3(-.71,1.48,.62),.55)
	set_meta("solid_footprints",[Rect2(-1.16,-1.12,.28,2.28),Rect2(.88,-1.12,.28,2.28),Rect2(-.88,-1.13,1.76,.30)])
	set_meta("floor_height",.17)


func _hex_corner(index: int, radius: float, y: float) -> Vector3:
	var angle := PI/6+TAU*index/6.0
	return Vector3(cos(angle)*radius,y,sin(angle)*radius)


func _hex_pavilion() -> void:
	name = "HexagonalLotusPavilion"
	footprint = Vector2(2.7,3.0)
	var slab := cylinder(Vector3(0,.075,0),1.31,.15,"architecture",null,6)
	slab.rotation.y = -PI/6
	var paving := cylinder(Vector3(0,.16,0),1.23,.025,"stone",null,6)
	paving.rotation.y = -PI/6
	box(Vector3(0,.04,1.40),Vector3(1.1,.08,.25),"stone",.65)
	for i in 6:
		var a := _hex_corner(i,1.07,.17)
		var b := _hex_corner(i+1,1.07,.17)
		_column(a,1.48)
		beam(a+Vector3.UP*1.63,b+Vector3.UP*1.63,.13)
		beam(a+Vector3.UP*1.30,a.lerp(b,.24)+Vector3.UP*1.65,.055)
		if (a+b).z*.5<.40: _seat(a.lerp(b,.12),a.lerp(b,.88))
	_hex_roof()
	cylinder(Vector3(0,.39,0),.10,.43,"architecture",null,6)
	cylinder(Vector3(0,.625,0),.36,.075,"stone",null,8)
	for x in [-.49,.49]:
		cylinder(Vector3(x,.30,.26),.15,.27,"stone",null,6)
	lantern(Vector3(0,1.46,.30),.56)
	set_meta("floor_height",.173)
	var posts: Array = []
	for i in 6:
		var at := _hex_corner(i,1.07,0)
		posts.append(Rect2(at.x-.14,at.z-.14,.28,.28))
	set_meta("solid_footprints",posts)


func _hex_roof() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [.08,.72,1.22,1.62]
	var heights := [2.66,2.33,2.02,1.91]
	for side in 6:
		for band in 3:
			for strip in 5:
				var points: Array[Vector3] = []
				for corner: Vector2i in [Vector2i(band,strip),Vector2i(band,strip+1),Vector2i(band+1,strip+1),Vector2i(band+1,strip)]:
					var t := corner.y/5.0
					var at := _hex_corner(side,radii[corner.x],heights[corner.x]).lerp(_hex_corner(side+1,radii[corner.x],heights[corner.x]),t)
					at.y += .12*pow(absf(t-.5)*2,3)*pow(corner.x/3.0,3)
					points.append(at)
				var normal := (points[1]-points[0]).cross(points[3]-points[0]).normalized()
				if normal.y<0: normal = -normal
				_quad(surface,points,normal)
				_quad(surface,[points[0]-Vector3.UP*.045,points[1]-Vector3.UP*.045,points[2]-Vector3.UP*.045,points[3]-Vector3.UP*.045],-normal)
				if band==2:
					var side_normal := Vector3(points[2].x+points[3].x,0,points[2].z+points[3].z).normalized()
					_quad(surface,[points[3],points[2],points[2]-Vector3.UP*.045,points[3]-Vector3.UP*.045],side_normal)
	var roof := style.mesh(self,surface.commit(),Vector3.ZERO,"roof",1.05)
	roof.set_meta("roof_occluder",true)
	for i in 6:
		var a := _hex_corner(i,1.62,2.03)
		var b := _hex_corner(i+1,1.62,2.03)
		var eave: Array[Vector3] = []
		for j in 9:
			var t := j/8.0
			var at := a.lerp(b,t)
			at.y = 1.91+.12*pow(absf(t-.5)*2,3)
			eave.append(at)
		ink(eave,.60).set_meta("roof_occluder",true)
		for fraction in [.34,.67]:
			var left := _hex_corner(i,lerpf(.08,1.62,fraction),lerpf(2.66,1.91,fraction))
			var right := _hex_corner(i+1,lerpf(.08,1.62,fraction),left.y)
			# Correspond to actual stepped roof radii, not floating planar lines.
			var ring_index := 1 if fraction<.5 else 2
			left = _hex_corner(i,radii[ring_index],heights[ring_index]+.006)
			right = _hex_corner(i+1,radii[ring_index],heights[ring_index]+.006)
			ink([left,right],.26).set_meta("roof_occluder",true)
		ink([_hex_corner(i,.08,2.665),_hex_corner(i,.72,2.34),_hex_corner(i,1.22,2.06),a],.40).set_meta("roof_occluder",true)
		box(a+Vector3.UP*.015,Vector3(.055,.06,.085),"copper_dark",.3).set_meta("roof_occluder",true)
	cylinder(Vector3(0,2.70,0),.07,.12,"copper_dark",null,6).set_meta("roof_occluder",true)


func _rock(at: Vector3, size_value: Vector3, turn: float, seed_value: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for tier in 4:
		var ring: Array[Vector3] = []
		for n in 7:
			var angle := TAU*n/7.0+turn
			var irregular := .84+fposmod(n*1.73+tier*.31+seed_value*.23,1.0)*.24
			var radius: float = [1.0,1.08,.78,.35][tier]
			var p := Vector3(cos(angle)*radius*.5*irregular,[0.0,.28,.70,1.0][tier],sin(angle)*radius*.5*irregular)
			p.x += tier*.085
			p.z += sin(seed_value)*tier*.035
			ring.append(at+p*size_value)
		rings.append(ring)
	for tier in 3:
		for n in 7:
			var points: Array = [rings[tier][n],rings[tier][(n+1)%7],rings[tier+1][(n+1)%7],rings[tier+1][n]]
			var normal: Vector3 = (points[1]-points[0]).cross(points[3]-points[0]).normalized()
			if normal.dot((points[0]+points[1])*.5-at)<0: normal = -normal
			_quad(surface,points,normal)
	for n in range(1,6): _triangle(surface,rings[3][0],rings[3][n],rings[3][n+1],Vector3.UP)
	style.mesh(self,surface.commit(),Vector3.ZERO,"stone",.9)
	ink([rings[3][1],rings[2][1],rings[1][1]],.43)
	ink([rings[2][2],rings[1][2],rings[0][2]],.33)


func _low_rockery() -> void:
	name = "LowGardenRockery"
	footprint = Vector2(2.9,1.9)
	_rock(Vector3(-.48,0,-.16),Vector3(1.22,1.42,1.10),-.16,3)
	_rock(Vector3(.53,0,-.04),Vector3(1.13,.96,.95),.24,9)
	_rock(Vector3(-.07,0,.49),Vector3(1.29,.49,.76),-.31,12)
	_rock(Vector3(-1.03,0,.26),Vector3(.66,.55,.65),.21,5)
	_rock(Vector3(1.03,0,.30),Vector3(.64,.34,.60),-.12,17)
	# A few long rock seams carry the form; avoid speckle and pebble scatter.
	ink([Vector3(-.68,.96,.30),Vector3(-.49,.89,.41),Vector3(-.45,.72,.43)],.50)
	set_meta("solid_footprints",[Rect2(-1.36,-.68,2.72,1.55)])


func _hollow_rockery() -> void:
	name = "PiercedGardenScholarRock"
	footprint = Vector2(2.75,1.9)
	# The leaning, split summit is intentionally unlike a round stone ring.
	var outside: Array[Vector2] = [Vector2(.75,.95),Vector2(.78,1.44),Vector2(.48,1.62),Vector2(.38,2.05),Vector2(.32,2.58),Vector2(-.05,2.42),Vector2(-.40,2.66),Vector2(-.63,1.76),Vector2(-.66,1.10),Vector2(-.92,.72),Vector2(-.87,.38),Vector2(-.50,.09),Vector2(-.15,.02),Vector2(.26,.08),Vector2(.48,.38),Vector2(.67,.58)]
	var inside: Array[Vector2] = []
	for i in 16:
		var angle := (outside[i]-Vector2(-.03,.95)).angle()
		inside.append(Vector2(-.12+cos(angle)*(.22+.025*sin(i*1.9))+.04*sin(angle),.87+sin(angle)*(.34+.03*cos(i*1.3))))
	var front_outer: Array[Vector3] = []
	var front_shoulder: Array[Vector3] = []
	var front_inner: Array[Vector3] = []
	var back_outer: Array[Vector3] = []
	var back_inner: Array[Vector3] = []
	for i in 16:
		var a := outside[i]
		var b := inside[i]
		var shoulder := a.lerp(b,.22)
		front_outer.append(Vector3(a.x,a.y,.18+.06*sin(i*1.4)))
		front_shoulder.append(Vector3(shoulder.x,shoulder.y,.40+.045*cos(i*1.6)))
		front_inner.append(Vector3(b.x,b.y,.30))
		back_outer.append(Vector3(a.x+.09,a.y,-.29))
		back_inner.append(Vector3(b.x+.05,b.y,-.29))
	var stone := SurfaceTool.new(); stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var holes := SurfaceTool.new(); holes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		var j := (i+1)%16
		for band: Array in [[front_outer,front_shoulder],[front_shoulder,front_inner]]:
			var points: Array = [band[0][i],band[0][j],band[1][j],band[1][i]]
			var normal: Vector3 = (points[1]-points[0]).cross(points[3]-points[0]).normalized()
			if normal.z<0: normal = -normal
			_quad(stone,points,normal)
		_quad(stone,[back_outer[i],back_inner[i],back_inner[j],back_outer[j]],Vector3.FORWARD)
		var outward := Vector3(outside[i].x,outside[i].y-.99,0).normalized()
		_quad(stone,[front_outer[i],back_outer[i],back_outer[j],front_outer[j]],outward)
		var inward := -Vector3(inside[i].x+.06,inside[i].y-.96,0).normalized()
		_quad(holes,[front_inner[i],front_inner[j],back_inner[j],back_inner[i]],inward)
	style.mesh(self,stone.commit(),Vector3.ZERO,"stone",1.0)
	style.mesh(self,holes.commit(),Vector3.ZERO,"architecture",.4)
	# The aperture is real open geometry; these are creases on the stone shoulder.
	ink([front_shoulder[3],front_shoulder[4],front_shoulder[5]],.55)
	ink([front_shoulder[8],front_shoulder[9],front_shoulder[10]],.42)
	_rock(Vector3(-.94,0,-.02),Vector3(.73,.93,.82),.12,4)
	_rock(Vector3(.80,0,-.08),Vector3(.77,.67,.92),-.19,14)
	_rock(Vector3(.22,0,.43),Vector3(.92,.30,.64),.30,20)
	set_meta("solid_footprints",[Rect2(-1.30,-.62,2.63,1.38)])


func _window(center: Vector3, width: float, height: float, side := false) -> void:
	var holder := Node3D.new()
	holder.position = center
	holder.rotation.y = PI*.5 if side else 0.0
	add_child(holder)
	box(Vector3.ZERO,Vector3(width+.07,height+.07,.055),"copper_dark",.65,holder)
	box(Vector3(0,0,.032),Vector3(width-.07,height-.07,.025),"foreground",.25,holder)
	for x in [-width*.5,width*.5]: box(Vector3(x,0,.069),Vector3(.046,height+.035,.045),"architecture",.5,holder)
	for y in [-height*.5,height*.5]: box(Vector3(0,y,.069),Vector3(width,.045,.045),"architecture",.5,holder)
	for x in [-width*.25,0.0,width*.25]: box(Vector3(x,0,.064),Vector3(.025,height-.07,.035),"patina",.35,holder)
	for y in [-height*.22,height*.22]: box(Vector3(0,y,.073),Vector3(width-.06,.023,.025),"patina",.35,holder)
	# One broad fret at the center, rather than fine grilles across the whole facade.
	ink([Vector3(-width*.27,height*.08,.092),Vector3(-width*.09,height*.08,.092),Vector3(-width*.09,height*.30,.092),Vector3(width*.09,height*.30,.092),Vector3(width*.09,-height*.08,.092),Vector3(width*.27,-height*.08,.092)],.36,"ink",holder)


func _balcony_rail(a: Vector3, b: Vector3) -> void:
	beam(a+Vector3.UP*.49,b+Vector3.UP*.49,.065,"copper_dark")
	beam(a+Vector3.UP*.13,b+Vector3.UP*.13,.055,"architecture")
	var count := maxi(1,roundi(a.distance_to(b)/.38))
	for i in count+1:
		var at := a.lerp(b,float(i)/count)
		beam(at+Vector3.UP*.10,at+Vector3.UP*.49,.04,"patina")


func _small_loft() -> void:
	name = "TwoStoreyGardenLoft"
	footprint = Vector2(3.5,3.25)
	box(Vector3(0,.075,0),Vector3(3.03,.15,2.35),"architecture",.95)
	box(Vector3(0,.17,0),Vector3(2.86,.045,2.19),"stone",.6)
	for step in 3:
		box(Vector3(0,.025+step*.05,1.48-step*.14),Vector3(1.28,.05+step*.10,.18),"stone",.6)
	# Recessed ground-floor room inside its load-bearing timber frame.
	box(Vector3(0,.94,-.75),Vector3(2.45,1.50,.10),"wood",.65)
	for x in [-1.20,1.20]: box(Vector3(x,.94,0),Vector3(.10,1.50,1.52),"wood",.7)
	for x in [-1.21,1.21]:
		for z in [-.77,.78]: _column(Vector3(x,.19,z),1.37)
	for x in [-.89,.89]:
		box(Vector3(x,.94,.79),Vector3(.61,1.50,.09),"wood",.7)
		_window(Vector3(x,1.09,.85),.43,.57)
	box(Vector3(0,.83,.65),Vector3(1.06,1.28,.075),"wood",.75)
	for x in [-.56,.56]: box(Vector3(x,.89,.82),Vector3(.065,1.40,.10),"architecture",.65)
	box(Vector3(0,1.61,.82),Vector3(1.22,.10,.13),"architecture",.65)
	box(Vector3(0,.81,.697),Vector3(.025,1.25,.025),"architecture",.35)
	for x in [-.105,.105]: cylinder(Vector3(x,.86,.717),.035,.06,"bronze",null,6).rotation.x = PI*.5
	box(Vector3(.49,1.13,.89),Vector3(.11,.31,.014),"cloth",.35)
	_hip(Vector3(0,1.72,0),3.72,2.83,.26,.52)
	# Second floor projects a modest balcony above the first-storey eaves.
	box(Vector3(0,1.96,.21),Vector3(2.99,.12,2.26),"architecture",.8)
	box(Vector3(0,2.035,.22),Vector3(2.86,.025,2.10),"wood",.5)
	for x in [-1.16,1.16]:
		beam(Vector3(x,1.59,.78),Vector3(x,1.94,1.22),.11,"architecture")
	box(Vector3(0,2.59,-.67),Vector3(2.36,1.11,.10),"wood",.65)
	for x in [-1.13,1.13]: box(Vector3(x,2.59,0),Vector3(.10,1.11,1.36),"wood",.7)
	box(Vector3(0,2.59,.69),Vector3(2.34,1.11,.10),"wood",.65)
	for x in [-1.15,1.15]:
		for z in [-.68,.70]:
			box(Vector3(x,2.60,z),Vector3(.09,1.17,.10),"architecture",.65)
	_window(Vector3(0,2.64,.76),1.35,.67)
	_window(Vector3(1.20,2.64,-.04),.85,.63,true)
	for x in [-1.39,1.39]:
		_balcony_rail(Vector3(x,2.05,-.72),Vector3(x,2.05,1.24))
		box(Vector3(x,2.32,1.24),Vector3(.105,.60,.105),"architecture",.55)
	_balcony_rail(Vector3(-1.39,2.05,1.24),Vector3(1.39,2.05,1.24))
	box(Vector3(0,3.19,0),Vector3(2.57,.13,1.66),"architecture",.7)
	_hip(Vector3(0,3.29,0),3.24,2.40,.46,.40)
	box(Vector3(0,3.12,.87),Vector3(.45,.20,.035),"patina",.45)
	sign_text("阁",Vector3(0,3.12,.895),.0012)
	lantern(Vector3(-.73,1.31,1.02),.47)
	lantern(Vector3(.73,1.31,1.02),.47)
	set_meta("solid_footprints",[Rect2(-1.51,-1.18,3.02,2.36)])
	set_meta("entrance",Vector3(0,.195,1.10))


func _collect_roof_geometry(node: Node, inherited: bool) -> void:
	var roof := inherited or bool(node.get_meta("roof_occluder",false))
	if roof and node is GeometryInstance3D: _roof_geometry.append(node)
	for child in node.get_children(): _collect_roof_geometry(child,roof)


func set_roofs_faded(value: bool) -> void:
	for geometry in _roof_geometry: geometry.transparency = .82 if value else 0.0
