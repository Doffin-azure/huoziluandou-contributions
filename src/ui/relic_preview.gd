extends Control
## A real mesh preview. The viewport renders only on layout or interaction.
const Specimen := preload("res://src/ui/object_stage/relic_specimen.gd")
var relic_id := ""
var viewport: SubViewport
var specimen: Node3D
var _camera: Camera3D
var _pivot: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_meta("relic_id", relic_id)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = RelicArt.AMBIENT_COLOR
	environment.ambient_light_energy = RelicArt.AMBIENT_ENERGY
	var backdrop := WorldEnvironment.new()
	backdrop.environment = environment
	world.add_child(backdrop)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -34, -12)
	sun.light_color = RelicArt.SUN_COLOR
	sun.light_energy = RelicArt.SUN_ENERGY
	world.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 4, 4)
	fill.light_color = RelicArt.FILL_COLOR
	fill.light_energy = RelicArt.FILL_ENERGY
	fill.omni_range = 12
	world.add_child(fill)
	_pivot = Node3D.new()
	world.add_child(_pivot)
	specimen = Specimen.build(world, relic_id, 0)
	_pivot.add_child(specimen)
	var bounds := Specimen.bounds_of(specimen)
	var center := bounds.get_center()
	specimen.position = -center
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.position = Vector3(2.8, 4.8, 6.8).normalized() * 8.0
	world.add_child(_camera)
	_camera.look_at(Vector3.ZERO)
	var in_view: AABB = _camera.global_transform.affine_inverse() * AABB(bounds.position - center, bounds.size)
	_camera.size = maxf(in_view.size.x, in_view.size.y) * 1.17
	_camera.current = true
	var picture := TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_resize_preview)
	_resize_preview()
	# Allow resources to upload before the retained first frame.
	_refresh.call_deferred()


func _resize_preview() -> void:
	var extent := clampi(int(minf(size.x, size.y) * 2), 128, 512)
	viewport.size = Vector2i.ONE * extent
	_refresh()


func highlight(active: bool) -> void:
	if _pivot == null: return
	_pivot.rotation.y = -0.16 if active else 0.0
	_refresh()


func _refresh() -> void:
	if viewport != null: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
