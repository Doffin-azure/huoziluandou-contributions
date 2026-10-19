extends Control
## Draw above the SubViewport texture, while leaving world picking to its owner.
var map_view: Control
func _draw() -> void:
	if is_instance_valid(map_view): map_view.draw_overlay(self)
