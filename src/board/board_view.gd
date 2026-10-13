extends Control
class_name BoardView
signal commit(path: Array)
signal selection_changed(path: Array, glyphs: Array, word: WordData)
signal tile_picked(pos: Vector2i)
signal pick_cancelled

var board: BoardState
var tiles: Array = []
var path: Array = []
var pick_mode := ""
var pick_multi := false   ## true=多选：选完不自动退出选区模式（由调用方 end_pick）
var _dragging := false
var _drag_moved := false
var _interactable := true
var _dim_locked := true
var _touch_index := -1
var _last_pointer := Vector2.ZERO
var _cancelled_drag_cell := Vector2i(-1, -1)
var _path_layer: Control
var _presentation: BoardPresentation3D


func setup(p_board: BoardState) -> void:
	board = p_board


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	resized.connect(_layout)
	_layout()


func _build() -> void:
	var tray := Panel.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Palette.PANEL_DARK
	frame.border_color = Palette.WOOD_DARK.darkened(0.5)
	frame.set_border_width_all(4)
	frame.set_corner_radius_all(7)
	frame.shadow_color = Color(Palette.INK, 0.22)
	frame.shadow_size = 8
	frame.shadow_offset = Vector2(0, 4)
	tray.add_theme_stylebox_override("panel", frame)
	tray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray)
	if Palette.STYLE_ID == "paper":
		tray.hide()
		_presentation = BoardPresentation3D.new()
		add_child(_presentation)
		_presentation.resized.connect(func(): _layout.call_deferred())
	for y in board.size:
		for x in board.size:
			var tile := TileView.new()
			tile.grid_pos = Vector2i(x, y)
			tile.tile_pressed.connect(_on_tile_pressed)
			tile.tile_hovered.connect(_on_tile_hovered)
			add_child(tile)
			tiles.append(tile)
			if _presentation != null:
				tile._visual.hide()
				tile.get_child(0).hide()
	if _presentation != null:
		_presentation.set_tiles(tiles)
	_path_layer = Control.new()
	_path_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_path_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_path_layer.draw.connect(_draw_path)
	add_child(_path_layer)
	rebuild()


func _layout() -> void:
	if tiles.is_empty():
		return
	var gap := 7.0
	var pad := 14.0
	var tile_side := (minf(size.x, size.y) - pad * 2.0 - (board.size - 1) * gap) / board.size
	for tile in tiles:
		tile.position = Vector2(pad, pad) + Vector2(tile.grid_pos) * (tile_side + gap)
		tile.size = Vector2.ONE * tile_side
	if _presentation != null and _presentation.has_projection():
		for index in tiles.size():
			var rect := _presentation.cell_rect(index)
			tiles[index].position = rect.position
			tiles[index].size = rect.size
	_path_layer.queue_redraw()


func _process(_delta: float) -> void:
	if not path.is_empty():
		_path_layer.queue_redraw()


func rebuild(animate := false) -> void:
	if board == null:
		return
	var positions: Dictionary = {}
	for tile in tiles:
		if tile.display_uid >= 0:
			positions[tile.display_uid] = tile.position
	for tile in tiles:
		var inst: CharInstance = board.get_xy(tile.grid_pos)
		var old_uid: int = tile.display_uid
		var old_key: String = tile.display_key
		tile.set_instance(inst)
		tile.set_selected(path.has(tile.grid_pos), path.find(tile.grid_pos))
		tile.set_dimmed(not _interactable and _dim_locked)
		if animate and inst != null and (old_uid != inst.uid or old_key != tile.display_key):
			var fresh := not positions.has(inst.uid)
			var offset: Vector2 = Vector2(0, -10) if fresh else positions[inst.uid] - tile.position
			tile.enter(offset, fresh, float(tile.grid_pos.y) * 0.015 if fresh else 0.0)
	if not pick_mode.is_empty():
		_apply_pick_highlight()
	if _path_layer != null:
		_path_layer.queue_redraw()


func release_selected(selected: Array) -> void:
	var surviving: Dictionary = {}
	for cell in board.cells:
		if cell != null:
			surviving[cell.uid] = true
	for tile in tiles:
		if selected.has(tile.grid_pos):
			tile.release(surviving.has(tile.display_uid))


func play_opening() -> void:
	for tile in tiles:
		if tile.instance != null:
			tile.enter(Vector2(0, -8), true, tile.grid_pos.y * 0.025 + tile.grid_pos.x * 0.015)


func set_interactable(value: bool, dim := true) -> void:
	_interactable = value
	_dim_locked = dim
	if not value:
		_dragging = false
		_touch_index = -1
		_cancelled_drag_cell = Vector2i(-1, -1)
	for tile in tiles:
		tile.set_dimmed(not value and dim)


func _on_tile_pressed(pos: Vector2i) -> void:
	if not _interactable:
		return
	if not pick_mode.is_empty():
		if _valid_pick(pos):
			if not pick_multi:
				end_pick()
			tile_picked.emit(pos)
		return
	if board.get_xy(pos) == null:
		return
	_dragging = true
	_drag_moved = false
	_last_pointer = get_viewport().get_mouse_position()
	_cancelled_drag_cell = Vector2i(-1, -1)
	if path.has(pos):
		# 点击撤销该字及其后续路径；拖动回退仍由 _extend_path 保留经过的字。
		path = path.slice(0, path.find(pos))
		_cancelled_drag_cell = pos
	elif board.can_extend_path(path, pos):
		path.append(pos)
	else:
		path = [pos]
	_sync_selection()


func _extend_path(pos: Vector2i) -> void:
	if not pick_mode.is_empty() or not _dragging or board.get_xy(pos) == null:
		return
	# 点击取消后的手指/鼠标微动不能立即把同一枚字重新选回来。
	if pos == _cancelled_drag_cell:
		return
	_cancelled_drag_cell = Vector2i(-1, -1)
	if path.has(pos):
		var i := path.find(pos)
		if i != path.size() - 1:
			path = path.slice(0, i + 1)
			_drag_moved = true
			_sync_selection()
	elif board.can_extend_path(path, pos):
		path.append(pos)
		_drag_moved = true
		_sync_selection()


func _on_tile_hovered(pos: Vector2i) -> void:
	if _interactable and _dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_extend_path(pos)


func _cell_at(screen_pos: Vector2) -> Vector2i:
	var local := get_global_transform().affine_inverse() * screen_pos
	if _presentation != null and _presentation.has_projection():
		return _presentation.cell_at(local)
	for tile in tiles:
		if Rect2(tile.position, tile.size).has_point(local):
			return tile.grid_pos
	return Vector2i(-1, -1)


func _trace_pointer(next: Vector2) -> void:
	var steps := maxi(1, int(ceil(_last_pointer.distance_to(next) / 16.0)))
	for i in range(1, steps + 1):
		var cell := _cell_at(_last_pointer.lerp(next, float(i) / steps))
		if cell.x >= 0:
			_extend_path(cell)
	_last_pointer = next


func _finish_drag() -> void:
	var was_dragging := _dragging
	_dragging = false
	_cancelled_drag_cell = Vector2i(-1, -1)
	if was_dragging and _drag_moved and not path.is_empty() and Settings.drag_release_play:
		commit.emit(path.duplicate())


func _input(event: InputEvent) -> void:
	if not _interactable or Debug.is_open():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index < 0:
			var cell := _cell_at(event.position)
			if cell.x < 0:
				return
			_on_tile_pressed(cell)
			_touch_index = event.index if _dragging else -1
			_last_pointer = event.position
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			if event.canceled:
				_dragging = false
				clear_selection()
			else:
				_finish_drag()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_trace_pointer(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _presentation != null:
		var cell := _cell_at(event.position)
		if cell.x >= 0:
			_on_tile_pressed(cell)
			_last_pointer = event.position
			get_viewport().set_input_as_handled()
		elif get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _dragging:
		_trace_pointer(event.position)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag()


func _unhandled_input(event: InputEvent) -> void:
	if not _interactable or event.is_echo() or Debug.is_open():
		return
	if event.is_action_pressed("confirm_word") and not path.is_empty() and pick_mode.is_empty():
		commit.emit(path.duplicate())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel_selection"):
		if not pick_mode.is_empty():
			end_pick()
			pick_cancelled.emit()
			get_viewport().set_input_as_handled()
		elif not path.is_empty():
			clear_selection()
			get_viewport().set_input_as_handled()


func begin_pick(mode: String, multi := false) -> void:
	pick_mode = mode
	pick_multi = multi
	clear_selection()
	_apply_pick_highlight()


func end_pick() -> void:
	pick_mode = ""
	pick_multi = false
	for tile in tiles:
		tile.set_dimmed(not _interactable and _dim_locked)
		tile.set_selected(false)


func _valid_pick(pos: Vector2i) -> bool:
	var cell: CharInstance = board.get_xy(pos)
	match pick_mode:
		"any": return cell != null
		"empty": return cell == null
		"enemy": return cell != null and cell.is_enemy_owned()
		"own": return cell != null and cell.is_player_owned()
		"2x2": return pos.x >= 0 and pos.y >= 0 and pos.x <= board.size - 2 and pos.y <= board.size - 2
	return false


func _apply_pick_highlight() -> void:
	for tile in tiles:
		tile.set_dimmed(not _valid_pick(tile.grid_pos))


func _sync_selection() -> void:
	for tile in tiles:
		tile.set_selected(path.has(tile.grid_pos), path.find(tile.grid_pos))
	var glyphs := board.glyphs_of(path)
	var word: WordData = Database.get_word_by_glyphs(glyphs) if glyphs.size() >= 2 else null
	selection_changed.emit(path.duplicate(), glyphs, word)
	_path_layer.queue_redraw()


func clear_selection() -> void:
	path.clear()
	_dragging = false
	_cancelled_drag_cell = Vector2i(-1, -1)
	_sync_selection()


func flash_invalid() -> void:
	for tile in tiles:
		if path.has(tile.grid_pos):
			tile.shake()


func remove_xy(pos: Vector2i) -> void:
	board.clear_xy(pos)
	path = path.filter(func(p): return p != pos)
	_on_sync()


func _on_sync() -> void:
	rebuild()
	_sync_selection()


func _draw_path() -> void:
	for i in range(1, path.size()):
		var previous: TileView = tiles[board.from_xy(path[i - 1])]
		var current: TileView = tiles[board.from_xy(path[i])]
		var from: Vector2 = previous.position + previous.size * 0.5
		var to: Vector2 = current.position + current.size * 0.5
		if _presentation != null and _presentation.has_projection():
			from = _presentation.center_of(board.from_xy(path[i - 1]))
			to = _presentation.center_of(board.from_xy(path[i]))
		var dir := (to - from).normalized()
		var mid := (from + to) * 0.5 + Vector2(0, -5 if not Settings.reduced_motion else 0)
		if _presentation != null and _presentation.has_projection():
			mid = (from + to) * 0.5
		var start := mid - dir * 16
		var tip := mid + dir * 16
		_path_layer.draw_line(start, tip, Palette.VERMILION, 2.5, true)
		_path_layer.draw_line(tip, tip - dir.rotated(0.55) * 8, Palette.VERMILION, 2.5, true)
		_path_layer.draw_line(tip, tip - dir.rotated(-0.55) * 8, Palette.VERMILION, 2.5, true)
