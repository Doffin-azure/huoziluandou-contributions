extends "res://src/tools/expedition_shrine_lab.gd"
## Four gravestone variants under the same dark architecture lighting.
const TOMBSTONE = preload("res://src/map/expedition_tombstone.gd")
var graves: Array[Node3D] = []
var _caption: Label


func _build_ui() -> void:
	super._build_ui()
	title_label.text = "冥府碑林 · 倾斜旧碑／断裂残碑／瘦高碑／矮宽碑"
	mode.clear()
	for text in ["倾斜旧碑近看","断裂残碑近看","瘦高碑近看","矮宽碑近看","四碑同屏","与问字龛同屏"]: mode.add_item(text)
	mode.select(4)
	light_toggle.text = "暖光对照"
	light_toggle.set_pressed_no_signal(false)
	detail_toggle.text = "铭文／刻纹"
	detail_toggle.toggled.connect(func(value: bool):
		for grave in graves: grave.set_details_enabled(value))
	# Hide architecture-only colors; keep the common camera, ink and light controls.
	for property in ["architecture_front","roof"]:
		var picker: ColorPickerButton = _pickers[property]
		picker.get_parent().get_child(picker.get_index()-1).hide()
		picker.hide()
	roof_response_slider.get_parent().get_child(roof_response_slider.get_index()-1).hide()
	roof_response_slider.hide()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	tool_footer.add_child(row)
	tool_footer.move_child(row,2)
	for entry in [["碑石","tomb_stone"],["断口","tomb_cut"],["刻字","tomb_engraving"]]:
		var text := Label.new()
		text.text = entry[0]
		row.add_child(text)
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
	hint.text = "左键转看／滚轮缩放｜同一制作比例 · 真厚度与倒角 · 阴刻铭文／断口／碑脚落地"


func _build_world() -> void:
	super._build_world()
	for index in 4:
		var grave: Node3D = TOMBSTONE.new()
		grave.variant = index
		world_root.add_child(grave)
		grave.setup(style)
		graves.append(grave)
	set_mode(4)


func set_mode(index: int) -> void:
	if graves.is_empty(): return
	var group := index>=4
	var positions := [-2.0,-.70,.65,1.95]
	for n in graves.size():
		graves[n].visible = group or n==index
		graves[n].position = Vector3(positions[n],0,0) if group else Vector3.ZERO
	shrine.visible = index==5
	shrine.position = Vector3(3.8,0,0)
	tree.visible = false
	stage.mesh = TypeMeshes.beveled_box(Vector3(9.0 if index==5 else (6.4 if group else 2.7),.08,2.25),.02)
	stage.position = Vector3(.65 if index==5 else 0,-.04,.12)
	if group:
		_look = Vector3(.55 if index==5 else 0,.80,.06)
		_view_size = 4.6 if index==5 else 3.55
	else:
		_look = [Vector3(-.10,.73,0),Vector3(.08,.43,.12),Vector3(0,.93,0),Vector3(0,.46,0)][index]
		_view_size = [2.15,1.65,2.55,1.75][index]
	_yaw = 12 if group else 18
	_pitch = 37 if group else 32
	_caption.text = "同一比例：倾斜旧碑 → 残碑 → 瘦高碑 → 矮宽碑" if group else ["碑脚为倾斜支点，虬裂与沉脚","真实断口＋倒落碑额＋残留铭文","窄碑额、双层碑座、竖向铭文","宽肩厚碑、低碑座、横向铭文"][index]
	_update_light()
	_apply_camera()


func _update_light() -> void:
	super._update_light()
	if not graves.is_empty() and not shrine.visible:
		lamp_light.global_position = Vector3(-.45,.68,.85)
		lamp_light.omni_range = 1.8
		lamp_light.light_energy = .42


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		_view_size = clampf(_view_size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),.9,5.5)
		_apply_camera()
		return
	super._map_input(event)
