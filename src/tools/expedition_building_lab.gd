extends "res://src/tools/expedition_shrine_lab.gd"
## Three service/gate assets share the existing shrine's camera, palette and lighting.
const REST = preload("res://src/map/expedition_rest_pavilion.gd")
const STALL = preload("res://src/map/expedition_type_stall.gd")
const GATE = preload("res://src/map/expedition_beast_gate.gd")
var buildings: Array[Node3D] = []
var state_toggle: CheckButton
var _state_hint: Label


func _build_ui() -> void:
	super._build_ui()
	title_label.text = "冥府碑院 · 息灯亭／青铜字摊／兽面门阙"
	mode.clear()
	for label in ["息灯亭近看","青铜字摊近看","兽面门阙近看","三座同屏","与问字龛同屏"]: mode.add_item(label)
	mode.select(3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	tool_footer.add_child(row)
	tool_footer.move_child(row,2)
	state_toggle = CheckButton.new()
	state_toggle.text = "使用后／解封"
	state_toggle.toggled.connect(set_alternate_state)
	row.add_child(state_toggle)
	_state_hint = Label.new()
	_state_hint.text = "息灯亭：熄灯挂歇牌　字摊：闭柜收字　门阙：去封开门"
	_state_hint.add_theme_color_override("font_color",Color("a3b6b2"))
	_state_hint.add_theme_font_size_override("font_size",14)
	row.add_child(_state_hint)
	var cloth_label := Label.new()
	cloth_label.text = "棚布"
	row.add_child(cloth_label)
	var cloth_picker := ColorPickerButton.new()
	cloth_picker.custom_minimum_size = Vector2(32,26)
	cloth_picker.edit_alpha = false
	cloth_picker.color = palette.cloth
	cloth_picker.color_changed.connect(func(value: Color): palette.cloth = value)
	_pickers["cloth"] = cloth_picker
	row.add_child(cloth_picker)
	light_toggle.text = "设施暖灯"
	detail_toggle.toggled.connect(func(value: bool):
		for building in buildings: building.set_details_enabled(value))


func _build_world() -> void:
	super._build_world()
	for source in [REST,STALL,GATE]:
		var building: Node3D = source.new()
		world_root.add_child(building)
		building.setup(style)
		buildings.append(building)
	set_mode(3)


func set_mode(index: int) -> void:
	if buildings.is_empty(): return
	var group := index>=3
	for n in buildings.size():
		var building := buildings[n]
		building.visible = group or n==index
		building.position = Vector3((n-1)*2.35,0,0) if group else Vector3.ZERO
	shrine.visible = index==4
	shrine.position = Vector3(3.6,0,0)
	tree.visible = false
	if index==4:
		for n in buildings.size(): buildings[n].position.x = (n-1.5)*2.25
		shrine.position.x = 3.25
	stage.mesh = TypeMeshes.beveled_box(Vector3(9.4 if index==4 else (7.6 if group else 3.6),.09,2.8),.02)
	_look = Vector3(0,.85,0)
	_view_size = 4.8 if index==4 else (4.2 if group else 2.9)
	_yaw = 12 if group else 18
	_pitch = 40 if group else 38
	_update_light()
	_apply_camera()
	state_toggle.text = ["歇息后：熄灯挂牌","收摊：闭柜收字","解封：开启门扇","使用后／解封","使用后／解封"][index]


func set_alternate_state(value: bool) -> void:
	for building in buildings: building.set_alternate_state(value)
	style.refresh_outlines()


func _update_light() -> void:
	super._update_light()
	for building in buildings: building.set_lamps_enabled(light_toggle.button_pressed)


func set_lighting_enabled(value: bool) -> void:
	super.set_lighting_enabled(value)
	for building in buildings: building.set_scene_lighting(value)
