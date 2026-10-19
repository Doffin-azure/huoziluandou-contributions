extends "res://src/tools/expedition_garden_overlay.gd"


func _draw() -> void:
	super._draw()
	if lab==null or not lab.grid_toggle.button_pressed: return
	for pond in lab.ponds:
		for tile in pond.get_children():
			var outline := PackedVector2Array()
			for point in [Vector3(-1,.01,-1),Vector3(1,.01,-1),Vector3(1,.01,1),Vector3(-1,.01,1),Vector3(-1,.01,-1)]:
				outline.append(lab.camera.unproject_position(tile.to_global(point)))
			draw_polyline(outline,Color(.66,.60,.42,.65),1.2,true)
