extends Control
## Workbench annotations only, never part of the models or runtime map.
var lab: Control


func _draw() -> void:
	if lab==null or lab.camera==null: return
	for entry in lab.labels:
		var at: Vector2 = lab.camera.unproject_position(entry[0])
		var text: String = entry[1]
		var width := Ink.serif.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		draw_string(Ink.serif,at+Vector2(-width*.5,entry[2] if entry.size()>2 else 25),text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("b5b0a0"))
	if not lab.grid_toggle.button_pressed: return
	for group in lab.assemblies:
		for point: Vector3 in group.get_meta("post_positions"):
			var at: Vector2 = lab.camera.unproject_position(group.to_global(point)+Vector3.UP*.015)
			draw_circle(at,4,Color("bca06a"),false,1.5,true)
