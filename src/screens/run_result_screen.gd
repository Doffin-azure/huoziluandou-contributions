extends ScreenBase
## 成功与失败统一结算；记录结束时的构筑与本局新解锁成就。
var result: Dictionary = {}
var _return_button: Button
var _leaving := false


func build(root: Control) -> void:
	if GameState.last_run_result.is_empty():
		var won: bool = bool(params.get("victory", false)) or (GameState.room_run != null and GameState.room_run.phase == "victory") or (GameState.expedition != null and GameState.expedition.won) or GameState.run_complete()
		Achievements.finish_run(won)
		GameState.last_run_result = _snapshot(won)
		GameState.end_run(won)
	result = GameState.last_run_result.duplicate(true)
	var page := JourneyStyle.page(root)
	var won: bool = bool(result.get("victory", false))
	var detail := ("三幕已尽，字阵大成。" if won else "字散墨枯，这一程到此为止。") + " 本局新解锁%d项成就。" % (result.get("achievements", []) as Array).size()
	page.add_child(JourneyStyle.heading("通关结算 · 破狱而行" if won else "失败结算 · 此程止步", detail, null))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var panel := Ink.panel("PanelCard")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	var col := Ink.vbox(14)
	panel.add_child(col)
	var lines: Array[String] = ["%s　·　第%d幕" % [str(result.mode), int(result.act)]]
	if not str(result.location).is_empty(): lines.append(("完成于：" if won else "止步于：") + str(result.location))
	if not str(result.enemies).is_empty(): lines.append("本场敌人：" + str(result.enemies) + ("　·　%d回合" % int(result.turn) if int(result.turn) > 0 else ""))
	elif int(result.turn) > 0: lines.append("本场战斗：%d回合" % int(result.turn))
	lines.append("经历战斗：%d场　·　铜钱：%d" % [int(result.battles), int(result.gold)])
	lines.append("牌库：%d枚　遗物：%d件　字匣：%d枚" % [int(result.deck_count), result.relics.size(), result.tray.size()])
	var summary := EffectText.new()
	summary.name = "RunSummary"
	summary.add_theme_font_size_override("normal_font_size", int(20 * JourneyStyle.touch_scale(self)))
	summary.set_effect_text("\n".join(lines))
	col.add_child(summary)
	col.add_child(JourneyStyle.label("本局新解锁成就 · %d项" % (result.get("achievements", []) as Array).size(), "Subheading", JourneyStyle.GOLD))
	if (result.get("achievements", []) as Array).is_empty():
		col.add_child(JourneyStyle.label("本局未解锁新成就。", "Muted"))
	for definition: Dictionary in result.get("achievements", []):
		var card := Ink.panel("PanelInset")
		card.name = "Achievement_" + str(definition.id)
		col.add_child(card)
		var row := Ink.hbox(14)
		card.add_child(row)
		row.add_child(AchievementArt.icon(definition, 64 * JourneyStyle.touch_scale(self)))
		var text := Ink.vbox(4)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var name_label := JourneyStyle.label(AchievementArt.title(definition), "Subheading", JourneyStyle.GOLD)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(name_label)
		var description := JourneyStyle.label(str(definition.description), "Muted")
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(description)
	var achievements := JourneyStyle.button("查看全部成就 · 已解锁%d项" % int(result.get("achievement_total", 0)), _open_achievements)
	col.add_child(achievements)
	if not result.relics.is_empty():
		col.add_child(JourneyStyle.label("本局遗物", "Subheading", JourneyStyle.GOLD))
		var relics := EffectText.new()
		relics.set_effect_text("\n".join(result.relics))
		col.add_child(relics)
	var hint := JourneyStyle.label("本次冒险已结束。可通过顶部行囊查看本局构筑，确认后返回主菜单。", "Muted")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(hint)
	_return_button = JourneyStyle.button("返回主菜单", _return_to_title, true)
	_return_button.custom_minimum_size.y = 48 * JourneyStyle.touch_scale(self)
	page.add_child(_return_button)
	_return_button.grab_focus.call_deferred()


func _snapshot(won: bool) -> Dictionary:
	var mode := "经典冒险"
	var act := GameState.act_index
	var location := str(params.get("location", ""))
	var tray: Array = []
	if GameState.room_run != null:
		mode = "主线冒险"
		tray = GameState.room_run.tray.duplicate()
		if location.is_empty(): location = str(GameState.room_run.layout.rooms[GameState.room_run.current_room].name)
	elif GameState.expedition != null:
		mode = "墨途远征"
		act = GameState.expedition.act
		tray = GameState.expedition.tray.duplicate()
	return {"victory":won, "achievements":Achievements.run_unlocks(), "achievement_total":Achievements.profile.unlocked.size(),
		"mode":mode, "act":mini(3, act), "location":location,
		"enemies":str(params.get("enemies", "")), "turn":int(params.get("turn", 0)),
		"battles":GameState.battle_sequence, "gold":GameState.gold, "deck_count":GameState.deck_size(),
		"relics":GameState.relics.map(func(id): return Relics.text(id)), "tray":tray}


func _open_achievements() -> void:
	for child in get_children():
		if child is AchievementOverlay: return
	var overlay := AchievementOverlay.new()
	overlay.z_index = 71
	_return_button.disabled = true
	overlay.tree_exited.connect(func():
		if is_inside_tree():
			_return_button.disabled = false
			_return_button.grab_focus())
	add_child(overlay)
	var close_buttons := overlay.find_children("*", "Button", true, false)
	if not close_buttons.is_empty(): close_buttons[0].grab_focus()


func _return_to_title() -> void:
	if _leaving: return
	_leaving = true
	GameState.room_run = null
	GameState.expedition = null
	goto("res://src/screens/title_screen.gd")
