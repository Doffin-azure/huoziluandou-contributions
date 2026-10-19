extends Control
## Small art feasibility fixture, deliberately isolated from the live expedition.
const INLAY = preload("res://src/map/expedition_inlaid_glyph.gd")
const PALETTE = preload("res://assets/expedition/palettes/mochi_flat.tres")
const GLYPHS := ["泉", "纸", "焰", "炉", "桩", "障", "流", "潮", "闸"]
@export var palette_source: ExpeditionFlatPalette = PALETTE
var palette: ExpeditionFlatPalette
var style: ExpeditionFlatStyle
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var area: Control
var inscriptions: Array[Node3D] = []
var props: Node3D
var props_toggle: CheckButton
var used_toggle: CheckButton
var alias_toggle: CheckButton
var perspective_toggle: CheckButton
var title_label: Label
var tool_rows: VBoxContainer
var floor_surfaces: Array[MeshInstance3D] = []
var color_pickers: Dictionary = {}
var zoom_limits := Vector2(2.5,4.8)
var _water: MeshInstance3D
var _water_material: StandardMaterial3D
var _paper_material: StandardMaterial3D
var _flow_arrows: Node3D
var _bars: Node3D
var _spent_marks: Node3D
var _tide_warning: Node3D
var _status: Label
var _detail: Label
var _environment: Environment
var _look := Vector3(1.5, 0, 1.5)
var _view_size := 3.35
var _dragging := false
var tick := 0


func _ready() -> void:
	palette = palette_source.duplicate(true)
	style = ExpeditionFlatStyle.new(palette)
	_build_ui()
	_build_world()
	palette.changed.connect(_refresh_colors)
	_refresh_colors()
	set_tick(0)
	set_spent(false)
	_resize.call_deferred()


func _exit_tree() -> void:
	if style != null: style.dispose()
	if palette != null and palette.changed.is_connected(_refresh_colors): palette.changed.disconnect(_refresh_colors)


func _build_ui() -> void:
	var visual_theme := Theme.new()
	visual_theme.default_font = Ink.serif
	visual_theme.default_font_size = 16
	theme = visual_theme
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	var top := _margin(column, 24, 12)
	var title := Label.new()
	title_label = title
	title.text = "机关字砖 · 3×3 镶字样板"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("ded4b7"))
	top.add_child(title)
	area = Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size = Vector2(320, 360)
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
	var bottom := VBoxContainer.new()
	tool_rows = bottom
	_margin(column, 24, 10).add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bottom.add_child(row)
	props_toggle = _toggle(row, "叠放机关", true, func(value: bool): props.visible = value)
	used_toggle = _toggle(row, "消耗后", false, set_spent)
	alias_toggle = _toggle(row, "换字候选", false, set_alias)
	perspective_toggle = _toggle(row, "轻透视", true, func(_value: bool): _apply_camera())
	var step := Button.new()
	step.text = "前进1步"
	step.pressed.connect(func(): set_tick(tick + 1))
	row.add_child(step)
	var reset := Button.new()
	reset.text = "复位"
	reset.pressed.connect(reset_camera)
	row.add_child(reset)
	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 12)
	bottom.add_child(color_row)
	for entry in [["嵌字", "glyph_fill"], ["刻槽", "glyph_recess"], ["石面", "stone_top"], ["水色", "water"]]:
		var label := Label.new()
		label.text = entry[0]
		color_row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(32, 26)
		picker.edit_alpha = false
		var property: String = entry[1]
		picker.color = palette.get(property)
		picker.color_changed.connect(func(value: Color): palette.set(property, value))
		color_pickers[property] = picker
		color_row.add_child(picker)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("ded4b7"))
	color_row.add_child(_status)
	_detail = Label.new()
	_detail.text = "左键查看字义　中键拖看　滚轮缩放｜浅渠与机关为造型试验；换字仅预览"
	_detail.add_theme_font_size_override("font_size", 14)
	_detail.add_theme_color_override("font_color", Color("9dac99"))
	bottom.add_child(_detail)


func _margin(parent: Node, horizontal: int, vertical: int) -> MarginContainer:
	var result := MarginContainer.new()
	for edge in ["left", "right"]: result.add_theme_constant_override("margin_" + edge, horizontal)
	for edge in ["top", "bottom"]: result.add_theme_constant_override("margin_" + edge, vertical)
	parent.add_child(result)
	return result


func _toggle(parent: Node, text: String, initial: bool, callback: Callable) -> CheckButton:
	var result := CheckButton.new()
	result.text = text
	result.button_pressed = initial
	result.toggled.connect(callback)
	parent.add_child(result)
	return result


func _box(parent: Node3D, center: Vector3, dimensions: Vector3, role := "stone", outline := .45) -> MeshInstance3D:
	return style.mesh(parent, TypeMeshes.beveled_box(dimensions, .008), center, role, outline)


func _build_world() -> void:
	world = Node3D.new()
	viewport.add_child(world)
	var settings := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	settings.environment = _environment
	world.add_child(settings)
	camera = Camera3D.new()
	camera.current = true
	camera.near = .05
	camera.far = 60
	world.add_child(camera)
	style.camera = camera
	# Continuous platform; a small reserved trough is genuine geometry, not a blue tile.
	floor_surfaces.append(_box(world, Vector3(1.5,-.06,1.0),Vector3(3,.12,2),"stone",.65))
	floor_surfaces.append(_box(world, Vector3(.5,-.06,2.5),Vector3(1,.12,1),"stone",.65))
	floor_surfaces.append(_box(world, Vector3(2.5,-.06,2.5),Vector3(1,.12,1),"stone",.65))
	_box(world, Vector3(1.5,-.14,2.5),Vector3(1,.04,1),"stone",.65)
	# The central inscription stone remains visible above both illustrative water levels.
	_box(world, Vector3(1.5,-.034,2.60),Vector3(.62,.14,.64),"stone",.45)
	_box(world, Vector3(1.5,-.034,2.06),Vector3(1,.14,.12),"stone",.4)
	for index in GLYPHS.size():
		var mark := INLAY.new()
		mark.position = Vector3(index%3+.5, .0, index/3+.65)
		if index==7: mark.position.y = .038
		world.add_child(mark)
		mark.setup(GLYPHS[index],palette,Ink.serif)
		inscriptions.append(mark)
	# Only occasional long joints; inscriptions do not create nine boxed UI cells.
	_strip(world, Vector3(1.5,.002,.97),Vector2(3,.008),style.solid_material("joint"))
	_strip(world, Vector3(.76,.002,1.98),Vector2(1.52,.008),style.solid_material("joint"))
	props = Node3D.new()
	world.add_child(props)
	_build_props()
	_water_material = StandardMaterial3D.new()
	_water_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water_material.roughness = 1
	_water = _strip(props,Vector3(1.5,-.09,2.5),Vector2(.98,.98),_water_material)
	_tide_warning = Node3D.new()
	props.add_child(_tide_warning)
	for sx in [-1,1]:
		for sz in [-1,1]:
			_box(_tide_warning,Vector3(1.5+sx*.29,.052,2.60+sz*.29),Vector3(.09,.008,.014),"seal",0)
			_box(_tide_warning,Vector3(1.5+sx*.33,.052,2.60+sz*.25),Vector3(.014,.008,.09),"seal",0)
	# Recesses and arrows occupy the rear margin so the character keeps its own footprint.
	_flow_arrows = Node3D.new()
	props.add_child(_flow_arrows)
	for x in [.24,.48,.72]:
		for sign_value in [-1,1]:
			var bar := _box(_flow_arrows,Vector3(x,.008,2.17+sign_value*.035),Vector3(.12,.009,.016),"bronze",0)
			bar.rotation.y = sign_value*-.55
	_bars = Node3D.new()
	_bars.position = Vector3(2.5,0,2.28)
	_bars.scale.y = .65
	props.add_child(_bars)
	for x in [-.17,0,.17]: _box(_bars,Vector3(x,.21,0),Vector3(.038,.40,.035),"bronze",.4)
	_spent_marks = Node3D.new()
	world.add_child(_spent_marks)
	for index in [0,3,4,6]:
		var line := _box(_spent_marks,Vector3(index%3+.76,.012,index/3+.82),Vector3(.12,.01,.016),"stone",0)
		line.rotation.y = -.7
	_apply_camera()


func _strip(parent: Node3D, center: Vector3, dimensions: Vector2, material: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = dimensions
	result.mesh = mesh
	result.position = center
	result.material_override = material
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(result)
	return result


func _build_props() -> void:
	# Restrained silhouettes, not finished production assets.
	for index in [0,2,3,4,5,8]:
		var holder := Node3D.new()
		holder.position = Vector3(index%3+.5,0,index/3+.25)
		holder.scale.y = .65
		props.add_child(holder)
		var center := Vector3.ZERO
		match index:
			0:
				_box(holder,center+Vector3(0,.025,0),Vector3(.42,.05,.22),"bronze")
				_box(holder,center+Vector3(0,.055,0),Vector3(.31,.02,.12),"ink",0)
			2:
				_box(holder,center+Vector3(0,.015,0),Vector3(.36,.025,.18),"ink",0)
				for x in [-.10,0,.10]: _box(holder,center+Vector3(x,.034,0),Vector3(.028,.012,.12),"seal",0)
			3:
				_box(holder,center+Vector3(0,.15,0),Vector3(.34,.30,.24),"stone")
				_box(holder,center+Vector3(0,.33,0),Vector3(.40,.06,.29),"bronze")
				_box(holder,center+Vector3(0,.10,.126),Vector3(.16,.14,.008),"ink",0)
			4:
				_box(holder,center+Vector3(0,.16,0),Vector3(.18,.32,.18),"stone")
				_box(holder,center+Vector3(0,.34,0),Vector3(.25,.05,.24),"bronze")
			5:
				var fragment := _box(holder,center+Vector3(-.05,.15,0),Vector3(.40,.30,.15),"stone")
				fragment.rotation.z = -.14
				_box(holder,center+Vector3(-.05,.19,.09),Vector3(.26,.035,.009),"seal",0)
			8:
				for x in [-.30,.30]: _box(holder,center+Vector3(x,.18,.04),Vector3(.10,.36,.16),"stone")
				_box(holder,center+Vector3(0,.38,.04),Vector3(.72,.06,.17),"bronze")
	# Paper stays visibly distinct from an inscription stone.
	var paper := StandardMaterial3D.new()
	_paper_material = paper
	paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paper.albedo_color = Color("bfb892")
	var sheet := _strip(props,Vector3(1.5,.004,.20),Vector2(.48,.24),paper)
	sheet.rotation.y = .12
	_strip(props,Vector3(1.5,.006,.12),Vector2(.46,.07),style.solid_material("shadow"))


func set_tick(value: int) -> void:
	tick = maxi(0,value)
	var tide: Dictionary = MapGen.THEMES["潮汐渠"].mech[1]
	var gate: Dictionary = MapGen.THEMES["雷池"].mech[0]
	_water.position.y = .018 if MapGen.shut(tide,tick) else -.09
	_tide_warning.visible = MapGen.shut(tide,tick)
	_bars.scale.y = .65 if MapGen.shut(gate,tick) else .052
	_update_status()


func _update_status() -> void:
	var tide: Dictionary = MapGen.THEMES["潮汐渠"].mech[1]
	var gate: Dictionary = MapGen.THEMES["雷池"].mech[0]
	_status.text = "第%d步 · %s · 电闸%s" % [tick,"涨潮／禁行" if MapGen.shut(tide,tick) else "退潮／可行","关闭" if MapGen.shut(gate,tick) else "开启"]


func set_spent(value: bool) -> void:
	# Simplified baseline uses: upgrades may restore a second furnace/pylon use in the live map.
	for index in [0,3,4,6]: inscriptions[index].set_spent(value)
	_flow_arrows.visible = not value
	_spent_marks.visible = value


func set_alias(value: bool) -> void:
	for entry in [[2,"灼"],[4,"镇"],[7,"渡"]]:
		inscriptions[entry[0]].set_glyph(entry[1] if value else GLYPHS[entry[0]])
	_detail.text = "换字候选：焰→灼（灼烧地面），桩→镇（镇住首领），潮→渡（周期渡口）；玩法中的字尚未修改" if value else "左键查看字义　中键拖看　滚轮缩放｜浅渠与机关为造型试验；换字仅预览"


func _refresh_colors() -> void:
	_environment.background_color = palette.background
	RenderingServer.set_default_clear_color(palette.background)
	_water_material.albedo_color = palette.water
	_paper_material.albedo_color = palette.glyph_fill.lightened(.06)
	for property in color_pickers: color_pickers[property].color = palette.get(property)


func reset_camera() -> void:
	_look = Vector3(1.5,0,1.5)
	_view_size = 3.35
	set_tick(0)
	_apply_camera()


func _resize() -> void:
	if viewport==null or camera==null: return
	viewport.size = Vector2i(maxi(16,int(area.size.x)),maxi(16,int(area.size.y)))
	_apply_camera()


func _apply_camera() -> void:
	if camera==null: return
	var pitch := deg_to_rad(43.0)
	var yaw := deg_to_rad(12.0)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = _view_size
	camera.fov = 16
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if perspective_toggle.button_pressed else Camera3D.PROJECTION_ORTHOGONAL
	var distance := _view_size/(2*tan(deg_to_rad(8.0))) if perspective_toggle.button_pressed else 10.0
	camera.position = _look + Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(_look,Vector3.UP)
	style.refresh_outlines()


func pick_cell(point: Vector2) -> int:
	var origin := camera.project_ray_origin(point)
	var ray := camera.project_ray_normal(point)
	if ray.y>=-.0001: return -1
	var hit := origin+ray*(-origin.y/ray.y)
	if hit.x<0 or hit.x>=3 or hit.z<0 or hit.z>=3: return -1
	return int(floorf(hit.z))*3+int(floorf(hit.x))


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE: _dragging = event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			var index := pick_cell(event.position)
			if index>=0:
				var glyph: String = GLYPHS[index]
				var description := "墨障：消耗墨清除；墨不够则消耗气血"
				for data: Dictionary in MapGen.THEMES.values():
					for mc: Dictionary in data.mech:
						if mc.g==glyph: description = mc.desc
				_detail.text = "【%s】%s" % [inscriptions[index].glyph,description]
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_view_size = clampf(_view_size*(.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),zoom_limits.x,zoom_limits.y)
			_apply_camera()
	elif event is InputEventMouseMotion and _dragging:
		_look += (-camera.basis.x*event.relative.x+camera.basis.y*event.relative.y)*_view_size/maxf(16,area.size.y)
		_apply_camera()
