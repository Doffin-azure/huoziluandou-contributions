extends Button
class_name HintButton
## Shared readable hints and touch targets, scoped to the owning screen's skin.
func _ready() -> void:
	if JourneyStyle.is_active(self):
		custom_minimum_size.y = maxf(custom_minimum_size.y, 48 * JourneyStyle.touch_scale(self))
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _make_custom_tooltip(for_text: String) -> Object:
	# 引擎也会对没有提示文字的按钮调用此方法；返回空节点仍会画出面板。
	if for_text.strip_edges().is_empty(): return null
	if JourneyStyle.is_active(self):
		var hint := JourneyStyle.label(for_text)
		hint.theme = JourneyStyle.get_theme()
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size.x = minf(420, get_viewport_rect().size.x - 48)
		return hint
	return Ink.tooltip(for_text)
