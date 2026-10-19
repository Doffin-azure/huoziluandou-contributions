extends ScreenBase
## 璇玑字盘事件：从 4×4 字盘上连出一个 2～3 字词，获得词中不重复的字。

const BOARD_VIEW := preload("res://src/board/board_view.gd")
var _run: RefCounted
var _board: BoardState
var _view
var _preview: Label
var _hint: Label
var _confirm: Button
var _leave: Button
var _done := false


func build(root: Control) -> void:
	_run = GameState.room_run
	if _run == null or _run.phase != "event_board" or _run.event_board.is_empty():
		goto.call_deferred("res://src/screens/room_map_screen.gd")
		return
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)
	var column := Ink.vbox(10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	margin.add_child(column)

	var eyebrow := Ink.label("庭院 · 璇玑图", "Muted", JourneyStyle.GOLD)
	column.add_child(eyebrow)
	var title := Ink.h2("璇玑拾字")
	column.add_child(title)
	column.add_child(Ink.hline())
	var body := Ink.body("“织锦为回文旋图诗以赠滔，宛转循环以读之，词甚凄惋。”\n廊下挂着一幅未收的锦，锦上字字相连。沿四邻连出二至三字的词，锦线会把其中的字留给你。")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)

	_board = BoardState.new(4)
	var glyphs: Array = _run.event_board.get("glyphs", [])
	for i in mini(glyphs.size(), _board.cells.size()):
		var cd: CharacterData = Database.get_character_by_glyph(str(glyphs[i]))
		if cd == null:
			continue
		var inst := CharInstance.new(cd)
		inst.owner = CharInstance.Owner.PLAYER
		_board.cells[i] = inst
	_view = BOARD_VIEW.new()
	_view.setup(_board)
	_view.custom_minimum_size = Vector2(360, 360)
	_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_view.selection_changed.connect(_on_selection)
	column.add_child(_view)

	_preview = Ink.label("当前锦线：未成词", "", JourneyStyle.TEXT)
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_preview)
	_hint = Ink.caption("拖动或点击相邻字；可回头撤销末字。确认后只结算一次。")
	column.add_child(_hint)
	var actions := Ink.hbox(10)
	column.add_child(actions)
	_confirm = Ink.button("确认取字", true)
	_confirm.custom_minimum_size = Vector2(180, 48)
	_confirm.disabled = true
	_confirm.pressed.connect(_on_confirm)
	actions.add_child(_confirm)
	_leave = Ink.button("收起字盘，离开")
	_leave.custom_minimum_size = Vector2(180, 48)
	_leave.pressed.connect(_on_leave)
	actions.add_child(_leave)
	column.add_child(Ink.caption("只可读二至三字的词。词中的字不会触发战斗效果。"))


func _on_selection(path: Array, glyphs: Array, word: WordData) -> void:
	if _done:
		return
	_confirm.disabled = word == null or glyphs.size() < 2 or glyphs.size() > 3
	if glyphs.is_empty():
		_preview.text = "当前锦线：未成词"
	elif word == null:
		_preview.text = "当前锦线：" + "".join(glyphs) + "（不成词）"
	elif glyphs.size() > 3:
		_preview.text = "当前锦线：" + "".join(glyphs) + "（只可读二至三字）"
	else:
		_preview.text = "当前锦线：" + "".join(glyphs) + "（" + word.word + "）"


func _on_confirm() -> void:
	if _done:
		return
	if _view.path.size() < 2:
		_hint.text = "先连出至少两枚字。"
		return
	_done = true
	var result: Dictionary = _run.apply({"type": "event_word", "path": _view.path.duplicate()})
	if not result.get("ok", false):
		_done = false
		_hint.text = str(result.get("reason", "锦线未成词。"))
		_view.flash_invalid()
		return
	goto("res://src/screens/room_map_screen.gd")


func _on_leave() -> void:
	if _done:
		return
	_done = true
	var result: Dictionary = _run.apply({"type": "event_board_leave"})
	if not result.get("ok", false):
		_done = false
		_hint.text = str(result.get("reason", "现在不能收起字盘。"))
		return
	goto("res://src/screens/room_map_screen.gd")
