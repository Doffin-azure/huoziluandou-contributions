extends RefCounted
## Shared geometric edges, including collinear overlaps and T junctions.
static func segments(paths: Array) -> Array:
	var raw: Array = []
	for path: Array in paths:
		for i in path.size()-1:
			var a := Vector2(float(path[i][0]),float(path[i][1])).snapped(Vector2.ONE*.01)
			var b := Vector2(float(path[i+1][0]),float(path[i+1][1])).snapped(Vector2.ONE*.01)
			if a.distance_to(b)>.01: raw.append([a,b])
	var unique := {}
	for edge: Array in raw:
		var a: Vector2 = edge[0]; var b: Vector2 = edge[1]
		var points: Array = [a,b]
		for other: Array in raw:
			for p: Vector2 in other:
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))<.001 and not points.has(p): points.append(p)
			var cross = Geometry2D.segment_intersects_segment(a,b,other[0],other[1])
			if cross!=null and not points.has(cross): points.append(cross)
		points.sort_custom(func(p,q):return p.distance_squared_to(a)<q.distance_squared_to(a))
		for i in points.size()-1:
			var p: Vector2 = points[i]; var q: Vector2 = points[i+1]
			if p.distance_to(q)<.01: continue
			var key := str(p.min(q))+":"+str(p.max(q))
			unique[key] = [p,q]
	return unique.values()
