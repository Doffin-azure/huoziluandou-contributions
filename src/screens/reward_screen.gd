extends ScreenBase
## 战后奖励：三选一增字，或跳过换金币。

var node: MapNodeData
var _options: Array = []


func build(root: Control) -> void:
	node = params.get("node", null)
	var is_boss := node != null and node.type == MapNodeData.Type.BOSS
	_options = _roll_options(is_boss)

	var main := Ink.vbox(0)
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(main)
	main.add_child(_header(is_boss))

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(center)
	var col := Ink.vbox(18)
	center.add_child(col)

	var row := Ink.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for opt in _options:
		var card := CharCard.new()
		card.setup(_with_hint(opt))
		card.clicked.connect(_on_pick.bind(opt))
		row.add_child(card)

	if not is_boss:
		var skip := Ink.button("跳过，拿走 8 金币")
		skip.theme_type_variation = "GhostButton"
		skip.pressed.connect(_on_skip)
		col.add_child(skip)
	else:
		var skip2 := Ink.button("收下这幕的馈赠")
		skip2.theme_type_variation = "GhostButton"
		skip2.pressed.connect(_on_skip)
		col.add_child(skip2)


func _header(is_boss: bool) -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(14)
	panel.add_child(pad)
	var row := Ink.hbox(16)
	pad.add_child(row)
	row.add_child(Ink.h2("幕末大奖" if is_boss else "战利品"))
	row.add_child(Ink.label("选择一枚实体字加入字袋，或放弃以换取金币。", "Muted"))
	row.add_child(Ink.expander())
	row.add_child(Ink.label("血 %d/%d　❖ %d" % [GameState.player_hp, GameState.player_max_hp, GameState.gold], "Muted"))
	return panel


func _roll_options(is_boss: bool) -> Array:
	var pool: Array = []
	for c in Database.characters.values():
		if c.is_pollution or c.pending_design or c.tags.has("enemy"):
			continue
		if is_boss:
			if c.rarity >= 1:
				pool.append(c)
		else:
			if c.rarity <= 2:
				pool.append(c)
	if pool.is_empty():
		pool = Database.characters.values()
	var out: Array = []
	var rng := GameState.rng
	var guard := 0
	while out.size() < 3 and guard < 200:
		guard += 1
		var c: CharacterData = pool[rng.randi_range(0, pool.size() - 1)]
		if out.any(func(x): return x.id == c.id):
			continue
		out.append(c)
	return out


func _with_hint(c: CharacterData) -> CharacterData:
	var copy: CharacterData = c.duplicate()
	var words := _words_for(c.glyph)
	var hint := c.description
	if not words.is_empty():
		var shown := words.slice(0, 4)
		hint += "\n可组：" + " / ".join(shown)
	copy.description = hint
	return copy


func _words_for(glyph: String) -> Array:
	var out: Array = []
	for w in Database.words.values():
		if w.glyphs.has(glyph):
			out.append(w.word)
	return out


func _on_pick(c: CharacterData) -> void:
	GameState.add_character(c, 1)
	GameState.complete_current_node()
	if GameState.run_complete():
		_try_victory()
	else:
		goto("res://src/screens/map_screen.gd")


func _on_skip() -> void:
	GameState.add_gold(8)
	GameState.complete_current_node()
	if GameState.run_complete():
		_try_victory()
	else:
		goto("res://src/screens/map_screen.gd")


func _try_victory() -> void:
	var overlay := ChoiceOverlay.new()
	overlay.setup({
		"title": "通关",
		"body": "三幕已尽，字阵大成。你的字袋共 %d 枚实体字。" % GameState.deck_size(),
		"options": [{"text": "再走一遍", "primary": true}, {"text": "返回标题"}],
	})
	overlay.chose.connect(_on_victory_choice)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_victory_choice(index: int) -> void:
	if index == 0:
		GameState.start_new_run("v03")
		goto("res://src/screens/map_screen.gd")
	else:
		goto("res://src/screens/title_screen.gd")
