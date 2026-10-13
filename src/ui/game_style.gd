extends RefCounted
class_name GameStyle
## 视觉风格令牌。切换风格 = 换一套令牌 + 背景/字块材质 + 主题。
## 目前两套：
##   paper —— 宣纸 / 木活字 / 朱印（默认）
##   neon  —— 墨芯：深蓝科技 / 玻璃面板 / 发光字块（大模型概念）
## 新增风格：照抄一个 static func，再在 Palette.apply 与 Ink 里接线即可。

var id := "paper"
var name := "宣纸活字"
var bg_kind := "paper"      ## paper | neon
var tile_kind := "wood"     ## wood | glass
var panel_alpha := 1.0
var glow := false
var corner_bonus := 0

# 背景渐变（neon 用）
var BG_TOP := Color("efe6d2")
var BG_BOTTOM := Color("d8c8a2")

# 基础色（名字沿用原 Palette，避免大改调用点）
var PAPER := Color("efe6d2")
var PAPER_WARM := Color("e7d9b8")
var PAPER_DARK := Color("d8c8a2")
var PAPER_SHADE := Color("c8b68d")
var INK := Color("221f1a")
var INK_SOFT := Color("4a4438")
var INK_FAINT := Color("7c7360")
var VERMILION := Color("b83a2e")      ## 主强调色（宣纸=朱印；墨芯=青）
var VERMILION_DK := Color("8c2a20")
var GOLD := Color("c9a35a")
var GOLD_DK := Color("9a7838")
var WOOD := Color("a9773f")
var WOOD_LIGHT := Color("c99c60")
var WOOD_DARK := Color("6f4a24")
var JADE := Color("5f7d6a")
var INDIGO := Color("3c4a6b")
var PLUM := Color("7a4a63")
var HP := Color("a63c34")
var BLOCK := Color("5f7f9a")
var BORDER := Color("4a4438")
var BORDER_SOFT := Color("c8b68d")
var PANEL_DARK := Color("2b2620")   ## 深色托盘（字盘底）
var SHADOW := Color(0.08, 0.06, 0.04, 0.45)


static func get_style(style_id: String) -> GameStyle:
	match style_id:
		"neon": return neon()
		_: return paper()


static func paper() -> GameStyle:
	var s := GameStyle.new()
	s.id = "paper"
	s.name = "宣纸活字"
	s.bg_kind = "paper"
	s.tile_kind = "wood"
	s.panel_alpha = 1.0
	s.glow = false
	s.corner_bonus = 0
	s.BG_TOP = Color("efe6d2")
	s.BG_BOTTOM = Color("d8c8a2")
	s.BORDER = s.INK_SOFT
	s.BORDER_SOFT = s.PAPER_SHADE
	s.PAPER = Color("efe8d8")
	s.PAPER_WARM = Color("e8deca")
	s.INK = Color("28241f")
	s.VERMILION = Color("aa392d")
	s.WOOD_DARK = Color("b39368")
	s.WOOD_LIGHT = Color("dcc8a3")
	s.PANEL_DARK = Color("30251d")
	return s


static func neon() -> GameStyle:
	var s := GameStyle.new()
	s.id = "neon"
	s.name = "墨芯（大模型）"
	s.bg_kind = "neon"
	s.tile_kind = "glass"
	s.panel_alpha = 0.82
	s.glow = true
	s.corner_bonus = 6
	# 背景
	s.BG_TOP = Color("070d1c")
	s.BG_BOTTOM = Color("12203c")
	# 表面 / 文字
	s.PAPER = Color("16233c")
	s.PAPER_WARM = Color("1b2c4b")
	s.PAPER_DARK = Color("0d1729")
	s.PAPER_SHADE = Color("2a4a70")
	s.INK = Color("e9f3ff")
	s.INK_SOFT = Color("b6cbe6")
	s.INK_FAINT = Color("7d95b6")
	# 强调（青）/ 金 / 字块玻璃
	s.VERMILION = Color("3ee0ff")
	s.VERMILION_DK = Color("14a6d6")
	s.GOLD = Color("ffd166")
	s.GOLD_DK = Color("d9a521")
	s.WOOD = Color("1d2e4c")
	s.WOOD_LIGHT = Color("3f7fb8")
	s.WOOD_DARK = Color("0c1526")
	s.JADE = Color("45d99b")
	s.INDIGO = Color("6aa8ff")
	s.PLUM = Color("c07bff")
	s.HP = Color("ff5c7a")
	s.BLOCK = Color("5aa9ff")
	s.BORDER = Color("2f5f8f")
	s.BORDER_SOFT = Color("1f3c5e")
	s.PANEL_DARK = Color("0a1222")
	s.SHADOW = Color(0, 0, 0, 0.55)
	return s
