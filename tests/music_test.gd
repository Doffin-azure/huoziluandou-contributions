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
	var saved_sfx := Settings.sfx_volume
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
	var bgm_bus := AudioServer.get_bus_index(Settings.MUSIC_BUS)
	var sfx_bus := AudioServer.get_bus_index(Settings.SFX_BUS)
	check(bgm_bus > 0 and sfx_bus > 0 and bgm_bus != sfx_bus, "BGM 与音效使用独立总线")
	check(AudioServer.is_bus_mute(bgm_bus), "音乐音量 0 时完全静音")
	Music.play("explore")
	Settings.set_sfx_volume(0.25)
	await get_tree().create_timer(Music.FADE + 0.1).timeout
	check(AudioServer.is_bus_mute(bgm_bus), "静音后切曲及调节音效仍保持 BGM 静音")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) - 0.25) < 0.001, "音效独立调到 25%")
	Settings.set_music_volume(saved)
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(bgm_bus)) - saved) < 0.001, "BGM 总线恢复用户音量")
	check(absf(Music._players[Music._active].volume_db - Music._target_db()) < 0.01, "恢复音量")
	var audio := BattleAudio.new()
	add_child(audio)
	audio.play_cue("gravity")
	check(audio._voices[0].bus == Settings.SFX_BUS and audio._voices[0].playing, "战斗音效接入 SFX 总线")
	Settings.set_sfx_volume(0.5)
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) - 0.5) < 0.001 and audio._voices[0].playing, "播放中的音效实时调整音量")
	var overlay := SettingsOverlay.new()
	add_child(overlay)
	await get_tree().process_frame
	var bgm_slider := overlay.find_child("BGMVolume", true, false).find_child("Slider", true, false) as HSlider
	var sfx_slider := overlay.find_child("SFXVolume", true, false).find_child("Slider", true, false) as HSlider
	bgm_slider.value = 35
	sfx_slider.value = 0
	check(is_equal_approx(Settings.music_volume, 0.35) and Settings.sfx_volume == 0.0, "设置页两条滑杆独立生效")
	check(AudioServer.is_bus_mute(sfx_bus) and not AudioServer.is_bus_mute(bgm_bus), "音效静音不影响 BGM")
	var cfg := ConfigFile.new()
	check(cfg.load(Settings.storage_path) == OK and is_equal_approx(float(cfg.get_value("audio", "music_volume")), 0.35) and float(cfg.get_value("audio", "sfx_volume")) == 0.0, "两类音量独立保存")
	overlay.free()
	audio.free()
	Settings.set_music_volume(saved)
	Settings.set_sfx_volume(saved_sfx)
	Music.stop()
	# 音频线程下一次混音才释放播放实例
	await get_tree().create_timer(0.3).timeout
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.storage_path))
	Settings.storage_path = saved_path
	print("[music_test] PASS=%d FAIL=%d TOTAL=%d" % [checks - failures, failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
