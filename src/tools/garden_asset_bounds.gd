extends RefCounted
## Read the constructed geometry, not a guessed one-cell proxy.
## These are conservative world bounds; overlapping projections are not collisions.


static func measure(root: Node3D) -> Dictionary:
	var parts: Array[Dictionary] = []
	var visual := AABB()
	var body := AABB()
	var canopy := AABB()
	var first := true
	var first_body := true
	var first_roof := true
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("flat_outline_only") or mesh.has_meta("ground_imprint") or not mesh.is_visible_in_tree(): continue
		var parent: Node = mesh
		var roof := false
		var skip := false
		while parent!=root and parent!=null:
			roof = roof or bool(parent.get_meta("roof_occluder",false))
			if parent.get_script()!=null and str(parent.get_script().resource_path).ends_with("expedition_inlaid_glyph.gd"): skip = true
			parent = parent.get_parent()
		if skip: continue
		var bounds := mesh.global_transform*mesh.get_aabb()
		# Screen-space strokes have no physical thickness.
		if bounds.size.x*bounds.size.y*bounds.size.z<.00000001: continue
		parts.append({"bounds":bounds,"roof":roof})
		visual = bounds if first else visual.merge(bounds)
		first = false
		if roof:
			canopy = bounds if first_roof else canopy.merge(bounds)
			first_roof = false
		else:
			body = bounds if first_body else body.merge(bounds)
			first_body = false
	return {"visual":visual,"body":body,"canopy":canopy,"parts":parts}


static func rect(bounds: AABB) -> Rect2:
	return Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))


static func conflicts(a: Dictionary, b: Dictionary, tolerance := .012) -> bool:
	if not a.visual.intersects(b.visual): return false
	for left in a.parts:
		for right in b.parts:
			var overlap: AABB = left.bounds.intersection(right.bounds)
			if minf(overlap.size.x,minf(overlap.size.y,overlap.size.z))>tolerance: return true
	return false
