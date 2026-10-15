extends RefCounted
class_name EffectGlossary
## 纯展示词典：完整词效仍来自 WordData，不能执行效果或创建实体。

const ENTRIES := {
	"block": ["临时格挡", "先于持久盾吸收伤害；本回合所有敌人行动后清空。获得的数值可以叠加。"],
	"shield": ["持久盾", "在临时格挡耗尽后吸收伤害，跨回合保留，直到消耗完毕。"],
	"strength": ["力量", "每层使本场攻击的每段伤害+1，可以叠加。非攻击伤害不受力量加成。"],
	"counter": ["反击", "本回合所有敌人行动后，对首个存活敌人反击一次：基础伤害=剩余临时格挡+3×反击层数。层数可叠加，结算后清除。"],
	"temporary": ["临时字 / 临时复制", "用后移除，不进入字袋或弃字堆循环。生成的临时复制不继承原实体的固定、精炼、额外使用或镀金等强化；需要空格才能放入。单独出字是否有效，以该临时字的说明为准。"],
	"original": ["己方原实体", "属于玩家、且不是临时复制的真实字块。同字形的两枚字是两个实体；移动或回袋时，原实体保留自己的强化。敌方字与临时字不在此列。"],
	"extra_use": ["额外使用", "每次有效使用先扣1次额外使用，字留在原格；额外次数耗尽后，再次使用才正常消耗原实体。不同来源的次数可以叠加。"],
	"refined": ["精炼效果", "当次获得2次额外使用；本场该实体以后每次重新补入盘面，都恢复至少2次额外使用。仅移动或进入新回合不刷新，战后结束。"],
	"pinned": ["固定", "本场留在原格，不能移动或换字；每回合最多有效使用1次，下回合恢复使用机会。"],
	"gilded": ["镀金", "每枚镀金字参与有效多字词时获得1金币。原实体上的镀金跨战保留，临时复制不继承。"],
	"replay": ["效果重演", "即时效果额外结算1次，不重复消耗组成词的字块；金币、储能等费用仍须再付。持续能力的启用效果不重演。"],
	"return": ["原格返回", "优先放回原来所在的格子，原格被占用则改放空格。回放只返回当前有空位容纳的原实体；重连在满盘时继续等待空位。"],
	"vulnerable": ["易伤", "受到的伤害提高50%，向上取整。多层仍为50%增幅；敌方易伤在本场不按回合衰减。"],
	"corrosion": ["心蚀", "该敌人每次行动后，受到等于心蚀层数的非攻击伤害，可被护盾吸收。层数可以叠加，且不衰减。"],
	"regen": ["再生", "每回合开始时回复等于当前层数的生命，随后减少1层。层数可以叠加。"],
	"heart": ["心力", "每层抵挡1次致命伤害，触发时消耗1层并保留当前生命。强心会记录本场成功抵挡致命伤害的次数。"],
	"bounty": ["爆金", "本场目标此后每受到一次攻击，你获得1金币；多段攻击逐段计入，被护盾全挡也触发。"],
	"burn": ["灼烧", "在目标行动后造成伤害；放火持续2次行动，伤害按施放时热度记录，此后改变热度不改变这次灼烧。与字块的灼热污染不同。"],
	"scorch": ["灼热污染", "字块上的污染标签。打出这枚字会使玩家受到灼热伤害；净化只移除污染标签，不改变所有权。"],
	"overflow": ["溢热", "热度增加并超出热容时，会生成带灼热污染的【热】。相关能力只在实际新增污染时触发，抽到或移动旧的【热】不触发。"],
	"funds": ["临时资金", "仅本回合可用的金币支付额度，支付时优先消耗；不是实际金币收入，未用完的回合结束清空。"],
	"energy": ["储能", "本场可积累并跨回合保留的资源。写明消耗或支付时才扣除；仅按当前储能计算伤害的词不会自动消耗。"],
	"capacity": ["热容", "容纳热度的阈值。超过热容的新增热度可能产生溢热污染，提高热容不会主动降低已有热度。"],
	"non_attack": ["非攻击伤害", "不属于攻击，不享受力量或下一次攻击的强化；仍可被护盾吸收，并按受击目标的减伤与易伤结算。"],
	"double_attack": ["超强翻倍", "下一次攻击的各段基础伤害、力量与热力加成翻倍。蓄力、连载、过火的追加伤害不随之翻倍；被护盾全挡也消耗机会。"],
	"double_passive": ["可翻倍的被动收益", "只支持这些能力中首项可兑现的收益：加速、流转、能力、连载、蓄能、蓄热、复利、分利、过热、火热、电流过载、电能、心力、护甲。消耗与降温量不重复，没有实际收益时不消耗机会。"],
	"formation": ["结阵", "之后打出的词先登记，点「发动」再按顺序结算。多词可以共享同一枚【击】；每个词的实时来源和资源按轮到它结算时的状态计算。"]
}

## 长词优先，避免把“非攻击伤害”拆成“攻击”等片段。
const TERMS := {
	"临时格挡": "block", "临挡": "block", "持久盾": "shield", "力量": "strength",
	"反击": "counter", "临时复制": "temporary", "临时副本": "temporary", "临时字": "temporary",
	"己方原实体": "original", "原实体": "original", "实体字": "original",
	"额外使用": "extra_use", "精炼效果": "refined", "固定": "pinned", "镀金": "gilded",
	"效果重演": "replay", "原格返回": "return", "易伤": "vulnerable", "心蚀": "corrosion",
	"心力": "heart", "爆金": "bounty", "灼烧": "burn", "灼热污染": "scorch",
	"再生": "regen",
	"溢热": "overflow", "临时资金": "funds", "储能": "energy", "热容": "capacity",
	"非攻击伤害": "non_attack", "超强翻倍": "double_attack", "被动收益": "double_passive",
	"结阵": "formation"
}

static func brief(word: WordData) -> String:
	return WordDescriptions.BRIEF_TEXT.get(word.word, word.describe())

static func entry(meta: String) -> Dictionary:
	if meta.begins_with("term:"):
		var key := meta.trim_prefix("term:")
		if ENTRIES.has(key):
			return {"title": ENTRIES[key][0], "text": ENTRIES[key][1]}
	elif meta.begins_with("word:"):
		var word := Database.get_word_by_glyphs_string(meta.trim_prefix("word:"))
		if word != null:
			return {"title": word.word, "text": word.describe()}
	return {}

static func escape(text: String) -> String:
	return text.replace("[", "[lb]")

static func format_text(text: String, number_size := 0, exclude := "") -> String:
	var terms: Array = TERMS.keys()
	terms.sort_custom(func(a, b): return a.length() > b.length())
	var output := ""
	var cursor := 0
	while cursor < text.length():
		# 只有完整的【词语】才转词条链接，避免把【热】等字形当作规则名。
		if text[cursor] == "【":
			var end := text.find("】", cursor + 1)
			if end >= 0:
				var glyphs := text.substr(cursor + 1, end - cursor - 1)
				var literal := text.substr(cursor, end - cursor + 1)
				var meta := "word:" + glyphs
				output += link(literal, meta) if glyphs.length() >= 2 and meta != exclude and not entry(meta).is_empty() else escape(literal)
				cursor = end + 1
				continue
		var matched := false
		for term in terms:
			if text.substr(cursor, term.length()) != term:
				continue
			var meta: String = "term:" + TERMS[term]
			output += link(term, meta) if meta != exclude else escape(term)
			cursor += term.length()
			matched = true
			break
		if matched:
			continue
		if text[cursor] >= "0" and text[cursor] <= "9":
			var end := cursor + 1
			while end < text.length() and ((text[end] >= "0" and text[end] <= "9") or text[end] == "."):
				end += 1
			var digits := text.substr(cursor, end - cursor)
			output += "[color=#%s]%s%s%s[/color]" % [Palette.VERMILION_DK.to_html(false), "[font_size=%d]" % number_size if number_size > 0 else "", digits, "[/font_size]" if number_size > 0 else ""]
			cursor = end
			continue
		output += escape(text[cursor])
		cursor += 1
	return output

static func link(label: String, meta: String) -> String:
	return "[url=%s][color=#%s]%s[/color][/url]" % [meta, Palette.INDIGO.to_html(false), escape(label)]
