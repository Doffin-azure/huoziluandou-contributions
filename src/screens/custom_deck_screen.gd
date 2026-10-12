extends ScreenBase
## 自定义模式：自选起始字袋（卡组构筑），然后开局。
## 左键字块 +1，右键 -1；单字上限 3，总数上限 20。

const MAX_PER_GLYPH := 3
const MAX_TOTAL := 20

var _counts: Dictionary = {}     ## glyph -> 数量
var _pool: Array = []            ## CharacterData 列表
var _grid: GridContainer
var _total_label: Label
var _start_btn: Button
var _tiles: Dictionary = {}      ## glyph -> Control（字块）
var _count_labels: Dictionary = {} ## glyph -> Label
var _tile_bgs: Dictionary = {}   ## glyph -> ColorRect


func build(root: Control) -> void:
	for c in Database.characters.values():
		if c.is_pollution or c.pending_design or c.tags.has("enemy") or c.tags.has("彩蛋"):
			continue
		_pool.append(c)
	_pool.sort_custom(func(a, b):
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.glyph < b.glyph)

	var main := Ink.vbox(0)
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(main)
	main.add_child(_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var pad := Ink.margin(20)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = 9
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	pad.add_child(_grid)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_child(center)

	for c in _pool:
		_grid.add_child(_make_tile(c))

	main.add_child(_footer())
	_refresh()


func _header() -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(12)
	panel.add_child(pad)
	var row := Ink.hbox(16)
	pad.add_child(row)
	row.add_child(Ink.h2("自定义构筑"))
	row.add_child(Ink.label("左键加字 · 右键减字　单字上限 %d · 总数上限 %d" % [MAX_PER_GLYPH, MAX_TOTAL], "Muted"))
	row.add_child(Ink.expander())
	_total_label = Ink.label("", "Stat", Palette.GOLD_DK)
	row.add_child(_total_label)
	var back := Ink.button("返回标题")
	back.theme_type_variation = "GhostButton"
	back.pressed.connect(func(): goto("res://src/screens/title_screen.gd"))
	row.add_child(back)
	return panel


func _footer() -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(10)
	panel.add_child(pad)
	var row := Ink.hbox(12)
	pad.add_child(row)
	row.add_child(Ink.expander())
	var clear := Ink.button("清空")
	clear.theme_type_variation = "GhostButton"
	clear.custom_minimum_size = Vector2(90, 44)
	clear.pressed.connect(_on_clear)
	row.add_child(clear)
	_start_btn = Ink.button("以此字袋开始冒险", true)
	_start_btn.custom_minimum_size = Vector2(240, 44)
	_start_btn.pressed.connect(_on_start)
	row.add_child(_start_btn)
	return panel


func _make_tile(c: CharacterData) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(88, 88)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := Ink.make_wood_material()
	mat.set_shader_parameter("tile_size", Vector2(88, 88))
	mat.set_shader_parameter("corner_radius", 10.0)
	bg.material = mat
	holder.add_child(bg)
	var gl := Ink.label(c.glyph, "", Palette.INK)
	gl.set_anchors_preset(Control.PRESET_FULL_RECT)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gl.add_theme_font_size_override("font_size", 40)
	holder.add_child(gl)
	var cnt := Ink.label("", "Muted", Palette.VERMILION)
	cnt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cnt.position = Vector2(-26, -24)
	cnt.add_theme_font_size_override("font_size", 18)
	holder.add_child(cnt)
	holder.tooltip_text = "%s　%s" % [c.glyph, c.description]
	holder.gui_input.connect(_on_tile_input.bind(c))
	_tiles[c.glyph] = holder
	_count_labels[c.glyph] = cnt
	_tile_bgs[c.glyph] = bg
	return holder


func _on_tile_input(event: InputEvent, c: CharacterData) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_add(c.glyph)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_remove(c.glyph)
		accept_event()


func _total() -> int:
	var n := 0
	for g in _counts:
		n += int(_counts[g])
	return n


func _add(glyph: String) -> void:
	if _total() >= MAX_TOTAL:
		return
	if int(_counts.get(glyph, 0)) >= MAX_PER_GLYPH:
		return
	_counts[glyph] = int(_counts.get(glyph, 0)) + 1
	_refresh()


func _remove(glyph: String) -> void:
	if not _counts.has(glyph):
		return
	_counts[glyph] = int(_counts[glyph]) - 1
	if int(_counts[glyph]) <= 0:
		_counts.erase(glyph)
	_refresh()


func _on_clear() -> void:
	_counts.clear()
	_refresh()


func _refresh() -> void:
	var n := _total()
	for glyph in _count_labels:
		var c: int = int(_counts.get(glyph, 0))
		var lab: Label = _count_labels[glyph]
		lab.text = "×%d" % c if c > 0 else ""
		lab.visible = c > 0
		var bg: ColorRect = _tile_bgs[glyph]
		bg.modulate = Color(1, 0.85, 0.7) if c > 0 else Color.WHITE
	_total_label.text = "已选 %d / %d" % [n, MAX_TOTAL]
	if _start_btn != null:
		_start_btn.disabled = n == 0


func _on_start() -> void:
	var glyphs: Array = []
	for g in _counts:
		for i in int(_counts[g]):
			glyphs.append(g)
	if glyphs.is_empty():
		return
	GameState.start_new_run("v03", glyphs)
	goto("res://src/screens/map_screen.gd")
