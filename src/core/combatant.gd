extends RefCounted
class_name Combatant
## 只报告已结算的结果，监听者不参与规则或随机数。
signal feedback(event: Dictionary)
## 战斗单位（玩家或敌人）。V0.2：临挡(block) 与持久盾(persistent_block) 分开计算。

var display_name: String = ""
var max_hp: int = 10
var hp: int = 10
var block: int = 0                 ## 临时格挡，敌方行动后清除
var persistent_block: int = 0      ## 持久盾，跨回合保留
var statuses: Dictionary = {}      ## status_id -> stacks
var is_player: bool = false
var enemy_data: EnemyData = null
var move_index: int = 0

# --- 玩家本场比赛资源 ---
var energy: int = 0
var heat: int = 0
var heat_capacity: int = 10
var equity: int = 0
var temp_funds: int = 0            ## 本回合临时支付额度

# --- 跨战永久 ---
var permanent_damage_reduction: int = 0
## 调试用：无敌（玩家免伤）
var god_mode: bool = false


func _init(p_name: String = "", p_max_hp: int = 10, p_is_player: bool = false) -> void:
	display_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	is_player = p_is_player


## 返回实际损失生命。格挡优先，持久盾其次。
func take_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	if is_player and god_mode:
		feedback.emit({"kind": "damage", "hp": hp, "max_hp": max_hp,
			"hp_loss": 0, "blocked": 0, "block": block, "persistent_block": persistent_block})
		return 0
	var before_hp := hp
	var before_shield := block + persistent_block
	var dmg: int = amount
	if statuses.has("vulnerable"):
		dmg = int(ceil(dmg * 1.5))
	if is_player:
		dmg = max(0, dmg - permanent_damage_reduction)
	var blocked: int = min(block, dmg)
	block -= blocked
	dmg -= blocked
	if dmg > 0:
		var persisted: int = min(persistent_block, dmg)
		persistent_block -= persisted
		dmg -= persisted
	hp = max(0, hp - dmg)
	feedback.emit({"kind": "damage", "hp": hp, "max_hp": max_hp,
		"hp_loss": before_hp - hp, "blocked": before_shield - block - persistent_block,
		"block": block, "persistent_block": persistent_block})
	return dmg


func heal(amount: int) -> void:
	var before := hp
	hp = min(max_hp, hp + amount)
	if hp != before:
		feedback.emit({"kind": "heal", "hp": hp, "max_hp": max_hp, "gain": hp - before})


func add_block(amount: int) -> void:
	var before := block
	block = max(0, block + amount)
	if block != before:
		feedback.emit({"kind": "shield", "block": block, "persistent_block": persistent_block, "gain": block - before})


func add_persistent_block(amount: int) -> void:
	var before := persistent_block
	persistent_block = max(0, persistent_block + amount)
	if persistent_block != before:
		feedback.emit({"kind": "shield", "block": block, "persistent_block": persistent_block, "gain": persistent_block - before})


func remove_block(amount: int) -> int:
	var removed := mini(block, maxi(0, amount))
	block -= removed
	if removed > 0:
		feedback.emit({"kind": "shield", "block": block, "persistent_block": persistent_block, "gain": -removed})
	return removed


func add_status(status_id: String, stacks: int) -> void:
	if status_id.is_empty() or stacks == 0:
		return
	statuses[status_id] = int(statuses.get(status_id, 0)) + stacks
	if int(statuses[status_id]) == 0:
		statuses.erase(status_id)


func status_stacks(status_id: String) -> int:
	return int(statuses.get(status_id, 0))


func is_alive() -> bool:
	return hp > 0


func clear_block() -> void:
	block = 0


func add_heat(amount: int) -> int:
	heat = max(0, heat + amount)
	return heat


func add_energy(amount: int) -> void:
	energy = max(0, energy + amount)
