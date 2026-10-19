extends RefCounted
class_name RelicRewardFlow
## 经典模式的遗物发放：精英 / 首领 / 事件 / 商店共用。
## 弹出遗物候选，选中后入手；绑定类遗物再从字袋挑一枚字，关掉选择窗就随机绑定。

## 商店遗物统一价
const SHOP_PRICE := 45


## 从还没有的遗物里抽 n 件候选；默认用主随机数
static func roll(n: int, rng: RandomNumberGenerator = null) -> Array:
	return Relics.roll_choices(GameState.relics, rng if rng != null else GameState.rng, n)


## 从主随机数当前状态派生一条旁路随机数：结果可复现，又不推进主随机数，
## 事件和商店原有的抽取（字、价格）因此保持不变。
static func side_rng(salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(str(GameState.rng.state) + salt)
	return r


## ids 为候选；allow_skip 时多一个「不要」选项。on_done(id) 收到入手的遗物 id，放弃为空串。
static func offer(host: Node, title: String, body: String, ids: Array, on_done: Callable, allow_skip := false) -> void:
	if ids.is_empty():
		on_done.call("")
		return
	var options: Array = []
	for i in ids.size():
		options.append({"text": "遗物「%s」" % Relics.name_of(ids[i]), "hint": Relics.desc_of(ids[i]), "primary": i == 0})
	if allow_skip:
		options.append({"text": "不要"})
	var overlay := ChoiceOverlay.new()
	overlay.setup({"title": title, "body": body, "options": options})
	overlay.chose.connect(func(index: int):
		if index >= ids.size():
			on_done.call("")
			return
		grant(host, ids[index], on_done))
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(overlay)


## 直接入手一件遗物；需要绑定时先弹字袋选择。
static func grant(host: Node, id: String, on_done: Callable) -> void:
	if not GameState.add_relic(id):
		on_done.call("")
		return
	if not Relics.needs_bind(id):
		on_done.call(id)
		return
	var counts := {}
	var bound: Array = GameState.relic_binds.values()
	for c in GameState.deck:
		if not bound.has(c.uid):
			counts[c.id()] = int(counts.get(c.id(), 0)) + 1
	if counts.is_empty():
		on_done.call(id)
		return
	var chars: Array = []
	for glyph_id in counts.keys():
		var cd: CharacterData = Database.get_character(glyph_id)
		if cd != null:
			chars.append(cd)
	var picker := CollectionOverlay.new()
	var state := {"done": false}
	picker.setup({
		"title": "「%s」绑定哪一枚字？" % Relics.name_of(id),
		"subtitle": Relics.desc_of(id) + "　关闭则随机绑定",
		"characters": chars,
		"counts": counts,
		"pick_on_click": true,
	})
	picker.picked.connect(func(cd: CharacterData):
		if state.done: return
		state.done = true
		GameState.bind_relic(id, cd.id)
		on_done.call(id))
	picker.closed.connect(func():
		if state.done: return
		state.done = true
		var keys: Array = counts.keys()
		GameState.bind_relic(id, str(keys[GameState.rng.randi_range(0, keys.size() - 1)]))
		on_done.call(id))
	picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(picker)
