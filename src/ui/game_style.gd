extends RefCounted
class_name GameStyle
## 视觉风格令牌。青铜绘卷基于宣纸基础令牌构建。
## 风格：
##   taopunk —— 青铜绘卷：手绘青绿 / 青铜机关 / 朱红（当前定稿）
##   paper —— 内部基础令牌与旧版渲染验证，不再提供切换入口。

var id := "paper"
var name := "宣纸活字"
var corner_bonus := 0

# 基础色（名字沿用原 Palette，避免大改调用点）
var PAPER := Color("efe6d2")
var PAPER_WARM := Color("e7d9b8")
var PAPER_DARK := Color("d8c8a2")
var PAPER_SHADE := Color("c8b68d")
var INK := Color("221f1a")
var INK_SOFT := Color("4a4438")
var INK_FAINT := Color("7c7360")
var VERMILION := Color("b83a2e")      ## 朱砂强调色
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
var STAGE := Color("251f1a")
var STAGE_EDGE := Color("5d4430")
var SURFACE_RAISED := Color("f7eedc")
var SHADOW := Color(0.08, 0.06, 0.04, 0.45)


static func get_style(_style_id: String) -> GameStyle:
	return taopunk()


static func normalize_id(_style_id: String) -> String:
	return "taopunk"


static func taopunk() -> GameStyle:
	var s := paper()
	s.id = "taopunk"
	s.name = "青铜绘卷"
	s.PAPER = Color("e8d9b7")
	s.PAPER_WARM = Color("dfcd9f")
	s.PAPER_DARK = Color("cbb98f")
	s.PAPER_SHADE = Color("af9a70")
	s.INK = Color("171f1d")
	s.INK_SOFT = Color("343d33")
	s.INK_FAINT = Color("73654b")
	s.VERMILION = Color("a93630")
	s.VERMILION_DK = Color("802822")
	s.GOLD = Color("b98c3e")
	s.GOLD_DK = Color("785925")
	s.WOOD = Color("1f4946")
	s.WOOD_LIGHT = Color("49716a")
	s.WOOD_DARK = Color("102e30")
	s.PANEL_DARK = Color("132527")
	s.STAGE = Color("10353b")
	s.STAGE_EDGE = s.GOLD_DK
	s.HP = s.VERMILION
	s.BORDER = s.INK
	s.BORDER_SOFT = s.GOLD_DK
	s.corner_bonus = -4
	return s


static func paper() -> GameStyle:
	var s := GameStyle.new()
	s.id = "paper"
	s.name = "宣纸活字"
	s.corner_bonus = 0
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
