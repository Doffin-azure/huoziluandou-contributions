extends Control
## Native frames for a short preview; not an image-generated animation.
const SAMPLE := preload("res://src/tools/title_art_sample.tscn")


func _ready() -> void:
	_capture.call_deferred()


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(2)
		return
	var sample := SAMPLE.instantiate()
	add_child(sample)
	for i in 40: await get_tree().process_frame
	sample.stage.atmosphere.set_motion(false)
	DirAccess.make_dir_recursive_absolute("res://shots/courtyard-ambient-frames")
	for i in 60:
		sample.stage.atmosphere.seek(3.0 + i * 0.1)
		for frame in 3: await get_tree().process_frame
		RenderingServer.force_draw(false)
		var picture := get_viewport().get_texture().get_image()
		var error := picture.save_png("res://shots/courtyard-ambient-frames/%03d.png" % i)
		if error != OK:
			push_error("Could not save ambient preview frame: %s" % error)
			get_tree().quit(1)
			return
	sample.queue_free()
	for i in 16: await get_tree().process_frame
	print("[courtyard_ambient_capture] FRAMES=60 FPS=10")
	get_tree().quit()
