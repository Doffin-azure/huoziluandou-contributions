extends VBoxContainer
class_name BoardFontPicker
## 内置字盘字体切换，不打开文件选择器，不重建战斗页面。
var _description: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	add_child(Ink.label("字盘字体", "Subheading"))
	_description = Ink.caption("")
	add_child(_description)
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	add_child(row)
	for entry in BoardTypography.STYLES:
		var choose := Ink.button(entry.name)
		choose.toggle_mode = true
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choose.custom_minimum_size.y = 48 * JourneyStyle.touch_scale(self)
		choose.add_theme_font_override("font", BoardTypography.font_for_id(entry.id))
		choose.pressed.connect(_choose.bind(entry.id))
		row.add_child(choose)
		_buttons[entry.id] = choose
	Settings.board_font_changed.connect(_refresh)
	_refresh()


func _refresh(_font_id: String = "") -> void:
	_description.text = "当前：%s\n字体已内置，只更改字盘汉字；正文保持清晰易读。" % BoardTypography.display_name(Settings.board_font_id)
	for font_id in _buttons:
		_buttons[font_id].set_pressed_no_signal(font_id == Settings.board_font_id)


func _choose(font_id: String) -> void:
	Settings.set_board_font_id(font_id)
	_refresh()
