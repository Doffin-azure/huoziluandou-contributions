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
	var instances: Array = GameState.deck
	if run.phase=="rest_choose" and run.pending_kind=="upgrade":
		instances = instances.filter(func(inst): return not inst.gilded)
	var overlay := CollectionOverlay.new()
	overlay.setup({"title":title,"characters":chars,"instances":instances,"counts":GameState.glyph_counts(),"modification_preview": "镀金：每次有效打出额外获得%d金币，组词也生效，永久保留。" % BattleBalance.i("gild_gold", 1) if run.phase=="rest_choose" and run.pending_kind=="upgrade" else "","pick_on_click":true})
	overlay.picked.connect(func(character: CharacterData):
		if generation!=_picker_generation or not _picker_open: return
		_picker_open = false; _picker_generation += 1
		completed.call(apply({"type":"pick","glyph":character.glyph})))
	overlay.closed.connect(func():
		if generation!=_picker_generation or not _picker_open or not is_instance_valid(screen): return
		_picker_open = false
		# Shop payment and pending event effects are already saved. Closing the
		# picker cannot silently discard them or charge the player a second time.
		pick.call_deferred(screen,title,completed))
	screen.add_child(overlay)
