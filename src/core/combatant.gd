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
var status_data: Dictionary = {}   ## 状态的目标独立数据（如灼烧伤害快照）
var is_player: bool = false
var enemy_data: EnemyData = null
var move_index: int = 0
## 本次主动出字中的最大单段真实生命损失；由BattleState在结算前清零。
var largest_hp_hit: int = 0

# --- 玩家本场比赛资源 ---
var energy: int = 0
var heat: int = 0
var heat_capacity: int = 10

# --- 跨战永久 ---
var permanent_damage_reduction: int = 0
## 御：本回合每次受伤减免（临时，回合结束清零）
var turn_damage_reduction: int = 0
var next_damage_reduction: int = 0 ## 御：下一次受击减伤，触发后清空
var turn_strength: int = 0         ## 强：仅当前回合的伤害加成
## 放心：本回合受到伤害减半（临时，回合结束清零）
var turn_damage_halve: bool = false
## 强心：本场累计「已触发的心力层数」
var heart_power_triggered: int = 0
## 冷心：本回合造成的伤害翻倍（临时）
var turn_damage_double: bool = false
## 冷心：剩余多少回合不能获得防御（格挡/持久盾无效）
var no_block_turns: int = 0
## 甲：本回合格挡是否被击穿（用于护甲碎裂判定）
var block_broken: bool = false
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
		feedback.emit({"kind": "damage", "hp": hp, "max_hp": max_hp,
			"hp_loss": 0, "blocked": 0, "block": block, "persistent_block": persistent_block})
		return 0
	var before_hp := hp
	var before_shield := block + persistent_block
	var dmg: int = amount
	if statuses.has("vulnerable"):
		dmg = int(ceil(dmg * BattleBalance.f("vulnerable_mult", 1.5)))
	if is_player:
		dmg = max(0, dmg - permanent_damage_reduction - turn_damage_reduction - next_damage_reduction)
		next_damage_reduction = 0
	var blocked: int = min(block, dmg)
	block -= blocked
	dmg -= blocked
	if is_player and blocked > 0 and dmg > 0:
		block_broken = true
	if dmg > 0:
		var persisted: int = min(persistent_block, dmg)
		persistent_block -= persisted
		dmg -= persisted
	# 放心：本回合受伤减半（向上取整，再减 1）
	if is_player and turn_damage_halve and dmg > 0:
		dmg = max(0, int(ceil(dmg / BattleBalance.f("guard_divisor", 2.0))) - BattleBalance.i("guard_flat", 1))
	# 心力：抵挡一次致命伤害（本次伤害不生效，保留当前生命）
	if is_player and dmg > 0 and hp - dmg <= 0 and heart_power > 0:
		heart_power -= 1
		heart_power_triggered += 1
		dmg = 0
	hp = max(0, hp - dmg)
	largest_hp_hit = maxi(largest_hp_hit, before_hp - hp)
	if dmg > 0:
		EventBus.damage_dealt.emit(is_player, dmg)
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
	if no_block_turns > 0:
		return   # 冷心：不能获得防御
	if amount > 0 and status_data.has("first_shield_discount"):
		amount = maxi(0, amount - int(status_data.first_shield_discount))
		status_data.erase("first_shield_discount")
	if amount > 0 and bool(status_data.get("first_shield_cancel", false)):
		amount = 0
		status_data.erase("first_shield_cancel")
	var before := block
	block = max(0, block + amount)
	if block != before:
		feedback.emit({"kind": "shield", "block": block, "persistent_block": persistent_block, "gain": block - before})


func add_persistent_block(amount: int) -> void:
	if no_block_turns > 0:
		return   # 冷心：不能获得防御
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
