extends RefCounted
class_name EffectRegistry
## 效果协议：分类、目标、校验、说明、只读预览、执行。
## 内置执行仍委托旧处理函数；新效果可以一次注册完整定义。

const KIND_GROUPS := {
	EffectData.Kind.DAMAGE: ["damage", "overdo", "gravity_damage", "shield_smash", "break_shield_damage",
		"energy_discharge", "heat_burst", "destroy_2x2", "clear_board", "heat_to_damage_flow", "spend_gold_damage",
		"electric_strike", "fire_power", "energy_to_heat_damage", "cold_snap", "damage_multi", "solo_release", "chip_shield_damage"],
	EffectData.Kind.DAMAGE_ALL: ["damage_all"],
	EffectData.Kind.BLOCK: ["block_temp", "joint_force"],
	EffectData.Kind.PERSISTENT_BLOCK: ["block_persist", "alloy"],
	EffectData.Kind.HEAL: ["heal"],
	EffectData.Kind.DRAW_CHARS: ["draw_random", "draw_excluding_source"],
	EffectData.Kind.GAIN_GOLD: ["gold"],
	EffectData.Kind.ENERGY: ["energy", "energy_around_tail"],
	EffectData.Kind.HEAT: ["heat", "heat_clear", "heat_cleanse"],
	EffectData.Kind.TEMP_FUNDS: ["temp_funds"],
	EffectData.Kind.APPLY_STATUS: ["apply_status_self", "apply_status_enemy", "ignite", "strength_growing"],
}
const INTERACTIONS := {
	"suspend_three": "choose_three_tiles", "recast_three": "choose_three_tiles",
	"precision_place": "choose_discard_place", "fuse_cards": "choose_fuse_pair",
	"place_two": "choose_place_two", "reshuffle_line": "choose_line", "reverse_line": "choose_line",
	"gild_glyph": "choose_glyph_gild", "swap_cells": "choose_any_pair", "move_cell": "choose_move",
	"recover_two": "choose_recover_two", "recover_to_bag": "choose_recover_to_bag",
	"collect_own": "choose_own_tiles", "divert": "choose_junk_tiles", "merge_flow": "choose_merge_flow",
	"buyback": "choose_buyback", "reveal_place": "choose_bag_deploy", "transform_board": "reveal_pick_board",
	"refine_layer": "choose_same_pair", "empower_glyph": "choose_glyph_empower", "refine_remove": "choose_battle_card_remove",
}
const SOLO_NEIGHBOR := ["cleanse_adjacent", "wash_adjacent", "move_neighbor", "throw_neighbor", "split_neighbor", "recast_neighbor", "refine_junk_neighbor"]
const SOLO_BAG := ["precision_draw", "buy_bag_solo"]

static var _definitions: Dictionary = {}
static var _builtin_metadata: Dictionary = {}


static func register_handler(id: String, definition: Dictionary) -> bool:
	if not id.contains(":") or id.get_slice(":", 0).is_empty() or id.get_slice(":", 1).is_empty() or id.strip_edges() != id or _definitions.has(id):
		return false
	if not definition.get("execute", Callable()) is Callable:
		return false
	if not definition.get("execute", Callable()).is_valid():
		return false
	for callback in ["validate", "preview", "targets", "describe"]:
		if definition.has(callback):
			if not definition[callback] is Callable or not definition[callback].is_valid():
				return false
	if definition.has("kind") and (not definition.kind is int or not EffectData.Kind.values().has(definition.kind)):
		return false
	if definition.has("required_target") and (not definition.required_target is int or not EffectData.Target.values().has(definition.required_target)):
		return false
	for field in ["interaction", "needs"]:
		if definition.has(field) and not definition[field] is String:
			return false
	_definitions[id] = definition.duplicate(true)
	return true


static func unregister_handler(id: String) -> void:
	_definitions.erase(id)


static func metadata(id: String) -> Dictionary:
	if _definitions.has(id):
		return _definitions[id].duplicate(true)
	if _builtin_metadata.is_empty():
		for kind in KIND_GROUPS:
			for handler in KIND_GROUPS[kind]:
				_builtin_metadata[handler] = {"kind": kind}
		for handler in INTERACTIONS:
			if not _builtin_metadata.has(handler):
				_builtin_metadata[handler] = {}
			_builtin_metadata[handler]["interaction"] = INTERACTIONS[handler]
	return (_builtin_metadata.get(id, {}) as Dictionary).duplicate(true)


static func semantic_kind(effect: EffectData) -> int:
	if effect.handler.is_empty():
		return effect.kind
	return int(metadata(effect.handler).get("kind", EffectData.Kind.ABILITY if effect.timing == "persistent" else EffectData.Kind.SPECIAL))


static func execute(id: String, effect: EffectData, context: Dictionary) -> Array:
	if _definitions.has(id):
		return _definitions[id].execute.call(effect, context)
	return EffectHandlers.run_builtin(id, effect, context)


static func validate(effect: EffectData, b: BattleState, path: Array, target: Dictionary) -> String:
	if effect.handler.contains(":") and not _definitions.has(effect.handler):
		return "效果未注册：" + effect.handler
	var definition: Dictionary = _definitions.get(effect.handler, {})
	if definition.get("validate", Callable()).is_valid():
		return str(definition.validate.call(effect, {"battle": b, "path": path, "target": target}))
	return EffectTargets.validate_builtin(b, effect.handler, path, target)


static func targets(effect: EffectData, b: BattleState, path: Array) -> Dictionary:
	var definition: Dictionary = _definitions.get(effect.handler, {})
	if definition.get("targets", Callable()).is_valid():
		return definition.targets.call(effect, {"battle": b, "path": path})
	return {}


static func preview(effect: EffectData, b: BattleState, path: Array, target: Dictionary) -> String:
	var definition: Dictionary = _definitions.get(effect.handler, {})
	if definition.get("preview", Callable()).is_valid():
		return str(definition.preview.call(effect, {"battle": b, "path": path, "target": target}))
	return EffectDescriptions.legacy_preview(effect, b, path, target)


static func describe(effect: EffectData) -> String:
	if not effect.note.is_empty():
		return effect.note
	var definition: Dictionary = _definitions.get(effect.handler, {})
	if definition.get("describe", Callable()).is_valid():
		return str(definition.describe.call(effect))
	return effect.describe_builtin()
