extends ScreenBase
## 事件：风险与资源取舍。选择一个选项后推进节点。

var node: MapNodeData
var _event: Dictionary
var _done := false
var _pending_removal := false
var _scroll: ScrollContainer
var _page: Control
var _art: TextureRect
var _copy: VBoxContainer
var _eyebrow: Label
var _title: Label
var _body: Label
var _buttons: Array[Button] = []
var _choice_labels: Array[Label] = []
var _ui_scale := 1.0
var _vertical := false
var _layout_key := ""

const EVENTS := [
	{
		"id": "ink_pool",
		"illustration": "res://assets/events/ink_pool.png",
		"title": "墨池遗字",
		"body": "林间有一方墨池，字迹在池底幽幽浮动。\n伸手可取，却要付出代价。",
		"options": [
			{"text": "探手取字（失去 8 生命，获得一枚字）", "primary": true},
			{"text": "掬一捧墨（获得 18 金币）"},
			{"text": "静观而退"},
		],
	},
	{
		"id": "broken_stele",
		"illustration": "res://assets/events/broken_stele.png",
		"title": "断碑",
		"body": "半截石碑立在荒径，\n碑上刻字已被岁月磨平，唯余一道深痕。",
		"options": [
			{"text": "拓下残字（获得一枚稀有字）", "primary": true},
			{"text": "敲下碑角（获得 25 金币，失去 5 生命）"},
			{"text": "绕道而行"},
		],
	},
	{
		"id": "old_bookshop",
		"illustration": "res://assets/events/old_bookshop.png",
		"title": "旧书肆",
		"body": "无人看管的书肆里堆满残页，\n老板的位置只剩一盏将熄的灯。",
		"options": [
			{"text": "撕下一页（删掉字袋中一枚字）", "primary": true},
			{"text": "诵读静心（回复 18 点气血）"},
			{"text": "顺手牵金（获得 14 金币）"},
		],
	},
]


func build(root: Control) -> void:
	node = params.get("node", null)
	_event = EVENTS[GameState.rng.randi_range(0, EVENTS.size() - 1)]

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_page = Control.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_page)
	_art = TextureRect.new()
	_art.texture = load(_event.illustration)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_art)
	_copy = Ink.vbox(14)
	_page.add_child(_copy)
	_eyebrow = Ink.label("行旅 · 事件", "Muted", Palette.INK_FAINT)
	_copy.add_child(_eyebrow)
	_title = Ink.h2(_event.title)
	_copy.add_child(_title)
	_copy.add_child(Ink.hline())
	_body = Ink.body(_event.body)
	_copy.add_child(_body)
	_copy.add_child(Ink.spacer(6))
	for i in _event.options.size():
		var opt: Dictionary = _event.options[i]
		var b := Ink.button("", bool(opt.get("primary", false)))
		b.tooltip_text = opt.text
		var label := Ink.label(opt.text, "", Palette.PAPER if opt.get("primary", false) else Palette.INK)
		label.add_theme_font_override("font", Ink.serif)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(label)
		b.button_down.connect(func(): label.add_theme_color_override("font_color", Palette.PAPER))
		b.button_up.connect(func(): label.add_theme_color_override("font_color", Palette.PAPER if opt.get("primary", false) else Palette.INK))
		b.pressed.connect(_choose.bind(i))
		_copy.add_child(b)
		_buttons.append(b)
		_choice_labels.append(label)
	resized.connect(_layout)
	_copy.minimum_size_changed.connect(_place.call_deferred)
	_layout.call_deferred()


func _layout() -> void:
	if _copy == null or size.x < 1: return
	var key := str(size) + str(get_window().size)
	if key == _layout_key: return
	_layout_key = key
	_vertical = size.x / maxf(1, size.y) < 1.1
	var compact := size.x / maxf(1, size.y) >= 1.95 or size.x < 1100
	_ui_scale = maxf(1.0, size.y / maxf(1, get_window().size.y))
	var margin := 24 * _ui_scale
	var width := minf(size.x - margin * 2, 1080 * _ui_scale)
	var art_width := width if _vertical else width * 0.40
	var gap := 28 * _ui_scale if compact else 56.0
	var copy_width := width if _vertical else width - art_width - gap
	_art.size = Vector2(art_width, minf(art_width, 300 * _ui_scale) if _vertical else art_width)
	_art.position.x = (size.x - width) * 0.5
	_copy.position.x = _art.position.x if _vertical else _art.position.x + art_width + gap
	_copy.size.x = copy_width
	_copy.add_theme_constant_override("separation", int(10 * _ui_scale if compact else 14))
	_eyebrow.add_theme_font_size_override("font_size", int(14 * _ui_scale))
	_title.add_theme_font_size_override("font_size", int((32 if compact else 42) * _ui_scale))
	_body.add_theme_font_size_override("font_size", int((18 if compact else 20) * _ui_scale))
	for index in _buttons.size():
		var label := _choice_labels[index]
		var font_size := int(18 * _ui_scale)
		label.add_theme_font_size_override("font_size", font_size)
		label.offset_left = 18 * _ui_scale
		label.offset_right = -18 * _ui_scale
		label.offset_top = 6 * _ui_scale
		label.offset_bottom = -6 * _ui_scale
		var lines := Ink.serif.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, maxf(1, copy_width - 36 * _ui_scale), font_size)
		_buttons[index].custom_minimum_size.y = maxf(48 * _ui_scale, lines.y + 12 * _ui_scale)
	_place.call_deferred()


func _place() -> void:
	if _copy == null or _art.size.x < 1: return
	var copy_height := _copy.get_combined_minimum_size().y
	var height := _art.size.y + 24 * _ui_scale + copy_height if _vertical else maxf(_art.size.y, copy_height)
	var top := maxf(24 * _ui_scale, (size.y - height) * 0.5)
	_page.custom_minimum_size.y = height + 48 * _ui_scale
	_art.position.y = top
	_copy.position.y = top + _art.size.y + 24 * _ui_scale if _vertical else top + (height - copy_height) * 0.5
	_copy.size.y = copy_height


func _choose(index: int) -> void:
	if _done:
		return
	_done = true
	for button in _buttons: button.disabled = true
	match _event.id:
		"ink_pool":
			if index == 0:
				GameState.damage(8)
				GameState.add_character(_random_char(0, 2), 1)
				_finish()
			elif index == 1:
				GameState.add_gold(18)
				_finish()
			else:
				_finish()
		"broken_stele":
			if index == 0:
				GameState.add_character(_random_char(2, 4), 1)
				_finish()
			elif index == 1:
				GameState.add_gold(25)
				GameState.damage(5)
				_finish()
			else:
				_finish()
		"old_bookshop":
			if index == 0:
				_remove_prompt()
			elif index == 1:
				GameState.heal(18)
				_finish()
			else:
				GameState.add_gold(14)
				_finish()


func _remove_prompt() -> void:
	var counts := GameState.glyph_counts()
	var chars: Array = []
	for glyph in counts.keys():
		var cd: CharacterData = Database.get_character_by_glyph(str(glyph))
		if cd != null:
			chars.append(cd)
	if chars.is_empty():
		_finish()
		return
	var overlay := CollectionOverlay.new()
	_pending_removal = true
	overlay.setup({
		"title": "撕下哪一页？",
		"characters": chars,
		"counts": counts,
		"pick_on_click": true,
	})
	overlay.picked.connect(_on_removed)
	overlay.closed.connect(func():
		if _pending_removal and is_inside_tree():
			_pending_removal = false
			_done = false
			for button in _buttons: button.disabled = false)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_removed(ch: CharacterData) -> void:
	if not _pending_removal: return
	_pending_removal = false
	GameState.remove_character_id(ch.id)
	_finish()


func _random_char(min_rarity: int, max_rarity: int) -> CharacterData:
	var pool: Array = []
	for c in Database.characters.values():
		if c.is_pollution or c.pending_design or c.tags.has("enemy") or c.tags.has("彩蛋"):
			continue
		if c.rarity >= min_rarity and c.rarity <= max_rarity:
			pool.append(c)
	if pool.is_empty():
		pool = Database.characters.values()
	return pool[GameState.rng.randi_range(0, pool.size() - 1)]


func _finish() -> void:
	GameState.complete_current_node()
	goto("res://src/screens/map_screen.gd")
