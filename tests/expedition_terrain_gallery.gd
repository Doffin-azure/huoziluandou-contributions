extends Control
## Interactive terrain-production check. No changes to normal map generation.
var view: ExpeditionMapView


static func make_fixture() -> Expedition:
	var fixture := Expedition.start(901)
	fixture.themes[0] = "墨池"
	fixture.load_act(1)
	# This fixture authors its own binary topology. Do not retain the unrelated
	# generated courtyard's continuous field and building foundations.
	fixture.m.erase("layout")
	fixture.m.ink.fill(0)
	# Straight shores, both corner signs, single pool, one-cell channel and island.
	for k in [13,14,15,25,26,27,18,19,30,42,43,44,22,61,62,63,64,65,53,69,70,71,81,83,93,94,95]: fixture.m.ink[k] = 1
	fixture.m.node.clear()
	fixture.m.glyph.clear()
	fixture.m.mech.clear()
	fixture.m.obst.clear()
	fixture.m.ambush.clear()
	fixture.pos = 40
	fixture.boss = 82
	for k in MapGen.N:
		fixture.explored[k] = true
		fixture.visible[k] = true
	return fixture


func _ready() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	var title := Label.new()
	title.text = "墨池 · 连续地形拼接检查"
	title.add_theme_color_override("font_color",Color("e8d9b5"))
	title.add_theme_font_size_override("font_size",24)
	column.add_child(title)
	var caption := Label.new()
	caption.text = "直岸 / 外凸角 / 内凹角 / 孤池 / 单格水道 / 孤岛　　滚轮缩放 · 中键拖看"
	caption.add_theme_color_override("font_color",Color("acb5a7"))
	column.add_child(caption)
	view = ExpeditionMapView.new()
	column.add_child(view)
	view.refresh(make_fixture())
	view.show_overview()
