@tool
extends Resource
class_name CharacterData
## 一枚“实体字”（卡牌本身）。这是整个游戏的构筑单位。
## 修改字的能力 = 修改这里的 solo_effects / solo_handler；改美术色 = accent。

@export var id: String = ""
@export var glyph: String = "字"
@export var pinyin: String = ""
@export_multiline var description: String = ""
@export var tags: Array[String] = []
@export var solo_effects: Array[EffectData] = []
## 需要特殊规则的单字效果（如 回=原位换字、重=全盘重力、清=净化相邻污染）
@export var solo_handler: String = ""
@export_range(0, 4) var rarity: int = 0
@export var removable: bool = true
@export var accent: Color = Color("b8523a")
## 是否为污染源字（污/热等），由系统生成
@export var is_pollution: bool = false
## 是否仍在待定/未复审状态（来自开发看板）
@export var pending_design: bool = false


func display_name() -> String:
	return glyph
