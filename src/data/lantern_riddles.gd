extends RefCounted
## 无字灯谜池：谜面只给玩家看，谜底和奖励在选项效果里。
## 谜底必须存在于当前字库，且同一事件抽三个不同答案。

const POOL := [
	# 易
	{"riddle": "一人一个口不能分开走", "answer": "合", "tier": 1},
	{"riddle": "拿不出手", "answer": "合", "tier": 1},
	{"riddle": "去一人还有一口，去一口还有一人", "answer": "合", "tier": 1},
	{"riddle": "八把刀", "answer": "分", "tier": 1},
	{"riddle": "大小参差光照人", "answer": "灯", "tier": 1},
	{"riddle": "男儿一生有离合", "answer": "灯", "tier": 1},
	{"riddle": "用火一定要小心", "answer": "灯", "tier": 1},
	{"riddle": "动嘴又出力", "answer": "加", "tier": 1},
	{"riddle": "坐滑板的车", "answer": "连", "tier": 1},
	{"riddle": "情人无心空流泪水", "answer": "清", "tier": 1},
	{"riddle": "沱江水", "answer": "清", "tier": 1},
	{"riddle": "绿化西湖", "answer": "清", "tier": 1},
	# 中
	{"riddle": "表里如一", "answer": "回", "tier": 2},
	{"riddle": "格外大方", "answer": "回", "tier": 2},
	{"riddle": "烟消日出不见人", "answer": "火", "tier": 2},
	{"riddle": "人间牛女双星", "answer": "火", "tier": 2},
	{"riddle": "丢人现眼", "answer": "火", "tier": 2},
	{"riddle": "卷尾猴", "answer": "电", "tier": 2},
	{"riddle": "俺大人不在", "answer": "电", "tier": 2},
	{"riddle": "太阳照在金钩上", "answer": "电", "tier": 2},
	{"riddle": "一边软如纸，一边硬如铁，软的做鞋穿，硬的把墙砌", "answer": "破", "tier": 2},
	{"riddle": "石头太顽皮", "answer": "破", "tier": 2},
	{"riddle": "一人站在小亭边", "answer": "停", "tier": 2},
	{"riddle": "人在亭边歇", "answer": "停", "tier": 2},
	{"riddle": "招手不见走来", "answer": "超", "tier": 2},
	{"riddle": "方木运走一半", "answer": "速", "tier": 2},
	# 难
	{"riddle": "千里相逢", "answer": "重", "tier": 3},
	{"riddle": "千里姻缘一线牵", "answer": "重", "tier": 3},
	{"riddle": "斜月三星洞", "answer": "心", "tier": 3},
	{"riddle": "一钩残月带三星", "answer": "心", "tier": 3},
	{"riddle": "片云残月带三星", "answer": "心", "tier": 3},
	{"riddle": "一得之余", "answer": "金", "tier": 3},
	{"riddle": "一个人他姓王，口袋里装了两颗糖", "answer": "金", "tier": 3},
]

const BONUS := {
	1: {"new": [{"type": "gold", "amount": 6}], "owned": [{"type": "gold", "amount": 10}]},
	2: {"new": [{"type": "gold", "amount": 8}], "owned": [{"type": "heal", "amount": 8}]},
	3: {"new": [{"type": "heal", "amount": 12}], "owned": [{"type": "max_hp", "amount": 3}]},
}


static func fill(event: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if str(event.get("id", "")) != "lantern_riddle" or bool(event.get("riddle_ready", false)):
		return event
	var copy := event.duplicate(true)
	copy["options"] = roll(rng)
	copy["riddle_ready"] = true
	return copy


static func roll(rng: RandomNumberGenerator) -> Array:
	var pools := {1: [], 2: [], 3: []}
	for entry: Dictionary in POOL:
		pools[int(entry.tier)].append(entry)
	var picked: Array = []
	for tier in [1, 2, 3]:
		var entries: Array = pools[tier]
		if entries.is_empty():
			continue
		var entry: Dictionary = entries[rng.randi_range(0, entries.size() - 1)]
		picked.append(_make_option(entry))
	# 保险：正常池子会给出三个答案；若配置损坏，至少不返回空。
	var remaining: Array = POOL.duplicate()
	_shuffle(remaining, rng)
	while picked.size() < 3 and not remaining.is_empty():
		var entry: Dictionary = remaining.pop_back()
		picked.append(_make_option(entry))
	_shuffle(picked, rng)
	return picked


static func _make_option(entry: Dictionary) -> Dictionary:
	var answer := str(entry["answer"])
	var tier := int(entry["tier"])
	var bonus: Dictionary = BONUS.get(tier, BONUS[1])
	return {
		"text": "“%s”（打一字）" % str(entry["riddle"]),
		"effects": [
			{"type": "if", "condition": {"type": "has_glyph", "glyph": answer},
				"then": (bonus["owned"] as Array).duplicate(true), "else": (bonus["new"] as Array).duplicate(true)},
			{"type": "gain_character", "glyph": answer},
		],
	}


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
