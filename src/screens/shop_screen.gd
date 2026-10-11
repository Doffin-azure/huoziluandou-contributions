extends ScreenBase
## 商店：定向增字、复制、删字、治疗。价格取自 GDD V0.3 测试起点。

var node: MapNodeData
var _offers: Array = []       ## [{kind, character, price}]
var _grid: GridContainer
var _gold_label: Label
var _cards_root: Control
var _pending_offer_index := -1
var _pending_kind := ""


func build(root: Control) -> void:
	node = params.get("node", null)
	_offers = _roll_offers()

	var main := Ink.vbox(0)
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(main)
	main.add_child(_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var pad := Ink.margin(20)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	_cards_root = Control.new()
	_cards_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_cards_root)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	_cards_root.add_child(_grid)

	_refresh()


func _header() -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(12)
	panel.add_child(pad)
	var row := Ink.hbox(16)
	pad.add_child(row)
	row.add_child(Ink.h2("市集 · 笔墨铺"))
	row.add_child(Ink.label("可购买单字、复制已有字、指定删字、治疗。", "Muted"))
	row.add_child(Ink.expander())
	_gold_label = Ink.label("❖ %d" % GameState.gold, "Stat", Palette.GOLD_DK)
	row.add_child(_gold_label)
	var leave := Ink.button("离开市集")
	leave.pressed.connect(_leave)
	row.add_child(leave)
	return panel


func _roll_offers() -> Array:
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
	out.append({"kind": "remove", "character": null, "price": rng.randi_range(16, 20)})
	out.append({"kind": "copy", "character": null, "price": rng.randi_range(18, 22)})
	out.append({"kind": "heal", "character": null, "price": rng.randi_range(10, 14)})
	return out


func _refresh() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_gold_label.text = "❖ %d" % GameState.gold
	for i in _offers.size():
		_grid.add_child(_make_offer_cell(_offers[i], i))


func _make_offer_cell(offer: Dictionary, index: int) -> Control:
	var cell := Ink.vbox(6)
	cell.custom_minimum_size.x = 210

	match offer.kind:
		"buy_char":
			var card := CharCard.new()
			card.setup(offer.character)
			cell.add_child(card)
		"remove":
			cell.add_child(_service_card("删字", "从字袋中永久移除一枚字。让字袋更精炼。", Palette.PLUM))
		"copy":
			cell.add_child(_service_card("复制", "复制字袋中的一枚字，提高抽中密度。", Palette.INDIGO))
		"heal":
			cell.add_child(_service_card("治疗", "回复 %d 点气血。" % _heal_amount(), Palette.JADE))

	var afford := GameState.gold >= int(offer.price)
	var btn := Ink.button("❖ %d" % offer.price, afford)
	btn.disabled = not afford
	btn.pressed.connect(_buy.bind(index))
	cell.add_child(btn)
	return cell


func _service_card(title: String, desc: String, color: Color) -> Control:
	var panel := Ink.panel("PanelCard")
	panel.custom_minimum_size = Vector2(196, 268)
	var pad := Ink.margin(16)
	panel.add_child(pad)
	var col := Ink.vbox(10)
	pad.add_child(col)
	col.add_child(Ink.spacer(24))
	var t := Ink.label(title, "Title", color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var d := Ink.body(desc)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(d)
	return panel


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
		var cd: CharacterData = Database.get_character(id)
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
