extends Node
## 玩家设置（持久化到 user://settings.cfg）。
## 手感、音效、视觉风格与字盘字体分开持久化。

signal changed
signal board_font_changed(path: String)

const PATH := "user://settings.cfg"
var storage_path := PATH

## 拖拽连线后“松手立即出字”。
##   false（默认）：松手只保留选择，需要按【出字】或回车/空格确认 —— 节奏更从容。
##   true：松手即结算（旧的手感，节奏更快）。
var drag_release_play: bool = false

## 视觉风格固定为青铜绘卷；旧主题配置迁移到当前定稿。
var visual_style: String = "taopunk"
var board_font_path := ""
var reduced_motion: bool = false
var sfx_volume := 0.65

var _cfg := ConfigFile.new()


func _ready() -> void:
	if _cfg.load(storage_path) == OK:
		drag_release_play = bool(_cfg.get_value("input", "drag_release_play", drag_release_play))
		var stored_style := str(_cfg.get_value("visual", "art_style", visual_style))
		visual_style = GameStyle.normalize_id(stored_style)
		board_font_path = str(_cfg.get_value("visual", "board_font", ""))
		reduced_motion = bool(_cfg.get_value("visual", "reduced_motion", false))
		sfx_volume = clampf(float(_cfg.get_value("audio", "sfx_volume", 0.65)), 0.0, 1.0)
		if stored_style != visual_style or _cfg.has_section_key("visual", "style"):
			_save()


func set_drag_release_play(value: bool) -> void:
	if drag_release_play == value:
		return
	drag_release_play = value
	_save()
	changed.emit()


func set_visual_style(style_id: String) -> void:
	style_id = GameStyle.normalize_id(style_id)
	if visual_style == style_id:
		return
	visual_style = style_id
	_save()
	changed.emit()


func _save() -> void:
	_cfg.set_value("input", "drag_release_play", drag_release_play)
	if _cfg.has_section_key("visual", "style"):
		_cfg.erase_section_key("visual", "style")
	_cfg.set_value("visual", "art_style", visual_style)
	_cfg.set_value("visual", "board_font", board_font_path)
	_cfg.set_value("visual", "reduced_motion", reduced_motion)
	_cfg.set_value("audio", "sfx_volume", sfx_volume)
	_cfg.save(storage_path)


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_save()
	changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_save()
	changed.emit()


func set_board_font_path(path: String) -> void:
	if path == board_font_path: return
	board_font_path = path
	_save()
	board_font_changed.emit(path)
