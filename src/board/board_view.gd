extends Control
class_name BoardView
## 4×4 字盘视图 + 连线选择逻辑。
## 交互：点击起手 / 拖动连线 / 点回退。释放或点“出字”提交。

signal commit(path: Array)
signal selection_changed(path: Array, glyphs: Array, word: WordData)
signal tile_picked(pos: Vector2i)
signal pick_cancelled

var board: BoardState
var tiles: Array = []          ## Array[TileView]
var path: Array = []           ## Array[Vector2i]

var pick_mode: String = ""     ## "" / "any" / "empty" / "2x2" / "enemy"
var reserved_cells: Array = []   ## 结阵中被锁定的格（置暗）
var preview_cells: Array = []    ## 待发动目标的高亮预览

var _grid: GridContainer
var _tray: PanelContainer
var _dragging := false
var _drag_moved := false
var _interactable := true


func setup(p_board: BoardState) -> void:
	board = p_board


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()


func _build() -> void:
	_tray = PanelContainer.new()
	_tray.theme_type_variation = "PanelDark"
	_tray.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tray)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 12)
	pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_child(pad)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(center)

	_grid = GridContainer.new()
	_grid.columns = board.size if board != null else 4
	_grid.add_theme_constant_override("h_separation", 7)
	_grid.add_theme_constant_override("v_separation", 7)
	center.add_child(_grid)

	var n0: int = board.size if board != null else 4
	var side: float = n0 * TileView.TILE_SIZE.x + (n0 - 1) * 7 + 24
	custom_minimum_size = Vector2(side, side)

	tiles.clear()
	for y in n0:
		for x in n0:
			var t := TileView.new()
			t.grid_pos = Vector2i(x, y)
			t.tile_pressed.connect(_on_tile_pressed)
			t.tile_hovered.connect(_on_tile_hovered)
			_grid.add_child(t)
			tiles.append(t)
	rebuild()


func rebuild() -> void:
	if board == null:
		return
	for t in tiles:
		var inst: CharInstance = board.get_xy(t.grid_pos)
		t.set_instance(inst)
		t.set_selected(path.has(t.grid_pos) or preview_cells.has(t.grid_pos))
		t.set_dimmed((not _interactable) or reserved_cells.has(t.grid_pos))
	if not pick_mode.is_empty():
		_apply_pick_highlight()


func set_interactable(value: bool) -> void:
	_interactable = value
	for t in tiles:
		t.set_dimmed(not value)


# ---------------------------------------------------------------- 选择逻辑
func _on_tile_pressed(pos: Vector2i) -> void:
	if not _interactable:
		return
	if not pick_mode.is_empty():
		if _valid_pick(pos):
			end_pick()
			tile_picked.emit(pos)
		return
	if board.get_xy(pos) == null:
		return
	_dragging = true
	_drag_moved = false
	if path.has(pos):
		# 点已选中的字 -> 回退到它
		var i := path.find(pos)
		path = path.slice(0, i + 1)
	elif path.is_empty() or board.is_adjacent(path[-1], pos):
		path.append(pos)
	else:
		path = [pos]
	_sync_selection()


func _on_tile_hovered(pos: Vector2i) -> void:
	if pick_mode != "":
		return
	if not _interactable or not _dragging or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if board.get_xy(pos) == null:
		return
	if path.has(pos):
		var i := path.find(pos)
		if i != path.size() - 1:
			path = path.slice(0, i + 1)
			_drag_moved = true
			_sync_selection()
		return
	if path.is_empty():
		path = [pos]
		_drag_moved = true
		_sync_selection()
		return
	if board.is_adjacent(path[-1], pos):
		path.append(pos)
		_drag_moved = true
		_sync_selection()


func _input(event: InputEvent) -> void:
	if not _interactable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if pick_mode != "":
			return
		if _dragging:
			_dragging = false
			if _drag_moved and not path.is_empty() and Settings.drag_release_play:
				commit.emit(path.duplicate())


func _unhandled_input(event: InputEvent) -> void:
	if not _interactable:
		return
	if event.is_action_pressed("confirm_word"):
		if not path.is_empty() and pick_mode == "":
			commit.emit(path.duplicate())
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel_selection"):
		if pick_mode != "":
			end_pick()
			pick_cancelled.emit()
			get_viewport().set_input_as_handled()
		elif not path.is_empty():
			clear_selection()
			get_viewport().set_input_as_handled()
		# 否则不消费 ESC，交给暂停菜单


# ---------------------------------------------------------------- 目标选择模式
func begin_pick(mode: String) -> void:
	pick_mode = mode
	clear_selection()
	_apply_pick_highlight()


func end_pick() -> void:
	pick_mode = ""
	for t in tiles:
		t.set_dimmed(not _interactable)
		t.set_selected(false)


func _valid_pick(pos: Vector2i) -> bool:
	match pick_mode:
		"any":
			return board.get_xy(pos) != null
		"empty":
			return board.get_xy(pos) == null
		"enemy":
			var c: CharInstance = board.get_xy(pos)
			return c != null and c.is_enemy_owned()
		"own":
			var c2: CharInstance = board.get_xy(pos)
			return c2 != null and c2.is_player_owned()
		"2x2":
			return pos.x >= 0 and pos.y >= 0 and pos.x <= board.size - 2 and pos.y <= board.size - 2
		"3x3":
			return pos.x >= 0 and pos.y >= 0 and pos.x <= board.size - 3 and pos.y <= board.size - 3
		"row":
			return pos.y >= 0 and pos.y < board.size
	return false


func _apply_pick_highlight() -> void:
	for t in tiles:
		t.set_dimmed(not _valid_pick(t.grid_pos))


func _sync_selection() -> void:
	for t in tiles:
		t.set_selected(path.has(t.grid_pos))
	var glyphs := board.glyphs_of(path)
	var word: WordData = null
	if glyphs.size() >= 2:
		word = Database.get_word_by_glyphs(glyphs)
	selection_changed.emit(path.duplicate(), glyphs, word)


func clear_selection() -> void:
	path.clear()
	_sync_selection()
	for t in tiles:
		t.set_selected(false)


func flash_invalid() -> void:
	for t in tiles:
		if path.has(t.grid_pos):
			t.shake()
	var tw := create_tween()
	tw.tween_interval(0.18)


func remove_xy(pos: Vector2i) -> void:
	board.clear_xy(pos)
	if path.has(pos):
		path = path.filter(func(p): return p != pos)
	_on_sync()


func _on_sync() -> void:
	rebuild()
	_sync_selection()
