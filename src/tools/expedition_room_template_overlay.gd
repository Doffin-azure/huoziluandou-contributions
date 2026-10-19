extends Control
## Workbench annotations: template ports / interaction anchors / clear floor lanes.
var lab: Control


func _draw() -> void:
	if lab==null or lab.camera==null or lab.room.is_empty(): return
	if not lab.grid_toggle.button_pressed: return
	var room: Dictionary = lab.room
	for route in room.lanes:
		var points := PackedVector2Array()
		for at: Vector2 in route: points.append(lab.camera.unproject_position(Vector3(at.x,.045,at.y)))
		if points.size()>1: draw_polyline(points,Color(.40,.77,.69,.85),3,true)
	for port in room.ports:
		var world: Vector3 = lab.CATALOG.port_position(room,port)
		var point: Vector2 = lab.camera.unproject_position(world+Vector3.UP*.05)
		draw_circle(point,6,Color("c7a561"),false,2,true)
		draw_string(Ink.serif,point+Vector2(9,-7),str(port.side)+" / "+str(port.role),HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("ddc99b"))
	var stand: Vector2 = lab.camera.unproject_position(Vector3(room.stand.x,.06,room.stand.y))
	draw_circle(stand,10,Color("c7a561"),false,2,true)
	draw_string(Ink.serif,stand+Vector2(13,5),"交互站位",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ddc99b"))
	for record in lab.occupied:
		var bounds: AABB = lab.SURVEY.measure(record.root).body
		if bounds.size==Vector3.ZERO: continue
		var polygon := PackedVector2Array()
		for p in [Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.end.x,bounds.position.z),Vector2(bounds.end.x,bounds.end.z),Vector2(bounds.position.x,bounds.end.z),Vector2(bounds.position.x,bounds.position.z)]:
			polygon.append(lab.camera.unproject_position(Vector3(p.x,.065,p.y)))
		draw_polyline(polygon,Color(.62,.74,.81,.65),1.5,true)
	draw_string(Ink.serif,Vector2(24,75),str(room.description),HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("d1c4a6"))
	draw_string(Ink.serif,Vector2(24,102),"绿线：建议通行中心线（不是已完成的导航网格）　金圈：接点与站位　青框：实物范围",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("b1b8aa"))
