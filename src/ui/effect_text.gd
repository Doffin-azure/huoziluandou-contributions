extends RichTextLabel
class_name EffectText
## 可复用的词条文本。浮层属于来源控件，离开界面即释放；只读取说明。

var _plain := ""
var _source_word: WordData
var _local_entries: Dictionary = {}
var _layer: CanvasLayer
var _cards: Array[PanelContainer] = []
var _hovered: Dictionary = {}
var _pinned := false
var _away := 0.0
var _viewport_size := Vector2.ZERO


func _ready() -> void:
	if JourneyStyle.is_active(self): text = _journey_links(text)


func _init() -> void:
	bbcode_enabled = true
	fit_content = true
	scroll_active = false
	selection_enabled = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_hover_started.connect(_on_link_entered.bind(0))
	meta_hover_ended.connect(_on_link_exited.bind(0))
	meta_clicked.connect(_on_link_clicked.bind(0))
	set_process(false)
	set_process_input(false)


func set_effect_text(value: String, number_size := 0, source_word: WordData = null, local_entries: Dictionary = {}) -> void:
	value = BattleText.clean(value)
	if value != _plain or source_word != _source_word or local_entries != _local_entries:
		close_help()
	_plain = value
	_source_word = source_word
	_local_entries = local_entries.duplicate(true)
	text = _format(value, number_size)
	if source_word != null and EffectGlossary.brief(source_word) != source_word.describe():
		text += "\n[font_size=%d]%s[/font_size]" % [mini(get_theme_font_size("normal_font_size"), 16), EffectGlossary.link("完整词效", "word:" + source_word.word)]
	if JourneyStyle.is_active(self): text = _journey_links(text)


func _format(value: String, number_size := 0, exclude := "") -> String:
	var formatted := EffectGlossary.format_text(BattleText.clean(value), number_size, exclude, _local_entries)
	return _journey_links(formatted) if JourneyStyle.is_active(self) else formatted


func _journey_links(value: String) -> String:
	return value.replace(Palette.INDIGO.to_html(false), JourneyStyle.GOLD.to_html(false)).replace(Palette.VERMILION_DK.to_html(false), "e5977e")


func _on_link_entered(meta: Variant, depth: int) -> void:
	if _touch_mode(): return
	_hovered[depth] = str(meta)
	open_entry(str(meta), depth)


func _on_link_exited(meta: Variant, depth: int) -> void:
	if _hovered.get(depth, "") == str(meta):
		_hovered.erase(depth)


func _on_link_clicked(meta: Variant, depth: int) -> void:
	open_entry(str(meta), depth)
	_pinned = not _cards.is_empty()
	accept_event()


func _touch_mode() -> bool:
	return DisplayServer.is_touchscreen_available() or BattleTouchLayout.test_dpi > 0


func open_entry(meta: String, depth := 0) -> void:
	var info: Dictionary = _local_entries.get(meta, {})
	if info.is_empty(): info = EffectGlossary.entry(meta)
	if info.is_empty() or not is_inside_tree() or depth > _cards.size():
		return
	if depth == 0:
		for other in get_tree().get_nodes_in_group("effect_help_open"):
			if other != self and other.get_viewport() == get_viewport():
				other.close_help()
	if depth < _cards.size() and _cards[depth].get_meta("entry") == meta:
		_away = 0.0
		return
	# 子词条形成一条阅读路径，最多同时显示三层；再深入替换最深一层。
	depth = mini(depth, 2)
	while _cards.size() > depth:
		var old := _cards.pop_back() as PanelContainer
		old.hide()
		old.queue_free()
	for level in _hovered.keys():
		if level > depth:
			_hovered.erase(level)
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 90
		add_child(_layer)
	if not is_in_group("effect_help_open"):
		add_to_group("effect_help_open")
	_viewport_size = get_viewport_rect().size
	var help_scale := JourneyStyle.touch_scale(self)
	var width := minf(380.0 * help_scale, _viewport_size.x - 24.0)
	var card := Ink.panel("PanelCard")
	# CanvasLayer 不继承 Control 的主题链，浮层需显式使用当前游戏主题。
	var journey := JourneyStyle.is_active(self)
	card.theme = JourneyStyle.get_theme() if journey else Ink.theme
	card.name = "EffectHelp"
	card.set_meta("entry", meta)
	card.custom_minimum_size.x = width
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBox
	if journey:
		style = JourneyStyle.frame("panel", 10 * help_scale)
	else:
		var paper := (Ink.theme.get_stylebox("panel", "PanelCard") as StyleBoxFlat).duplicate()
		paper.bg_color = Palette.PAPER
		paper.border_color = Palette.INDIGO
		paper.set_border_width_all(1)
		paper.shadow_color = Palette.SHADOW
		paper.shadow_size = 8
		style = paper
	style.set_content_margin_all(10 * help_scale)
	card.add_theme_stylebox_override("panel", style)
	_layer.add_child(card)
	_cards.append(card)
	var col := Ink.vbox(int(8 * help_scale))
	card.add_child(col)
	var head := Ink.hbox(8)
	col.add_child(head)
	var title := Ink.label(str(info.title), "Subheading", JourneyStyle.GOLD if journey else Palette.INDIGO)
	title.add_theme_font_size_override("font_size", int(20 * help_scale))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	var close := Ink.button("×")
	close.custom_minimum_size = Vector2(48, 48) * help_scale
	close.add_theme_font_size_override("font_size", int(18 * help_scale))
	close.pressed.connect(close_help)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width - 20 * help_scale, 64)
	col.add_child(scroll)
	var description := RichTextLabel.new()
	description.bbcode_enabled = true
	description.fit_content = true
	description.scroll_active = false
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.mouse_filter = Control.MOUSE_FILTER_STOP
	description.add_theme_font_size_override("normal_font_size", int(18 * help_scale))
	description.text = _format(str(info.text), 0, meta)
	description.meta_hover_started.connect(_on_link_entered.bind(depth + 1))
	description.meta_hover_ended.connect(_on_link_exited.bind(depth + 1))
	description.meta_clicked.connect(_on_link_clicked.bind(depth + 1))
	scroll.add_child(description)
	var hint := Ink.label("点按词条查看 · ×关闭" if _touch_mode() else "悬浮查看 · 点按词条固定 · ×关闭", "Muted")
	hint.add_theme_font_size_override("font_size", int(13 * help_scale))
	col.add_child(hint)
	card.modulate.a = 0.0
	_layout_card.call_deferred(card, scroll, description, get_global_mouse_position(), help_scale)
	_away = 0.0
	set_process(true)
	set_process_input(true)


func _layout_card(card: PanelContainer, scroll: ScrollContainer, description: RichTextLabel, anchor: Vector2, help_scale: float) -> void:
	await get_tree().process_frame
	if not is_instance_valid(card) or not is_inside_tree() or not card.visible:
		return
	scroll.custom_minimum_size.y = minf(description.get_content_height() + 4.0 * help_scale, maxf(48.0 * help_scale, minf(400.0 * help_scale, get_viewport_rect().size.y - 120.0 * help_scale)))
	card.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(card) or not is_inside_tree() or not card.visible:
		return
	var bounds := get_viewport_rect().size
	var at := anchor + Vector2(18, 20)
	if at.x + card.size.x > bounds.x - 12:
		at.x = anchor.x - card.size.x - 18
	if at.y + card.size.y > bounds.y - 12:
		at.y = anchor.y - card.size.y - 12
	card.position = _avoid_status(at, card.size, bounds, 6 * help_scale)
	card.modulate.a = 1.0


func _avoid_status(preferred: Vector2, dimensions: Vector2, bounds: Vector2, gap: float) -> Vector2:
	var clamp_point := func(point: Vector2) -> Vector2:
		return Vector2(clampf(point.x,12,maxf(12,bounds.x-dimensions.x-12)),clampf(point.y,12,maxf(12,bounds.y-dimensions.y-12)))
	var desired: Vector2 = clamp_point.call(preferred)
	var obstacles: Array[Rect2] = []
	for control in get_tree().get_nodes_in_group("effect_help_avoid"):
		if control is Control and control.get_viewport()==get_viewport() and control.is_visible_in_tree():
			var rect: Rect2 = control.get_global_rect()
			if rect.has_area(): obstacles.append(rect.grow(gap))
	var candidates: Array[Vector2] = [desired]
	for obstacle: Rect2 in obstacles:
		candidates.append(clamp_point.call(Vector2(desired.x,obstacle.end.y)))
		candidates.append(clamp_point.call(Vector2(desired.x,obstacle.position.y-dimensions.y)))
		candidates.append(clamp_point.call(Vector2(obstacle.end.x,desired.y)))
		candidates.append(clamp_point.call(Vector2(obstacle.position.x-dimensions.x,desired.y)))
	var best := desired
	var best_overlap := INF
	var best_distance := INF
	for candidate: Vector2 in candidates:
		var box := Rect2(candidate,dimensions)
		var overlap := 0.0
		for obstacle: Rect2 in obstacles: overlap += box.intersection(obstacle).get_area()
		var distance := candidate.distance_squared_to(desired)
		if overlap < best_overlap or is_equal_approx(overlap,best_overlap) and distance < best_distance:
			best = candidate; best_overlap = overlap; best_distance = distance
	return best


func _process(delta: float) -> void:
	_update_help(delta, get_global_mouse_position())


func _update_help(delta: float, pointer: Vector2) -> void:
	if not is_visible_in_tree() or _viewport_size != get_viewport_rect().size:
		close_help()
		return
	if _pinned or not _hovered.is_empty() or contains_pointer(pointer, 12):
		_away = 0.0
	else:
		_away += delta
		if _away >= 0.3:
			close_help()


func _input(event: InputEvent) -> void:
	# Handle the native finger once; its earlier emulated press must neither
	# close the help nor reach an underlying GUI action.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if not contains_pointer(event.position) and not get_global_rect().has_point(event.position): get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cancel_selection"):
		close_help()
		get_viewport().set_input_as_handled()
	elif (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		if not contains_pointer(event.position) and not get_global_rect().has_point(event.position):
			close_help()
			get_viewport().set_input_as_handled()


func contains_pointer(point: Vector2, margin := 0.0) -> bool:
	for card in _cards:
		if card.visible and card.get_global_rect().grow(margin).has_point(point):
			return true
	return false


static func blocks_pointer(viewport: Viewport, _point: Vector2) -> bool:
	for control in viewport.get_tree().get_nodes_in_group("effect_help_open"):
		if control.get_viewport() == viewport and control.is_visible_in_tree():
			return true
	return false


func close_help() -> void:
	for card in _cards:
		card.hide()
		card.queue_free()
	_cards.clear()
	_hovered.clear()
	_pinned = false
	_away = 0.0
	if is_in_group("effect_help_open"):
		remove_from_group("effect_help_open")
	set_process(false)
	set_process_input(false)
