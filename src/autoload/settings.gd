extends Node
## 玩家设置（持久化到 user://settings.cfg）。
## 手感、音效、视觉风格与字盘字体分开持久化。

signal changed
signal board_font_changed(path: String)

const MUSIC_BUS := &"BGM"
const SFX_BUS := &"SFX"

const PATH := "user://settings.cfg"
var storage_path := PATH

## 拖拽连线后“松手立即出字”。
##   false（默认）：松手只保留选择，需要按【出字】或回车/空格确认 —— 节奏更从容。
##   true：松手即结算（旧的手感，节奏更快）。
var drag_release_play: bool = false

## 视觉风格：taopunk 为当前定稿；paper / neon 保留为可选旧版。
var visual_style: String = "taopunk"
var board_font_path := ""
var reduced_motion: bool = false
var sfx_volume := 0.65
var music_volume := 0.6

var _cfg := ConfigFile.new()


func _ready() -> void:
	if _cfg.load(storage_path) == OK:
		drag_release_play = bool(_cfg.get_value("input", "drag_release_play", drag_release_play))
		# 定稿启用独立的风格键，旧版 style 不覆盖新默认；仍可主动切回旧版。
		visual_style = str(_cfg.get_value("visual", "art_style", visual_style))
		board_font_path = str(_cfg.get_value("visual", "board_font", ""))
		reduced_motion = bool(_cfg.get_value("visual", "reduced_motion", false))
		sfx_volume = clampf(float(_cfg.get_value("audio", "sfx_volume", 0.65)), 0.0, 1.0)
		music_volume = clampf(float(_cfg.get_value("audio", "music_volume", 0.6)), 0.0, 1.0)

	_apply_audio_volumes()


func _apply_audio_volumes() -> void:
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)


func _set_bus_volume(bus_name: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))


func set_drag_release_play(value: bool) -> void:
	if drag_release_play == value:
		return
	drag_release_play = value
	_save()
	changed.emit()


func set_visual_style(style_id: String) -> void:
	if visual_style == style_id:
		return
	visual_style = style_id
	_save()
	changed.emit()


func _save() -> void:
	_cfg.set_value("input", "drag_release_play", drag_release_play)
	_cfg.set_value("visual", "style", visual_style)
	_cfg.set_value("visual", "art_style", visual_style)
	_cfg.set_value("visual", "board_font", board_font_path)
	_cfg.set_value("visual", "reduced_motion", reduced_motion)
	_cfg.set_value("audio", "sfx_volume", sfx_volume)
	_cfg.set_value("audio", "music_volume", music_volume)
	_cfg.save(storage_path)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_save()
	changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(SFX_BUS, sfx_volume)
	_save()
	changed.emit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume(MUSIC_BUS, music_volume)
	_save()
	changed.emit()


func set_board_font_path(path: String) -> void:
	if path == board_font_path: return
	board_font_path = path
	_save()
	board_font_changed.emit(path)
