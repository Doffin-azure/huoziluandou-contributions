extends Control
## Native renderer acceptance and captures for the independent 3D art sample.
const SAMPLE := preload("res://src/tools/title_art_sample.tscn")
var _fail := 0
var _pass := 0
var _sample: Control


func _ready() -> void:
	_run.call_deferred()


func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		_pass += 1
		print("PASS ", description)
	else:
		_fail += 1
		push_error(description)


func _capture(filename: String) -> Image:
	await _frames(12)
	RenderingServer.force_draw(false)
	var picture := get_viewport().get_texture().get_image()
	_check(picture.save_png("res://shots/title-art-%s.png" % filename) == OK, "capture " + filename)
	return picture


func _image_delta(a: Image, b: Image) -> Vector2:
	var sum := 0.0
	var changed := 0
	var count := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var first := a.get_pixel(x, y)
			var second := b.get_pixel(x, y)
			var delta := (absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)) / 3.0
			sum += delta
			count += 1
			if delta > 0.02: changed += 1
	return Vector2(sum / count, changed)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this scene with the native renderer.")
		get_tree().quit(2)
		return
	var workshop = preload("res://src/title/courtyard/mesh_workshop.gd").new()
	var model_check := Node3D.new()
	add_child(model_check)
	workshop.beam(Vector3(-2, 3, 0), Vector3(2, 3, 0), 0.1, 0.15, StandardMaterial3D.new())
	workshop.finish(model_check)
	var beam_bounds: AABB = model_check.get_child(0).mesh.get_aabb()
	_check(is_equal_approx(beam_bounds.size.x, 4.0) and beam_bounds.size.y < 0.16, "beam model respects endpoints and local section dimensions")
	model_check.queue_free()
	_sample = SAMPLE.instantiate()
	add_child(_sample)
	await _frames(40)
	_check(_sample.viewport.own_world_3d and _sample.stage.camera.current, "dedicated world and active 3D camera")
	_check(_sample.stage.find_children("*", "StudyStage", true, false).is_empty(), "no StudyStage reuse")
	_check(_sample.stage.key.shadow_enabled and _sample.stage.accent is SpotLight3D, "independent daylight and pavilion lighting")
	_check(int(_sample.stage.geometry.get_meta("modelled_parts")) > 1000, "detailed architectural modules, joinery and lattice")
	_check(_sample.stage.geometry.palette.wood.albedo_texture != null and _sample.stage.geometry.palette.stone.normal_texture != null, "bundled wood and stone material maps")
	_check(_sample.stage.environment.sky != null and not _sample.stage.environment.ssr_enabled, "painted sky and controlled planar reflections without PBR SSR")
	_check(_sample.stage.render_style.material_count > 15 and _sample.stage.render_style.outlined_count > 0, "render-only pigments and selective contours applied")
	_check(_sample.stage.geometry.get_node("ArchivePlaque").material_override is ShaderMaterial, "architecture uses pigment lighting instead of photographic albedo")
	var triangles := 0
	for component in [_sample.stage.geometry, _sample.stage.landscape]:
		for instance in component.get_children():
			if instance is MeshInstance3D:
				var arrays: Array = instance.mesh.surface_get_arrays(0)
				triangles += arrays[Mesh.ARRAY_INDEX].size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size() / 3
	print("MODEL PARTS=", _sample.stage.geometry.get_meta("modelled_parts"), " TRIANGLES=", triangles)
	_check(triangles > 100000, "model contains actual tiled roofs and individual blossom geometry")
	var wide := await _capture("wide")
	var scene_image: Image = _sample.viewport.get_texture().get_image()
	_check(scene_image.save_png("res://shots/title-art-scene.png") == OK, "native 3D scene capture without UI")
	var sign_point: Vector2 = _sample.stage.camera.unproject_position(_sample.stage.geometry.get_node("ArchiveLettering").global_position)
	var lettering_pixels := 0
	for y in range(int(sign_point.y) - 12, int(sign_point.y) + 12):
		for x in range(int(sign_point.x) - 42, int(sign_point.x) + 42):
			var pixel := scene_image.get_pixel(x, y)
			if pixel.r > 0.65 and pixel.g > 0.55 and pixel.b < pixel.r * 0.85: lettering_pixels += 1
	_check(lettering_pixels > 20, "gold sign lettering survives the contour screen pass")
	var before: Transform3D = _sample.stage.camera.global_transform
	_sample.set_detail(true)
	await _sample.stage._motion.finished
	_check(_sample.stage.camera.global_transform != before and _sample.stage.inspection > 0.99, "camera enters the courtyard")
	_check(not _sample._menu.visible and _sample._return.visible, "detail has a visible return control")
	await _capture("detail")
	_sample.set_detail(false)
	await _sample.stage._motion.finished
	_check(_sample._menu.visible and not _sample._return.visible and _sample.stage.inspection < 0.01, "return restores composition")
	_sample._key_slider.value = 0
	_sample._accent_slider.value = 0
	_check(_sample.stage.key.light_energy == 0 and _sample.stage.accent.light_energy == 0, "review sliders control actual light nodes")
	var dark := await _capture("lights-off")
	var difference := 0.0
	for y in range(0, wide.get_height(), 16):
		for x in range(wide.get_width() / 2, wide.get_width(), 16):
			difference += absf(wide.get_pixel(x, y).get_luminance() - dark.get_pixel(x, y).get_luminance())
	_check(difference > 5.0, "render visibly responds to real light changes")
	_sample._key_slider.value = 1.85
	_sample._accent_slider.value = 3.6
	_sample._reflection_check.button_pressed = false
	_check(is_zero_approx(_sample.stage.get_node("ReflectingPool").material_override.get_shader_parameter("reflection_strength")), "reflection control removes the planar image contribution")
	_check(_sample.stage.mirror_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "disabled reflections stop the extra render pass")
	_sample._reflection_check.button_pressed = true
	_sample._contour_check.button_pressed = false
	_check(not _sample.stage.contours.visible and _sample.stage.mirror_camera.cull_mask & _sample.stage.contours.layers == 0, "contour switch disables the pass and reflection camera excludes it")
	_sample._contour_check.button_pressed = true
	var atmosphere: Node3D = _sample.stage.atmosphere
	_check(atmosphere.fog_volumes.size() == 2 and _sample.stage.environment.volumetric_fog_density == 0.0, "local volumetric mist leaves the foreground and sky free of global haze")
	_sample._motion_check.button_pressed = false
	var stopped: float = atmosphere.elapsed
	var stopped_petal: Transform3D = atmosphere.petals.multimesh.get_instance_transform(0)
	await _frames(6)
	_check(atmosphere.elapsed == stopped and atmosphere.petals.multimesh.get_instance_transform(0) == stopped_petal, "motion control freezes petals and the shared ambient clock")
	var bounded := true
	for at_time in [0.0, 10.0, 1000.0]:
		for i in atmosphere.PETAL_COUNT:
			var transform: Transform3D = atmosphere.petal_transform(i, at_time)
			bounded = bounded and atmosphere.petals.custom_aabb.has_point(transform.origin) and transform.origin.y >= 0.23
	_check(bounded and atmosphere.petals.multimesh.instance_count == 112, "petal loops stay above the ground within fixed bounds and fixed instance count")
	atmosphere.seek(4.0)
	var fog_image := await _capture("ambient-fog")
	_sample._fog_slider.value = 0.0
	_check(not _sample.stage.environment.volumetric_fog_enabled, "zero mist slider disables volumetric rendering")
	var clear_image := await _capture("ambient-clear")
	var mist_delta := _image_delta(fog_image, clear_image)
	print("AMBIENT MIST DELTA=", mist_delta)
	_check(mist_delta.x > 0.0002 and mist_delta.x < 0.06, "local fog changes the rendered image without washing out the palette")
	atmosphere.petals.visible = false
	var no_petals := await _capture("ambient-no-petals")
	var petal_delta := _image_delta(clear_image, no_petals)
	print("AMBIENT PETAL DELTA=", petal_delta)
	_check(petal_delta.y > 80, "falling petals remain visible after contour composition")
	atmosphere.petals.visible = true
	_sample._fog_slider.value = 1.0
	_sample._motion_check.button_pressed = true
	await _frames(6)
	_check(atmosphere.elapsed > 4.0, "resuming ambient motion advances the shared clock")
	await _frames()
	_sample.queue_free()
	await _frames(16)
	print("[title_art_sample_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
