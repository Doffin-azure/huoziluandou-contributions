extends Node3D
## A solid, hollow-fronted shrine: closed hip roof, stone wall volumes and real recess.
## Color and ink use the same palette and painted-light path as the tree/courtyard.
const INLAY = preload("res://src/map/expedition_inlaid_glyph.gd")
const INK = preload("res://src/shaders/expedition_tree_ink.gdshader")
var style: ExpeditionFlatStyle
var roof: MeshInstance3D
var niche_frame: MeshInstance3D
var lamp: Node3D
var lamp_lit := true
var details: Node3D
var _lamp_paint: StandardMaterial3D
var _glow_paint: ShaderMaterial
var _glow: MeshInstance3D
var _roof_paint: ShaderMaterial
var _inks: Dictionary = {}
var _primary: Array[MeshInstance3D] = []


func setup(painter: ExpeditionFlatStyle) -> void:
	style = painter
	details = Node3D.new()
	details.name = "EngravedDetails"
	add_child(details)
	_foundation()
	_chamber()
	_roof()
	_carving()
	_lamp()
	_ground_shadow()
	style.palette.changed.connect(refresh_palette)
	refresh_palette()


func _exit_tree() -> void:
	if style!=null and style.palette.changed.is_connected(refresh_palette): style.palette.changed.disconnect(refresh_palette)


func _box(center: Vector3, dimensions: Vector3, role := "architecture", outline := .8, parent: Node3D = null) -> MeshInstance3D:
	var node := style.mesh(self if parent==null else parent,TypeMeshes.beveled_box(dimensions,.009),center,role,outline)
	_primary.append(node)
	return node


func _foundation() -> void:
	_box(Vector3(0,.055,0),Vector3(1.30,.11,.99),"architecture",1.0)
	_box(Vector3(0,.145,-.025),Vector3(1.17,.07,.85),"stone",.6)
	_box(Vector3(0,.215,-.03),Vector3(1.05,.07,.75),"architecture",.7)
	_box(Vector3(0,.035,.60),Vector3(.75,.07,.25),"architecture",.65)
	_box(Vector3(0,.103,.49),Vector3(.70,.065,.20),"stone",.55)
	# The playable glyph remains a separate, floor-aligned inlay.
	var mark := INLAY.new()
	mark.position = Vector3(0,.138,.52)
	mark.scale = Vector3.ONE*.45
	add_child(mark)
	mark.setup("谜",style.palette,Ink.serif)
	_line([Vector3(-.54,.181,.405),Vector3(-.23,.181,.405)],.26,"worn")
	_line([Vector3(.17,.181,.405),Vector3(.40,.181,.405)],.26,"worn")
	_line([Vector3(-.48,.112,.498),Vector3(-.42,.073,.498),Vector3(-.37,.066,.498),Vector3(-.34,.036,.498)],.32)
	_line([Vector3(.52,.182,.21),Vector3(.52,.151,.16),Vector3(.49,.149,.14)],.30)


func _chamber() -> void:
	# Three solid walls leave a genuine entrance, not a dark rectangle pasted on a box.
	_box(Vector3(0,.64,-.29),Vector3(.96,.79,.13),"architecture",.8)
	for sign_value in [-1,1]:
		_box(Vector3(sign_value*.43,.64,-.025),Vector3(.12,.79,.51),"architecture",.8)
	_box(Vector3(0,.275,.01),Vector3(.80,.05,.52),"roof",.45)
	_box(Vector3(0,.65,-.212),Vector3(.71,.65,.012),"foreground",0)
	var outer := PackedVector2Array([Vector2(-.50,.31),Vector2(.50,.31),Vector2(.50,.96),Vector2(.40,1.075),Vector2(-.40,1.075),Vector2(-.50,.96)])
	var inner := PackedVector2Array([Vector2(-.30,.39),Vector2(.30,.39),Vector2(.30,.84),Vector2(.225,.935),Vector2(-.225,.935),Vector2(-.30,.84)])
	niche_frame = style.mesh(self,_ring(outer,inner,.245,.340),Vector3.ZERO,"architecture",.9)
	_primary.append(niche_frame)
	var rim: Array[Vector3] = []
	for point in inner: rim.append(Vector3(point.x,point.y,.342))
	rim.append(rim[0])
	_line(rim,.53)
	for sign_value in [-1,1]:
		_box(Vector3(sign_value*.413,.625,.368),Vector3(.105,.55,.075),"architecture",.65)
		_box(Vector3(sign_value*.413,.375,.37),Vector3(.147,.07,.113),"copper_dark",.45)
		_box(Vector3(sign_value*.413,.898,.37),Vector3(.15,.055,.12),"copper_dark",.45)
		# A shallow, carved vertical flute on each post.
		_line([Vector3(sign_value*.413,.45,.408),Vector3(sign_value*.413,.81,.408)],.30)
		_line([Vector3(sign_value*.395,.46,.408),Vector3(sign_value*.395,.79,.408)],.18,"worn")
	_box(Vector3(0,.365,.035),Vector3(.49,.14,.33),"architecture",.6)
	_box(Vector3(0,.448,.035),Vector3(.57,.035,.37),"stone",.5)
	# Upright tablet has depth and chamfered shoulders, with a restrained bronze seal.
	var stele := PackedVector2Array([Vector2(-.15,0),Vector2(.15,0),Vector2(.15,.35),Vector2(.105,.41),Vector2(-.105,.41),Vector2(-.15,.35)])
	var tablet := style.mesh(self,_extruded(stele,.095),Vector3(0,.466,.095),"architecture",.75)
	_primary.append(tablet)
	_box(Vector3(0,.695,.152),Vector3(.22,.25,.020),"copper_dark",.45)
	_box(Vector3(0,.695,.164),Vector3(.159,.186,.009),"roof",.28)
	_line([Vector3(-.040,.75,.171),Vector3(.040,.75,.171),Vector3(.040,.70,.171),Vector3(-.025,.70,.171),Vector3(-.025,.65,.171),Vector3(.044,.65,.171)],.28,"bronze")
	_box(Vector3(0,.615,.175),Vector3(.055,.028,.018),"seal",.20)
	_box(Vector3(0,1.06,.01),Vector3(1.11,.095,.75),"architecture",.8)
	_box(Vector3(0,1.115,.01),Vector3(1.19,.028,.80),"copper_dark",.45)
	for sx in [-1,1]:
		for sz in [-1,1]:
			_box(Vector3(sx*.46,1.115,sz*.28),Vector3(.16,.11,.19),"architecture",.5)
			_box(Vector3(sx*.48,1.17,sz*.30),Vector3(.24,.05,.25),"roof",.5)
	_box(Vector3(0,1.02,.367),Vector3(.27,.09,.028),"copper_dark",.35)
	var title := Label3D.new()
	title.text = "问"
	title.font = Ink.serif
	title.font_size = 72
	title.pixel_size = .00115
	title.position = Vector3(0,1.021,.384)
	title.modulate = style.palette.glyph_fill.darkened(.12)
	title.outline_size = 0
	title.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(title)
	title.set_meta("shrine_name",true)


func _height(x: float, z: float) -> float:
	var hip := maxf(absf(z)/.53,maxf(0,absf(x)-.29)/.46)
	var corner_lift := .065*pow(absf(x)/.75,6)*pow(absf(z)/.53,2)
	return 1.20+.26*pow(maxf(0,1-hip),.85)+corner_lift


func _roof() -> void:
	var xs := [-.75,-.60,-.43,-.29,0.0,.29,.43,.60,.75]
	var zs := [-.53,-.40,-.24,0.0,.24,.40,.53]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(xs.size()-1):
		for z in range(zs.size()-1):
			var points := [Vector3(xs[x],_height(xs[x],zs[z]),zs[z]),Vector3(xs[x+1],_height(xs[x+1],zs[z]),zs[z]),Vector3(xs[x+1],_height(xs[x+1],zs[z+1]),zs[z+1]),Vector3(xs[x],_height(xs[x],zs[z+1]),zs[z+1])]
			_roof_quad(surface,points,Vector3.UP)
			var underside: Array[Vector3] = []
			for point: Vector3 in points: underside.append(point-Vector3.UP*.052)
			_roof_quad(surface,underside,Vector3.DOWN)
	# Close all four eaves with real fascia thickness.
	for side in [-1.0,1.0]:
		for x in range(xs.size()-1):
			var a := Vector3(xs[x],_height(xs[x],side*.53),side*.53)
			var b := Vector3(xs[x+1],_height(xs[x+1],side*.53),side*.53)
			_quad(surface,[a,b,b-Vector3.UP*.052,a-Vector3.UP*.052],Vector3(0,0,side))
		for z in range(zs.size()-1):
			var a := Vector3(side*.75,_height(side*.75,zs[z]),zs[z])
			var b := Vector3(side*.75,_height(side*.75,zs[z+1]),zs[z+1])
			_quad(surface,[a,b,b-Vector3.UP*.052,a-Vector3.UP*.052],Vector3(side,0,0))
	roof = style.mesh(self,surface.commit(),Vector3.ZERO,"roof",1.05)
	_roof_paint = ShaderMaterial.new()
	_roof_paint.shader = preload("res://src/shaders/expedition_painted_roof.gdshader")
	roof.material_override = _roof_paint
	_primary.append(roof)
	_box(Vector3(0,1.477,0),Vector3(.69,.052,.083),"roof",.55)
	for sign_value in [-1,1]:
		_box(Vector3(sign_value*.36,1.475,0),Vector3(.055,.078,.10),"copper_dark",.4)
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:
			var hip_line: Array[Vector3] = []
			for n in 11:
				var t := n/10.0
				var x: float = sx*lerpf(.29,.75,t)
				var z: float = sz*.53*t
				hip_line.append(Vector3(x,_height(x,z)+.003,z))
			_line(hip_line,.46)
	# Only selected ribs and broken rows: enough to show curved slopes at map scale.
	for x in [-.50,-.30,-.10,.10,.30,.50]:
		for sign_value in [-1.0,1.0]:
			var points: Array[Vector3] = []
			for n in range(1,9):
				var z: float = sign_value*(.05+n*.052)
				points.append(Vector3(x,_height(x,z)+.002,z))
			_line(points,.27)
	for sign_value in [-1.0,1.0]:
		for x_center in [-.40,-.20,0.0,.20,.40]:
			var z_value: float = .34 if absf(x_center)<.3 else .40
			var points: Array[Vector3] = []
			for n in 5:
				var x: float = x_center-.066+n*.033
				var z: float = sign_value*(z_value+.007*sin(n/4.0*PI))
				points.append(Vector3(x,_height(x,z)+.002,z))
			_line(points,.18)
		var eave: Array[Vector3] = []
		for x in xs: eave.append(Vector3(x,_height(x,sign_value*.53)-.023,sign_value*.532))
		_line(eave,.34)


func _carving() -> void:
	# Shallow key-pattern engraving follows the side wall instead of facing the camera.
	for side in [-1.0,1.0]:
		var x: float = side*.492
		_line([Vector3(x,.87,-.21),Vector3(x,.87,.12),Vector3(x,.73,.12),Vector3(x,.73,-.09),Vector3(x,.57,-.09),Vector3(x,.57,.12)],.31)
		_line([Vector3(x,.45,-.21),Vector3(x,.45,.07)],.25)
		_line([Vector3(x,.91,-.19),Vector3(x,.94,-.13),Vector3(x,.99,-.12)],.23)
	# A few fractured stone lines, not an all-over scratch texture.
	_line([Vector3(-.484,.82,.342),Vector3(-.46,.77,.342),Vector3(-.48,.72,.342)],.28)
	_line([Vector3(.425,.52,.409),Vector3(.40,.49,.409),Vector3(.409,.46,.409)],.25)
	_line([Vector3(-.49,1.082,.24),Vector3(-.38,1.082,.24)],.22,"worn")


func _lamp() -> void:
	lamp = Node3D.new()
	lamp.position = Vector3(0,.51,.16)
	lamp.name = "RecessLamp"
	add_child(lamp)
	_box(Vector3(0,-.018,0),Vector3(.12,.035,.10),"copper_dark",.3,lamp)
	_lamp_paint = StandardMaterial3D.new()
	_lamp_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_paint.emission_enabled = true
	var flame := MeshInstance3D.new()
	flame.mesh = TypeMeshes.beveled_box(Vector3(.046,.065,.037),.005)
	flame.position.y = .028
	flame.material_override = _lamp_paint
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(flame)
	_glow_paint = ShaderMaterial.new()
	_glow_paint.shader = preload("res://src/shaders/expedition_ground_glow.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(.29,.32)
	_glow = MeshInstance3D.new()
	_glow.mesh = quad
	_glow.material_override = _glow_paint
	_glow.position = Vector3(0,.035,.035)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(_glow)


func _line(points: Array[Vector3], width: float, role := "ink") -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(points.size()-1):
		for corner: Vector2i in [Vector2i(index,-1),Vector2i(index+1,-1),Vector2i(index+1,1),Vector2i(index,-1),Vector2i(index+1,1),Vector2i(index,1)]:
			var n := corner.x
			var tangent := (points[mini(points.size()-1,n+1)]-points[maxi(0,n-1)]).normalized()
			surface.set_normal(tangent)
			surface.set_color(Color.WHITE)
			surface.set_uv(Vector2(0,corner.y))
			surface.add_vertex(points[n])
	var key := role+str(width)
	if not _inks.has(key):
		var material := ShaderMaterial.new()
		material.shader = INK
		material.set_meta("role",role)
		material.set_meta("width",width)
		_inks[key] = material
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = _inks[key]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	details.add_child(node)


func _ring(outer: PackedVector2Array, inner: PackedVector2Array, back: float, front: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in outer.size():
		var next := (n+1)%outer.size()
		for depth in [back,front]:
			_quad(surface,[Vector3(outer[n].x,outer[n].y,depth),Vector3(outer[next].x,outer[next].y,depth),Vector3(inner[next].x,inner[next].y,depth),Vector3(inner[n].x,inner[n].y,depth)],Vector3(0,0,1 if depth==front else -1))
		for profile in [outer,inner]:
			var a: Vector2 = profile[n]
			var b: Vector2 = profile[next]
			var normal := Vector3(b.y-a.y,a.x-b.x,0).normalized()
			if profile==inner: normal = -normal
			_quad(surface,[Vector3(a.x,a.y,back),Vector3(b.x,b.y,back),Vector3(b.x,b.y,front),Vector3(a.x,a.y,front)],normal)
	return surface.commit()


func _extruded(profile: PackedVector2Array, depth: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(profile)
	for side in [-1.0,1.0]:
		for n in range(0,indices.size(),3):
			var points: Array[Vector3] = []
			for j in 3:
				var p: Vector2 = profile[indices[n+j]]
				points.append(Vector3(p.x,p.y,side*depth*.5))
			_triangle(surface,points[0],points[1],points[2],Vector3(0,0,side))
	for n in profile.size():
		var a := profile[n]
		var b := profile[(n+1)%profile.size()]
		_quad(surface,[Vector3(a.x,a.y,-depth*.5),Vector3(b.x,b.y,-depth*.5),Vector3(b.x,b.y,depth*.5),Vector3(a.x,a.y,depth*.5)],Vector3(b.y-a.y,a.x-b.x,0).normalized())
	return surface.commit()


func _quad(surface: SurfaceTool, points: Array, normal: Vector3) -> void:
	_triangle(surface,points[0],points[1],points[2],normal)
	_triangle(surface,points[0],points[2],points[3],normal)


func _roof_quad(surface: SurfaceTool, points: Array, hint: Vector3) -> void:
	for indices in [Vector3i(0,1,2),Vector3i(0,2,3)]:
		var a: Vector3 = points[indices.x]
		var b: Vector3 = points[indices.y]
		var c: Vector3 = points[indices.z]
		var normal := (b-a).cross(c-a).normalized()
		if normal.dot(hint)<0: normal = -normal
		_triangle(surface,a,b,c,normal)


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var tri := [a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]
	for point: Vector3 in tri:
		surface.set_normal(normal)
		surface.add_vertex(point)


func _ground_shadow() -> void:
	var points := PackedVector2Array()
	for item in _primary:
		var relative := Transform3D.IDENTITY
		var cursor: Node3D = item
		while cursor!=self and cursor!=null:
			relative = cursor.transform*relative
			cursor = cursor.get_parent() as Node3D
		var vertices: PackedVector3Array = item.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var point := relative*vertex
			points.append(Vector2(point.x+point.y*.32,point.z+point.y*.24))
	var hull := Geometry2D.convex_hull(points)
	if hull[0].is_equal_approx(hull[-1]): hull.resize(hull.size()-1)
	var indices := Geometry2D.triangulate_polygon(hull)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(0,indices.size(),3):
		var tri: Array[Vector3] = []
		for j in 3:
			var point := hull[indices[n+j]]
			tri.append(Vector3(point.x,.002,point.y))
		_triangle(surface,tri[0],tri[1],tri[2],Vector3.UP)
	var node := MeshInstance3D.new()
	node.name = "PaintedGroundShadow"
	node.mesh = surface.commit()
	node.material_override = style.solid_material("shadow")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func set_lamp_lit(value: bool) -> void:
	lamp_lit = value
	refresh_palette()


func set_scene_lighting(value: bool) -> void:
	_roof_paint.shader = preload("res://src/shaders/expedition_lit_roof.gdshader") if value else preload("res://src/shaders/expedition_painted_roof.gdshader")
	get_node("PaintedGroundShadow").visible = not value
	refresh_palette()


func sync_light() -> void:
	# The local roof material receives the same active painted light as other surfaces.
	var source := style.face_material("architecture")
	for parameter in ["fire_position","fire_color","fire_energy","fire_radius","fire_pulse"]:
		_roof_paint.set_shader_parameter(parameter,source.get_shader_parameter(parameter))


func refresh_palette() -> void:
	var colors := style.palette
	_roof_paint.set_shader_parameter("roof_color",colors.roof)
	_roof_paint.set_shader_parameter("diffuse_response",colors.roof_light_response)
	sync_light()
	for material: ShaderMaterial in _inks.values():
		var role: String = material.get_meta("role")
		var tint: Color = colors.ink
		if role=="worn": tint = colors.architecture_top.lerp(colors.stone_top,.45)
		elif role=="bronze": tint = colors.bronze
		material.set_shader_parameter("ink_color",tint)
		material.set_shader_parameter("half_width_pixels",colors.outline_pixels*float(material.get_meta("width")))
	_lamp_paint.albedo_color = colors.fire_inner if lamp_lit else colors.roof
	_lamp_paint.emission = colors.fire_inner
	_lamp_paint.emission_energy_multiplier = (1.4 if style.scene_lighting else .35) if lamp_lit else 0
	_glow.visible = lamp_lit
	_glow_paint.set_shader_parameter("tint",Color(colors.fire_light.r,colors.fire_light.g,colors.fire_light.b,.17))
	for child in get_children():
		if child.has_meta("shrine_name"): child.modulate = colors.glyph_fill.darkened(.12)
