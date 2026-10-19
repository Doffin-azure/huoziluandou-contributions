extends Control
## 遗物图鉴回归：数据驱动卡片、档次/绑定/持有标签、设置入口与 ESC 层级（图鉴先关，设置随后）。

var _pass := 0
var _fail := 0


func _ready() -> void:
	_run.call_deferred()


func _ok(value: bool, message: String) -> void:
	if value:
		_pass += 1
		print("  ok  ", message)
	else:
		_fail += 1
		push_error(message)


func _frames(count := 8) -> void:
	for index in count: await get_tree().process_frame


func _labels(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is Label:
			out.append(c.text)
		out.append_array(_labels(c))
	return out


func _effects(node: Node) -> Array:
	var out: Array = []
	for c in node.get_children():
		if c is EffectText:
			out.append(c)
		out.append_array(_effects(c))
	return out


func _find_button(root: Node, text: String) -> Button:
	for c in root.get_children():
		if c is Button and c.text == text:
			return c
		var found := _find_button(c, text)
		if found != null:
			return found
	return null


func _find_compendium(root: Node) -> RelicCompendiumOverlay:
	for c in root.get_children():
		if c is RelicCompendiumOverlay and not c.is_queued_for_deletion():
			return c
		var found := _find_compendium(c)
		if found != null:
			return found
	return null


func _escape() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = "cancel_selection"
	event.pressed = true
	return event


func _run() -> void:
	GameState.relics.clear()
	GameState.relic_binds.clear()
	GameState.relics.append("strike")

	var settings := SettingsOverlay.new()
	add_child(settings)
	await _frames()

	var btn := _find_button(settings, "遗物图鉴")
	_ok(btn != null, "设置浮层提供「遗物图鉴」入口")
	if btn == null:
		_finish()
		return
	btn.pressed.emit()
	await _frames()

	var comp := _find_compendium(settings)
	_ok(comp != null, "「遗物图鉴」按钮打开图鉴浮层")
	if comp == null:
		_finish()
		return

	var cards := comp._grid.get_children()
	_ok(cards.size() == Relics.DEFS.size(), "卡片数 == Relics.DEFS.size()（%d 件）" % Relics.DEFS.size())

	var ids := {}
	var order_ok := true
	var last_tier := 0
	var last_id := ""
	var names_ok := true
	var descs_ok := true
	var tiers_ok := true
	var binds_ok := true
	var owned_ok := true
	for card in cards:
		var id := str(card.get_meta("relic_id", ""))
		if id.is_empty() or not Relics.DEFS.has(id):
			names_ok = false
			continue
		ids[id] = true
		var tier := int(Relics.TIER.get(id, 2))
		if tier < last_tier or (tier == last_tier and id < last_id):
			order_ok = false
		last_tier = tier
		last_id = id
		var texts := _labels(card)
		if not texts.has(Relics.name_of(id)):
			names_ok = false
		var effect_nodes := _effects(card)
		if effect_nodes.is_empty() or effect_nodes[0]._plain != BattleText.clean(Relics.desc_of(id)):
			descs_ok = false
		var tier_names := {1: "常见", 2: "少见", 3: "稀有"}
		if not texts.has("◆".repeat(tier) + " " + str(tier_names[tier])):
			tiers_ok = false
		if texts.has("需绑定一枚字") != Relics.needs_bind(id):
			binds_ok = false
		if texts.has("持有中") != GameState.has_relic(id):
			owned_ok = false
	_ok(ids.size() == Relics.DEFS.size(), "meta relic_id 齐全且无重复")
	_ok(names_ok, "名称 == Relics.name_of(id)")
	_ok(descs_ok, "描述 _plain == BattleText.clean(Relics.desc_of(id))")
	_ok(order_ok, "按档次升序（再 id）排序")
	_ok(tiers_ok, "档次文本（slab→稀有、sleep→常见 等）")
	_ok(binds_ok, "slab 有「需绑定一枚字」，strike 无")
	_ok(owned_ok, "strike 持有后标「持有中」，slab 无")

	var escape := _escape()
	comp._input(escape)
	settings._input(escape)
	await _frames()
	_ok(_find_compendium(settings) == null, "ESC 先关闭遗物图鉴")
	_ok(is_instance_valid(settings), "同帧派发 ESC 不连带关闭设置（图鉴先）")

	settings._input(escape)
	await _frames()
	_ok(not is_instance_valid(settings), "图鉴关闭后 ESC 才关闭设置")

	settings = SettingsOverlay.new()
	add_child(settings)
	await _frames()
	btn = _find_button(settings, "遗物图鉴")
	if btn == null:
		_finish()
		return
	btn.pressed.emit()
	await _frames()
	comp = _find_compendium(settings)
	if comp == null:
		_finish()
		return
	settings._input(escape)
	comp._input(escape)
	await _frames()
	_ok(_find_compendium(settings) == null, "（设置先）图鉴仍被关闭")
	_ok(is_instance_valid(settings), "同帧派发 ESC 不连带关闭设置（设置先）")

	settings._input(escape)
	await _frames()
	_ok(not is_instance_valid(settings), "（设置先）图鉴关闭后 ESC 才关闭设置")

	_finish()


func _finish() -> void:
	print("[relic_compendium_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
