extends SceneTree
## 只更新怪物与关卡，不重建字、词和玩家数值。
func _initialize() -> void:
	EnemyRoster.save_enemies()
	EnemyRoster.save_acts()
	print("[build_monsters] 20 monsters / 3 acts")
	quit()
