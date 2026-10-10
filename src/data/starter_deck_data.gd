@tool
extends Resource
class_name StarterDeckData
## 初始字袋。GDD V0.3：12 枚实体字 / 9 种字，开局随机落 10，普通回合补 3。

@export var id: String = ""
@export var name: String = "初始字袋 V0.3"
@export var entries: Array[DeckEntryData] = []
@export var opening_draw: int = 10
@export var turn_draw: int = 3


func total_count() -> int:
	var n := 0
	for e in entries:
		n += e.count
	return n


func distinct_count() -> int:
	return entries.size()
