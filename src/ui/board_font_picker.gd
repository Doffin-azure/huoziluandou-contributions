extends VBoxContainer
class_name BoardFontPicker
## 字盘字体独立于正文；导入失败保留当前选择，不重建战斗页面。
var _description: Label
var _dialog: FileDialog


func _ready() -> void:
	add_child(Ink.label("字盘字体", "Subheading"))
	_description = Ink.caption("")
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_description)
	var row := Ink.hbox(10)
	add_child(row)
	var choose := Ink.button("选择字体文件")
	choose.custom_minimum_size.y = 48
	choose.pressed.connect(_open)
	row.add_child(choose)
	var reset := Ink.button("恢复默认")
	reset.custom_minimum_size.y = 48
	reset.pressed.connect(func():
		Settings.set_board_font_path("")
		_refresh())
	row.add_child(reset)
	_refresh()


func _refresh() -> void:
	_description.text = "当前：%s\n只更改字盘汉字，说明与数字保留清晰字体。" % ("内置思源宋体" if Settings.board_font_path.is_empty() else Settings.board_font_path.get_file())
	if not Settings.board_font_path.is_empty() and Ink.board_font == Ink.serif:
		_description.text = "原字体不可用，当前使用内置字体。\n可重新选择文件或恢复默认。"


func _open() -> void:
	if is_instance_valid(_dialog): return
	_dialog = FileDialog.new()
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.use_native_dialog = true
	_dialog.title = "选择字盘字体"
	_dialog.filters = PackedStringArray(["*.ttf, *.otf, *.ttc, *.woff, *.woff2 ; 字体文件"])
	_dialog.file_selected.connect(_choose)
	_dialog.canceled.connect(_close_dialog)
	add_child(_dialog)
	_dialog.popup_centered_ratio(0.8)


func _choose(path: String) -> void:
	if BoardTypography.load_font(path, Ink.serif) == null:
		_description.text = "字体未能读取，已保留当前字体。请选择有效的 TTF / OTF 字体。"
	else:
		Settings.set_board_font_path(path)
		_refresh()
	_close_dialog()


func _close_dialog() -> void:
	if is_instance_valid(_dialog): _dialog.queue_free()
	_dialog = null
