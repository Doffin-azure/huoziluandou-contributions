extends RefCounted
class_name EnemyAttackProfiles
## 各敌人独立的攻击画稿与时序；已有墨灵蒙皮不变。
const DATA := {
	"bronze_seal": {"motion": "低伏印击", "effect": "seal", "release": 0.34, "length": 0.98},
	"iron_seal": {"motion": "收翼探颈", "effect": "blade", "release": 0.28, "length": 0.86},
	"paper_guard": {"motion": "转身挥扇", "effect": "paper", "release": 0.28, "length": 0.88},
	"rust_scribe": {"motion": "收笔突刺", "effect": "brush", "release": 0.28, "length": 0.86},
	"ember_imp": {"motion": "交替连扑", "effect": "ember", "release": 0.22, "length": 0.56},
	"boss_lead_plate": {"motion": "提模下砸", "effect": "press", "release": 0.38, "length": 1.04},
	"boss_word_demon": {"motion": "卷身撕咬", "effect": "serpent", "release": 0.32, "length": 0.94},
	"boss_chaos_press": {"motion": "张颚合噬", "effect": "maw", "release": 0.36, "length": 1.02},
}


static func get_profile(id: String) -> Dictionary:
	return DATA.get(id, {})
