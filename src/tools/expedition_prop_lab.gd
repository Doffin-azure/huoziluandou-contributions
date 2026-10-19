extends "res://src/tools/expedition_shrine_lab.gd"
## Small reward, light and obstacle assets, with reversible visual states.
const CASKET = preload("res://src/map/expedition_reward_casket.gd")
const LAMP = preload("res://src/map/expedition_bronze_lamp.gd")
const BARRIER = preload("res://src/map/expedition_sealed_barrier.gd")
var props: Array[Node3D] = []
var state_toggle: CheckButton
var marker_toggle: CheckButton
var _caption: Label


func _build_ui() -> void:
	super._build_ui()
	title_label.text = "冥府碑院 · 奖励封匣／青铜灯柱／封印墨障"
	mode.clear()
	for text in ["奖励封匣近看","青铜灯柱近看","封印墨障近看","三件同屏","与问字龛同屏"]: mode.add_item(text)
	mode.select(3)
	light_toggle.text = "灯柱暖光"
	detail_toggle.toggled.connect(func(value: bool):
		for prop in props: prop.set_details_enabled(value))
	var stone_picker: ColorPickerButton = _pickers["architecture_front"]
	stone_picker.get_parent().get_child(stone_picker.get_index()-1).hide()
	stone_picker.hide()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	tool_footer.add_child(row)
	tool_footer.move_child(row,2)
	state_toggle = CheckButton.new()
	state_toggle.text = "使用后／解除"
	state_toggle.toggled.connect(set_alternate_state)
	row.add_child(state_toggle)
	marker_toggle = CheckButton.new()
	marker_toggle.text = "地面镶字"
	marker_toggle.set_pressed_no_signal(true)
	marker_toggle.toggled.connect(func(value: bool):
		for index in [0,2]: props[index].floor_marker.visible = value)
	row.add_child(marker_toggle)
	for entry in [["旧铜","bronze"],["铜绿","patina"]]:
		var label := Label.new()
		label.text = entry[0]
		row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(32,26)
		picker.edit_alpha = false
		var property: String = entry[1]
		picker.color = palette.get(property)
		picker.color_changed.connect(func(value: Color): palette.set(property,value))
		_pickers[property] = picker
		row.add_child(picker)
	_caption = Label.new()
	_caption.add_theme_color_override("font_color",Color("a3b6b2"))
	_caption.add_theme_font_size_override("font_size",14)
	row.add_child(_caption)
	var hint: Label = tool_footer.get_child(tool_footer.get_child_count()-1)
	hint.text = "左键转看／滚轮缩放｜深色材质与墨线 · 实体空匣／灯罩／封印 · 独立表现状态"


func _build_world() -> void:
	super._build_world()
	for source in [CASKET,LAMP,BARRIER]:
		var prop: Node3D = source.new()
		world_root.add_child(prop)
		prop.setup(style)
		props.append(prop)
	set_mode(3)


func set_mode(index: int) -> void:
	if props.is_empty(): return
	var group := index>=3
	var xs := [-1.65,0.0,1.65]
	for n in props.size():
		props[n].visible = group or n==index
		props[n].position = Vector3(xs[n],0,0) if group else Vector3.ZERO
	shrine.visible = index==4
	shrine.position = Vector3(3.4,0,0)
	tree.visible = false
	stage.mesh = TypeMeshes.beveled_box(Vector3(7.5 if index==4 else (5.7 if group else 2.6),.08,2.35),.02)
	stage.position = Vector3(.65 if index==4 else 0,-.04,.12)
	if group:
		_look = Vector3(.55 if index==4 else 0,.72,.03)
		_view_size = 4.1 if index==4 else 3.05
	else:
		_look = [Vector3(0,.62,0),Vector3(0,.80,0),Vector3(0,.58,0)][index]
		_view_size = [2.05,2.25,2.05][index]
	_yaw = 12 if group else 18
	_pitch = 39 if group else 35
	state_toggle.text = ["取空：开盖断封","熄灯：合上灯罩","解除：散为碎石","使用后／解除","使用后／解除"][index]
	_caption.text = "封匣 → 灯柱 → 墨障" if group else ["真空腔、后铰链与断封条","铜绿柱身、六面灯笼与合罩","交叉封印、实体石障与解除残骸"][index]
	_update_light()
	_apply_camera()


func set_alternate_state(value: bool) -> void:
	for prop in props: prop.set_alternate_state(value)
	style.refresh_outlines()


func _update_light() -> void:
	super._update_light()
	if not props.is_empty():
		lamp_light.visible = light_toggle.button_pressed and shrine.visible
		for prop in props: prop.set_lamps_enabled(light_toggle.button_pressed)


func set_lighting_enabled(value: bool) -> void:
	super.set_lighting_enabled(value)
	for prop in props: prop.set_scene_lighting(value)


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		_view_size = clampf(_view_size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),.9,5.5)
		_apply_camera()
		return
	super._map_input(event)
