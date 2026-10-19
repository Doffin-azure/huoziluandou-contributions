extends Control
## Reusable title scenery. Owns rendering and camera motion, never gameplay or menus.
const STAGE := preload("res://src/title/courtyard/courtyard_stage.tscn")
const ENTRY_SECONDS := 2.0
var stage: Node3D
var viewport: SubViewport
var _scrim: ColorRect
var follow_settings := true
var max_render_size := Vector2i(1920, 1080)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.name = "CourtyardWorld"
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X if RenderingServer.get_current_rendering_method() == "mobile" else Viewport.MSAA_4X
	if RenderingServer.get_current_rendering_method() == "mobile": max_render_size = Vector2i(1280, 720)
	viewport.positional_shadow_atlas_size = 2048
	add_child(viewport)
	stage = STAGE.instantiate()
	viewport.add_child(stage)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	_scrim = ColorRect.new()
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scrim_material := ShaderMaterial.new()
	scrim_material.shader = preload("res://src/title/courtyard/menu_scrim.gdshader")
	_scrim.material = scrim_material
	add_child(_scrim)
	if follow_settings:
		Settings.changed.connect(_apply_preferences)
		_apply_preferences()
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	if viewport == null: return
	var pixels := Vector2(get_viewport().get_texture().get_size())
	var factor := 1.0
	if max_render_size.x > 0 and max_render_size.y > 0:
		factor = minf(1.0, minf(max_render_size.x / pixels.x, max_render_size.y / pixels.y))
	viewport.size = Vector2i(maxi(320, int(pixels.x * factor)), maxi(180, int(pixels.y * factor)))


func enter() -> float:
	_scrim.hide()
	if Settings.reduced_motion:
		stage.reset_camera(1.0)
		return 0.05
	stage.show_detail(true)
	return ENTRY_SECONDS


func reset_camera() -> void:
	stage.reset_camera()
	_scrim.show()


func _apply_preferences() -> void:
	stage.atmosphere.set_motion(not Settings.reduced_motion)
	stage.atmosphere.petals.visible = not Settings.reduced_motion


func _exit_tree() -> void:
	if Settings.changed.is_connected(_apply_preferences):
		Settings.changed.disconnect(_apply_preferences)
