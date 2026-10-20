extends Control
## Reusable title scenery. Owns rendering and camera motion, never gameplay or menus.
const STAGE := preload("res://src/title/courtyard/courtyard_stage.tscn")
const ENTRY_SECONDS := 2.0
var stage: Node3D
var viewport: SubViewport
var _scrim: ColorRect
var follow_settings := true
var max_render_size := Vector2i(1920, 1080)
# Debug-only override exercises the APK render budget on a desktop; it is not a device emulator.
var mobile_quality := OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or (OS.is_debug_build() and OS.get_cmdline_user_args().has("--mobile-budget"))
var _render_clock := 0.0
var _active := true
var _mirror_update_mode := SubViewport.UPDATE_ALWAYS


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.name = "CourtyardWorld"
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if mobile_quality else SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED if mobile_quality else Viewport.MSAA_4X
	viewport.positional_shadow_atlas_size = 0 if mobile_quality else 2048
	if RenderingServer.get_current_rendering_method() == "mobile": max_render_size = Vector2i(1280, 720)
	add_child(viewport)
	stage = STAGE.instantiate()
	stage.mobile_quality = mobile_quality
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
	set_process(mobile_quality and not Settings.reduced_motion)


func _process(delta: float) -> void:
	# 背景单独以 30 帧更新；菜单和触摸输入继续按主视口帧率响应。
	_render_clock += delta
	if _render_clock >= 1.0 / 30.0:
		_render_clock = fmod(_render_clock, 1.0 / 30.0)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _layout() -> void:
	if viewport == null: return
	var pixels := Vector2(get_viewport().get_texture().get_size())
	var factor := 1.0
	var limit := max_render_size
	if mobile_quality:
		limit = Vector2i(mini(limit.x, 960), mini(limit.y, 540))
	if limit.x > 0 and limit.y > 0:
		factor = minf(1.0, minf(limit.x / pixels.x, limit.y / pixels.y))
	viewport.size = Vector2i(maxi(320, int(pixels.x * factor)), maxi(180, int(pixels.y * factor)))
	if mobile_quality and _active: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func enter() -> float:
	_scrim.hide()
	if Settings.reduced_motion:
		stage.reset_camera(1.0)
		if mobile_quality: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return 0.05
	stage.show_detail(true)
	return ENTRY_SECONDS


func reset_camera() -> void:
	stage.reset_camera()
	_scrim.show()
	if mobile_quality: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _apply_preferences() -> void:
	stage.atmosphere.set_motion(_active and not Settings.reduced_motion)
	stage.atmosphere.petals.visible = not Settings.reduced_motion
	if mobile_quality:
		set_process(_active and not Settings.reduced_motion)
		if _active: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func set_active(active: bool) -> void:
	if _active != active and stage.mirror_viewport != null:
		if not active:
			_mirror_update_mode = stage.mirror_viewport.render_target_update_mode
		stage.mirror_viewport.render_target_update_mode = _mirror_update_mode if active else SubViewport.UPDATE_DISABLED
	_active = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_render_clock = 0.0
	_apply_preferences()
	viewport.render_target_update_mode = (SubViewport.UPDATE_ONCE if mobile_quality else SubViewport.UPDATE_ALWAYS) if active else SubViewport.UPDATE_DISABLED


func _exit_tree() -> void:
	if Settings.changed.is_connected(_apply_preferences):
		Settings.changed.disconnect(_apply_preferences)
