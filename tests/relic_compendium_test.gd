extends Control
## 遗物子页面的入口、数据、布局、选择模式隔离与关闭行为。
var _pass := 0
var _fail := 0

func _ready() -> void:
	_run.call_deferred()

func _ok(condition: bool, message: String) -> void:
	if condition:
		_pass += 1
		print("  ✓ ", message)
	else:
		_fail += 1
		push_error(message)

func _frames(count := 8) -> void:
	for i in count: await get_tree().process_frame

func _labels(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is Label: out.append(child.text)
		out.append_array(_labels(child))
	return out

func _button(root: Node, text: String) -> Button:
	for child in root.get_children():
		if child is Button and child.text == text: return child
		var found := _button(child, text)
		if found != null: return found
	return null

func _run() -> void:
	GameState.relics.clear()
	GameState.relics.append("strike")
	var before := GameState.relics.duplicate()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var library := CollectionOverlay.new()
	library.setup({"title": "字库图鉴", "subtitle": "%d 种实体字 · %d 个词" % [Database.characters.size() - 1, Database.words.size()], "words": Database.words.values(), "show_relics": true})
	viewport.add_child(library)
	await _frames()
	var tab := _button(library, "遗物")
	_ok(tab != null and _button(library, "实体字") != null and _button(library, "词") != null, "图鉴内提供实体字、词、遗物三个页面")
	if tab == null:
		_finish(); return
	_ok(library._mode == "chars" and not library._relic_page.visible, "默认展示实体字")
	tab.pressed.emit()
	await _frames()
	var page := library._relic_page
	_ok(page.is_visible_in_tree() and not library._scroll.visible, "遗物是图鉴内的独立子页面")
	var cards := page._grid.get_children()
	_ok(cards.size() == Relics.DEFS.size(), "全部 %d 件遗物均有卡片" % Relics.DEFS.size())
	var seen := {}
	var names_ok := true
	var descriptions_ok := true
	var tags_ok := true
	var order_ok := true
	var last_tier := 0
	var last_id := ""
	for card in cards:
		var id := str(card.get_meta("relic_id", ""))
		seen[id] = true
		var labels := _labels(card)
		names_ok = names_ok and labels.has(Relics.name_of(id))
		var effects := card.find_children("*", "RichTextLabel", true, false)
		descriptions_ok = descriptions_ok and not effects.is_empty() and effects[0]._plain == BattleText.clean(Relics.desc_of(id))
		var tier := int(Relics.TIER[id])
		tags_ok = tags_ok and labels.has(page._tier_text(id)) and labels.has("事件专属") == Relics.is_event_relic(id) and labels.has("需绑定一枚字") == Relics.needs_bind(id) and labels.has("持有中") == GameState.has_relic(id)
		order_ok = order_ok and (tier > last_tier or (tier == last_tier and id > last_id))
		last_tier = tier
		last_id = id
	_ok(seen.size() == Relics.DEFS.size(), "遗物 ID 无遗漏或重复")
	_ok(names_ok and descriptions_ok, "名称与完整效果同步当前遗物数据")
	_ok(tags_ok, "档次、事件专属、绑定和持有状态正确")
	_ok(order_ok, "按档次与 ID 稳定排序")
	for dimensions in [Vector2i(1280, 720), Vector2i(640, 480), Vector2i(960, 540)]:
		viewport.size = dimensions
		await _frames(16)
		var bounds := page._scroll.get_global_rect()
		var fits := page._grid.size.x <= bounds.size.x + 1
		var readable := true
		for card in cards:
			fits = fits and card.size.x > 0 and card.get_global_rect().end.x <= bounds.end.x + 1
			var effects := card.find_children("*", "RichTextLabel", true, false)
			readable = readable and not effects.is_empty() and effects[0].size.y > 0 and effects[0].size.x > 0
		_ok(fits and readable, "%s 下卡片不横向溢出，词条有实际显示区域" % dimensions)
		_ok(page._scroll.get_v_scroll_bar().max_value > bounds.size.y, "%s 下可纵向滚动浏览全部遗物" % dimensions)
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--capture-dir="):
				await RenderingServer.frame_post_draw
				var path := argument.trim_prefix("--capture-dir=").path_join("relic-library-%dx%d.png" % [dimensions.x, dimensions.y])
				_ok(viewport.get_texture().get_image().save_png(path) == OK, "保存遗物子页面截图")
	page._scroll.scroll_vertical = int(page._scroll.get_v_scroll_bar().max_value)
	await _frames()
	_ok(cards.back().get_global_rect().end.y <= page._scroll.get_global_rect().end.y + 2, "滚动到底可看完整最后一张卡片")
	var help: EffectText = cards[0].find_children("*", "RichTextLabel", true, false)[0]
	help.open_entry("term:energy")
	await _frames()
	_ok(not help._cards.is_empty(), "遗物词条可打开解释浮层")
	_button(library, "词").pressed.emit()
	await _frames()
	_ok(library._word_grid.is_visible_in_tree() and not page.visible, "可从遗物切回词页面")
	_ok(help._cards.is_empty(), "切换页面时关闭词条解释，避免浮层残留")
	_button(library, "实体字").pressed.emit()
	await _frames()
	_ok(library._grid.is_visible_in_tree() and not page.visible, "可切回实体字页面")
	_ok(GameState.relics == before, "浏览和切换页面不修改持有遗物")
	var picker := CollectionOverlay.new()
	picker.setup({"characters": [], "pick_on_click": true, "show_relics": true})
	viewport.add_child(picker)
	await _frames()
	_ok(_button(picker, "遗物") == null, "选字浮层不出现遗物子页")
	picker.queue_free()
	var settings := SettingsOverlay.new()
	viewport.add_child(settings)
	await _frames()
	_ok(_button(settings, "遗物图鉴") == null, "设置中移除独立遗物图鉴入口")
	settings.queue_free()
	var event := InputEventAction.new()
	event.action = "cancel_selection"
	event.pressed = true
	library._input(event)
	await _frames()
	_ok(not is_instance_valid(library), "ESC 关闭整个图鉴，不残留独立遗物浮层")
	viewport.queue_free()
	_finish()

func _finish() -> void:
	print("[relic_compendium_test] PASS=%d FAIL=%d" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)
