extends Node3D
## Run with -- --rebuild-garden to regenerate the production mesh prototypes.
const LIBRARY = preload("res://src/map/garden_mesh_library.gd")


func _ready() -> void: bake.call_deferred()


func bake() -> void:
	var camera := Camera3D.new(); add_child(camera)
	var painter := ExpeditionFlatStyle.new(load("res://assets/expedition/palettes/mochi_night.tres"))
	painter.camera = camera; painter.set_scene_lighting(true)
	var ground := preload("res://src/map/expedition_pond_shape_tile.gd").ground_material(Vector2.ZERO)
	var count := 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LIBRARY.DIRECTORY))
	var manifest := FileAccess.open(LIBRARY.DIRECTORY.path_join("manifest.json"),FileAccess.WRITE); manifest.store_string("{}"); manifest.close()
	for seed_value in [17,67]:
		var run = preload("res://src/expedition/room_run_state.gd").new()
		run.reset({"seed":seed_value,"layout":"random_garden"})
		var visual := preload("res://src/map/authored_garden_visual.gd").new(); add_child(visual)
		await visual.build(run.layout,painter,camera,Environment.new(),ground,true)
		for asset: String in preload("res://src/expedition/room_interior_assets.gd").MODELS:
			visual._asset(asset,Vector2(-100,-100),1.0)
			await get_tree().process_frame
		for index in 4: visual._instance("tomb_"+str(index)).free()
		count = LIBRARY.save_cached()
		visual.free(); painter.reset_geometry_tracking()
	print("[BakeGarden] cached scenes=",count," generated=",LIBRARY.misses)
	painter.dispose()
	get_tree().quit()
