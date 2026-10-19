extends Node3D
## Decorative courtyard fixture: shared flat materials, real depth, no gameplay cells or RNG.
const TREE = preload("res://src/map/expedition_stylized_tree.gd")
const SHRINE = preload("res://src/map/expedition_stylized_shrine.gd")
const TOMBSTONE = preload("res://src/map/expedition_tombstone.gd")
const BRONZE_LAMP = preload("res://src/map/expedition_bronze_lamp.gd")
var style: ExpeditionFlatStyle
var camera: Camera3D
var foreground: Node3D
var distant_layer: Node3D
var near_anchor: Node3D
var far_anchor: Node3D
var tree: Node3D
var shrine: Node3D
var tombstones: Array[Node3D] = []
var guide_lamps: Array[Node3D] = []
var _sky: ProceduralSkyMaterial
var _water: ShaderMaterial
var _lamp: StandardMaterial3D
var _halo: ShaderMaterial
var _environment: Environment


func setup(painter: ExpeditionFlatStyle, view: Camera3D, settings: Environment) -> void:
	style = painter
	camera = view
	_environment = settings
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_energy_multiplier = 1
	_sky.ground_energy_multiplier = 1
	_sky.sun_angle_max = 0
	var sky := Sky.new()
	sky.sky_material = _sky
	_environment.sky = sky
	_environment.background_mode = Environment.BG_SKY
	_water = ShaderMaterial.new()
	_water.shader = preload("res://src/shaders/expedition_moat.gdshader")
	_halo = ShaderMaterial.new()
	_halo.shader = preload("res://src/shaders/expedition_ground_glow.gdshader")
	_halo.set_shader_parameter("tint",Color(1.0,.72,.35,.17))
	_lamp = _plain(Color("f4c782"))
	_lamp.emission_enabled = true
	_lamp.emission = Color("ffc178")
	_lamp.emission_energy_multiplier = .28
	_ground()
	_courtyard()
	_distant()
	_foreground()
	refresh_palette()
	style.palette.changed.connect(refresh_palette)


func _exit_tree() -> void:
	if style != null and style.palette.changed.is_connected(refresh_palette): style.palette.changed.disconnect(refresh_palette)


func _box(parent: Node3D, position: Vector3, size: Vector3, role := "architecture", outline := .7) -> MeshInstance3D:
	return style.mesh(parent,TypeMeshes.beveled_box(size,.008),position,role,outline)


func _plain(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result


func _plane(parent: Node3D, center: Vector3, size: Vector2, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	result.mesh = plane
	result.position = center
	result.material_override = material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result


func _ground() -> void:
	# A local moat must not cover the distant silhouettes on the lower, opposite bank.
	_plane(self,Vector3(1.5,-.24,2.10),Vector2(12,5.60),_water)
	# Four border strips meet the existing 3×3 surface without another tile frame.
	_box(self,Vector3(1.5,-.06,-.28),Vector3(4.10,.12,.56),"stone",.45)
	_box(self,Vector3(-.275,-.06,1.5),Vector3(.55,.12,3),"stone",.45)
	_box(self,Vector3(3.275,-.06,1.5),Vector3(.55,.12,3),"stone",.45)
	_box(self,Vector3(1.5,-.06,3.25),Vector3(4.10,.12,.50),"stone",.45)
	# Open foreground landing, with short steps down to a lower, decorative riverside.
	for n in 3:
		_box(self,Vector3(1.45,-.035-n*.055,3.56+n*.19),Vector3(1.18,.07,.20),"stone",.45)
	for x in [-.44,3.44]:
		_box(self,Vector3(x,-.23,1.5),Vector3(.22,.34,4.1),"architecture",.45)
		for z in [.05,1.05,2.05,3.1]: _box(self,Vector3(x,-.07,z),Vector3(.245,.065,.15),"copper_dark",.35)
	# Asymmetric stone splinters in the ink-river, not rows of identical rocks.
	for entry in [[-1.15,2.65,.45,.3],[-.98,3.32,.24,.18],[4.15,1.75,.42,.35],[3.92,3.70,.32,.22]]:
		var shard := _box(self,Vector3(entry[0],-.19,entry[1]),Vector3(entry[2],.14,entry[3]),"architecture",.4)
		shard.rotation.y = .17


func _courtyard() -> void:
	# Gate is kept behind the playable slab; every primary inscription stays visible.
	var gate := Node3D.new()
	gate.position = Vector3(1.48,0,-.42)
	add_child(gate)
	for x in [-.55,.55]:
		_box(gate,Vector3(x,.07,0),Vector3(.28,.14,.34),"architecture")
		_box(gate,Vector3(x,.49,0),Vector3(.18,.80,.23),"architecture")
		_box(gate,Vector3(x,.40,.125),Vector3(.065,.34,.016),"copper_dark",.35)
	_box(gate,Vector3(0,.88,0),Vector3(1.36,.15,.30),"architecture")
	_roof(gate,Vector3(0,.96,0),1.52,.56,"roof",.65)
	_box(gate,Vector3(0,.81,.172),Vector3(.31,.17,.025),"copper_dark",.45)
	_seal(gate,Vector3(0,.81,.191),.058)
	for x in [-.77,.77]:
		_box(gate,Vector3(x,.65,0),Vector3(.28,.045,.09),"copper_dark",.35)
		_lantern(gate,Vector3(x,.44,0),.65)
	# A wall mass left and a capped return right, with sparse structural engraving.
	_wall(Vector3(.08,0,-.42),.95,.58)
	_wall(Vector3(3.03,0,-.42),1.1,.69)
	shrine = SHRINE.new()
	shrine.name = "StoneQuestionShrine"
	shrine.position = Vector3(3.64,0,.48)
	shrine.rotation.y = -.22
	shrine.scale = Vector3.ONE*.60
	add_child(shrine)
	shrine.setup(style)
	# Tablets are clustered and varied in silhouette; side slabs are never selectable.
	for entry in [[-.83,.50,.56,0],[-1.36,1.23,.53,1],[-.78,1.80,.49,2],[-.94,2.46,.46,3]]:
		var tablet: Node3D = TOMBSTONE.new()
		tablet.variant = int(entry[3])
		tablet.position = Vector3(entry[0],0,entry[1])
		tablet.scale = Vector3.ONE*float(entry[2])
		tablet.rotation_degrees.y = -8
		add_child(tablet)
		tablet.setup(style)
		tombstones.append(tablet)
	# Copper service line is built into the wall, rather than sprinkled on every stone.
	for x in [2.62,3.18]:
		_box(self,Vector3(x,.30,-.20),Vector3(.035,.34,.032),"copper_dark",.25)
	_box(self,Vector3(2.90,.47,-.20),Vector3(.595,.034,.032),"copper_dark",.25)
	for x in [2.62,3.18]: _box(self,Vector3(x,.44,-.17),Vector3(.09,.07,.035),"copper_dark",.3)
	# Two low river lamps establish the warm accents on the foreground approach.
	for x in [.58,2.43]:
		var guide: Node3D = BRONZE_LAMP.new()
		guide.position = Vector3(x,0,3.28)
		guide.scale = Vector3.ONE*.27
		add_child(guide)
		guide.setup(style)
		guide_lamps.append(guide)
	_ground_shadow(PackedVector2Array([Vector2(-.5,-.3),Vector2(.52,-.3),Vector2(.88,.34),Vector2(-.15,.34)]))


func _wall(origin: Vector3, width: float, height: float) -> void:
	_box(self,origin+Vector3(0,height*.5,0),Vector3(width,height,.24),"architecture",.6)
	_box(self,origin+Vector3(0,height+.04,0),Vector3(width+.08,.08,.33),"roof",.4)
	_box(self,origin+Vector3(0,.11,.133),Vector3(width-.13,.035,.015),"roof",0)
	for x in [-width*.37,width*.37]:
		_box(self,origin+Vector3(x,height*.47,.134),Vector3(.026,height*.51,.012),"roof",0)


func _lantern(parent: Node3D, center: Vector3, scale_value: float) -> void:
	var holder := Node3D.new()
	holder.position = center
	holder.scale = Vector3.ONE*scale_value
	parent.add_child(holder)
	_box(holder,Vector3(0,-.087,0),Vector3(.21,.035,.19),"foreground",.45)
	var pane := MeshInstance3D.new()
	pane.mesh = TypeMeshes.beveled_box(Vector3(.145,.13,.145),0)
	pane.material_override = _lamp
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(pane)
	# Four corner ribs leave the warm pane legible from above.
	for x in [-.075,.075]:
		for z in [-.075,.075]: _box(holder,Vector3(x,0,z),Vector3(.023,.19,.023),"copper_dark",.25)
	_box(holder,Vector3(0,.137,0),Vector3(.24,.055,.22),"roof",.4)
	var glow := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(.60,.65)
	glow.mesh = plane
	glow.material_override = _halo
	glow.position = camera.basis.z*.12
	glow.basis = camera.basis
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(glow)


func _seal(parent: Node3D, center: Vector3, radius: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = radius*.76
	ring.outer_radius = radius
	ring.rings = 20
	ring.ring_segments = 6
	var node := style.mesh(parent,ring,center,"copper_dark",0)
	node.rotation_degrees.x = 90
	_box(parent,center+Vector3(0,0,.01),Vector3(radius*.33,radius*.66,.015),"seal",0)


func _roof(parent: Node3D, center: Vector3, width: float, depth: float, role: String, outline: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var xs := [-.59,-.43,0.0,.43,.59]
	for index in range(xs.size()-1):
		for side in [-1.0,1.0]:
			var xa: float = xs[index]*width
			var xb: float = xs[index+1]*width
			var lift_a: float = .11*width if index==0 else 0.0
			var lift_b: float = .11*width if index==3 else 0.0
			var a := Vector3(xa,lift_a,side*depth*.57)
			var b := Vector3(xb,lift_b,side*depth*.57)
			var c := Vector3(xb,.16*width,0)
			var d := Vector3(xa,.16*width,0)
			_quad(surface,[a,b,c,d],Vector3.UP)
			_quad(surface,[a-Vector3.UP*.045,b-Vector3.UP*.045,b,a],Vector3(0,0,side))
	var mesh := surface.commit()
	style.mesh(parent,mesh,center,role,outline)
	_box(parent,center+Vector3(0,.16*width+.016,0),Vector3(width*1.13,.035,.055),role,.0 if role in ["distant","distant_back"] else .3)
	if role not in ["distant","distant_back"]:
		# A few narrow structural strokes refine the roof; no noisy shingle texture.
		for fraction in [-.30,0,.30]:
			var start := center+Vector3(fraction*width,.16*width+.005,.03)
			var end := center+Vector3(fraction*width,.01,depth*.55)
			_stroke(parent,start,end,.008,"foreground")


func _distant() -> void:
	distant_layer = Node3D.new()
	distant_layer.name = "DistantTablets"
	add_child(distant_layer)
	# The negative height puts the distant temples on the opposite bank, not above the camera.
	for entry in [[-2.85,-4.15,-3.1,1.0],[4.55,-4.35,-3.4,.86]]:
		var bank := Node3D.new()
		bank.position = Vector3(entry[0],entry[1],entry[2])
		bank.scale = Vector3.ONE*float(entry[3])
		distant_layer.add_child(bank)
		var ridge := PackedVector2Array([Vector2(-2.0,-1),Vector2(1.95,-1),Vector2(1.73,1.24),Vector2(1.25,1.33),Vector2(.96,1.65),Vector2(.48,1.60),Vector2(.20,1.95),Vector2(-.19,2.08),Vector2(-.64,1.81),Vector2(-.93,1.58),Vector2(-1.45,1.55),Vector2(-1.87,1.20)])
		style.mesh(bank,_extruded(ridge,.45),Vector3.ZERO,"distant",0)
		# A low pavilion grows out of the same bank silhouette.
		_box(bank,Vector3(-.15,2.11,0),Vector3(.72,.09,.59),"distant",0)
		for x in [-.43,.13]: _box(bank,Vector3(x,2.35,0),Vector3(.065,.44,.065),"distant",0)
		_roof(bank,Vector3(-.15,2.59,0),1.05,.68,"distant",0)
	for entry in [[-3.4,-4.7,-4.5,1.65,1.55],[-.5,-5.0,-5.2,2.15,1.20],[3.0,-4.8,-5.0,1.75,1.50],[5.3,-5.0,-5.5,2.30,1.10]]:
		var tower := Node3D.new()
		tower.position = Vector3(entry[0],entry[1],entry[2])
		distant_layer.add_child(tower)
		var height: float = entry[3]
		var width: float = entry[4]
		_box(tower,Vector3(0,height*.5,0),Vector3(width*.82,height,.72),"distant_back",0)
		_roof(tower,Vector3(0,height*.55,0),width*1.12,.94,"distant_back",0)
		_roof(tower,Vector3(0,height,0),width,.90,"distant_back",0)
		_box(tower,Vector3(0,height*.43,.43),Vector3(width*.74,.13,.16),"distant_back",0)
	for entry in [[-.8,-2.8,-3.5,1.25],[2.4,-2.7,-3.2,1.40]]:
		var stone := Node3D.new()
		stone.position = Vector3(entry[0],entry[1],entry[2])
		distant_layer.add_child(stone)
		_box(stone,Vector3(0,.7,0),Vector3(.45,float(entry[3]),.50),"distant",0)
		_roof(stone,Vector3(0,float(entry[3])*.5+.73,0),.85,.7,"distant",0)
	far_anchor = Node3D.new()
	far_anchor.position = Vector3(-2.4,-2.5,-2.8)
	distant_layer.add_child(far_anchor)


func _foreground() -> void:
	foreground = Node3D.new()
	foreground.name = "ForegroundFrame"
	add_child(foreground)
	# Upright flat branch silhouettes and ribbons sit in real 3D space.
	for side in [-1,1]:
		var post := Node3D.new()
		post.position = Vector3(-1.45 if side<0 else 4.55,0,3.35)
		foreground.add_child(post)
		_box(post,Vector3(0,-.11,0),Vector3(.70,.22,.67),"architecture",.5)
		_box(post,Vector3(0,.08,0),Vector3(.37,.16,.45),"foreground",.65)
		_box(post,Vector3(0,.86,0),Vector3(.20,1.55,.24),"foreground",.8)
		_box(post,Vector3(0,1.68,0),Vector3(.43,.10,.40),"foreground",.6)
		_roof(post,Vector3(-side*.19,1.76,0),1.03,.62,"foreground",.7)
		_box(post,Vector3(0,1.05,.13),Vector3(.11,.15,.015),"copper_dark",.3)
		var ribbon := PackedVector2Array([Vector2(-.07,0),Vector2(.08,0),Vector2(.055,-.26),Vector2(.10,-.54),Vector2(.04,-.72),Vector2(-.015,-.64),Vector2(-.045,-.73),Vector2(-.035,-.39)])
		var cloth := style.mesh(post,_extruded(ribbon,.006),Vector3(-side*.30,1.61,.18),"foliage",.35)
		cloth.rotation.y = deg_to_rad(12)
		_lantern(post,Vector3(-side*.34,1.36,.09),.65)
	near_anchor = Node3D.new()
	near_anchor.position = Vector3(-1.45,.86,3.35)
	foreground.add_child(near_anchor)
	tree = TREE.new()
	tree.name = "UnderworldPine"
	tree.position = Vector3(-1.66,0,1.1)
	foreground.add_child(tree)
	tree.setup(style,camera)


func _stroke(parent: Node3D, a: Vector3, b: Vector3, width: float, role: String) -> void:
	var line := _box(parent,(a+b)*.5,Vector3(width,a.distance_to(b),width),role,0)
	line.quaternion = Quaternion(Vector3.UP,(b-a).normalized())


func _extruded(profile: PackedVector2Array, depth: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(profile)
	for side in [-1.0,1.0]:
		for n in range(0,indices.size(),3):
			var vertices: Array[Vector3] = []
			for j in 3:
				var p: Vector2 = profile[indices[n+j]]
				vertices.append(Vector3(p.x,p.y,side*depth*.5))
			_triangle(surface,vertices[0],vertices[1],vertices[2],Vector3(0,0,side))
	for n in profile.size():
		var a := profile[n]
		var b := profile[(n+1)%profile.size()]
		var normal := Vector3(b.y-a.y,a.x-b.x,0).normalized()
		_quad(surface,[Vector3(a.x,a.y,-depth*.5),Vector3(b.x,b.y,-depth*.5),Vector3(b.x,b.y,depth*.5),Vector3(a.x,a.y,depth*.5)],normal)
	return surface.commit()


func _quad(surface: SurfaceTool, vertices: Array, normal: Vector3) -> void:
	_triangle(surface,vertices[0],vertices[1],vertices[2],normal)
	_triangle(surface,vertices[0],vertices[2],vertices[3],normal)


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var points := [a,c,b] if (b-a).cross(c-a).dot(normal)>0 else [a,b,c]
	for point: Vector3 in points:
		surface.set_normal(normal)
		surface.add_vertex(point)


func _ground_shadow(points: PackedVector2Array) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(points)
	for n in range(0,indices.size(),3):
		var vertices: Array[Vector3] = []
		for j in 3:
			var point := points[indices[n+j]]
			vertices.append(Vector3(point.x,.004,point.y))
		_triangle(surface,vertices[0],vertices[1],vertices[2],Vector3.UP)
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = style.solid_material("shadow")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func refresh_palette() -> void:
	var colors := style.palette
	_sky.sky_top_color = colors.background.darkened(.35)
	_sky.sky_horizon_color = colors.mist
	_sky.ground_horizon_color = colors.mist
	_sky.ground_bottom_color = colors.background
	_sky.ground_curve = .15
	_water.set_shader_parameter("water_color",colors.water.darkened(.12))
	# One restrained lamp wash uses the existing painted-light path, without realistic gloss.
	style.set_fire_light(guide_lamps[0].to_global(Vector3(0,1.22,0)),colors.fire_light,.50 if visible else .0,1.45)
	shrine.sync_light()


func set_enabled(value: bool) -> void:
	visible = value
	refresh_palette()
