extends RefCounted
class_name GameStyle
## 青铜绘卷配色令牌。旧配置 ID 仅用于迁移，不再保留旧主题实现。

var id := "taopunk"
var name := "青铜绘卷"
var corner_bonus := -4

# 基础色（名字沿用原 Palette，避免大改调用点）
var PAPER := Color("e8d9b7")
var PAPER_WARM := Color("dfcd9f")
var PAPER_DARK := Color("cbb98f")
var PAPER_SHADE := Color("af9a70")
var INK := Color("171f1d")
var INK_SOFT := Color("343d33")
var INK_FAINT := Color("73654b")
var VERMILION := Color("a93630")      ## 朱砂强调色
var VERMILION_DK := Color("802822")
var GOLD := Color("b98c3e")
var GOLD_DK := Color("785925")
var WOOD := Color("1f4946")
var WOOD_LIGHT := Color("49716a")
var WOOD_DARK := Color("102e30")
var JADE := Color("5f7d6a")
var INDIGO := Color("3c4a6b")
var PLUM := Color("7a4a63")
var HP := Color("a93630")
var BLOCK := Color("5f7f9a")
var BORDER := Color("171f1d")
var BORDER_SOFT := Color("785925")
var PANEL_DARK := Color("132527")   ## 深色托盘（字盘底）
var STAGE := Color("10353b")
var STAGE_EDGE := Color("785925")
var SURFACE_RAISED := Color("f7eedc")
var SHADOW := Color(0.08, 0.06, 0.04, 0.45)


static func get_style(_style_id: String) -> GameStyle:
	return taopunk()


static func normalize_id(_style_id: String) -> String:
	return "taopunk"


static func taopunk() -> GameStyle:
	return GameStyle.new()
