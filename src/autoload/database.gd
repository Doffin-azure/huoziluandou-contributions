extends Node
## 内容数据库：扫描 res://resources 下的 .tres，建立索引。
## 新增字/词/敌人/幕 = 往对应目录丢一个 .tres，不需要改代码。

const CHAR_DIR := "res://resources/characters"
const WORD_DIR := "res://resources/words"
const STATUS_DIR := "res://resources/statuses"
const POLLUTION_DIR := "res://resources/pollutions"
const ENEMY_DIR := "res://resources/enemies"
const ACT_DIR := "res://resources/acts"
const DECK_DIR := "res://resources/starter_decks"
const RULES_PATH := "res://resources/rules/default_rules.tres"

var characters: Dictionary = {}      ## id -> CharacterData
var char_by_glyph: Dictionary = {}   ## glyph -> CharacterData
var words: Dictionary = {}           ## id -> WordData
var words_by_glyphs: Dictionary = {} ## "击破" -> WordData
var statuses: Dictionary = {}        ## id -> StatusData
var pollutions: Dictionary = {}      ## id -> PollutionData
var enemies: Dictionary = {}         ## id -> EnemyData
var acts: Dictionary = {}            ## index -> ActData
var starter_decks: Dictionary = {}   ## id -> StarterDeckData
var rules: BattleRules = null

var warnings: Array[String] = []


func _ready() -> void:
	reload()


func reload() -> void:
	characters.clear()
	char_by_glyph.clear()
	words.clear()
	words_by_glyphs.clear()
	statuses.clear()
	pollutions.clear()
	enemies.clear()
	acts.clear()
	starter_decks.clear()
	warnings.clear()

	for res in _load_dir(CHAR_DIR, "CharacterData"):
		characters[res.id] = res
		char_by_glyph[res.glyph] = res
	for res in _load_dir(WORD_DIR, "WordData"):
		words[res.id] = res
		words_by_glyphs[res.glyph_string()] = res
	for res in _load_dir(STATUS_DIR, "StatusData"):
		statuses[res.id] = res
	for res in _load_dir(POLLUTION_DIR, "PollutionData"):
		pollutions[res.id] = res
	for res in _load_dir(ENEMY_DIR, "EnemyData"):
		enemies[res.id] = res
	for res in _load_dir(ACT_DIR, "ActData"):
		acts[res.index] = res
	for res in _load_dir(DECK_DIR, "StarterDeckData"):
		starter_decks[res.id] = res

	if ResourceLoader.exists(RULES_PATH):
		rules = load(RULES_PATH)
	if rules == null:
		rules = BattleRules.default_rules()

	print("[Database] 字 %d / 词 %d / 敌人 %d / 幕 %d / 污染 %d" % [
		characters.size(), words.size(), enemies.size(), acts.size(), pollutions.size()
	])


func _load_dir(dir_path: String, _expect_class: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir_path):
		warnings.append("目录不存在: %s" % dir_path)
		return out
	var files := DirAccess.get_files_at(dir_path)
	for f in files:
		if f.ends_with(".remap"):
			f = f.trim_suffix(".remap")
		if not (f.ends_with(".tres") or f.ends_with(".res")):
			continue
		var full := dir_path.path_join(f)
		var res = load(full)
		if res == null:
			warnings.append("无法加载: %s" % full)
			continue
		out.append(res)
	return out


func get_character(id: String) -> CharacterData:
	return characters.get(id)


func get_character_by_glyph(glyph: String) -> CharacterData:
	return char_by_glyph.get(glyph)


func get_pollution(id: String) -> PollutionData:
	return pollutions.get(id)


func get_word_by_glyphs(glyphs: Array) -> WordData:
	var key := ""
	for g in glyphs:
		key += str(g)
	return words_by_glyphs.get(key)


func get_word_by_glyphs_string(key: String) -> WordData:
	return words_by_glyphs.get(key)


func get_status(id: String) -> StatusData:
	return statuses.get(id)


func get_enemy(id: String) -> EnemyData:
	return enemies.get(id)


func get_act(index: int) -> ActData:
	return acts.get(index)
