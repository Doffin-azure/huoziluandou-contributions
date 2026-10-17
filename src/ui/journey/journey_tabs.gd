extends VBoxContainer
## A view-only switcher. Each pane retains its controls and scroll position.
var _bar: HBoxContainer
var _pages: Dictionary = {}
var _buttons: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 8)
	add_child(_bar)


func add_tab(caption: String, page: Control) -> void:
	var button := JourneyStyle.button(caption, show_tab.bind(caption))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.add_child(button)
	_buttons[caption] = button
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	add_child(scroll)
	_pages[caption] = scroll
	show_tab(_pages.keys()[0])


func show_tab(caption: String) -> void:
	if not _pages.has(caption): return
	for key in _pages:
		_pages[key].visible = key == caption
		_buttons[key].theme_type_variation = "PrimaryButton" if key == caption else "GhostButton"
