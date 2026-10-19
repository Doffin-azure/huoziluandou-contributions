extends Control
## A real 3D architecture asset, inspectable in isolation and alongside the pine cutout.
const SHRINE = preload("res://src/map/expedition_stylized_shrine.gd")
const TREE = preload("res://src/map/expedition_stylized_tree.gd")
const PALETTE = preload("res://assets/expedition/palettes/mochi_lantern.tres")
const BASELINE_PALETTE = preload("res://assets/expedition/palettes/mochi_dusk.tres")
var palette: ExpeditionFlatPalette
var style: ExpeditionFlatStyle
var viewport: SubViewport
var camera: Camera3D
var shrine: Node3D
var tree: Node3D
var area: Control
var title_label: Label
var tool_footer: VBoxContainer
var world_root: Node3D
var stage: MeshInstance3D
var mode: OptionButton
var light_toggle: CheckButton
var detail_toggle: CheckButton
var line_slider: HSlider
var _environment: Environment
var _sky: Sky
var _lights: Node3D
var main_light: DirectionalLight3D
var rim_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var lamp_light: OmniLight3D
var lighting_toggle: CheckButton
var sky_toggle: CheckButton
var rim_toggle: CheckButton
var glow_toggle: CheckButton
var exposure_slider: HSlider
var roof_response_slider: HSlider
var _pickers: Dictionary = {}
var _yaw := 18.0
var _pitch := 43.0
var _view_size := 2.45
var _look := Vector3(0,.70,0)
var _dragging := false


func _ready() -> void:
	palette = PALETTE.duplicate(true)
	style = ExpeditionFlatStyle.new(palette)
	style.set_scene_lighting(true)
	_build_ui()
	_build_world()
	palette.changed.connect(_refresh_palette)
	_refresh_palette()
	_resize.call_deferred()


func _exit_tree() -> void:
	if style!=null: style.dispose()
	if palette!=null and palette.changed.is_connected(_refresh_palette): palette.changed.disconnect(_refresh_palette)


func _build_ui() -> void:
	var visual_theme := Theme.new()
	visual_theme.default_font = Ink.serif
	visual_theme.default_font_size = 16
	theme = visual_theme
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation",0)
	add_child(column)
	var title := Label.new()
	title_label = title
	title.text = "碑院问字龛 · 天空与冷暖光影"
	title.add_theme_font_size_override("font_size",26)
	title.add_theme_color_override("font_color",Color("ded4b7"))
	_margin(column,24,12).add_child(title)
	area = Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size = Vector2(320,360)
	area.gui_input.connect(_map_input)
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
	tool_footer = footer
	_margin(column,24,10).add_child(footer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	footer.add_child(row)
	mode = OptionButton.new()
	mode.add_item("建筑近看")
	mode.add_item("与怪松同屏")
	mode.item_selected.connect(set_mode)
	row.add_child(mode)
	for entry in [["前侧",18.0],["侧面",80.0],["背面",155.0]]:
		var button := Button.new()
		button.text = entry[0]
		var angle: float = entry[1]
		button.pressed.connect(func(): _yaw = angle; _pitch = 43; _apply_camera())
		row.add_child(button)
	light_toggle = CheckButton.new()
	light_toggle.text = "龛内暖光"
	light_toggle.button_pressed = true
	light_toggle.toggled.connect(func(value: bool): shrine.set_lamp_lit(value); _update_light())
	row.add_child(light_toggle)
	detail_toggle = CheckButton.new()
	detail_toggle.text = "结构刻线"
	detail_toggle.button_pressed = true
	detail_toggle.toggled.connect(func(value: bool): shrine.details.visible = value; tree.details.visible = value)
	row.add_child(detail_toggle)
	var label := Label.new()
	label.text = "线宽"
	row.add_child(label)
	line_slider = HSlider.new()
	line_slider.custom_minimum_size.x = 115
	line_slider.min_value = .8
	line_slider.max_value = 3
	line_slider.step = .1
	line_slider.value_changed.connect(func(value: float): palette.outline_pixels = value; palette.tree_outline_pixels = value*1.13)
	row.add_child(line_slider)
	for entry in [["灰石","architecture_front"],["屋面","roof"],["墨线","ink"]]:
		var text := Label.new()
		text.text = entry[0]
		row.add_child(text)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(32,26)
		picker.edit_alpha = false
		var property: String = entry[1]
		picker.color_changed.connect(func(value: Color): palette.set(property,value); palette.tree_ink = palette.ink)
		_pickers[property] = picker
		row.add_child(picker)
	var lighting_row := HBoxContainer.new()
	lighting_row.add_theme_constant_override("separation",18)
	footer.add_child(lighting_row)
	lighting_toggle = CheckButton.new()
	lighting_toggle.text = "新版配色／实际受光"
	lighting_toggle.button_pressed = true
	lighting_toggle.toggled.connect(set_lighting_enabled)
	lighting_row.add_child(lighting_toggle)
	sky_toggle = CheckButton.new()
	sky_toggle.text = "天空与环境光"
	sky_toggle.button_pressed = true
	sky_toggle.toggled.connect(func(_value: bool): _update_environment())
	lighting_row.add_child(sky_toggle)
	rim_toggle = CheckButton.new()
	rim_toggle.text = "冷色轮廓光"
	rim_toggle.button_pressed = true
	rim_toggle.toggled.connect(func(value: bool): rim_light.visible = value)
	lighting_row.add_child(rim_toggle)
	glow_toggle = CheckButton.new()
	glow_toggle.text = "灯火微辉光"
	glow_toggle.button_pressed = true
	glow_toggle.toggled.connect(func(_value: bool): _update_environment())
	lighting_row.add_child(glow_toggle)
	var exposure_label := Label.new()
	exposure_label.text = "曝光"
	lighting_row.add_child(exposure_label)
	exposure_slider = HSlider.new()
	exposure_slider.custom_minimum_size.x = 120
	exposure_slider.min_value = .6
	exposure_slider.max_value = 1.6
	exposure_slider.step = .05
	exposure_slider.value = 1.0
	exposure_slider.value_changed.connect(func(_value: float): _update_environment())
	lighting_row.add_child(exposure_slider)
	var roof_label := Label.new()
	roof_label.text = "屋面受光"
	lighting_row.add_child(roof_label)
	roof_response_slider = HSlider.new()
	roof_response_slider.custom_minimum_size.x = 100
	roof_response_slider.min_value = 0.0
	roof_response_slider.max_value = 1.5
	roof_response_slider.step = .05
	roof_response_slider.value_changed.connect(func(value: float): palette.roof_light_response = value)
	lighting_row.add_child(roof_response_slider)
	var hint := Label.new()
	hint.text = "左键转看／滚轮缩放｜关闭新版可对比原配色与固定染光 · 天空环境光＋主光＋冷边光＋前补光＋龛内灯"
	hint.add_theme_font_size_override("font_size",14)
	hint.add_theme_color_override("font_color",Color("a3b6b2"))
	footer.add_child(hint)


func _margin(parent: Node, horizontal: int, vertical: int) -> MarginContainer:
	var node := MarginContainer.new()
	for edge in ["left","right"]: node.add_theme_constant_override("margin_"+edge,horizontal)
	for edge in ["top","bottom"]: node.add_theme_constant_override("margin_"+edge,vertical)
	parent.add_child(node)
	return node


func _build_world() -> void:
	var world := Node3D.new()
	world_root = world
	viewport.add_child(world)
	var settings := WorldEnvironment.new()
	_environment = Environment.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = preload("res://assets/expedition/sky/mochi_twilight.svg")
	_sky = Sky.new()
	_sky.sky_material = panorama
	_sky.radiance_size = Sky.RADIANCE_SIZE_256
	_environment.sky = _sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_energy = .16
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_environment.glow_intensity = .18
	_environment.glow_strength = .7
	_environment.glow_hdr_threshold = 1.4
	settings.environment = _environment
	world.add_child(settings)
	_lights = Node3D.new()
	_lights.name = "NativeStylizedLights"
	world.add_child(_lights)
	main_light = _directional("MoonKey",Color("fff0d9"),1.15,Vector3(-48,-32,0),true)
	rim_light = _directional("TealRim",Color("81c3d0"),.38,Vector3(-25,145,0),true)
	fill_light = _directional("BlueFill",Color("a7c1cf"),.14,Vector3(-22,25,0),false)
	lamp_light = OmniLight3D.new()
	lamp_light.name = "NicheLantern"
	lamp_light.light_color = Color("ffbb72")
	lamp_light.light_energy = .85
	lamp_light.omni_range = .90
	lamp_light.omni_attenuation = 1.25
	lamp_light.shadow_enabled = true
	lamp_light.shadow_bias = .015
	lamp_light.shadow_normal_bias = .20
	_lights.add_child(lamp_light)
	camera = Camera3D.new()
	camera.current = true
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.fov = 25
	world.add_child(camera)
	style.camera = camera
	_apply_camera()
	stage = style.mesh(world,TypeMeshes.beveled_box(Vector3(4.4,.09,2.6),.02),Vector3(0,-.045,0),"stone",.45)
	shrine = SHRINE.new()
	shrine.name = "QuestionShrine"
	world.add_child(shrine)
	shrine.setup(style)
	shrine.set_scene_lighting(true)
	tree = TREE.new()
	tree.position = Vector3(-1.35,0,-.18)
	tree.scale = Vector3.ONE*.78
	world.add_child(tree)
	tree.setup(style,camera)
	tree.visible = false
	style.refresh_outlines()
	_update_environment()


func _directional(label: String, tint: Color, energy: float, angles: Vector3, shadows: bool) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = label
	light.light_color = tint
	light.light_energy = energy
	light.rotation_degrees = angles
	light.shadow_enabled = shadows
	light.directional_shadow_max_distance = 20
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.shadow_bias = .06
	light.shadow_normal_bias = 1.5
	_lights.add_child(light)
	return light


func set_lighting_enabled(value: bool) -> void:
	style.set_scene_lighting(value)
	shrine.set_scene_lighting(value)
	_lights.visible = value
	var source: ExpeditionFlatPalette = PALETTE if value else BASELINE_PALETTE
	palette.set_block_signals(true)
	for property in source.get_property_list():
		if property.type==TYPE_COLOR or property.type==TYPE_FLOAT:
			palette.set(property.name,source.get(property.name))
	palette.set_block_signals(false)
	palette.emit_changed()
	_update_environment()


func _update_environment() -> void:
	if _environment==null: return
	var lit := lighting_toggle.button_pressed
	_environment.background_mode = Environment.BG_SKY if lit and sky_toggle.button_pressed else Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if lit and sky_toggle.button_pressed else Environment.AMBIENT_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC if lit else Environment.TONE_MAPPER_LINEAR
	_environment.tonemap_exposure = exposure_slider.value if lit else 1.0
	_environment.glow_enabled = lit and glow_toggle.button_pressed


func set_mode(index: int) -> void:
	tree.visible = index==1
	shrine.position = Vector3(.65,0,.04) if index==1 else Vector3.ZERO
	_look = Vector3(0,.70,0) if index==0 else Vector3(-.15,.65,0)
	_view_size = 2.45 if index==0 else 3.2
	_yaw = 18
	_pitch = 43
	_update_light()
	_apply_camera()


func _resize() -> void:
	if viewport==null or camera==null: return
	viewport.size = Vector2i(maxi(16,int(area.size.x)),maxi(16,int(area.size.y)))
	_apply_camera()


func _apply_camera() -> void:
	if camera==null: return
	var pitch := deg_to_rad(_pitch)
	var yaw := deg_to_rad(_yaw)
	var distance := _view_size/(2*tan(deg_to_rad(camera.fov*.5)))
	camera.position = _look+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(_look,Vector3.UP)
	if tree!=null: tree.sync_camera()
	style.refresh_outlines()


func _update_light() -> void:
	if shrine!=null:
		style.set_fire_light(shrine.lamp.global_position+Vector3(0,.055,.02),palette.fire_light,.65 if light_toggle.button_pressed else 0,.72)
		shrine.sync_light()
		lamp_light.global_position = shrine.lamp.global_position+Vector3(0,.07,.09)
		lamp_light.visible = light_toggle.button_pressed


func _refresh_palette() -> void:
	_environment.background_color = palette.background
	RenderingServer.set_default_clear_color(palette.background)
	for property in _pickers: _pickers[property].color = palette.get(property)
	line_slider.set_value_no_signal(palette.outline_pixels)
	roof_response_slider.set_value_no_signal(palette.roof_light_response)
	_update_light()


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: _dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_view_size = clampf(_view_size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),1.8,5.0)
			_apply_camera()
	elif event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x*.4
		_pitch = clampf(_pitch+event.relative.y*.22,18,65)
		_apply_camera()
