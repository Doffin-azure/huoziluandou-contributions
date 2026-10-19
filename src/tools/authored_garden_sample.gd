extends Control
## F6 opens the playable fixed garden without overwriting the player's save.
func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Router.host = self
	var run = preload("res://src/expedition/room_run_state.gd").new()
	run.reset({"seed":29,"layout":"authored_garden"}); run.autosave = false
	Router.goto(run.MAP_SCREEN)
