extends Node
## 全局 BGM 播放器。Suno 导出的本地文件放入 assets/audio/bgm/ 后自动接入。

const AUDIO_ROOT := "res://assets/audio/bgm/"
const FADE_SECONDS := 0.8
const TRACKS := {
	"title": "title_menu.ogg",
	"exploration": "exploration.ogg",
	"combat": "combat.ogg",
	"boss": "boss.ogg",
	"victory": "victory.ogg",
	"defeat": "defeat.ogg",
}

var _players: Array[AudioStreamPlayer] = []
var _active := -1
var _track_id := ""
var _tween: Tween
var _cache: Dictionary = {}
var _music_bus := -1


func _ready() -> void:
	if has_node("/root/Music"): return
	_music_bus = AudioServer.get_bus_index("Music")
	if _music_bus < 0:
		AudioServer.add_bus()
		_music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus, "Music")
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	Settings.changed.connect(_on_settings_changed)
	if not Router.route_changed.is_connected(_on_route_changed):
		Router.route_changed.connect(_on_route_changed)
	if Router.current_path != "":
		_on_route_changed(Router.current_path)


func _exit_tree() -> void:
	if Settings.changed.is_connected(_on_settings_changed):
		Settings.changed.disconnect(_on_settings_changed)
	if Router.route_changed.is_connected(_on_route_changed):
		Router.route_changed.disconnect(_on_route_changed)
	if _tween != null:
		_tween.kill()


func _on_settings_changed() -> void:
	if _active >= 0 and _active < _players.size():
		_players[_active].volume_db = _target_db()


func _on_route_changed(screen_path: String) -> void:
	var next := _track_for_path(screen_path)
	if next == _track_id:
		return
	_play_track(next)


func _track_for_path(screen_path: String) -> String:
	if screen_path.contains("battle_screen"):
		return "boss" if screen_path.contains("boss") else "combat"
	if screen_path.contains("title_screen"):
		return "title"
	if screen_path.contains("reward_screen"):
		return "victory"
	if screen_path.contains("defeat"):
		return "defeat"
	return "exploration"


func _stream_for(track_id: String) -> AudioStream:
	if track_id == "" or not TRACKS.has(track_id):
		return null
	if _cache.has(track_id):
		return _cache[track_id]
	var path := AUDIO_ROOT + str(TRACKS[track_id])
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_cache[track_id] = stream
	return stream


func _play_track(track_id: String) -> void:
	_track_id = track_id
	var stream := _stream_for(track_id)
	if stream == null:
		if _active >= 0:
			_players[_active].stop()
			_players[_active].volume_db = -80.0
		_active = -1
		return
	var next := 0 if _active != 0 else 1
	var incoming := _players[next]
	var outgoing := _players[_active] if _active >= 0 else null
	if _tween != null:
		_tween.kill()
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	_active = next
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(incoming, "volume_db", _target_db(), FADE_SECONDS)
	if outgoing != null:
		_tween.tween_property(outgoing, "volume_db", -80.0, FADE_SECONDS)
		_tween.chain().tween_callback(outgoing.stop)


func _target_db() -> float:
	return -80.0 if Settings.bgm_volume <= 0.001 else linear_to_db(Settings.bgm_volume)


func current_track() -> String:
	return _track_id


func has_local_track(track_id: String) -> bool:
	return _stream_for(track_id) != null
