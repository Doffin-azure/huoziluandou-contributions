extends SceneTree
## 内容生成器 V2：把 V0.1/V0.2 的权威表格一次性生成为 .tres 资源。
##
## 数据来源（res://data/import/）：
##   完整词效总账_P23及新增_105词.csv  -> resources/words/*.tres
##   单字出牌规则及11个P25实现.csv      -> resources/characters/*.tres 的单字效果
## 生成后即可在 Inspector 里直接改资源，不需要再跑本脚本。
##
## 运行：godot --headless --script res://src/tools/build_content.gd

const CharacterDataS := preload("res://src/data/character_data.gd")
const EffectDataS := preload("res://src/data/effect_data.gd")
const WordDataS := preload("res://src/data/word_data.gd")
const StatusDataS := preload("res://src/data/status_data.gd")
const PollutionDataS := preload("res://src/data/pollution_data.gd")
const EnemyDataS := preload("res://src/data/enemy_data.gd")
const EnemyMoveDataS := preload("res://src/data/enemy_move_data.gd")
const MapNodeDataS := preload("res://src/data/map_node_data.gd")
const ActDataS := preload("res://src/data/act_data.gd")
const DeckEntryDataS := preload("res://src/data/deck_entry_data.gd")
const StarterDeckDataS := preload("res://src/data/starter_deck_data.gd")
const BattleRulesS := preload("res://src/data/battle_rules.gd")

const RES := "res://resources"
const IMPORT := "res://data/import"

## 已裁撤内容（见 docs/裁撤记录.md）。总账不删行，生成时跳过。
const CUT_GLYPHS := ["纯"]
const CUT_WORDS := ["纯化", "纯金", "纯利", "精纯", "强力反击"]

## 特殊交互（WordData.interaction）
const INTERACTIONS := {"转化": "reveal_pick_board", "强化": "choose_glyph_empower", "炼化": "choose_battle_card_remove", "化合": "choose_fuse_pair", "精炼": "choose_same_pair", "精金": "choose_glyph_gild", "精铸": "choose_discard_place", "再铸": "choose_discard_place", "反转": "choose_line", "合流": "choose_merge_flow"}
## 界面分组覆盖（设计负责人重定义后，不再归入原总账分组）
const GROUP_OVERRIDES := {"转化": "空间", "分化": "空间", "停电": "彩蛋"}

var _char_by_glyph: Dictionary = {}
var _solo_rows: Dictionary = {}


func _initialize() -> void:
	for d in ["characters", "words", "statuses", "pollutions", "enemies", "acts", "starter_decks", "rules"]:
		DirAccess.make_dir_recursive_absolute(RES.path_join(d))
		_clear_dir(RES.path_join(d))

	_read_solo_rows()
	_build_pollutions()
	_build_statuses()
	_build_curated_characters()
	_build_words_from_ledger()
	_build_extra_words()
	_build_enemies()
	_build_acts()
	_build_starter_deck()
	_build_rules()

	print("[build_content] 完成：字 %d / 词 %d" % [_char_by_glyph.size(), _count_files(RES.path_join("words"))])
	quit()


func _clear_dir(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".tres") or f.ends_with(".res"):
			DirAccess.remove_absolute(dir_path.path_join(f))


func _count_files(dir_path: String) -> int:
	var n := 0
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".tres"):
			n += 1
	return n


# ---------------------------------------------------------------- 基础构造
func _e(handler: String, amount := 0, target := -1, status := "", note := "", args := {}, kind := -1, timing := "immediate") -> EffectData:
	var e: EffectData = EffectDataS.new()
	e.handler = handler
	e.amount = amount
	if target >= 0:
		e.target = target
	e.status_id = status
	e.args = args
	e.timing = timing
	if kind >= 0:
		e.kind = kind
	e.note = note if not note.is_empty() else _handler_note(handler, amount, status, args)
	return e


## 简易效果的默认文案（保证预览/图鉴/策划案都准确）
func _handler_note(handler: String, amount: int, status: String, args: Dictionary) -> String:
	match handler:
		"block_temp": return "获得 %d 点临时格挡" % amount
		"block_persist": return "获得 %d 点持久盾" % amount
		"damage": return "造成 %d 点伤害" % amount
		"damage_all": return "对所有敌人造成 %d 点伤害" % amount
		"draw_random": return "随机补 %d 字" % amount
		"draw_penalty_next": return "下一次正常补字 -%d" % amount
		"heal": return "回复 %d 点生命" % amount
		"energy": return "获得 %d 点储能" % amount
		"heat": return "热度 %+d" % amount if amount != 0 else "热度不变"
		"heat_clear": return "清空当前热度"
		"gold": return "获得 %d 金币" % amount
		"temp_funds": return "获得 %d 点临时资金（本回合有效）" % amount
		"apply_status_self": return "获得状态【%s】×%d" % [_status_name(status), max(1, amount)]
		"apply_status_enemy": return "使敌人获得【%s】×%d" % [_status_name(status), max(1, amount)]
		"remove_enemy_block": return "移除敌人全部护盾"
		"cleanse_all": return "清除当前字盘的全部污染（所有权不变）"
		"cleanse_adjacent": return "净化目标及其四邻的污染"
		"gravity": return "全盘按列向下重力"
		"rotate_2x2": return "顺时转旋转所选 2×2 区域"
		"destroy_2x2": return "摧毁所选 2×2，每摧毁 1 字造成 %d 伤" % amount
		"recover_consumed": return "从弃字堆回收本回合消耗的 1 枚字到袋顶"
		"replay_last_attack": return "重演上一个即时攻击词的效果"
		"shield_smash": return "造成 %d 伤并消耗全部持久盾（每 2 点额外 3 伤）" % amount
		"counter": return "预留 %d 层反击" % max(1, amount)
		"conditional_draw_after_attack": return "若此前已有即时攻击则补 %d 字" % amount
		"conditional_draw_half_hp": return "低于半血补 %d 字，否则补 %d 字" % [int(args.get("low", amount)), int(args.get("high", 1))]
		"break_shield_damage": return "造成 %d 伤；拆盾效率×2；击碎护盾再补 1 字" % amount
		"permanent_damage_reduction": return "本局永久：每次实际生命伤害 -%d" % amount
		"permanent_gold_growth": return "本局每场胜利后金币 +%d%%" % amount
		"transform_board": return "随机揭示 %d 枚实体字，选 1 枚替换盘面指定字" % int(args.get("reveal", 5))
		"split_grow": return "删除一个盘面字，四周生长可组词临时字"
		"empower_glyph": return "选择一个字，本场它被打出时额外触发单字效果"
		"refine_remove": return "热度 -%d、金币 +%d，并移出一张牌" % [int(args.get("heat", 3)), int(args.get("gold", 4))]
		"fuse_cards": return "选两张相邻己方牌融合为一格（本场不可拆）"
		"refine_layer": return "选两个相同己方字，本场一直重合（可重复使用）"
		"gild_glyph": return "选一个字永久镀金；每次参与多字词 +1 金币"
		"precision_place": return "支付 %d 金币，把弃字堆一枚字放进指定空格" % amount
		"recast_board": return "把盘面上已有的字全部重新替换"
		"recast_copy": return "从弃字堆选一张，把临时复制放进指定空格"
		"repeat_last": return "重复上一个词/字的最后一个字（临时）"
		"reverse_line": return "选一行或一列，倒转其 4 格（含空格/叠层）"
		"merge_flow": return "揭示字袋 1 枚 + 弃字堆 1 枚，放入两个相邻空格"
		"hard_stop": return "清空热度并移除未打出的灼热【热】；立即结束出字"
		"repeat_word": return "每回合第一次多字词再执行一次"
		_:
			return handler


func _status_name(id: String) -> String:
	match id:
		"strength": return "强力"
		"vulnerable": return "易伤"
		"next_bonus": return "加强"
		"next_double": return "超强"
		"next_extra": return "超载"
		"burn": return "灼烧"
		"poison": return "中毒"
		_: return id


func _teffects(list: Array) -> Array[EffectData]:
	var out: Array[EffectData] = []
	for e in list:
		out.append(e)
	return out


func _strs(list: Array) -> Array[String]:
	var out: Array[String] = []
	for s in list:
		out.append(str(s))
	return out


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("保存失败 %s (%d)" % [path, err])


# ---------------------------------------------------------------- 污染
func _build_pollutions() -> void:
	var defs := [
		{"id": "rush", "name": "刺痛", "glyph": "刺", "hp": 2, "draw": 0, "color": "8c2a20",
		 "desc": "打出附着刺痛的字时，失去 2 点生命。"},
		{"id": "block", "name": "堵塞", "glyph": "堵", "hp": 0, "draw": 1, "color": "6b6354",
		 "desc": "打出附着堵塞的字后，下一次正常补字数量 -1（一次性）。"},
		{"id": "scorch", "name": "灼热", "glyph": "灼", "hp": 1, "draw": 0, "color": "b0522e",
		 "desc": "自我过热生成的【热】带有灼热，打出时失去 1 点生命；本场循环，战后清除。"},
	]
	for d in defs:
		var p: PollutionData = PollutionDataS.new()
		p.id = d.id
		p.name = d.name
		p.glyph = d.glyph
		p.hp_loss_on_play = d.hp
		p.draw_penalty_on_play = d.draw
		p.color = Color(d.color)
		p.description = d.desc
		p.self_generated = d.id == "scorch"
		_save(p, "%s/pollutions/%s.tres" % [RES, p.id])


# ---------------------------------------------------------------- 状态
func _build_statuses() -> void:
	var defs := [
		{"id": "strength", "name": "强力", "glyph": "力", "kind": 0, "color": "b8523a", "decay": 0,
		 "desc": "每层使你的伤害 +1。"},
		{"id": "vulnerable", "name": "易伤", "glyph": "脆", "kind": 1, "color": "7a4a63", "decay": 1,
		 "desc": "受到的伤害提高 50%。"},
		{"id": "poison", "name": "中毒", "glyph": "毒", "kind": 1, "color": "5f7d6a", "decay": 1,
		 "desc": "回合开始损失等量生命。"},
		{"id": "next_bonus", "name": "加强", "glyph": "增", "kind": 0, "color": "3c4a6b", "decay": 0,
		 "desc": "下一次攻击每段 +2 伤害。"},
		{"id": "next_double", "name": "超强", "glyph": "倍", "kind": 0, "color": "7a3b3b", "decay": 0,
		 "desc": "下一次造成伤害的攻击翻倍。"},
		{"id": "next_extra", "name": "超载", "glyph": "载", "kind": 0, "color": "b0522e", "decay": 0,
		 "desc": "下一次多字词的即时效果额外执行一次。"},
		{"id": "burn", "name": "灼烧", "glyph": "燃", "kind": 1, "color": "b0522e", "decay": 0,
		 "desc": "接下来 2 次敌方行动各受到一次灼烧伤害。"},
	]
	for d in defs:
		var s: StatusData = StatusDataS.new()
		s.id = d.id
		s.name = d.name
		s.glyph = d.glyph
		s.kind = d.kind
		s.description = d.desc
		s.color = Color(d.color)
		s.decay_per_turn = d.decay
		_save(s, "%s/statuses/%s.tres" % [RES, s.id])


# ---------------------------------------------------------------- 单字表
func _read_solo_rows() -> void:
	var f := FileAccess.open(IMPORT.path_join("solo_effects.txt"), FileAccess.READ)
	if f == null:
		return
	f.get_csv_line()  # header
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 3 and not row[0].is_empty():
			_solo_rows[row[0]] = {"direction": row[2], "state": row[3] if row.size() > 3 else ""}
	f.close()


## 单字效果：来自 V0.2 附录 C（击/防/护/御/回/重/清/反/甲/盾/破）。
func _solo_spec(glyph: String) -> Dictionary:
	match glyph:
		"击": return {"h": "damage", "a": 4, "note": "造成 4 伤害"}
		"防": return {"h": "block_temp", "a": 4, "note": "获得 4 点临时格挡"}
		"护": return {"h": "block_persist", "a": 2, "note": "获得 2 点持久盾"}
		"御": return {"h": "block_temp", "a": 2, "note": "获得 2 点临时格挡"}
		"回": return {"h": "replace_self", "target": EffectDataS.Target.BOARD_TILE, "note": "在原位置随机换一枚字"}
		"重": return {"h": "gravity", "target": EffectDataS.Target.BOARD, "note": "字盘按列向下重力"}
		"清": return {"h": "cleanse_adjacent", "target": EffectDataS.Target.BOARD_TILE, "note": "净化一个四邻污染标记（保留字与所有权）"}
		"反": return {"h": "damage", "a": 2, "note": "占位：造成 2 伤害（用户未确认）"}
		"甲": return {"h": "block_temp", "a": 2, "note": "占位：获得 2 临时格挡（单字用途未定）"}
		"盾": return {"h": "block_temp", "a": 3, "note": "占位：获得 3 临时格挡（反弹方案已撤回）"}
		"破": return {"h": "damage", "a": 3, "note": "占位：造成 3 伤害（单字用途未定）"}
		"再": return {"h": "repeat_last", "note": "单字：重复上一个词/字的最后一个字（临时）"}
	return {}


func _build_curated_characters() -> void:
	# glyph, id, pinyin, tags, rarity, is_pollution
	var defs := [
		["击", "ji", "ji", ["attack"], 0, false],
		["防", "fang", "fang", ["defense"], 0, false],
		["回", "hui", "hui", ["space", "flow"], 0, false],
		["反", "fan", "fan", ["defense", "attack"], 0, false],
		["破", "po", "po", ["attack"], 0, false],
		["重", "zhong", "zhong", ["space"], 0, false],
		["流", "liu", "liu", ["flow"], 0, false],
		["连", "lian", "lian", ["attack"], 0, false],
		["御", "yu", "yu", ["defense"], 0, false],
		["护", "hu", "hu", ["defense"], 1, false],
		["甲", "jia", "jia", ["defense"], 1, false],
		["盾", "dun", "dun", ["defense"], 1, false],
		["力", "li", "li", ["utility"], 1, false],
		["合", "he", "he", ["attack"], 1, false],
		["强", "qiang", "qiang", ["utility"], 1, false],
		["加", "jia2", "jia", ["utility"], 1, false],
		["超", "chao", "chao", ["utility"], 2, false],
		["复", "fu", "fu", ["economy", "utility"], 1, false],
		["转", "zhuan", "zhuan", ["space"], 1, false],
		["清", "qing", "qing", ["flow"], 1, false],
		["洗", "xi", "xi", ["flow"], 2, false],
		["电", "dian", "dian", ["energy"], 1, false],
		["蓄", "xu", "xu", ["energy"], 1, false],
		["能", "neng", "neng", ["energy"], 1, false],
		["充", "chong", "chong", ["energy"], 1, false],
		["放", "fang2", "fang", ["energy", "space"], 1, false],
		["热", "re", "re", ["heat"], 1, false],
		["火", "huo", "huo", ["heat"], 1, false],
		["爆", "bao", "bao", ["heat"], 2, false],
		["过", "guo", "guo", ["heat"], 1, false],
		["载", "zai", "zai", ["heat"], 1, false],
		["速", "su", "su", ["heat"], 2, false],
		["急", "ji2", "ji", ["heat"], 1, false],
		["冷", "leng", "leng", ["heat"], 1, false],
		["却", "que", "que", ["heat"], 2, false],
		["停", "ting", "ting", ["heat"], 2, false],
		["息", "xi2", "xi", ["heat"], 2, false],
		["金", "jin", "jin", ["economy"], 1, false],
		["币", "bi", "bi", ["economy"], 1, false],
		["资", "zi", "zi", ["economy"], 1, false],
		["投", "tou", "tou", ["economy", "space"], 1, false],
		["利", "li2", "li", ["economy"], 2, false],
		["购", "gou", "gou", ["economy"], 2, false],
		["收", "shou", "shou", ["flow"], 2, false],
		["铸", "zhu", "zhu", ["economy"], 2, false],
		["炼", "lian2", "lian", ["economy"], 2, false],
		["纯", "chun", "chun", ["economy"], 2, false],
		["再", "zai2", "zai", ["economy"], 2, false],
		["分", "fen", "fen", ["flow"], 2, false],
		["化", "hua", "hua", ["alchemy"], 3, false],
		["精", "jing", "jing", ["alchemy"], 3, false],
		# 额外基础字（保护旧脚手架内容）
		["攻", "gong", "gong", ["attack"], 2, false],
		["剑", "jian", "jian", ["attack"], 3, false],
		["心", "xin", "xin", ["utility"], 2, false],
		["愈", "yu2", "yu", ["utility"], 3, false],
		["毒", "du", "du", ["attack"], 3, false],
		["雷", "lei", "lei", ["attack"], 3, false],
		# 敌人注入用的实体字（可被玩家组词，消耗后消失）
		["蚀", "shi", "shi", ["enemy"], 2, false],
		["障", "zhang", "zhang", ["enemy"], 2, false],
		["灰", "hui2", "hui", ["enemy", "彩蛋"], 2, false],
		["骨", "gu", "gu", ["彩蛋"], 3, false],
		["开", "kai", "kai", ["彩蛋"], 3, false],
		["灯", "deng", "deng", ["彩蛋"], 3, false],
		["碍", "ai", "ai", ["enemy"], 2, false],
		["秽", "hui3", "hui", ["enemy"], 2, false],
		["污", "pollution", "wu", ["pollution"], 0, true],
	]
	for d in defs:
		if CUT_GLYPHS.has(d[0]):
			continue
		_make_character(d[0], d[1], d[2], d[3], d[4], d[5], false)


func _make_character(glyph: String, id: String, pinyin: String, tags: Array, rarity: int, is_pollution: bool, pending: bool, desc := "") -> CharacterData:
	var c: CharacterData = CharacterDataS.new()
	c.id = id
	c.glyph = glyph
	c.pinyin = pinyin
	c.tags = _strs(tags)
	c.rarity = rarity
	c.is_pollution = is_pollution
	c.pending_design = pending
	var spec := _solo_spec(glyph)
	if not spec.is_empty():
		var e := _e(spec.get("h", ""), int(spec.get("a", 0)), int(spec.get("target", -1)), "", spec.get("note", ""))
		c.solo_effects = _teffects([e])
		c.solo_handler = spec.get("h", "")
	if not desc.is_empty():
		c.description = desc
	elif not spec.is_empty():
		c.description = spec.get("note", "")
	else:
		c.description = "可单字打出（暂无单字效果，用于腾出空格）。"
	if is_pollution:
		c.removable = false
		c.description = "污染源字。"
	_char_by_glyph[glyph] = c
	_save(c, "%s/characters/%s.tres" % [RES, id])
	return c


func _ensure_glyph(glyph: String) -> CharacterData:
	if _char_by_glyph.has(glyph):
		return _char_by_glyph[glyph]
	# 未列入策划单字表的候选字：自动创建为待定字（保证词网完整）
	return _make_character(glyph, "auto_" + glyph, "", ["pending"], 3, false, true,
		"候选字（来自词网，单字效果未定）。")


# ---------------------------------------------------------------- 词（105 条总账）
func _word_effects(word: String) -> Array:
	# 按《完整词效总账》的“最近讨论效果方向”实现；未收敛的返回空数组（=待定）。
	var T := EffectDataS.Target
	match word:
		# 防反
		"防御": return [_e("block_temp", 10)]
		"防护": return [_e("ability_prevent_interference", 1, -1, "", "本场持续：抵消下一次敌人对字盘的干扰（注入/塞字）", {}, -1, "persistent")]
		"护甲": return [_e("ability_convert_block", 50, -1, "", "回合结束把一半剩余临挡转为持久盾", {"percent": 50}, -1, "persistent")]
		"护盾": return [_e("block_persist", 6)]
		"重甲": return [_e("block_persist", 12), _e("draw_penalty_next", 1)]
		"反击": return [_e("counter", 3, -1, "", "预留反击；敌人整次行动后把剩余临挡转为伤害并 +3/层", {}, -1, "delayed")]
		"盾击": return [_e("shield_smash", 4, T.ENEMY, "", "造成 4 伤并消耗全部持久盾，每 2 点额外 3 伤", {"per": 2, "bonus": 3})]
		"回防": return [_e("block_temp", 8), _e("conditional_draw_after_attack", 1)]
		"破防": return [_e("apply_status_enemy", 2, T.ENEMY, "vulnerable")]
		"破甲": return [_e("remove_enemy_block")]
		"击破": return [_e("break_shield_damage", 8, T.ENEMY, "", "造成 8 伤；拆盾效率×2；击碎护盾再补 1 字", {"mult": 2, "draw": 1})]
		"防御力": return [_e("permanent_damage_reduction", 1, -1, "", "首次组出后本局永久每次实际生命伤害 -1", {}, -1, "persistent")]
		"反超": return [_e("conditional_draw_half_hp", 4, -1, "", "低于半血补 4 字，否则补 1 字", {"low": 4, "high": 1})]
		# 连携
		"连击": return [_e("replay_last_attack", 0, -1, "", "重演上一个即时攻击词的效果", {}, -1, "immediate")]
		"重击": return [_e("gravity_damage", 6, T.ENEMY, "", "6 伤 + 重力移动的每枚字块 2 伤", {"per": 2})]
		"合击": return [_e("ability_shared_attack", 4, -1, "", "本回合后续攻击词共享【击】且每词 +4 伤", {}, -1, "persistent")]
		"回击": return [_e("damage", 7), _e("conditional_draw_after_attack", 1)]
		"强力": return [_e("apply_status_self", 2, T.SELF, "strength")]
		"加强": return [_e("apply_status_self", 2, T.SELF, "next_bonus")]
		"超强": return [_e("apply_status_self", 1, T.SELF, "next_double")]
		"重合": return [_e("merge_duplicates", 0, T.BOARD_TILE, "", "汇聚同字：保留 1 实体并获得同数量临时层，其余回字袋")]
		# 流转
		"回流": return [_e("draw_random", 4)]
		"回收": return [_e("recover_consumed", 1, T.DISCARD_GLYPH)]
		"回转": return [_e("rotate_2x2", 0, T.BOARD_2X2)]
		"流转": return [_e("ability_flow", 2, -1, "", "本回合每打出 2 种不同多字词补 2 字", {}, -1, "persistent")]
		"清洗": return [_e("cleanse_all", 0, T.BOARD, "", "清除当前字盘所有污染标签（所有权不变）")]
		"复合": return [_e("ability_compound_next", 1, -1, "", "下一次≥3字词保留 1 枚用过的字为临时层", {}, -1, "next_word")]
		"流利": return [_e("ability_diagonal_next", 1, -1, "", "下一次组词允许最多一步对角线", {}, -1, "next_word")]
		"分流": return [_e("cleanse_all", 0, T.BOARD, "", "清除当前字盘的全部污染（所有权不变）")]
		# 蓄放
		"蓄能": return [_e("ability_energy_idle", 1, -1, "", "回合结束若仍有可用多字词，储能 +1", {}, -1, "persistent")]
		"蓄电": return [_e("energy_around_tail", 1, -1, "", "基础 +1；词尾电周围每个己方四邻字再 +1 储能", {})]
		"充电": return [_e("energy", 3)]
		"充能": return [_e("energy", 1), _e("draw_random", 2)]
		"放电": return [_e("energy_discharge", 4, T.ENEMY, "", "清空全部储能，每点造成一段 4 伤电击", {})]
		"充放电": return [_e("energy_discharge", 4, T.ENEMY, "", "清空全部储能，每点 4 伤并随机补 1 字", {"draw_per": 1})]
		# 热暴
		"过热": return [_e("ability_heat_overload_bonus", 2, -1, "", "本回合首次溢热后，下一次多字词额外补 2 字", {}, -1, "persistent")]
		"过载": return [_e("draw_random", 6), _e("heat", 3)]
		"超载": return [_e("apply_status_self", 1, T.SELF, "next_extra"), _e("heat", 3)]
		"加速": return [_e("ability_accel", 1, -1, "", "本回合每次打出多字词额外补 1 字并热度 +1", {}, -1, "persistent")]
		"急速": return [_e("ability_rapid_next", 3, -1, "", "下一次多字词结算后在其空格补至多 3 字并升温 2", {"heat": 2}, -1, "next_word")]
		"冷却": return [_e("heat", -4)]
		"清热": return [_e("heat_cleanse", 2, -1, "", "热度 -2 并清除灼热污染")] 
		"热流": return [_e("heat_to_damage_flow", 2, T.ENEMY, "", "按本回合补字数最多降 4 热，每实际降 1 热造成 2 伤", {"max": 4})]
		"火爆": return [_e("heat_burst", 8, T.ENEMY, "", "消耗全部热度，造成 8 + 4×热度伤害", {"per": 4})]
		"爆破": return [_e("destroy_2x2", 4, T.BOARD_2X2, "", "摧毁 2×2 区域，每摧毁 1 字造成 4 伤", {})]
		"重载": return [_e("ability_reload", 3, -1, "", "本场热容 +3，此后每回合基础补字 -1", {"draw_penalty": 1}, -1, "persistent")]
		"加热": return [_e("heat", 3)]
		"急冷": return [_e("heat_clear", 0), _e("draw_penalty_next", 1)]
		"过火": return [_e("ability_overfire", 0, -1, "", "下一次攻击额外 + 当前热度×3 伤，同时热度 +2", {"per": 3, "heat": 2}, -1, "next_word")]
		"电流过载": return [_e("ability_electric_overload", 3, -1, "", "本战每次溢热：生成灼热热字、储能 +1、对敌 3 伤", {}, -1, "persistent")]
		"超速": return [_e("ability_double_draw_next", 4, -1, "", "本回合下一次补字翻倍，最多额外 4 字；每额外 1 字升温 1", {}, -1, "next_word")]
		# 经济
		"金币": return [_e("gold", 3)]
		"资金": return [_e("temp_funds", 3)]
		"投币": return [_e("spend_gold_damage", 5, T.ENEMY, "", "支付最多 3 金币，每金币造成 5 伤", {"max": 3})]
		"收购": return [_e("capture_glyph", 4, T.ENEMY_GLYPH, "", "支付 4 金币，净化并永久收编一枚敌方实体字", {})]
		"投放": return [_e("reveal_place", 3, T.EMPTY_TILE, "", "支付 3 金币，随机揭示一枚实体字并指定空格落下", {})]
		"复利投资": return [_e("permanent_gold_growth", 20, -1, "", "首次打出后，本局每场胜利使现有金币额外增长 20%", {}, -1, "persistent")]
		# ---- 蓄放进阶 ----
		"蓄力": return [_e("energy_to_bonus", 2, -1, "", "消耗全部储能，下一次攻击每点储能 +2 伤", {"per": 2})]
		"放热": return [_e("energy_to_heat_damage", 2, T.ENEMY, "", "消耗全部储能：转为热度并对敌每点 2 伤", {"per": 2})]
		"热能": return [_e("heat_to_energy", 1, -1, "", "当前热度转为等量储能")]
		"热力": return [_e("heat_to_bonus", 2, -1, "", "当前热度转为下一次攻击强化（每点 +2）", {"per": 2})]
		"电流": return [_e("flow_energy_or_draw", 2, -1, "", "本回合已补字则储能 +2，否则补 2 字", {})]
		# ---- 经济 / 股权 ----
		"投资": return [_e("invest_equity", 3, -1, "", "支付 3 金币锁定为 3 股权（战后返还本金）", {})]
		"复利": return [_e("compound_equity", 1, -1, "", "本回合首次存股权时额外 +1 股权", {}, -1, "persistent")]
		"利息": return [_e("equity_interest", 1, -1, "", "持有≥2股权时，支付 1 股权获得 2 金币并补 1 字", {})]
		"炼金": return [_e("alchemy", 3, -1, "", "消耗全部股权：每点 +3 金币并补 1 字", {"per": 3})]
		"纯金": return [_e("pure_gold", 1, -1, "", "把本回合剩余临时资金转为正式金币", {})]
		"合金": return [_e("alloy", 6, -1, "", "获得 6 持久盾与 2 金币", {"gold": 2})]
		"铸币": return [_e("mint", 2, -1, "", "获得 2 金币，并在原格生成一枚临时【币】", {"gold": 2})]
		"再投资": return [_e("reinvest", 6, -1, "", "锁定最多 6 金币，下一场胜利后返还 2 倍", {"max": 6}, -1, "persistent")]
		"重金": return [_e("bounty", 12, T.ENEMY, "", "支付 5 金币悬赏，本回合击杀返 12，否则本金不返", {"cost": 5})]
		# ---- 热暴 P3 ----
		"爆冷": return [_e("cold_snap", 4, T.ENEMY, "", "4 伤 + 上回合每失 1 生命额外 2 伤，清空热度", {"per": 2})]
		"停火": return [_e("ceasefire", 1, -1, "", "本回合未造成敌伤则免疫敌方攻击", {}, -1, "persistent")]
		"放火": return [_e("ignite", 3, T.ENEMY, "", "敌方接下来 2 次行动各受 3+施放时热度 伤", {})]
		# ---- 连携 ----
		"电击": return [_e("electric_strike", 6, T.ENEMY, "", "造成 6 伤 + 2×储能", {"per": 2})]
		"火力": return [_e("fire_power", 6, T.ENEMY, "", "造成 6 伤 + 2×热度", {"per": 2})]
		"合力": return [_e("joint_force", 6, -1, "", "获得 6 临挡与 2 储能", {"energy": 2})]
		"连载": return [_e("serial", 6, -1, "", "本战每打出 3 种不同多字词，下一次攻击 +6 伤", {"bonus": 6}, -1, "persistent")]
		"反复": return [_e("repeat_zero", 1, -1, "", "本回合首次无效果单字出牌时，在原格补 1 字", {}, -1, "persistent")]
		# ---- 流转 P3 ----
		"清流": return [_e("clear_flow", 2, -1, "", "净化全部灼热并补 2 字", {})]
		"回购": return [_e("buyback", 3, T.DISCARD_GLYPH, "", "支付 3 金币，回收本回合消耗的 1 枚字到袋顶", {"cost": 3})]
		# ---- 空间新增词 ----
		"重力": return [_e("ability_gravity_always", 1, -1, "", "本战每次有效出字后自动全盘向下重力", {}, -1, "persistent")]
		"停电": return [_e("blackout", 0, -1, "", "彩蛋：停电，屏幕变黑；拖动连出【开灯】才能恢复", {})]
		"充电过热": return [_e("charge_overheat", 8, -1, "", "获得 8 储能 + 8 热度；本战此后每次出字后立即补满盘面", {"energy": 8, "heat": 8}, -1, "persistent")]
		"重铸": return [_e("recast_board", 0, -1, "", "把盘面上已有的字全部重新替换（己方字回袋重抽，敌方/临时字清除）", {})]
		"再铸": return [_e("recast_copy", 0, -1, "", "从弃字堆选一张，把它的临时复制放进指定空格（原牌留在弃字堆）", {})]
		"反转": return [_e("reverse_line", 0, -1, "", "选择一整行或一整列，倒转其 4 格（含空格与完整叠层）", {})]
		"合流": return [_e("merge_flow", 0, -1, "", "揭示字袋 1 枚 + 弃字堆指定 1 枚，按任选顺序放入两个相邻空格；无相邻空格则不移动", {})]
		"急停": return [_e("hard_stop", 0, -1, "", "清空热度并移除本回合溢热生成的灼热【热】（字袋/弃字堆/盘面），立即结束出字阶段", {})]
		"重复": return [_e("repeat_word", 0, -1, "", "开启后每回合第一次有效多字词再执行一次其即时效果（不重复消耗字；需支付的照常再付）", {}, -1, "persistent")]
		"防火": return [_e("fireproof", 0, -1, "", "本场持续：自己打出的灼热【热】不再扣血（仍占字袋、不被自动净化）", {}, -1, "persistent")]
		"防爆": return [_e("blastproof", 0, -1, "", "本场持续：被爆破/爆炸摧毁的己方实体字改为回字袋，每救回 1 枚 +1 持久盾", {}, -1, "persistent")]
		"合资": return [_e("joint_funding", 0, -1, "", "本场持续：支付金币发动词效时可用 2 储能抵 1 金币，允许混合支付", {}, -1, "persistent")]
		"分利": return [_e("profit_share", 0, -1, "", "本回合剩余时间，每当实际获得金币就额外获得等量储能", {})]
		"停息": return [_e("suspend", 0, -1, "", "立即结束出字阶段：清零全部热度，每 1 热度换 2 持久盾；敌人正常行动", {})]
		# ---- 盘面改造（设计负责人直接定义）----
		"转化": return [_e("transform_board", 5, T.BOARD_TILE, "", "随机揭示 5 枚实体字，选 1 枚，把一个盘面字定向改成它", {"reveal": 5})]
		"分化": return [_e("split_grow", 4, T.BOARD_TILE, "", "删除一个盘面字，在其上下左右的空格各生长一枚可组词的临时字（打出即消耗，不进字袋）", {"max": 4})]
		"强化": return [_e("empower_glyph", 0, -1, "", "选择字袋中一个字；本场它被打出时（单字或成词）额外触发其单字效果", {})]
		"炼化": return [_e("refine_remove", 3, -1, "", "热度 -3、获得 4 金币，并指定一张牌在本场战斗移出循环", {"heat": 3, "gold": 4})]
		"精炼": return [_e("refine_layer", 0, -1, "", "选择两个相同的己方字，本场它们一直重合（一格可重复使用，另一张回字袋）", {})]
		"精力": return [_e("vigor", 0, -1, "", "本回合每打出一种不同的多字词，下回合基础补字 +1", {}, -1, "persistent")]
	return []


func _build_words_from_ledger() -> void:
	var f := FileAccess.open(IMPORT.path_join("word_ledger_105.txt"), FileAccess.READ)
	if f == null:
		push_error("找不到 word_ledger_105.txt")
		return
	f.get_csv_line()
	var count := 0
	var implemented := 0
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 12 or row[1].is_empty():
			continue
		var word: String = row[1]
		if CUT_WORDS.has(word):
			continue
		count += 1
		var effects_list := _word_effects(word)
		var glyphs: Array[String] = []
		for i in word.length():
			var g := word.substr(i, 1)
			glyphs.append(g)
			_ensure_glyph(g)

		var w: WordData = WordDataS.new()
		w.id = "w%03d" % int(row[0])
		w.word = word
		w.glyphs = glyphs
		w.group = GROUP_OVERRIDES.get(word, row[3])
		w.interaction = INTERACTIONS.get(word, "")
		w.design_stage = row[4]
		w.effect_summary = row[5]
		w.priority = row[11]
		w.p25_implemented = row[7].strip_edges() == "是"
		w.implementation_delta = row[10]
		w.description = row[5]
		w.effects = _teffects(effects_list)
		w.implemented = not effects_list.is_empty()
		w.rarity = 1
		if w.implemented:
			implemented += 1
			w.effect_handler_id = effects_list[0].handler
			var req := 0
			var timing := "immediate"
			for e in effects_list:
				if e.target > req and e.target in [EffectDataS.Target.BOARD_TILE, EffectDataS.Target.BOARD_2X2, EffectDataS.Target.EMPTY_TILE, EffectDataS.Target.DISCARD_GLYPH, EffectDataS.Target.ENEMY_GLYPH]:
					req = e.target
				if e.timing != "immediate":
					timing = e.timing
			w.requires_target = req
			w.timing = timing
		_save(w, "%s/words/%s.tres" % [RES, w.id])
	f.close()
	print("  · 词：总账 %d 条，已实现 %d 条，待定 %d 条" % [count, implemented, count - implemented])


func _build_extra_words() -> void:
	# 彩蛋/设计负责人新增、不在总账 105 里的词
	var w: WordData = WordDataS.new()
	w.id = "extra_huohua"
	w.word = "火化"
	w.glyphs = _strs(["火", "化"])
	w.group = "彩蛋"
	w.design_stage = "设计负责人新增（彩蛋）"
	w.effect_summary = "彩蛋词：【火化】原地变成【骨灰】（无实际效果）"
	w.description = w.effect_summary
	w.priority = "彩蛋"
	w.effects = _teffects([_e("cremate", 0, -1, "", "【火化】原地变成【骨灰】两个字", {})])
	w.implemented = true
	w.effect_handler_id = "cremate"
	for g in w.glyphs:
		_ensure_glyph(g)
	_save(w, "%s/words/%s.tres" % [RES, w.id])
	print("  · 彩蛋词：火化（额外）")

	# 化合：融合两张相邻牌
	var w2: WordData = WordDataS.new()
	w2.id = "extra_huahe"
	w2.word = "化合"
	w2.glyphs = _strs(["合", "化"])
	w2.group = "空间"
	w2.design_stage = "设计负责人新增"
	w2.effect_summary = "选择两张相邻的己方牌融合成一个占 1 格的复合单位（本场有效；进出字袋/弃字堆不拆散）"
	w2.description = w2.effect_summary
	w2.priority = "空间"
	w2.effects = _teffects([_e("fuse_cards", 0, -1, "", "选择两张相邻的己方牌融合为一格（本场不可拆）", {})])
	w2.implemented = true
	w2.effect_handler_id = "fuse_cards"
	w2.interaction = "choose_fuse_pair"
	for g2 in w2.glyphs:
		_ensure_glyph(g2)
	_save(w2, "%s/words/%s.tres" % [RES, w2.id])
	print("  · 新增词：化合（额外）")

	# 精金：永久镀金
	_save(_extra("extra_jinjin", "精金", ["精", "金"], "经济", "choose_glyph_gild",
		"选择一枚己方实体字，将其永久镀金；此后它每次参与有效多字词获得 1 金币",
		_e("gild_glyph", 0, -1, "", "选择一枚己方字永久镀金", {})),
		"%s/words/extra_jinjin.tres" % RES)

	# 精铸：精准制造
	_save(_extra("extra_jingzhu", "精铸", ["精", "铸"], "流转", "choose_discard_place",
		"支付 3 金币，从弃字堆选一枚己方实体字，直接放进指定空格",
		_e("precision_place", 3, -1, "", "支付 3 金币，把弃字堆中的一枚字放进指定空格", {})),
		"%s/words/extra_jingzhu.tres" % RES)

	# 精分：彩蛋
	_save(_extra("extra_jingfen", "精分", ["精", "分"], "彩蛋", "",
		"彩蛋词：本回合内敌人攻击打自己、你的攻击也打自己",
		_e("split_mind", 0, -1, "", "本回合敌我攻击都打向自己", {})),
		"%s/words/extra_jingfen.tres" % RES)
	print("  · 新增词：精金/精铸/精分（额外）")

	# 开灯：停电彩蛋的恢复词
	_save(_extra("extra_kaideng", "开灯", ["开", "灯"], "彩蛋", "",
		"彩蛋词：来电了",
		_e("lights_on", 0, -1, "", "来电了", {})),
		"%s/words/extra_kaideng.tres" % RES)
	print("  · 彩蛋词：开灯（额外）")


func _extra(id: String, word: String, glyphs: Array, group: String, interaction: String, desc: String, effect: EffectData) -> WordData:
	var w: WordData = WordDataS.new()
	w.id = id
	w.word = word
	w.glyphs = _strs(glyphs)
	w.group = group
	w.design_stage = "设计负责人新增"
	w.effect_summary = desc
	w.description = desc
	w.priority = group
	w.effects = _teffects([effect])
	w.implemented = true
	w.effect_handler_id = effect.handler
	w.interaction = interaction
	for g in w.glyphs:
		_ensure_glyph(g)
	return w


# ---------------------------------------------------------------- 敌人
func _move(kind: int, title: String, damage := 0, hits := 1, block := 0, status := "", stacks := 0, inject := 0, pollution := "", desc := "") -> EnemyMoveData:
	var m: EnemyMoveData = EnemyMoveDataS.new()
	m.kind = kind
	m.title = title
	m.damage = damage
	m.hits = hits
	m.block = block
	m.status_id = status
	m.status_stacks = stacks
	m.inject_count = inject
	m.pollution_id = pollution
	m.description = desc
	return m


func _typed_moves(list: Array) -> Array[EnemyMoveData]:
	var out: Array[EnemyMoveData] = []
	for m in list:
		out.append(m)
	return out


func _make_enemy(id: String, name: String, glyph: String, hp: int, color: String, moves: Array, boss := false, elite := false) -> EnemyData:
	var e: EnemyData = EnemyDataS.new()
	e.id = id
	e.name = name
	e.glyph = glyph
	e.max_hp = hp
	e.accent = Color(color)
	e.moves = _typed_moves(moves)
	e.is_boss = boss
	e.is_elite = elite
	_save(e, "%s/enemies/%s.tres" % [RES, id])
	return e


func _build_enemies() -> void:
	var K := EnemyMoveDataS.Kind
	_make_enemy("ink_spirit", "墨灵", "墨", 30, "3c4a6b", [
		_move(K.ATTACK, "溅墨", 6),
		_move(K.INJECT, "落墨", 0, 1, 0, "", 0, 1, "rush"),
		_move(K.BLOCK, "结茧", 0, 1, 5),
	])
	_make_enemy("paper_guard", "纸卫", "纸", 36, "8a7a5a", [
		_move(K.BLOCK, "覆纸", 0, 1, 6),
		_move(K.ATTACK, "割", 9),
		_move(K.INJECT, "糊", 0, 1, 0, "", 0, 1, "block"),
	])
	_make_enemy("ember_imp", "焦火", "焦", 34, "b0522e", [
		_move(K.MULTI, "连焰", 4, 2),
		_move(K.INJECT, "落灰", 0, 1, 0, "", 0, 1, "scorch"),
	])
	_make_enemy("rust_scribe", "锈笔", "锈", 40, "6f7a3f", [
		_move(K.DEBUFF, "污墨", 0, 1, 0, "vulnerable", 1),
		_move(K.ATTACK, "刺", 8),
		_move(K.INJECT, "蚀文", 0, 1, 0, "", 0, 1, "rush"),
	])
	_make_enemy("iron_seal", "铁画", "铁", 52, "4a4a52", [
		_move(K.ATTACK_BLOCK, "重压", 7, 1, 6),
		_move(K.ATTACK, "横扫", 11),
	], false, true)
	_make_enemy("bronze_seal", "铜印", "铜", 48, "9a7838", [
		_move(K.BLOCK, "铸壁", 0, 1, 8),
		_move(K.ATTACK, "印击", 10),
		_move(K.INJECT, "蚀版", 0, 1, 0, "", 0, 2, "block"),
	])
	_make_enemy("boss_word_demon", "字魔", "魔", 78, "7a3b3b", [
		_move(K.ATTACK, "撕字", 9),
		_move(K.BLOCK, "结阵", 0, 1, 8),
		_move(K.INJECT, "散字", 0, 1, 0, "", 0, 2, "rush"),
	], true)
	_make_enemy("boss_lead_plate", "铅版", "铅", 112, "3a3a44", [
		_move(K.ATTACK_BLOCK, "压印", 10, 1, 8),
		_move(K.MULTI, "连铸", 6, 2),
		_move(K.INJECT, "蚀版", 0, 1, 0, "", 0, 3, "block"),
	], true)
	_make_enemy("boss_chaos_press", "混铅海", "沌", 150, "2c2c3a", [
		_move(K.ATTACK, "吞字", 13),
		_move(K.MULTI, "乱版", 7, 3),
		_move(K.BLOCK, "封泥", 0, 1, 12),
		_move(K.INJECT, "蚀海", 0, 1, 0, "", 0, 4, "scorch"),
	], true)


func Database_enemy(id: String) -> EnemyData:
	return load("%s/enemies/%s.tres" % [RES, id])


# ---------------------------------------------------------------- 幕与节点（沿用 V0.3 三幕八节点）
func _node(order: int, type: int, title: String, desc: String, enemies: Array, branch := false) -> MapNodeData:
	var n: MapNodeData = MapNodeDataS.new()
	n.order = order
	n.type = type
	n.title = title
	n.description = desc
	var typed: Array[EnemyData] = []
	for e in enemies:
		typed.append(e)
	n.enemies = typed
	n.is_optional_branch = branch
	return n


func _typed_nodes(list: Array) -> Array[MapNodeData]:
	var out: Array[MapNodeData] = []
	for n in list:
		out.append(n)
	return out


func _build_acts() -> void:
	var T := MapNodeDataS.Type
	var battles := {
		1: ["ink_spirit", "paper_guard", "ember_imp"],
		2: ["rust_scribe", "bronze_seal", "paper_guard"],
		3: ["ember_imp", "rust_scribe", "bronze_seal"],
	}
	var elites := {1: "iron_seal", 2: "bronze_seal", 3: "iron_seal"}
	var bosses := {1: "boss_word_demon", 2: "boss_lead_plate", 3: "boss_chaos_press"}
	var titles := {1: "第一幕 · 起步", 2: "第二幕 · 成型", 3: "第三幕 · 兑现"}
	var themes := {
		1: "从少量高连通字开始，确立主方向。",
		2: "从一个词扩展到联动体系，敌人开始污染盘面。",
		3: "在压力下完成联动与收尾。",
	}
	for act_i in [1, 2, 3]:
		var act: ActData = ActDataS.new()
		act.index = act_i
		act.title = titles[act_i]
		act.theme = themes[act_i]
		var pool: Array = []
		for eid in battles[act_i]:
			pool.append(Database_enemy(eid))
		var nodes: Array = []
		nodes.append(_node(1, T.BATTLE, "初试", "教授组词与单字的取舍", [pool[0]]))
		nodes.append(_node(2, T.BATTLE, "第二条线", "提供第一条新联动", [pool[1]]))
		nodes.append(_node(3, T.EVENT, "途中小憩", "叙事与风险、资源取舍", []))
		nodes.append(_node(4, T.BATTLE, "机制之敌", "开始应对机制性敌人", [pool[2]]))
		nodes.append(_node(5, T.SHOP, "市集", "购字、复制、删字或治疗", []))
		nodes.append(_node(6, T.FORK, "岔路", "精英（高收益）或事件（较安全）", [Database_enemy(elites[act_i])], true))
		nodes.append(_node(7, T.REST, "休整", "治疗 / 删字 / 修饰，三选一", []))
		nodes.append(_node(8, T.BOSS, "幕末首领", "验证整套构筑", [Database_enemy(bosses[act_i])]))
		act.nodes = _typed_nodes(nodes)
		_save(act, "%s/acts/act_%d.tres" % [RES, act_i])


# ---------------------------------------------------------------- 初始字袋 / 规则
func _build_starter_deck() -> void:
	var entries := [
		["击", 2], ["防", 2], ["回", 2], ["反", 1], ["破", 1],
		["重", 1], ["流", 1], ["连", 1], ["御", 1],
	]
	var deck: StarterDeckData = StarterDeckDataS.new()
	deck.id = "v03"
	deck.name = "初始字袋 V0.3（12 枚 / 9 种）"
	deck.opening_draw = 10
	deck.turn_draw = 3
	var typed: Array[DeckEntryData] = []
	for e in entries:
		var de: DeckEntryData = DeckEntryDataS.new()
		de.character = _char_by_glyph.get(e[0])
		de.count = e[1]
		typed.append(de)
	deck.entries = typed
	_save(deck, "%s/starter_decks/v03.tres" % RES)


func _build_rules() -> void:
	var r: BattleRules = BattleRulesS.new()
	r.board_size = 4
	r.opening_draw = 10
	r.turn_draw = 3
	r.player_max_hp = 60
	r.starting_gold = 6
	r.plays_per_turn = 0   # V0.2：无固定出字次数上限
	r.heat_capacity = 10
	_save(r, "%s/rules/default_rules.tres" % RES)
