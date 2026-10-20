extends RefCounted
class_name JourneyStyle
## A local UI skin for the journey screens; battle palette and game state stay independent.
const TEXT := Color("e6d8b6")
const MUTED := Color("a6b5a5")
const GOLD := Color("c6aa70")
const COIN := Color("fff2b0")
const RED := Color("bd5143")
const INK := Color("10262f")
const SURFACE := Color("18333b")
const EDGE := Color("51625a")
const DARK_TEXT := Color("252c2b")
const ROOT := "res://assets/ui/journey/"
static var _theme: Theme
static var _textures: Dictionary = {}
static var _scaled_themes: Dictionary = {}


static func currency(label: Label) -> void:
	label.add_theme_color_override("font_color", COIN)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)


static func frame(kind := "panel", inset := 14.0) -> StyleBoxTexture:
	if not _textures.has(kind): _textures[kind] = load(ROOT + "frame_%s.svg" % kind)
	var skin := StyleBoxTexture.new()
	skin.texture = _textures[kind]
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_texture_margin(side, 24.0)
		skin.set_content_margin(side, inset)
	return skin


static func apply(control: Control) -> void:
	var scale := touch_scale(control)
	var key := snappedf(scale, 0.02)
	if scale > 1.01:
		if not _scaled_themes.has(key):
			var readable := get_theme().duplicate() as Theme
			readable.default_font_size = int(18 * scale)
			for type in readable.get_type_list():
				for property in readable.get_font_size_list(type):
					readable.set_font_size(property, type, int(get_theme().get_font_size(property, type) * scale))
			_scaled_themes[key] = readable
		control.theme = _scaled_themes[key]
	else:
		control.theme = get_theme()
	control.set_meta("journey_ui", true)


static func is_active(node: Node) -> bool:
	var parent := node
	while parent != null:
		if parent.get_meta("journey_ui", false): return true
		parent = parent.get_parent()
	return false


static func get_theme() -> Theme:
	if _theme != null: return _theme
	var theme := Theme.new()
	theme.default_font = Ink.sans
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", TEXT)
	theme.set_font("font", "Label", Ink.sans)
	for item in [["Title", 42, TEXT], ["Heading", 30, TEXT], ["Subheading", 21, TEXT], ["Muted", 16, MUTED], ["Stat", 23, GOLD]]:
		theme.set_type_variation(item[0], "Label")
		theme.set_font("font", item[0], Ink.serif)
		theme.set_font_size("font_size", item[0], item[1])
		theme.set_color("font_color", item[0], item[2])
	theme.set_font("normal_font", "RichTextLabel", Ink.sans)
	theme.set_font("bold_font", "RichTextLabel", Ink.serif)
	theme.set_color("default_color", "RichTextLabel", TEXT)
	for panel_type in ["PanelContainer", "Panel"]: theme.set_stylebox("panel", panel_type, frame())
	for item in [["PanelCard", "panel"], ["PanelInset", "inset"], ["PanelDark", "card"], ["StagePanel", "inset"]]:
		theme.set_type_variation(item[0], "PanelContainer")
		theme.set_stylebox("panel", item[0], frame(item[1]))
	theme.set_font("font", "Button", Ink.serif)
	theme.set_font_size("font_size", "Button", 19)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		theme.set_color(state, "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", Color("82938b"))
	for item in [["normal", "panel"], ["hover", "hover"], ["pressed", "pressed"], ["disabled", "disabled"], ["focus", "selected"]]:
		theme.set_stylebox(item[0], "Button", frame(item[1], 10))
	for variation in ["PrimaryButton", "GhostButton", "DangerButton"]:
		theme.set_type_variation(variation, "Button")
		theme.set_color("font_color", variation, TEXT)
		theme.set_color("font_hover_color", variation, Color("f2e5c3"))
		theme.set_color("font_pressed_color", variation, TEXT)
		theme.set_color("font_disabled_color", variation, Color("82938b"))
		if variation != "GhostButton": theme.set_stylebox("normal", variation, frame("primary", 10))
	for bar in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = INK
		track.set_content_margin_all(3)
		theme.set_stylebox("scroll", bar, track)
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var grab := StyleBoxFlat.new()
			grab.bg_color = GOLD if state != "grabber" else EDGE
			grab.set_content_margin_all(3)
			theme.set_stylebox(state, bar, grab)
	theme.set_stylebox("panel", "TooltipPanel", frame("panel", 14))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 18)
	theme.set_font("font", "TooltipLabel", Ink.sans)
	theme.set_stylebox("normal", "LineEdit", frame("inset", 10))
	theme.set_color("font_color", "LineEdit", TEXT)
	var rail := StyleBoxFlat.new()
	rail.bg_color = INK
	rail.border_color = EDGE
	rail.set_border_width_all(1)
	rail.set_content_margin_all(3)
	theme.set_stylebox("slider", "HSlider", rail)
	var filled := rail.duplicate() as StyleBoxFlat
	filled.bg_color = GOLD.darkened(0.2)
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		theme.set_icon(state, "HSlider", load(ROOT + "slider_grab.svg"))
	_theme = theme
	return theme


static func touch_scale(control: Control) -> float:
	return BattleTouchLayout.unit_for(control.get_viewport_rect().size, control.get_window().size)


static func button(caption: String, action: Callable, primary := false) -> Button:
	var control := Ink.button(caption, primary)
	control.custom_minimum_size.y = 48
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if action.is_valid(): control.pressed.connect(action)
	return control


static func label(caption: String, variation := "", color := TEXT) -> Label:
	return Ink.label(caption, variation, color)


static func section(caption: String, detail := "") -> Control:
	var row := Ink.hbox(14)
	row.add_child(label(caption, "Subheading", GOLD))
	var line := ColorRect.new()
	line.color = Color(EDGE, 0.6)
	line.custom_minimum_size.y = 1
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	if not detail.is_empty(): row.add_child(label(detail, "Muted", MUTED))
	return row


static func page(root: Control) -> VBoxContainer:
	var mobile := root.get_viewport_rect().size.x / touch_scale(root) < 1100
	var pad := Ink.margin(16 if mobile else 28)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(pad)
	var col := Ink.vbox(12 if mobile else 20)
	pad.add_child(col)
	return col


static func heading(caption: String, detail: String, accessory: Control = null) -> Control:
	var panel := Ink.panel("PanelInset")
	var window := Engine.get_main_loop().root as Window
	var compact := window.get_visible_rect().size.x / BattleTouchLayout.unit_for(window.get_visible_rect().size, window.size) < 1000
	var row := Ink.hbox(12 if compact else 24)
	var unit := BattleTouchLayout.unit_for(window.get_visible_rect().size, window.size)
	if compact: panel.add_theme_stylebox_override("panel", frame("inset", 8))
	panel.add_child(row)
	var col := Ink.vbox(3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := label(caption, "Heading")
	if compact: title.add_theme_font_size_override("font_size", int(20 * unit))
	col.add_child(title)
	var description := label(detail, "Muted")
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if compact: description.add_theme_font_size_override("font_size", int(12 * unit))
	col.add_child(description)
	row.add_child(col)
	if accessory != null: row.add_child(accessory)
	return panel


static func flow(gap := 10) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", gap)
	row.add_theme_constant_override("v_separation", gap)
	return row
