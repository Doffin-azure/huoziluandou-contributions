extends Node
const LAB = preload("res://src/tools/expedition_tombstone_lab.gd")
const CONTEXT = preload("res://src/tools/expedition_atmosphere_lab.gd")
var _out := ""
var _fail := 0


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-16-mochi/godot-tombstone-study")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(90).timeout.connect(func(): push_error("墓碑小样超时"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 8) -> void:
	for n in count: await get_tree().process_frame


func _check(value: bool, message: String) -> void:
	if not value:
		_fail += 1
		push_error(message)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"保存墓碑实机图失败："+name)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var rng_before := GameState.rng.state
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(24)
	_check(lab.graves.size()==4,"四种墓碑已建立")
	_check(absf(lab.graves[0].body_pivot.rotation.z)>.2,"倾斜作用于真实碑体和刻字的共同支点")
	_check(lab.graves[1].wear.has_node("FallenCrownFragment"),"残碑有独立立体落片")
	_check(lab.graves[2].body.mesh.get_aabb().size.y>lab.graves[3].body.mesh.get_aabb().size.y*1.8,"高矮碑保持真实高度差")
	_check(lab.graves[3].body.mesh.get_aabb().size.x>lab.graves[2].body.mesh.get_aabb().size.x*1.8,"宽窄碑保持真实宽度差")
	await _shot("01-four-tombstones-1280.png")
	for index in 4:
		lab.mode.select(index)
		lab.mode.item_selected.emit(index)
		await _frames()
		await _shot("0%d-tombstone-%d-1280.png"%[index+2,index])
	lab.mode.select(0)
	lab.mode.item_selected.emit(0)
	lab._yaw = 80
	lab._apply_camera()
	await _frames()
	await _shot("06-leaning-side-1280.png")
	lab.mode.select(4)
	lab.mode.item_selected.emit(4)
	get_window().size = Vector2i(1920,1080)
	await _frames(12)
	await _shot("07-four-tombstones-1920.png")
	lab.mode.select(5)
	lab.mode.item_selected.emit(5)
	await _frames()
	await _shot("08-tombstones-and-shrine-1920.png")
	lab.mode.select(4)
	lab.mode.item_selected.emit(4)
	lab.light_toggle.button_pressed = true
	await _frames()
	await _shot("09-warm-light-1920.png")
	lab.detail_toggle.button_pressed = false
	await _frames()
	_check(not lab.graves[0]._inscriptions[0].visible,"关闭铭文同时关闭模拟凹刻的边缘层")
	lab.detail_toggle.button_pressed = true
	lab.queue_free()
	await _frames()
	var context := CONTEXT.new()
	add_child(context)
	context.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_window().size = Vector2i(1280,720)
	await _frames(16)
	await _shot("10-tombstones-in-courtyard-1280.png")
	for index in 9:
		var point: Vector2 = context.camera.unproject_position(Vector3(index%3+.5,0,index/3+.5))
		_check(context.pick_cell(point)==index,"替换外围墓碑后字格拾取一致")
	get_window().size = Vector2i(1920,1080)
	await _frames(12)
	await _shot("11-tombstones-in-courtyard-1920.png")
	_check(GameState.rng.state==rng_before,"墓碑、碎石、刻纹和镜头不消耗玩法随机数")
	context.queue_free()
	await _frames()
	print("[TombstoneLab] FAIL %d"%_fail)
	get_tree().quit(0 if _fail==0 else 1)
