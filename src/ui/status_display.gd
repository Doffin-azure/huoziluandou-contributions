extends RefCounted
class_name StatusDisplay
## Read-only adapter: gameplay values never live in the HUD.

const ABILITY_NAMES := {
	"armor_plating": "甲", "guard_inject": "护", "prevent_interference": "防护",
	"convert_block": "护甲", "counter": "反击",
	"next_heat_to_block": "过冷", "longword_draw": "能力", "electric_material": "电能",
	"heat_to_energy": "蓄热", "overheat_shield": "蓄冷", "next_copy_layer": "超能",
	"double_next": "超能力", "gold_to_shield": "收息", "inject_bounty": "加收",
	"instant_power": "电力", "heat_pollution_damage": "火热", "heart_power": "心力",
	"next_diagonal": "流利", "flow": "流转", "next_compound": "复合", "energy_idle": "蓄能",
	"heat_overload_bonus_armed": "过热", "accel": "加速", "next_rapid": "急速",
	"heat_overload_bonus": "过热待触发",
	"next_double_draw": "超速", "next_overfire": "过火", "electric_overload": "电流过载",
	"fireproof": "防火", "blastproof": "防爆", "joint_funding": "合资", "profit_share": "分利",
	"next_energy_bonus": "蓄力", "gravity_always": "重力", "compound_equity": "复利",
	"ceasefire": "停火", "serial": "连载", "repeat_zero": "反复", "split_mind": "精分",
	"vigor": "精力", "vigor_next": "精力待补", "auto_refill": "充电过热", "repeat": "重复",
	"next_serial_bonus": "连载待发", "next_draw_bonus": "额外补字",
	"warm_heart": "热心", "strong_heart": "强心", "manual_draw": "精心", "shared_attack": "合击"
}

const LAYERED_ABILITIES := ["guard_inject", "counter", "next_energy_bonus", "next_serial_bonus", "vigor_next", "next_draw_bonus"]
## 这些是主能力的参数或伴随标记，由主能力的详情承接，不另占一个图标。
const ABILITY_PARAMETERS := ["next_rapid_heat", "next_overfire_per", "heat_overload_bonus_armed"]

static func entry(id: String, name: String, glyph: String, stacks: int, description: String, color: Color, kind := 0, unit_label := "层") -> Dictionary:
	return {"id": id, "name": name, "glyph": glyph, "stacks": stacks, "description": description, "color": color, "kind": kind, "unit": unit_label}

static func collect(unit: Combatant, battle: BattleState = null) -> Array:
	var result: Array = []
	if unit.is_player:
		if unit.heat > 0:
			var heat := entry("heat", "热度", "火", unit.heat, "当前热度 %d / 热容 %d。超过热容会产生灼热字。" % [unit.heat, unit.heat_capacity], Palette.VERMILION_DK, 0, "点")
			heat["capacity"] = unit.heat_capacity
			result.append(heat)
		if unit.energy > 0:
			result.append(entry("energy", "储能", "电", unit.energy, "当前储能 %d，用于消耗储能的字与词效。" % unit.energy, Palette.INK, 0, "点"))
	for id in unit.statuses:
		var stacks := int(unit.statuses[id])
		if stacks == 0:
			continue
		var data := Database.get_status(str(id))
		if data != null:
			var description := data.description
			if data.decay_per_turn > 0:
				description += "\n每回合衰减 %d 层。" % data.decay_per_turn
			result.append(entry(str(id), data.name, data.glyph, stacks, description, data.color, data.kind))
		else:
			result.append(entry(str(id), str(id), "状", stacks, "未配置状态说明。", Palette.GOLD))
	if unit.is_player:
		var permanent := maxi(unit.permanent_damage_reduction, GameState.permanent_damage_reduction)
		if permanent > 0:
			result.append(entry("permanent_guard", "永久减伤", "防", permanent, "每次受到伤害时减免 %d。" % permanent, Palette.JADE))
		if unit.turn_damage_reduction > 0:
			result.append(entry("turn_guard", "御", "御", unit.turn_damage_reduction, "本回合每次受到伤害时减免 %d。" % unit.turn_damage_reduction, Palette.BLOCK))
		if unit.turn_damage_halve:
			result.append(entry("guard_halve", "放心", "安", 1, "本回合受伤减半，向上取整后再减 1。", Palette.JADE))
		if unit.turn_damage_double:
			result.append(entry("damage_double", "冷心", "倍", 1, "本回合造成的伤害翻倍。", Palette.GOLD))
		if unit.no_block_turns > 0:
			result.append(entry("no_block", "禁防", "禁", unit.no_block_turns, "剩余 %d 回合不能获得格挡或持久盾。" % unit.no_block_turns, Palette.PLUM, StatusData.Kind.DEBUFF))
		var has_heart_ability := battle != null and battle.has_ability("heart_power")
		if unit.heart_power > 0 or has_heart_ability:
			var description := "每层可抵挡一次致命伤害。"
			if has_heart_ability:
				description += "\n本场每打出一颗【心】，获得一层。"
			result.append(entry("heart_layers", "心力", "心", unit.heart_power, description, Palette.VERMILION))
		if battle != null:
			for id in battle.abilities:
				if str(id).begins_with("_") or id in ABILITY_PARAMETERS or id == "heart_power" or not battle.has_ability(id):
					continue
				var name: String = ABILITY_NAMES.get(id, "其他能力")
				var value := battle.ability_value(id)
				var word := Database.get_word_by_glyphs_string(name)
				var description := word.effect_summary if word != null else "持续能力已生效。"
				if id == "armor_plating":
					description = "每回合获得 1 点格挡；格挡被击穿时碎裂。"
				elif id == "guard_inject":
					description = "下次敌方塞字减少 %d 个。" % value
				elif id == "counter":
					description = "敌人整次行动结束后，对首个存活敌人造成剩余临挡 + %d 伤害；发动后消耗全部 %d 层。" % [3 * value, value]
				elif id == "next_energy_bonus" or id == "next_serial_bonus":
					description = "下一次攻击额外造成 %d 伤害。" % value
				elif id == "next_draw_bonus":
					description = "本回合下一次多字词结算后，额外补 %d 字。" % value
				elif id == "vigor_next":
					description = "下回合基础补字额外增加 %d 字。" % value
				elif id == "next_double_draw":
					description = "本回合下一次补字最多额外补 %d 字；触发后消耗。" % value
				elif id == "next_rapid":
					description = "本回合下一次多字词后，补至多 %d 字，优先回填急速的原格；升温 %d。" % [value, battle.ability_value("next_rapid_heat")]
				elif id == "next_overfire":
					description = "下一次攻击序列，每段额外造成当前热度 × %d 伤害；触发后消耗。" % battle.ability_value("next_overfire_per", 3)
				elif id == "heat_overload_bonus":
					description = "本回合首次产生新增溢热污染后，下一次多字词额外补 2 字。"
				var layers := maxi(1, value) if id in LAYERED_ABILITIES else 1
				var label_unit := "层"
				if id in ["vigor_next", "next_draw_bonus", "next_double_draw", "next_rapid"]:
					layers = value
					label_unit = "字"
				result.append(entry("ability:" + id, name, name.substr(0, 1), layers, description, Palette.GOLD, 1 if id == "split_mind" else 0, label_unit))
			if battle.flow_row >= 0:
				result.append(entry("flow_row", "流速", "流", 1, "本回合第 %d 行腾出的空格立即补回。" % (battle.flow_row + 1), Palette.GOLD))
			if battle.base_draw_penalty > 0:
				result.append(entry("reload", "重载", "载", 1, "本场热容 %d；每回合基础补字减少 %d。" % [unit.heat_capacity, battle.base_draw_penalty], Palette.GOLD))
			if battle.next_draw_penalty > 0:
				result.append(entry("draw_penalty", "下回合少抽", "缓", battle.next_draw_penalty, "下回合基础补字减少 %d 字；结算后清除。" % battle.next_draw_penalty, Palette.PLUM, StatusData.Kind.DEBUFF, "字"))
			elif battle.next_draw_penalty < 0:
				result.append(entry("draw_bonus_next", "下回合多抽", "流", -battle.next_draw_penalty, "下回合基础补字增加 %d 字；结算后清除。" % -battle.next_draw_penalty, Palette.INK, StatusData.Kind.BUFF, "字"))
			if battle.manual_draw_pending > 0:
				result.append(entry("manual_draw_pending", "待选补字", "选", battle.manual_draw_pending, "本回合还有 %d 枚补字等待从字袋选择，随机落地。" % battle.manual_draw_pending, Palette.INK, StatusData.Kind.BUFF, "字"))
			if not battle.empowered_glyphs.is_empty():
				result.append(entry("empowered", "强化", "强", 1, "本场【%s】参与成词时额外触发单字效果。" % "、".join(battle.empowered_glyphs.keys()), Palette.GOLD))
			if battle.bounty_paid:
				result.append(entry("bounty", "重金", "赏", 1, "本回合击杀后返还 %d 金币。" % battle.bounty_reward, Palette.GOLD))
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var priority_a := _priority(a)
		var priority_b := _priority(b)
		return str(a.id) < str(b.id) if priority_a == priority_b else priority_a < priority_b)
	return result


static func _priority(item: Dictionary) -> int:
	var resources := ["heat", "energy"]
	if item.id in resources: return resources.find(item.id) - 4
	if int(item.kind) == StatusData.Kind.DEBUFF: return 0
	if item.id in ["draw_bonus_next", "manual_draw_pending", "ability:vigor_next"]: return 1
	if str(item.id).begins_with("ability:next_") or item.id == "ability:double_next": return 2
	return 3
