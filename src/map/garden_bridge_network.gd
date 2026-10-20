extends Node3D
## One shared bridge surface, with lazily assembled masonry / roof / railing kits.
const PLAN = preload("res://src/expedition/garden_bridge_plan.gd")
const KIT = preload("res://src/map/garden_bridge_kit.gd")
var layout: RefCounted
var style: ExpeditionFlatStyle
var ground: ShaderMaterial
var features: Array[Dictionary] = []
var surface_patches: Array[Dictionary] = []
var pieces: Array[Dictionary] = []
var instances := {}
var bridge_cells := {}


func setup(room_layout: RefCounted, graph: Dictionary, painter: ExpeditionFlatStyle, material: ShaderMaterial) -> void:
	layout = room_layout; style = painter; ground = material
	features = PLAN.generate(layout,graph)
	surface_patches = PLAN.surface_patches(features)
	_build_surface()
	for feature in features: pieces.append(feature)
	_plan_rails()
	set_meta("span_counts",_counts())


func _counts() -> Dictionary:
	var counts := {}
	for feature in features: counts[feature.kind] = int(counts.get(feature.kind,0))+1
	return counts


func _build_surface() -> void:
	for cell: Vector2i in layout.cells:
		if layout.cells[cell].edges.is_empty(): continue
		var p: Vector2 = layout.point(cell)
		if layout.rooms.values().any(func(room): return room.bounds.grow(-.126).has_point(p)): continue
		bridge_cells[cell] = true
	var deck := SurfaceTool.new(); deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := SurfaceTool.new(); side.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector2i in bridge_cells:
		var p: Vector2 = layout.point(cell)
		var rect := Rect2(p-Vector2.ONE*.125,Vector2.ONE*.25)
		for patch: Rect2 in _outside_rooms(rect):
			var corners := [_point(patch.position),_point(Vector2(patch.end.x,patch.position.y)),_point(patch.end),_point(Vector2(patch.position.x,patch.end.y))]
			var normal: Vector3 = (corners[2]-corners[0]).cross(corners[1]-corners[0]).normalized()
			_quad(deck,corners,normal)
		var corners := [_point(rect.position),_point(Vector2(rect.end.x,rect.position.y)),_point(rect.end),_point(Vector2(rect.position.x,rect.end.y))]
		for i in 4:
			var next: Vector2i = cell+[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)][i]
			if bridge_cells.has(next): continue
			var a: Vector3 = corners[i]; var b: Vector3 = corners[(i+1)%4]
			_quad(side,[a,b,b-Vector3.UP*.13,a-Vector3.UP*.13],Vector3(b.z-a.z,0,a.x-b.x).normalized())
	var surface := MeshInstance3D.new(); surface.name = "JoinedDeckNoOverlaps"
	surface.mesh = deck.commit(); surface.material_override = ground; add_child(surface)
	var fascia := MeshInstance3D.new(); fascia.name = "ContinuousStoneFascia"
	fascia.mesh = side.commit(); fascia.material_override = style.face_material("architecture"); add_child(fascia)


func _point(p: Vector2) -> Vector3:
	return Vector3(p.x,PLAN.height_at(features,p),p.y)


func _outside_rooms(rect: Rect2) -> Array:
	var patches: Array = [rect]
	for room: Dictionary in layout.rooms.values():
		if not rect.intersects(room.bounds): continue
		var remaining: Array = []
		for patch: Rect2 in patches:
			var cut := patch.intersection(room.bounds)
			if cut.get_area()<=.000001: remaining.append(patch); continue
			for piece: Rect2 in [Rect2(patch.position,Vector2(patch.size.x,cut.position.y-patch.position.y)),Rect2(Vector2(patch.position.x,cut.end.y),Vector2(patch.size.x,patch.end.y-cut.end.y)),Rect2(Vector2(patch.position.x,cut.position.y),Vector2(cut.position.x-patch.position.x,cut.size.y)),Rect2(Vector2(cut.end.x,cut.position.y),Vector2(patch.end.x-cut.end.x,cut.size.y))]:
				if piece.get_area()>.000001: remaining.append(piece)
		patches = remaining
	return patches


func _quad(surface: SurfaceTool, points: Array, normal: Vector3) -> void:
	for i in [0,1,2,0,2,3]: surface.set_normal(normal); surface.add_vertex(points[i])


func _plan_rails() -> void:
	# Directed cell edges form complete outer and inner water boundaries.
	# Offset whole loops so concave corners meet, rather than extending every bar.
	var edges := {}
	for cell: Vector2i in bridge_cells:
		var corners := [cell*2+Vector2i(-1,-1),cell*2+Vector2i(1,-1),cell*2+Vector2i(1,1),cell*2+Vector2i(-1,1)]
		for i in 4:
			if bridge_cells.has(cell+[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][i]): continue
			if not edges.has(corners[i]): edges[corners[i]] = []
			edges[corners[i]].append(corners[(i+1)%4])
	var loops: Array = []
	while not edges.is_empty():
		var first: Vector2i = edges.keys()[0]
		var point := first
		var loop := PackedVector2Array()
		for safety in bridge_cells.size()*4+1:
			loop.append(Vector2(point)*.125)
			if not edges.has(point) or edges[point].is_empty(): break
			var next: Vector2i = edges[point].pop_back()
			if edges[point].is_empty(): edges.erase(point)
			point = next
			if point==first: break
		if point==first and loop.size()>3: loops.append(loop)
	var post_keys := {}
	for loop: PackedVector2Array in loops:
		var area := 0.0
		for i in loop.size(): area += loop[i].cross(loop[(i+1)%loop.size()])
		var offset_loops := Geometry2D.offset_polygon(loop,.10 if area>0 else -.10,Geometry2D.JOIN_MITER)
		for offset: PackedVector2Array in offset_loops:
			for i in offset.size():
				var a := offset[i]; var b := offset[(i+1)%offset.size()]
				var length := a.distance_to(b)
				if length<.14: continue
				var direction := (b-a)/length
				var start := -1.0
				var steps := maxi(1,ceili(length/.125))
				for j in steps+1:
					var s := length*j/steps
					var p := a+direction*s
					var usable := _rail_usable(p)
					if usable and start<0: start = s
					if start>=0 and (not usable or j==steps):
						var end := s if usable else maxf(start,s-length/steps)
						if end-start>.12: _rail_chunks(a+direction*start,a+direction*end,post_keys)
						start = -1
	# Corner posts are independent shared pieces. A sealed neighbouring branch
	# cannot hide a post that the still-open branch also needs.
	for post in post_keys.values(): pieces.append(post)


func _rail_usable(p: Vector2) -> bool:
	if not layout.cells.get(layout.cell(p),{}).get("rooms",[]).is_empty(): return false
	if layout.rooms.values().any(func(room): return room.bounds.grow(.23).has_point(p)): return false
	for feature: Dictionary in features:
		var delta: Vector2 = p-feature.start
		var s: float = delta.dot(feature.direction)
		var side: float = delta.dot(Vector2(-feature.direction.y,feature.direction.x))
		if s>-.06 and s<feature.length+.06 and absf(side)<.7: return false
	return true


func _rail_chunks(a: Vector2, b: Vector2, post_keys: Dictionary) -> void:
	a = _snap_to_cap(a)
	b = _snap_to_cap(b)
	var length := a.distance_to(b)
	if length<.08: return
	var direction := (b-a)/length
	var count := maxi(1,ceili(length/5.0))
	for i in count:
		var start: Vector2 = a+(b-a)*float(i)/count
		var finish: Vector2 = a+(b-a)*float(i+1)/count
		var midpoint := (start+finish)*.5
		var closest: Vector2i = layout.cell(midpoint)
		# A rail lies outside the walk strip. Find the adjacent deck owners.
		var owners: Array = []
		for x in range(-3,4):
			for y in range(-3,4):
				var entry: Dictionary = layout.cells.get(closest+Vector2i(x,y),{})
				for edge_id in entry.get("edges",[]):
					if not owners.has(edge_id): owners.append(edge_id)
		var first_key := Vector2i((start*1000).round()); var last_key := Vector2i((finish*1000).round())
		pieces.append({"id":"rail_"+str(pieces.size()),"kind":"rail","edges":owners,"start":start,"direction":direction,"length":start.distance_to(finish),"bounds":Rect2(start,Vector2.ZERO).expand(finish).grow(.3),"omit_first":true,"omit_last":true})
		for endpoint in [{"key":first_key,"point":start},{"key":last_key,"point":finish}]:
			if _feature_cap(endpoint.point): continue
			if not post_keys.has(endpoint.key):
				post_keys[endpoint.key] = {"id":"post_"+str(endpoint.key),"kind":"post","edges":[],"start":endpoint.point,"direction":direction,"length":.1,"bounds":Rect2(endpoint.point-Vector2.ONE*.15,Vector2.ONE*.3)}
			for edge_id in owners:
				if not post_keys[endpoint.key].edges.has(edge_id): post_keys[endpoint.key].edges.append(edge_id)


func _snap_to_cap(point: Vector2) -> Vector2:
	for feature: Dictionary in features:
		var normal := Vector2(-feature.direction.y,feature.direction.x)
		for s in [0.0,float(feature.length)]:
			for side in [-1.0,1.0]:
				var cap: Vector2 = feature.start+feature.direction*float(s)+normal*.475*float(side)
				if cap.distance_to(point)<.22: return cap
	return point


func _feature_cap(point: Vector2) -> bool:
	for feature: Dictionary in features:
		var normal := Vector2(-feature.direction.y,feature.direction.x)
		for s in [0.0,float(feature.length)]:
			for side in [-1.0,1.0]:
				var cap: Vector2 = feature.start+feature.direction*float(s)+normal*.475*float(side)
				if cap.distance_to(point)<.005: return true
	return false


func refresh(player: Vector2, run: RefCounted) -> void:
	for piece: Dictionary in pieces:
		var owners: Array = piece.get("edges",[piece.get("edge","")])
		var known := owners.any(func(edge_id):
			var ends: PackedStringArray = str(edge_id).split(">")
			return ends.size()==2 and run.resolved.has(ends[0]) and not run.sealed.has(ends[0]) and not run.sealed.has(ends[1]))
		var needed: bool = known and piece.bounds.grow(23).has_point(player)
		if not needed:
			if instances.has(piece.id): instances[piece.id].queue_free(); instances.erase(piece.id)
			continue
		if not instances.has(piece.id):
			var kit := KIT.new()
			kit.kind = piece.kind; kit.span_length = piece.length; kit.with_deck = false
			kit.omit_first_post = piece.get("omit_first",false); kit.omit_last_post = piece.get("omit_last",false)
			kit.position = Vector3(piece.start.x,0,piece.start.y)
			kit.rotation.y = atan2(-piece.direction.y,piece.direction.x)
			add_child(kit); kit.setup(style)
			instances[piece.id] = kit
		var kit: Node3D = instances[piece.id]
		kit.set_lamps_enabled(piece.bounds.grow(6).has_point(player))
		var local: Vector2 = player-piece.start
		var s: float = local.dot(piece.direction)
		var side: float = absf(local.dot(Vector2(-piece.direction.y,piece.direction.x)))
		kit.set_roof_faded(s>-.65 and s<piece.length+.65 and side<.8)


func update_roofs(player: Vector2) -> void:
	for kit: Node3D in instances.values():
		if kit.kind not in ["covered","gallery"]: continue
		var local: Vector3 = kit.to_local(Vector3(player.x,0,player.y))
		kit.set_roof_faded(local.x>-.65 and local.x<kit.span_length+.65 and absf(local.z)<.8)
