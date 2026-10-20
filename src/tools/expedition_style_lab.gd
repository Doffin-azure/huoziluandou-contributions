extends Control
## Isolated playable art fixture. Reuses TypeMeshes and the existing map's gate geometry.
const DEFAULT_PALETTE = preload("res://assets/expedition/palettes/mochi_flat.tres")
const ASH_PALETTE = preload("res://assets/expedition/palettes/ash_flat.tres")
const FIRE = preload("res://src/map/expedition_stylized_fire.gd")
const PITCH := 43.0
const YAW := 12.0
@export var palette: ExpeditionFlatPalette
var style: ExpeditionFlatStyle
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var chest: Node3D
var gate: Node3D
var body_mesh: MeshInstance3D
var lid_mesh: MeshInstance3D
var floor_mesh: MeshInstance3D
var guides: MeshInstance3D
var map_area: Control
var environment: Environment
var model_select: OptionButton
var preset_select: OptionButton
var perspective_toggle: CheckButton
var style_toggle: CheckButton
var guide_toggle: CheckButton
var fire: Node3D
var fire_toggle: CheckButton
var flicker_toggle: CheckButton
var glow_toggle: CheckButton
var _pickers: Dictionary = {}
var _caption: Label
var _outline_slider: HSlider
var _look := Vector3(1.5, 0.0, 1.5)
var _view_size := 2.95
var _dragging := false
var _fire_energy_slider: HSlider
var _fire_radius_slider: HSlider
var _cast_shadow: MeshInstance3D


func _ready() -> void:
	palette = (palette if palette != null else DEFAULT_PALETTE).duplicate(true)
	style = ExpeditionFlatStyle.new(palette)
	_build_ui()
	_build_world()
	palette.changed.connect(_palette_changed)
	_palette_changed()
	_resize.call_deferred()


func _exit_tree() -> void:
	if style != null: style.dispose()


func _build_ui() -> void:
	var theme_value := Theme.new()
	theme_value.default_font = Ink.serif
	theme_value.default_font_size = 16
	theme = theme_value
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var header := MarginContainer.new()
	for edge in ["left","right"]: header.add_theme_constant_override("margin_" + edge, 28)
	header.add_theme_constant_override("margin_top", 12)
	header.add_theme_constant_override("margin_bottom", 8)
	column.add_child(header)
	var titles := VBoxContainer.new()
	header.add_child(titles)
	var title := Label.new()
	title.text = "墨池 · 3×3 平涂样板"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("ded4b7"))
	titles.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "左键摆放字匣　中键拖看　滚轮缩放"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("9dac99"))
	titles.add_child(subtitle)
	map_area = Control.new()
	map_area.custom_minimum_size = Vector2(320, 360)
	map_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_area.mouse_filter = Control.MOUSE_FILTER_STOP
	map_area.gui_input.connect(_map_input)
	map_area.resized.connect(_resize)
	column.add_child(map_area)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_8X
	map_area.add_child(viewport)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_area.add_child(display)
	var footer := MarginContainer.new()
	for edge in ["left","right"]: footer.add_theme_constant_override("margin_" + edge, 24)
	footer.add_theme_constant_override("margin_top", 8)
	footer.add_theme_constant_override("margin_bottom", 10)
	column.add_child(footer)
	var tools := VBoxContainer.new()
	footer.add_child(tools)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	tools.add_child(row)
	model_select = OptionButton.new()
	model_select.add_item("字匣")
	model_select.add_item("复用旧闸门")
	model_select.item_selected.connect(show_model)
	row.add_child(model_select)
	style_toggle = CheckButton.new()
	style_toggle.text = "平涂描线"
	style_toggle.button_pressed = true
	style_toggle.toggled.connect(func(value: bool): style.set_enabled(value))
	row.add_child(style_toggle)
	guide_toggle = CheckButton.new()
	guide_toggle.text = "对齐线"
	guide_toggle.toggled.connect(func(value: bool): guides.visible = value)
	row.add_child(guide_toggle)
	perspective_toggle = CheckButton.new()
	perspective_toggle.text = "轻透视"
	perspective_toggle.toggled.connect(func(_value: bool): _apply_camera())
	row.add_child(perspective_toggle)
	var reset := Button.new()
	reset.text = "复位"
	reset.pressed.connect(reset_camera)
	row.add_child(reset)
	preset_select = OptionButton.new()
	preset_select.add_item("墨绿配色")
	preset_select.add_item("灰青配色")
	preset_select.item_selected.connect(set_preset)
	row.add_child(preset_select)
	for item in [["保存配色", save_palette], ["截图", save_screenshot]]:
		var button := Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		row.add_child(button)
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 10)
	tools.add_child(colors)
	for entry in [["底色","background"],["石面","stone_top"],["箱身","wood_front"],["箱盖","wood_top"],["锁扣","bronze"],["描线","ink"]]:
		var label := Label.new()
		label.text = entry[0]
		colors.add_child(label)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(34, 27)
		picker.edit_alpha = false
		var property: String = entry[1]
		picker.color_changed.connect(func(color: Color): palette.set(property, color))
		colors.add_child(picker)
		_pickers[property] = picker
	var line_label := Label.new()
	line_label.text = "线宽"
	colors.add_child(line_label)
	_outline_slider = HSlider.new()
	_outline_slider.custom_minimum_size.x = 110
	_outline_slider.min_value = 0.0
	_outline_slider.max_value = 4.0
	_outline_slider.step = 0.1
	_outline_slider.value_changed.connect(func(value: float): palette.outline_pixels = value)
	colors.add_child(_outline_slider)
	var fire_tools := HBoxContainer.new()
	fire_tools.add_theme_constant_override("separation", 10)
	tools.add_child(fire_tools)
	fire_toggle = CheckButton.new()
	fire_toggle.text = "点火"
	fire_toggle.button_pressed = true
	fire_toggle.toggled.connect(func(value: bool): fire.set_enabled(value); _update_shadow_geometry())
	fire_tools.add_child(fire_toggle)
	flicker_toggle = CheckButton.new()
	flicker_toggle.text = "跳动"
	flicker_toggle.button_pressed = true
	flicker_toggle.toggled.connect(func(value: bool): fire.set_animation(value))
	fire_tools.add_child(flicker_toggle)
	glow_toggle = CheckButton.new()
	glow_toggle.text = "柔光"
	glow_toggle.button_pressed = true
	glow_toggle.toggled.connect(func(value: bool): fire.set_glow(value))
	fire_tools.add_child(glow_toggle)
	for entry in [["焰色","fire_outer"],["光色","fire_light"]]:
		var label := Label.new()
		label.text = entry[0]
		fire_tools.add_child(label)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(34,27)
		picker.edit_alpha = false
		var property: String = entry[1]
		picker.color_changed.connect(func(color: Color): palette.set(property,color))
		fire_tools.add_child(picker)
		_pickers[property] = picker
	for entry in [["照明",0.0,2.0,"fire_energy"],["范围",.7,3.2,"fire_radius"]]:
		var label := Label.new()
		label.text = entry[0]
		fire_tools.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 90
		slider.min_value = entry[1]
		slider.max_value = entry[2]
		slider.step = .05
		var property: String = entry[3]
		slider.value_changed.connect(func(value: float): palette.set(property,value))
		fire_tools.add_child(slider)
		if property=="fire_energy": _fire_energy_slider = slider
		else: _fire_radius_slider = slider
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 13)
	_caption.add_theme_color_override("font_color", Color("9dac99"))
	_caption.text = "同一套3D几何 · 可调面色与轮廓 · 配色修改实时生效"
	tools.add_child(_caption)


func _build_world() -> void:
	world = Node3D.new()
	viewport.add_child(world)
	var settings := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("82958b")
	environment.ambient_light_energy = 0.5
	settings.environment = environment
	world.add_child(settings)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.0
	world.add_child(light)
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.05
	camera.far = 60.0
	world.add_child(camera)
	style.camera = camera
	floor_mesh = style.mesh(world, TypeMeshes.beveled_box(Vector3(3,.075,3),.006), Vector3(1.5,-.0375,1.5), "stone", 0.6)
	_floor_patch(Vector2(1.5,.455), Vector2(3,.91), "slab_light")
	_floor_patch(Vector2(.84,2.48), Vector2(1.68,1.04), "slab_dark")
	_lines([Vector3(0,.004,.91),Vector3(3,.004,.91),Vector3(0,.004,1.96),Vector3(3,.004,1.96),Vector3(1.68,.004,1.96),Vector3(1.68,.004,3)], style.solid_material("joint"))
	chest = Node3D.new()
	chest.name = "TypeChest"
	chest.position = Vector3(1.55,0,1.52)
	world.add_child(chest)
	# The existing shared beveled-box generator supplies every part, not an imported illustration.
	var body_shape := TypeMeshes.beveled_box(Vector3(.96,.4,.57), .014)
	body_shape = _taper_body(body_shape)
	body_mesh = style.mesh(chest, body_shape, Vector3(0,.2,0), "wood")
	lid_mesh = style.mesh(chest, TypeMeshes.beveled_box(Vector3(1.045,.085,.66),.018), Vector3(0,.4425,0), "wood")
	style.mesh(chest, TypeMeshes.beveled_box(Vector3(.13,.168,.025),.007), Vector3(0,.361,.339), "bronze", .55)
	var hole := MeshInstance3D.new()
	hole.mesh = TypeMeshes.beveled_box(Vector3(.026,.042,.003),0)
	hole.position = Vector3(0,.349,.353)
	hole.material_override = style.solid_material("ink")
	chest.add_child(hole)
	_shadow(chest)
	gate = Node3D.new()
	gate.name = "ExistingGate"
	gate.position = Vector3(1.5,0,1.5)
	world.add_child(gate)
	var old_factory := ExpeditionMapProps.new(PITCH)
	old_factory.mechanism(gate,{"g":"闸","kind":"gate"},false,true)
	style.apply_legacy(gate)
	gate.visible = false
	var points: Array[Vector3] = []
	for n in 4:
		points.append_array([Vector3(n,.009,0),Vector3(n,.009,3),Vector3(0,.009,n),Vector3(3,.009,n)])
	guides = _lines(points,style.solid_material("bronze"))
	guides.visible = false
	fire = FIRE.new()
	fire.name = "StylizedBrazier"
	fire.position = Vector3(.70,0,2.03)
	world.add_child(fire)
	fire.setup(style,camera,environment)
	_update_shadow_geometry()


func _taper_body(source: ArrayMesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0).duplicate(true)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in vertices.size():
		# x' = x*(.9375 + .3125*y): .90 width at the foot, .96 at the top.
		var factor := .9375 + .3125 * vertices[i].y
		var normal := normals[i]
		normals[i] = Vector3(normal.x/factor,normal.y-.3125*vertices[i].x*normal.x/factor,normal.z).normalized()
		vertices[i].x *= factor
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result


func _floor_patch(center: Vector2, dimensions: Vector2, role: String) -> void:
	var plane := PlaneMesh.new()
	plane.size = dimensions
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.position = Vector3(center.x,.001,center.y)
	node.material_override = style.solid_material(role)
	world.add_child(node)


func _lines(points: Array[Vector3], material: Material) -> MeshInstance3D:
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for point in points: lines.surface_add_vertex(point)
	lines.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = lines
	node.material_override = material
	world.add_child(node)
	return node


func _shadow(parent: Node3D) -> void:
	var corners := [Vector2(-.5225,-.33),Vector2(.5225,-.33),Vector2(.5225,.33),Vector2(-.5225,.33)]
	var points := PackedVector2Array()
	for point: Vector2 in corners:
		points.append(point)
		points.append(point+Vector2(.485*.55,.485*.33))
	_cast_shadow = _ground_polygon(parent,Geometry2D.convex_hull(points),style.solid_material("shadow"),.004)
	_ground_polygon(parent,PackedVector2Array([Vector2(-.45,-.285),Vector2(.45,-.285),Vector2(.45,.285),Vector2(-.45,.285)]),style.solid_material("contact"),.005)


func _ground_polygon(parent: Node3D, points: PackedVector2Array, material: Material, height: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _polygon_mesh(points,height)
	node.material_override = material
	parent.add_child(node)
	return node


func _polygon_mesh(points: PackedVector2Array, height: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(points)
	for index in indices:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(points[index].x,height,points[index].y))
	return surface.commit()


func _update_shadow_geometry() -> void:
	if _cast_shadow==null: return
	var points := PackedVector2Array()
	var center := Vector2(chest.position.x,chest.position.z)
	for point in [Vector2(-.5225,-.33),Vector2(.5225,-.33),Vector2(.5225,.33),Vector2(-.5225,.33)]:
		points.append(center+point)
		if fire!=null and fire.enabled:
			var source := Vector2(fire.position.x,fire.position.z)
			points.append(source+(center+point-source)*(.75/(.75-.485)))
		else: points.append(center+point+Vector2(.485*.55,.485*.33))
	var silhouette := Geometry2D.convex_hull(points)
	var clipped := Geometry2D.intersect_polygons(silhouette,PackedVector2Array([Vector2.ZERO,Vector2(3,0),Vector2(3,3),Vector2(0,3)]))
	if clipped.is_empty():
		_cast_shadow.visible = false
		return
	var local: PackedVector2Array = clipped[0]
	for i in local.size(): local[i] -= center
	_cast_shadow.mesh = _polygon_mesh(local,.004)
	_cast_shadow.visible = true


func _resize() -> void:
	if viewport == null or camera == null: return
	viewport.size = Vector2i(maxi(16,int(map_area.size.x)),maxi(16,int(map_area.size.y)))
	_apply_camera()


func _apply_camera() -> void:
	if camera == null: return
	var pitch := deg_to_rad(PITCH)
	var yaw := deg_to_rad(YAW)
	var direction := Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = _view_size
	camera.fov = 16.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if perspective_toggle.button_pressed else Camera3D.PROJECTION_ORTHOGONAL
	var distance := _view_size / (2.0 * tan(deg_to_rad(camera.fov*.5))) if perspective_toggle.button_pressed else 10.0
	camera.position = _look + direction * distance
	camera.look_at(_look, Vector3.UP)
	style.refresh_outlines()
	if fire!=null: fire.sync_camera()


func pan_by(pixels: Vector2) -> void:
	var amount := _view_size / maxf(16.0,map_area.size.y)
	var offset := (-camera.basis.x*pixels.x+camera.basis.y*pixels.y)*amount
	_look += offset
	_apply_camera()


func place_chest(point: Vector2) -> void:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	if direction.y >= -.0001: return
	var hit := origin + direction * (-origin.y/direction.y)
	if hit.x < 0 or hit.x > 3 or hit.z < 0 or hit.z > 3: return
	chest.position = Vector3(clampf(floorf(hit.x)+.5,.56,2.44),0,clampf(floorf(hit.z)+.5,.36,2.64))
	style.refresh_outlines()
	_update_shadow_geometry()


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE: _dragging = event.pressed
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and chest.visible: place_chest(event.position)
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				_view_size = clampf(_view_size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),2.2,4.6)
				_apply_camera()
	elif event is InputEventMouseMotion and _dragging: pan_by(event.relative)


func reset_camera() -> void:
	_look = Vector3(1.5,0,1.5)
	_view_size = 2.95
	chest.position = Vector3(1.55,0,1.52)
	_update_shadow_geometry()
	_apply_camera()


func show_model(index: int) -> void:
	chest.visible = index == 0
	gate.visible = index == 1
	_caption.text = "字匣：沿用项目倒角几何，平涂与描线可切换" if index==0 else "旧闸门：直接调用现有地图模型生成，再套用同一材质"


func set_preset(index: int) -> void:
	set_palette((DEFAULT_PALETTE if index==0 else ASH_PALETTE).duplicate(true))


func set_palette(value: ExpeditionFlatPalette) -> void:
	if palette.changed.is_connected(_palette_changed): palette.changed.disconnect(_palette_changed)
	palette = value
	style.set_palette(value)
	palette.changed.connect(_palette_changed)
	_palette_changed()


func _palette_changed() -> void:
	if environment == null: return
	environment.background_color = palette.background
	RenderingServer.set_default_clear_color(palette.background)
	for property in _pickers: _pickers[property].color = palette.get(property)
	_outline_slider.set_value_no_signal(palette.outline_pixels)
	_fire_energy_slider.set_value_no_signal(palette.fire_energy)
	_fire_radius_slider.set_value_no_signal(palette.fire_radius)
	if fire!=null: fire.refresh()


func save_palette() -> void:
	var path := "user://expedition_flat_palette.tres"
	var result := ResourceSaver.save(palette,path)
	_caption.text = "配色已保存：" + ProjectSettings.globalize_path(path) if result==OK else "配色保存失败"


func save_screenshot() -> void:
	await RenderingServer.frame_post_draw
	var path := "user://expedition_style_lab.png"
	var result := get_viewport().get_texture().get_image().save_png(path)
	_caption.text = "截图已保存：" + ProjectSettings.globalize_path(path) if result==OK else "截图保存失败"
