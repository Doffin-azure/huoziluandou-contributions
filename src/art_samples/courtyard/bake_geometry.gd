extends SceneTree
## Run with --headless --script to save editable model assets, without the preview UI.
const ARCHITECTURE := preload("res://src/title/courtyard/architecture.gd")
const LANDSCAPE := preload("res://src/title/courtyard/landscape.gd")


func _initialize() -> void:
	_bake.call_deferred()


func _bake() -> void:
	var source := Node3D.new()
	root.add_child(source)
	for script in [ARCHITECTURE, LANDSCAPE]:
		var component: Node3D = script.new()
		source.add_child(component)
	await process_frame
	var model := Node3D.new()
	model.name = "CourtyardModel"
	for component in source.get_children():
		var section := Node3D.new()
		section.name = "Architecture" if component.get_script() == ARCHITECTURE else "Landscape"
		model.add_child(section)
		section.owner = model
		for instance in component.get_children():
			if not instance is MeshInstance3D: continue
			var copy: MeshInstance3D = instance.duplicate()
			section.add_child(copy)
			copy.owner = model
	var directory := "res://docs/art-concepts/2026-10-16/courtyard-3d/models/"
	DirAccess.make_dir_recursive_absolute(directory)
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, directory + "courtyard_geometry.scn") == OK)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(model, state) == OK)
	assert(document.write_to_filesystem(state, directory + "courtyard_geometry.glb") == OK)
	print("BAKED courtyard_geometry.scn and courtyard_geometry.glb")
	model.free()
	source.queue_free()
	await process_frame
	quit()
