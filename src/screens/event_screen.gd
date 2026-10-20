extends ScreenBase
## 事件：风险与资源取舍。选择一个选项后推进节点。
## 有一定概率多出一个「拾得遗物」选项。

var node: MapNodeData
var _event: Dictionary
var _done := false
var _pending_removal := false
var _pending_effect: Dictionary = {}
var _picker_generation := 0
var _scroll: ScrollContainer
var _page: Control
var _art: TextureRect
var _copy: VBoxContainer
var _eyebrow: Label
var _title: Label
var _body: Label
var _notice: Label
var _buttons: Array[Button] = []
var _choice_labels: Array[Label] = []
var _leave_button: Button
var _ui_scale := 1.0
var _page_margin := 24.0
var _vertical := false
var _layout_key := ""
var _room_session: RefCounted

const RELIC_CHANCE := 0.4

const EventEffects := preload("res://src/core/event_effects.gd")
const LANTERN := preload("res://src/data/lantern_riddles.gd")
const SHEFU := preload("res://src/data/shefu_rewards.gd")
const EventArt := preload("res://src/core/event_art.gd")
const EVENTS: Array = preload("res://src/data/event_catalog.gd").EVENTS


func save_checkpoint() -> Dictionary:
	if _done or _pending_removal: return {}
	var snapshot := super.save_checkpoint()
	snapshot.screen = {"event": _event}
	return snapshot



func build(root: Control) -> void:
	node = params.get("node", null)
	var saved: Dictionary = params.get("_saved_screen", {})
	if saved.has("event"):
		_event = saved.event
	else:
		if params.get("room_run",false) and GameState.room_run!=null:
			_room_session = preload("res://src/screens/room_node_session.gd").new(GameState.room_run)
			_event = _room_session.run.current_event()
		else:
			var pool: Array = EventEffects.all().filter(func(event): return EventEffects.condition_met(event.get("requires", {})))
			if pool.is_empty(): pool = EventEffects.all()
			_event = EventEffects.node(pool[GameState.rng.randi_range(0, pool.size() - 1)])

		if _room_session == null:
			var side := RelicRewardFlow.side_rng("event")
			if side.randf() < RELIC_CHANCE:
				var found := RelicRewardFlow.roll(1, side)
				if not found.is_empty():
					_event.options.append({"text": "拾得遗物「%s」（%s）" % [Relics.name_of(found[0]), Relics.desc_of(found[0])], "relic": found[0]})

		_event = LANTERN.fill(_event, GameState.rng)
		_event = SHEFU.fill(_event, GameState.rng)

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
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_art)
	_copy = Ink.vbox(14)
	_page.add_child(_copy)
	_eyebrow = Ink.label("行旅 · 事件", "Muted", JourneyStyle.GOLD)
	_copy.add_child(_eyebrow)
	_title = Ink.h2(_event.title)
	_copy.add_child(_title)
	_copy.add_child(Ink.hline())
	_body = Ink.body(_event.body)
	_copy.add_child(_body)
	_notice = Ink.caption("")
	_notice.add_theme_color_override("font_color", JourneyStyle.RED)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.hide()
	_copy.add_child(_notice)
	_copy.add_child(Ink.spacer(6))
	_render_event()
	resized.connect(_layout)
	_copy.minimum_size_changed.connect(_place.call_deferred)
	_layout.call_deferred()
	if _room_session!=null and _room_session.run.phase=="event_choose": _resume_room_choice.call_deferred()


func _render_event() -> void:
	_notice.hide()
	for button in _buttons: _copy.remove_child(button); button.queue_free()
	_buttons.clear(); _choice_labels.clear()
	if is_instance_valid(_leave_button):
		_copy.remove_child(_leave_button); _leave_button.queue_free()
	_leave_button = null
	# Saved story/options stay intact; newly added art is resolved from the current catalog.
	var event_id := str(_event.get("id",""))
	var definition: Dictionary = EventEffects.get_event(event_id)
	var path := str(_event.get("illustration",definition.get("illustration","")))
	if path.is_empty():
		path = EventArt.path_for(event_id)
	_art.texture = load(path) if not path.is_empty() else null; _art.visible = _art.texture!=null
	var art_style := str(_event.get("illustration_style",definition.get("illustration_style","")))
	if art_style.is_empty() and not path.is_empty():
		art_style = EventArt.style_for(event_id)
	if art_style=="scene":
		var edge := ShaderMaterial.new()
		edge.shader = preload("res://src/shaders/event_illustration.gdshader")
		_art.material = edge
	else: _art.material = null
	_title.text = _event.title; _body.text = _event.body
	for i in _event.options.size():
		var opt: Dictionary = _event.options[i]
		var b := Ink.button("", bool(opt.get("primary", false)))
		b.tooltip_text = opt.text
		var label := Ink.label(opt.text, "", JourneyStyle.TEXT)
		label.add_theme_font_override("font", Ink.serif)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(label)
		b.button_down.connect(func(): label.add_theme_color_override("font_color", JourneyStyle.TEXT))
		b.button_up.connect(func(): label.add_theme_color_override("font_color", JourneyStyle.TEXT))
		b.pressed.connect(_choose.bind(i))
		b.disabled = not EventEffects.option_available(opt) or (_room_session!=null and _room_session.run.phase=="event_choose")
		_copy.add_child(b)
		_buttons.append(b)
		_choice_labels.append(label)
	# 纯益事件允许额外空手离开；不占三个收益选项的位置。
	var has_empty: bool = _event.options.any(func(opt):
		return EventEffects.option_available(opt) and (opt.get("effects", []) as Array).is_empty() and str(opt.get("goto", "")).is_empty() and str(opt.get("spawn", "")).is_empty() and str(opt.get("relic", "")).is_empty() and not bool(opt.get("board", false)))
	if bool(_event.get("allow_leave", true)) and not has_empty:
		_leave_button = Ink.button("空手离开")
		_leave_button.custom_minimum_size.y = 40
		_leave_button.pressed.connect(_leave_event)
		if _room_session != null and _room_session.run.phase != "event":
			_leave_button.disabled = true
		_copy.add_child(_leave_button)
	_layout_key = ""
	_layout.call_deferred()


func _layout() -> void:
	if _copy == null or size.x < 1: return
	var key := str(size) + str(get_window().size)
	if key == _layout_key: return
	_layout_key = key
	_vertical = size.x / maxf(1, size.y) < 1.1
	var compact := size.x / maxf(1, size.y) >= 1.95 or size.x < 1100
	_ui_scale = JourneyStyle.touch_scale(self)
	var margin := (8 if compact else 24) * _ui_scale
	_page_margin = margin
	var width := minf(size.x - margin * 2, 1080 * _ui_scale)
	var art_width := (width if _vertical else width * (0.32 if compact else 0.40)) if _art.visible else 0.0
	var gap := (18 * _ui_scale if compact else 56.0) if _art.visible and not _vertical else 0.0
	var copy_width := width if _vertical or not _art.visible else width - art_width - gap
	_art.size = Vector2(art_width, minf(art_width, 300 * _ui_scale) if _vertical else art_width)
	_art.position.x = (size.x - width) * 0.5
	_copy.position.x = _art.position.x if _vertical else _art.position.x + art_width + gap
	_copy.size.x = copy_width
	_copy.add_theme_constant_override("separation", int(4 * _ui_scale if compact else 14))
	_eyebrow.visible = not compact
	_eyebrow.add_theme_font_size_override("font_size", int(14 * _ui_scale))
	_title.add_theme_font_size_override("font_size", int((28 if compact else 42) * _ui_scale))
	_body.add_theme_font_size_override("font_size", int((16 if compact else 20) * _ui_scale))
	_notice.add_theme_font_size_override("font_size", int(16 * _ui_scale))
	for index in _buttons.size():
		var label := _choice_labels[index]
		var font_size := int((16 if compact else 18) * _ui_scale)
		label.add_theme_font_size_override("font_size", font_size)
		label.offset_left = (12 if compact else 18) * _ui_scale
		label.offset_right = -(12 if compact else 18) * _ui_scale
		label.offset_top = 4 * _ui_scale
		label.offset_bottom = -4 * _ui_scale
		var lines := Ink.serif.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, maxf(1, copy_width - (24 if compact else 36) * _ui_scale), font_size)
		_buttons[index].custom_minimum_size.y = maxf(48 * _ui_scale, lines.y + (8 if compact else 12) * _ui_scale)
	if is_instance_valid(_leave_button):
		_leave_button.custom_minimum_size.y = 48*_ui_scale
		_leave_button.add_theme_font_size_override("font_size",int(18*_ui_scale))
	_place.call_deferred()


func _place() -> void:
	if _copy == null or size.y < 1: return
	var copy_height := _copy.get_combined_minimum_size().y
	var art_height := _art.size.y if _art.visible else 0.0
	var art_gap := 24 * _ui_scale if _art.visible and _vertical else 0.0
	var height := art_height + art_gap + copy_height if _vertical else maxf(art_height, copy_height)
	var top := maxf(_page_margin, (size.y - height) * 0.5)
	_page.custom_minimum_size.y = height + _page_margin * 2
	_art.position.y = top
	_copy.position.y = top + art_height + art_gap if _vertical else top + (height - copy_height) * 0.5
	_copy.size.y = copy_height


func _choose(index: int) -> void:
	if _done or index < 0 or index >= _event.options.size(): return
	if not EventEffects.option_available(_event.options[index]): return
	_done = true
	for button in _buttons: button.disabled = true
	if is_instance_valid(_leave_button): _leave_button.disabled = true
	if _room_session!=null:
		_room_event_result(_room_session.apply({"type":"event","index":index})); return
	var relic := str(_event.options[index].get("relic", ""))
	if not relic.is_empty():
		RelicRewardFlow.grant(self, relic, func(_id): _finish())
		return
	var result: Dictionary = EventEffects.resolve(_event.options[index].get("effects", []), GameState.rng)
	if not result.get("ok", false):
		_restore_choices(str(result.get("reason", "事件结算失败")))
		return
	_pending_effect = result.get("pending", {})
	_continue_effects()


func _leave_event() -> void:
	if _done or not bool(_event.get("allow_leave", true)): return
	_done = true
	if _room_session != null:
		var result: Dictionary = _room_session.apply({"type": "event_leave"})
		if not result.get("ok", false):
			_restore_choices(str(result.get("reason", "现在不能离开")))
			return
		goto("res://src/screens/room_map_screen.gd")
		return
	GameState.clear_event_temp_hp()
	GameState.complete_current_node()
	goto("res://src/screens/map_screen.gd")


func _continue_effects() -> void:
	if _pending_effect.is_empty():
		_finish()
		return
	_open_removal_picker()


func _open_removal_picker() -> void:
	var chars: Array = []
	var counts: Dictionary = EventEffects.remaining_counts(_pending_effect)
	for glyph in _pending_effect.get("glyphs", []):
		var character: CharacterData = Database.get_character_by_glyph(str(glyph))
		if character != null: chars.append(character)
	if chars.is_empty():
		_restore_choices("字袋中没有符合条件的字，请重新选择。")
		return
	_picker_generation += 1
	var generation := _picker_generation
	var overlay := CollectionOverlay.new()
	_pending_removal = true
	overlay.setup({"title": "选择要删去的字", "subtitle": "还需 %d 枚" % int(_pending_effect.get("remaining", 1)), "characters": chars, "counts": counts, "pick_on_click": true, "close_text": "取消选择"})
	overlay.picked.connect(_on_removed.bind(generation))
	overlay.closed.connect(_on_picker_closed.bind(generation))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_picker_closed(generation: int) -> void:
	if generation != _picker_generation or not _pending_removal or not is_inside_tree(): return
	_restore_choices()


func _restore_choices(message := "") -> void:
	_picker_generation += 1
	_pending_removal = false
	_pending_effect = {}
	_done = false
	_render_event()
	_notice.text = message
	_notice.visible = not message.is_empty()


func _on_removed(character: CharacterData, generation := -1) -> void:
	if generation < 0: generation = _picker_generation
	if generation != _picker_generation or not _pending_removal: return
	_pending_removal = false
	var result: Dictionary = EventEffects.resume(_pending_effect, character.glyph, GameState.rng)
	if not result.get("ok", false):
		_restore_choices(str(result.get("reason", "事件删字失败")))
		return
	_pending_effect = result.get("pending", {})
	_continue_effects()


func _finish() -> void:
	if _room_session!=null: goto("res://src/screens/room_map_screen.gd"); return
	# 经典模式：事件里拿到要挑字 / 许愿的遗物，离开前补上
	if not Relics.next_pending_peek().is_empty():
		RelicRewardFlow.drain_pending(self, _finish)
		return
	GameState.clear_event_temp_hp()
	GameState.complete_current_node()
	goto("res://src/screens/map_screen.gd")


func _room_event_result(result: Dictionary) -> void:
	if not result.ok:
		if _room_session.current() and _room_session.run.phase == "event_choose":
			_room_session.apply({"type":"cancel_pick"})
		_restore_choices(str(result.get("reason", "事件选择失败")))
		return
	if _room_session.run.phase not in ["event","event_choose"]: _finish(); return
	_event = _room_session.run.current_event(); _done = false; _render_event()
	if _room_session.run.phase=="event_choose": _resume_room_choice()


func _resume_room_choice() -> void:
	if not _room_session.current() or _room_session.run.phase != "event_choose": return
	_done = true
	_body.text = str(_event.body)+"\n\n选择要删去的字（还需 %d 枚）。" % int(_room_session.run.pending_event_effect.get("remaining",1))
	_room_session.pick(self,"选择要删去的字",_room_event_result)
