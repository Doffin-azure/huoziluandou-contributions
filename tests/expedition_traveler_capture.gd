extends Control
const LAB = preload("res://src/tools/expedition_traveler_lab.gd")
var _out := ""
var _pass := 0
var _fail := 0


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-17-traveler")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(150).timeout.connect(func(): push_error("Traveler preview timed out"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 10) -> void:
	for i in count: await get_tree().process_frame


func _check(ok: bool, message: String) -> void:
	if ok: _pass += 1
	else:
		_fail += 1
		push_error(message)


func _shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(filename))==OK,filename)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1920,1080)
	var before := GameState.rng.state
	var expedition_before: Expedition = GameState.expedition
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(18)
	_check(lab.characters.size()==3,"Front, side, and back share one native mesh design")
	var count: int = lab.characters[0].triangle_count
	print("[Traveler] triangles=%d excluding outlines" % count)
	_check(count>300 and count<8000,"Native mesh triangle budget")
	lab.chrome.visible = false
	await _shot("01-three-views-1920.png")
	lab.set_mode(1)
	await _frames()
	await _shot("02-model-volume-1920.png")
	# Color edits must actually reach the native character material.
	var original: Color = lab.costume.coat
	lab.costume.coat = Color("394355")
	var paint: ShaderMaterial = lab.characters[0]._costume_materials.coat
	_check(paint.get_shader_parameter("pigment")==lab.costume.coat,"Editable costume palette updates materials")
	lab.costume.coat = original
	lab.set_mode(2)
	await _frames()
	await _shot("03-garden-scale-1920.png")
	get_window().size = Vector2i(1280,720)
	await _frames(12)
	await _shot("04-garden-scale-1280.png")
	lab.set_mode(3)
	await _frames()
	await _shot("05-real-lantern-light-1280.png")
	lab.warm_toggle.button_pressed = false
	await _frames()
	_check(not lab.characters[0].lantern_light.visible,"Carried light can be toggled independently")
	await _shot("06-lantern-light-off-1280.png")
	lab.warm_toggle.button_pressed = true
	lab.chrome.visible = true
	await _frames()
	_check(lab.chrome.get_child(1).get_global_rect().end.x<=lab.size.x,"1280 workbench controls fit")
	await _shot("07-workbench-1280.png")
	lab.queue_free()
	await _frames(4)
	var prefab: PackedScene = load("res://assets/expedition/characters/lantern_traveler.tscn")
	var character: Node3D = prefab.instantiate()
	add_child(character)
	await _frames(5)
	_check(character.triangle_count==count,"Standalone Godot scene builds the same mesh")
	_check(GameState.rng.state==before and GameState.expedition==expedition_before,"Preview does not alter gameplay or RNG")
	character.queue_free()
	await _frames(3)
	print("[Traveler] PASS=%d FAIL=%d" % [_pass,_fail])
	get_tree().quit(1 if _fail else 0)
