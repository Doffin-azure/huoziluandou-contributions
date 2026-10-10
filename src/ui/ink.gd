extends Node
## Ink —— 全局“美术工具箱”。
## 所有界面都用 Ink.xxx() 组装，不依赖大量 .tscn，改一处即全局换皮。
## - 主题（字体/颜色/按钮/面板）在 _ready() 里构建并套用到窗口。
## - 纸纹、木纹用着色器程序化生成，无需美术资源。

var theme: Theme
var serif: Font
var sans: Font

var _paper_shader: Shader
var _wood_shader: Shader
var _paper_mat: ShaderMaterial


func _ready() -> void:
	_load_fonts()
	_load_shaders()
	theme = _build_theme()
	get_tree().root.theme = theme


func _load_fonts() -> void:
	var bundled := "res://assets/fonts/NotoSerifSC-VF.ttf"
	if ResourceLoader.exists(bundled):
		serif = load(bundled)
	else:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Noto Serif SC", "SimSun", "Microsoft YaHei", "PingFang SC"])
		serif = sf
	sans = serif


func _load_shaders() -> void:
	_paper_shader = load("res://src/shaders/paper.gdshader")
	_wood_shader = load("res://src/shaders/wood.gdshader")
	_paper_mat = ShaderMaterial.new()
	_paper_mat.shader = _paper_shader


# ---------------------------------------------------------------- 主题构建
func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = serif
	t.default_font_size = 17

	t.set_color("font_color", "Label", Palette.INK)
	t.set_font("font", "Label", serif)
	t.set_font("normal_font", "RichTextLabel", serif)
	t.set_font("bold_font", "RichTextLabel", serif)
	t.set_color("default_color", "RichTextLabel", Palette.INK)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())

	# --- 按钮：纸签 ---
	t.set_font("font", "Button", serif)
	t.set_font_size("font_size", "Button", 18)
	t.set_color("font_color", "Button", Palette.INK)
	t.set_color("font_hover_color", "Button", Palette.VERMILION_DK)
	t.set_color("font_pressed_color", "Button", Palette.PAPER)
	t.set_color("font_disabled_color", "Button", Palette.INK_FAINT)
	t.set_stylebox("normal", "Button", _sb(Palette.PAPER_WARM, 8, Palette.INK_SOFT, 2))
	t.set_stylebox("hover", "Button", _sb(Palette.PAPER, 8, Palette.VERMILION, 2))
	t.set_stylebox("pressed", "Button", _sb(Palette.VERMILION_DK, 8, Palette.VERMILION_DK, 2))
	t.set_stylebox("disabled", "Button", _sb(Palette.PAPER_DARK, 8, Palette.PAPER_SHADE, 2))
	t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), 8, Palette.GOLD, 2))
	t.set_constant("outline_size", "Button", 0)

	# --- 面板：纸面卡片 ---
	t.set_stylebox("panel", "PanelContainer", _sb(Palette.PAPER, 10, Palette.PAPER_SHADE, 2))
	t.set_stylebox("panel", "Panel", _sb(Palette.PAPER, 10, Palette.PAPER_SHADE, 2))

	# --- 滚动条 ---
	t.set_stylebox("scroll", "VScrollBar", _sb(Palette.PAPER_DARK, 6, Color(0, 0, 0, 0), 0))
	t.set_stylebox("grabber", "VScrollBar", _sb(Palette.INK_FAINT, 6, Color(0, 0, 0, 0), 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", _sb(Palette.VERMILION, 6, Color(0, 0, 0, 0), 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", _sb(Palette.VERMILION_DK, 6, Color(0, 0, 0, 0), 0))
	t.set_constant("minimum_grab_length", "VScrollBar", 0)

	# --- 文本框 ---
	t.set_stylebox("normal", "LineEdit", _sb(Palette.PAPER, 6, Palette.INK_FAINT, 2))

	# --- 类型变体 ---
	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", serif)
	t.set_font_size("font_size", "Title", 46)
	t.set_color("font_color", "Title", Palette.INK)

	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", serif)
	t.set_font_size("font_size", "Heading", 26)
	t.set_color("font_color", "Heading", Palette.INK)

	t.set_type_variation("Subheading", "Label")
	t.set_font("font", "Subheading", serif)
	t.set_font_size("font_size", "Subheading", 20)
	t.set_color("font_color", "Subheading", Palette.INK_SOFT)

	t.set_type_variation("Muted", "Label")
	t.set_font("font", "Muted", serif)
	t.set_font_size("font_size", "Muted", 15)
	t.set_color("font_color", "Muted", Palette.INK_FAINT)

	t.set_type_variation("Stat", "Label")
	t.set_font("font", "Stat", serif)
	t.set_font_size("font_size", "Stat", 22)
	t.set_color("font_color", "Stat", Palette.INK)

	t.set_type_variation("PanelCard", "PanelContainer")
	t.set_stylebox("panel", "PanelCard", _sb(Palette.PAPER, 10, Palette.PAPER_SHADE, 2))

	t.set_type_variation("PanelDark", "PanelContainer")
	t.set_stylebox("panel", "PanelDark", _sb(Color("2b2620"), 12, Palette.GOLD_DK, 2))

	t.set_type_variation("PanelInset", "PanelContainer")
	t.set_stylebox("panel", "PanelInset", _sb(Palette.PAPER_WARM, 8, Palette.PAPER_SHADE, 1))

	t.set_type_variation("PrimaryButton", "Button")
	t.set_color("font_color", "PrimaryButton", Palette.PAPER)
	t.set_color("font_hover_color", "PrimaryButton", Palette.PAPER)
	t.set_color("font_pressed_color", "PrimaryButton", Palette.PAPER)
	t.set_stylebox("normal", "PrimaryButton", _sb(Palette.VERMILION, 8, Palette.VERMILION_DK, 2))
	t.set_stylebox("hover", "PrimaryButton", _sb(Palette.VERMILION_DK, 8, Palette.GOLD, 2))
	t.set_stylebox("pressed", "PrimaryButton", _sb(Palette.VERMILION_DK, 8, Palette.VERMILION_DK, 2))
	t.set_stylebox("focus", "PrimaryButton", _sb(Color(0, 0, 0, 0), 8, Palette.GOLD, 2))

	t.set_type_variation("GhostButton", "Button")
	t.set_color("font_color", "GhostButton", Palette.INK_SOFT)
	t.set_stylebox("normal", "GhostButton", _sb(Color(0, 0, 0, 0), 8, Palette.INK_FAINT, 1))
	t.set_stylebox("hover", "GhostButton", _sb(Palette.PAPER_WARM, 8, Palette.INK_SOFT, 1))

	t.set_type_variation("DangerButton", "Button")
	t.set_color("font_color", "DangerButton", Palette.PAPER)
	t.set_stylebox("normal", "DangerButton", _sb(Palette.PLUM, 8, Palette.VERMILION_DK, 2))
	t.set_stylebox("hover", "DangerButton", _sb(Palette.VERMILION_DK, 8, Palette.GOLD, 2))

	return t


func _sb(bg: Color, radius: int, border: Color, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_content_margin_all(10)
	return sb


# ---------------------------------------------------------------- 工厂方法
func paper_layer(stain := 0.45) -> ColorRect:
	var cr := ColorRect.new()
	var mat := _paper_mat.duplicate() as ShaderMaterial
	mat.set_shader_parameter("stain_amount", stain)
	cr.material = mat
	cr.color = Color.WHITE
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.name = "PaperLayer"
	return cr


func label(text: String, variation: String = "", override_color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if not variation.is_empty():
		l.theme_type_variation = variation
	if override_color.a > 0.0:
		l.add_theme_color_override("font_color", override_color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.08))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func h1(text: String) -> Label:
	return label(text, "Title")


func h2(text: String) -> Label:
	return label(text, "Heading")


func caption(text: String) -> Label:
	var l := label(text, "Muted")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func body(text: String) -> Label:
	var l := label(text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "PrimaryButton" if primary else ""
	b.custom_minimum_size = Vector2(0, 42)
	b.focus_mode = Control.FOCUS_NONE
	return b


func panel(variation := "PanelCard") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


func card() -> PanelContainer:
	return panel("PanelCard")


func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func margin(all := 16) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", all)
	m.add_theme_constant_override("margin_right", all)
	m.add_theme_constant_override("margin_top", all)
	m.add_theme_constant_override("margin_bottom", all)
	return m


func spacer(size: float, vertical := true) -> Control:
	var c := Control.new()
	if vertical:
		c.custom_minimum_size = Vector2(0, size)
	else:
		c.custom_minimum_size = Vector2(size, 0)
	return c


func hline(color := Palette.PAPER_SHADE) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(0, 2)
	return c


func expander() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func rich(text: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = text
	r.fit_content = true
	r.scroll_active = false
	return r


func make_wood_material(tint := Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _wood_shader
	mat.set_shader_parameter("wood_dark", Palette.WOOD_DARK * tint)
	mat.set_shader_parameter("wood_light", Palette.WOOD_LIGHT * tint)
	return mat
