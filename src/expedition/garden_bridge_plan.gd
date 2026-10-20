extends RefCounted
## Presentation-only bridge placement. No gameplay RNG or room progression state.
const HALF_LANE := .375
const SURFACE_STEP := .25
const WATER_Y := -.45


static func generate(layout: RefCounted, graph: Dictionary) -> Array[Dictionary]:
	var features: Array[Dictionary] = []
	for corridor: Dictionary in layout.corridors:
		if corridor.has("cluster_id") or (corridor.get("site_route",false) and corridor.from=="start"):
			_cluster_gallery(corridor,features)
			continue
		var kind := _kind(corridor,graph)
		for index in range(corridor.points.size()-1):
			var a: Vector2 = corridor.points[index]
			var b: Vector2 = corridor.points[index+1]
			var vector := b-a
			if vector.length()<3.5: continue
			var direction := vector.normalized()
			var normal := Vector2(-direction.y,direction.x)
			var start := -1.0
			var count := floori(vector.length()*4)
			var ranges: Array[Vector2] = []
			for i in count+1:
				var s := i*.25
				var point := a+direction*s
				var cell: Vector2i = layout.cell(point)
				var entry: Dictionary = layout.cells.get(cell,{})
				var valid: bool = not entry.is_empty() and entry.edges.size()==1 and entry.edges[0]==corridor.id
				valid = valid and not layout.rooms.values().any(func(room): return room.bounds.grow(1.15).has_point(point))
				# Allow the full roof/rail envelope, not merely its centerline.
				for side in [-1.0,1.0]:
					var nearby: Dictionary = layout.cells.get(layout.cell(point+normal*.75*side),{})
					if not nearby.is_empty() and nearby.edges.any(func(id): return id!=corridor.id): valid = false
				if valid and start<0: start = s
				if (not valid or i==count) and start>=0:
					var end := s if valid else s-.25
					if end-start>=3.0: ranges.append(Vector2(start,end))
					start = -1.0
			for interval in ranges:
				var length := minf(interval.y-interval.x,11.0 if kind in ["gallery","covered"] else 8.0)
				var offset := interval.x+(interval.y-interval.x-length)*.5
				var first := a+direction*offset
				# Align feature ends with quarter-grid mesh edges, not cell centers.
				var coordinate: float = first.x if absf(direction.x)>.5 else first.y
				var snapped := roundf((coordinate+.125)*4)*.25-.125
				offset += (snapped-coordinate)*(direction.x if absf(direction.x)>.5 else direction.y)
				first = a+direction*offset
				length = floorf(length*4)*.25
				var last := first+direction*length
				var bounds := Rect2(first,Vector2.ZERO).expand(last).grow(.80)
				if features.any(func(old): return old.bounds.grow(.1).intersects(bounds)): continue
				features.append({"id":corridor.id+"_"+str(index)+"_"+str(features.size()),"edge":corridor.id,"kind":kind,"start":first,"direction":direction,"length":length,"bounds":bounds})
	return features


static func _cluster_gallery(corridor: Dictionary, features: Array[Dictionary]) -> void:
	var candidates: Array = []
	for i in range(corridor.points.size()-1):
		var a: Vector2 = corridor.points[i]; var b: Vector2 = corridor.points[i+1]
		var length := a.distance_to(b)
		if length>=3.0: candidates.append({"a":a,"b":b,"length":length})
	candidates.sort_custom(func(a,b): return a.length>b.length)
	for candidate in candidates:
		var direction: Vector2 = (candidate.b-candidate.a).normalized()
		var trim := 1.5 if float(candidate.length)>5.0 else .65
		var first: Vector2 = candidate.a+direction*trim
		var length := floorf((float(candidate.length)-2*trim)*4)*.25
		if length<1.5: continue
		var bounds := Rect2(first,Vector2.ZERO).expand(first+direction*length).grow(.85)
		if features.any(func(old): return old.bounds.grow(.05).intersects(bounds)): continue
		features.append({"id":corridor.id+"_garden_gallery","edge":corridor.id,"kind":"gallery","start":first,"direction":direction,"length":length,"bounds":bounds})
		return


static func _kind(corridor: Dictionary, graph: Dictionary) -> String:
	if corridor.from=="start": return "gallery"
	var a: String = graph.rooms[corridor.from].kind
	var b: String = graph.rooms[corridor.to].kind
	if a=="treasure" or b=="treasure": return "arch"
	if a in ["rest","shop"] or b in ["rest","shop"]: return "covered"
	if b in ["elite","boss"]: return "pier"
	return ["arch","covered","pier"][absi(str(corridor.id).hash()^int(graph.seed))%3]


static func elevation(kind: String, s: float, length: float) -> float:
	if kind!="arch": return 0.0
	var t := clampf(s/length,0,1)
	return minf(.34,length*.07)*4*t*(1-t)


static func height_at(features: Array[Dictionary], point: Vector2) -> float:
	for feature: Dictionary in features:
		var delta: Vector2 = point-feature.start
		var s: float = delta.dot(feature.direction)
		var side: float = delta.dot(Vector2(-feature.direction.y,feature.direction.x))
		if s<-.00001 or s>feature.length+.00001 or absf(side)>HALF_LANE+.01: continue
		var first := clampf(floorf(s/SURFACE_STEP)*SURFACE_STEP,0,feature.length-SURFACE_STEP)
		return lerpf(elevation(feature.kind,first,feature.length),elevation(feature.kind,first+SURFACE_STEP,feature.length),clampf((s-first)/SURFACE_STEP,0,1))
	return 0.0


static func surface_patches(features: Array[Dictionary]) -> Array[Dictionary]:
	var patches: Array[Dictionary] = []
	for feature: Dictionary in features:
		if feature.kind!="arch": continue
		var basis := Basis(Vector3.UP,atan2(-feature.direction.y,feature.direction.x))
		for i in roundi(feature.length/SURFACE_STEP):
			var s := i*SURFACE_STEP
			var h := elevation(feature.kind,s,feature.length)
			var slope := (elevation(feature.kind,s+SURFACE_STEP,feature.length)-h)/SURFACE_STEP
			patches.append({"origin":Vector3(feature.start.x,0,feature.start.y),"basis":basis,"rect":Rect2(s,-HALF_LANE,SURFACE_STEP,HALF_LANE*2),"height":h-s*slope,"gradient":Vector2(slope,0)})
	return patches
