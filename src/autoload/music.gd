extends Node
## 背景音乐：标题 / 探索 / 战斗 / 失败四首，切屏时交叉淡入淡出。
## Router.goto 按屏幕路径选曲；失败曲由战斗结算主动切换。

const TRACKS := {
	"title": "res://assets/audio/music/title.mp3",
	"explore": "res://assets/audio/music/explore.mp3",
	"battle": "res://assets/audio/music/battle.mp3",
	"defeat": "res://assets/audio/music/defeat.mp3",
}
## 失败曲只播一遍，其余循环。
const ONE_SHOT := ["defeat"]
const FADE := 0.8
const SILENT_DB := -60.0

var current := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)
	Settings.changed.connect(_apply_volume)


## 按屏幕脚本路径选曲；未知屏幕（调试工具等）不换曲。
func track_for_screen(screen_path: String) -> String:
	if screen_path.ends_with("/title_screen.gd"):
		return "title"
	if screen_path.ends_with("/battle_screen.gd"):
		return "battle"
	if screen_path.begins_with("res://src/screens/"):
		return "explore"
	return ""


func for_screen(screen_path: String) -> void:
	var track := track_for_screen(screen_path)
	if not track.is_empty():
		play(track)


func play(track: String) -> void:
	if track == current or not TRACKS.has(track):
		return
	var stream := load(TRACKS[track]) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = not ONE_SHOT.has(track)
	current = track
	var old := _players[_active]
	_active = 1 - _active
	var next := _players[_active]
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(next, "volume_db", _target_db(), FADE)
	if old.playing:
		_tween.tween_property(old, "volume_db", SILENT_DB, FADE)
		_tween.chain().tween_callback(old.stop)


func stop() -> void:
	current = ""
	if _tween != null:
		_tween.kill()
	for player in _players:
		player.stop()
		player.stream = null


func _exit_tree() -> void:
	stop()


func _target_db() -> float:
	return linear_to_db(maxf(Settings.music_volume, 0.001)) - 6.0


func _apply_volume() -> void:
	var player := _players[_active]
	if _tween != null and _tween.is_running():
		_tween.kill()
		_players[1 - _active].stop()
	player.volume_db = _target_db() if Settings.music_volume > 0.0 else SILENT_DB
