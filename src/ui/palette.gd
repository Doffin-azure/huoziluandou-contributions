class_name Palette
## 《活字战斗》配色：宣纸、墨、朱印、老木、铜。
## 改这里就能整体换皮。

const PAPER        := Color("efe6d2")   # 宣纸底
const PAPER_WARM   := Color("e7d9b8")   # 暖纸
const PAPER_DARK   := Color("d8c8a2")   # 纸的暗部
const PAPER_SHADE  := Color("c8b68d")
const INK          := Color("221f1a")   # 浓墨
const INK_SOFT     := Color("4a4438")
const INK_FAINT    := Color("7c7360")
const VERMILION    := Color("b83a2e")   # 朱印
const VERMILION_DK := Color("8c2a20")
const GOLD         := Color("c9a35a")   # 铜/金
const GOLD_DK      := Color("9a7838")
const WOOD         := Color("a9773f")   # 木活字
const WOOD_LIGHT   := Color("c99c60")
const WOOD_DARK    := Color("6f4a24")
const JADE         := Color("5f7d6a")
const INDIGO       := Color("3c4a6b")
const PLUM         := Color("7a4a63")
const HP           := Color("a63c34")
const BLOCK        := Color("5f7f9a")

const SHADOW := Color(0.08, 0.06, 0.04, 0.45)


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
