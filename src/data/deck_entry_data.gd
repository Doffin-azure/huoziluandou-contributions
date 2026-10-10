@tool
extends Resource
class_name DeckEntryData
## 初始字袋里的一项：一枚字 + 份数。

@export var character: CharacterData
@export_range(1, 8) var count: int = 1
