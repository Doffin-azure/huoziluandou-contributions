extends Node
## 背景音乐：选曲映射、四首曲子可加载、失败曲不循环、音量设置生效。

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[music_test] FAIL: " + message)


func _ready() -> void:
	check(Music.track_for_screen("res://src/screens/title_screen.gd") == "title", "标题界面用开始界面曲")
	check(Music.track_for_screen("res://src/screens/battle_screen.gd") == "battle", "战斗界面用战斗曲")
	for screen in ["expedition_map_screen", "map_screen", "reward_screen", "shop_screen", "rest_screen", "event_screen"]:
		check(Music.track_for_screen("res://src/screens/%s.gd" % screen) == "explore", screen + " 用探索曲")
	check(Music.track_for_screen("res://src/tools/board_sim.gd") == "", "调试工具不换曲")
	for track in Music.TRACKS:
		check(load(Music.TRACKS[track]) is AudioStreamMP3, track + " 可加载")
	var saved := Settings.music_volume
	var saved_path := Settings.storage_path
	Settings.storage_path = "user://music_test_settings.cfg"
	Music.play("battle")
	check(Music.current == "battle" and Music._players[Music._active].playing, "切到战斗曲并开始播放")
	check((Music._players[Music._active].stream as AudioStreamMP3).loop, "战斗曲循环")
	Music.play("defeat")
	check(Music.current == "defeat" and not (Music._players[Music._active].stream as AudioStreamMP3).loop, "失败曲只播一遍")
	await get_tree().create_timer(Music.FADE + 0.2).timeout
	check(not Music._players[1 - Music._active].playing, "淡出后旧曲停止")
	Settings.set_music_volume(0.0)
	check(Music._players[Music._active].volume_db <= Music.SILENT_DB, "音乐音量 0 时静音")
	Settings.set_music_volume(saved)
	check(absf(Music._players[Music._active].volume_db - Music._target_db()) < 0.01, "恢复音量")
	Music.stop()
	# 音频线程下一次混音才释放播放实例
	await get_tree().create_timer(0.1).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.storage_path))
	Settings.storage_path = saved_path
	print("[music_test] PASS=%d FAIL=%d TOTAL=%d" % [checks - failures, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
