extends Button
class_name HintButton
## 悬停说明共享纸底、墨字和换行宽度，不继承引擎默认的深色提示框。
func _make_custom_tooltip(for_text: String) -> Object:
	return Ink.tooltip(for_text)
