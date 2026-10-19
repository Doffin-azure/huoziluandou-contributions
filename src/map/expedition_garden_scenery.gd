extends Node3D
## Rendering adapter for generated structures and non-interactive scenery.
const ARCH = preload("res://src/map/expedition_garden_architecture.gd")
const BOUNDARY = preload("res://src/map/expedition_garden_boundary.gd")
const LEAVES = preload("res://src/map/expedition_lotus_leaf_layer.gd")
const LOTUS = preload("res://src/map/expedition_lotus_tile.gd")
const PERIMETER = preload("res://src/map/expedition_garden_perimeter.gd")
const LAYOUT = preload("res://src/expedition/garden_layout.gd")
const ASSETS = preload("res://src/expedition/garden_asset_layout.gd")
var fade_roots: Array[Node3D] = []
var records: Array[Dictionary] = []
var leaf_layer: Node3D
var perimeter: Node3D
var flower_specs: Array[Dictionary] = []
var _art: ExpeditionMapArt
var _map: Dictionary
var _last_sight := ""


func setup(ex: Expedition, art: ExpeditionMapArt) -> void:
	_art = art
	_map = ex.m
	perimeter = PERIMETER.new()
	add_child(perimeter)
	perimeter.setup(_art.style)
	records.append_array(perimeter.records)
	fade_roots.append_array(perimeter.fade_roots)
	if not _map.has("layout"):
		sync(ex)
		return
	var random := MapGen.Rng.new(int(_map.layout.decor_seed))
	var courtyard: bool = _map.layout.get("version","")=="garden_v2"
	for entry in _map.layout.structures:
		var root := Node3D.new()
		root.name = "Generated_"+str(entry.asset)
		root.position = entry.at
		root.rotation.y = entry.turn
		add_child(root)
		var width := 2.3
		var height := 1.6
		if entry.asset=="grave_bed":
			if courtyard: _make_bed(root)
			for i in (2 if courtyard else 3):
				var grave := Node3D.new()
				grave.position = Vector3(-.30+i*.48,.01,.42-i*.10) if courtyard else Vector3((i-1)*.20,0,random.next()*.24-.12)
				grave.rotation.y = (random.next()-.5)*.38
				root.add_child(grave)
				_art.tomb(grave,(i+random.ri(4))%4,.25+random.next()*.03)
			if courtyard:
				var tree := Node3D.new()
				tree.position = Vector3(-.15,0,-.24)
				root.add_child(tree)
				_art.tree(tree,.58)
			width = 1.8 if courtyard else .9
			height = 1.6 if courtyard else .7
			var fire := Node3D.new()
			fire.position = Vector3(.28,0,.20)
			root.add_child(fire)
			_art.fire(fire,.38)
		else:
			var asset := ARCH.new()
			asset.building = {"moon_gate":0,"screen_wall":1,"covered_walk":2,"bridge":3}[entry.asset]
			asset.open_floor_passage = true
			asset.scale = Vector3.ONE*.5
			if entry.asset=="covered_walk" and courtyard:
				asset.scale = Vector3.ONE*ASSETS.WALK_SCALE
				asset.position.y = ASSETS.WALK_FLOOR_Y
			if entry.asset=="bridge" and courtyard: asset.position.y = ASSETS.DECK_Y
			root.add_child(asset)
			asset.setup(_art.style)
			if entry.asset=="covered_walk":
				if courtyard: ASSETS.walk_fixtures(asset)
				else: asset.position.y = -.085
			if entry.asset=="bridge": height = .58
			if entry.asset=="covered_walk": root.set_meta("fade_roof_only",true)
			if courtyard: _make_approaches(root,entry.asset)
		root.set_meta("height",height)
		root.set_meta("visual_width",width)
		if height>.85: fade_roots.append(root)
		records.append({"root":root,"cells":entry.reveal,"outside":false})
	_make_dividers()
	_make_rails(random)
	_make_flowers()
	_make_leaves()
	_make_outside(random)
	sync(ex)


func _make_approaches(root: Node3D, asset: String) -> void:
	for patch in ASSETS.floor_patches(asset):
		var gradient: Vector2 = patch.gradient
		if gradient==Vector2.ZERO: continue
		var rect: Rect2 = patch.rect
		var corners := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
		var top: Array[Vector3] = []
		for p: Vector2 in corners: top.append(Vector3(p.x,patch.height+gradient.dot(p),p.y))
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var normal := Vector3(-gradient.x,1,-gradient.y).normalized()
		ExpeditionTerrain.triangle(surface,top[0],top[1],top[2],normal)
		ExpeditionTerrain.triangle(surface,top[0],top[2],top[3],normal)
		for i in 4:
			var a := top[i]
			var b := top[(i+1)%4]
			var low_a := Vector3(a.x,-.03,a.z)
			var low_b := Vector3(b.x,-.03,b.z)
			var side := Vector3(b.z-a.z,0,a.x-b.x).normalized()
			ExpeditionTerrain.triangle(surface,a,low_a,low_b,side)
			ExpeditionTerrain.triangle(surface,a,low_b,b,side)
		var approach := _art.style.mesh(root,surface.commit(),Vector3.ZERO,"stone",.5)
		approach.name = "GroundApproach"


func _make_bed(root: Node3D) -> void:
	var soil := MeshInstance3D.new()
	soil.name = "PlantedGardenSoil"
	soil.mesh = TypeMeshes.beveled_box(Vector3(1.75,.025,1.75),.025)
	soil.position.y = .008
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("30372f")
	paint.roughness = 1
	soil.material_override = paint
	root.add_child(soil)
	for sign_value in [-1.0,1.0]:
		_art.box(root,Vector3(sign_value*.88,.015,0),Vector3(.035,.04,1.80),"stone",.25)
		_art.box(root,Vector3(0,.015,sign_value*.88),Vector3(1.80,.04,.035),"stone",.25)


func _make_dividers() -> void:
	for run in _map.layout.get("wall_runs",[]):
		var holder := Node3D.new()
		holder.name = "AttachedCourtyardWall"
		holder.scale = Vector3.ONE*.5
		add_child(holder)
		var points: Array[Vector3] = []
		for at: Vector3 in run.points: points.append(at*2)
		var group := BOUNDARY.assemble(holder,_art.style,points,true,false,true)
		for part in group.get_children():
			var post: bool = part.piece in [BOUNDARY.Piece.WALL_POST,BOUNDARY.Piece.WALL_END]
			if post and run.omit_posts.any(func(p): return p.distance_to(part.global_position)<.01):
				group.remove_child(part)
				part.queue_free()
				continue
			var at: Vector3 = part.to_global(Vector3.ZERO if post else Vector3(1,0,0))
			part.set_meta("occlusion_center",Vector3.ZERO if post else Vector3(1,0,0))
			part.set_meta("height",1.1)
			part.set_meta("visual_width",.34 if post else 1.1)
			part.set_meta("occlusion_fade",.58)
			part.set_meta("courtyard_wall",true)
			var cells: Array = []
			for dx in [-.3,.3]:
				for dz in [-.3,.3]:
					if MapGen.inb(floori(at.z+dz),floori(at.x+dx)):
						var k := MapGen.kk(floori(at.z+dz),floori(at.x+dx))
						if not cells.has(k): cells.append(k)
			records.append({"root":part,"cells":cells,"outside":false})
			fade_roots.append(part)
		# Continuous infill closes the small masonry gaps at the gate sockets.
		for at: Vector3 in run.omit_posts:
			if at.x<=0 or at.z>=MapGen.H: continue
			var joint := Node3D.new()
			joint.position = at
			add_child(joint)
			_art.box(joint,Vector3(0,.44,0),Vector3(.13,.88,.16),"stone",.2)
			records.append({"root":joint,"cells":run.solid,"outside":false})


func _make_rails(random: MapGen.Rng) -> void:
	var candidates: Array = []
	for k in MapGen.N:
		if _map.layout.terrain_base[k]!=1 or _map.layout.bridges.has(k): continue
		var p := MapGen.rc(k)
		for side in 4:
			var n: Vector2i = p+MapGen.DIRS[side]
			if not MapGen.inb(n.x,n.y): continue
			var neighbour := MapGen.kk(n.x,n.y)
			if _map.ink[neighbour]!=0 or _map.layout.no_content.has(neighbour): continue
			var a: Vector2i
			var b: Vector2i
			match side:
				0: a = Vector2i(p.y+1,p.x); b = a+Vector2i.DOWN
				1: a = Vector2i(p.y,p.x+1); b = a+Vector2i.RIGHT
				2: a = Vector2i(p.y,p.x); b = a+Vector2i.DOWN
				3: a = Vector2i(p.y,p.x); b = a+Vector2i.RIGHT
			var supported := true
			for at in [a,b]:
				for i in 8:
					if LAYOUT.water_field(_map,Vector2(at)+Vector2.from_angle(TAU*i/8.0)*.08)>=0: supported = false
			if supported: candidates.append({"a":a,"b":b,"cell":neighbour})
	var edges: Array = []
	var links: Dictionary = {}
	for edge in random.shuf(candidates):
		if edges.size()>=7: break
		if links.get(edge.a,[]).size()>=2 or links.get(edge.b,[]).size()>=2: continue
		var i := edges.size()
		edges.append(edge)
		for p in [edge.a,edge.b]:
			if not links.has(p): links[p] = []
			links[p].append(i)
	var used := {}
	var starts: Array = []
	for p in links:
		if links[p].size()==1: starts.append(p)
	starts.append_array(links.keys())
	for first: Vector2i in starts:
		var points: Array[Vector3] = [Vector3(first.x*2,0,first.y*2)]
		var cells: Array = []
		var cursor := first
		while true:
			var next := -1
			for i: int in links[cursor]:
				if not used.has(i): next = i; break
			if next<0: break
			used[next] = true
			cells.append(edges[next].cell)
			cursor = edges[next].b if edges[next].a==cursor else edges[next].a
			points.append(Vector3(cursor.x*2,0,cursor.y*2))
		if points.size()<3: continue # Avoid isolated one-bay fence props.
		var closed := cursor==first
		if closed: points.pop_back()
		var holder := Node3D.new()
		holder.name = "JoinedShoreRail"
		holder.scale = Vector3.ONE*.5
		add_child(holder)
		BOUNDARY.assemble(holder,_art.style,points,false,closed)
		records.append({"root":holder,"cells":cells,"outside":false})


func _make_leaves() -> void:
	leaf_layer = LEAVES.new()
	leaf_layer.scale = Vector3.ONE*.5
	leaf_layer.position = Vector3(MapGen.W*.5,0,MapGen.H*.5)
	leaf_layer.layout_seed = int(_map.layout.decor_seed)
	leaf_layer.small_leaf_count = 28
	leaf_layer.small_radius = Vector2(.07,.22)
	leaf_layer.half_extent = Vector2(MapGen.W-.2,MapGen.H-.2)
	leaf_layer.water_height = float(_map.layout.water_height)*2
	for spec in flower_specs:
		var center: Vector2 = (spec.at-Vector2(MapGen.W*.5,MapGen.H*.5))*2
		leaf_layer.keepouts.append(Rect2(center-Vector2.ONE*.65,Vector2.ONE*1.3))
	leaf_layer.water_test = func(point: Vector2):
		var at := Vector2(MapGen.W*.5,MapGen.H*.5)+point*.5
		return _open_water(at)
	add_child(leaf_layer)
	leaf_layer.setup(_art.style)


func _open_water(at: Vector2) -> bool:
	if not Rect2(0,0,MapGen.W,MapGen.H).has_point(at): return false
	for entry in _map.layout.structures:
		if entry.clearance.grow(.04).has_point(at): return false
	return LAYOUT.water_field(_map,at)>.02


func _water_disc_clear(at: Vector2, radius: float) -> bool:
	if not _open_water(at): return false
	for n in 16:
		if not _open_water(at+Vector2.from_angle(TAU*n/16.0)*radius): return false
	return true


func _make_flowers() -> void:
	var random := MapGen.Rng.new(int(_map.layout.decor_seed)+5011)
	var main_pond: Array[Vector2] = []
	var pockets: Array[Vector2] = []
	var water_cells := 0
	for k in MapGen.N:
		if _map.layout.terrain_base[k]!=LAYOUT.WATER or _map.layout.bridges.has(k): continue
		water_cells += 1
		var rc := MapGen.rc(k)
		var at := Vector2(rc.y+.5,rc.x+.5)+Vector2(random.next()-.5,random.next()-.5)*.20
		if _map.layout.reserved.has(k): main_pond.append(at)
		else: pockets.append(at)
	var target := clampi(water_cells/5,3,7)
	var candidates: Array = random.shuf(main_pond)
	candidates.append_array(random.shuf(pockets))
	for candidate: Vector2 in candidates:
		if flower_specs.size()>=target: break
		var at := candidate
		if not _water_disc_clear(at,.30):
			at = Vector2(floorf(at.x)+.5,floorf(at.y)+.5)
			if not _water_disc_clear(at,.30): continue
		if flower_specs.any(func(spec): return at.distance_to(spec.at)<.85): continue
		var kind: int = [LOTUS.Plant.BLOOM,LOTUS.Plant.BUD,LOTUS.Plant.WITHERED,LOTUS.Plant.BLOOM][flower_specs.size()%4]
		var flower := LOTUS.new()
		flower.plants_only = true
		flower.plant = kind
		flower.position = Vector3(at.x,0,at.y)
		flower.scale = Vector3.ONE*.5
		flower.layout_seed = random.ri(2147483647)
		flower.water_height = float(_map.layout.water_height)*2
		flower.water_test = func(local: Vector2): return _open_water(at+local*.5)
		add_child(flower)
		flower.setup(_art.style)
		flower.set_meta("runtime_lotus",true)
		flower_specs.append({"at":at,"kind":kind,"node":flower})
		records.append({"root":flower,"cells":[MapGen.kk(floori(at.y),floori(at.x))],"outside":false})


func _make_outside(random: MapGen.Rng) -> void:
	for side in [-1,1]:
		for i in 3:
			var root := Node3D.new()
			root.position = Vector3(-1.2-random.next()*.6 if side<0 else MapGen.W+1.2+random.next()*.6,0,.7+i*2.8+random.next()*.6)
			add_child(root)
			_art.box(root,Vector3(0,-.30,0),Vector3(.70,.60,.65),"architecture",.25)
			if i==1: _art.tomb(root,random.ri(4),.60)
			else: _art.tree(root,.72+random.next()*.25)
			root.set_meta("height",2.2)
			fade_roots.append(root)
			records.append({"root":root,"cells":[],"outside":true})


func sync(ex: Expedition) -> void:
	var identity := str([ex.explored,ex.visible])
	if identity==_last_sight: return
	_last_sight = identity
	for record in records:
		var known: bool = record.outside or record.cells.any(func(k): return ex.explored.has(k))
		record.root.visible = known
		if known:
			var lit: bool = record.cells.any(func(k): return ex.visible.has(k))
			_art.shade(record.root,.62 if record.outside else (1.0 if lit else .48))
	if leaf_layer==null: return
	for child in leaf_layer.get_children():
		if not child.has_meta("radius"): continue
		var at: Vector3 = child.global_position
		var r := floori(at.z)
		var c := floori(at.x)
		var k := MapGen.kk(r,c)
		child.visible = MapGen.inb(r,c) and ex.explored.has(k)
		if child.visible: _art.shade(child,1.0 if ex.visible.has(k) else .48)
