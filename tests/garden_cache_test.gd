extends Node3D
## Verify shared mesh resources and independent baked light controls.
const LIBRARY = preload("res://src/map/garden_mesh_library.gd")
var failures := []


func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)


func _ready() -> void: inspect.call_deferred()


func inspect() -> void:
	var painter := ExpeditionFlatStyle.new(load("res://assets/expedition/palettes/mochi_night.tres")); painter.set_scene_lighting(true)
	var assets := []
	for i in 2:
		var asset: Node3D = LIBRARY.instantiate("boundary:8:0",func():return null,painter)
		add_child(asset); assets.append(asset)
	var first: Array = assets[0].find_children("*","MeshInstance3D",true,false)
	var second: Array = assets[1].find_children("*","MeshInstance3D",true,false)
	check(not first.is_empty() and first.size()==second.size(),"wall cache contains static meshes")
	for i in first.size(): check(first[i].mesh==second[i].mesh,"instances share immutable mesh resources")
	check(LIBRARY.misses==0,"approved wall loads without procedural geometry")
	var lamp: Node3D = LIBRARY.instantiate("prop:lamp",func():return null,painter); add_child(lamp)
	check(not lamp.lamps.is_empty(),"baked lamp preserves light socket")
	lamp.set_lamps_enabled(true)
	check(lamp.lamps.all(func(light):return light.visible and not light.shadow_enabled),"lamp controller enables only shadow-free local lights")
	lamp.set_lamps_enabled(false)
	check(lamp.lamps.all(func(light):return not light.visible),"fog can disable baked lights")
	print("[GardenCache] failures=",failures)
	painter.dispose(); get_tree().quit(0 if failures.is_empty() else 1)
