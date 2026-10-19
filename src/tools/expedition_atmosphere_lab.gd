extends "res://src/tools/expedition_glyph_lab.gd"
## Palette and peripheral architecture iteration around the accepted inlaid-glyph fixture.
const SURROUNDINGS = preload("res://src/map/expedition_stylized_surroundings.gd")
const DUSK = preload("res://assets/expedition/palettes/mochi_dusk.tres")
const HALL = preload("res://assets/expedition/palettes/cinnabar_hall.tres")
var surroundings: Node3D
var palette_select: OptionButton
var scenery_toggle: CheckButton
var foreground_toggle: CheckButton


func _ready() -> void:
	palette_source = DUSK
	_view_size = 4.6
	_look = Vector3(1.5,.28,1.25)
	zoom_limits = Vector2(3.3,7.0)
	super._ready()
	_detail.text = "中键拖看　滚轮缩放｜同一3×3字砖 · 冷暖配色 · 近景门柱／中景碑院／远景冥河"


func _build_ui() -> void:
	super._build_ui()
	title_label.text = "墨池 · 冥河碑院｜配色与外围建筑"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	tool_rows.add_child(row)
	tool_rows.move_child(row,0)
	palette_select = OptionButton.new()
	for text in ["冷青冥河", "暖灰朱砂", "原灰绿（对照）"]: palette_select.add_item(text)
	palette_select.item_selected.connect(set_palette_index)
	row.add_child(palette_select)
	scenery_toggle = _toggle(row,"外围建筑",true,func(value: bool): surroundings.set_enabled(value))
	foreground_toggle = _toggle(row,"近景框景",true,func(value: bool): surroundings.foreground.visible = value)
	for entry in [["墙面","architecture_front"],["屋面","roof"],["朱砂","seal"],["远雾","mist"]]:
		var label := Label.new()
		label.text = entry[0]
		row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(32,26)
		picker.edit_alpha = false
		var property: String = entry[1]
		picker.color = palette.get(property)
		picker.color_changed.connect(func(value: Color): palette.set(property,value))
		color_pickers[property] = picker
		row.add_child(picker)


func _build_world() -> void:
	super._build_world()
	# The old slab edge stops being a frame when joined to the surrounding courtyard.
	for mesh in floor_surfaces: mesh.get_meta("flat_outline").visible = false
	surroundings = SURROUNDINGS.new()
	surroundings.name = "MochiCourtyardSurroundings"
	world.add_child(surroundings)
	surroundings.setup(style,camera,_environment)
	style.refresh_outlines()


func set_palette_index(index: int) -> void:
	var source: ExpeditionFlatPalette = [DUSK,HALL,PALETTE][clampi(index,0,2)]
	# Keep the shared instance and existing subscriptions; emit one update after the copy.
	palette.set_block_signals(true)
	for property: Dictionary in source.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)!=0 and int(property.type) in [TYPE_COLOR,TYPE_FLOAT]:
			palette.set(property.name,source.get(property.name))
	palette.set_block_signals(false)
	palette.emit_changed()


func reset_camera() -> void:
	_view_size = 4.6
	_look = Vector3(1.5,.28,1.25)
	set_tick(0)
	_apply_camera()
