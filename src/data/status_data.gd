@tool
extends Resource
class_name StatusData
## 状态（buff / debuff）。战斗中按 id 叠加层数。

enum Kind { BUFF, DEBUFF, NEUTRAL }

@export var id: String = ""
@export var name: String = ""
@export var glyph: String = "状"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.BUFF
@export var stackable: bool = true
@export var decay_per_turn: int = 0
@export var color: Color = Color("6f8f6a")
