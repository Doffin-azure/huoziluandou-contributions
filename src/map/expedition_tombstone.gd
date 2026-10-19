extends "res://src/map/expedition_building_base.gd"
## Four solid stone variants: a rooted leaning tablet, fractured remains, tall and wide stelae.
enum Kind { LEANING, BROKEN, TALL, WIDE }
const TITLES := ["倾斜旧碑","断裂残碑","瘦高墓碑","矮宽墓碑"]
var variant := Kind.LEANING
var body_pivot: Node3D
var body: MeshInstance3D
var wear: Node3D
var _inscriptions: Array[Label3D] = []


func _build() -> void:
	name = "Tombstone%d"%variant
	map_scale = .65
	wear = Node3D.new()
	wear.name = "ChipsAndMoss"
	add_child(wear)
	body_pivot = Node3D.new()
	body_pivot.name = "StoneBodyPivot"
	add_child(body_pivot)
	match variant:
		Kind.LEANING: _leaning()
		Kind.BROKEN: _broken()
		Kind.TALL: _tall()
		Kind.WIDE: _wide()


func _beveled_tablet(points: PackedVector2Array, depth: float, center: Vector3, parent: Node3D, fracture_edges: Array[int] = []) -> MeshInstance3D:
	var bevel := .014
	var centroid := Vector2.ZERO
	for point in points: centroid += point
	centroid /= points.size()
	var inner := PackedVector2Array()
	for point in points: inner.append(point+(centroid-point).normalized()*bevel)
	var indices := Geometry2D.triangulate_polygon(inner)
	assert(not indices.is_empty(),"墓碑正面必须是有效闭合轮廓")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cut := SurfaceTool.new()
	cut.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		for n in range(0,indices.size(),3):
			var vertices: Array[Vector3] = []
			for j in 3:
				var p := inner[indices[n+j]]
				vertices.append(Vector3(p.x,p.y,side*depth*.5))
			_triangle(surface,vertices[0],vertices[1],vertices[2],Vector3(0,0,side))
	for n in points.size():
		var next := (n+1)%points.size()
		var a := points[n]
		var b := points[next]
		var target: SurfaceTool = cut if fracture_edges.has(n) else surface
		var outward := Vector3(b.y-a.y,a.x-b.x,0).normalized()
		_quad(target,[Vector3(a.x,a.y,-depth*.5+bevel),Vector3(b.x,b.y,-depth*.5+bevel),Vector3(b.x,b.y,depth*.5-bevel),Vector3(a.x,a.y,depth*.5-bevel)],outward)
		for side in [-1.0,1.0]:
			var edge := [Vector3(a.x,a.y,side*(depth*.5-bevel)),Vector3(b.x,b.y,side*(depth*.5-bevel)),Vector3(inner[next].x,inner[next].y,side*depth*.5),Vector3(inner[n].x,inner[n].y,side*depth*.5)]
			_quad(target,edge,(outward+Vector3(0,0,side)).normalized())
	var result := style.mesh(parent,surface.commit(),center,"tombstone",1.0)
	if not fracture_edges.is_empty(): style.mesh(parent,cut.commit(),center,"tomb_cut",0)
	return result


func _foot(width: float, depth: float, height: float, chipped := false) -> void:
	var shape := PackedVector2Array([Vector2(-width*.5,-depth*.33),Vector2(-width*.34,-depth*.5),Vector2(width*.37,-depth*.5),Vector2(width*.5,-depth*.29),Vector2(width*.5,depth*.35),Vector2(width*.31,depth*.5),Vector2(-width*.39,depth*.5),Vector2(-width*.5,depth*.27)])
	if chipped: shape[4] += Vector2(-.11,-.045)
	var base := profile(shape,height,Vector3(0,height*.5,0),"tombstone",.65)
	base.rotation.x = -PI*.5
	if not chipped: box(Vector3(0,height+.026,0),Vector3(width*.79,.052,depth*.77),"tombstone",.5)


func _engrave(text: String, center: Vector3, character_height: float, parent: Node3D) -> void:
	for edge in [true,false]:
		var label := Label3D.new()
		label.text = text
		label.font = Ink.serif
		label.font_size = 128
		label.pixel_size = character_height/128.0
		label.position = center+(Vector3(.0025,-.003,-.001) if edge else Vector3.ZERO)
		label.outline_size = 0
		label.set_meta("cut_edge",edge)
		parent.add_child(label)
		_inscriptions.append(label)


func _border(rect: Rect2, depth: float, parent: Node3D, broken_top := false) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	ink([Vector3(x,y+h*.85,depth),Vector3(x,y,depth),Vector3(x+w,y,depth),Vector3(x+w,y+h*.90,depth)],.30,"ink",parent)
	if not broken_top: ink([Vector3(x,y+h*.85,depth),Vector3(x,y+h,depth),Vector3(x+w,y+h,depth),Vector3(x+w,y+h*.90,depth)],.30,"ink",parent)
	ink([Vector3(x+.008,y+.008,depth-.0005),Vector3(x+w-.008,y+.008,depth-.0005)],.16,"worn",parent)


func _chip(center: Vector3, width: float, height: float, angle: float) -> void:
	var piece := profile(PackedVector2Array([Vector2(-width*.5,0),Vector2(width*.5,0),Vector2(width*.30,height*.52),Vector2(-width*.08,height)]),width*.55,center,"tomb_cut",.35,wear)
	piece.rotation.y = angle


func _moss(points: PackedVector2Array, center: Vector3, parent: Node3D) -> void:
	var patch := profile(points,.001,center,"tomb_moss",0,parent)
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _leaning() -> void:
	footprint = Vector2(.95,.70)
	_foot(.78,.61,.085,true)
	body_pivot.position = Vector3(.07,.07,0)
	body_pivot.rotation_degrees = Vector3(-5,-7,14)
	var p := PackedVector2Array([Vector2(-.31,0),Vector2(.32,0),Vector2(.32,.71),Vector2(.30,.77),Vector2(.32,.83),Vector2(.32,1.21),Vector2(.26,1.35),Vector2(.13,1.43),Vector2(-.10,1.43),Vector2(-.27,1.34),Vector2(-.32,1.19),Vector2(-.32,.25),Vector2(-.28,.18)])
	body = _beveled_tablet(p,.20,Vector3.ZERO,body_pivot)
	_border(Rect2(-.22,.19,.43,.90),.102,body_pivot)
	_engrave("无\n名\n之\n墓",Vector3(0,.65,.106),.145,body_pivot)
	_engrave("幽",Vector3(0,1.22,.106),.11,body_pivot)
	ink([Vector3(-.22,1.17,.103),Vector3(-.22,1.29,.103),Vector3(-.11,1.33,.103),Vector3(-.08,1.28,.103)],.30,"ink",body_pivot)
	ink([Vector3(.22,1.17,.103),Vector3(.22,1.29,.103),Vector3(.11,1.33,.103),Vector3(.08,1.28,.103)],.30,"ink",body_pivot)
	# Two larger cracks, with a small branch each, define age at map scale.
	ink([Vector3(.29,1.33,.105),Vector3(.20,1.24,.105),Vector3(.24,1.16,.105),Vector3(.14,1.07,.105)],.36,"ink",body_pivot)
	ink([Vector3(.24,1.16,.105),Vector3(.30,1.11,.105)],.22,"ink",body_pivot)
	ink([Vector3(-.30,.39,.105),Vector3(-.20,.31,.105),Vector3(-.22,.21,.105),Vector3(-.10,.12,.105)],.34,"ink",body_pivot)
	ink([Vector3(-.20,.31,.105),Vector3(-.12,.33,.105)],.22,"ink",body_pivot)
	_moss(PackedVector2Array([Vector2(-.30,0),Vector2(.13,0),Vector2(.09,.035),Vector2(-.04,.05),Vector2(-.08,.025),Vector2(-.22,.08),Vector2(-.28,.045)]),Vector3(0,.04,.102),body_pivot)
	_chip(Vector3(-.36,.01,.21),.12,.07,.30)
	_chip(Vector3(.28,.01,.34),.09,.045,-.40)
	# A wedged stone touches the leaning foot; the tablet never rotates about its centre.
	_chip(Vector3(-.17,.01,-.16),.28,.12,.15)
	ink([Vector3(-.28,.09,.29),Vector3(-.12,.09,.29)],.26)


func _broken() -> void:
	footprint = Vector2(1.12,.95)
	_foot(.82,.57,.10,true)
	body_pivot.position.y = .10
	body_pivot.rotation_degrees.y = 4
	var p := PackedVector2Array([Vector2(-.34,0),Vector2(.34,0),Vector2(.34,.58),Vector2(.26,.61),Vector2(.25,.70),Vector2(.12,.65),Vector2(.02,.74),Vector2(-.05,.73),Vector2(-.09,.64),Vector2(-.24,.68),Vector2(-.34,.55)])
	body = _beveled_tablet(p,.235,Vector3.ZERO,body_pivot,[2,3,4,5,6,7,8,9])
	_border(Rect2(-.24,.13,.48,.57),.120,body_pivot,true)
	_engrave("之\n墓",Vector3(0,.30,.124),.15,body_pivot)
	# Surviving cuts run to the fracture instead of printing a complete epitaph over it.
	ink([Vector3(-.04,.59,.121),Vector3(.08,.59,.121),Vector3(.08,.66,.121)],.37,"ink",body_pivot)
	ink([Vector3(.22,.67,.122),Vector3(.16,.59,.122),Vector3(.23,.48,.122),Vector3(.20,.39,.122)],.38,"ink",body_pivot)
	ink([Vector3(.23,.48,.122),Vector3(.31,.45,.122)],.22,"ink",body_pivot)
	var fallen := Node3D.new()
	fallen.name = "FallenCrownFragment"
	fallen.position = Vector3(.43,.10,.55)
	fallen.rotation_degrees = Vector3(-75,12,-16)
	wear.add_child(fallen)
	var crown := PackedVector2Array([Vector2(-.22,0),Vector2(-.08,.075),Vector2(.02,.025),Vector2(.13,.10),Vector2(.23,.025),Vector2(.22,.24),Vector2(.13,.34),Vector2(-.12,.35),Vector2(-.23,.25)])
	_beveled_tablet(crown,.18,Vector3.ZERO,fallen,[0,1,2,3])
	_engrave("冥",Vector3(0,.22,.094),.10,fallen)
	_chip(Vector3(-.35,.008,.30),.15,.08,.45)
	_chip(Vector3(.36,.008,-.13),.11,.055,-.20)
	_moss(PackedVector2Array([Vector2(-.31,0),Vector2(-.10,0),Vector2(-.13,.06),Vector2(-.21,.04),Vector2(-.29,.12)]),Vector3(0,.02,.120),body_pivot)


func _tall() -> void:
	footprint = Vector2(.81,.62)
	_foot(.80,.60,.13)
	body_pivot.position.y = .18
	var p := PackedVector2Array([Vector2(-.265,0),Vector2(.265,0),Vector2(.265,1.45),Vector2(.225,1.60),Vector2(.13,1.73),Vector2(-.10,1.73),Vector2(-.22,1.64),Vector2(-.265,1.47)])
	body = _beveled_tablet(p,.25,Vector3.ZERO,body_pivot)
	box(Vector3(0,.10,0),Vector3(.61,.12,.34),"tombstone",.55,body_pivot)
	box(Vector3(0,1.315,0),Vector3(.575,.045,.29),"tombstone",.4,body_pivot)
	_border(Rect2(-.17,.26,.34,1.02),.128,body_pivot)
	_engrave("故\n人\n之\n墓",Vector3(0,.77,.132),.17,body_pivot)
	# The high tablet's shaped crown and narrow border distinguish it from a stretched slab.
	_engrave("冥",Vector3(0,1.46,.132),.12,body_pivot)
	ink([Vector3(-.20,1.34,.129),Vector3(-.20,1.50,.129),Vector3(-.12,1.60,.129),Vector3(-.05,1.57,.129)],.30,"ink",body_pivot)
	ink([Vector3(.20,1.34,.129),Vector3(.20,1.50,.129),Vector3(.12,1.60,.129),Vector3(.05,1.57,.129)],.30,"ink",body_pivot)
	ink([Vector3(-.225,.32,.129),Vector3(-.225,1.28,.129)],.22,"ink",body_pivot)
	ink([Vector3(.225,.32,.129),Vector3(.225,1.27,.129)],.22,"ink",body_pivot)
	ink([Vector3(-.263,1.41,.13),Vector3(-.20,1.34,.13),Vector3(-.22,1.25,.13)],.30,"ink",body_pivot)
	ink([Vector3(.267,.52,.09),Vector3(.267,.42,-.005),Vector3(.267,.31,.015)],.27,"ink",body_pivot)
	# Rear panel stays quiet but remains a finished side when the camera turns.
	ink([Vector3(-.17,.35,-.128),Vector3(-.17,1.32,-.128),Vector3(.17,1.32,-.128),Vector3(.17,.35,-.128)],.23,"ink",body_pivot)
	_chip(Vector3(.32,.005,.29),.08,.045,.30)


func _wide() -> void:
	footprint = Vector2(1.35,.72)
	_foot(1.35,.72,.125)
	body_pivot.position.y = .175
	var p := PackedVector2Array([Vector2(-.55,0),Vector2(.55,0),Vector2(.55,.46),Vector2(.47,.60),Vector2(.28,.68),Vector2(.11,.72),Vector2(-.11,.72),Vector2(-.28,.68),Vector2(-.47,.60),Vector2(-.55,.46)])
	body = _beveled_tablet(p,.29,Vector3.ZERO,body_pivot)
	box(Vector3(0,.055,0),Vector3(1.14,.07,.35),"tombstone",.5,body_pivot)
	_border(Rect2(-.40,.17,.80,.32),.148,body_pivot)
	_engrave("长眠",Vector3(0,.33,.152),.20,body_pivot)
	_engrave("归",Vector3(0,.59,.152),.10,body_pivot)
	for side in [-1.0,1.0]:
		ink([Vector3(side*.12,.60,.15),Vector3(side*.23,.62,.15),Vector3(side*.38,.55,.15),Vector3(side*.33,.51,.15)],.29,"ink",body_pivot)
		ink([Vector3(side*.47,.15,.15),Vector3(side*.47,.41,.15),Vector3(side*.43,.45,.15)],.25,"ink",body_pivot)
	ink([Vector3(.54,.31,.15),Vector3(.45,.27,.15),Vector3(.47,.18,.15),Vector3(.39,.10,.15)],.32,"ink",body_pivot)
	ink([Vector3(-.44,.05,-.148),Vector3(-.44,.45,-.148),Vector3(.44,.45,-.148),Vector3(.44,.05,-.148)],.23,"ink",body_pivot)
	_moss(PackedVector2Array([Vector2(-.51,0),Vector2(-.28,0),Vector2(-.30,.04),Vector2(-.40,.025),Vector2(-.46,.07)]),Vector3(0,.08,.148),body_pivot)
	_chip(Vector3(-.58,.005,.27),.10,.055,-.25)


func set_details_enabled(value: bool) -> void:
	super.set_details_enabled(value)
	for label in _inscriptions: label.visible = value


func refresh_palette() -> void:
	super.refresh_palette()
	for paint: ShaderMaterial in _inks.values():
		if paint.get_meta("role")=="worn":
			paint.set_shader_parameter("ink_color",style.palette.tomb_stone.lerp(style.palette.tomb_cut,.35))
	for label in _inscriptions:
		label.modulate = style.palette.tomb_stone.lerp(style.palette.tomb_cut,.28) if label.get_meta("cut_edge") else style.palette.tomb_engraving
