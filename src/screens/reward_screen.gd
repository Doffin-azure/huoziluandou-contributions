extends ScreenBase
## 战后奖励：三选一增字，或跳过换金币。
## 经典模式：精英先给 1 件遗物；首领（最后一幕除外）先回血，再三选一遗物。
## 庭院路线的首领沿用控制器提供的两件候选。

## 首领战后回复最大气血的比例
const BOSS_HEAL_RATIO := 0.3

var node: MapNodeData
var _options: Array = []
var _room_run := false
var _expedition := false   ## 墨途远征：选中的字进字匣，回远征地图
var _cards: Array[GlyphOffer] = []
var _showcase: Control
var _hud: Control
var _selected := 0
var _busy := false
var _boss_heal := 0
var _settled := false
var _reward_owner: RefCounted
var _reward_room := ""
var _relic_kind := ""
var _relic_choices: Array = []
var _relic_pending := false


func has_scene_background() -> bool:
	return true


func build(root: Control) -> void:
	JourneyStyle.apply(self)
	node = params.get("node", null)
	_expedition = params.get("expedition", false) and GameState.expedition != null
	var is_boss := node != null and node.type == MapNodeData.Type.BOSS
	var saved: Dictionary = params.get("_saved_screen", {})
	_room_run = params.get("room_run", false) and GameState.room_run != null
	if _room_run:
		_reward_owner = GameState.room_run
		_reward_room = _reward_owner.current_room
		# Settlement clears the run's pending list. The displayed offers must keep
		# their own stable snapshot throughout the take animation and callbacks.
		_options = _reward_owner.reward_options.duplicate()
	else:
		_options = saved.options if saved.has("options") else _roll_options(is_boss, int(params.get("count", 3)))
		if saved.has("relic_kind"):
			_relic_kind = str(saved.relic_kind)
			_relic_choices = saved.get("relic_choices", [])
			_relic_pending = bool(saved.get("relic_pending", false))
			_boss_heal = int(saved.get("boss_heal", 0))
		else:
			if not _room_run and not _expedition and node != null and not params.get("relic_done", false):
				if node.type == MapNodeData.Type.ELITE: _relic_kind = "elite"
				elif is_boss and GameState.act_index < 3: _relic_kind = "boss"
			if _relic_kind == "boss":
				_boss_heal = mini(GameState.player_max_hp - GameState.player_hp, int(round(GameState.player_max_hp * BOSS_HEAL_RATIO)))
				GameState.heal(_boss_heal)
			if not _relic_kind.is_empty():
				_relic_choices = RelicRewardFlow.roll(3 if _relic_kind == "boss" else 1)
				_relic_pending = not _relic_choices.is_empty()
	_showcase = preload("res://src/ui/object_stage/object_stage_view.gd").new()
	_showcase.mode = "reward"
	_showcase.reward_count = _options.size()
	root.add_child(_showcase)
	_hud = preload("res://src/ui/object_stage/object_hud.gd").new()
	_hud.heading = "幕末 · 馈赠" if is_boss else "战后 · 择字"
	if _room_run and GameState.room_run.graph.rooms[GameState.room_run.current_room].kind=="treasure": _hud.heading = "荷池 · 藏字"
	_hud.instruction = "选择一枚活字收入字匣，满时收入字袋。" if _expedition else "选择一枚活字收入字袋。"
	_hud.status = "气血 %d / %d    金币 %d" % [GameState.player_hp, GameState.player_max_hp, GameState.gold]
	_hud.action_text = "收入字匣" if _expedition else "收入字袋"
	_hud.secondary_text = "收下这幕的馈赠" if is_boss else "跳过 · 获得 %d 金币" % Expedition.SKIP_GOLD
	if _room_run: _hud.secondary_text = "跳过 · 获得 %d 金币" % Expedition.SKIP_GOLD
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
	if _relic_pending:
		_hud.action_button.disabled = true
		_hud.secondary_button.disabled = true
		_offer_relics.call_deferred()
	if _room_run and not _reward_owner.contents[_reward_room].get("battle_relics",[]).is_empty():
		_set_busy(true)
		_offer_room_relics.call_deferred()


func _offer_room_relics() -> void:
	var ids: Array = _reward_owner.contents[_reward_room].get("battle_relics",[]).duplicate()
	var overlay := ChoiceOverlay.new()
	var options: Array = ids.map(func(id):return {"text":"遗物「%s」" % Relics.name_of(id),"relic_id":id,"hint":Relics.desc_of(id)})
	overlay.setup({"title":"幕末 · 遗物" if node.type==MapNodeData.Type.BOSS else "精英战利品", "body":"选择一件遗物，然后择字。", "options":options,"compact":true,"physical_relics":true})
	overlay.chose.connect(func(index: int):
		if GameState.room_run!=_reward_owner or _reward_owner.current_room!=_reward_room: return
		var result: Dictionary = _reward_owner.apply({"type":"reward_relic","index":index})
		if not result.get("ok",false): return
		RelicRewardFlow.bind_owned(self,str(ids[index]),func(_id):
			_reward_owner._save_if_enabled()
			_set_busy(false)
			_on_relic_taken(_id)))
	add_child(overlay)


func _offer_relics() -> void:
	var title := "精英战利品" if _relic_kind == "elite" else "幕末 · 遗物"
	var body := "击败精英，得到一件遗物。" if _relic_kind == "elite" else "首领倒下，气血回复 %d 点。从三件遗物中选一件。" % _boss_heal
	if _relic_kind == "boss" and _relic_choices.size() < 3:
		body = "首领倒下，气血回复 %d 点。剩余未拥有的遗物不足三件，选择一件。" % _boss_heal
	RelicRewardFlow.offer(self, title, body, _relic_choices, _on_relic_taken)


func _on_relic_taken(_id: String) -> void:
	_relic_pending = false
	params["relic_done"] = true
	if not is_inside_tree(): return
	_hud.status_label.text = "气血 %d / %d    金币 %d" % [GameState.player_hp, GameState.player_max_hp, GameState.gold]
	_hud.action_button.disabled = false
	_hud.secondary_button.disabled = false
	SaveManager.request_save()


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
	if _busy or _relic_pending or _settled or _selected<0 or _selected>=_options.size(): return
	_set_busy(true)
	var choice: CharacterData = _options[_selected]
	if Settings.reduced_motion:
		_on_pick(choice)
	else:
		_showcase.stage.take(_selected)
		create_tween().tween_interval(0.24).finished.connect(_on_pick.bind(choice))


func _set_busy(value: bool) -> void:
	_busy = value
	_hud.action_button.disabled = value
	_hud.secondary_button.disabled = value


func _claim_failed(reason: String) -> void:
	_set_busy(false)
	_showcase.stage.restore_object(_selected)
	_hud.set_detail("奖励未领取",reason)


func _claim_room_reward(action: Dictionary) -> bool:
	if GameState.room_run!=_reward_owner or _reward_owner.current_room!=_reward_room:
		_claim_failed("当前奖励已变化，请重新打开当前庭院的奖励。")
		return false
	var result: Dictionary = _reward_owner.apply(action)
	if not result.get("ok",false):
		_claim_failed(str(result.get("reason","领取失败，请重试。")))
		return false
	_settled = true
	return true


func _roll_options(is_boss: bool, count := 3) -> Array:
	var pool := _reward_pool(is_boss)
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


func _reward_pool(is_boss: bool) -> Array:
	var pool: Array = []
	for c in Database.characters.values():
		if c.is_pollution or c.pending_design or c.tags.has("enemy") or c.tags.has("彩蛋") or c.tags.has("event"):
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
	if _relic_pending or _settled: return
	_set_busy(true)
	if c==null or not _options.has(c):
		_claim_failed("无效奖励，请重新选择。")
		return
	if _room_run:
		if not _claim_room_reward({"type":"reward","index":_options.find(c),"glyph":c.glyph}): return
		goto("res://src/screens/room_map_screen.gd")
		return
	_settled = true
	if _expedition:
		GameState.expedition.receive_reward_glyph(c)
	else:
		GameState.add_character(c, 1)
	_leave()


func _on_skip() -> void:
	if _busy or _relic_pending or _settled: return
	_set_busy(true)
	if _room_run:
		if not _claim_room_reward({"type":"skip"}): return
		goto("res://src/screens/room_map_screen.gd")
		return
	_settled = true
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


func save_checkpoint() -> Dictionary:
	if _busy: return {}
	# A binding picker has already granted the relic; keep the preceding whole transaction.
	for child in get_children():
		if child is CollectionOverlay: return {}
	var snapshot := super.save_checkpoint()
	snapshot.screen = {"options": _options, "relic_kind": _relic_kind, "relic_choices": _relic_choices, "relic_pending": _relic_pending, "boss_heal": _boss_heal}
	return snapshot
