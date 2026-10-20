extends Node
## 只收集已结算的事实；不调用玩法、预览或随机数。
signal unlocked(id: String)
signal changed

const CATALOG := "res://data/achievements/catalog.json"
const STORE := "user://achievements.json"
var storage_path := STORE
var test_enabled := false
var autosave := true
var definitions: Array = []
var by_id := {}
var profile := {"version": 1, "unlocked": {}, "lifetime": {}, "best": {}, "sessions": {}}
var run_id := ""
var session := {}
var _dirty := false
var _save_queued := false
var _writable := true
var _battle_serial := 0
var _toast: CanvasLayer


func _ready() -> void:
	reload_catalog()
	EventBus.run_ended.connect(finish_run)
	if not _test_scene():
		_toast = preload("res://src/ui/achievement_toast.gd").new()
		add_child(_toast)
	load_progress()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT] and _dirty:
		save_progress()


func _test_scene() -> bool:
	if OS.get_cmdline_user_args().has("--achievement-test"): return true
	for argument in OS.get_cmdline_args():
		if argument.begins_with("res://tests/"): return true
	var scene := get_tree().current_scene
	return DisplayServer.get_name() == "headless" or (scene != null and scene.scene_file_path.begins_with("res://tests/"))


func reload_catalog() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if not data is Dictionary or not data.get("achievements") is Array:
		push_error("成就配置无法读取")
		return
	definitions = data.achievements.duplicate(true)
	definitions.sort_custom(func(a, b): return int(a.order) < int(b.order))
	by_id.clear()
	for definition in definitions:
		by_id[str(definition.id)] = definition
	_recheck()


func start_run(mode: String) -> void:
	if _test_scene() and not test_enabled:
		return
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	session = {"mode": mode, "eligible": true, "active": true, "stats": {}, "seen": {}, "streams": {}}
	profile.sessions[run_id] = session
	_battle_serial = 0
	_touch()
	observe_inventory()


func suspend_run() -> void:
	run_id = ""
	session = {}


func eligible() -> bool:
	return not run_id.is_empty() and bool(session.get("active", false)) and bool(session.get("eligible", false)) and GameState.custom_deck.is_empty() and not bool(GameState.get_meta("courtyard_preview", false))


func invalidate_run() -> void:
	if session.is_empty(): return
	session.eligible = false
	_touch()


func finish_run(victory: bool) -> void:
	if not eligible(): return
	if victory:
		commit("run/finish", [{"metric": "run_wins", "amount": 1}])
	session.active = false
	_touch()
	save_progress()


func export_run() -> Dictionary:
	return {"run_id": run_id, "session": session.duplicate(true)} if not run_id.is_empty() else {}


func resume_run(data: Dictionary) -> void:
	suspend_run()
	if data.is_empty() or (_test_scene() and not test_enabled): return
	var id := str(data.get("run_id", ""))
	if id.is_empty() or not _valid_session(data.get("session")): return
	run_id = id
	# 账号进度优先于旧冒险快照，读旧档不能倒退去重记录或刷同一奖励。
	if not profile.sessions.has(id): profile.sessions[id] = data.session.duplicate(true)
	session = profile.sessions[id]
	if not bool(data.session.get("eligible", false)): session.eligible = false


func watch_battle(battle: BattleState) -> RefCounted:
	if not eligible(): return null
	if battle.player.god_mode:
		invalidate_run()
		return null
	_battle_serial += 1
	var key := "%s:%d:%d" % [node_key(), GameState.battle_sequence, _battle_serial]
	# 同一房间读档重开仍是同一场正式战斗；序号只用于没有地图的经典入口。
	if GameState.room_run != null or GameState.expedition != null: key = node_key()
	return preload("res://src/core/achievement_battle.gd").new(self, battle, key)


func node_key() -> String:
	if GameState.room_run != null: return "room:%d:%s" % [GameState.act_index, GameState.room_run.current_room]
	if GameState.expedition != null: return "expedition:%d:%d" % [GameState.expedition.act, GameState.expedition.pos]
	return "classic:%d:%d" % [GameState.act_index, GameState.node_index]


func node_completed(key: String = "") -> void:
	commit("node/" + (node_key() if key.is_empty() else key), [{"metric": "nodes_completed", "amount": 1}])


func event_completed(id: String, source: String = "") -> void:
	if id.is_empty(): return
	commit("event/" + (node_key() if source.is_empty() else source) + "/" + id, [{"metric": "unique_events", "value": id}])


func shop_purchase(key: String) -> void:
	commit("purchase/" + node_key() + "/" + key, [{"metric": "shop_purchases", "amount": 1}])


func register_offers(offers: Array) -> void:
	if not eligible(): return
	for offer in offers:
		if not offer.has("achievement_offer"): offer.achievement_offer = Crypto.new().generate_random_bytes(12).hex_encode()


func bought_offer(offer: Dictionary) -> void:
	if offer.has("achievement_offer"): shop_purchase(str(offer.achievement_offer))


func gilded(inst: CharInstance) -> void:
	commit("gild/" + str(inst.uid), [{"metric": "gilded_tiles", "amount": 1}])


func observe_inventory() -> void:
	if not eligible(): return
	_update("relics_held", GameState.relics.size(), "", "", {"run": run_id})
	_recheck()
	_touch()


func commit(token: String, metrics: Array, context: Dictionary = {}, stream := "", sequence := 0) -> void:
	if not eligible(): return
	if not stream.is_empty():
		if sequence <= int(session.streams.get(stream, 0)): return
		session.streams[stream] = sequence
	elif not token.is_empty():
		if session.seen.has(token): return
		session.seen[token] = true
	for row in metrics:
		_update(str(row.metric), int(row.get("amount", 1)), str(row.get("value", "")), str(row.get("filter", "")), context)
	_recheck()
	_touch()


func _update(metric: String, amount: int, value: String, filter: String, context: Dictionary) -> void:
	if amount < 0: return
	var visited := {}
	for definition in definitions:
		if definition.metric != metric or str(definition.filter) != filter: continue
		var scope: String = definition.scope
		var bucket: String = "lifetime" if scope == "lifetime" else str(context.get(scope, run_id if scope == "run" else ""))
		if bucket.is_empty(): continue
		var key := "%s/%s/%s/%s" % [scope, bucket, metric, filter]
		if visited.has(key): continue
		visited[key] = true
		var container: Dictionary = profile.lifetime if scope == "lifetime" else session.stats
		# 旧回合/动作只需保留最好纪录，避免每次出词都积累一个存档桶。
		if scope in ["turn", "action"]:
			key = "%s/%s/%s" % [scope, metric, filter]
			if container.get(key, {}).get("bucket", "") != bucket: container[key] = {"bucket": bucket, "value": 0, "unique": {}}
		if not container.has(key): container[key] = {"value": 0, "unique": {}}
		var state: Dictionary = container[key]
		match str(definition.aggregation):
			"sum": state.value = int(state.value) + amount
			"max": state.value = maxi(int(state.value), amount)
			"unique_count":
				if value.is_empty(): continue
				state.unique[value] = true
				state.value = state.unique.size()
		for other in definitions:
			if other.metric == metric and other.scope == scope and str(other.filter) == filter:
				profile.best[other.id] = maxi(int(profile.best.get(other.id, 0)), int(state.value))


func _recheck() -> void:
	# 前置完成前保留计数；同一事实可依次解锁完整前置链。
	var again := true
	while again:
		again = false
		for definition in definitions:
			if not bool(definition.enabled) or profile.unlocked.has(definition.id): continue
			if int(profile.best.get(definition.id, 0)) < int(definition.target): continue
			if not (definition.prerequisites as Array).all(func(id): return profile.unlocked.has(id)): continue
			profile.unlocked[definition.id] = {"time": int(Time.get_unix_time_from_system()), "unread": true, "run_id":run_id if eligible() else ""}
			_dirty = true
			again = true
			# 先落盘再提示；读档、打开总览均不会重复通知。
			save_progress()
			unlocked.emit(str(definition.id))
			if is_instance_valid(_toast): _toast.enqueue(str(definition.id))


func progress(id: String) -> int:
	return int(profile.best.get(id, 0))


func run_unlocks() -> Array:
	var result: Array = []
	if run_id.is_empty(): return result
	for definition: Dictionary in definitions:
		var entry: Dictionary = profile.unlocked.get(str(definition.id), {})
		if str(entry.get("run_id", "")) == run_id:
			result.append(definition.duplicate(true))
	return result


func is_unlocked(id: String) -> bool:
	return profile.unlocked.has(id)


func mark_read(id: String) -> void:
	if not profile.unlocked.has(id): return
	if not bool(profile.unlocked[id].get("unread", false)): return
	profile.unlocked[id].unread = false
	_touch()


func _touch() -> void:
	_dirty = true
	changed.emit()
	if autosave and not _save_queued:
		_save_queued = true
		_flush.call_deferred()


func _flush() -> void:
	_save_queued = false
	if _dirty: save_progress()


func _valid_save(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1: return false
	for key in ["unlocked", "lifetime", "best", "sessions"]:
		if not data.get(key) is Dictionary: return false
	for value in data.best.values():
		if not value is float and not value is int: return false
		if not is_finite(float(value)) or value < 0: return false
	for entry in data.unlocked.values():
		if not entry is Dictionary or not entry.get("time") is float and not entry.get("time") is int: return false
	for entry in data.sessions.values():
		if not _valid_session(entry): return false
	for entry in data.lifetime.values():
		if not _valid_counter(entry): return false
	return true


func _valid_counter(entry: Variant) -> bool:
	if not entry is Dictionary or not entry.get("unique") is Dictionary: return false
	var value: Variant = entry.get("value")
	return (value is float or value is int) and is_finite(float(value)) and value >= 0


func _valid_session(entry: Variant) -> bool:
	if not entry is Dictionary: return false
	for key in ["stats", "seen", "streams"]:
		if not entry.get(key) is Dictionary: return false
	for state in entry.stats.values():
		if not _valid_counter(state): return false
	for value in entry.streams.values():
		if not (value is float or value is int) or not is_finite(float(value)) or value < 0: return false
	return true


func load_progress() -> void:
	if _test_scene() and not test_enabled: return
	if not FileAccess.file_exists(storage_path): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(storage_path))
	if not _valid_save(data):
		data = JSON.parse_string(FileAccess.get_file_as_string(storage_path + ".bak")) if FileAccess.file_exists(storage_path + ".bak") else null
	if not _valid_save(data):
		_writable = false
		push_warning("成就存档无法读取，已保留原文件；本次进度暂不写入。")
		return
	profile = data
	_writable = true
	_recheck()


func save_progress() -> Error:
	if not autosave or not _writable or (_test_scene() and not test_enabled): return OK
	var temporary := storage_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(profile))
	file.flush()
	file.close()
	var absolute := ProjectSettings.globalize_path(storage_path)
	var backup := absolute + ".bak"
	if FileAccess.file_exists(storage_path):
		var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(storage_path))
		if _valid_save(previous):
			DirAccess.copy_absolute(absolute, backup)
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute)
	if error == OK: _dirty = false
	return error
