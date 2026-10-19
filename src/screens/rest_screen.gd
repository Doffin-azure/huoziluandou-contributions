extends ScreenBase
## 休整：治疗 / 删字 / 修饰，三选一。

var node: MapNodeData
var _done := false
var _room_session: RefCounted


func build(root: Control) -> void:
	node = params.get("node", null)
	if params.get("room_run",false) and GameState.room_run!=null:
		_room_session = preload("res://src/screens/room_node_session.gd").new(GameState.room_run)

	var main := JourneyStyle.page(root)
	var stats := JourneyStyle.label("气血 %d / %d" % [GameState.player_hp, GameState.player_max_hp], "Stat", JourneyStyle.GOLD)
	main.add_child(JourneyStyle.heading("休整 · 灯下", "灯火未熄。选择一项整备，然后继续前行。", stats))
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(center)
	var row := Ink.hbox(20)
	center.add_child(row)
	row.add_child(_option_card("息", "调息", "回复 %d 点气血。" % _heal_amount(), _do_heal))
	row.add_child(_option_card("删", "删字", "永久移除一枚字，精炼字袋。", _do_remove))
	row.add_child(_option_card("镌", "修饰", "强化一枚字的单字效果。", _do_upgrade))
	main.add_child(JourneyStyle.section("此处可歇脚", "三项整备，只选其一"))
	if _room_session!=null:
		main.add_child(JourneyStyle.button("不休整，继续前行",func(): _room_rest_action({"type":"leave_service"})))
		if _room_session.run.phase=="rest_choose": _resume_room_choice.call_deferred()


func _option_card(seal: String, title: String, desc: String, cb: Callable) -> Control:
	var panel := Ink.panel("PanelCard")
	panel.custom_minimum_size = Vector2(280, 320)
	var col := Ink.vbox(18)
	panel.add_child(col)
	var mark := JourneyStyle.label(seal, "Title", JourneyStyle.GOLD)
	mark.add_theme_font_size_override("font_size", 76)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(mark)
	var t := JourneyStyle.label(title, "Subheading")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var d := JourneyStyle.label(desc, "Muted")
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(d)
	var button := JourneyStyle.button("选择" + title, cb, true)
	button.custom_minimum_size.y = 48 * JourneyStyle.touch_scale(self)
	col.add_child(button)
	return panel


func _heal_amount() -> int:
	return int(round(GameState.player_max_hp * 0.3)) + Relics.rest_bonus()


func _do_heal() -> void:
	if _room_session!=null: _room_rest_action({"type":"rest","kind":"heal"}); return
	if _done:
		return
	_done = true
	GameState.heal(_heal_amount())
	_finish()


func _do_remove() -> void:
	if _room_session!=null: _room_rest_action({"type":"rest","kind":"remove"}); return
	if _done:
		return
	_choose_char("选择要删除的字", "remove")


func _do_upgrade() -> void:
	if _room_session!=null: _room_rest_action({"type":"rest","kind":"upgrade"}); return
	if _done:
		return
	_choose_char("选择要修饰的字", "upgrade")


func _choose_char(title: String, kind: String) -> void:
	var counts := GameState.glyph_counts()
	var chars: Array = []
	for id in counts.keys():
		var cd: CharacterData = Database.get_character_by_glyph(id)
		if cd != null:
			chars.append(cd)
	var overlay := CollectionOverlay.new()
	overlay.setup({
		"title": title,
		"characters": chars,
		"counts": counts,
		"pick_on_click": true,
	})
	overlay.picked.connect(_on_picked.bind(kind))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_picked(ch: CharacterData, kind: String) -> void:
	if _done:
		return
	if kind == "remove":
		GameState.remove_character_id(ch.id)
	else:
		_apply_upgrade(ch)
	_done = true
	_finish()


func _apply_upgrade(ch: CharacterData) -> void:
	var copy: CharacterData = ch.duplicate()
	var new_effects: Array[EffectData] = []
	for eff in ch.solo_effects:
		var e2: EffectData = eff.duplicate() as EffectData
		e2.amount += 2
		new_effects.append(e2)
	copy.solo_effects = new_effects
	# 把字袋中同种字全部替换为强化版
	for inst in GameState.deck:
		if inst.id() == ch.id:
			inst.data = copy


func _finish() -> void:
	if _room_session!=null: goto("res://src/screens/room_map_screen.gd"); return
	GameState.complete_current_node()
	goto("res://src/screens/map_screen.gd")


func _room_rest_action(action: Dictionary) -> void:
	if _done: return
	_room_rest_result(_room_session.apply(action))


func _room_rest_result(result: Dictionary) -> void:
	if not result.ok:
		if _room_session.current() and _room_session.run.phase == "rest_choose": _room_session.apply({"type":"cancel_pick"})
		_done = false
		return
	if _room_session.run.phase == "rest": _done = false; return
	_done = true
	if _room_session.run.phase=="rest_choose": _resume_room_choice()
	else: _finish()


func _resume_room_choice() -> void:
	_done = true
	_room_session.pick(self,"选择要删去的字" if _room_session.run.pending_kind=="remove" else "选择要修饰的字",_room_rest_result)
