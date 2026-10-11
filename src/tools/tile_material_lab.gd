extends Control
## 字块素材实验室：独立预览字块材质与状态，不进入正式战斗流程。

var _grid: GridContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Ink.background(0.28))
	var root := Ink.margin(34)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var col := Ink.vbox(16)
	root.add_child(col)
	var title := Ink.h1("字块素材实验室")
	col.add_child(title)
	col.add_child(Ink.caption("先调材质，再接回字盘。这里展示字块的重量、边缘、压印和状态层。"))
	var line := Ink.hline()
	col.add_child(line)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 22)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_grid)
	_add_sample("普通活字", "击", CharInstance.Owner.PLAYER, false, false, false, false)
	_add_sample("选中 / 朱印", "防", CharInstance.Owner.PLAYER, false, false, false, true)
	_add_sample("敌方铅字", "蚀", CharInstance.Owner.ENEMY, false, false, false, false)
	_add_sample("临时字", "心", CharInstance.Owner.SELF_GENERATED, true, false, false, false)
	_add_sample("融合字", "合化", CharInstance.Owner.PLAYER, false, true, false, false)
	_add_sample("污染字", "热", CharInstance.Owner.PLAYER, false, false, true, false)

func _add_sample(title_text: String, glyph: String, owner: int, temporary: bool, fused: bool, polluted: bool, selected: bool) -> void:
	var card := Ink.panel("PanelInset")
	card.custom_minimum_size = Vector2(190, 155)
	var pad := Ink.margin(12)
	card.add_child(pad)
	var col := Ink.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(col)
	var tile := TileView.new()
	tile.custom_minimum_size = Vector2(92, 92)
	col.add_child(tile)
	var label := Ink.label(title_text, "Subheading")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	_grid.add_child(card)
	var glyph_data := Database.get_character_by_glyph(glyph.substr(0, 1))
	if glyph_data == null:
		return
	var inst := CharInstance.new(glyph_data)
	inst.owner = owner
	inst.temporary = temporary
	if fused:
		inst.fusion.clear()
		inst.fusion.append(CharInstance.new(Database.get_character_by_glyph("化")))
	if polluted:
		inst.pollutions.append("scorch")
	tile.set_instance(inst)
	tile.set_selected(selected)
