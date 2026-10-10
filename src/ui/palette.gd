class_name Palette
## 全局配色令牌（由当前 GameStyle 填充）。
## 切换风格时调用 Palette.apply(style)，其余代码继续读 Palette.XXX 即可。

static var PAPER := Color("efe6d2")
static var PAPER_WARM := Color("e7d9b8")
static var PAPER_DARK := Color("d8c8a2")
static var PAPER_SHADE := Color("c8b68d")
static var INK := Color("221f1a")
static var INK_SOFT := Color("4a4438")
static var INK_FAINT := Color("7c7360")
static var VERMILION := Color("b83a2e")
static var VERMILION_DK := Color("8c2a20")
static var GOLD := Color("c9a35a")
static var GOLD_DK := Color("9a7838")
static var WOOD := Color("a9773f")
static var WOOD_LIGHT := Color("c99c60")
static var WOOD_DARK := Color("6f4a24")
static var JADE := Color("5f7d6a")
static var INDIGO := Color("3c4a6b")
static var PLUM := Color("7a4a63")
static var HP := Color("a63c34")
static var BLOCK := Color("5f7f9a")
static var BORDER := Color("4a4438")
static var BORDER_SOFT := Color("c8b68d")
static var PANEL_DARK := Color("2b2620")
static var SHADOW := Color(0.08, 0.06, 0.04, 0.45)
static var BG_TOP := Color("efe6d2")
static var BG_BOTTOM := Color("d8c8a2")

# 风格开关（供 Ink / TileView 判断用）
static var STYLE_ID := "paper"
static var STYLE_NAME := "宣纸活字"
static var BG_KIND := "paper"
static var TILE_KIND := "wood"
static var PANEL_ALPHA := 1.0
static var GLOW := false
static var CORNER_BONUS := 0


static func apply(style: GameStyle) -> void:
	PAPER = style.PAPER
	PAPER_WARM = style.PAPER_WARM
	PAPER_DARK = style.PAPER_DARK
	PAPER_SHADE = style.PAPER_SHADE
	INK = style.INK
	INK_SOFT = style.INK_SOFT
	INK_FAINT = style.INK_FAINT
	VERMILION = style.VERMILION
	VERMILION_DK = style.VERMILION_DK
	GOLD = style.GOLD
	GOLD_DK = style.GOLD_DK
	WOOD = style.WOOD
	WOOD_LIGHT = style.WOOD_LIGHT
	WOOD_DARK = style.WOOD_DARK
	JADE = style.JADE
	INDIGO = style.INDIGO
	PLUM = style.PLUM
	HP = style.HP
	BLOCK = style.BLOCK
	BORDER = style.BORDER
	BORDER_SOFT = style.BORDER_SOFT
	PANEL_DARK = style.PANEL_DARK
	SHADOW = style.SHADOW
	BG_TOP = style.BG_TOP
	BG_BOTTOM = style.BG_BOTTOM
	STYLE_ID = style.id
	STYLE_NAME = style.name
	BG_KIND = style.bg_kind
	TILE_KIND = style.tile_kind
	PANEL_ALPHA = style.panel_alpha
	GLOW = style.glow
	CORNER_BONUS = style.corner_bonus


static func rarity_color(rarity: int) -> Color:
	match rarity:
		0: return INK_FAINT
		1: return JADE
		2: return INDIGO
		3: return VERMILION
		_: return GOLD


static func tag_label(tag: String) -> String:
	match tag:
		"attack": return "攻"
		"defense": return "防"
		"space": return "位"
		"utility": return "辅"
		"economy": return "金"
		"heat": return "热"
		_: return tag
