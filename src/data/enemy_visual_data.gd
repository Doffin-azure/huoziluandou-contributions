@tool
extends Resource
class_name EnemyVisualData
## Optional presentation at assets/enemies/<enemy_id>/visual.tres.
## Content rebuilding never touches this directory. Scene roots are Node2D.

@export var texture: Texture2D
@export var scene: PackedScene
@export var visual_scale := Vector2.ONE
@export var offset := Vector2.ZERO

static func for_enemy(enemy_id: String) -> EnemyVisualData:
	var path := "res://assets/enemies/%s/visual.tres" % enemy_id
	if enemy_id.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource := load(path) as EnemyVisualData
	if resource == null:
		push_warning("Enemy visual must be EnemyVisualData: " + path)
	return resource
