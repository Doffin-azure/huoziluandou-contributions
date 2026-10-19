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
	stage.camera.v_offset = -0.65 if JourneyStyle.touch_scale(self) > 1.1 else 0.0
	layout_changed.emit()


func object_rect(index: int, service := false) -> Rect2:
	if stage == null or index >= stage.rests.size(): return Rect2()
	var origin: Vector3 = stage.rests[index]
	var b := 0.53 if service else 1.0
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for x in [-1.04, 1.04]:
		for y in [0.0, 2.55]:
			for z in [-0.23, 0.40]:
				var at: Vector2 = stage.camera.unproject_position(origin + Vector3(x * b, y * b, z))
				at *= size / Vector2(viewport.size)
				low = low.min(at)
				high = high.max(at)
	return Rect2(low, high - low).grow(6)
