extends Node3D
## Offline production cache for compact halls, common furniture and boundaries.
func _ready() -> void: bake.call_deferred()


func bake() -> void:
	var library = preload("res://src/map/garden_mesh_library.gd")
	var camera := Camera3D.new(); add_child(camera)
	var painter := ExpeditionFlatStyle.new(load("res://assets/expedition/palettes/mochi_night.tres"))
	painter.camera = camera; painter.set_scene_lighting(true)
	var ground := preload("res://src/map/expedition_pond_shape_tile.gd").ground_material(Vector2.ZERO)
	var count := 0
	for seed_value in [17,29,67]:
		var run = preload("res://src/expedition/room_run_state.gd").new()
		run.reset({"seed":seed_value,"layout":"compact_garden"}); run.autosave = false
		var visual := preload("res://src/map/garden_compact_visual.gd").new(); add_child(visual)
		await visual.build(run.layout,painter,camera,Environment.new(),ground,true)
		count = library.save_cached()
		visual.free(); painter.reset_geometry_tracking()
	print("[BakeCompactGarden] cached=",count," generated=",library.misses)
	painter.dispose(); get_tree().quit()
