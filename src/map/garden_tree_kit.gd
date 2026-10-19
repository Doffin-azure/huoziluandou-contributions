extends "res://src/map/expedition_garden_asset_base.gd"
## Solid, flat-painted garden trees. All variation uses a private visual seed.
enum Kind { RED_MAPLE, CROOKED_PINE, WEEPING_WILLOW, BARE_LOCUST }
const LEAF_SHADER = preload("res://src/shaders/garden_tree_leaves.gdshader")
@export var kind: Kind = Kind.RED_MAPLE
@export_range(0, 1) var variant := 0
## Transparent means use the shared palette; an opaque tint overrides foliage.
@export var foliage_tint := Color(0,0,0,0)
var _leaf_paints: Array[ShaderMaterial] = []
var _leaf_nodes: Array[GeometryInstance3D] = []
var _visual_rng := RandomNumberGenerator.new()


func _build() -> void:
	map_scale = 1.0
	_visual_rng.seed = 7919+int(kind)*1009+variant*131
	set_meta("decorative_only",true)
	match kind:
		Kind.RED_MAPLE: _maple()
		Kind.CROOKED_PINE: _pine()
		Kind.WEEPING_WILLOW: _willow()
		Kind.BARE_LOCUST: _locust()
	set_meta("ground_contact",Vector3.ZERO)
	# Only the trunk/roots block ground placement. The canopy may overhang.
	set_meta("footprint",footprint)
	set_meta("solid_footprints",[Rect2(-footprint*.5,footprint)])
	set_meta("visual_bounds",_geometry_bounds())
	set_meta("sockets",[])


func _branch(points: Array[Vector3], radii: Array[float], role := "tree_bark", weight := .85) -> void:
	assert(points.size()==radii.size())
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Array] = []
	const SIDES := 7
	for n in points.size():
		var axis := (points[mini(n+1,points.size()-1)]-points[maxi(0,n-1)]).normalized()
		var right := axis.cross(Vector3.FORWARD if absf(axis.z)<.8 else Vector3.RIGHT).normalized()
		var forward := axis.cross(right).normalized()
		var ring: Array[Vector3] = []
		for j in SIDES:
			var angle := TAU*j/SIDES+.17
			ring.append(points[n]+(right*cos(angle)+forward*sin(angle))*radii[n])
		rings.append(ring)
	for n in range(points.size()-1):
		for j in SIDES:
			var k := (j+1)%SIDES
			var normal: Vector3 = ((rings[n][j]+rings[n][k])*.5-points[n]).normalized()
			_quad(surface,[rings[n][j],rings[n+1][j],rings[n+1][k],rings[n][k]],normal)
	for j in SIDES:
		var last := points.size()-1
		_triangle(surface,points[last],rings[last][j],rings[last][(j+1)%SIDES],(points[last]-points[last-1]).normalized())
	style.mesh(self,surface.commit(),Vector3.ZERO,role,weight)


func _roots(radius := .72) -> void:
	for n in 5:
		var angle := TAU*n/5.0+.24
		var direction := Vector3(cos(angle),0,sin(angle))
		_branch([Vector3(0,.23,0),direction*radius*.48+Vector3.UP*.06,direction*radius+Vector3.UP*.014],[.13,.085,.006],"tree_bark",.65)
	# One broad bark scar, rather than tracing every facet of every branch.
	ink([Vector3(-.065,.23,.16),Vector3(.01,.53,.12),Vector3(-.035,.82,.13)],.4)


func _paint_leaf(mesh: Mesh, shade := 0.0, outline := .65, parent: Node3D = null) -> MeshInstance3D:
	var node := style.mesh(self if parent==null else parent,mesh,Vector3.ZERO,"tree_leaf",outline)
	var paint := ShaderMaterial.new()
	paint.set_meta("leaf_shade",shade)
	node.material_override = paint
	_leaf_paints.append(paint); _leaf_nodes.append(node)
	return node


func _crown(center: Vector3, size: Vector3, shade := 0.0, teeth := 18) -> void:
	# Flattened, asymmetric leaf masses with cut edges; never a triangulated sphere.
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii: Array[float] = []
	for j in teeth: radii.append(_visual_rng.randf_range(.85,1.12)*(1.0 if j%2==0 else .79))
	var rings: Array[Array] = []
	for layer in 3:
		var ring: Array[Vector3] = []
		for j in teeth:
			var angle := TAU*j/teeth
			var radius: float = radii[j]*[.57,1.0,.73][layer]
			var y: float = [-.42,-.08,.32][layer]+.11*sin(angle*3.0+.7)+.055*cos(angle*5.0)
			ring.append(center+Vector3(cos(angle)*size.x*radius,y*size.y,sin(angle)*size.z*radius))
		rings.append(ring)
	for layer in 2:
		for j in teeth:
			var k := (j+1)%teeth
			var a: Vector3 = rings[layer][j]; var b: Vector3 = rings[layer+1][j]; var c: Vector3 = rings[layer+1][k]
			var normal := (b-a).cross(c-a).normalized()
			if normal.dot((a+b+c)/3.0-center)<0: normal = -normal
			_quad(surface,[a,b,c,rings[layer][k]],normal)
	for j in teeth:
		var k := (j+1)%teeth
		var tip := center+Vector3(-.13*size.x,.58*size.y,.06*size.z)
		var normal: Vector3 = (rings[2][k]-tip).cross(rings[2][j]-tip).normalized()
		if normal.y<0: normal = -normal
		_triangle(surface,tip,rings[2][j],rings[2][k],normal)
		_triangle(surface,center-Vector3.UP*size.y*.46,rings[0][j],rings[0][k],Vector3.DOWN)
	_paint_leaf(surface.commit(),shade,.80)


func _maple_leaf(at: Vector3, width: float, turn: Vector3, shade := 0.0) -> void:
	# A few readable palmate accents along the crown edge and on the ground.
	var xy := PackedVector2Array([Vector2(0,-.45),Vector2(-.19,-.12),Vector2(-.55,-.18),Vector2(-.38,.02),Vector2(-.85,.30),Vector2(-.42,.34),Vector2(-.51,.69),Vector2(-.18,.48),Vector2(0,1),Vector2(.18,.48),Vector2(.51,.69),Vector2(.42,.34),Vector2(.85,.30),Vector2(.38,.02),Vector2(.55,-.18),Vector2(.19,-.12)])
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(xy)
	var basis_value := Basis.from_euler(turn)
	for n in range(0,indices.size(),3):
		var points: Array[Vector3] = []
		for j in 3:
			var p := xy[indices[n+j]]
			points.append(at+basis_value*Vector3(p.x*width,absf(p.x)*width*.10,-p.y*width))
		var normal := basis_value*Vector3.UP
		_triangle(surface,points[0],points[1],points[2],normal)
	_paint_leaf(surface.commit(),shade,.40)


func _maple() -> void:
	footprint = Vector2(1.3,1.25)
	_roots(.62)
	var lean := -.35 if variant==1 else .0
	_branch([Vector3.ZERO,Vector3(.12,.73,0),Vector3(-.12,1.42,.04),Vector3(.08+lean,2.12,-.08),Vector3(.22+lean,3.05,-.10)],[.23,.18,.15,.095,.009])
	_branch([Vector3(-.10,1.15,.02),Vector3(-.53+lean,1.81,.04),Vector3(-1.03+lean,2.02,.05),Vector3(-1.52+lean,2.56,.02)],[.13,.10,.065,.008])
	_branch([Vector3(.01,1.65,0),Vector3(.67,2.02,.18),Vector3(1.27,2.51,.28)],[.12,.075,.006])
	_branch([Vector3(.02,1.92,-.06),Vector3(-.35,2.34,-.71),Vector3(-.50,2.90,-.90)],[.085,.058,.006])
	_branch([Vector3(-.79+lean,1.97,.04),Vector3(-.94+lean,2.39,.54)],[.055,.005])
	var crowns := [
		[Vector3(-.54+lean,3.15,-.58),Vector3(.91,.68,.76),.02],
		[Vector3(.42+lean,3.41,-.17),Vector3(.91,.64,.74),.11],
		[Vector3(1.18,2.83,.18),Vector3(.83,.65,.73),-.06],
		[Vector3(-1.39+lean,2.68,.06),Vector3(.87,.61,.70),-.08],
		[Vector3(-.48+lean,2.81,.57),Vector3(.89,.58,.65),.04]]
	if variant==1:
		crowns[2][0] = Vector3(.74,2.68,.22); crowns[2][1] = Vector3(.69,.55,.62)
	for crown: Array in crowns:
		_crown(crown[0],crown[1],crown[2],24)
		for n in 3:
			var angle := n*2.2+_visual_rng.randf_range(-.4,.4)
			var at: Vector3 = crown[0]+Vector3(cos(angle)*crown[1].x*.88,-.07,sin(angle)*crown[1].z*.88)
			_maple_leaf(at,_visual_rng.randf_range(.15,.23),Vector3(.25,angle,.15),float(crown[2])+.05)
	for n in 9:
		var angle := _visual_rng.randf()*TAU; var radius := _visual_rng.randf_range(.65,1.75)
		_maple_leaf(Vector3(cos(angle)*radius,.018,sin(angle)*radius),_visual_rng.randf_range(.09,.15),Vector3(0,angle,0),-.1)


func _pine() -> void:
	footprint = Vector2(1.5,1.45)
	_roots(.72)
	_branch([Vector3.ZERO,Vector3(.25,.65,.02),Vector3(.02,1.26,0),Vector3(.50,1.88,-.10),Vector3(.48,2.47,-.14),Vector3(.94,3.23,-.10)],[.25,.21,.17,.14,.095,.008])
	_branch([Vector3(.10,1.23,0),Vector3(-.40,1.63,.06),Vector3(-1.17,1.69,.10),Vector3(-1.65,2.07,.08)],[.15,.11,.075,.007])
	_branch([Vector3(.49,1.91,-.10),Vector3(1.14,2.08,.07),Vector3(1.57,2.49,.10)],[.10,.065,.007])
	_branch([Vector3(.48,2.41,-.13),Vector3(-.15,2.59,-.33),Vector3(-.78,2.93,-.40)],[.085,.055,.005])
	_branch([Vector3(-1.05,1.71,.10),Vector3(-1.24,2.10,.54)],[.05,.004])
	for crown: Array in [[Vector3(.83,3.30,-.13),Vector3(.85,.40,.61),.07],[Vector3(-.67,2.94,-.40),Vector3(.82,.35,.56),.0],[Vector3(1.52,2.55,.12),Vector3(.78,.31,.60),-.04],[Vector3(-1.49,2.14,.07),Vector3(.99,.32,.65),-.07]]:
		_crown(crown[0],crown[1],crown[2],20)
		# Several needle fans at tips, with the same ink as the buildings.
		for j in 4:
			var at: Vector3 = crown[0]+Vector3((j-1.5)*crown[1].x*.42,.14*float(crown[1].y),float(crown[1].z)*.6)
			for k in 3:
				ink([at,at+Vector3((k-1)*.085,.08+(.035 if k==1 else 0),.025)],.30)
	ink([Vector3(.19,.49,.15),Vector3(.08,1.16,.14),Vector3(.38,1.65,.07)],.48)


func _willow_ribbon(at: Vector3, drop: float, width: float, angle: float, shade: float) -> void:
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var right := Vector3(cos(angle),0,sin(angle))
	var points: Array[Vector3] = []
	for j in 8:
		var t := j/7.0
		points.append(at+Vector3(sin(t*3.2+angle)*.10,-drop*t,cos(t*2.4+angle)*.08))
	for j in 7:
		var wa := width*(1.0-j/8.0)*(.75 if j%2 else 1.0)
		var wb := width*(1.0-(j+1)/8.0)*(.75 if j%2==0 else 1.0)
		var a := points[j]-right*wa; var b := points[j]+right*wa
		var c := points[j+1]+right*wb; var d := points[j+1]-right*wb
		var normal := right.cross(Vector3.DOWN).normalized()
		_quad(surface,[a,b,c,d],normal)
	_paint_leaf(surface.commit(),shade,.4)


func _willow() -> void:
	footprint = Vector2(1.35,1.3)
	_roots(.65)
	_branch([Vector3.ZERO,Vector3(-.18,.80,0),Vector3(.12,1.61,-.04),Vector3(.20,2.42,-.10),Vector3(.07,3.24,-.07)],[.24,.19,.14,.10,.008])
	for angle: float in [.1,1.7,3.1,4.5,5.7]:
		var direction := Vector3(cos(angle),0,sin(angle))
		_branch([Vector3(.08,1.71,0),direction*.68+Vector3.UP*2.59,direction*1.25+Vector3.UP*2.68],[.105,.052,.007])
	_crown(Vector3(.03,3.16,-.10),Vector3(.91,.60,.71),.05)
	for n in 7:
		var angle := TAU*n/7.0
		var center := Vector3(cos(angle)*.94,2.83+sin(angle*3.0)*.10,sin(angle)*.76)
		_crown(center,Vector3(.67,.42,.58),-.04 if n%2 else .04,14)
		for j in 4:
			var theta := angle+(j-1.5)*.31
			var at := center+Vector3(cos(theta)*.36,-.03,sin(theta)*.37)
			_willow_ribbon(at,_visual_rng.randf_range(1.06,1.85),_visual_rng.randf_range(.055,.09),theta+.4,_visual_rng.randf_range(-.12,.09))


func _locust() -> void:
	footprint = Vector2(1.7,1.6)
	_roots(.81)
	_branch([Vector3.ZERO,Vector3(-.18,.71,.02),Vector3(.02,1.26,-.05),Vector3(-.16,1.93,-.10),Vector3(.15,2.62,-.12),Vector3(.07,3.26,-.15)],[.28,.23,.19,.15,.085,.025])
	_branch([Vector3(-.07,1.13,0),Vector3(-.64,1.54,.04),Vector3(-1.20,1.52,.03),Vector3(-1.57,2.11,.05),Vector3(-1.69,2.49,.01)],[.16,.12,.075,.035,.004])
	_branch([Vector3(-1.18,1.53,.03),Vector3(-1.10,2.05,.07),Vector3(-.86,2.34,.02)],[.065,.026,.003])
	_branch([Vector3(-.12,1.77,-.08),Vector3(.59,2.02,.03),Vector3(1.13,2.50,.10),Vector3(1.47,2.55,.12)],[.13,.09,.035,.003])
	_branch([Vector3(1.07,2.46,.10),Vector3(.98,2.89,.09),Vector3(1.12,3.10,.06)],[.036,.02,.003])
	_branch([Vector3(.10,2.60,-.12),Vector3(-.39,2.88,-.23),Vector3(-.55,3.38,-.25),Vector3(-.82,3.56,-.25)],[.075,.043,.018,.003])
	_branch([Vector3(-.51,3.25,-.25),Vector3(-.25,3.48,-.30)],[.02,.003])
	_branch([Vector3(-.10,1.62,-.08),Vector3(.12,1.97,-.63),Vector3(.35,2.45,-.86),Vector3(.70,2.63,-.88)],[.10,.065,.025,.004])
	# A shallow trunk hollow and a narrow weathered split.
	var hollow := profile(PackedVector2Array([Vector2(-.09,0),Vector2(-.12,.24),Vector2(-.03,.40),Vector2(.07,.31),Vector2(.06,.08)]),.012,Vector3(-.10,.72,.175),"tree_bark_shadow",.65)
	hollow.rotation.y = -.12
	ink([Vector3(-.13,.30,.22),Vector3(-.10,.59,.20),Vector3(-.20,.88,.14)],.55)
	ink([Vector3(-.03,1.19,.13),Vector3(-.09,1.56,.08),Vector3(-.02,1.87,.02)],.48)


func _geometry_bounds() -> AABB:
	var bounds := AABB(); var first := true
	for child in get_children():
		if child is MeshInstance3D:
			var value: AABB = child.transform*child.get_aabb()
			bounds = value if first else bounds.merge(value)
			first = false
	return bounds


func set_canopy_faded(value: bool) -> void:
	for node in _leaf_nodes: node.transparency = .78 if value else 0.0


func refresh_palette() -> void:
	super.refresh_palette()
	var colors := style.palette
	var tint := Color(colors.seal.r*.94,colors.seal.g*.69,colors.seal.b*.83)
	if kind==Kind.CROOKED_PINE: tint = colors.tree_leaf
	elif kind==Kind.WEEPING_WILLOW: tint = colors.tree_leaf_light.darkened(.06)
	if foliage_tint.a>0: tint = foliage_tint
	for paint in _leaf_paints:
		paint.shader = LEAF_SHADER
		paint.set_shader_parameter("scene_lighting",style.scene_lighting)
		var shade: float = paint.get_meta("leaf_shade")
		var tone := tint.lightened(shade) if shade>=0 else tint.darkened(-shade)
		paint.set_shader_parameter("top_color",tone.lightened(.035))
		paint.set_shader_parameter("front_color",tone.darkened(.04))
		paint.set_shader_parameter("side_color",tone.darkened(.15))
