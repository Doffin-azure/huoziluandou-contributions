@tool
extends Resource
class_name EnemyMoveData
## 敌人的一个行动（意图）。按 EnemyData.moves 循环释放。

enum Kind { ATTACK, BLOCK, ATTACK_BLOCK, BUFF, DEBUFF, MULTI, INJECT, SPECIAL }

@export var kind: Kind = Kind.ATTACK
@export var title: String = "攻击"
@export_multiline var description: String = ""
@export var damage: int = 6
@export var hits: int = 1
@export var block: int = 0
@export var status_id: String = ""
@export var status_stacks: int = 0
## 往盘面空格注入的敌方实体字数量
@export var inject_count: int = 0
## 注入时附带的污染（PollutionData.id）：rush / block / scorch
@export var pollution_id: String = ""
@export var heal: int = 0
@export var mechanic_action: String = ""


func intent_text() -> String:
	if not description.is_empty():
		return description
	match kind:
		Kind.ATTACK:
			return "攻击 %d" % damage
		Kind.BLOCK:
			return "防御 %d" % block
		Kind.ATTACK_BLOCK:
			return "攻击 %d / 防御 %d" % [damage, block]
		Kind.MULTI:
			return "%d × %d" % [damage, hits]
		Kind.DEBUFF:
			return "施加 %s" % status_id
		Kind.INJECT:
			return "注入 %d 个污染字" % inject_count
		_:
			return title
