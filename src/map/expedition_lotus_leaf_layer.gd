extends "res://src/map/expedition_garden_asset_base.gd"
## Reusable foliage only: independent local RNG, no water or shore geometry.
@export var lotus_colors: ExpeditionLotusPalette = preload("res://assets/expedition/lotus/lotus_night.tres")
@export var layout_seed := 137
@export_range(0,64,1) var small_leaf_count := 5
@export_range(0,16,1) var large_leaf_count := 0
@export var small_radius := Vector2(.075,.22)
@export var large_radius := Vector2(.27,.40)
@export var half_extent := Vector2(.82,.82)
@export var water_height := -.64
@export var clustered := false
@export var withered := false
var water_test: Callable
var keepouts: Array[Rect2] = []
var leaf_specs: Array[Dictionary] = []
var _leaf_paints: Dictionary = {}


func _build() -> void:
	name = "ScatteredLotusLeaves"
	footprint = half_extent*2
	set_meta("decorative_only",true)
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var anchors := [Vector2(rng.randf_range(-.45,.45),rng.randf_range(-.45,.45))*half_extent,Vector2(rng.randf_range(-.55,.55),rng.randf_range(-.55,.55))*half_extent]
	for index in large_leaf_count+small_leaf_count:
		var range_value := large_radius if index<large_leaf_count else small_radius
		var radius := rng.randf_range(minf(range_value.x,range_value.y),maxf(range_value.x,range_value.y))
		for attempt in 120:
			var at := Vector2(rng.randf_range(-half_extent.x,half_extent.x),rng.randf_range(-half_extent.y,half_extent.y))
			if clustered and attempt<85 and index%4!=3:
				at = anchors[index%2]+Vector2(rng.randf_range(-.32,.32),rng.randf_range(-.32,.32))
			if not _accept(at,radius): continue
			var turn := rng.randf_range(-PI,PI)
			var stretch := Vector2(rng.randf_range(.86,1.04),rng.randf_range(.76,1.03))
			var tone := rng.randi_range(-1,1)
			leaf_specs.append({"at":at,"radius":radius,"turn":turn,"stretch":stretch,"tone":tone})
			_leaf(at,radius,turn,stretch,tone,rng.randf_range(-PI,PI))
			break
	lotus_colors.changed.connect(_refresh_leaves)
	_refresh_leaves()


func _accept(at: Vector2, radius: float) -> bool:
	var margin := radius*1.14
	if absf(at.x)+margin>half_extent.x or absf(at.y)+margin>half_extent.y: return false
	for rect in keepouts:
		if rect.grow(margin).has_point(at): return false
	for leaf in leaf_specs:
		if at.distance_to(leaf.at)<(radius+leaf.radius)*1.10: return false
	if water_test.is_valid():
		if not water_test.call(at): return false
		for i in 12:
			if not water_test.call(at+Vector2.from_angle(TAU*i/12.0)*margin): return false
	return true


func _leaf(at: Vector2, radius: float, turn: float, stretch: Vector2, tone: int, phase: float) -> void:
	var holder := Node3D.new()
	holder.name = "FloatingLeaf"
	holder.position = Vector3(at.x,water_height+.026,at.y)
	holder.rotation.y = turn
	holder.scale = Vector3(stretch.x,1,stretch.y)
	holder.set_meta("radius",radius)
	add_child(holder)
	var polygon := PackedVector2Array([Vector2.ZERO])
	for n in 29:
		var angle := .10+(TAU-.20)*n/28.0
		var r := radius*(1+sin(angle*3+phase)*.035+cos(angle*7-phase)*.025)
		polygon.append(Vector2(cos(angle)*r,sin(angle)*r))
	var shape := SurfaceTool.new()
	shape.begin(Mesh.PRIMITIVE_TRIANGLES)
	for n in range(1,polygon.size()-1):
		_triangle(shape,Vector3(0,-.006,0),Vector3(polygon[n].x,.006,polygon[n].y),Vector3(polygon[n+1].x,.006,polygon[n+1].y),Vector3.UP)
		_triangle(shape,Vector3(0,-.017,0),Vector3(polygon[n].x,-.005,polygon[n].y),Vector3(polygon[n+1].x,-.005,polygon[n+1].y),Vector3.DOWN)
	for n in polygon.size():
		var a := polygon[n]
		var b := polygon[(n+1)%polygon.size()]
		_quad(shape,[Vector3(a.x,.006,a.y),Vector3(b.x,.006,b.y),Vector3(b.x,-.005,b.y),Vector3(a.x,-.005,a.y)],Vector3(a.x+b.x,0,a.y+b.y).normalized())
	var leaf := style.mesh(holder,shape.commit(),Vector3.ZERO,"stone",clampf(radius*2.4,.26,.85))
	leaf.name = "NotchedLotusLeaf"
	leaf.material_override = _paint(tone)
	leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var veins := 2 if radius<.12 else (3 if radius<.23 else 5)
	for n in veins:
		var angle := .65+n*TAU/(veins+1.0)
		ink([Vector3(radius*.14*cos(angle),.010,radius*.14*sin(angle)),Vector3(radius*.45*cos(angle+.03),.012,radius*.45*sin(angle+.03)),Vector3(radius*.82*cos(angle),.013,radius*.82*sin(angle))],.12 if radius<.23 else .20,"ink",holder)
	if withered:
		ink([Vector3(-radius*.10,.014,-radius*.07),Vector3(-radius*.46,.014,-radius*.23),Vector3(-radius*.64,.014,-radius*.12)],.20,"ink",holder)


func _paint(tone: int) -> ShaderMaterial:
	if not _leaf_paints.has(tone):
		var paint := ShaderMaterial.new()
		paint.shader = preload("res://src/shaders/expedition_lit_faces.gdshader")
		_leaf_paints[tone] = paint
	return _leaf_paints[tone]


func _refresh_leaves() -> void:
	for tone: int in _leaf_paints:
		var paint: ShaderMaterial = _leaf_paints[tone]
		var colors: Array[Color] = [lotus_colors.leaf_light,lotus_colors.leaf,lotus_colors.leaf_shadow]
		if withered: colors = [lotus_colors.withered,lotus_colors.withered.darkened(.12),lotus_colors.withered.darkened(.30)]
		for i in colors.size(): colors[i] = colors[i].lightened(tone*.025) if tone>0 else colors[i].darkened(-tone*.055)
		paint.set_shader_parameter("top_color",colors[0])
		paint.set_shader_parameter("front_color",colors[1])
		paint.set_shader_parameter("side_color",colors[2])


func _exit_tree() -> void:
	if lotus_colors!=null and lotus_colors.changed.is_connected(_refresh_leaves): lotus_colors.changed.disconnect(_refresh_leaves)
	super._exit_tree()
