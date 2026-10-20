extends ScreenBase
## 自定义模式：自选起始字袋（卡组构筑），然后开局。
## 左键字块 +1，右键 -1；单字上限 3，总数上限 20。

const MAX_PER_GLYPH := 3
const MAX_TOTAL := 20

var _remove_mode := false
var _inspect_mode := false
var _taps := {}
var _mobile := false
var _counts: Dictionary = {}     ## glyph -> 数量
var _pool: Array = []            ## CharacterData 列表
var _grid: GridContainer
var _total_label: Label
var _start_btn: Button
var _tiles: Dictionary = {}      ## glyph -> Control（字块）
var _count_labels: Dictionary = {} ## glyph -> Label
var _tile_bgs: Dictionary = {}   ## glyph -> Panel


func build(root: Control) -> void:
	for c in Database.characters.values():
		if c.is_pollution or c.pending_design or c.tags.has("enemy") or c.tags.has("彩蛋") or c.tags.has("event"):
			continue
		_pool.append(c)
	_pool.sort_custom(func(a, b):
		if a.rarity != b.rarity:
			return a.rarity < b.rarity
		return a.glyph < b.glyph)

	_mobile = get_viewport_rect().size.x / JourneyStyle.touch_scale(self) < 1100
	var main := JourneyStyle.page(root)

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


	for c in _pool:
		_grid.add_child(_make_tile(c))

	main.add_child(_footer())
	_refresh()
	_grid.resized.connect(_layout_grid)
	_layout_grid.call_deferred()


func _layout_grid() -> void:
	_grid.columns = maxi(1, int((_grid.size.x + 12) / ((64 if _mobile else 88) * JourneyStyle.touch_scale(self) + 12)))


func _header() -> Control:
	var panel := Ink.panel("PanelInset")
	var pad := Ink.margin(12)
	panel.add_child(pad)
	var row := JourneyStyle.flow(12)
	pad.add_child(row)
	var titles := Ink.vbox(0)
	row.add_child(titles)
	var title := Ink.h2("自定义构筑")
	if _mobile: title.add_theme_font_size_override("font_size", int(20 * JourneyStyle.touch_scale(self)))
	titles.add_child(title)
	if _mobile:
		var hint := Ink.label("点字加减 · 开启「查看字效」后点字阅读", "Muted")
		hint.add_theme_font_size_override("font_size", int(12 * JourneyStyle.touch_scale(self)))
		titles.add_child(hint)
	var instructions := Ink.label("左键加字 · 右键减字　单字上限 %d · 总数上限 %d" % [MAX_PER_GLYPH, MAX_TOTAL], "Muted")
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.custom_minimum_size.x = 260 * JourneyStyle.touch_scale(self)
	if not _mobile: row.add_child(instructions)
	else: instructions.queue_free()
	_total_label = Ink.label("", "Stat", JourneyStyle.GOLD)
	if _mobile: _total_label.add_theme_font_size_override("font_size", int(16 * JourneyStyle.touch_scale(self)))
	row.add_child(_total_label)
	var back := Ink.button("返回标题")
	back.custom_minimum_size.y = 48 * JourneyStyle.touch_scale(self)
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
	if _mobile:
		var mode := Ink.button("加字模式")
		mode.custom_minimum_size = Vector2(100,48) * JourneyStyle.touch_scale(self)
		mode.pressed.connect(func():
			_remove_mode = not _remove_mode
			mode.text = "减字模式" if _remove_mode else "加字模式"
			mode.theme_type_variation = "DangerButton" if _remove_mode else "GhostButton")
		row.add_child(mode)
	var inspect := Ink.button("查看字效")
	inspect.toggle_mode = true
	inspect.custom_minimum_size = Vector2(100, 48) * JourneyStyle.touch_scale(self)
	inspect.toggled.connect(func(value):
		_inspect_mode = value
		inspect.text = "字效查看中" if value else "查看字效"
		inspect.theme_type_variation = "PrimaryButton" if value else "GhostButton")
	row.add_child(inspect)
	row.add_child(Ink.expander())
	var clear := Ink.button("清空")
	clear.theme_type_variation = "GhostButton"
	clear.custom_minimum_size = Vector2(90, 48 * JourneyStyle.touch_scale(self))
	clear.pressed.connect(_on_clear)
	row.add_child(clear)
	_start_btn = Ink.button("以此字袋开始冒险", true)
	_start_btn.custom_minimum_size = Vector2(240, 48 * JourneyStyle.touch_scale(self))
	_start_btn.pressed.connect(_on_start)
	row.add_child(_start_btn)
	return panel


func _make_tile(c: CharacterData) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(64 if _mobile else 88, 64 if _mobile else 88) * JourneyStyle.touch_scale(self)
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Let the ScrollContainer receive the emulated press/motion; TouchTap
	# accepts only the final native tap, so dragging can scroll this list.
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", JourneyStyle.frame("paper", 8))
	holder.add_child(bg)
	var gl := Ink.label(c.glyph, "", JourneyStyle.DARK_TEXT)
	gl.set_anchors_preset(Control.PRESET_FULL_RECT)
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gl.add_theme_font_size_override("font_size", int((30 if _mobile else 40) * JourneyStyle.touch_scale(self)))
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(gl)
	var cnt := Ink.label("", "Muted", JourneyStyle.TEXT)
	cnt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cnt.position = Vector2(-26, -24) * JourneyStyle.touch_scale(self)
	cnt.add_theme_font_size_override("font_size", int(14 * JourneyStyle.touch_scale(self)))
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(cnt)
	holder.tooltip_text = "%s　%s" % [c.glyph, c.description]
	holder.gui_input.connect(_on_tile_input.bind(c))
	_taps[c.glyph] = TouchTap.new()
	_tiles[c.glyph] = holder
	_count_labels[c.glyph] = cnt
	_tile_bgs[c.glyph] = bg
	return holder


func _on_tile_input(event: InputEvent, c: CharacterData) -> void:
	if _taps[c.glyph].matches(event, _tiles[c.glyph]):
		if _inspect_mode:
			ChoiceOverlay.show_details(self, "【%s】字效" % c.glyph, c.description + "\n\n当前字袋：%d 枚。关闭说明后可继续加减字。" % int(_counts.get(c.glyph, 0)))
			return
		if _remove_mode: _remove(c.glyph)
		else: _add(c.glyph)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
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
		var bg: Panel = _tile_bgs[glyph]
		bg.add_theme_stylebox_override("panel", JourneyStyle.frame("primary" if c > 0 else "paper", 8))
		var gl: Label = _tiles[glyph].get_child(1)
		gl.add_theme_color_override("font_color", JourneyStyle.TEXT if c > 0 else JourneyStyle.DARK_TEXT)
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
	var run = load("res://src/expedition/room_run_state.gd").new()
	run.reset({"seed":int(Time.get_unix_time_from_system())^int(Time.get_ticks_usec()),"deck":glyphs,"layout":"node_graph"})
	run.autosave = not bool(GameState.get_meta("courtyard_preview",false))
	if run.autosave: run.save_run()
	goto("res://src/screens/room_map_screen.gd")
