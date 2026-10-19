extends Control
var lab: Control


func _draw() -> void:
	if lab==null or not lab.grid_toggle.button_pressed: return
	for item in lab.landmarks:
		var extent: Vector2 = item.footprint*.5
		var points := PackedVector2Array()
		for at in [Vector3(-extent.x,.02,-extent.y),Vector3(extent.x,.02,-extent.y),Vector3(extent.x,.02,extent.y),Vector3(-extent.x,.02,extent.y),Vector3(-extent.x,.02,-extent.y)]:
			points.append(lab.camera.unproject_position(item.to_global(at)))
		draw_polyline(points,Color(.65,.78,.74,.9),1.5,true)
		var foot: Vector2 = lab.camera.unproject_position(item.global_position)
		draw_circle(foot,5,Color("c3a367"),false,2,true)
		draw_string(Ink.serif,points[0]+Vector2(4,-8),"占地 %.1f × %.1f" % [extent.x*2,extent.y*2],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("c8b48b"))
