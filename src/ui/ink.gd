extends Node
## Ink —— 全局“美术工具箱”。
## 所有界面都用 Ink.xxx() 组装；改一处即全局换皮。
## 风格由 GameStyle 令牌驱动，可运行时切换（宣纸 / 墨芯）。

var theme: Theme
var serif: Font
var sans: Font
var style: GameStyle

var _paper_shader: Shader
var _bg_neon_shader: Shader
var _wood_shader: Shader
var _tile_neon_shader: Shader


func _ready() -> void:
	_load_fonts()
	_load_shaders()
	var sid := "paper"
	if Settings != null and "visual_style" in Settings:
		sid = Settings.visual_style
	apply_style(GameStyle.get_style(sid))


## 切换风格：更新令牌 + 重建主题。
func apply_style(new_style: GameStyle) -> void:
	style = new_style
	Palette.apply(new_style)
	theme = _build_theme()
	if get_tree() != null:
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
	_bg_neon_shader = load("res://src/shaders/bg_neon.gdshader")
	_wood_shader = load("res://src/shaders/wood.gdshader")
	_tile_neon_shader = load("res://src/shaders/tile_neon.gdshader")


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

	# --- 按钮 ---
	t.set_font("font", "Button", serif)
	t.set_font_size("font_size", "Button", 18)
	t.set_color("font_color", "Button", Palette.INK)
	t.set_color("font_hover_color", "Button", Palette.VERMILION)
	t.set_color("font_pressed_color", "Button", Palette.PAPER)
	t.set_color("font_disabled_color", "Button", Palette.INK_FAINT)
	t.set_stylebox("normal", "Button", _sb(Palette.PAPER_WARM, 8, Palette.BORDER, 2, 0.4))
	t.set_stylebox("hover", "Button", _sb(Palette.PAPER, 8, Palette.VERMILION, 2, 1.0))
	t.set_stylebox("pressed", "Button", _sb(Palette.VERMILION_DK, 8, Palette.VERMILION_DK, 2, 0.6))
	t.set_stylebox("disabled", "Button", _sb(Palette.PAPER_DARK, 8, Palette.BORDER_SOFT, 2))
	t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), 8, Palette.GOLD, 2))
	t.set_constant("outline_size", "Button", 0)

	# --- 面板 ---
	t.set_stylebox("panel", "PanelContainer", _sb(Palette.PAPER, 10, Palette.BORDER_SOFT, 2, 0.8))
	t.set_stylebox("panel", "Panel", _sb(Palette.PAPER, 10, Palette.BORDER_SOFT, 2, 0.8))

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
	t.set_stylebox("panel", "PanelCard", _sb(Palette.PAPER, 10, Palette.BORDER_SOFT, 2, 0.8))

	t.set_type_variation("PanelDark", "PanelContainer")
	t.set_stylebox("panel", "PanelDark", _sb(Palette.PANEL_DARK, 12, Palette.GOLD_DK, 2, 0.5))

	t.set_type_variation("PanelInset", "PanelContainer")
	t.set_stylebox("panel", "PanelInset", _sb(Palette.PAPER_WARM, 8, Palette.BORDER_SOFT, 1, 0.4))

	t.set_type_variation("StagePanel", "PanelContainer")
	t.set_stylebox("panel", "StagePanel", _sb(Palette.STAGE, 12, Palette.STAGE_EDGE, 2, 0.75))

	t.set_type_variation("PrimaryButton", "Button")
	t.set_color("font_color", "PrimaryButton", Palette.PAPER)
	t.set_color("font_hover_color", "PrimaryButton", Palette.PAPER)
	t.set_color("font_pressed_color", "PrimaryButton", Palette.PAPER)
	t.set_stylebox("normal", "PrimaryButton", _sb(Palette.VERMILION, 8, Palette.VERMILION_DK, 2, 1.0))
	t.set_stylebox("hover", "PrimaryButton", _sb(Palette.VERMILION_DK, 8, Palette.GOLD, 2, 1.2))
	t.set_stylebox("pressed", "PrimaryButton", _sb(Palette.VERMILION_DK, 8, Palette.VERMILION_DK, 2, 0.6))
	t.set_stylebox("focus", "PrimaryButton", _sb(Color(0, 0, 0, 0), 8, Palette.GOLD, 2))

	t.set_type_variation("GhostButton", "Button")
	t.set_color("font_color", "GhostButton", Palette.INK_SOFT)
	t.set_stylebox("normal", "GhostButton", _sb(Color(0, 0, 0, 0), 8, Palette.INK_FAINT, 1))
	t.set_stylebox("hover", "GhostButton", _sb(Palette.PAPER_WARM, 8, Palette.INK_SOFT, 1, 0.6))

	t.set_type_variation("DangerButton", "Button")
	t.set_color("font_color", "DangerButton", Palette.PAPER)
	t.set_stylebox("normal", "DangerButton", _sb(Palette.PLUM, 8, Palette.VERMILION_DK, 2, 0.8))
	t.set_stylebox("hover", "DangerButton", _sb(Palette.VERMILION_DK, 8, Palette.GOLD, 2, 1.0))

	return t


func _sb(bg: Color, radius: int, border: Color, border_w: int, glow := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg.r, bg.g, bg.b, bg.a * Palette.PANEL_ALPHA)
	sb.set_corner_radius_all(radius + Palette.CORNER_BONUS)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.set_content_margin_all(10)
	if Palette.GLOW and glow > 0.0:
		sb.shadow_color = Color(Palette.VERMILION.r, Palette.VERMILION.g, Palette.VERMILION.b, 0.22 * glow)
		sb.shadow_size = int(7.0 * glow)
		sb.shadow_offset = Vector2(0, 2)
	return sb


# ---------------------------------------------------------------- 背景 / 字块材质
func background(stain := 0.45) -> ColorRect:
	var cr := ColorRect.new()
	var mat := ShaderMaterial.new()
	if Palette.BG_KIND == "neon":
		mat.shader = _bg_neon_shader
		mat.set_shader_parameter("top_color", Palette.BG_TOP)
		mat.set_shader_parameter("bottom_color", Palette.BG_BOTTOM)
		mat.set_shader_parameter("glow_color", Palette.VERMILION)
		mat.set_shader_parameter("grid_color", Palette.VERMILION)
	else:
		mat.shader = _paper_shader
		mat.set_shader_parameter("stain_amount", stain)
	cr.material = mat
	cr.color = Color.WHITE
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.name = "Background"
	return cr


## 兼容旧名
func paper_layer(stain := 0.45) -> ColorRect:
	return background(stain)


func make_tile_material(tint := Color.WHITE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if Palette.TILE_KIND == "glass":
		mat.shader = _tile_neon_shader
		mat.set_shader_parameter("edge", Palette.VERMILION)
		mat.set_shader_parameter("edge_width", 2.2 + (1.6 if Palette.GLOW else 0.0))
		mat.set_shader_parameter("glow", 1.0 if Palette.GLOW else 0.6)
	else:
		mat.shader = _wood_shader
	tile_set_tint(mat, tint)
	return mat


## 兼容旧名
func make_wood_material(tint := Color.WHITE) -> ShaderMaterial:
	return make_tile_material(tint)


## 按当前风格设置字块基色（木纹 or 玻璃）
func tile_set_tint(mat: ShaderMaterial, tint: Color) -> void:
	if mat == null:
		return
	if Palette.TILE_KIND == "glass":
		mat.set_shader_parameter("face", Palette.WOOD_DARK * tint)
		mat.set_shader_parameter("face_light", Palette.WOOD_LIGHT * tint)
		mat.set_shader_parameter("edge", Palette.VERMILION)
	else:
		mat.set_shader_parameter("wood_dark", Palette.WOOD_DARK * tint)
		mat.set_shader_parameter("wood_light", Palette.WOOD_LIGHT * tint)


# ---------------------------------------------------------------- 工厂方法
func label(text: String, variation: String = "", override_color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if not variation.is_empty():
		l.theme_type_variation = variation
	if override_color.a > 0.0:
		l.add_theme_color_override("font_color", override_color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25 if Palette.GLOW else 0.08))
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


func stage_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "StagePanel"
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


func hline(color := Color(0, 0, 0, 0)) -> ColorRect:
	var c := ColorRect.new()
	c.color = color if color.a > 0.0 else Palette.BORDER_SOFT
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
