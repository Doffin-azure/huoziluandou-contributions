extends ScreenBase
## 战后奖励：选两轮字。第一轮跳过换金币；第二轮优先给能和第一轮所选字组词的字。

const ROUNDS := 2

var node: MapNodeData
var _options: Array = []
var _expedition := false   ## 墨途远征：选中的字进字匣，回远征地图
var _cards: Array[GlyphOffer] = []
var _showcase: Control
var _hud: Control
var _selected := 0
var _busy := false
var _round := 1
var _anchor := ""            ## 第一轮选中的字；第二轮围绕它出题
var _links: Dictionary = {}  ## 第二轮候选字 -> 与 _anchor 共组的词


func has_scene_background() -> bool:
	return true


func build(root: Control) -> void:
	JourneyStyle.apply(self)
	node = params.get("node", null)
	_expedition = params.get("expedition", false) and GameState.expedition != null
	var is_boss := node != null and node.type == MapNodeData.Type.BOSS
	_round = int(params.get("round", 1))
	_anchor = str(params.get("anchor", ""))
	_options = _roll_options(is_boss, int(params.get("count", 3)))
	_showcase = preload("res://src/ui/object_stage/object_stage_view.gd").new()
	_showcase.mode = "reward"
	_showcase.reward_count = _options.size()
	root.add_child(_showcase)
	_hud = preload("res://src/ui/object_stage/object_hud.gd").new()
	_hud.heading = ("幕末 · 馈赠" if is_boss else "战后 · 择字") + "（%d / %d）" % [_round, ROUNDS]
	if _round == 1:
		_hud.instruction = "选择字匣中的一枚活字，收入字袋。之后还能再选一枚。"
	else:
		_hud.instruction = "再选一枚。能和【%s】组词的字排在前面。" % _anchor
	_hud.status = "气血 %d / %d    金币 %d" % [GameState.player_hp, GameState.player_max_hp, GameState.gold]
	_hud.action_text = "收入字匣" if _expedition else "收入字袋"
	if _round > 1:
		_hud.secondary_text = "不再选字 · 离开"
	else:
		_hud.secondary_text = "收下这幕的馈赠" if is_boss else "跳过 · 获得 %d 金币" % Expedition.SKIP_GOLD
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
	var pool := _reward_pool(is_boss)
	var out: Array = []
	if not _anchor.is_empty():
		out = _related_options(pool, count)
	var rng := GameState.rng
	var guard := 0
	while out.size() < count and guard < 200:
		guard += 1
		var c: CharacterData = pool[rng.randi_range(0, pool.size() - 1)]
		if c.glyph == _anchor or out.any(func(x): return x.id == c.id):
			continue
		out.append(c)
	return out


func _reward_pool(is_boss: bool) -> Array:
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
	return pool


## 第二轮：找和 _anchor 同在一个词里的字。补上它就能凑齐整词的排前面，同档内随机。
func _related_options(pool: Array, count: int) -> Array:
	var allowed := {}
	for c in pool:
		allowed[c.glyph] = c
	var owned := _owned_glyphs()
	owned[_anchor] = true
	var score := {}
	for w in Database.words.values():
		if not w.glyphs.has(_anchor):
			continue
		for g in w.glyphs:
			if g == _anchor or not allowed.has(g):
				continue
			var complete: bool = w.glyphs.all(func(x): return x == g or owned.has(x))
			var s := 2 if complete else 1
			if s > int(score.get(g, 0)):
				score[g] = s
				_links[g] = w.word
	var keys: Array = score.keys()
	var rng := GameState.rng
	for i in range(keys.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = keys[i]
		keys[i] = keys[j]
		keys[j] = t
	keys.sort_custom(func(a, b): return score[a] > score[b])
	var out: Array = []
	for g in keys.slice(0, count):
		out.append(allowed[g])
	return out


func _owned_glyphs() -> Dictionary:
	if _expedition:
		return GameState.expedition.owned_glyphs()
	var out := {}
	for c in GameState.deck:
		out[c.glyph()] = true
	return out


func _with_hint(c: CharacterData) -> CharacterData:
	var copy: CharacterData = c.duplicate()
	var words := _words_for(c.glyph)
	var hint := c.description
	if _links.has(c.glyph):
		hint = "与【%s】组「%s」
" % [_anchor, _links[c.glyph]] + hint
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
	else:
		GameState.add_character(c, 1)
	if _round < ROUNDS:
		var next := params.duplicate()
		next["round"] = _round + 1
		next["anchor"] = c.glyph
		goto("res://src/screens/reward_screen.gd", next)
		return
	_leave()


func _on_skip() -> void:
	if _round == 1:
		GameState.add_gold(Expedition.SKIP_GOLD)
	_leave()


func _leave() -> void:
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
