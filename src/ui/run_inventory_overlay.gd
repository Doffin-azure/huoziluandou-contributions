extends Control
## 只读行囊：牌库按永久实体逐枚展示，不合并有不同强化的同名字。
var initial_tab := "deck"
var _tab := ""
var _body: VBoxContainer
var _tabs: Dictionary = {}
var _summary: Label
var _was_paused := false
var _previous_focus: Control


static func tray() -> Array:
	if GameState.room_run != null: return GameState.room_run.tray
	if GameState.expedition != null: return GameState.expedition.tray
	return []


static func tray_capacity() -> int:
	if GameState.room_run != null: return 6
	if GameState.expedition != null: return GameState.expedition.tray_cap()
	return 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	_previous_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	tree_exiting.connect(func():
		get_tree().paused = _was_paused
		if is_instance_valid(_previous_focus): _previous_focus.grab_focus.call_deferred())
	JourneyStyle.apply(self)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.07, 0.09, 0.92)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var margin := Ink.margin(16)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(margin)
	var panel := Ink.panel("PanelCard")
	margin.add_child(panel)
	var col := Ink.vbox(10)
	panel.add_child(col)
	var header := Ink.hbox(12)
	col.add_child(header)
	header.add_child(JourneyStyle.label("行囊", "Heading", JourneyStyle.GOLD))
	header.add_child(Ink.expander())
	var close := JourneyStyle.button("关闭", _close)
	close.custom_minimum_size.y = 48 * JourneyStyle.touch_scale(self)
	header.add_child(close)
	_summary = JourneyStyle.label("牌库 %d 枚 · 遗物 %d 件 · 铜钱 %d · 字匣 %d 枚" % [GameState.deck_size(), GameState.relics.size(), GameState.gold, tray().size()], "Muted")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_summary)
	var tabs := HBoxContainer.new()
	col.add_child(tabs)
	for entry in [["deck", "牌库"], ["relics", "遗物"], ["gold", "铜钱"], ["tray", "字匣"]]:
		var button := JourneyStyle.button(entry[1], show_tab.bind(entry[0]))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48 * JourneyStyle.touch_scale(self)
		tabs.add_child(button)
		_tabs[entry[0]] = button
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_body = Ink.vbox(10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)
	show_tab(initial_tab)
	close.grab_focus()


func show_tab(tab: String) -> void:
	_tab = tab
	for child in _body.get_children():
		_body.remove_child(child); child.queue_free()
	for key in _tabs: _tabs[key].theme_type_variation = "PrimaryButton" if key == tab else "GhostButton"
	match tab:
		"deck":
			if GameState.deck.is_empty(): _entry("牌库为空", "开始冒险后可查看本局持有的所有实体字。")
			for inst: CharInstance in GameState.deck:
				_entry("%s · %s　#%d" % [inst.glyph(), inst.data.pinyin, inst.uid], inst.describe())
		"relics":
			if GameState.relics.is_empty(): _entry("暂无遗物", "获得的遗物会按获得顺序显示在这里和常驻栏中。")
			for id: String in GameState.relics:
				var body := Relics.desc_of(id)
				if Relics.needs_bind(id):
					var inst := GameState.relic_bound_inst(id)
					body += "\n绑定：【%s】 #%d" % [inst.glyph(), inst.uid] if inst != null else "\n绑定的字不在牌库中，当前不生效。"
				if id == "egg":
					var interval := maxi(1, BattleBalance.i("egg_interval", Relics.EGG_EVERY))
					body += "\n获胜进度：%d / %d" % [int(GameState.relic_counters.get(id, 0)) % interval, interval]
				_entry(Relics.name_of(id), body)
		"gold": _entry("铜钱 %d" % GameState.gold, "本局当前持有的铜钱，可在商店和部分事件中使用。")
		"tray":
			var capacity := tray_capacity()
			if capacity == 0: _entry("当前模式没有字匣", "获得的字直接收入牌库。")
			else:
				_entry("字匣 %d / %d" % [tray().size(), capacity], "这里可查看暂存的字；回到地图可整理字匣与版面。")
				if tray().is_empty(): _entry("字匣为空", "尚未暂存任何字。")
				for glyph: String in tray():
					var data := Database.get_character_by_glyph(glyph)
					_entry(glyph, data.description if data != null else "暂无说明。")


func _entry(title: String, body: String) -> void:
	var panel := Ink.panel("PanelInset")
	_body.add_child(panel)
	var col := Ink.vbox(6)
	panel.add_child(col)
	var label := JourneyStyle.label(title, "Subheading", JourneyStyle.GOLD)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(label)
	var effects := EffectText.new()
	effects.set_effect_text(body)
	effects.add_theme_font_size_override("normal_font_size", int(17 * JourneyStyle.touch_scale(self)))
	col.add_child(effects)


func _close() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_selection") or event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
