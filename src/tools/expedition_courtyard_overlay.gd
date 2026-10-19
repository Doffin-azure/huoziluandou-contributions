extends Control
var lab: Control


func _draw() -> void:
	if lab==null or lab.camera==null or not lab.grid_toggle.button_pressed: return
	for entry in lab.surveyed:
		_footprint(entry.body,Color("6f9c8d"),.03)
		_footprint(entry.canopy,Color("bd9a55"),.05)
		var at: Vector2 = lab.camera.unproject_position(entry.visual.get_center()+Vector3.UP*.8)
		var width := Ink.serif.get_string_size(entry.label,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		draw_string(Ink.serif,at-Vector2(width*.5,0),entry.label,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("cec5ac"))
	for route in [lab.ROUTE,lab.SHORTCUT]:
		for i in range(route.size()-1):
			var a: Vector3 = route[i]+Vector3.UP*.04
			var b: Vector3 = route[i+1]+Vector3.UP*.04
			var side := (b-a).cross(Vector3.UP).normalized()*.18
			var ribbon := PackedVector2Array()
			for p: Vector3 in [a-side,b-side,b+side,a+side]: ribbon.append(lab.camera.unproject_position(p))
			draw_colored_polygon(ribbon,Color(.71,.67,.46,.16))
		var path := PackedVector2Array()
		for p: Vector3 in route: path.append(lab.camera.unproject_position(p+Vector3.UP*.04))
		draw_polyline(path,Color(.71,.67,.46,.85),2.0,true)
	var text := "青：主体包围范围　金：屋檐范围　通行带宽 0.36 格　检查："+("包围盒检查通过／通路不入水" if lab.layout_errors.is_empty() else str(lab.layout_errors))
	draw_string(Ink.serif,Vector2(24,82),text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("cec5ac"))


func _footprint(bounds: AABB, color: Color, height: float) -> void:
	if bounds.size==Vector3.ZERO: return
	var path := PackedVector2Array()
	for p in [Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.end.x,bounds.position.z),Vector2(bounds.end.x,bounds.end.z),Vector2(bounds.position.x,bounds.end.z),Vector2(bounds.position.x,bounds.position.z)]:
		path.append(lab.camera.unproject_position(Vector3(p.x,height,p.y)))
	draw_polyline(path,color,1.8,true)
