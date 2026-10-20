extends RefCounted
class_name BoardTypography
## 字盘只使用随包发布的字体；配置只保存样式 ID，不接受文件路径。

const BUNDLED_FONT: Font = preload("res://assets/fonts/NotoSerifSC-VF.ttf")
const DEFAULT_ID := "serif_standard"
const STYLES := [
	{"id": DEFAULT_ID, "name": "宋体标准", "family": "思源宋体 · 标准", "weight": 650.0},
	{"id": "serif_light", "name": "宋体细体", "family": "思源宋体 · 细体", "weight": 450.0},
	{"id": "serif_bold", "name": "宋体粗体", "family": "思源宋体 · 粗体", "weight": 850.0},
	{"id": "wenkai", "name": "霞鹜文楷", "family": "霞鹜文楷 · 楷体", "path": "res://assets/fonts/LXGWWenKai-Regular.ttf"},
	{"id": "longcang", "name": "龙藏草书", "family": "龙藏体 · 草书", "path": "res://assets/fonts/LongCang-Regular.ttf"},
]
static var _fonts: Dictionary = {}


static func is_builtin(font_id: String) -> bool:
	return STYLES.any(func(entry): return entry.id == font_id)


static func normalize_id(font_id: String) -> String:
	return font_id if is_builtin(font_id) else DEFAULT_ID


static func display_name(font_id: String) -> String:
	for entry in STYLES:
		if entry.id == normalize_id(font_id):
			return entry.family
	return ""


static func font_for_id(font_id: String) -> Font:
	font_id = normalize_id(font_id)
	if not _fonts.has(font_id):
		for entry in STYLES:
			if entry.id == font_id:
				var font := FontVariation.new()
				# 路径来自固定目录表，绝不拼接用户配置或运行时输入。
				font.base_font = load(entry.path) if entry.has("path") else BUNDLED_FONT
				if entry.has("weight"):
					var weight_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
					font.variation_opentype = {weight_tag: entry.weight}
				else:
					# 书法字体缺少生僻字时仍回退到包内宋体。
					font.fallbacks = [BUNDLED_FONT]
				_fonts[font_id] = font
	return _fonts[font_id]
