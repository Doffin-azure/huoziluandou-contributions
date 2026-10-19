extends RefCounted
class_name EffectPreview
## 兼容旧 UI 调用；说明与只读预览统一由核心层提供。

static func word_for(glyphs: Array) -> WordData:
	return EffectDescriptions.word_for(glyphs)


static func word_text(word: WordData, b: BattleState, path: Array = [], target: Dictionary = {}, concise := false) -> String:
	return EffectDescriptions.word_text(word, b, path, target, concise)


static func solo_text(inst: CharInstance, b: BattleState, path: Array = [], target: Dictionary = {}) -> String:
	return EffectDescriptions.solo_text(inst, b, path, target)


static func replayable(b: BattleState) -> Array:
	return EffectDescriptions.replayable(b)


static func refundable(b: BattleState) -> int:
	return EffectDescriptions.refundable(b)
