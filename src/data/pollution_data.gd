@tool
extends Resource
class_name PollutionData
## 污染类型。污染是附着在实体字上的状态，不改变汉字本身。
## 刺痛：打出时损失生命；堵塞：打出后下次补字 -1；灼热：打出时损失极少生命。

@export var id: String = ""
@export var name: String = ""
@export var glyph: String = "污"
@export_multiline var description: String = ""
@export var hp_loss_on_play: int = 0
@export var draw_penalty_on_play: int = 0
@export var color: Color = Color("7a4a63")
@export var self_generated: bool = false
