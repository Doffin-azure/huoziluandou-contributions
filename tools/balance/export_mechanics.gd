extends SceneTree
## Export the loaded configuration and registered content without starting a run.

func _initialize() -> void:
	_dump.call_deferred()

func _resource(value: Resource) -> Dictionary:
	var result := {"source": value.resource_path}
	for property in value.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property.usage) & PROPERTY_USAGE_STORAGE:
			result[property.name] = _plain(value.get(property.name))
	return result

func _plain(value: Variant) -> Variant:
	if value is Resource: return _resource(value)
	if value is Dictionary:
		var result := {}
		for key in value: result[str(key)] = _plain(value[key])
		return result
	if value is Array or value is PackedStringArray:
		var result: Array = []
		for item in value: result.append(_plain(item))
		return result
	if value is Color: return value.to_html()
	return value

func _dump() -> void:
	var db = root.get_node("Database")
	var glossary = load("res://src/ui/effect_glossary.gd")
	var events = load("res://src/core/event_effects.gd")
	var lexicon = load("res://src/expedition/lexicon.gd")
	var relics = load("res://src/core/relics.gd")
	var output := {}
	for category in ["characters", "words", "enemies", "statuses", "pollutions", "acts", "starter_decks"]:
		var rows: Array = []
		for value in db.get(category).values():
			var row := _resource(value)
			if category == "statuses": row["current_description"] = glossary.status_description(value.id)
			rows.append(row)
		output[category] = rows
	output["rules"] = _resource(db.rules)
	output["glossary"] = glossary.ENTRIES
	output["events"] = events.all()
	output["event_effect_types"] = events.SUPPORTED
	output["lexicon"] = lexicon.WORDS
	output["riddles"] = load("res://src/data/lantern_riddles.gd").POOL
	output["riddle_bonus"] = load("res://src/data/lantern_riddles.gd").BONUS
	output["seals"] = Expedition.SEALS
	output["relics"] = []
	for id in relics.DEFS:
		output.relics.append({"id": id, "name": relics.name_of(id), "description": relics.desc_of(id), "bind": relics.needs_bind(id), "tier": relics.TIER[id], "event_only": relics.is_event_relic(id)})
	output["warnings"] = db.warnings
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass an output JSON path after --")
		quit(1)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("Mechanics exported: ", args[0])
	quit(0 if db.warnings.is_empty() else 1)
