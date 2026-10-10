extends ScreenBase
## 休整：治疗 / 删字 / 修饰，三选一。

var node: MapNodeData
var _done := false


func build(root: Control) -> void:
	node = params.get("node", null)

	var main := Ink.vbox(0)
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(main)

	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(14)
	panel.add_child(pad)
	var head := Ink.hbox(16)
	pad.add_child(head)
	head.add_child(Ink.h2("休整 · 灯下"))
	head.add_child(Ink.label("只可选其一。整理你的字袋。", "Muted"))
	head.add_child(Ink.expander())
	head.add_child(Ink.label("血 %d/%d" % [GameState.player_hp, GameState.player_max_hp], "Muted"))
	main.add_child(panel)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(center)
	var row := Ink.hbox(20)
	center.add_child(row)

	row.add_child(_option_card("调息", "回复 %d 点气血。" % _heal_amount(), "治疗", Palette.JADE, _do_heal))
	row.add_child(_option_card("删字", "从字袋中永久移除一枚字，让抽字更纯粹。", "删字", Palette.PLUM, _do_remove))
	row.add_child(_option_card("修饰", "为一枚字加上修饰，使其单字效果更强。", "修饰", Palette.INDIGO, _do_upgrade))


func _option_card(title: String, desc: String, btn_text: String, color: Color, cb: Callable) -> Control:
	var panel := Ink.panel("PanelCard")
	panel.custom_minimum_size = Vector2(240, 300)
	var pad := Ink.margin(18)
	panel.add_child(pad)
	var col := Ink.vbox(12)
	pad.add_child(col)
	var t := Ink.label(title, "Title", color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var d := Ink.body(desc)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(d)
	var b := Ink.button(btn_text, true)
	b.pressed.connect(cb)
	col.add_child(b)
	return panel


func _heal_amount() -> int:
	return int(round(GameState.player_max_hp * 0.3))


func _do_heal() -> void:
	if _done:
		return
	_done = true
	GameState.heal(_heal_amount())
	_finish()


func _do_remove() -> void:
	if _done:
		return
	_choose_char("选择要删除的字", "remove")


func _do_upgrade() -> void:
	if _done:
		return
	_choose_char("选择要修饰的字", "upgrade")


func _choose_char(title: String, kind: String) -> void:
	var counts := GameState.glyph_counts()
	var chars: Array = []
	for id in counts.keys():
		var cd: CharacterData = Database.get_character(id)
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
	GameState.complete_current_node()
	goto("res://src/screens/map_screen.gd")
