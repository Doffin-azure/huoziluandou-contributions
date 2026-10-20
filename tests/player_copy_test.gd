extends Node
## 玩家文案检查：完整覆盖、简洁、无程序术语、数值绑定，及关键机制边界。
var checks := 0
var failures := 0
const FORBIDDEN := ["实体", "兑现", "预算", "正价", "当前配置", "〔见", "handler", "UID", "P23", "未定稿"]

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[player_copy_test] " + message)

func readable(text: String, limit: int) -> bool:
	if text.is_empty() or text.length() > limit or text.contains("{"): return false
	for term in FORBIDDEN:
		if text.contains(term): return false
	return true

func _ready() -> void:
	check(BattleText.WORDS.size() == Database.words.size(), "全部词语都有玩家文案")
	check(BattleText.CHARACTERS.size() == Database.characters.size(), "全部单字都有玩家文案")
	GameState.start_new_run("v03")
	for card in GameState.deck:
		check(card.data.description == BattleText.character(card.data), "实际起始字袋也使用新说明：" + card.glyph())
	var review := {"words": [], "characters": [], "terms": [], "statuses": [], "pollutions": [], "enemies": []}
	for word in Database.words.values():
		var full: String = word.describe()
		var brief := EffectGlossary.brief(word)
		check(readable(full, 110), "完整词效清晰且不超过110字：" + word.word + " / " + full)
		check(readable(brief, 65), "战斗短说明不超过65字：" + word.word + " / " + brief)
		check(full == BattleText.word(word), "玩家文案已接入真实数据库：" + word.word)
		review.words.append({"word": word.word, "brief": brief, "full": full})
	for data in Database.characters.values():
		check(readable(data.description, 80), "单字说明简明：" + data.glyph)
		review.characters.append({"glyph": data.glyph, "text": data.description})
	for key in EffectGlossary.ENTRIES:
		var info := EffectGlossary.entry("term:" + str(key))
		check(readable(info.text, 120), "名词解释简明：" + str(key))
		review.terms.append(info)
	for id in Database.statuses:
		var info := EffectGlossary.entry("status:" + str(id))
		check(readable(info.text, 120), "状态说明简明：" + str(id))
		review.statuses.append(info)
	for data in Database.pollutions.values():
		check(readable(data.description, 100) and not data.description.contains("失去0") and not data.description.contains("减少0"), "污染不重复无效的0值：" + data.name)
		review.pollutions.append({"title": data.name, "text": data.description})
	for data in Database.enemies.values():
		check(readable(data.description, 150), "怪物说明无程序术语：" + data.name + " / " + data.description)
		review.enemies.append({"title": data.name, "text": data.description})
	# 默认数值相同的不同效果，必须绑定各自参数，不能用字符串替换猜测。
	var word := Database.get_word_by_glyphs_string("分心").duplicate(true) as WordData
	for i in word.effects.size(): word.effects[i].amount = i + 5
	check(BattleText.word(word) == "补5字，造成6伤害，获得7持久盾，回复8生命。", "同为默认1的四项数值独立更新")
	word = Database.get_word_by_glyphs_string("充电过热").duplicate(true) as WordData
	word.effects[0].args.energy = 11
	word.effects[0].args.heat = 6
	check(BattleText.word(word).contains("11储能、6热度"), "参数相同默认值不互相误替换")
	word = Database.get_word_by_glyphs_string("超载").duplicate(true) as WordData
	word.effects[0].amount = 2
	word.effects[1].amount = 9
	check(BattleText.word(word).contains("热度+9，获得2层"), "层数和热度分别绑定")
	var fold := Combatant.new("折页蛾", 32, false)
	fold.enemy_data = Database.get_enemy("fold_moth")
	check(EnemyMechanics.marker_name(fold, "签") == "折页签" and EnemyMechanics.marker_description(fold, "签").contains("单纯移动无效"), "普通签按来源命名，写明移动不解签")
	fold.enemy_data = Database.get_enemy("proof_boss")
	check(EnemyMechanics.marker_description(fold, "红").contains("移动无效") and EnemyMechanics.marker_description(fold, "蓝").contains("移动此字都可"), "红蓝签解除方式明确区分")
	fold.enemy_data = Database.get_enemy("rail_boss")
	check(EnemyMechanics.marker_name(fold, "签") == "压轨签" and EnemyMechanics.marker_description(fold, "签").contains("移出原行"), "压轨签说明具体移动要求")
	var glutton := Database.get_enemy("glutton")
	check(glutton.description.contains("每吞1字获得%d格挡" % int(glutton.tuning.swallow_block)), "吞字护盾参数不被同名行动字段覆盖")
	check(BattleText.clean("己方原实体#123，预算与待兑现") == "己方原字，次数与待生效", "旧战斗提示也清理程序术语与内部编号")
	var bubble := SpeechBubble.new()
	add_child(bubble)
	bubble.set_result(null, ["击"], ["获得1金币", "回复1生命", "热度+1", "补1字", "获得1格挡"])
	check(bubble.body.get_parsed_text().split("\n").size() == 4 and bubble.body.text.contains("url=result:details"), "多项战斗结果只显示3行，其他结果放进词条")
	check(bubble.body._local_entries["result:details"].text.contains("获得1格挡"), "精简结果不丢失末尾效果")
	bubble.queue_free()
	var review_path := OS.get_environment("PLAYER_COPY_REVIEW")
	if review_path.is_empty(): review_path = "user://player_copy_review.json"
	var file := FileAccess.open(review_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(review, "\t"))
	file.close()
	print("[player_copy_test] PASS=%d FAIL=%d TOTAL=%d" % [checks-failures, failures, checks])
	get_tree().quit(1 if failures else 0)
