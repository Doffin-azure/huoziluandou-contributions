extends "res://src/map/expedition_garden_asset_base.gd"
## Small native garden assets. Dimensions are world units; roofs have no solid footprint.
enum Kind { WATER_PAVILION, ROCK_BED, TYPE_CABINET, STELE_PLINTH, STONE_TABLE, WRITING_DESK, STONE_BENCH, INCENSE_BURNER, LOTUS_TUB, TYPE_RACK }
@export var kind: Kind = Kind.WATER_PAVILION


func _build() -> void:
	map_scale = 1.0
	match kind:
		Kind.WATER_PAVILION: _water_pavilion()
		Kind.ROCK_BED: _rock_bed()
		Kind.TYPE_CABINET: _type_cabinet()
		Kind.STELE_PLINTH: _stele_plinth()
		Kind.STONE_TABLE: _stone_table()
		Kind.WRITING_DESK: _writing_desk()
		Kind.STONE_BENCH: _stone_bench()
		Kind.INCENSE_BURNER: _incense_burner()
		Kind.LOTUS_TUB: _lotus_tub()
		Kind.TYPE_RACK: _type_rack()


func _stone_table() -> void:
	footprint = Vector2(1.8,.95)
	cylinder(Vector3(0,.22,0),.14,.44,"architecture",null,6)
	cylinder(Vector3(0,.47,0),.44,.09,"stone",null,8)
	for x in [-.70,.70]:
		cylinder(Vector3(x,.16,0),.14,.32,"architecture",null,6)
		cylinder(Vector3(x,.34,0),.19,.06,"stone",null,8)
	# A closed book and one cup carry the scale without small filigree.
	box(Vector3(-.08,.54,.02),Vector3(.22,.05,.30),"cloth",.45)
	cylinder(Vector3(.22,.55,-.10),.055,.08,"bronze",null,6)


func _writing_desk() -> void:
	footprint = Vector2(1.35,.70)
	box(Vector3(0,.58,0),Vector3(1.35,.085,.64),"wood",.85)
	for x in [-.53,.53]:
		for z in [-.23,.23]: box(Vector3(x,.27,z),Vector3(.075,.54,.075),"architecture",.55)
	box(Vector3(0,.39,-.20),Vector3(1.12,.055,.055),"architecture",.45)
	box(Vector3(-.18,.631,.02),Vector3(.46,.012,.36),"tomb_cut",.25)
	for x in [-.36,-.26,-.16]:
		ink([Vector3(x,.641,-.09),Vector3(x+.025,.641,.12)],.28)
	box(Vector3(.36,.66,-.12),Vector3(.20,.045,.14),"tomb_recess",.45)
	beam(Vector3(.30,.69,-.04),Vector3(.48,.69,.16),.015,"bronze")
	box(Vector3(.29,.65,.16),Vector3(.18,.035,.16),"cloth",.35)


func _stone_bench() -> void:
	footprint = Vector2(1.50,.52)
	box(Vector3(0,.38,0),Vector3(1.50,.10,.48),"stone",.8)
	for x in [-.50,.50]: box(Vector3(x,.17,0),Vector3(.20,.34,.36),"architecture",.6)
	ink([Vector3(-.54,.435,.18),Vector3(.54,.435,.18)],.28)


func _incense_burner() -> void:
	footprint = Vector2(.68,.60)
	box(Vector3(0,.04,0),Vector3(.63,.08,.53),"stone",.7)
	for x in [-.19,.19]:
		for z in [-.14,.14]: beam(Vector3(x,.08,z),Vector3(x*.85,.26,z*.85),.055,"copper_dark")
	cylinder(Vector3(0,.31,0),.25,.21,"patina",null,8)
	cylinder(Vector3(0,.42,0),.28,.05,"bronze",null,8)
	cylinder(Vector3(0,.451,0),.22,.012,"tomb_recess",null,8)
	for x in [-.10,0.0,.10]:
		beam(Vector3(x,.46,0),Vector3(x,.75+(.04 if x==0 else 0),-.035),.012,"wood")
	for x in [-.31,.31]:
		beam(Vector3(x,.28,0),Vector3(x,.46,0),.04,"bronze")
		beam(Vector3(x,.46,0),Vector3(x*.67,.46,0),.04,"bronze")


func _lotus_tub() -> void:
	footprint = Vector2(.90,.90)
	cylinder(Vector3(0,.06,0),.34,.12,"architecture",null,8)
	# Real hollow rim, with water and a small lotus below its upper lip.
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in 12:
		var a := TAU*n/12.0; var b := TAU*(n+1)/12.0
		var aa := Vector3(cos(a),0,sin(a)); var bb := Vector3(cos(b),0,sin(b))
		_quad(surface,[aa*.32+Vector3.UP*.10,bb*.32+Vector3.UP*.10,bb*.43+Vector3.UP*.44,aa*.43+Vector3.UP*.44],(aa+bb).normalized())
		_quad(surface,[aa*.43+Vector3.UP*.44,bb*.43+Vector3.UP*.44,bb*.35+Vector3.UP*.44,aa*.35+Vector3.UP*.44],Vector3.UP)
		_quad(surface,[aa*.35+Vector3.UP*.44,bb*.35+Vector3.UP*.44,bb*.31+Vector3.UP*.32,aa*.31+Vector3.UP*.32],-(aa+bb).normalized())
	style.mesh(self,surface.commit(),Vector3.ZERO,"stone",.7)
	cylinder(Vector3(0,.35,0),.33,.015,"tomb_recess",null,12)
	var flower := preload("res://src/map/expedition_lotus_tile.gd").new()
	flower.plants_only = true; flower.water_height = 0
	flower.position.y = .36; flower.scale = Vector3.ONE*.29
	add_child(flower); flower.setup(style)


func _type_rack() -> void:
	footprint = Vector2(1.05,.48)
	for x in [-.46,.46]:
		box(Vector3(x,.62,0),Vector3(.07,1.24,.08),"architecture",.65)
		box(Vector3(x,.045,0),Vector3(.19,.09,.45),"stone",.5)
	for y in [.20,.65,1.10]:
		box(Vector3(0,y,0),Vector3(1.05,.06,.43),"wood",.6)
		for n in 3:
			box(Vector3((n-1)*.27,y+.13,-.02),Vector3(.20,.20,.24),"stone" if n%2 else "architecture",.45)
	box(Vector3(0,1.27,0),Vector3(1.12,.08,.50),"roof",.65)


func _water_pavilion() -> void:
	name = "LotusWaterPavilion"
	footprint = Vector2(2.6,1.5)
	# One continuous roof; open passage below, without an extra raised floor.
	for x in [-1.2,1.2]:
		for z in [-.65,.65]:
			box(Vector3(x,.055,z),Vector3(.24,.11,.24),"stone",.65)
			box(Vector3(x,.82,z),Vector3(.105,1.46,.105),"architecture",.8)
			box(Vector3(x,.22,z),Vector3(.145,.16,.145),"patina",.4)
			box(Vector3(x,1.53,z),Vector3(.22,.12,.22),"copper_dark",.5)
			beam(Vector3(x,1.30,z),Vector3(x-signf(x)*.28,1.60,z),.055)
			ink([Vector3(x-.025,.34,z+.055),Vector3(x-.025,1.40,z+.055)],.3)
	for z in [-.65,.65]:
		box(Vector3(0,1.61,z),Vector3(2.65,.15,.14),"architecture",.7)
		box(Vector3(0,1.71,z),Vector3(2.75,.045,.18),"copper_dark",.45)
		for x in [-.79,0.0,.79]:
			ink([Vector3(x-.24,1.50,z),Vector3(x-.24,1.38,z),Vector3(x,1.38,z),Vector3(x,1.51,z),Vector3(x+.24,1.51,z)],.45)
	for x in [-1.2,1.2]:
		box(Vector3(x,1.61,0),Vector3(.14,.15,1.46),"architecture",.65)
		# Seats belong to the side bays, leaving the central route open.
		box(Vector3(x,.39,0),Vector3(.24,.09,.86),"wood",.65)
		for z in [-.32,.32]: box(Vector3(x,.22,z),Vector3(.11,.30,.11),"architecture",.4)
	hip_roof(Vector3(0,1.77,0),3.04,1.99,.38,.43)
	# Readable tile courses and folded eaves at map scale, without noisy filigree.
	for side in [-1.0,1.0]:
		for n in range(1,4):
			var z: float = side*.995*n/4.0
			var path: Array[Vector3] = []
			for i in 17:
				var x := lerpf(-1.52,1.52,i/16.0)
				path.append(Vector3(x,1.775+_roof_y(x,z,1.52,.995,1.52*.43,.38),z))
			ink(path,.22).set_meta("roof_occluder",true)
		for x in [-1.33,1.33]:
			box(Vector3(x,1.77,side*.91),Vector3(.055,.075,.13),"copper_dark",.4).set_meta("roof_occluder",true)
	box(Vector3(0,1.58,.735),Vector3(.42,.19,.036),"patina",.55)
	sign_text("息",Vector3(0,1.58,.758),.0013)
	lantern(Vector3(-.78,1.25,.27),.54)


func _rock_bed() -> void:
	name = "GardenRockPlantingBed"
	footprint = Vector2(1.3,1.05)
	var edge: Array[Vector3] = [Vector3(-.63,.08,-.50),Vector3(.42,.08,-.50),Vector3(.65,.08,-.21),Vector3(.65,.08,.50),Vector3(-.43,.08,.50),Vector3(-.63,.08,.28)]
	# Soil is a single quiet inset, with an angular stone rim and no paving through it.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,edge.size()-1): _triangle(surface,edge[0],edge[i],edge[i+1],Vector3.UP)
	style.mesh(self,surface.commit(),Vector3.ZERO,"wood",0)
	for i in edge.size(): beam(edge[i],edge[(i+1)%edge.size()],.09,"stone")
	_rock(Vector3(-.43,.07,-.20),Vector3(.34,.44,.30),-.19)
	_rock(Vector3(-.19,.07,.25),Vector3(.38,.25,.28),.27)
	_rock(Vector3(.40,.07,-.30),Vector3(.28,.32,.31),.34)


func _rock(at: Vector3, size_value: Vector3, turn: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for tier in 3:
		var ring: Array[Vector3] = []
		for n in 7:
			var angle := TAU*n/7.0+turn
			var radius := [1.0,1.08,.54][tier] as float
			var irregular := .85+fposmod(n*1.73+tier*.37,1.0)*.25
			var point := Vector3(cos(angle)*radius*.5*irregular,[0.0,.55,1.0][tier],sin(angle)*radius*.5*irregular)
			point.x += tier*.09
			ring.append(at+point*size_value)
		rings.append(ring)
	for tier in 2:
		for n in 7:
			var j := (n+1)%7
			var points: Array = [rings[tier][n],rings[tier][j],rings[tier+1][j],rings[tier+1][n]]
			var normal: Vector3 = (points[1]-points[0]).cross(points[3]-points[0]).normalized()
			if normal.dot((points[0]+points[1])*.5-at)<0: normal = -normal
			_quad(surface,points,normal)
	for n in range(1,6): _triangle(surface,rings[2][0],rings[2][n],rings[2][n+1],Vector3.UP)
	style.mesh(self,surface.commit(),Vector3.ZERO,"stone",.8)
	ink([rings[2][1],rings[1][1],rings[0][1]],.34)


func _type_cabinet() -> void:
	name = "BronzeTypeCabinet"
	footprint = Vector2(.96,.65)
	box(Vector3(0,.06,0),Vector3(1.04,.12,.70),"stone",.7)
	box(Vector3(0,.49,0),Vector3(.92,.78,.59),"wood",.85)
	box(Vector3(0,.92,0),Vector3(1.05,.10,.72),"roof",.7)
	for x in [-.44,.44]:
		box(Vector3(x,.49,.31),Vector3(.07,.80,.06),"architecture",.55)
	for row in 4:
		for col in 3:
			var x := (col-1)*.27
			var y := .21+row*.18
			box(Vector3(x,y,.311),Vector3(.242,.145,.043),"architecture",.45)
			box(Vector3(x,y+.017,.343),Vector3(.056,.030,.014),"bronze",.3)
			ink([Vector3(x-.04,y-.025,.337),Vector3(x+.04,y-.025,.337)],.22)
	box(Vector3(.23,1.025,0),Vector3(.30,.10,.26),"wood",.4)
	box(Vector3(-.24,1.00,.03),Vector3(.23,.05,.34),"stone",.4)
	box(Vector3(0,.86,.337),Vector3(.18,.11,.028),"patina",.35)
	sign_text("字",Vector3(0,.86,.355),.0009)


func _stele_plinth() -> void:
	name = "SteleStonePlinth"
	footprint = Vector2(1.1,.78)
	box(Vector3(0,.045,0),Vector3(1.12,.09,.82),"architecture",.7)
	box(Vector3(0,.12,0),Vector3(1.02,.06,.72),"stone",.55)
	for x in [-.40,.40]:
		ink([Vector3(x-.045,.077,.414),Vector3(x+.045,.077,.414)],.3)
