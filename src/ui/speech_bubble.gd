extends Control
class_name SpeechBubble
## 纸面词效按阅读顺序自然排布；长说明滚动，不把目标推到纸张底部。
enum State { IDLE, PREVIEW, RESULT, ERROR }

var frame_details: Label
var title: Label
var body: EffectText
var _caption: Label
var _context: Label
var _column: VBoxContainer
var _scroll: ScrollContainer
var _state: int = State.IDLE
var _pulse: Tween
var _effect_text := ""
var _context_text := ""
var _source_word: WordData
var ui_scale := 1.0
var compact := false
var illustrated_scale := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_column = Ink.vbox(12)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_column)
	var heading := Ink.hbox(12)
	_caption = Ink.label("当前连词", "", Palette.INK)
	_caption.add_theme_font_override("font", Ink.serif)
	heading.add_child(_caption)
	var rule := _rule()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(rule)
	_column.add_child(heading)
	title = Ink.label("", "", Palette.VERMILION_DK)
	title.add_theme_font_override("font", Ink.serif)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(title)
	_column.add_child(_rule())
	body = EffectText.new()
	body.add_theme_constant_override("line_separation", 0)
	_column.add_child(body)
	_column.add_child(_rule())
	_context = Ink.label("", "", Palette.INK)
	_context.add_theme_font_override("font", Ink.serif)
	_context.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_context)
	frame_details = Ink.label("", "", Palette.INK)
	frame_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(frame_details)
	_column.move_child(frame_details, 1)
	frame_details.hide()
	set_ui_scale(ui_scale, compact)


func _rule() -> HSeparator:
	var line := HSeparator.new()
	var ink := StyleBoxLine.new()
	ink.color = Color(Palette.INK_SOFT, 0.5)
	ink.thickness = 1
	line.add_theme_stylebox_override("separator", ink)
	line.add_theme_constant_override("separation", 1)
	return line


func set_context(text: String) -> void:
	_context_text = text
	if _context != null:
		_context.text = text.replace("\n", " · ").replace("污染代价：", "污染：") if compact or illustrated_scale > 0 else text


func set_state(s: int) -> void:
	_state = s
	_caption.text = ["连字成词", "当前连词", "本次出字", "请调整选择"][s]
	title.add_theme_color_override("font_color", Palette.VERMILION_DK if s != State.IDLE else Palette.INK_SOFT)


func set_text(t: String, b: String, s: int = State.PREVIEW, source_word: WordData = null) -> void:
	if title == null:
		return
	var next_title := t.replace("《", "").replace("》", "").replace("「", "").replace("」", "")
	var changed := next_title != title.text
	title.text = next_title
	_effect_text = b
	_source_word = source_word
	set_ui_scale(ui_scale, compact)
	set_state(s)
	if changed and not Settings.reduced_motion:
		if _pulse != null:
			_pulse.kill()
		title.modulate.a = 0.55
		_pulse = create_tween()
		_pulse.tween_property(title, "modulate:a", 1.0, 0.10)
	_scroll.scroll_vertical = 0


func set_result(word: WordData, glyphs: Array, messages: Array) -> void:
	var head := word.word if word != null else "".join(glyphs)
	var lines: Array[String] = []
	for m in messages:
		if not lines.has(str(m)):
			lines.append(str(m))
	if lines.is_empty():
		lines.append(word.describe() if word != null else "没有效果，仅消耗字块")
	set_text(head, "\n".join(lines), State.RESULT)


func set_error(reason: String) -> void:
	set_text("无效选择", reason, State.ERROR)


func set_idle(hint: String) -> void:
	set_text("连字成词", hint, State.IDLE)
	set_context("")


func set_ui_scale(value: float, is_compact := false) -> void:
	ui_scale = value
	compact = is_compact
	if title == null:
		return
	_column.add_theme_constant_override("separation", 4 if compact else 6)
	var title_size := 38 if compact else 72
	if title.text.length() > 2:
		title_size = 32 if compact else 46
	title.add_theme_font_size_override("font_size", int(minf(72, title_size * value)))
	body.add_theme_font_size_override("normal_font_size", int(minf(27, (18 if compact else 23) * value)))
	body.add_theme_font_size_override("bold_font_size", int(minf(27, (18 if compact else 23) * value)))
	_caption.add_theme_font_size_override("font_size", int(minf(24, (15 if compact else 19) * value)))
	_context.add_theme_font_size_override("font_size", int(minf(23, (15 if compact else 19) * value)))
	frame_details.add_theme_font_size_override("font_size", int(clampf(17 * value, 14, 23)))
	var number_size := int(minf(29, (20 if compact else 26) * ui_scale))
	if illustrated_scale > 0:
		var unit := illustrated_scale
		_column.add_theme_constant_override("separation", int(4 * unit))
		title.add_theme_font_size_override("font_size", int((64 if title.text.length() <= 2 else 46) * unit))
		body.add_theme_font_size_override("normal_font_size", int(30 * unit))
		body.add_theme_font_size_override("bold_font_size", int(30 * unit))
		body.add_theme_constant_override("line_separation", int(-3 * unit))
		_caption.add_theme_font_size_override("font_size", int(26 * unit))
		_context.add_theme_font_size_override("font_size", int(26 * unit))
		number_size = int(34 * unit)
	body.set_effect_text(_effect_text, number_size, _source_word)
	set_context(_context_text)
