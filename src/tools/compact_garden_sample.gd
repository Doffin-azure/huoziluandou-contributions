extends Node
## F6: the actual encounter loop in a fixed-seed compact garden. No autosave.
@export var map_seed := 29


func _ready() -> void:
	GameState.set_meta("courtyard_preview",true) # Restarts in this F6 session stay disposable too.
	var host := Control.new(); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(host); Router.host = host
	var run = preload("res://src/expedition/room_run_state.gd").new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): map_seed = int(arg.trim_prefix("--seed="))
	run.reset({"seed":map_seed,"layout":"compact_garden"}); run.autosave = false
	Router.goto(run.MAP_SCREEN)
