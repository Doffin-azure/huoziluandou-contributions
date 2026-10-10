extends PanelContainer
class_name EnemyView
## 战斗中的敌人：印章 + 血条 + 意图。

signal clicked(index)

var index := 0
var combatant: Combatant
var _seal: SealView
var _name: Label
var _hp: StatBar
var _intent: Label
var _block: Label
var _status: HBoxContainer
var _style: StyleBoxFlat


func setup(p_index: int, p_combatant: Combatant) -> void:
	index = p_index
	combatant = p_combatant


func _ready() -> void:
	theme_type_variation = "PanelCard"
	_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", _style)
	custom_minimum_size = Vector2(164, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	refresh()
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		clicked.emit(index)


func _build() -> void:
	var pad := Ink.margin(10)
	add_child(pad)
	var col := Ink.vbox(4)
	pad.add_child(col)

	var seal_holder := Control.new()
	seal_holder.custom_minimum_size = Vector2(0, 66)
	col.add_child(seal_holder)
	_seal = SealView.new()
	_seal.shape = SealView.Shape.CIRCLE
	_seal.set_anchors_preset(Control.PRESET_CENTER)
	_seal.custom_minimum_size = Vector2(64, 64)
	_seal.position = Vector2(-32, 0)
	seal_holder.add_child(_seal)

	_name = Ink.label("", "Subheading")
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 18)
	col.add_child(_name)

	_hp = StatBar.new()
	col.add_child(_hp)

	var info := Ink.hbox(8)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(info)
	_block = Ink.label("", "", Palette.BLOCK)
	info.add_child(_block)
	_intent = Ink.label("", "", Palette.VERMILION_DK)
	info.add_child(_intent)

	_status = Ink.hbox(6)
	_status.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_status)


func refresh() -> void:
	if combatant == null:
		return
	var ed: EnemyData = combatant.enemy_data
	var col: Color = ed.accent if ed != null else Palette.VERMILION
	_seal.setup(ed.glyph if ed != null else "敌", col, SealView.Shape.CIRCLE)
	_name.text = combatant.display_name
	_hp.setup_bar(combatant.hp, combatant.max_hp, Palette.HP)
	_block.text = "盾 %d" % combatant.block if combatant.block > 0 else ""
	for c in _status.get_children():
		c.queue_free()
	for sid in combatant.statuses.keys():
		var sd: StatusData = Database.get_status(sid)
		if sd != null:
			var l := Ink.label("%s%d" % [sd.glyph, combatant.statuses[sid]], "", sd.color)
			l.add_theme_font_size_override("font_size", 13)
			_status.add_child(l)
	modulate = Color(0.5, 0.48, 0.46, 0.8) if not combatant.is_alive() else Color.WHITE


func set_intent(move: EnemyMoveData) -> void:
	if move == null:
		_intent.text = ""
		return
	_intent.text = "⟶ " + move.intent_text()


func set_targeted(value: bool) -> void:
	_style.border_color = Palette.VERMILION if value else Palette.PAPER_SHADE
	_style.set_border_width_all(3 if value else 2)
