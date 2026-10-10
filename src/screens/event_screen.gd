extends ScreenBase
## 事件：风险与资源取舍。选择一个选项后推进节点。

var node: MapNodeData
var _event: Dictionary
var _done := false

const EVENTS := [
	{
		"id": "ink_pool",
		"title": "墨池遗字",
		"body": "林间有一方墨池，字迹在池底幽幽浮动。伸手可取，却要付出代价。",
		"options": [
			{"text": "探手取字（失去 8 生命，获得一枚字）", "primary": true},
			{"text": "掬一捧墨（获得 18 金币）"},
			{"text": "静观而退"},
		],
	},
	{
		"id": "broken_stele",
		"title": "断碑",
		"body": "半截石碑立在荒径，碑上刻字已被岁月磨平，唯余一道深痕。",
		"options": [
			{"text": "拓下残字（获得一枚稀有字）", "primary": true},
			{"text": "敲下碑角（获得 25 金币，失去 5 生命）"},
			{"text": "绕道而行"},
		],
	},
	{
		"id": "old_bookshop",
		"title": "旧书肆",
		"body": "无人看管的书肆里堆满残页，老板的位置只剩一盏将熄的灯。",
		"options": [
			{"text": "撕下一页（删掉字袋中一枚字）", "primary": true},
			{"text": "诵读静心（回复 18 点气血）"},
			{"text": "顺手牵金（获得 14 金币）"},
		],
	},
]


func build(root: Control) -> void:
	node = params.get("node", null)
	_event = EVENTS[GameState.rng.randi_range(0, EVENTS.size() - 1)]

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := Ink.panel("PanelCard")
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var pad := Ink.margin(28)
	panel.add_child(pad)
	var col := Ink.vbox(14)
	pad.add_child(col)
	col.add_child(Ink.h2(_event.title))
	col.add_child(Ink.hline())
	var body := Ink.body(_event.body)
	body.custom_minimum_size.x = 480
	col.add_child(body)
	col.add_child(Ink.spacer(6))

	for i in _event.options.size():
		var opt: Dictionary = _event.options[i]
		var b := Ink.button(opt.text, bool(opt.get("primary", false)))
		b.pressed.connect(_choose.bind(i))
		col.add_child(b)


func _choose(index: int) -> void:
	if _done:
		return
	_done = true
	match _event.id:
		"ink_pool":
			if index == 0:
				GameState.damage(8)
				GameState.add_character(_random_char(0, 2), 1)
				_finish()
			elif index == 1:
				GameState.add_gold(18)
				_finish()
			else:
				_finish()
		"broken_stele":
			if index == 0:
				GameState.add_character(_random_char(2, 4), 1)
				_finish()
			elif index == 1:
				GameState.add_gold(25)
				GameState.damage(5)
				_finish()
			else:
				_finish()
		"old_bookshop":
			if index == 0:
				_remove_prompt()
			elif index == 1:
				GameState.heal(18)
				_finish()
			else:
				GameState.add_gold(14)
				_finish()


func _remove_prompt() -> void:
	var counts := GameState.glyph_counts()
	var chars: Array = []
	for id in counts.keys():
		var cd: CharacterData = Database.get_character(id)
		if cd != null:
			chars.append(cd)
	if chars.is_empty():
		_finish()
		return
	var overlay := CollectionOverlay.new()
	overlay.setup({
		"title": "撕下哪一页？",
		"characters": chars,
		"counts": counts,
		"pick_on_click": true,
	})
	overlay.picked.connect(_on_removed)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _on_removed(ch: CharacterData) -> void:
	GameState.remove_character_id(ch.id)
	_finish()


func _random_char(min_rarity: int, max_rarity: int) -> CharacterData:
	var pool: Array = []
	for c in Database.characters.values():
		if c.is_pollution or c.pending_design or c.tags.has("enemy"):
			continue
		if c.rarity >= min_rarity and c.rarity <= max_rarity:
			pool.append(c)
	if pool.is_empty():
		pool = Database.characters.values()
	return pool[GameState.rng.randi_range(0, pool.size() - 1)]


func _finish() -> void:
	GameState.complete_current_node()
	goto("res://src/screens/map_screen.gd")
