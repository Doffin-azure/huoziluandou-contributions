extends ScreenBase
## 商店：定向增字、复制、删字、治疗。价格取自 GDD V0.3 测试起点。

var node: MapNodeData
var _offers: Array = []       ## [{kind, character, price}]
var _showcase: Control
var _hud: Control
var _cards: Array[GlyphOffer] = []
var _selected := 0
var _busy := false
var _pending_offer_index := -1
var _pending_kind := ""


func has_scene_background() -> bool:
	return true


func build(root: Control) -> void:
	JourneyStyle.apply(self)
	node = params.get("node", null)
	_offers = _roll_offers()
	for i in _offers.size(): _offers[i]["display_slot"] = i
	_showcase = preload("res://src/ui/object_stage/object_stage_view.gd").new()
	_showcase.mode = "shop"
	root.add_child(_showcase)
	_hud = preload("res://src/ui/object_stage/object_hud.gd").new()
	_hud.heading = "市集 · 字肆"
	_hud.instruction = "柜上择字，印台整备。"
	_hud.action_text = "购入"
	_hud.secondary_text = "离开"
	_hud.on_action = _purchase_selected
	_hud.on_secondary = _leave
	_hud.tertiary_text = "刷新 · %d 金币" % Expedition.SHOP_REFRESH_COST
	_hud.on_tertiary = _refresh_stock
	root.add_child(_hud)
	_showcase.layout_changed.connect(_layout_offers)
	_refresh()



func _roll_offers() -> Array:
	var out := _roll_chars()
	out.append({"kind": "remove", "character": null, "price": GameState.rng.randi_range(16, 20)})
	out.append({"kind": "copy", "character": null, "price": GameState.rng.randi_range(18, 22)})
	out.append({"kind": "heal", "character": null, "price": GameState.rng.randi_range(10, 14)})
	return out


func _roll_chars() -> Array:
	var out: Array = []
	var pool: Array = []
	for c in Database.characters.values():
		if not c.is_pollution and not c.pending_design and not c.tags.has("enemy") and not c.tags.has("彩蛋") and c.rarity <= 2:
			pool.append(c)
	var rng := GameState.rng
	var picked: Array = []
	var guard := 0
	while picked.size() < 3 and guard < 200:
		guard += 1
		var c: CharacterData = pool[rng.randi_range(0, pool.size() - 1)]
		if picked.any(func(x): return x.id == c.id):
			continue
		picked.append(c)
		out.append({"kind": "buy_char", "character": c, "price": rng.randi_range(12, 15)})
	return out


## 花 5 金币换三枚新字；没买的服务原样保留在原位。
func _refresh_stock() -> void:
	if _busy or not GameState.spend_gold(Expedition.SHOP_REFRESH_COST):
		return
	var chars := _roll_chars()
	for i in chars.size(): chars[i]["display_slot"] = i
	_offers = chars + _offers.filter(func(o): return o.kind != "buy_char")
	_selected = 0
	_refresh()


func _refresh() -> void:
	_showcase.stage.clear_objects()
	for card in _cards:
		card.get_parent().remove_child(card)
		card.queue_free()
	_cards.clear()
	_hud.status_label.text = "金币 %d" % GameState.gold
	if _hud.tertiary_button != null:
		_hud.tertiary_button.disabled = GameState.gold < Expedition.SHOP_REFRESH_COST
	for i in _offers.size():
		var item: Dictionary = _offers[i]
		var ch: CharacterData = item.character
		var glyph: String = ch.glyph if ch != null else {"remove": "删", "copy": "拓", "heal": "息"}[item.kind]
		_showcase.stage.add_object(glyph, int(item.display_slot), ch.rarity if ch != null else 0, ch == null)
		var card := GlyphOffer.new()
		card.character = ch
		card.caption = "%d 金" % item.price
		card.clicked.connect(_inspect.bind(i))
		card.hovered.connect(_inspect.bind(i))
		content.add_child(card)
		_cards.append(card)
	_selected = clampi(_selected, 0, maxi(0, _offers.size() - 1))
	_layout_offers.call_deferred()
	_inspect(_selected)


func _layout_offers() -> void:
	for i in _cards.size():
		var rect: Rect2 = _showcase.object_rect(i, _offers[i].kind != "buy_char")
		_cards[i].position = rect.position
		_cards[i].size = rect.size


func _inspect(index: int) -> void:
	if _busy or _offers.is_empty(): return
	_selected = index
	for i in _cards.size(): _cards[i].set_selected(i == index)
	_showcase.stage.select_object(index)
	var item: Dictionary = _offers[index]
	var ch: CharacterData = item.character
	var title: String = ch.glyph if ch != null else {"remove": "删字", "copy": "复制", "heal": "调息"}[item.kind]
	var body: String = ch.description if ch != null else {"remove": "从字袋中永久移除一枚字。", "copy": "复制字袋中的一枚字。", "heal": "回复 %d 点气血。" % _heal_amount()}[item.kind]
	_hud.set_detail(title + "  ·  " + str(item.price) + " 金币", body)
	_hud.action_button.text = "金币不足" if GameState.gold < int(item.price) else "购入 · %d 金币" % item.price
	_hud.action_button.disabled = GameState.gold < int(item.price)


func _purchase_selected() -> void:
	if _busy or _offers.is_empty() or GameState.gold < int(_offers[_selected].price): return
	var index := _selected
	if Settings.reduced_motion or _offers[index].kind != "buy_char":
		_buy(index)
		return
	_busy = true
	_hud.action_button.disabled = true
	_hud.secondary_button.disabled = true
	_showcase.stage.take(index)
	create_tween().tween_interval(0.24).finished.connect(func():
		_busy = false
		_hud.secondary_button.disabled = false
		_buy(index))


func _heal_amount() -> int:
	return int(round(GameState.player_max_hp * 0.3))


func _buy(index: int) -> void:
	var offer: Dictionary = _offers[index]
	if not GameState.spend_gold(int(offer.price)):
		return
	match offer.kind:
		"buy_char":
			GameState.add_character(offer.character, 1)
			_finish_offer(index)
		"heal":
			GameState.heal(_heal_amount())
			_finish_offer(index)
		"remove":
			_pending_offer_index = index
			_pending_kind = "remove"
			_choose_char("选择要删除的字")
		"copy":
			_pending_offer_index = index
			_pending_kind = "copy"
			_choose_char("选择要复制的字")


func _on_char_chosen(ch: CharacterData) -> void:
	if _pending_kind == "remove":
		GameState.remove_character_id(ch.id)
	elif _pending_kind == "copy":
		GameState.add_character(ch, 1)
	var idx := _pending_offer_index
	_pending_kind = ""
	_pending_offer_index = -1
	if idx >= 0 and idx < _offers.size():
		_finish_offer(idx)


func _finish_offer(index: int) -> void:
	_offers.remove_at(index)
	_refresh()


func _choose_char(title: String) -> void:
	var counts := GameState.glyph_counts()
	var chars: Array = []
	for id in counts.keys():
		var cd: CharacterData = Database.get_character_by_glyph(id)
		if cd != null:
			chars.append(cd)
	var overlay := CollectionOverlay.new()
	overlay.setup({
		"title": title,
		"subtitle": "点击一枚字",
		"characters": chars,
		"counts": counts,
		"pick_on_click": true,
	})
	overlay.picked.connect(_on_char_chosen)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _leave() -> void:
	GameState.complete_current_node()
	goto("res://src/screens/map_screen.gd")
