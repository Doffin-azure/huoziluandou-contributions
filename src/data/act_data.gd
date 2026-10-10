@tool
extends Resource
class_name ActData
## 一幕。对应 三幕节点计划_V03.csv：每幕 8 个节点。

@export var index: int = 1
@export var title: String = "第一幕"
@export_multiline var theme: String = ""
@export var nodes: Array[MapNodeData] = []
