extends RefCounted
class_name BoardTypography
## 仅解析字体数据，不改变战斗与用户配置。缺字交给内置字体回退。

static func load_font(path: String, fallback: Font) -> Font:
	if path.is_empty(): return fallback
	if not path.get_extension().to_lower() in ["ttf", "otf", "ttc", "woff", "woff2"]:
		return null
	if not FileAccess.file_exists(path): return null
	var font := FontFile.new()
	if font.load_dynamic_font(path) != OK: return null
	font.fallbacks = [fallback]
	return font
