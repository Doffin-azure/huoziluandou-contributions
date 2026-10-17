extends ScreenBase
## 战后奖励：三选一增字，或跳过换金币。

var node: MapNodeData
var _options: Array = []
var _expedition := false   ## 墨途远征：选中的字进字匣，回远征地图
var _cards: Array[GlyphOffer] = []
var _showcase: Control
var _hud: Control
var _selected := 0
var _busy := false


func has_scene_background() -> bool:
	return true


func build(root: Control) -> void:
	JourneyStyle.apply(self)
	node = params.get("node", null)
	_expedition = params.get("expedition", false) and GameState.expedition != null
	var is_boss := node != null and node.type == MapNodeData.Type.BOSS
	_options = _roll_options(is_boss, int(params.get("count", 3)))
	_showcase = preload("res://src/ui/object_stage/object_stage_view.gd").new()
	_showcase.mode = "reward"
	_showcase.reward_count = _options.size()
	root.add_child(_showcase)
	_hud = preload("res://src/ui/object_stage/object_hud.gd").new()
	_hud.heading = "幕末 · 馈赠" if is_boss else "战后 · 择字"
	_hud.instruction = "选择字匣中的一枚活字，收入字袋。"
	_hud.status = "气血 %d / %d    金币 %d" % [GameState.player_hp, GameState.player_max_hp, GameState.gold]
	_hud.action_text = "收入字匣" if _expedition else "收入字袋"
	_hud.secondary_text = "收下这幕的馈赠" if is_boss else "跳过 · 获得 8 金币"
	_hud.on_action = _accept_pick
	_hud.on_secondary = _on_skip
	root.add_child(_hud)
	for i in _options.size():
		var ch: CharacterData = _options[i]
		_showcase.stage.add_object(ch.glyph, i, ch.rarity)
		var offer := GlyphOffer.new()
		offer.character = ch
		offer.caption = "%02d   %s" % [i + 1, ch.glyph]
		offer.clicked.connect(_inspect.bind(i))
		offer.hovered.connect(_inspect.bind(i))
		root.add_child(offer)
		_cards.append(offer)
	_showcase.layout_changed.connect(_layout_cards)
	_layout_cards.call_deferred()
	_inspect(0)
	_showcase.stage.open_case()


func _layout_cards() -> void:
	for i in _cards.size():
		var rect: Rect2 = _showcase.object_rect(i)
		_cards[i].position = rect.position
		_cards[i].size = rect.size


func _inspect(index: int) -> void:
	if _busy or index < 0 or index >= _options.size(): return
	_selected = index
	for i in _cards.size(): _cards[i].set_selected(i == index)
	_showcase.stage.select_object(index)
	var ch: CharacterData = _options[index]
	_hud.set_detail("%s  ·  %s" % [ch.glyph, ch.pinyin], _with_hint(ch).description)


func _accept_pick() -> void:
	if _busy or _options.is_empty(): return
	_busy = true
	_hud.action_button.disabled = true
	_hud.secondary_button.disabled = true
	if Settings.reduced_motion:
		_on_pick(_options[_selected])
	else:
		_showcase.stage.take(_selected)
		create_tween().tween_interval(0.24).finished.connect(func(): _on_pick(_options[_selected]))


func _roll_options(is_boss: bool, count := 3) -> Array:
	var pool: Array = []
	for c in Database.characters.values():
		if c.is_pollution or c.pending_design or c.tags.has("enemy") or c.tags.has("彩蛋"):
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
	while out.size() < count and guard < 200:
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
	if _expedition:
		GameState.expedition.receive_reward_glyph(c)
		goto("res://src/screens/expedition_map_screen.gd")
		return
	GameState.add_character(c, 1)
	GameState.complete_current_node()
	if GameState.run_complete():
		_try_victory()
	else:
		goto("res://src/screens/map_screen.gd")


func _on_skip() -> void:
	GameState.add_gold(8)
	if _expedition:
		goto("res://src/screens/expedition_map_screen.gd")
		return
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
