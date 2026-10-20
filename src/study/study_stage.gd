extends Control
class_name StudyStage
## 沿用路由宿主名称；只承载青铜绘卷背景，不再创建旧书房、桌面或共享视口。
var _illustrated_backdrop: TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_illustrated_backdrop = TextureRect.new()
	_illustrated_backdrop.texture = TaopunkArt.background()
	_illustrated_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illustrated_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_illustrated_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_illustrated_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_illustrated_backdrop)
	hide()


func set_screen(path: String) -> void:
	visible = path.ends_with("/battle_screen.gd")
