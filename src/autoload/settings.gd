extends Node
## 玩家设置（持久化到 user://settings.cfg）。
## 手感、音效、视觉风格与字盘字体分开持久化。

signal changed
signal board_font_changed(font_id: String)

const PATH := "user://settings.cfg"
var storage_path := PATH

## 拖拽连线后“松手立即出字”。
##   false（默认）：松手只保留选择，需要按【出字】或回车/空格确认 —— 节奏更从容。
##   true：松手即结算（旧的手感，节奏更快）。
var drag_release_play: bool = false

## 视觉风格固定为青铜绘卷；旧主题配置迁移到当前定稿。
var visual_style: String = "taopunk"
var board_font_id := BoardTypography.DEFAULT_ID
var reduced_motion: bool = false
var sfx_volume := 0.65
var music_volume := 0.6
var bgm_volume := 0.35
var first_run_tutorial_completed := false
var route_hint_seen := false

var _cfg := ConfigFile.new()


func _ready() -> void:
	if _cfg.load(storage_path) == OK:
		drag_release_play = bool(_cfg.get_value("input", "drag_release_play", drag_release_play))
		var stored_style := str(_cfg.get_value("visual", "art_style", visual_style))
		visual_style = GameStyle.normalize_id(stored_style)
		var stored_font := str(_cfg.get_value("visual", "board_font_id", BoardTypography.DEFAULT_ID))
		board_font_id = BoardTypography.normalize_id(stored_font)
		reduced_motion = bool(_cfg.get_value("visual", "reduced_motion", false))
		sfx_volume = clampf(float(_cfg.get_value("audio", "sfx_volume", 0.65)), 0.0, 1.0)
		music_volume = clampf(float(_cfg.get_value("audio", "music_volume", 0.6)), 0.0, 1.0)
		bgm_volume = clampf(float(_cfg.get_value("audio", "bgm_volume", 0.35)), 0.0, 1.0)
		first_run_tutorial_completed = bool(_cfg.get_value("onboarding", "first_run_tutorial_completed", false))
		route_hint_seen = bool(_cfg.get_value("guides", "route_hint_seen", false))
		if stored_style != visual_style or _cfg.has_section_key("visual", "style") or stored_font != board_font_id or _cfg.has_section_key("visual", "board_font"):
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
	# 迁移旧版外部字体配置；不读取或解析该路径指向的任何文件。
	if _cfg.has_section_key("visual", "board_font"):
		_cfg.erase_section_key("visual", "board_font")
	_cfg.set_value("visual", "board_font_id", board_font_id)
	_cfg.set_value("visual", "reduced_motion", reduced_motion)
	_cfg.set_value("audio", "sfx_volume", sfx_volume)
	_cfg.set_value("audio", "music_volume", music_volume)
	_cfg.set_value("audio", "bgm_volume", bgm_volume)
	_cfg.set_value("onboarding", "first_run_tutorial_completed", first_run_tutorial_completed)
	_cfg.set_value("guides", "route_hint_seen", route_hint_seen)
	_cfg.save(storage_path)


func dismiss_route_hint() -> void:
	if route_hint_seen: return
	route_hint_seen = true
	_save()


func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	_save()
	changed.emit()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_save()
	changed.emit()


func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_save()
	changed.emit()


func complete_first_run_tutorial() -> void:
	if first_run_tutorial_completed: return
	first_run_tutorial_completed = true
	_save()


func set_board_font_id(font_id: String) -> void:
	if not BoardTypography.is_builtin(font_id) or font_id == board_font_id: return
	board_font_id = font_id
	_save()
	board_font_changed.emit(font_id)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_save()
	changed.emit()
