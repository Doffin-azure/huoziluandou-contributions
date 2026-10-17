extends TextureRect
## A native capture of the approved courtyard, without a second 3D world per menu.
func _ready() -> void:
	name = "JourneyBackdrop"
	texture = preload("res://assets/ui/journey/courtyard_backdrop.png")
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://src/ui/journey/backdrop.gdshader")
	material = ink
