extends Control
## A private viewport for the counter. Projection supplies stable 2D picking bounds.
signal layout_changed
const Stage := preload("res://src/ui/object_stage/object_stage.gd")
var stage: Node3D
var viewport: SubViewport
var mode := "reward"
var reward_count := 3


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X if RenderingServer.get_current_rendering_method() == "mobile" else Viewport.MSAA_4X
	viewport.positional_shadow_atlas_size = 2048
	add_child(viewport)
	stage = Stage.new()
	stage.mode = mode
	stage.reward_count = reward_count
	viewport.add_child(stage)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(display)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/ui/object_stage/readability.gdshader")
	veil.material = material
	add_child(veil)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var pixels := Vector2(get_viewport().get_texture().get_size())
	var cap := Vector2(1280, 720) if RenderingServer.get_current_rendering_method() == "mobile" else Vector2(1600, 900)
	var factor := minf(1, minf(cap.x / pixels.x, cap.y / pixels.y))
	viewport.size = Vector2i(maxi(320, int(pixels.x * factor)), maxi(180, int(pixels.y * factor)))
	# Keep the complete counter visible on 4:3 tablets as well as wide phones.
	var aspect := pixels.x / maxf(1.0, pixels.y)
	stage.camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(34.0) * 0.5) * maxf(1.0, (16.0 / 9.0) / aspect)))
	stage.camera.v_offset = -1.0 if JourneyStyle.touch_scale(self) > 1.1 else 0.0
	layout_changed.emit()


func object_rect(index: int, service := false) -> Rect2:
	if stage == null or index >= stage.rests.size(): return Rect2()
	var origin: Vector3 = stage.rests[index]
	var b := 0.53 if service else (0.78 if mode == "shop" else 1.0)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for x in [-1.04, 1.04]:
		for y in [0.0, 2.55]:
			for z in [-0.23, 0.40]:
				var at: Vector2 = stage.camera.unproject_position(origin + Vector3(x * b, y * b, z))
				at *= size / Vector2(viewport.size)
				low = low.min(at)
				high = high.max(at)
	if mode == "shop" and not service:
		var target_size := (high - low + Vector2.ONE * 2).max(Vector2.ONE * 48 * JourneyStyle.touch_scale(self))
		return Rect2((low + high - target_size) * 0.5, target_size)
	return Rect2(low, high - low).grow(6)


func action_rect(key: String) -> Rect2:
	var action: Node3D = stage.shop_actions[key]
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for x in [-0.64, 0.64]:
		for y in [-1.18, 0.64]:
			var at: Vector2 = stage.camera.unproject_position(action.global_transform * Vector3(x, y, 0.38))
			at *= size / Vector2(viewport.size)
			low = low.min(at)
			high = high.max(at)
	var target_size := (high - low).max(Vector2.ONE * 48 * JourneyStyle.touch_scale(self))
	return Rect2((low + high - target_size) * 0.5, target_size)


func relic_rect(index: int) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for x in [-0.88, 0.88]:
		for y in [-0.65, 1.45]:
			var at: Vector2 = stage.camera.unproject_position(stage.rests[index] + Vector3(x, y, 0.85))
			at *= size / Vector2(viewport.size)
			low = low.min(at)
			high = high.max(at)
	var target_size := (high - low).max(Vector2.ONE * 48 * JourneyStyle.touch_scale(self))
	return Rect2((low + high - target_size) * 0.5, target_size)
