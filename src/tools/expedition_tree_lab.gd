extends Control
## A single-asset review: close-up of the same tree used by the courtyard fixture.
const TREE = preload("res://src/map/expedition_stylized_tree.gd")
const PALETTE = preload("res://assets/expedition/palettes/mochi_dusk.tres")
var palette: ExpeditionFlatPalette
var style: ExpeditionFlatStyle
var viewport: SubViewport
var camera: Camera3D
var tree: Node3D
var area: Control
var line_slider: HSlider
var contour_toggle: CheckButton
var detail_toggle: CheckButton
var _background: Environment
var _pickers: Dictionary = {}
var _view_size := 2.7


func _ready() -> void:
	palette = PALETTE.duplicate(true)
	style = ExpeditionFlatStyle.new(palette)
	_build_ui()
	_build_world()
	palette.changed.connect(_refresh_palette)
	_refresh_palette()
	_resize.call_deferred()


func _exit_tree() -> void:
	if style!=null: style.dispose()
	if palette!=null and palette.changed.is_connected(_refresh_palette): palette.changed.disconnect(_refresh_palette)


func _build_ui() -> void:
	var theme_value := Theme.new()
	theme_value.default_font = Ink.serif
	theme_value.default_font_size = 16
	theme = theme_value
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	var title := Label.new()
	title.text = "冥府怪松 · 斜干与针叶"
	title.add_theme_font_size_override("font_size",26)
	title.add_theme_color_override("font_color",Color("ded4b7"))
	_margin(column,24,12).add_child(title)
	area = Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size = Vector2(320,360)
	area.gui_input.connect(_input_area)
	area.resized.connect(_resize)
	column.add_child(area)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_8X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	area.add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(display)
	var footer := VBoxContainer.new()
	_margin(column,24,10).add_child(footer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	footer.add_child(row)
	contour_toggle = CheckButton.new()
	contour_toggle.text = "外轮廓"
	contour_toggle.button_pressed = true
	contour_toggle.toggled.connect(func(value: bool): tree.contour.visible = value)
	row.add_child(contour_toggle)
	detail_toggle = CheckButton.new()
	detail_toggle.text = "内部笔线"
	detail_toggle.button_pressed = true
	detail_toggle.toggled.connect(func(value: bool): tree.details.visible = value)
	row.add_child(detail_toggle)
	var label := Label.new()
	label.text = "线宽"
	row.add_child(label)
	line_slider = HSlider.new()
	line_slider.custom_minimum_size.x = 155
	line_slider.min_value = .8
	line_slider.max_value = 4
	line_slider.step = .1
	line_slider.value = palette.tree_outline_pixels
	line_slider.value_changed.connect(func(value: float): palette.tree_outline_pixels = value)
	row.add_child(line_slider)
	for item in [["枯皮","tree_bark"],["墨绿针叶","tree_leaf"],["灰青亮面","tree_leaf_light"],["墨线","tree_ink"]]:
		var text := Label.new()
		text.text = item[0]
		row.add_child(text)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(32,26)
		picker.edit_alpha = false
		var property: String = item[1]
		picker.color_changed.connect(func(value: Color): palette.set(property,value))
		_pickers[property] = picker
		row.add_child(picker)
	var note := Label.new()
	note.text = "横斜枯干 · 疏针与留白 · 断续刻线｜滚轮缩放，可调线宽和配色"
	note.add_theme_font_size_override("font_size",14)
	note.add_theme_color_override("font_color",Color("a3b6b2"))
	footer.add_child(note)


func _margin(parent: Node, horizontal: int, vertical: int) -> MarginContainer:
	var node := MarginContainer.new()
	for edge in ["left","right"]: node.add_theme_constant_override("margin_"+edge,horizontal)
	for edge in ["top","bottom"]: node.add_theme_constant_override("margin_"+edge,vertical)
	parent.add_child(node)
	return node


func _build_world() -> void:
	var world := Node3D.new()
	viewport.add_child(world)
	var settings := WorldEnvironment.new()
	_background = Environment.new()
	_background.background_mode = Environment.BG_COLOR
	settings.environment = _background
	world.add_child(settings)
	camera = Camera3D.new()
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	world.add_child(camera)
	style.camera = camera
	_apply_camera()
	tree = TREE.new()
	world.add_child(tree)
	tree.setup(style,camera)
	style.refresh_outlines()


func _resize() -> void:
	if camera==null: return
	viewport.size = Vector2i(maxi(16,int(area.size.x)),maxi(16,int(area.size.y)))
	_apply_camera()


func _apply_camera() -> void:
	if camera==null: return
	camera.size = _view_size
	var pitch := deg_to_rad(43.0)
	var yaw := deg_to_rad(12.0)
	var direction := Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))
	camera.position = direction*10+Vector3(.05,.66,-.45)
	camera.look_at(Vector3(.05,.66,-.45),Vector3.UP)
	if tree!=null: tree.sync_camera()
	style.refresh_outlines()


func _refresh_palette() -> void:
	_background.background_color = palette.background
	RenderingServer.set_default_clear_color(palette.background)
	for property in _pickers: _pickers[property].color = palette.get(property)
	line_slider.set_value_no_signal(palette.tree_outline_pixels)


func _input_area(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		_view_size = clampf(_view_size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),2.4,5.2)
		_apply_camera()
