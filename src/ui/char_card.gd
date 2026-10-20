extends PanelContainer
class_name CharCard
## Shared glyph specimen: paper face, dark frame and restrained rarity notches.
signal clicked
signal hovered

var character: CharacterData
var compact := false
var selected := false
var _glyph: Label
var _desc: EffectText
var _title: Label
var _tags: Label
var _rank: Label
var _hover := false
var _motion: Tween
var _tap := TouchTap.new()


func setup(p_character: CharacterData, p_compact := false) -> void:
	character = p_character
	compact = p_compact
	if is_node_ready(): _apply()


func _ready() -> void:
	JourneyStyle.apply(self)
	custom_minimum_size = custom_minimum_size.max(Vector2(220, 314) if not compact else Vector2(280, 100))
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	var mobile := JourneyStyle.touch_scale(self) > 1.1
	var col := Ink.vbox(8 if mobile else 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var face := PanelContainer.new()
	face.add_theme_stylebox_override("panel", JourneyStyle.frame("paper", 10))
	face.custom_minimum_size.y = (96 if mobile else 124) if not compact else 60
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(face)
	_glyph = Ink.label("", "", JourneyStyle.DARK_TEXT)
	_glyph.add_theme_font_override("font", Ink.serif)
	_glyph.add_theme_font_size_override("font_size", (64 if mobile else 76) if not compact else 40)
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(_glyph)
	var row := Ink.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_title = JourneyStyle.label("", "Subheading")
	row.add_child(_title)
	var spacer := Ink.expander()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	_rank = JourneyStyle.label("", "Muted", JourneyStyle.GOLD)
	_rank.add_theme_font_size_override("font_size", 11)
	row.add_child(_rank)
	_desc = EffectText.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override("normal_font_size", int(17 * JourneyStyle.touch_scale(self)))
	_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_desc)
	_tags = JourneyStyle.label("", "Muted", JourneyStyle.GOLD)
	_tags.add_theme_font_size_override("font_size", int(14 * JourneyStyle.touch_scale(self)))
	col.add_child(_tags)
	for child in [_title, _tags, _rank]: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply()
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func(): _hover = true; _update_frame(); hovered.emit())
	mouse_exited.connect(func(): _hover = false; _update_frame())
	focus_entered.connect(_update_frame)
	focus_exited.connect(_update_frame)
	resized.connect(func(): pivot_offset = size * 0.5)


func _apply() -> void:
	if character == null: return
	_glyph.text = character.glyph
	_title.text = character.pinyin if not character.pinyin.is_empty() else character.glyph
	_desc.set_effect_text(character.description)
	_rank.text = "◆".repeat(clampi(character.rarity + 1, 1, 4))
	var tags: PackedStringArray = []
	for tag in character.tags: tags.append({"energy": "储能", "flow": "流转"}.get(tag, Palette.tag_label(tag)))
	_tags.text = " · ".join(tags)
	_update_frame()


func set_selected(value: bool) -> void:
	selected = value
	if is_node_ready(): _update_frame()


func _update_frame() -> void:
	add_theme_stylebox_override("panel", JourneyStyle.frame("selected" if selected or has_focus() else ("hover" if _hover else "card"), 18))


func _on_gui_input(event: InputEvent) -> void:
	if _tap.matches(event, self):
		clicked.emit()
		accept_event()


func play_focus() -> void:
	if Settings.reduced_motion: return
	if _motion != null: _motion.kill()
	_motion = create_tween()
	_motion.tween_property(self, "scale", Vector2(1.025, 1.025), 0.08)
	_motion.tween_property(self, "scale", Vector2.ONE, 0.12)
