extends Node
## One local adventure, checkpointed at completed actions. Disk I/O runs off the UI thread.
signal availability_changed
const VERSION := 1
const MAX_BYTES := 8 * 1024 * 1024
const ROUTES := ["map", "expedition_map", "battle", "reward", "shop", "rest", "event"]
const STATE_FIELDS := ["deck", "player_max_hp", "player_hp", "gold", "act_index", "node_index",
	"fork_choice", "visited", "permanent_damage_reduction", "gold_growth_percent", "battle_sequence",
	"_reinvestments", "rng", "custom_deck", "expedition", "relics", "relic_binds", "relic_counters", "first_run_tutorial"]
var enabled := false
var save_path := "user://adventure.save"
var last_error := ""
var recovered_backup := false
var _active := false
var _queued := false
var _available := false
var _generation := 0
var _last_payload := PackedByteArray()
var _pending := PackedByteArray()
var _writer: Thread
var _write_result := OK


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	EventBus.run_started.connect(_new_run)
	EventBus.run_ended.connect(func(_victory): clear_run())


func activate(path := "user://adventure.save") -> void:
	save_path = path
	enabled = true
	_available = not _read_latest().is_empty()
	availability_changed.emit()


func has_save() -> bool:
	return enabled and _available


func _new_run() -> void:
	if not enabled: return
	clear_run()
	_active = true


func clear_run() -> void:
	if not enabled: return
	flush()
	_active = false
	_available = false
	_last_payload.clear()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(save_path + suffix)
	availability_changed.emit()


func request_save() -> void:
	if not enabled or not _active or _queued: return
	_queued = true
	_capture_deferred.call_deferred()


func _capture_deferred() -> void:
	_queued = false
	checkpoint()


func checkpoint() -> bool:
	if GameState.room_run != null: return false
	if not enabled or not _active: return false
	var screen := Router.current
	if not is_instance_valid(screen) or not screen.has_method("save_checkpoint"): return false
	var route := Router.current_path.get_file().trim_suffix("_screen.gd")
	if not ROUTES.has(route): return false
	if GameState.run_complete() or GameState.player_hp <= 0 or (GameState.expedition != null and GameState.expedition.over):
		clear_run()
		return false
	var local: Dictionary = screen.save_checkpoint()
	if local.is_empty(): return false
	var state := {}
	for field in STATE_FIELDS: state[field] = GameState.get(field)
	var codec := SaveCodec.new()
	var graph := codec.pack({"state": state, "route": route, "params": local.get("params", {}), "screen": local.get("screen", {}), "revive_charges": GameState.revive_charges})
	if graph.is_empty():
		_fail("无法编码当前冒险")
		return false
	var payload := var_to_bytes({"version": VERSION, "graph": graph})
	if payload == _last_payload: return true
	if payload.size() > MAX_BYTES:
		_fail("存档超过大小上限")
		return false
	_last_payload = payload
	_pending = payload
	_start_writer()
	return true


func _start_writer() -> void:
	if _writer != null or _pending.is_empty(): return
	_generation += 1
	var bytes := var_to_bytes({"generation": _generation, "payload": _pending, "sha256": _digest(_pending)})
	_pending = PackedByteArray()
	_writer = Thread.new()
	_writer.start(_write.bind(bytes, save_path + ("" if _generation % 2 == 1 else ".bak")))
	set_process(true)


func _write(bytes: PackedByteArray, destination: String) -> int:
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	if FileAccess.file_exists(destination):
		error = DirAccess.remove_absolute(destination)
		if error != OK: return error
	return DirAccess.rename_absolute(save_path + ".tmp", destination)


func _process(_delta: float) -> void:
	if _writer == null or _writer.is_alive(): return
	_finish_writer()
	_start_writer()
	set_process(_writer != null)


func _finish_writer() -> void:
	_write_result = _writer.wait_to_finish()
	_writer = null
	if _write_result != OK:
		_last_payload.clear()
		_fail("写入自动存档失败：%s" % error_string(_write_result))
	else:
		last_error = ""
		_available = true
		availability_changed.emit()


func flush() -> void:
	if _writer != null: _finish_writer()
	if not _pending.is_empty():
		_start_writer()
		_finish_writer()
	set_process(false)


func resume_run() -> bool:
	if not enabled: return false
	flush()
	var saved := _read_latest()
	if saved.is_empty():
		_available = false
		availability_changed.emit()
		return false
	for field in STATE_FIELDS: GameState.set(field, saved.state[field])
	GameState.room_run = null
	GameState.revive_charges = int(saved.get("revive_charges", 0))
	# New generated entities must never collide with relic-bound or battle-only UIDs.
	CharInstance._next_uid = maxi(CharInstance._next_uid, int(saved.get("next_uid", 1)))
	GameState.rules = Database.rules
	_active = true
	_last_payload.clear()
	EventBus.deck_changed.emit()
	EventBus.gold_changed.emit(GameState.gold)
	EventBus.hp_changed.emit(GameState.player_hp, GameState.player_max_hp)
	var parameters: Dictionary = saved.params.duplicate()
	parameters["_saved_screen"] = saved.screen
	Router.goto("res://src/screens/%s_screen.gd" % saved.route, parameters)
	return true


func _read_latest() -> Dictionary:
	var candidates: Array = []
	for suffix in ["", ".bak", ".tmp"]:
		var file := FileAccess.open(save_path + suffix, FileAccess.READ)
		if file == null: continue
		if file.get_length() < 4 or file.get_length() > MAX_BYTES + 4096: file.close(); continue
		var record = bytes_to_var(file.get_buffer(file.get_length()))
		file.close()
		if not record is Dictionary or not record.get("payload") is PackedByteArray or not record.get("generation") is int: continue
		if record.get("sha256") != _digest(record.payload): continue
		var envelope = bytes_to_var(record.payload)
		if not envelope is Dictionary or envelope.get("version") != VERSION or not envelope.get("graph") is Dictionary: continue
		candidates.append({"generation": record.generation, "graph": envelope.graph, "suffix": suffix})
	candidates.sort_custom(func(a, b): return a.generation > b.generation)
	for candidate in candidates:
		var codec := SaveCodec.new()
		var saved := codec.unpack(candidate.graph)
		if not _valid_snapshot(saved): continue
		var next_uid := 1
		for object in codec._objects:
			if object is CharInstance: next_uid = maxi(next_uid, object.uid + 1)
		saved.next_uid = next_uid
		_generation = candidate.generation
		recovered_backup = candidate.suffix != ("" if _generation % 2 == 1 else ".bak")
		return saved
	return {}


func _valid_snapshot(saved: Dictionary) -> bool:
	if not ROUTES.has(saved.get("route")) or not saved.get("state") is Dictionary or not saved.get("params") is Dictionary or not saved.get("screen") is Dictionary: return false
	if saved.state.size() != STATE_FIELDS.size(): return false
	for field in STATE_FIELDS:
		if not saved.state.has(field): return false
		var expected = GameState.get(field)
		var value = saved.state[field]
		if field == "expedition":
			if value != null and not value is Expedition: return false
		elif expected is Object:
			if not value is RandomNumberGenerator: return false
		elif typeof(expected) != typeof(value): return false
	if saved.state.player_hp <= 0 or saved.state.player_max_hp < saved.state.player_hp or saved.state.act_index < 1 or saved.state.act_index > 3 or saved.state.node_index < 1 or saved.state.node_index > 8: return false
	for ch in saved.state.deck:
		if not ch is CharInstance or ch.data == null or ch.uid < 1: return false
	var ex = saved.state.expedition
	if ex != null and (ex.over or ex.m.is_empty() or ex.pos < 0 or ex.pos >= ex.m.get("ink", []).size()): return false
	if saved.route == "expedition_map" and ex == null: return false
	if saved.route == "battle":
		var battle = saved.screen.get("battle")
		if not battle is BattleState or battle.player == null or battle.board == null or battle.is_over() or battle.board.size < 1 or battle.board.size > 8 or battle.board.cells.size() != battle.board.size * battle.board.size: return false
	return true


func _digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()


func _fail(message: String) -> void:
	last_error = message
	push_warning("[SaveManager] " + message)


func _notification(what: int) -> void:
	if not enabled: return
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		checkpoint()
		flush()


func _exit_tree() -> void:
	flush()
