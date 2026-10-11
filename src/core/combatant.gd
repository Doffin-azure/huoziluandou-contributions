extends RefCounted
class_name Combatant
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
## 心力层数（玩家专属）：抵挡致命伤害，每层可挡一次
var heart_power: int = 0
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
		return 0
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
	# 心力：抵挡一次致命伤害（本次伤害不生效，保留当前生命）
	if is_player and dmg > 0 and hp - dmg <= 0 and heart_power > 0:
		heart_power -= 1
		dmg = 0
	hp = max(0, hp - dmg)
	if dmg > 0:
		EventBus.damage_dealt.emit(is_player, dmg)
	return dmg


func heal(amount: int) -> void:
	hp = min(max_hp, hp + amount)


func add_block(amount: int) -> void:
	block = max(0, block + amount)


func add_persistent_block(amount: int) -> void:
	persistent_block = max(0, persistent_block + amount)


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
