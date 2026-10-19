extends Node3D
var checks := 0
var failures: Array = []


func _ready() -> void:
	var painter := ExpeditionFlatStyle.new(load("res://assets/expedition/palettes/mochi_night.tres"))
	painter.static_capture = true; painter.set_scene_lighting(true)
	for extent: Vector2 in [Vector2(3,7),Vector2(7,3),Vector2(5,5)]:
		var building := preload("res://src/map/garden_passage_building.gd").new()
		building.extent = extent; building.gallery = true; building.roof_kind = "hip"
		add_child(building); building.setup(painter)
		var footprint := Rect2(-extent*.5-Vector2.ONE*.35,extent+Vector2.ONE*.7)
		for stroke: MeshInstance3D in building._detail_items:
			if not stroke.get_meta("roof_occluder",false): continue
			for surface in stroke.mesh.get_surface_count():
				var vertices: PackedVector3Array = stroke.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for point: Vector3 in vertices:
					var world := stroke.global_transform*point
					checks += 1
					if not footprint.has_point(Vector2(world.x,world.z)):
						failures.append(str(extent)+": roof stroke outside footprint "+str(world)); break
		building.free()
	painter.dispose()
	print("[GardenRoofModule] ",{"checks":checks,"failures":failures})
	get_tree().quit(0 if failures.is_empty() else 1)
