extends RefCounted
## 射覆：三只倒扣的碗，奖励由固定种子预先排好；选项只显示碗的位置。
## 事件开始时生成一次并写入 event_data，重进不会重新洗牌。

const POSITIONS := ["左边的碗", "中间的碗", "右边的碗"]


static func fill(event: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if str(event.get("id", "")) != "shefu" or bool(event.get("shefu_ready", false)):
		return event
	var copy := event.duplicate(true)
	var seed := rng.randi()
	copy["reward_seed"] = seed
	copy["options"] = build(seed)
	copy["shefu_ready"] = true
	return copy


static func build(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# 一只碗有稀有字，另外两只空碗；没有铜钱和遗物。
	var rewards: Array = [
		{"effects": [{"type": "gain_character", "min_rarity": 2, "max_rarity": 4}]},
		{"effects": []},
		{"effects": []},
	]
	_shuffle(rewards, rng)
	var options: Array = []
	for i in rewards.size():
		options.append({"text": "揭开" + str(POSITIONS[i]), "effects": (rewards[i]["effects"] as Array).duplicate(true)})
	return options


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
