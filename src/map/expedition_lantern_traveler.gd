extends "res://src/map/expedition_garden_asset_base.gd"
## Native, faceted character study. Front is +Z; soles are on Y=0.
## No texture, billboard, game state or gameplay RNG is used.
const COSTUME = preload("res://assets/expedition/characters/lantern_traveler_palette.tres")
const PAINT = preload("res://src/shaders/expedition_traveler_paint.gdshader")
# Elongate the body below the neck while keeping the hood and lantern shapes.
const BODY_PROPORTIONS := Vector3(.92,1.08,1.0)
const NECK_HEIGHT := 2.35
const HAND_GRIP := Vector3(-.71,1.105,.19)
const LANTERN_GRIP := Vector3(-.96,1.17,.19)
@export var costume_palette: Resource = COSTUME
@export var idle_enabled := false
@export_range(0.0, 4.0, .05) var lantern_energy := .85:
	set(value):
		lantern_energy = value
		if lantern_light!=null: lantern_light.light_energy = value
var body_root: Node3D
var head_root: Node3D
var scarf_root: Node3D
var lantern_root: Node3D
var lantern_light: OmniLight3D
var triangle_count := 0
var _costume_materials: Dictionary = {}
var _time := 0.0


func _build() -> void:
	map_scale = .43
	footprint = Vector2(1.7, .95)
	set_meta("art_only",true)
	set_meta("source_height",3.24+NECK_HEIGHT*(BODY_PROPORTIONS.y-1.0))
	body_root = _group("Body",self)
	body_root.scale = BODY_PROPORTIONS
	head_root = _group("HoodAndMask",body_root)
	head_root.scale.y = 1.0/BODY_PROPORTIONS.y
	head_root.position.y = NECK_HEIGHT*(1.0-head_root.scale.y)
	scarf_root = _group("ScarfTails",body_root)
	scarf_root.position.x = .14
	lantern_root = _group("CarriedLantern",self)
	lantern_root.position = BODY_PROPORTIONS*HAND_GRIP-LANTERN_GRIP
	_legs()
	_robe()
	_arms()
	_cape()
	_hood()
	_mask()
	_scarf()
	_equipment()
	_lantern()
	costume_palette.changed.connect(refresh_costume)
	refresh_costume()
	set_meta("triangle_count",triangle_count)


func _exit_tree() -> void:
	if costume_palette.changed.is_connected(refresh_costume): costume_palette.changed.disconnect(refresh_costume)
	super._exit_tree()


func _process(delta: float) -> void:
	super._process(delta)
	if body_root==null or not idle_enabled: return
	_time += delta
	body_root.position.y = sin(_time*1.65)*.009
	scarf_root.rotation.x = sin(_time*1.2)*.012
	lantern_root.rotation.z = sin(_time*1.3)*.018
	lantern_root.position = BODY_PROPORTIONS*HAND_GRIP-lantern_root.basis*LANTERN_GRIP+body_root.position
	lantern_light.light_energy = lantern_energy*(.97+.03*sin(_time*5.3))


func refresh_costume() -> void:
	for role: String in _costume_materials:
		var key := "lamp" if role=="lens" else role
		var color: Color = costume_palette.get(key)
		_costume_materials[role].set_shader_parameter("pigment",color)
	if lantern_light!=null: lantern_light.light_color = costume_palette.lamp


func set_lamps_enabled(value: bool) -> void:
	super.set_lamps_enabled(value)
	if lantern_light!=null: lantern_light.visible = value


func _group(label: String, parent: Node3D) -> Node3D:
	var result := Node3D.new()
	result.name = label
	parent.add_child(result)
	return result


func _material(role: String) -> ShaderMaterial:
	if not _costume_materials.has(role):
		var result := ShaderMaterial.new()
		result.shader = PAINT
		result.set_shader_parameter("emissive",1.2 if role=="lamp" else (.3 if role=="lens" else 0.0))
		_costume_materials[role] = result
	return _costume_materials[role]


func _part(label: String, mesh: Mesh, role: String, parent: Node3D, outline := .55) -> MeshInstance3D:
	var node := style.mesh(parent,mesh,Vector3.ZERO,"cloth",outline)
	node.name = label
	node.material_override = _material(role)
	if label in ["ScarfFrontFold","KeyStem","BuckleHole","CinnabarEye","LensRim","ClaspRecess","ClaspSeal","TalismanTassel","LampPaperSeal","LampRedTassel"]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		triangle_count += (indices.size() if indices!=null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
	return node


func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, value := 1.0) -> void:
	var normal := (b-a).cross(c-a).normalized()
	if normal.dot(outward)<0: normal = -normal
	for p: Vector3 in ([a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]):
		surface.set_normal(normal)
		surface.set_color(Color(value,value,value))
		surface.add_vertex(p)


func _face(surface: SurfaceTool, points: Array, outward: Vector3, value := 1.0) -> void:
	for n in range(1,points.size()-1): _tri(surface,points[0],points[n],points[n+1],outward,value)


func _ring(center: Vector3, width: float, depth: float, sides := 8, phase := PI/8) -> PackedVector3Array:
	var result := PackedVector3Array()
	for n in sides:
		var a := TAU*n/sides+phase
		result.append(center+Vector3(sin(a)*width,0,cos(a)*depth))
	return result


func _loft(label: String, rings: Array, role: String, parent: Node3D, cap := true, outline := .6) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = rings[0].size()
	for level in range(rings.size()-1):
		for n in count:
			var k := (n+1)%count
			var a: Vector3 = rings[level][n]
			var b: Vector3 = rings[level][k]
			var c: Vector3 = rings[level+1][k]
			var d: Vector3 = rings[level+1][n]
			var normal := Vector3((a.x+b.x+c.x+d.x)*.25,0,(a.z+b.z+c.z+d.z)*.25)
			var center := Vector3.ZERO
			for p: Vector3 in rings[level]: center += p/float(count)
			normal -= Vector3(center.x,0,center.z)
			_face(surface,[a,b,c,d],normal,1.0-.035*((n+level)%3))
	if cap:
		for index in [0,rings.size()-1]:
			var center := Vector3.ZERO
			for p: Vector3 in rings[index]: center += p/float(count)
			for n in count: _tri(surface,center,rings[index][n],rings[index][(n+1)%count],Vector3.DOWN if index==0 else Vector3.UP)
	return _part(label,surface.commit(),role,parent,outline)


func _panel(label: String, points: Array[Vector3], thickness: float, role: String, parent: Node3D, outline := .5) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xy := PackedVector2Array()
	var center := Vector3.ZERO
	for p in points:
		xy.append(Vector2(p.x,p.y))
		center += p/float(points.size())
	var indices := Geometry2D.triangulate_polygon(xy)
	for side in [-1.0,1.0]:
		var offset := Vector3(0,0,side*thickness*.5)
		for n in range(0,indices.size(),3): _tri(surface,points[indices[n]]+offset,points[indices[n+1]]+offset,points[indices[n+2]]+offset,Vector3(0,0,side),.96 if side<0 else 1.0)
	for n in points.size():
		var a := points[n]
		var b := points[(n+1)%points.size()]
		var d := Vector3(0,0,thickness*.5)
		_face(surface,[a-d,b-d,b+d,a+d],(a+b)*.5-center,.88)
	return _part(label,surface.commit(),role,parent,outline)


func _block(label: String, at: Vector3, size: Vector3, role: String, parent: Node3D, outline := .4) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var node := _part(label,shape,role,parent,outline)
	node.position = at
	return node


func _segment(label: String, a: Vector3, b: Vector3, radius: float, role: String, parent: Node3D, sides := 6) -> MeshInstance3D:
	var node := _loft(label,[_ring(Vector3.ZERO,radius,radius,sides),_ring(Vector3(0,a.distance_to(b),0),radius*.84,radius*.84,sides)],role,parent,true,.4)
	node.position = a
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return node


func _disc(label: String, at: Vector3, radius: float, depth: float, role: String, parent: Node3D, sides := 8) -> MeshInstance3D:
	var node := _loft(label,[_ring(Vector3(0,-depth*.5,0),radius,radius,sides),_ring(Vector3(0,depth*.5,0),radius,radius,sides)],role,parent,true,.35)
	node.rotation.x = PI*.5
	node.position = at
	return node


func _legs() -> void:
	for sign_value in [-1.0,1.0]:
		var x: float = sign_value*.30
		_loft("Trouser",[_ring(Vector3(x,.45,0),.18,.18),_ring(Vector3(x,.68,-.015),.26,.24),_ring(Vector3(x,1.04,-.01),.23,.21)],"coat_fold",body_root)
		_loft("AnkleWrap",[_ring(Vector3(x,.20,0),.13,.13),_ring(Vector3(x,.47,0),.145,.145)],"recess",body_root)
		for y in [.255,.423]:
			var wrap := _loft("CinnabarBinding",[_ring(Vector3(x,y,0),.143,.143),_ring(Vector3(x,y+.055,0),.151,.145)],"scarf",body_root,true,.25)
			wrap.rotation.z = sign_value*.045
		# The toe projects forwards; the upper narrows into a sloping ankle.
		_loft("CutBoot",[_ring(Vector3(x,.045,.085),.21,.275),_ring(Vector3(x,.12,.105),.22,.28),_ring(Vector3(x,.28,.015),.135,.17)],"leather",body_root)
		_panel("BronzeToe",[Vector3(x-.165,.055,.325),Vector3(x+.165,.055,.325),Vector3(x+.14,.145,.34),Vector3(x+.055,.20,.29),Vector3(x-.10,.18,.30)],.022,"gold",body_root,.4)


func _robe() -> void:
	_loft("FittedTorso",[_ring(Vector3(0,1.43,0),.35,.235),_ring(Vector3(0,1.94,0),.40,.25),_ring(Vector3(0,2.20,0),.46,.255)],"coat",body_root)
	# The skirt is a real eight-sided volume with an irregular hem, not a cone primitive.
	var hem := _ring(Vector3(0,.58,-.005),.66,.38)
	for n in hem.size(): hem[n].y += [.05,-.035,.10,.01,.07,-.03,.015,.08][n]
	_loft("FacetedOverrobe",[hem,_ring(Vector3(0,1.00,0),.54,.315),_ring(Vector3(0,1.49,0),.36,.245)],"coat",body_root,false,.8)
	for s in [-1.0,1.0]:
		_panel("OpenRobeWing",[Vector3(s*.18,1.47,.25),Vector3(s*.37,1.42,.20),Vector3(s*.67,.64,.23),Vector3(s*.42,.74,.34),Vector3(s*.21,.58,.38)],.035,"coat_fold",body_root,.7)
	_panel("BoneApron",[Vector3(-.115,1.46,.275),Vector3(.11,1.46,.275),Vector3(.23,.56,.388),Vector3(.02,.47,.40),Vector3(-.18,.60,.39)],.026,"bone",body_root,.65)
	_panel("FrontRedSash",[Vector3(-.29,1.46,.293),Vector3(-.14,1.45,.30),Vector3(-.21,.86,.39),Vector3(-.285,.93,.40),Vector3(-.34,.79,.38)],.018,"scarf",body_root,.4)
	# Two restrained long crease strokes keep the broad shapes legible.
	ink([Vector3(-.43,.77,.27),Vector3(-.32,1.03,.29),Vector3(-.26,1.29,.28)],.23,"ink",body_root)
	ink([Vector3(.38,.76,.30),Vector3(.29,1.05,.31),Vector3(.24,1.28,.29)],.23,"ink",body_root)
	_key_symbol(Vector3(.015,.78,.414),.065,body_root)


func _arms() -> void:
	for s in [-1.0,1.0]:
		var upper := Vector3(s*.40,1.95,.0)
		var elbow := Vector3(s*.56,1.63,.035)
		var wrist := Vector3(s*.68,1.32,.11)
		_segment("UpperSleeve",upper,elbow,.17,"coat_fold",body_root)
		_segment("AngularCuff",elbow,wrist,.175,"coat_fold",body_root)
		_segment("WristGuard",wrist,Vector3(s*.69,1.225,.15),.12,"leather",body_root)
		_loft("Mitten",[_ring(Vector3(s*.70,1.095,.175),.115,.11,6),_ring(Vector3(s*.71,1.245,.155),.12,.13,6)],"leather",body_root,true,.6)
		_segment("Thumb",Vector3(s*.63,1.195,.22),Vector3(s*.62,1.115,.265),.048,"leather",body_root,5)
		for n in 2:
			ink([Vector3(s*(.65+n*.045),1.105,.268),Vector3(s*(.65+n*.045),1.160,.279)],.19,"ink",body_root)


func _cape() -> void:
	# A continuous twelve-sided poncho covers the upper arms. The front/back
	# hang lower than its sides, giving a cloth silhouette instead of shoulder armor.
	var shoulder := _ring(Vector3(0,2.15,0),.44,.27,12,0)
	var edge := _ring(Vector3(0,1.85,0),.84,.425,12,0)
	for n in edge.size(): edge[n].y = [1.68,1.77,1.85,1.88,1.85,1.79,1.74,1.80,1.86,1.89,1.83,1.77][n]
	_loft("ShoulderMantle",[edge,shoulder,_ring(Vector3(0,2.28,-.01),.28,.20,12,0)],"coat",body_root,false,.75)
	var raised := edge.duplicate()
	for n in raised.size(): raised[n] += Vector3(0,.045,0)
	var widened := edge.duplicate()
	for n in widened.size(): widened[n] = Vector3(widened[n].x*1.006,widened[n].y-.013,widened[n].z*1.014)
	_loft("MantleWornHem",[widened,raised],"hem",body_root,false,.3)
	for s in [-1.0,1.0]:
		var symbol := _group("SleeveSigil",body_root)
		symbol.position = Vector3(s*.57,1.96,.275)
		symbol.rotation_degrees = Vector3(0,s*35,s*17)
		_key_symbol(Vector3.ZERO,.066,symbol)
	var back_mark := _group("BackSigil",body_root)
	back_mark.position = Vector3(0,1.98,-.35)
	back_mark.rotation_degrees = Vector3(-20,180,0)
	_key_symbol(Vector3.ZERO,.105,back_mark)


func _hood() -> void:
	# The opening is a recessed six-sided cavity. Hood sides extend all the way to its back.
	var rim := PackedVector3Array([Vector3(-.43,2.46,.34),Vector3(-.30,2.96,.25),Vector3(0,3.24,.10),Vector3(.30,3.02,.24),Vector3(.43,2.47,.34),Vector3(0,2.35,.44)])
	var rear := PackedVector3Array([Vector3(-.35,2.44,-.27),Vector3(-.24,2.99,-.31),Vector3(.04,3.14,-.40),Vector3(.29,2.96,-.28),Vector3(.35,2.42,-.29),Vector3(.02,2.36,-.27)])
	var inner := PackedVector3Array([Vector3(-.34,2.48,.31),Vector3(-.23,2.89,.235),Vector3(0,3.10,.14),Vector3(.23,2.91,.235),Vector3(.34,2.48,.31),Vector3(0,2.41,.40)])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in rim.size():
		var k := (n+1)%rim.size()
		var radial := (rim[n]+rim[k])*.5-Vector3(0,2.77,0)
		_face(surface,[rim[n],rear[n],rear[k]],radial,.94 if n%2 else 1.04)
		_face(surface,[rim[n],rear[k],rim[k]],radial,1.0)
		_face(surface,[rim[n],rim[k],inner[k],inner[n]],Vector3.FORWARD*-1,1.10)
	_face(surface,Array(rear),Vector3(0,0,-1),.88)
	_part("HollowHoodShell",surface.commit(),"coat",head_root,.9)
	# Dark backing and inner walls are separate from the forward mask.
	var inside := SurfaceTool.new()
	inside.begin(Mesh.PRIMITIVE_TRIANGLES)
	var back_center := Vector3(0,2.75,-.13)
	for n in inner.size():
		var k := (n+1)%inner.size()
		_tri(inside,inner[n],inner[k],back_center,Vector3(0,0,1))
	_part("HoodShadowCavity",inside.commit(),"recess",head_root,.3)
	ink([rim[0]+Vector3(0,0,.005),rim[1],rim[2],rim[3],rim[4]],.38,"ink",head_root)
	# Small back diamond, intentionally the only ornament on the hood.
	_panel("HoodBackSeal",[Vector3(-.065,2.78,-.315),Vector3(0,2.88,-.322),Vector3(.065,2.78,-.315),Vector3(0,2.70,-.319)],.01,"gold",head_root,.25)


func _mask() -> void:
	# Folded beak: two broad planes sharing a protruding central ridge.
	var left := Vector3(-.14,2.73,.355)
	var right := Vector3(.14,2.73,.355)
	var brow := Vector3(0,2.84,.405)
	var ridge := Vector3(0,2.64,.555)
	var tip := Vector3(0,2.43,.41)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tri(surface,left,brow,ridge,Vector3(-.4,0,1),.97)
	_tri(surface,brow,right,ridge,Vector3(.4,0,1),1.06)
	_tri(surface,left,ridge,tip,Vector3(-.4,0,1),.90)
	_tri(surface,ridge,right,tip,Vector3(.4,0,1),1.0)
	_part("FoldedBronzeBeak",surface.commit(),"gold",head_root,.6)
	for s in [-1.0,1.0]:
		_panel("MaskHorn",[Vector3(s*.10,2.75,.35),Vector3(s*.235,2.86,.31),Vector3(s*.18,3.035,.28),Vector3(s*.135,2.88,.36),Vector3(s*.05,2.81,.41)],.035,"gold",head_root,.5)
		_panel("EyeSocket",[Vector3(s*.06,2.69,.37),Vector3(s*.18,2.74,.30),Vector3(s*.13,2.59,.33)],.015,"recess",head_root,.25)
	_disc("LensSetting",Vector3(0,2.79,.433),.094,.043,"recess",head_root)
	_disc("LensRim",Vector3(0,2.79,.461),.076,.023,"gold",head_root)
	_disc("CinnabarEye",Vector3(0,2.79,.48),.053,.025,"lens",head_root)
	ink([brow+Vector3(0,0,.008),ridge+Vector3(0,0,.008),tip+Vector3(0,0,.008)],.25,"ink",head_root)


func _scarf() -> void:
	_loft("WrappedCinnabarScarf",[_ring(Vector3(0,2.23,0),.29,.245),_ring(Vector3(0,2.36,0),.36,.28),_ring(Vector3(0,2.40,0),.29,.235)],"scarf",body_root,true,.7)
	_panel("ScarfFrontFold",[Vector3(-.33,2.37,.245),Vector3(-.18,2.30,.335),Vector3(.10,2.25,.335),Vector3(.33,2.35,.245),Vector3(.10,2.32,.345),Vector3(-.13,2.36,.345)],.025,"scarf",body_root,.3)
	_panel("LongScarfTail",[Vector3(-.10,2.32,-.29),Vector3(.10,2.32,-.30),Vector3(.16,1.86,-.45),Vector3(.32,1.43,-.42),Vector3(.34,.87,-.50),Vector3(.23,1.02,-.48),Vector3(.20,.84,-.49),Vector3(.05,1.46,-.47),Vector3(-.04,1.90,-.44)],.026,"scarf",scarf_root,.65)
	_panel("SideScarfTail",[Vector3(.05,2.30,-.31),Vector3(.20,2.29,-.30),Vector3(.37,1.85,-.43),Vector3(.48,1.51,-.41),Vector3(.37,1.48,-.43),Vector3(.43,1.26,-.46),Vector3(.26,1.47,-.47),Vector3(.16,1.85,-.46)],.022,"scarf",scarf_root,.5)
	ink([Vector3(.04,2.17,-.45),Vector3(.10,1.81,-.47),Vector3(.18,1.42,-.50)],.23,"ink",scarf_root)


func _equipment() -> void:
	_loft("WaistBelt",[_ring(Vector3(0,1.43,0),.387,.278),_ring(Vector3(0,1.56,0),.39,.278)],"leather",body_root,true,.45)
	for x in [-.15,.025]:
		_block("Buckle",Vector3(x,1.50,.293),Vector3(.137,.143,.038),"gold",body_root)
		_block("BuckleHole",Vector3(x,1.50,.318),Vector3(.079,.085,.013),"recess",body_root,.15)
	_panel("DiagonalSatchelStrap",[Vector3(-.33,1.62,.285),Vector3(-.39,1.73,.31),Vector3(.32,2.23,.275),Vector3(.41,2.16,.29)],.035,"leather",body_root,.5)
	_disc("OctagonalClasp",Vector3(.29,2.13,.35),.13,.055,"gold",body_root)
	_disc("ClaspRecess",Vector3(.29,2.13,.389),.087,.015,"recess",body_root)
	_disc("ClaspSeal",Vector3(.29,2.13,.403),.043,.017,"gold",body_root,6)
	_panel("ChestTalisman",[Vector3(.24,2.00,.35),Vector3(.35,2.00,.35),Vector3(.35,1.67,.37),Vector3(.24,1.69,.37)],.018,"bone",body_root,.4)
	_key_symbol(Vector3(.295,1.86,.39),.035,body_root)
	_panel("TalismanTassel",[Vector3(.273,1.71,.385),Vector3(.314,1.71,.385),Vector3(.33,1.50,.39),Vector3(.30,1.55,.39),Vector3(.29,1.50,.39),Vector3(.26,1.56,.39)],.014,"scarf",body_root,.3)


func _key_symbol(at: Vector3, radius: float, parent: Node3D) -> void:
	# Eight simple quads form an actual open ring. The stem is broad enough for map scale.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in 8:
		var a := TAU*n/8
		var b := TAU*(n+1)/8
		var outside_a := at+Vector3(sin(a)*radius,cos(a)*radius,0)
		var outside_b := at+Vector3(sin(b)*radius,cos(b)*radius,0)
		var inside_a := at+Vector3(sin(a)*radius*.68,cos(a)*radius*.68,0)
		var inside_b := at+Vector3(sin(b)*radius*.68,cos(b)*radius*.68,0)
		_face(surface,[outside_a,outside_b,inside_b,inside_a],Vector3(0,0,1))
	_part("KeyRing",surface.commit(),"gold",parent,.0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_block("KeyStem",at+Vector3(0,-radius*1.63,0),Vector3(radius*.32,radius*1.50,.008),"gold",parent,0)


func _lantern() -> void:
	var at := Vector3(-.96,.73,.20)
	# Handle runs through the right hand. It is a real octagonal ring in the XY plane.
	var ring := _group("Handle",lantern_root)
	_key_handle(Vector3(-.96,1.09,.19),.085,ring)
	var lower := at+Vector3(0,-.17,0)
	var upper := at+Vector3(0,.17,0)
	_loft("RedLanternGlass",[_ring(lower,.14,.14,6,PI/6),_ring(upper,.18,.18,6,PI/6)],"lamp",lantern_root,false,.25)
	_loft("LampFoot",[_ring(lower-Vector3(0,.045,0),.19,.19,6,PI/6),_ring(lower,.19,.19,6,PI/6)],"gold",lantern_root)
	_loft("LampRoof",[_ring(upper,.23,.23,6,PI/6),_ring(upper+Vector3(0,.06,0),.14,.14,6,PI/6),_ring(upper+Vector3(0,.13,0),.06,.06,6,PI/6)],"leather",lantern_root)
	var a := _ring(lower,.17,.17,6,PI/6)
	var b := _ring(upper,.205,.205,6,PI/6)
	for n in 6: _segment("LampMullion",a[n],b[n],.019,"leather",lantern_root,4)
	_segment("LampFinial",upper+Vector3(0,.11,0),upper+Vector3(0,.16,0),.028,"gold",lantern_root)
	_segment("LampPendantCord",lower-Vector3(0,.03,0),lower-Vector3(0,.11,0),.012,"scarf",lantern_root,4)
	_panel("LampPaperSeal",[lower+Vector3(-.045,-.11,.018),lower+Vector3(.045,-.11,.018),lower+Vector3(.045,-.34,.018),lower+Vector3(-.045,-.34,.018)],.012,"bone",lantern_root,.4)
	_key_symbol(lower+Vector3(0,-.18,.029),.024,lantern_root)
	_panel("LampRedTassel",[lower+Vector3(-.025,-.32,.03),lower+Vector3(.025,-.32,.03),lower+Vector3(.04,-.43,.03),lower+Vector3(.01,-.40,.03),lower+Vector3(-.015,-.46,.03),lower+Vector3(-.03,-.40,.03)],.012,"scarf",lantern_root,.25)
	lantern_light = OmniLight3D.new()
	lantern_light.name = "RealLanternLight"
	lantern_light.position = at
	lantern_light.light_energy = lantern_energy
	lantern_light.omni_range = 2.2
	lantern_light.omni_attenuation = 1.5
	lantern_light.shadow_enabled = false
	lantern_root.add_child(lantern_light)


func _key_handle(at: Vector3, radius: float, parent: Node3D) -> void:
	for n in 8:
		var a := TAU*n/8
		var b := TAU*(n+1)/8
		_segment("HandleSegment",at+Vector3(sin(a)*radius,cos(a)*radius,0),at+Vector3(sin(b)*radius,cos(b)*radius,0),.014,"leather",parent,4)
