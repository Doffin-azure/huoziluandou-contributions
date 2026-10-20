extends RefCounted
## Full-screen node views share the courtyard's saved content and settlement.
## They must never roll a new event/stock or complete a classic-map node.
var run: RefCounted
var room: String
var _picker_generation := 0
var _picker_open := false


func _init(owner: RefCounted) -> void:
	run = owner; room = run.current_room


func current() -> bool:
	return GameState.room_run==run and run.current_room==room


func apply(action: Dictionary) -> Dictionary:
	if not current(): return {"ok":false,"reason":"此节点已不再是当前庭院"}
	return run.apply(action)


func pick(screen: Control, title: String, completed: Callable) -> void:
	if not current() or _picker_open or not run.phase.ends_with("_choose"): return
	_picker_open = true; _picker_generation += 1
	var generation := _picker_generation
	var chars: Array = []
	for glyph: String in run.pending_glyphs:
		var character: CharacterData = Database.get_character_by_glyph(glyph)
		if character!=null: chars.append(character)
	var overlay := CollectionOverlay.new()
	var counts := GameState.glyph_counts()
	if run.phase == "event_choose": counts = preload("res://src/core/event_effects.gd").remaining_counts(run.pending_event_effect)
	var subtitle := "还需 %d 枚" % int(run.pending_event_effect.get("remaining",1)) if run.phase == "event_choose" else ""
	overlay.setup({"title":title,"subtitle":subtitle,"characters":chars,"counts":counts,"pick_on_click":true,"close_text":"取消选择"})
	overlay.picked.connect(func(character: CharacterData):
		if generation!=_picker_generation or not _picker_open or not is_instance_valid(screen) or screen.is_queued_for_deletion() or not screen.is_inside_tree(): return
		_picker_open = false; _picker_generation += 1
		completed.call(apply({"type":"pick","glyph":character.glyph})))
	overlay.closed.connect(func():
		if generation!=_picker_generation or not _picker_open or not is_instance_valid(screen) or screen.is_queued_for_deletion() or not screen.is_inside_tree(): return
		_picker_open = false; _picker_generation += 1
		completed.call(apply({"type":"cancel_pick"})))
	screen.add_child(overlay)
