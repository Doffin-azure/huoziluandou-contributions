extends RefCounted
class_name GlyphVfxProfile
## 纯表现映射：字义决定符号和运动，实际效果决定落点，不参与结算或游戏随机数。
const GLYPHS := {
	"击": ["hit", "hit", "slash"], "破": ["hit", "fracture", "fracture"], "反": ["hit", "counter", "reverse"],
	"火": ["fire", "heat", "embers"], "热": ["fire", "heat_overload_bonus_armed", "steam"], "爆": ["fire", "blast", "blast"],
	"电": ["electric", "energy", "arc"], "蓄": ["electric", "energy_idle", "charge"], "充": ["electric", "auto_refill", "split_charge"],
	"冷": ["ice", "frost", "crystal"], "防": ["shield", "block", "ward"], "盾": ["shield", "persistent_block", "plates"],
	"御": ["shield", "turn_guard", "orbit"], "甲": ["shield", "armor_plating", "plates"], "护": ["shield", "guard_inject", "barrier"],
	"障": ["shield", "prevent_interference", "barrier"], "心": ["heal", "health", "pulse"], "蚀": ["poison", "heart_corrosion", "drip"],
	"污": ["poison", "poison", "stain"], "秽": ["poison", "poison", "drip"], "重": ["gravity", "gravity_always", "down"],
	"左": ["gravity", "move_left", "left"], "右": ["gravity", "move_right", "right"], "回": ["flow", "return", "loop"],
	"转": ["flow", "rotate", "swirl"], "流": ["flow", "flow", "ripple"], "速": ["flow", "accel", "dash"],
	"急": ["flow", "next_rapid", "dash"], "再": ["flow", "repeat", "echo"], "复": ["flow", "next_copy_layer", "echo"],
	"连": ["flow", "serial", "thread"], "放": ["flow", "next_draw_bonus", "outward"], "金": ["gold", "gold", "coins"],
	"币": ["gold", "gold", "coins"], "资": ["gold", "temp_funds", "orbit"], "利": ["gold", "compound_equity", "rise"],
	"投": ["gold", "equity", "rise"], "购": ["gold", "gold_to_shield", "outward"], "收": ["draw", "manual_draw", "gather"],
	"能": ["draw", "longword_draw", "cards"], "合": ["ability", "shared_attack", "merge"], "分": ["draw", "profit_share", "split"],
	"加": ["draw", "next_draw_bonus", "cards"], "过": ["flow", "next_diagonal", "bridge"], "超": ["ability", "empowered", "star"],
	"力": ["ability", "strength", "pulse"], "强": ["ability", "strong_heart", "star"], "精": ["ability", "manual_draw", "star"],
	"化": ["ability", "next_compound", "merge"], "炼": ["clean", "cleanse", "dissolve"], "铸": ["shield", "armor_plating", "stamp"],
	"清": ["clean", "cleanse", "wash"], "洗": ["clean", "cleanse", "wash"], "开": ["ability", "unlock", "outward"],
	"灯": ["ability", "lantern", "glow"], "停": ["flow", "ceasefire", "stop"], "息": ["electric", "energy_idle", "settle"],
	"载": ["draw", "reload", "cards"], "灰": ["ink", "unknown", "dust"], "骨": ["shield", "armor_plating", "dust"],
	"碍": ["shield", "no_block", "barrier"]
}
const COLORS := {"hit": Color("98392c"), "fire": Color("ba592f"), "electric": Color("557c88"),
	"ice": Color("83a6ad"), "shield": Color("90733e"), "heal": Color("56866a"),
	"poison": Color("665568"), "gravity": Color("69523b"), "flow": Color("587579"),
	"gold": Color("aa823d"), "draw": Color("8c7751"), "ability": Color("a18243"), "clean": Color("709787"), "ink": Color("473e33")}
const BOARD_HANDLERS := ["gravity", "gravity_left", "gravity_right", "gravity_damage", "rotate_2x2", "rotate_3x3", "rotate_repeat",
	"shift_row", "swap_cells", "converge", "replace_self", "draw_random", "place_two", "recover_two", "move_cell", "recover_to_bag",
	"destroy_2x2", "clear_board", "cleanse_adjacent", "cleanse_all", "reshuffle_line"]


static func for_play(glyphs: Array, word: WordData = null, effects: Array = []) -> Dictionary:
	var parts: Array = []
	for glyph in glyphs:
		parts.append(for_glyph(str(glyph)))
	var profile: Dictionary = parts[0].duplicate(true) if not parts.is_empty() else for_glyph("")
	profile["parts"] = parts.slice(0, 4)
	profile["seed"] = "".join(glyphs).hash()
	profile["glyphs"] = glyphs.duplicate()
	profile["board"] = false
	profile["focus"] = "ability"
	if effects.is_empty():
		if word != null:
			effects = word.effects
		elif glyphs.size() == 1:
			var data := Database.get_character_by_glyph(str(glyphs[0]))
			if data != null:
				effects = data.solo_effects
	for effect in effects:
		if effect.handler in BOARD_HANDLERS or effect.semantic_kind() == EffectData.Kind.DRAW_CHARS:
			profile.board = true
		var kind: int = effect.semantic_kind()
		match kind:
			EffectData.Kind.DAMAGE, EffectData.Kind.DAMAGE_ALL: profile.focus = "enemy"
			EffectData.Kind.BLOCK, EffectData.Kind.PERSISTENT_BLOCK:
				if profile.focus != "enemy": profile.focus = "shield"
			EffectData.Kind.HEAL:
				if profile.focus != "enemy": profile.focus = "heal"
			EffectData.Kind.ENERGY:
				if profile.focus == "ability": profile.focus = "energy"
			EffectData.Kind.HEAT:
				if profile.focus == "ability": profile.focus = "heat"
			EffectData.Kind.GAIN_GOLD:
				if profile.focus == "ability": profile.focus = "gold"
			EffectData.Kind.TEMP_FUNDS:
				if profile.focus == "ability": profile.focus = "temp_funds"
			EffectData.Kind.EQUITY:
				if profile.focus == "ability": profile.focus = "equity"
		if effect.handler.begins_with("rotate"):
			profile.merge(_family("flow", "rotate", "swirl"), true)
		elif effect.handler.begins_with("gravity"):
			profile.merge(_family("gravity", "gravity_always", "left" if effect.handler == "gravity_left" else ("right" if effect.handler == "gravity_right" else "down")), true)
		elif effect.handler in ["electric_strike", "energy_discharge"]:
			profile.merge(_family("electric", "energy", "arc"), true)
		elif effect.handler in ["destroy_2x2", "clear_board"]:
			profile.merge(_family("fire", "blast", "blast"), true)
		elif effect.handler.begins_with("ability_") and BattleSymbol.SPECS.has(effect.handler.trim_prefix("ability_")):
			profile.symbol = effect.handler.trim_prefix("ability_")
	if profile.board and profile.focus == "ability":
		profile.focus = "board"
	return profile


static func for_glyph(glyph: String) -> Dictionary:
	var spec: Array = GLYPHS.get(glyph, ["ink", "unknown", "dust"])
	var result := _family(str(spec[0]), str(spec[1]), str(spec[2]))
	result["seed"] = glyph.hash()
	return result


static func _family(family: String, symbol: String, style: String) -> Dictionary:
	return {"family": family, "symbol": symbol, "style": style, "color": COLORS[family]}


static func feedback(profile: Dictionary, kind: String, shield_gain := 0) -> Dictionary:
	var result := profile.duplicate(true)
	if kind == "heal": result.merge(_family("heal", "health", "pulse"), true)
	elif kind == "shield": result.merge(_family("shield", "fracture" if shield_gain < 0 else "block", "fracture" if shield_gain < 0 else "ward"), true)
	return result
