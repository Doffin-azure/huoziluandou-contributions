extends PanelContainer
class_name PathBar
## 已选路径：把当前连线得到的字串以“字块缩略”形式展示。

var _title: Label
var _row: HBoxContainer


func _ready() -> void:
	theme_type_variation = "PanelInset"
	var pad := Ink.margin(8)
	add_child(pad)
	var col := Ink.vbox(4)
	pad.add_child(col)
	_title = Ink.caption("已选路径")
	col.add_child(_title)
	_row = Ink.hbox(6)
	col.add_child(_row)
	update([])


func update(glyphs: Array) -> void:
	if _row == null:
		return
	for c in _row.get_children():
		c.queue_free()
	_title.text = "已选路径（%d）" % glyphs.size()
	if glyphs.is_empty():
		_row.add_child(Ink.label("拖动字盘连词", "Muted"))
		return
	for g in glyphs:
		_row.add_child(_chip(str(g)))


func _chip(glyph: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PAPER_WARM
	sb.set_corner_radius_all(8 + Palette.CORNER_BONUS)
	sb.set_border_width_all(2)
	sb.border_color = Palette.BORDER
	sb.set_content_margin_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(40, 44)
	var l := Ink.label(glyph, "", Palette.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	p.add_child(l)
	return p
