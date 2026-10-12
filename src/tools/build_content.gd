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
const CUT_GLYPHS := ["纯", "攻", "剑", "雷", "毒", "愈", "却"]
const CUT_WORDS := ["纯化", "纯金", "纯利", "精纯", "强力反击", "冷却"]

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
		{"id": "heart_corrosion", "name": "心蚀", "glyph": "蚀", "kind": 1, "color": "8a4a63", "decay": 0,
		 "desc": "每回合损失等量层数的生命（不衰减）。"},
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
		"护": return {"h": "ability_guard_inject", "a": 1, "note": "下次敌方塞字减少 1 个"}
		"御": return {"h": "guard_reduce", "a": 1, "note": "本回合每次受伤 -1"}
		"回": return {"h": "replace_self", "note": "在原位置随机换一枚字"}
		"重": return {"h": "gravity", "target": EffectDataS.Target.BOARD, "note": "字盘按列向下重力"}
		"心": return {"h": "heal", "a": 1, "note": "回复 1 生命"}
		"清": return {"h": "cleanse_adjacent", "target": EffectDataS.Target.BOARD_TILE, "note": "净化一个四邻污染标记（保留字与所有权）"}
		"反": return {"h": "damage", "a": 2, "note": "占位：造成 2 伤害（用户未确认）"}
		"甲": return {"h": "ability_armor_plating", "a": 1, "note": "每回合获得 1 点格挡，格挡被击穿则碎裂"}
		"盾": return {"h": "block_persist", "a": 3, "note": "获得 3 点持久盾"}
		"破": return {"h": "damage", "a": 3, "note": "占位：造成 3 伤害（单字用途未定）"}
		"再": return {"h": "repeat_last", "note": "单字：重复上一个词/字的最后一个字（临时）"}
		"左": return {"h": "gravity_left", "target": EffectDataS.Target.BOARD, "note": "字盘按行向左重力"}
		"右": return {"h": "gravity_right", "target": EffectDataS.Target.BOARD, "note": "字盘按行向右重力"}
		# 资源 / 主题字（设计负责人补充）
		"火": return {"h": "heat", "a": 1, "note": "热度 +1"}
		"热": return {"h": "heat", "a": 2, "note": "热度 +2"}
		"冷": return {"h": "heat", "a": -2, "note": "热度 -2"}
		"电": return {"h": "energy", "a": 1, "note": "储能 +1"}
		"蓄": return {"h": "energy", "a": 2, "note": "储能 +2"}
		"金": return {"h": "gold", "a": 1, "note": "获得 1 金币"}
		"力": return {"h": "apply_status_self", "status": "strength", "a": 1, "note": "获得 1 层强力"}
		"流": return {"h": "draw_bonus_next", "a": 1, "note": "下回合多抽 1 字"}
		"蚀": return {"h": "damage", "a": 2, "note": "对敌造成 2 伤害"}
		# 下一批（复合 / 独立定位）
		"充": return {"effects": [{"h": "energy", "a": 1, "note": "储能 +1"}, {"h": "draw_random", "a": 1, "note": "随机补 1 字"}], "note": "储能 +1，随机补 1 字"}
		"爆": return {"effects": [{"h": "damage", "a": 2, "note": "造成 2 伤害"}, {"h": "heat", "a": 1, "note": "热度 +1"}], "note": "造成 2 伤，热度 +1"}
		"资": return {"h": "temp_funds", "a": 2, "note": "获得 2 点临时资金（本回合有效）"}
		"收": return {"h": "draw_random", "a": 1, "note": "随机补 1 字"}
		"障": return {"h": "block_temp", "a": 2, "note": "获得 2 点临时格挡"}
	return {}


func _spec_effect(spec: Dictionary) -> EffectData:
	return ContentBuild.e(spec.get("h", ""), int(spec.get("a", 0)), int(spec.get("target", -1)), spec.get("status", ""), spec.get("note", ""), spec.get("args", {}))

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
		["左", "zuo", "zuo", ["space"], 1, false],
		["右", "you", "you", ["space"], 1, false],
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
		["过", "guo", "guo", ["space"], 1, false, "可单字打出（无触发效果）；连线时【过】可被穿过，扩大连接面积（桥接）。"],
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
		["心", "xin", "xin", ["utility", "heal"], 1, false],
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
		_make_character(d[0], d[1], d[2], d[3], d[4], d[5], false, str(d[6]) if d.size() > 6 else "")

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
		var list: Array = spec.get("effects", [spec])
		var effs: Array = []
		for s in list:
			effs.append(_spec_effect(s))
		c.solo_effects = _teffects(effs)
		c.solo_handler = str(c.solo_effects[0].handler) if not c.solo_effects.is_empty() else ""
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
		var effects_list := ContentBuild.word_effects(word)
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
				if e.target > req and e.target in [EffectDataS.Target.BOARD_TILE, EffectDataS.Target.BOARD_2X2, EffectDataS.Target.BOARD_3X3, EffectDataS.Target.BOARD_ROW, EffectDataS.Target.EMPTY_TILE, EffectDataS.Target.DISCARD_GLYPH, EffectDataS.Target.ENEMY_GLYPH]:
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
	w.effects = _teffects([ContentBuild.e("cremate", 0, -1, "", "【火化】原地变成【骨灰】两个字", {})])
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
	w2.effects = _teffects([ContentBuild.e("fuse_cards", 0, -1, "", "选择两张相邻的己方牌融合为一格（本场不可拆）", {})])
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
		ContentBuild.e("gild_glyph", 0, -1, "", "选择一枚己方字永久镀金", {})),
		"%s/words/extra_jinjin.tres" % RES)

	# 精铸：精准制造
	_save(_extra("extra_jingzhu", "精铸", ["精", "铸"], "流转", "choose_discard_place",
		"支付 3 金币，从弃字堆选一枚己方实体字，直接放进指定空格",
		ContentBuild.e("precision_place", 3, -1, "", "支付 3 金币，把弃字堆中的一枚字放进指定空格", {})),
		"%s/words/extra_jingzhu.tres" % RES)

	# 精分：彩蛋
	_save(_extra("extra_jingfen", "精分", ["精", "分"], "彩蛋", "",
		"彩蛋词：本回合内敌人攻击打自己、你的攻击也打自己",
		ContentBuild.e("split_mind", 0, -1, "", "本回合敌我攻击都打向自己", {})),
		"%s/words/extra_jingfen.tres" % RES)
	print("  · 新增词：精金/精铸/精分（额外）")

	# 开灯：停电彩蛋的恢复词
	_save(_extra("extra_kaideng", "开灯", ["开", "灯"], "彩蛋", "",
		"彩蛋词：来电了",
		ContentBuild.e("lights_on", 0, -1, "", "来电了", {})),
		"%s/words/extra_kaideng.tres" % RES)
	print("  · 彩蛋词：开灯（额外）")

	# 方向与空间：左 / 右 / 左右 / 左转 / 右转 / 左击 / 右击（设计负责人新增）
	_save(_extra_list("extra_zuoyou", "左右", ["左", "右"], "空间", "choose_row_pair",
		"选择同一行里的任意两个格子，交换它们的位置",
		[ContentBuild.e("swap_cells", 0, -1, "", "交换选中的两个格子", {})], -1),
		"%s/words/extra_zuoyou.tres" % RES)
	_save(_extra_list("extra_zuozhuan", "左转", ["左", "转"], "空间", "",
		"选择一块 3×3 区域，将区域逆时针旋转 90°",
		[ContentBuild.e("rotate_3x3", 0, EffectDataS.Target.BOARD_3X3, "", "3×3 区域逆时针旋转 90°", {"dir": -1})]),
		"%s/words/extra_zuozhuan.tres" % RES)
	_save(_extra_list("extra_youzhuan", "右转", ["右", "转"], "空间", "",
		"选择一块 3×3 区域，将区域顺时针旋转 90°",
		[ContentBuild.e("rotate_3x3", 0, EffectDataS.Target.BOARD_3X3, "", "3×3 区域顺时针旋转 90°", {"dir": 1})]),
		"%s/words/extra_youzhuan.tres" % RES)
	_save(_extra_list("extra_zuoji", "左击", ["左", "击"], "攻击", "",
		"造成 6 点伤害，再选择一行向左循环移动一格",
		[ContentBuild.e("damage", 6, -1, "", "造成 6 点伤害", {}),
		 ContentBuild.e("shift_row", 0, EffectDataS.Target.BOARD_ROW, "", "再选择一行向左循环移动一格", {"dir": -1})],
		EffectDataS.Target.BOARD_ROW),
		"%s/words/extra_zuoji.tres" % RES)
	_save(_extra_list("extra_youji", "右击", ["右", "击"], "攻击", "",
		"造成 6 点伤害，再选择一行向右循环移动一格",
		[ContentBuild.e("damage", 6, -1, "", "造成 6 点伤害", {}),
		 ContentBuild.e("shift_row", 0, EffectDataS.Target.BOARD_ROW, "", "再选择一行向右循环移动一格", {"dir": 1})],
		EffectDataS.Target.BOARD_ROW),
		"%s/words/extra_youji.tres" % RES)
	print("  · 新增词：左右/左转/右转/左击/右击（额外）")

	# 字网加边 · 第一批（方向 / 空间 / 蓄放 / 流转）
	_save(_extra_list("extra_zhuansu", "转速", ["转", "速"], "空间", "",
		"选择一块 2×2 区域，点「发动」连续旋转；最多 3 次，第 2、3 次各增加 1 热度",
		[ContentBuild.e("rotate_repeat", 0, EffectDataS.Target.BOARD_2X2, "", "选择 2×2，点「发动」每次旋转一次（最多 3 次）", {})]),
		"%s/words/extra_zhuansu.tres" % RES)
	_save(_extra_list("extra_nengli", "能力", ["能", "力"], "蓄放", "",
		"本场持续：每成功打出一个三字及以上的词，额外随机补 1 字",
		[ContentBuild.e("ability_longword_draw", 1, -1, "", "本场持续：3 字及以上词各补 1 字", {}, -1, "persistent")]),
		"%s/words/extra_nengli.tres" % RES)
	_save(_extra_list("extra_dianneng", "电能", ["电", "能"], "蓄放", "",
		"本场持续：每累计消耗 2 点储能，就在随机空格生成一枚一次性临时【电】",
		[ContentBuild.e("ability_electric_material", 1, -1, "", "本场持续：每消耗 2 储能生成临时【电】", {}, -1, "persistent")]),
		"%s/words/extra_dianneng.tres" % RES)
	_save(_extra_list("extra_xure", "蓄热", ["蓄", "热"], "蓄放", "",
		"本场持续：回合结束时热度 -2，每降低 1 点获得 1 储能",
		[ContentBuild.e("ability_heat_to_energy", 1, -1, "", "本场持续：回合结束热度 -2，每点转 1 储能", {}, -1, "persistent")]),
		"%s/words/extra_xure.tres" % RES)
	_save(_extra_list("extra_guoleng", "过冷", ["过", "冷"], "蓄放", "",
		"立即清空热度；下一次本应获得的热度改为每点 +2 持久盾，且不生成过热污染",
		[ContentBuild.e("overcool", 0, -1, "", "清空热度；下次获得的热度转为每点 +2 持久盾", {})]),
		"%s/words/extra_guoleng.tres" % RES)
	_save(_extra_list("extra_jizhuan", "急转", ["急", "转"], "空间", "choose_any_pair",
		"选择盘上任意两个格子交换位置，并增加 2 热度",
		[ContentBuild.e("swap_cells", 0, -1, "", "交换选中的两格", {}),
		 ContentBuild.e("heat", 2, -1, "", "热度 +2", {})]),
		"%s/words/extra_jizhuan.tres" % RES)
	_save(_extra_list("extra_jiliu", "急流", ["急", "流"], "流转", "choose_line",
		"选择一行或一列：其中的己方实体字洗回抽字袋，再向原位置随机补入相同数量的字",
		[ContentBuild.e("reshuffle_line", 0, -1, "", "选一行/列：洗回实体字并原位随机补字", {})]),
		"%s/words/extra_jiliu.tres" % RES)
	_save(_extra_list("extra_huoji", "火急", ["火", "急"], "流转", "choose_place_two",
		"立即从字袋抽 2 字并增加 2 热度；揭示后由玩家逐枚指定空格放入",
		[ContentBuild.e("place_two", 0, -1, "", "把揭示的 2 枚字放进指定空格", {}),
		 ContentBuild.e("heat", 2, -1, "", "热度 +2", {})]),
		"%s/words/extra_huoji.tres" % RES)
	_save(_extra_list("extra_shoufu", "收复", ["收", "复"], "流转", "choose_recover_two",
		"从弃字堆选最多两枚己方实体字，直接放入字盘上两个彼此相邻的空格",
		[ContentBuild.e("recover_two", 0, -1, "", "从弃字堆放回最多 2 枚到相邻空格", {})]),
		"%s/words/extra_shoufu.tres" % RES)
	print("  · 新增词：转速/能力/电能/蓄热/过冷/急转/急流/火急/收复（第一批）")

	# 字网加边 · 第二批（蓄放 / 流转 / 经济）
	_save(_extra_list("extra_liusu", "流速", ["流", "速"], "流转", "",
		"选定一行：本回合每次打出涉及该行的词，都立即从字袋补回该行被腾出的空格",
		[ContentBuild.e("flow_row", 0, EffectDataS.Target.BOARD_ROW, "", "选定一行：本回合该行腾出的空格立即补字", {})]),
		"%s/words/extra_liusu.tres" % RES)
	_save(_extra_list("extra_huosu", "火速", ["火", "速"], "流转", "",
		"把盘面补到至少 12 字；每实际补入 1 字，增加 1 热度",
		[ContentBuild.e("fill_board_heat", 0, -1, "", "补至 12 字，每枚 +1 热度", {})]),
		"%s/words/extra_huosu.tres" % RES)
	_save(_extra_list("extra_jiaji", "加急", ["加", "急"], "流转", "",
		"立即从字袋补入 2 枚字（候选）",
		[ContentBuild.e("next_draw_bonus_two", 0, -1, "", "立即补 2 字", {})]),
		"%s/words/extra_jiaji.tres" % RES)
	_save(_extra_list("extra_xuleng", "蓄冷", ["蓄", "冷"], "蓄放", "",
		"获得一次性状态：下次过热时抵消最多 4 点污染【热】的溢出量",
		[ContentBuild.e("overheat_shield", 0, -1, "", "下次过热抵消 4 点污染【热】", {})]),
		"%s/words/extra_xuleng.tres" % RES)
	_save(_extra_list("extra_lengre", "冷热", ["冷", "热"], "蓄放", "",
		"立即消耗当前全部热度，每点转化为 2 点持久盾",
		[ContentBuild.e("heat_to_persist_block", 0, -1, "", "消耗全部热度，每点 +2 持久盾", {})]),
		"%s/words/extra_lengre.tres" % RES)
	_save(_extra_list("extra_chaoneng", "超能", ["超", "能"], "蓄放", "",
		"下一条三字及以上的词：可消耗储能，每消耗 1 点就在被用字的原格保留一个临时复制层",
		[ContentBuild.e("next_copy_layer", 0, -1, "", "下一条 3+ 字词可耗储能保留临时复制层", {})]),
		"%s/words/extra_chaoneng.tres" % RES)
	_save(_extra_list("extra_chaonengli", "超能力", ["超", "能", "力"], "蓄放", "",
		"本回合下一次已启动的持续能力触发时，效果结算两遍",
		[ContentBuild.e("double_next_ability", 0, -1, "", "下一次持续能力触发结算两遍", {})]),
		"%s/words/extra_chaonengli.tres" % RES)
	_save(_extra_list("extra_shouhui", "收回", ["收", "回"], "流转", "choose_recover_to_bag",
		"把盘上一枚己方实体字置于抽字袋顶，再从弃字堆选一枚放到原格",
		[ContentBuild.e("recover_to_bag", 0, -1, "", "盘面字回袋顶，弃字补入原格", {})]),
		"%s/words/extra_shouhui.tres" % RES)
	_save(_extra_list("extra_shoufang", "收放", ["收", "放"], "空间", "choose_move",
		"选择盘上一枚字或完整叠层，移动到任意空格，不交换其他字",
		[ContentBuild.e("move_cell", 0, -1, "", "把选中字移动到空格", {})]),
		"%s/words/extra_shoufang.tres" % RES)
	_save(_extra_list("extra_shouxi", "收息", ["收", "息"], "经济", "",
		"本回合每次花金币发动词效，同时获得等额持久盾",
		[ContentBuild.e("gold_to_shield", 0, -1, "", "本回合花金币附等额持久盾", {})]),
		"%s/words/extra_shouxi.tres" % RES)
	_save(_extra_list("extra_jiashou", "加收", ["加", "收"], "经济", "",
		"本回合敌人每往字盘塞入一枚污染字，获得 2 金币；污染照常存在",
		[ContentBuild.e("inject_bounty", 0, -1, "", "本回合敌人注入污染字获得金币", {})]),
		"%s/words/extra_jiashou.tres" % RES)
	_save(_extra_list("extra_dianli", "电力", ["电", "力"], "蓄放", "",
		"本场持续：每次行列位移后，可消耗 1 储能额外再位移一次",
		[ContentBuild.e("instant_power", 0, -1, "", "本场持续：位移后可耗 1 储能再位移", {}, -1, "persistent")]),
		"%s/words/extra_dianli.tres" % RES)
	_save(_extra_list("extra_dianre", "电热", ["电", "热"], "蓄放", "",
		"消耗当前全部储能，每点转为 1 热度与 3 点临挡（可能产生过热污染）",
		[ContentBuild.e("energy_to_heat_block", 0, -1, "", "储能转热度与临挡", {})]),
		"%s/words/extra_dianre.tres" % RES)
	_save(_extra_list("extra_huodian", "火电", ["火", "电"], "蓄放", "",
		"消耗当前全部热度，每 2 点获得 1 储能，并造成一次 5 点伤害",
		[ContentBuild.e("heat_to_energy_damage", 0, -1, "", "热度转储能并造成 5 伤", {})]),
		"%s/words/extra_huodian.tres" % RES)
	_save(_extra_list("extra_huore", "火热", ["火", "热"], "蓄放", "",
		"本场持续：每出现一枚污染【热】，就对敌人造成一次 5 点伤害",
		[ContentBuild.e("heat_pollution_damage", 0, -1, "", "本场持续：污染【热】造成 5 伤", {}, -1, "persistent")]),
		"%s/words/extra_huore.tres" % RES)
	_save(_extra_list("extra_fudian", "复电", ["复", "电"], "蓄放", "",
		"恢复上一条储能消耗词花费的一半储能，向下取整",
		[ContentBuild.e("refund_energy_half", 0, -1, "", "恢复最近一次储能花费的一半", {})]),
		"%s/words/extra_fudian.tres" % RES)
	_save(_extra_list("extra_liuhuo", "流火", ["流", "火"], "流转", "",
		"将盘上所有污染【热】洗回抽字袋，再冷却 2 点热度；腾出的空间保留",
		[ContentBuild.e("wash_heat", 0, -1, "", "洗回污染【热】并冷却 2 点", {})]),
		"%s/words/extra_liuhuo.tres" % RES)
	print("  · 新增词：流速/火速/加急/蓄冷/冷热/超能/超能力/收回/收放/收息/加收/电力/电热/火电/火热/复电/流火（第二批）")

	# 字网加边 · 第三批（清空字盘，每枚 5 伤；先清空再消耗，超/重自身也计入）
	_save(_extra_list("extra_chaozhong", "超重", ["超", "重"], "空间", "",
		"清空整个字盘，每个被清空的字造成 5 伤（己方字进弃字堆，敌方/临时字清除）",
		[ContentBuild.e("clear_board", 5, -1, "", "清空整个字盘，每个被清空的字造成 5 伤（己方字进弃字堆，敌方/临时字清除）", {}, -1, "immediate", true)]),
		"%s/words/extra_chaozhong.tres" % RES)
	print("  · 新增词：超重（第三批）")

	# 心系（设计负责人新增）
	_save(_extra_list("extra_zhongxin", "重心", ["重", "心"], "空间", "",
		"选择一个字，让所有字向它聚拢（冲突优先左上）",
		[ContentBuild.e("converge", 0, EffectDataS.Target.BOARD_TILE, "", "选择一个字，让所有字向它聚拢（冲突优先左上）", {})]),
		"%s/words/extra_zhongxin.tres" % RES)
	_save(_extra_list("extra_xinli", "心力", ["心", "力"], "连携", "",
		"能力牌：每打出一颗【心】，叠加一层心力；心力可抵挡一次致命伤害",
		[ContentBuild.e("ability_heart_power", 1, -1, "", "能力牌：每打出一颗【心】叠加一层心力，可抵挡一次致命伤害", {}, -1, "persistent")]),
		"%s/words/extra_xinli.tres" % RES)
	_save(_extra_list("extra_xinji", "心急", ["心", "急"], "流转", "",
		"补满盘面，下回合基础补字 -3",
		[ContentBuild.e("fill_board_full", 0, -1, "", "补满盘面", {}),
			ContentBuild.e("draw_penalty_next", 3, -1, "", "下回合基础补字 -3", {})]),
		"%s/words/extra_xinji.tres" % RES)
	_save(_extra_list("extra_xinshi", "心蚀", ["心", "蚀"], "连携", "",
		"给敌人叠加 4 层【心蚀】：每回合损失等量层数的生命",
		[ContentBuild.e("apply_status_enemy", 4, EffectDataS.Target.ENEMY, "heart_corrosion", "给敌人叠加 4 层【心蚀】", {})]),
		"%s/words/extra_xinshi.tres" % RES)
	_save(_extra_list("extra_xinlianxin", "心连心", ["心", "连", "心"], "空间", "",
		"将你的生命上限与当前生命都和敌人平均（上限整场有效）",
		[ContentBuild.e("heart_link", 0, EffectDataS.Target.ENEMY, "", "生命上限与当前生命都和敌人平均", {})]),
		"%s/words/extra_xinlianxin.tres" % RES)
	print("  · 新增词：重心/心力/心急/心蚀/心连心（心系）")

	# 过系（设计负责人新增）
	_save(_extra_list("extra_guofen", "过分", ["过", "分"], "连携", "",
		"造成 6 伤；本场每再打出一次【过分】，就重演之前所有【过分】的伤害（第 N 次共 6×N 伤）",
		[ContentBuild.e("overdo", 6, EffectDataS.Target.ENEMY, "", "造成 6 伤，并重演本场之前所有【过分】的伤害", {})]),
		"%s/words/extra_guofen.tres" % RES)
	print("  · 新增词：过分（过系）")

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


func _extra_list(id: String, word: String, glyphs: Array, group: String, interaction: String, desc: String, effects: Array, requires_target := -1) -> WordData:
	var w: WordData = WordDataS.new()
	w.id = id
	w.word = word
	w.glyphs = _strs(glyphs)
	w.group = group
	w.design_stage = "设计负责人新增"
	w.effect_summary = desc
	w.description = desc
	w.priority = group
	w.effects = _teffects(effects)
	w.implemented = true
	w.effect_handler_id = effects[0].handler
	w.interaction = interaction
	if requires_target >= 0:
		w.requires_target = requires_target
	else:
		var req := 0
		for e in effects:
			if e.target in [EffectDataS.Target.BOARD_TILE, EffectDataS.Target.BOARD_2X2, EffectDataS.Target.BOARD_3X3, EffectDataS.Target.BOARD_ROW, EffectDataS.Target.EMPTY_TILE, EffectDataS.Target.DISCARD_GLYPH, EffectDataS.Target.ENEMY_GLYPH]:
				req = e.target
		w.requires_target = req
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
