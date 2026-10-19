extends Control
## F6 starts a fresh seeded garden without replacing the player's autosave.
@export var map_seed := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Router.host = self
	var run = preload("res://src/expedition/room_run_state.gd").new()
	var value := map_seed if map_seed>=0 else int(Time.get_unix_time_from_system())^int(Time.get_ticks_usec())
	run.reset({"seed":value,"layout":"random_garden"}); run.autosave = false
	print("[RandomGardenSample] seed=",value)
	Router.goto(run.MAP_SCREEN)
