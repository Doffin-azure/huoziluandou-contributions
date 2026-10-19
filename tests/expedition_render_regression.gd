extends Node
## Exact contour facing + bounded sight sampling; native GPU required.
var _pass := 0
var _fail := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok: _pass += 1
	else:
		_fail += 1
		push_error(message)


func _frames(count := 5) -> void:
	for i in count: await get_tree().process_frame


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,480)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3,4,8)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var style := ExpeditionFlatStyle.new(ExpeditionFlatPalette.new())
	style.camera = camera
	var box_shape := BoxMesh.new()
	box_shape.size = Vector3(1,2,1)
	var cube := style.mesh(world,box_shape,Vector3.ZERO,"stone")
	cube.scale = Vector3(.5,1.8,.8)
	cube.rotation.y = .22
	var hidden := style.mesh(world,box_shape,Vector3(1,0,0),"stone")
	hidden.visible = false
	var remote := style.mesh(world,box_shape,Vector3(1000,0,0),"stone")
	style.refresh_outlines()
	_check(cube.get_meta("outline_edges").size()==6,"A rotated scaled cuboid has its six-edge perspective silhouette")
	_check(not hidden.has_meta("outline_edges") and not remote.has_meta("outline_edges"),"Hidden and out-of-frustum meshes are skipped")
	for projection in [Camera3D.PROJECTION_PERSPECTIVE,Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		style.refresh_outlines()
		var reference := PackedInt32Array()
		var edges := style._edges(cube.mesh)
		for index in edges.size():
			var edge: Dictionary = edges[index]
			var at: Vector3 = cube.to_global((edge.a+edge.b)*.5)
			var toward := camera.global_basis.z if projection==Camera3D.PROJECTION_ORTHOGONAL else (camera.global_position-at).normalized()
			var front := false
			var back := false
			for normal: Vector3 in edge.normals:
				var facing := (cube.global_basis.inverse().transposed()*normal).dot(toward)
				front = front or facing>.00001
				back = back or facing<-.00001
			if front and (back or edge.normals.size()==1): reference.append(index)
		_check(cube.get_meta("outline_edges")==reference,"Optimized local facing matches former world-space facing, projection "+str(projection))
	var holder := Node3D.new()
	world.add_child(holder)
	var newly_revealed := style.mesh(holder,box_shape,Vector3.ZERO,"stone")
	holder.visible = false
	style.refresh_outlines()
	_check(not newly_revealed.has_meta("outline_edges"),"Inherited hidden state is respected")
	holder.visible = true
	var iterations := 0
	while not style.refresh_outlines(.001) and iterations<100: iterations += 1
	_check(iterations>0 and iterations<100 and newly_revealed.has_meta("outline_edges"),"Budgeted refresh finishes and revealed models obtain contours")
	style.reset_geometry_tracking()
	_check(not style.outline_refresh_in_progress(),"Map reset clears the incremental sweep")
	style.dispose()
	for child in world.get_children():
		if child!=camera:
			world.remove_child(child)
			child.queue_free()
	# All-white vision exposes the old clamp bug most clearly: it must never
	# reveal the larger world plane outside the actual map rectangle.
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.WHITE
	world.add_child(environment)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18
	camera.position = Vector3(6,20,4)
	camera.look_at(Vector3(6,0,4),Vector3(0,0,-1))
	var mask := Image.create(12,8,false,Image.FORMAT_RGBA8)
	mask.fill(Color.WHITE)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://src/shaders/expedition_sight_veil.gdshader")
	paint.set_shader_parameter("fog_mask",ImageTexture.create_from_image(mask))
	paint.set_shader_parameter("clip_vision_bounds",true)
	var plane := MeshInstance3D.new()
	var shape := PlaneMesh.new()
	shape.size = Vector2(40,30)
	plane.mesh = shape
	plane.position = Vector3(6,0,4)
	plane.material_override = paint
	world.add_child(plane)
	await _frames(8)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	for at in [Vector3(-1,0,4),Vector3(13,0,4),Vector3(6,0,-1),Vector3(6,0,9)]:
		var pixel := camera.unproject_position(at)
		var color := image.get_pixelv(Vector2i(pixel))
		_check(maxf(color.r,maxf(color.g,color.b))<.20,"No explored mask leaks beyond "+str(at))
	var inside := image.get_pixelv(Vector2i(camera.unproject_position(Vector3(6,0,4))))
	_check(inside.r>.8 and inside.g>.8,"Revealed map interior remains clear")
	# Standalone art studies use unbounded white masks and negative coordinates.
	paint.set_shader_parameter("clip_vision_bounds",false)
	await _frames(4)
	await RenderingServer.frame_post_draw
	image = viewport.get_texture().get_image()
	var lab_color := image.get_pixelv(Vector2i(camera.unproject_position(Vector3(-1,0,4))))
	_check(lab_color.r>.8,"Standalone negative-coordinate asset previews retain their previous behavior")
	viewport.queue_free()
	await _frames(2)
	print("[ExpeditionRender] PASS=%d FAIL=%d" % [_pass,_fail])
	get_tree().quit(1 if _fail else 0)
