extends RefCounted
class_name EffectResolver
## 把 EffectData 列表结算成实际效果。
## handler 非空 -> 交给 EffectHandlers；否则按 kind 走通用分支。

static func resolve_all(effects: Array, ctx: Dictionary) -> Array:
	var messages: Array = []
	for eff in effects:
		if eff == null:
			continue
		if not eff.handler.is_empty():
			messages.append_array(EffectHandlers.run(eff.handler, eff, ctx))
		else:
			messages.append_array(_resolve_kind(eff, ctx))
	return messages


static func instant_effects(effects: Array, repeat_self: bool = false) -> Array:
	return effects.filter(func(e): return e.timing != "persistent" or (repeat_self and e.handler == "repeat_word"))


static func _resolve_kind(eff: EffectData, ctx: Dictionary) -> Array:
	var b: BattleState = ctx.get("battle")
	var src: Combatant = ctx.get("source")
	var g: int = (ctx.get("glyphs", []) as Array).size()
	var extra: int = max(0, g - 2)
	var amount: int = eff.amount + eff.amount_per_extra_glyph * extra
	var K := EffectData.Kind

	match eff.kind:
		K.DAMAGE: return EffectHandlers.run("damage", eff, ctx)
		K.DAMAGE_ALL: return EffectHandlers.run("damage_all", eff, ctx)
		K.BLOCK: return EffectHandlers.run("block_temp", eff, ctx)
		K.PERSISTENT_BLOCK: return EffectHandlers.run("block_persist", eff, ctx)
		K.HEAL: return EffectHandlers.run("heal", eff, ctx)
		K.DRAW_CHARS: return EffectHandlers.run("draw_random", eff, ctx)
		K.SCRY: return EffectHandlers.run("draw_random", eff, ctx)
		K.GAIN_GOLD: return EffectHandlers.run("gold", eff, ctx)
		K.ENERGY: return EffectHandlers.run("energy", eff, ctx)
		K.HEAT: return EffectHandlers.run("heat", eff, ctx)
		K.TEMP_FUNDS: return EffectHandlers.run("temp_funds", eff, ctx)
		K.REMOVE_BLOCK: return EffectHandlers.run("remove_enemy_block", eff, ctx)
		K.CLEANSE: return EffectHandlers.run("cleanse_all", eff, ctx)
		K.GRAVITY: return EffectHandlers.run("gravity", eff, ctx)
		K.ROTATE_2X2: return EffectHandlers.run("rotate_2x2", eff, ctx)
		K.DESTROY_2X2: return EffectHandlers.run("destroy_2x2", eff, ctx)
		K.REPLAY_ATTACK: return EffectHandlers.run("replay_last_attack", eff, ctx)
		K.SHIELD_SMASH: return EffectHandlers.run("shield_smash", eff, ctx)
		K.COUNTER: return EffectHandlers.run("counter", eff, ctx)
		K.CAPTURE_GLYPH: return EffectHandlers.run("capture_glyph", eff, ctx)
		K.RECOVER_CONSUMED: return EffectHandlers.run("recover_consumed", eff, ctx)
		K.REVEAL_PLACE: return EffectHandlers.run("reveal_place", eff, ctx)

		K.APPLY_STATUS:
			if eff.target == EffectData.Target.SELF:
				src.add_status(eff.status_id, amount if amount != 0 else 1)
				return ["获得状态 %s" % eff.status_id]
			var e := _enemy(b, ctx)
			if e != null:
				e.add_status(eff.status_id, amount if amount != 0 else 1)
				return ["使敌人获得 %s" % eff.status_id]
			return []

		K.ADD_CHAR_TO_BAG:
			var cd: CharacterData = Database.get_character(eff.character_id)
			if cd != null:
				GameState.add_character(cd, 1)
				return ["【%s】加入字袋" % cd.glyph]
			return []

		K.SWAP_TILES:
			_swap_random(b)
			return ["交换盘面字块"]
		K.DISCARD_TILE:
			_discard_random(b)
			return ["弃掉一个字"]

		K.EQUITY:
			src.equity = max(0, src.equity + amount)
			return ["股权 %+d" % amount]

		_:
			return ["（未实现的效果）"]


static func _enemy(b: BattleState, ctx: Dictionary) -> Combatant:
	var idx: int = int(ctx.get("target_index", 0))
	var alive := b.alive_enemies()
	if alive.is_empty():
		return null
	return alive[clampi(idx, 0, alive.size() - 1)]


static func _swap_random(b: BattleState) -> void:
	var filled: Array = []
	for i in b.board.cells.size():
		if b.board.cells[i] != null:
			filled.append(i)
	if filled.size() < 2:
		return
	var a: int = filled[b.rng.randi_range(0, filled.size() - 1)]
	var c: int = filled[b.rng.randi_range(0, filled.size() - 1)]
	while c == a:
		c = filled[b.rng.randi_range(0, filled.size() - 1)]
	var tmp = b.board.cells[a]
	b.board.cells[a] = b.board.cells[c]
	b.board.cells[c] = tmp


static func _discard_random(b: BattleState) -> void:
	var filled: Array = []
	for i in b.board.cells.size():
		if b.board.cells[i] != null:
			filled.append(i)
	if filled.is_empty():
		return
	var i2: int = filled[b.rng.randi_range(0, filled.size() - 1)]
	var inst: CharInstance = b.board.cells[i2]
	if inst != null and not inst.is_enemy_owned():
		b.discard.append(inst)
	b.board.cells[i2] = null
