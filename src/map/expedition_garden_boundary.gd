extends "res://src/map/expedition_garden_asset_base.gd"
## A two-unit bay becomes one map grid edge at scale .5. Segments share posts.
enum Piece { RAIL, HALF_RAIL, RAIL_POST, RAIL_END, BROKEN_RAIL, RAIL_CORNER, WALL, WINDOW_WALL, WALL_POST, WALL_END, BROKEN_WALL, WALL_CORNER }
enum WindowPattern { KEY_FRET, BEGONIA, ICE_CRACK }
const PITCH := 2.0
@export var piece: Piece = Piece.RAIL
@export var window_pattern: WindowPattern = WindowPattern.KEY_FRET
var sockets: Array[Vector3] = []
var span := PITCH


func _build() -> void:
	name = ["RailBay","HalfRailBay","RailPost","RailEndPost","BrokenRailBay","RailCorner","WallBay","LatticeWallBay","WallPier","WallEndPier","BrokenWallBay","WallCorner"][piece]
	map_scale = .5
	span = 1.0 if piece==Piece.HALF_RAIL else PITCH
	set_meta("garden_piece",int(piece))
	set_meta("module_pitch",PITCH)
	set_meta("decorative_only",true)
	if piece in [Piece.RAIL_POST,Piece.RAIL_END,Piece.WALL_POST,Piece.WALL_END]:
		footprint = Vector2(.38,.38)
		_post(piece in [Piece.WALL_POST,Piece.WALL_END],piece in [Piece.RAIL_END,Piece.WALL_END])
		return
	if piece in [Piece.RAIL_CORNER,Piece.WALL_CORNER]:
		var wall := piece==Piece.WALL_CORNER
		_post(wall,false)
		for quarter in [0,1]:
			var arm := Node3D.new()
			arm.rotation.y = -quarter*PI*.5
			add_child(arm)
			if wall: _wall(arm,false,false)
			else: _rail(arm,PITCH,false)
		sockets = [Vector3(PITCH,0,0),Vector3(0,0,PITCH)]
		footprint = Vector2(PITCH+.4,PITCH+.4)
	else:
		sockets = [Vector3.ZERO,Vector3(span,0,0)]
		footprint = Vector2(span,.52 if piece>=Piece.WALL else .30)
		if piece>=Piece.WALL: _wall(self,piece==Piece.WINDOW_WALL,piece==Piece.BROKEN_WALL)
		else: _rail(self,span,piece==Piece.BROKEN_RAIL)
	set_meta("sockets",sockets)


func _post(wall: bool, terminal: bool) -> void:
	var width := .38 if wall else .30
	var height := 1.80 if wall else .93
	box(Vector3(0,.065,0),Vector3(width,.13,width),"architecture",.8)
	box(Vector3(0,height*.5+.07,0),Vector3(width*.68,height-.14,width*.68),"stone",.8)
	box(Vector3(0,height+.015,0),Vector3(width*.90,.09,width*.90),"architecture",.55)
	if wall:
		hip_roof(Vector3(0,height+.065,0),.57,.57,.14,.12)
		for side in [-1.0,1.0]:
			ink([Vector3(-.095,.35,side*width*.345),Vector3(-.095,1.55,side*width*.345)],.25)
	else:
		# A squat lotus shoulder, rather than a glowing or oversized finial.
		cylinder(Vector3(0,1.01,0),.105,.07,"stone",null,4)
		cylinder(Vector3(0,1.065,0),.065,.065,"patina",null,4)
		box(Vector3(0,.28,.106),Vector3(.09,.12,.012),"patina",.25)
		ink([Vector3(-.047,.29,.114),Vector3(0,.33,.114),Vector3(.047,.29,.114)],.23)
	if terminal:
		box(Vector3(0,height*.58,width*.35+.008),Vector3(width*.40,.20,.018),"patina",.3)
		ink([Vector3(-.035,height*.58+.06,width*.35+.02),Vector3(.035,height*.58+.06,width*.35+.02),Vector3(.035,height*.58-.06,width*.35+.02)],.24)


func _rail(parent: Node3D, length: float, broken: bool) -> void:
	var mid := length*.5
	box(Vector3(mid,.065,0),Vector3(length-.30,.13,.24),"architecture",.6,parent)
	box(Vector3(mid,.26,0),Vector3(length-.18,.075,.10),"stone",.45,parent)
	if not broken:
		box(Vector3(mid,.85,0),Vector3(length-.18,.105,.16),"stone",.8,parent)
		box(Vector3(mid,.91,0),Vector3(length-.24,.025,.115),"patina",.3,parent)
		var count := 3 if length>1.1 else 1
		for i in count:
			var x := length*(i+1.0)/(count+1.0)
			box(Vector3(x,.55,0),Vector3(.055,.51,.065),"stone",.4,parent)
		if length>1.1:
			for sign_value in [-1.0,1.0]:
				var x: float = mid+sign_value*.24
				beam(Vector3(x,.39,0),Vector3(x,.68,0),.035,"patina",parent)
				beam(Vector3(x,.68,0),Vector3(mid,.68,0),.035,"patina",parent)
				beam(Vector3(x,.39,0),Vector3(mid,.39,0),.035,"patina",parent)
		ink([Vector3(.23,.905,.080),Vector3(length*.60,.905,.080)],.23,"ink",parent)
	else:
		box(Vector3(.43,.85,0),Vector3(.60,.105,.16),"stone",.7,parent)
		var loose := box(Vector3(1.58,.51,.08),Vector3(.58,.105,.16),"stone",.6,parent)
		loose.rotation.z = -.48
		box(Vector3(.43,.55,0),Vector3(.055,.51,.065),"stone",.4,parent)
		var stump := box(Vector3(1.50,.38,0),Vector3(.055,.23,.065),"tomb_cut",.4,parent)
		stump.rotation.z = .13
		box(Vector3(1.12,.06,.16),Vector3(.34,.09,.14),"tomb_cut",.45,parent).rotation.y = .24
		ink([Vector3(.68,.895,.082),Vector3(.72,.85,.082),Vector3(.66,.81,.082)],.28,"ink",parent)


func _wall(parent: Node3D, window: bool, broken: bool) -> void:
	box(Vector3(1,.075,0),Vector3(1.72,.15,.43),"architecture",.7,parent)
	if broken:
		profile(PackedVector2Array([Vector2(.14,.15),Vector2(1.86,.15),Vector2(1.86,.71),Vector2(1.68,.92),Vector2(1.40,.73),Vector2(1.16,1.04),Vector2(.98,1.01),Vector2(.72,1.35),Vector2(.48,1.25),Vector2(.14,1.51)]),.30,Vector3.ZERO,"stone",.85,parent)
		for side in [-1.0,1.0]:
			ink([Vector3(.45,1.25,side*.153),Vector3(.56,1.03,side*.153),Vector3(.79,.94,side*.153),Vector3(.84,.71,side*.153)],.34,"ink",parent)
		for i in 3:
			box(Vector3(.87+i*.30,.045,.32+(i%2)*.12),Vector3(.27,.09,.18),"tomb_cut",.45,parent).rotation.y = i*.21
		return
	if window:
		# Yellowed paper fills the real octagonal aperture behind the fretwork.
		# Its dark-gold tone stays legible at map scale without glowing like a lamp.
		var paper := box(Vector3(1,1.075,.115),Vector3(.98,.82,.018),"garden_paper",.08,parent)
		paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box(Vector3(1,.67,.17),Vector3(1.08,.055,.04),"wood",.24,parent)
		box(Vector3(1,1.48,.17),Vector3(1.08,.055,.04),"wood",.24,parent)
		beam(Vector3(.52,.72,.17),Vector3(.52,1.43,.17),.055,"wood",parent)
		beam(Vector3(1.48,.72,.17),Vector3(1.48,1.43,.17),.055,"wood",parent)
		box(Vector3(1,.74,.205),Vector3(1.24,.035,.035),"bronze",.20,parent)
		box(Vector3(1,1.46,.205),Vector3(1.24,.035,.035),"bronze",.20,parent)
		beam(Vector3(.72,.70,.19),Vector3(.72,1.45,.19),.028,"wood",parent)
		beam(Vector3(1.28,.70,.19),Vector3(1.28,1.45,.19),.028,"wood",parent)
		beam(Vector3(.52,1.075,.19),Vector3(1.48,1.075,.19),.030,"wood",parent)
		box(Vector3(.31,.95,0),Vector3(.38,1.62,.30),"stone",.7,parent)
		box(Vector3(1.69,.95,0),Vector3(.38,1.62,.30),"stone",.7,parent)
		box(Vector3(1,.38,0),Vector3(1.04,.46,.30),"stone",.65,parent)
		box(Vector3(1,1.65,0),Vector3(1.04,.22,.30),"stone",.65,parent)
		# A real octagonal opening. The four corner wedges are wall material.
		for flip_x in [-1.0,1.0]:
			for flip_y in [-1.0,1.0]:
				var x: float = 1.0+flip_x*.52
				var y: float = 1.075+flip_y*.465
				profile(PackedVector2Array([Vector2(x,y),Vector2(x-flip_x*.16,y),Vector2(x,y-flip_y*.16)]),.30,Vector3.ZERO,"stone",.45,parent)
		var ring: Array[Vector3] = []
		for point in [Vector2(-.36,-.465),Vector2(.36,-.465),Vector2(.52,-.305),Vector2(.52,.305),Vector2(.36,.465),Vector2(-.36,.465),Vector2(-.52,.305),Vector2(-.52,-.305),Vector2(-.36,-.465)]:
			ring.append(Vector3(1+point.x,1.075+point.y,.01))
		for i in range(ring.size()-1): beam(ring[i],ring[i+1],.055,"patina",parent)
		_window_lattice(parent)
		_window_relief(parent)
	else:
		box(Vector3(1,.96,0),Vector3(1.76,1.62,.30),"stone",.85,parent)
		for side in [-1.0,1.0]:
			# Large quiet stone faces: only a few mortar seams and cracks.
			ink([Vector3(.18,.62,side*.152),Vector3(.59,.62,side*.152)],.27,"ink",parent)
			ink([Vector3(1.24,1.32,side*.152),Vector3(1.84,1.32,side*.152)],.25,"ink",parent)
			ink([Vector3(1.62,.17,side*.154),Vector3(1.58,.35,side*.154),Vector3(1.65,.48,side*.154)],.26,"ink",parent)
	# A constant cross-section makes straight coping meet without roof humps.
	var coping := profile(PackedVector2Array([Vector2(-.25,1.79),Vector2(-.25,1.84),Vector2(-.16,1.96),Vector2(0,2.005),Vector2(.16,1.96),Vector2(.25,1.84),Vector2(.25,1.79)]),1.72,Vector3(1,0,0),"roof",.8,parent)
	coping.rotation.y = PI*.5
	for x in [.32,.77,1.22,1.67]:
		ink([Vector3(x,1.847,.242),Vector3(x,1.963,.158),Vector3(x,2.008,0)],.23,"ink",parent)
	box(Vector3(1,1.765,0),Vector3(1.74,.045,.34),"architecture",.45,parent)
	# Window piers visibly join the lintel and the lower wall beam.
	beam(Vector3(.13,.42,0),Vector3(.13,1.80,0),.075,"architecture",parent)
	beam(Vector3(1.87,.42,0),Vector3(1.87,1.80,0),.075,"architecture",parent)
	beam(Vector3(.13,1.80,0),Vector3(.52,1.80,0),.075,"architecture",parent)
	beam(Vector3(1.48,1.80,0),Vector3(1.87,1.80,0),.075,"architecture",parent)


func _window_path(parent: Node3D, points: Array, weight := .035, depth := .01) -> void:
	for n in range(points.size()-1):
		var a: Vector2 = points[n]
		var b: Vector2 = points[n+1]
		var lattice := beam(Vector3(1+a.x,1.075+a.y,depth),Vector3(1+b.x,1.075+b.y,depth),weight,"patina",parent)
		lattice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _window_relief(parent: Node3D) -> void:
	# A recessed central medallion and four stepped cloud hooks make the
	# lattice read as carved garden joinery instead of two crossing bars.
	for side in [-1.0, 1.0]:
		var medallion := cylinder(Vector3(1,1.075,side*.205),.135,.035,"patina",parent,8)
		medallion.rotation.x = PI*.5
		medallion.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var motif := [Vector2(-.15,-.15),Vector2(.0,-.28),Vector2(.15,-.15),Vector2(.28,0),Vector2(.15,.15),Vector2(0,.28),Vector2(-.15,.15),Vector2(-.28,0),Vector2(-.15,-.15)]
		_window_path(parent,motif,.032,side*.205)
		for sign_value in [-1.0,1.0]:
			_window_path(parent,[Vector2(sign_value*.37,-.31),Vector2(sign_value*.31,-.24),Vector2(sign_value*.31,-.12)],.034,side*.205)
			_window_path(parent,[Vector2(sign_value*.37,.31),Vector2(sign_value*.31,.24),Vector2(sign_value*.31,.12)],.034,side*.205)
		# Narrow inner rails sit behind the raised motifs and create depth.
		_window_path(parent,[Vector2(-.42,-.34),Vector2(-.42,.34)],.024,side*.205)
		_window_path(parent,[Vector2(.42,-.34),Vector2(.42,.34)],.024,side*.205)
		_window_path(parent,[Vector2(-.34,-.38),Vector2(.34,-.38)],.024,side*.205)
		_window_path(parent,[Vector2(-.34,.38),Vector2(.34,.38)],.024,side*.205)


func _window_lattice(parent: Node3D) -> void:
	# Real recessed, double-sided stone/bronze lattice. The opening stays closed
	# to traversal; the motifs are garden fretwork, never door-shaped openings.
	set_meta("window_pattern",int(window_pattern))
	match window_pattern:
		WindowPattern.KEY_FRET:
			for r in [.28,.12]:
				_window_path(parent,[Vector2(-r,-r),Vector2(r,-r),Vector2(r,r),Vector2(-r,r),Vector2(-r,-r)],.036)
			for sign_value in [-1.0,1.0]:
				_window_path(parent,[Vector2(sign_value*.52,0),Vector2(sign_value*.28,0)],.040)
				_window_path(parent,[Vector2(0,sign_value*.465),Vector2(0,sign_value*.28)],.040)
			for turn in 4:
				var path: Array = []
				for point: Vector2 in [Vector2(.28,.12),Vector2(.12,.12),Vector2(.12,.28)]: path.append(point.rotated(turn*PI*.5))
				_window_path(parent,path,.031)
		WindowPattern.BEGONIA:
			_window_path(parent,[Vector2(-.30,-.11),Vector2(-.13,-.11),Vector2(-.13,-.29),Vector2(.13,-.29),Vector2(.13,-.11),Vector2(.30,-.11),Vector2(.30,.11),Vector2(.13,.11),Vector2(.13,.29),Vector2(-.13,.29),Vector2(-.13,.11),Vector2(-.30,.11),Vector2(-.30,-.11)],.040)
			_window_path(parent,[Vector2(0,-.10),Vector2(.10,0),Vector2(0,.10),Vector2(-.10,0),Vector2(0,-.10)],.030)
			for sign_value in [-1.0,1.0]:
				_window_path(parent,[Vector2(sign_value*.52,0),Vector2(sign_value*.30,0)],.036)
				_window_path(parent,[Vector2(0,sign_value*.465),Vector2(0,sign_value*.29)],.036)
		WindowPattern.ICE_CRACK:
			for points in [
				[Vector2(-.52,-.12),Vector2(-.13,-.05),Vector2(.03,.20),Vector2(-.16,.465)],
				[Vector2(-.13,-.05),Vector2(-.02,-.29),Vector2(.20,-.465)],
				[Vector2(.03,.20),Vector2(.29,.16),Vector2(.52,.25)],
				[Vector2(.29,.16),Vector2(.20,-.12),Vector2(.52,-.25)],
				[Vector2(.20,-.12),Vector2(-.02,-.29)],
				[Vector2(-.13,-.05),Vector2(-.30,.18),Vector2(-.52,.25)]
			]: _window_path(parent,points,.034)


static func assemble(parent: Node3D, paint: ExpeditionFlatStyle, points: Array[Vector3], wall := false, closed := false, windows := false) -> Node3D:
	var result := Node3D.new()
	result.name = "JoinedGardenWall" if wall else "JoinedGardenRail"
	parent.add_child(result)
	var posts: Dictionary = {}
	var segment_count := 0
	var module_script: Script = load("res://src/map/expedition_garden_boundary.gd")
	for i in range(points.size() if closed else points.size()-1):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var vector := b-a
		assert(absf(vector.x)<.001 or absf(vector.z)<.001,"Garden paths use orthogonal grid edges")
		var length := vector.length()
		var direction := vector.normalized()
		var full := floori(length/PITCH+.001)
		var remainder := length-full*PITCH
		assert(remainder<.001 or is_equal_approx(remainder,1.0),"Garden bays support a full or half module")
		for n in range(full+(1 if remainder>.01 else 0)):
			var origin := a+direction*(n*PITCH)
			var half := n==full
			var section: Node3D = module_script.new()
			section.piece = Piece.WINDOW_WALL if wall and windows and not half and segment_count%2==1 else (Piece.WALL if wall else (Piece.HALF_RAIL if half else Piece.RAIL))
			section.window_pattern = (segment_count/2)%3
			section.position = origin
			section.rotation.y = -atan2(direction.z,direction.x)
			if wall and half: section.scale.x = .5 # Solid infill; never squash a lattice window.
			result.add_child(section)
			section.setup(paint)
			for endpoint in [origin,origin+direction*(1.0 if half else PITCH)]:
				var key := Vector3i(roundi(endpoint.x*100),roundi(endpoint.y*100),roundi(endpoint.z*100))
				posts[key] = endpoint
			segment_count += 1
	for point: Vector3 in posts.values():
		var post: Node3D = module_script.new()
		post.piece = Piece.WALL_POST if wall else Piece.RAIL_POST
		if not closed and (point.is_equal_approx(points.front()) or point.is_equal_approx(points.back())):
			post.piece = Piece.WALL_END if wall else Piece.RAIL_END
		post.position = point
		result.add_child(post)
		post.setup(paint)
	result.set_meta("post_count",posts.size())
	result.set_meta("segment_count",segment_count)
	result.set_meta("closed",closed)
	result.set_meta("post_positions",posts.values())
	return result
