extends Node
const LAB = preload("res://src/tools/expedition_prop_lab.gd")
const CONTEXT = preload("res://src/tools/expedition_atmosphere_lab.gd")
var _out := ""
var _fail := 0


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/art-concepts/2026-10-16-mochi/godot-prop-detail-study")
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(90).timeout.connect(func(): push_error("物件小样超时"); get_tree().quit(1))
	_run.call_deferred()


func _frames(count := 8) -> void:
	for n in count: await get_tree().process_frame


func _check(value: bool, message: String) -> void:
	if not value:
		_fail += 1
		push_error(message)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_check(get_viewport().get_texture().get_image().save_png(_out.path_join(name))==OK,"保存物件实机图失败："+name)


func _run() -> void:
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1280,720)
	var rng_before := GameState.rng.state
	var lab := LAB.new()
	add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames(24)
	_check(lab.props.size()==3,"三种物件已建立")
	await _shot("01-three-props-1280.png")
	for index in 3:
		lab.mode.select(index)
		lab.mode.item_selected.emit(index)
		await _frames()
		await _shot("0%d-prop-%d-1280.png"%[index+2,index])
	lab.state_toggle.button_pressed = true
	await _frames()
	_check(not lab.props[2].intact.visible and lab.props[2].cleared.visible,"解除移除高石障并显示低矮残骸")
	await _shot("05-barrier-cleared-1280.png")
	lab.mode.select(0)
	lab.mode.item_selected.emit(0)
	await _frames()
	_check(lab.props[0].lid_pivot.rotation.x<-1.5,"匣盖围绕后铰链真实开启")
	_check(lab.props[0]._torn_seal.visible and not lab.props[0]._seal.visible,"开匣移除完整封条并留下断封")
	await _shot("06-casket-open-1280.png")
	lab.mode.select(1)
	lab.mode.item_selected.emit(1)
	await _frames()
	_check(lab.props[1]._snuffer.visible and not lab.props[1]._lamps[0].visible,"熄灯关闭原生局部光并合上实体灯罩")
	await _shot("07-lamp-off-1280.png")
	lab.state_toggle.button_pressed = false
	lab.mode.select(3)
	lab.mode.item_selected.emit(3)
	get_window().size = Vector2i(1920,1080)
	await _frames(12)
	await _shot("08-three-props-1920.png")
	lab.state_toggle.button_pressed = true
	await _frames()
	await _shot("09-three-props-used-1920.png")
	lab.state_toggle.button_pressed = false
	lab.mode.select(4)
	lab.mode.item_selected.emit(4)
	await _frames()
	await _shot("10-props-and-shrine-1920.png")
	lab.marker_toggle.button_pressed = false
	_check(not lab.props[0].floor_marker.visible and not lab.props[2].floor_marker.visible,"镶字标识可独立关闭供后续字格接入")
	lab.queue_free()
	await _frames()
	var context := CONTEXT.new()
	add_child(context)
	context.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_window().size = Vector2i(1280,720)
	await _frames(16)
	await _shot("11-lamps-in-courtyard-1280.png")
	for index in 9:
		var point: Vector2 = context.camera.unproject_position(Vector3(index%3+.5,0,index/3+.5))
		_check(context.pick_cell(point)==index,"替换前沿灯柱不改变字格拾取")
	get_window().size = Vector2i(1920,1080)
	await _frames(12)
	await _shot("12-lamps-in-courtyard-1920.png")
	_check(GameState.rng.state==rng_before,"物件、状态与镜头不消耗玩法随机数")
	context.queue_free()
	await _frames()
	print("[PropDetailLab] FAIL %d"%_fail)
	get_tree().quit(0 if _fail==0 else 1)
