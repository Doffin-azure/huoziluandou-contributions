extends ScreenBase
## 战后奖励：三选一增字，或跳过换金币。
## 经典模式：精英先给 1 件遗物；首领（最后一幕除外）先回血，再二选一遗物。

## 首领战后回复最大气血的比例
const BOSS_HEAL_RATIO := 0.3

var node: MapNodeData
var _options: Array = []
var _room_run := false
var _expedition := false   ## 墨途远征：选中的字进字匣，回远征地图
var _cards: Array[GlyphOffer] = []
var _showcase: Control
var _hud: Control
var _selected := -1
var _busy := false
var _boss_heal := 0
var _settled := false
var _reward_owner: RefCounted
var _reward_room := ""


func has_scene_background() -> bool:
	return true


func build(root: Control) -> void:
	JourneyStyle.apply(self)
	node = params.get("node", null)
	_expedition = params.get("expedition", false) and GameState.expedition != null
	var is_boss := node != null and node.type == MapNodeData.Type.BOSS
	var reward_act: int = GameState.expedition.act if _expedition else GameState.act_index
	if is_boss and reward_act >= 3:
		if params.get("room_run", false) and GameState.room_run != null:
			GameState.room_run._finish_final_boss()
		elif not _expedition and not GameState.run_complete():
			GameState.complete_current_node()
		goto.call_deferred("res://src/screens/run_result_screen.gd", {"victory":true, "location":node.title})
		return
	_room_run = params.get("room_run", false) and GameState.room_run != null
	if _room_run:
		_reward_owner = GameState.room_run
		_reward_room = _reward_owner.current_room
		# Settlement clears the run's pending list. The displayed offers must keep
		# their own stable snapshot throughout the take animation and callbacks.
		_options = _reward_owner.reward_options.duplicate()
	else:
		_options = _roll_options(is_boss, int(params.get("count", 3)))
	var relic_step := _relic_step(is_boss)
	if relic_step == "boss":
		_boss_heal = mini(GameState.player_max_hp - GameState.player_hp, int(round(GameState.player_max_hp * BOSS_HEAL_RATIO)))
		GameState.heal(_boss_heal)
	_showcase = preload("res://src/ui/object_stage/object_stage_view.gd").new()
	_showcase.mode = "reward"
	_showcase.reward_count = _options.size()
	root.add_child(_showcase)
	_hud = preload("res://src/ui/object_stage/object_hud.gd").new()
	_hud.heading = "幕末 · 馈赠" if is_boss else "战后 · 择字"
	if _room_run and GameState.room_run.graph.rooms[GameState.room_run.current_room].kind=="treasure": _hud.heading = "荷池 · 藏字"
	_hud.instruction = "选择一枚活字收入字匣，满时收入字袋。" if _expedition or _room_run else "选择字匣中的一枚活字，收入字袋。"
	_hud.status = "气血 %d / %d    金币 %d" % [GameState.player_hp, GameState.player_max_hp, GameState.gold]
	_hud.action_text = "收入字匣" if _expedition or _room_run else "收入字袋"
	if _room_run:
		_hud.status += "    字匣 %d / 6" % _reward_owner.tray.size()
		if _reward_owner.tray.size()>=6:
			_hud.instruction = "字匣已满，选中的活字将收入字袋。"
			_hud.action_text = "收入字袋"
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
		root.add_child(offer)
		_cards.append(offer)
	_showcase.layout_changed.connect(_layout_cards)
	_layout_cards.call_deferred()
	_hud.set_detail("点击活字选中", "左键点击一枚活字查看效果并选中，再点击领取按钮确认。")
	_set_busy(false)
	_showcase.stage.open_case()
	if not relic_step.is_empty():
		_offer_relics.call_deferred(relic_step)
	if _room_run and not _reward_owner.contents[_reward_room].get("battle_relics",[]).is_empty():
		_set_busy(true)
		_offer_room_relics.call_deferred()


func _offer_room_relics() -> void:
	var ids: Array = _reward_owner.contents[_reward_room].get("battle_relics",[]).duplicate()
	var overlay := ChoiceOverlay.new()
	var options: Array = ids.map(func(id):return {"text":"遗物「%s」" % Relics.name_of(id),"hint":Relics.desc_of(id)})
	overlay.setup({"title":"幕末 · 遗物" if node.type==MapNodeData.Type.BOSS else "精英战利品", "body":"选择一件遗物，然后择字。", "options":options})
	overlay.chose.connect(func(index: int):
		if GameState.room_run!=_reward_owner or _reward_owner.current_room!=_reward_room: return
		var result: Dictionary = _reward_owner.apply({"type":"reward_relic","index":index})
		if not result.get("ok",false): return
		RelicRewardFlow.bind_owned(self,str(ids[index]),func(_id):
			_reward_owner._save_if_enabled()
			_set_busy(false)
			_on_relic_taken(_id)))
	add_child(overlay)


## 只在经典模式发遗物：精英 1 件，首领二选一；第三幕首领后直接通关，不再发。
func _relic_step(is_boss: bool) -> String:
	if _room_run or _expedition or node == null or params.get("relic_done", false):
		return ""
	if node.type == MapNodeData.Type.ELITE:
		return "elite"
	if is_boss and GameState.act_index < 3:
		return "boss"
	return ""


func _offer_relics(step: String) -> void:
	params["relic_done"] = true
	if step == "elite":
		RelicRewardFlow.offer(self, "精英战利品", "击败精英，得到一件遗物。", RelicRewardFlow.roll(1), _on_relic_taken)
	else:
		var body := ("首领倒下，气血回复 %d 点。" % _boss_heal) + "从两件遗物中选一件。"
		RelicRewardFlow.offer(self, "幕末 · 遗物", body, RelicRewardFlow.roll(2), _on_relic_taken)


func _on_relic_taken(_id: String) -> void:
	if is_inside_tree():
		_hud.status_label.text = "气血 %d / %d    金币 %d" % [GameState.player_hp, GameState.player_max_hp, GameState.gold]


func _layout_cards() -> void:
	for i in _cards.size():
		var rect: Rect2 = _showcase.object_rect(i)
		_cards[i].position = rect.position
		_cards[i].size = rect.size


func _inspect(index: int) -> void:
	if _busy or index < 0 or index >= _options.size(): return
	_selected = index
	_hud.action_button.disabled = false
	for i in _cards.size(): _cards[i].set_selected(i == index)
	_showcase.stage.select_object(index)
	var ch: CharacterData = _options[index]
	_hud.set_detail("%s  ·  %s" % [ch.glyph, ch.pinyin], _with_hint(ch).description)


func _accept_pick() -> void:
	if _busy or _settled or _selected<0 or _selected>=_options.size(): return
	_set_busy(true)
	var choice: CharacterData = _options[_selected]
	if Settings.reduced_motion:
		_on_pick(choice)
	else:
		_showcase.stage.take(_selected)
		create_tween().tween_interval(0.24).finished.connect(_on_pick.bind(choice))


func _set_busy(value: bool) -> void:
	_busy = value
	_hud.action_button.disabled = value or _selected < 0
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
	copy.description = EffectGlossary.character_hint(c)
	return copy


func _words_for(glyph: String) -> Array:
	return EffectGlossary.words_for_glyph(glyph)


func _on_pick(c: CharacterData) -> void:
	if _settled: return
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
	if _busy or _settled: return
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
	goto("res://src/screens/run_result_screen.gd", {"victory":true})
