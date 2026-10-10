@tool
extends Resource
class_name MapNodeData
## 一幕里的一个节点（对应 三幕节点计划_V03.csv 的一行）。

enum Type { BATTLE, EVENT, SHOP, ELITE, REST, BOSS, FORK }

@export var order: int = 1
@export var type: Type = Type.BATTLE
@export var title: String = ""
@export_multiline var description: String = ""
@export var enemies: Array[EnemyData] = []      ## 战斗节点用
@export var is_optional_branch: bool = false     ## 岔路（精英/事件）


func type_label() -> String:
	match type:
		Type.BATTLE: return "普通战"
		Type.EVENT: return "事件"
		Type.SHOP: return "商店"
		Type.ELITE: return "精英"
		Type.REST: return "休整"
		Type.BOSS: return "首领"
		Type.FORK: return "岔路"
		_: return "?"


func is_combat() -> bool:
	return type == Type.BATTLE or type == Type.ELITE or type == Type.BOSS
