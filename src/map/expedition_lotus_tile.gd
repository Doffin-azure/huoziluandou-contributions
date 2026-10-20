extends "res://src/map/expedition_garden_asset_base.gd"
## One-grid lotus water tile. Only exposed banks are built; eight neighbours
## decide straight shores, mitred outer corners and curved island corners.
enum Plant { WATER, LEAVES, BUD, BLOOM, WITHERED, STEP, SMALL_LEAVES, SMALL_CLUSTER }
const LEAF_LAYER = preload("res://src/map/expedition_lotus_leaf_layer.gd")
const PITCH := 2.0
const WATER_Y := -.64
const BANK_WIDTH := .16
const CARDINALS := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const DIAGONALS := [Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1)]
@export var plant: Plant = Plant.BLOOM
@export var plants_only := false
@export var water_height := WATER_Y
@export_flags("North","East","South","West") var water_neighbours := 0
@export_flags("NorthEast","SouthEast","SouthWest","NorthWest") var diagonal_neighbours := 0
@export var lotus_colors: ExpeditionLotusPalette = preload("res://assets/expedition/lotus/lotus_night.tres")
@export var glyph_text := "回"
@export var layout_seed := 137
@export var small_leaf_count := Vector2i(3,6)
@export var small_leaf_radius := Vector2(.075,.22)
var water: MeshInstance3D
var bank_count := 0
var island_corners := 0
var plants: Node3D
var _paints: Dictionary = {}
var _water_paint: ShaderMaterial
var foliage: Node3D
var water_test: Callable


func _build() -> void:
	name = ["LotusWater","LotusLeaves","LotusBud","LotusBloom","WitheredLotus","LotusSteppingStone","SmallLotusLeaves","SmallLotusCluster"][plant]
	footprint = Vector2.ONE*PITCH
	map_scale = .5
	set_meta("tile_pitch",PITCH)
	set_meta("water_height",water_height)
	set_meta("decorative_only",true)
	set_meta("connections",[Vector3(0,0,-1),Vector3(1,0,0),Vector3(0,0,1),Vector3(-1,0,0)])
	if not plants_only:
		_build_water()
		_build_banks()
	plants = Node3D.new()
	plants.name = "LotusPlants"
	add_child(plants)
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	match plant:
		Plant.LEAVES:
			_make_leaves(rng.randi_range(3,5),rng.randi_range(0,1))
		Plant.BUD:
			_make_leaves(rng.randi_range(2,4),1,false,[Rect2(.07,-.10,.26,.27)])
			_flower(Vector3(.20,water_height+.27,.04),true)
		Plant.BLOOM:
			_make_leaves(rng.randi_range(2,4),1,false,[Rect2(.04,-.03,.26,.26)])
			_flower(Vector3(.17,water_height+.28,.10),false)
		Plant.WITHERED:
			_make_leaves(rng.randi_range(2,4),1,true)
			_stem(Vector3(.13,water_height,.0),Vector3(.05,water_height+.24,.01),.018)
			_stem(Vector3(.05,water_height+.24,.01),Vector3(.15,water_height+.39,.04),.015)
			var head := cylinder(Vector3(.15,water_height+.405,.04),.065,.055,"bronze",plants,7)
			head.material_override = _paint("dry")
		Plant.STEP: _stepping_stone()
		Plant.SMALL_LEAVES,Plant.SMALL_CLUSTER:
			_make_leaves(rng.randi_range(maxi(0,mini(small_leaf_count.x,small_leaf_count.y)),maxi(0,maxi(small_leaf_count.x,small_leaf_count.y))),0)
	if not plants_only and plant!=Plant.WATER and plant<Plant.SMALL_LEAVES:
		_ripple(Vector2(-.16,.08),.68,.70,3.2)
		_ripple(Vector2(.10,-.06),.79,-1.3,.1)
	lotus_colors.changed.connect(_refresh_lotus)
	_refresh_lotus()


func _exit_tree() -> void:
	if lotus_colors!=null and lotus_colors.changed.is_connected(_refresh_lotus): lotus_colors.changed.disconnect(_refresh_lotus)
	super._exit_tree()


func refresh_palette() -> void:
	super.refresh_palette()
	_refresh_lotus()


func _build_water() -> void:
	water = MeshInstance3D.new()
	water.name = "ContinuousLotusWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE*PITCH
	water.mesh = plane
	water.position.y = water_height
	_water_paint = ShaderMaterial.new()
	_water_paint.shader = preload("res://src/shaders/expedition_lotus_water.gdshader")
	water.material_override = _water_paint
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_banks() -> void:
	for side in 4:
		if water_neighbours & (1<<side): continue
		var left := not bool(water_neighbours & (1<<posmod(side-1,4)))
		var right := not bool(water_neighbours & (1<<((side+1)%4)))
		var outer_a := Vector3(-1,0,-1)
		var outer_b := Vector3(1,0,-1)
		var inner_a := Vector3(-1+(BANK_WIDTH if left else 0),0,-1+BANK_WIDTH)
		var inner_b := Vector3(1-(BANK_WIDTH if right else 0),0,-1+BANK_WIDTH)
		var shape := SurfaceTool.new()
		shape.begin(Mesh.PRIMITIVE_TRIANGLES)
		_quad(shape,[outer_a,outer_b,inner_b,inner_a],Vector3.UP)
		var bottom_a := inner_a+Vector3.DOWN*.94
		var bottom_b := inner_b+Vector3.DOWN*.94
		_quad(shape,[inner_a,inner_b,bottom_b,bottom_a],Vector3.BACK)
		_quad(shape,[outer_a,outer_a+Vector3.DOWN*.94,outer_b+Vector3.DOWN*.94,outer_b],Vector3.FORWARD)
		var part := style.mesh(self,shape.commit(),Vector3.ZERO,"stone",.8)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.name = "ExposedBank%d" % side
		part.rotation.y = -side*PI*.5
		var direction := Basis(Vector3.UP,-side*PI*.5)
		ink([direction*(inner_a+Vector3.UP*.003),direction*(inner_b+Vector3.UP*.003)],.35)
		bank_count += 1
	for corner in 4:
		if not (water_neighbours & (1<<corner)) or not (water_neighbours & (1<<((corner+1)%4))): continue
		if diagonal_neighbours & (1<<corner): continue
		# Only the diagonal land touches this tile: a quarter-circle of stone
		# joins the neighbouring banks instead of leaving a pinhole at the island.
		var turn := Basis(Vector3.UP,-corner*PI*.5)
		var pivot := Vector3(1,0,-1)
		var shape := SurfaceTool.new()
		shape.begin(Mesh.PRIMITIVE_TRIANGLES)
		var line: Array[Vector3] = []
		for i in 9:
			var angle := PI*.5*i/8.0
			line.append(pivot+Vector3(-cos(angle)*BANK_WIDTH,0,sin(angle)*BANK_WIDTH))
		for i in 8:
			_triangle(shape,pivot,line[i],line[i+1],Vector3.UP)
			var normal := (line[i]+line[i+1])*.5-pivot
			_quad(shape,[line[i],line[i+1],line[i+1]+Vector3.DOWN*.94,line[i]+Vector3.DOWN*.94],normal.normalized())
		var part := style.mesh(self,shape.commit(),Vector3.ZERO,"stone",.75)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		part.name = "IslandCorner%d" % corner
		part.basis = turn
		var contour: Array[Vector3] = []
		for point in line: contour.append(turn*(point+Vector3.UP*.003))
		ink(contour,.35)
		island_corners += 1


func _paint(role: String) -> ShaderMaterial:
	if not _paints.has(role):
		var paint := ShaderMaterial.new()
		paint.shader = preload("res://src/shaders/expedition_lotus_petals.gdshader") if role in ["petal","inner"] else preload("res://src/shaders/expedition_lit_faces.gdshader")
		_paints[role] = paint
	return _paints[role]


func _refresh_lotus() -> void:
	if _water_paint!=null:
		_water_paint.set_shader_parameter("deep_color",lotus_colors.water_deep)
		_water_paint.set_shader_parameter("light_color",lotus_colors.water_light)
	for role: String in _paints:
		var paint: ShaderMaterial = _paints[role]
		if role in ["petal","inner"]:
			paint.set_shader_parameter("base_color",lotus_colors.petal_base if role=="petal" else lotus_colors.petal_tip)
			paint.set_shader_parameter("tip_color",lotus_colors.petal_tip if role=="petal" else lotus_colors.petal_inner)
		else:
			var colors: Array[Color] = [lotus_colors.leaf_light,lotus_colors.leaf,lotus_colors.leaf_shadow]
			if role=="dry": colors = [lotus_colors.withered,lotus_colors.withered.darkened(.12),lotus_colors.withered.darkened(.30)]
			elif role=="seed": colors = [lotus_colors.seed,lotus_colors.seed.darkened(.1),lotus_colors.seed.darkened(.25)]
			paint.set_shader_parameter("top_color",colors[0])
			paint.set_shader_parameter("front_color",colors[1])
			paint.set_shader_parameter("side_color",colors[2])
	for paint: ShaderMaterial in _inks.values():
		if paint.get_meta("role")=="ripple": paint.set_shader_parameter("ink_color",lotus_colors.ripple)


func _make_leaves(count: int, large := 0, dry := false, avoid: Array[Rect2] = []) -> void:
	foliage = LEAF_LAYER.new()
	foliage.layout_seed = layout_seed
	foliage.lotus_colors = lotus_colors
	foliage.small_leaf_count = count
	foliage.large_leaf_count = large
	foliage.small_radius = small_leaf_radius
	foliage.clustered = plant==Plant.SMALL_CLUSTER
	foliage.withered = dry
	foliage.keepouts = avoid
	foliage.water_height = water_height
	foliage.water_test = water_test
	plants.add_child(foliage)
	foliage.setup(style)


func _stem(a: Vector3, b: Vector3, radius: float) -> void:
	var stem := beam(a,b,radius*2,"patina",plants)
	stem.material_override = _paint("leaf")


func _flower(at: Vector3, bud: bool) -> void:
	_stem(Vector3(at.x,water_height,at.z),at,.015)
	var holder := Node3D.new()
	holder.position = at
	plants.add_child(holder)
	for ring in (1 if bud else 2):
		var count := 5 if bud else (8 if ring==0 else 6)
		for n in count:
			var part := _petal(.29 if ring==0 else .19,.18 if ring==0 else .14,.05 if ring==0 else .17,bud)
			var petal := style.mesh(holder,part,Vector3(0,.02*ring,0),"stone",.65)
			petal.name = "LotusPetal"
			petal.rotation.y = TAU*n/count+ring*.43
			petal.material_override = _paint("petal" if ring==0 else "inner")
	if not bud:
		var seed := cylinder(Vector3(0,.115,0),.052,.045,"bronze",holder,7)
		seed.material_override = _paint("seed")


func _petal(length: float, width: float, rise: float, bud: bool) -> ArrayMesh:
	var shape := SurfaceTool.new()
	shape.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in 12:
		for x in 6:
			var points: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for offset: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var u := (x+offset.x)/6.0
				var t := (y+offset.y)/12.0
				points.append(_petal_point(u,t,length,width,rise,bud))
				uvs.append(Vector2(u,t))
			for tri in [[0,1,2],[0,2,3]]:
				for i in tri:
					var u := uvs[i].x
					var t := uvs[i].y
					var across := _petal_point(minf(u+.01,1),t,length,width,rise,bud)-_petal_point(maxf(u-.01,0),t,length,width,rise,bud)
					var along := _petal_point(u,minf(t+.01,1),length,width,rise,bud)-_petal_point(u,maxf(t-.01,0),length,width,rise,bud)
					shape.set_normal(along.cross(across).normalized())
					shape.set_uv(uvs[i])
					shape.add_vertex(points[i])
	return shape.commit()


func _petal_point(u: float, t: float, length: float, width: float, rise: float, bud: bool) -> Vector3:
	var half_width := pow(maxf(.0001,sin(PI*t)),.8)*width*.5
	var radius := .025+length*t
	var height := .025+.105*sin(PI*t)+rise*t-(u-.5)*(u-.5)*.08
	if bud:
		radius = .018+sin(PI*t)*.10
		height = t*.31
	return Vector3((u*2-1)*half_width,height,radius)


func _ripple(center: Vector2, radius: float, begin: float, end: float) -> void:
	var points: Array[Vector3] = []
	for n in 16:
		var angle := lerpf(begin,end,n/15.0)
		points.append(Vector3(center.x+cos(angle)*radius,water_height+.006,center.y+sin(angle)*radius*.72))
	ink(points,.20,"ripple")


func _stepping_stone() -> void:
	box(Vector3(0,-.25,0),Vector3(.80,.50,.74),"architecture",.75)
	box(Vector3(0,-.06,0),Vector3(.99,.12,.86),"stone",.85)
	var top := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(.97,.84)
	top.mesh = plane
	top.position.y = .001
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://src/shaders/expedition_ground.gdshader")
	var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var white := ImageTexture.create_from_image(image)
	paint.set_shader_parameter("fog_mask",white)
	paint.set_shader_parameter("land_mask",white)
	top.material_override = paint
	add_child(top)
	if not glyph_text.is_empty():
		var glyph := INLAY.new()
		glyph.scale = Vector3.ONE*.75
		add_child(glyph)
		glyph.setup(glyph_text,style.palette,Ink.serif)
		glyph.set_floor_imprint(true,paint)
	_make_leaves(3,0,false,[Rect2(-.52,-.46,1.04,.92)])


static func assemble(parent: Node3D, paint: ExpeditionFlatStyle, cells: Dictionary, colors: ExpeditionLotusPalette, seed_value := 137) -> Node3D:
	var result := Node3D.new()
	result.name = "JoinedLotusPond"
	parent.add_child(result)
	var source: Script = load("res://src/map/expedition_lotus_tile.gd")
	for cell: Vector2i in cells:
		var tile: Node3D = source.new()
		tile.position = Vector3(cell.x*PITCH,0,cell.y*PITCH)
		tile.plant = int(cells[cell])
		if tile.plant==Plant.SMALL_CLUSTER:
			tile.small_leaf_count = Vector2i(5,8)
			tile.small_leaf_radius = Vector2(.07,.17)
		tile.lotus_colors = colors
		tile.layout_seed = seed_value+cell.x*73856093+cell.y*19349663
		for side in 4:
			if cells.has(cell+CARDINALS[side]): tile.water_neighbours |= 1<<side
			if cells.has(cell+DIAGONALS[side]): tile.diagonal_neighbours |= 1<<side
		tile.set_meta("cell",cell)
		result.add_child(tile)
		tile.setup(paint)
		# Independent seeded layouts replace rotating the same fixed pair of leaves.
	result.set_meta("tile_count",cells.size())
	return result
