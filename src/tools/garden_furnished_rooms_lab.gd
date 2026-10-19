extends "res://src/tools/expedition_room_template_lab.gd"


func _ready() -> void:
	output = "res://docs/art-concepts/2026-10-18-furnished-rooms"
	super._ready()


func _water_context() -> void:
	var shape := PlaneMesh.new(); shape.size = Vector2.ONE*200
	var water := MeshInstance3D.new(); water.mesh = shape; water.position.y = -.45
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://src/shaders/expedition_water.gdshader")
	paint.set_shader_parameter("fog_mask",_white()); paint.set_shader_parameter("water_tint",Color("102b32"))
	water.material_override = paint; contents.add_child(water)


func _capture_rooms() -> void:
	get_window().content_scale_size = Vector2i.ZERO; get_window().size = Vector2i(1600,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await _frames(10)
	var catalog_json: Array = []
	var requested := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--sample="): requested = argument.trim_prefix("--sample=")
	for index in rooms.size():
		if not requested.is_empty() and rooms[index].kind!=requested:
			var sample: Dictionary = CATALOG.with_variant(rooms[index],false)
			CATALOG.apply_enclosure(sample); catalog_json.append(_json_ready(sample))
			continue
		set_mode(index); await _frames(5)
		_snap("%02d-%s.png" % [index+1,room.kind])
		catalog_json.append(_json_ready(room))
		print("[FurnishedRoom] ",room.kind," props=",room.props.size())
	if not requested.is_empty():
		FileAccess.open(output.path_join("room-templates.json"),FileAccess.WRITE).store_string(JSON.stringify(catalog_json,"  "))
		print("[FurnishedRoom] Requested sample complete: ",requested)
		get_tree().quit(); return
	set_mode(3); alternate_toggle.button_pressed = true; await _frames(5)
	_snap("09-battle-four-doors.png")
	grid_toggle.button_pressed = true; _pitch = 78; _yaw = 0; _apply_camera(); await _frames(3)
	_snap("10-ports-and-lanes.png",true)
	alternate_toggle.button_pressed = false; set_mode(6); used_toggle.button_pressed = true; await _frames(5)
	_snap("11-treasure-opened.png")
	FileAccess.open(output.path_join("room-templates.json"),FileAccess.WRITE).store_string(JSON.stringify(catalog_json,"  "))
	print("[FurnishedRoom] Eight production rooms, variant, passage plan and used state complete")
	get_tree().quit()


func _snap(filename: String, with_ui := false) -> void:
	# Hidden desktop windows may suspend frame_post_draw; explicitly render the
	# native viewport rather than waiting indefinitely for a desktop repaint.
	RenderingServer.force_draw(false)
	var rendered := get_viewport() if with_ui else viewport
	var result := rendered.get_texture().get_image().save_png(output.path_join(filename))
	assert(result==OK,"Room screenshot could not be written")
