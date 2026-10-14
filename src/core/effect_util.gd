extends RefCounted
class_name EffectUtil
## 效果结算的共享小工具（伤害 / 支付 / 目标解析等）。供 EffectHandlers 与其子模块调用。

static func enemy(b: BattleState, ctx: Dictionary) -> Combatant:
	var idx: int = int(ctx.get("target_index", 0))
	var alive := b.alive_enemies()
	if alive.is_empty():
		return null
	return alive[clampi(idx, 0, alive.size() - 1)]

static func damage(b: BattleState, target: Combatant, amount: int) -> Array:
	if target == null:
		return ["（无目标）"]
	var real := b.deal_damage(target, amount, true)
	return ["造成 %d 点伤害" % real]

static func tile(ctx: Dictionary) -> Vector2i:
	var t: Dictionary = ctx.get("target", {})
	return t.get("tile", Vector2i.ZERO)

static func add_gold(b: BattleState, amount: int) -> void:
	b.earn_gold(amount)


## 可用支付额 = 临时资金 + 金币（“资金”可直接用于经济效果）

static func available(b: BattleState) -> int:
	var avail: int = b.player.temp_funds + GameState.gold
	if b.has_ability("joint_funding"):
		avail += int(b.player.energy / 2)
	return avail


static func discounted_cost(b: BattleState, cost: int) -> int:
	return maxi(0, cost - b.ability_value("payment_discount_once")) if cost >= 0 else cost

## 先兑现币的费用优惠，再花临时资金、合资储能和金币。失败时保留优惠。

static func pay(b: BattleState, cost: int) -> bool:
	var due := discounted_cost(b, cost)
	if cost < 0 or available(b) < due:
		return false
	if cost > 0 and b.has_ability("payment_discount_once"):
		b.abilities.erase("payment_discount_once")
	var from_temp: int = mini(b.player.temp_funds, due)
	b.player.temp_funds -= from_temp
	var remain: int = due - from_temp
	var gold_spent := 0
	if remain > 0 and b.has_ability("joint_funding"):
		var sub: int = mini(int(b.player.energy / 2), remain)
		b.spend_energy(sub * 2)
		remain -= sub
	if remain > 0:
		gold_spent = remain
		GameState.add_gold(-remain)
	if gold_spent > 0 and b.has_ability("gold_to_shield"):
		b.player.add_persistent_block(gold_spent)
	return true

static func simple_ability(b: BattleState, id: String, msg: String) -> Array:
	b.enable_ability(id, 1)
	return [msg]
