extends Resource
class_name EnemyAttackSheet
## 纹理与姿势索引共同导出，避免构建后遗漏非资源 JSON。
@export var texture: Texture2D
@export_multiline var index_json := ""
