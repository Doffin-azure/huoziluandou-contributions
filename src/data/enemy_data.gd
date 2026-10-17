@tool
extends Resource
class_name EnemyData
## 敌人定义。战斗界面上的“印章”就是这个字。

@export var id: String = ""
@export var name: String = "无名"
@export var glyph: String = "敌"        ## 头像大字
@export var description: String = ""
@export var max_hp: int = 24
@export var initial_block: int = 0
## 精选怪物机制标识；空值使用旧版行动。
@export var mechanic: String = ""
@export var act: int = 1
@export var accent: Color = Color("7a3b3b")
## 行动循环。会按顺序循环释放，长度可不等。
@export var moves: Array[EnemyMoveData] = []
@export var is_boss: bool = false
@export var is_elite: bool = false
