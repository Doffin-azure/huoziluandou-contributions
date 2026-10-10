extends Node
## 一局冒险的全局状态：字袋、生命、金币、进度。
## 所有“构筑”操作（加字/删字/复制/换字）都通过这里改动 deck。

var rules: BattleRules = null

var deck: Array = []          ## Array[CharInstance] 永久字袋
var player_max_hp: int = 60
var player_hp: int = 60
var gold: int = 6

var act_index: int = 1
var node_index: int = 1        ## 当前可挑战的下一个节点序号（1..8）
var fork_choice: int = -1      ## 岔路选择：0 精英 1 事件
var visited: Dictionary = {}   ## "act:node" -> true

# --- V0.2 跨战永久能力 ---
var permanent_damage_reduction: int = 0
var gold_growth_percent: int = 0
var reinvest_gold: int = 0

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rules = Database.rules
	rng.randomize()


func start_new_run(starter_id: String = "v03") -> void:
	if Database.rules == null:
		Database.reload()
	rules = Database.rules
	deck.clear()
	var starter: StarterDeckData = Database.starter_decks.get(starter_id)
	if starter == null and not Database.starter_decks.is_empty():
		starter = Database.starter_decks.values()[0]
	if starter != null:
		for entry in starter.entries:
			add_character(entry.character, entry.count)
		player_max_hp = rules.player_max_hp
		player_hp = player_max_hp
		gold = rules.starting_gold
	else:
		player_max_hp = rules.player_max_hp
		player_hp = player_max_hp
		gold = rules.starting_gold
	act_index = 1
	node_index = 1
	fork_choice = -1
	visited.clear()
	permanent_damage_reduction = 0
	gold_growth_percent = 0
	reinvest_gold = 0
	EventBus.run_started.emit()
	EventBus.deck_changed.emit()
	EventBus.gold_changed.emit(gold)
	EventBus.hp_changed.emit(player_hp, player_max_hp)


func add_character(data: CharacterData, count: int = 1) -> void:
	if data == null:
		return
	for i in count:
		deck.append(CharInstance.new(data))
	EventBus.deck_changed.emit()


## 把战斗中收购得到的实体字永久加入字袋
func add_captured(instances: Array) -> void:
	for inst in instances:
		var c := CharInstance.new(inst.data)
		c.upgrade_level = inst.upgrade_level
		deck.append(c)
	if not instances.is_empty():
		EventBus.deck_changed.emit()


## 胜利后结算跨战经济增益（复利投资 / 再投资）
func settle_victory_economy() -> void:
	if gold_growth_percent > 0:
		var bonus: int = int(floor(gold * gold_growth_percent / 100.0))
		if bonus > 0:
			add_gold(bonus)
	if reinvest_gold > 0:
		var back: int = reinvest_gold * 2
		add_gold(back)
		reinvest_gold = 0


func remove_by_uid(uid: int) -> bool:
	for i in deck.size():
		if deck[i].uid == uid:
			deck.remove_at(i)
			EventBus.deck_changed.emit()
			return true
	return false


func remove_character_id(id: String) -> bool:
	for i in deck.size():
		if deck[i].id() == id:
			deck.remove_at(i)
			EventBus.deck_changed.emit()
			return true
	return false


func add_gold(amount: int) -> void:
	gold = max(0, gold + amount)
	EventBus.gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold)
	return true


func heal(amount: int) -> void:
	player_hp = min(player_max_hp, player_hp + amount)
	EventBus.hp_changed.emit(player_hp, player_max_hp)


func damage(amount: int) -> void:
	player_hp = max(0, player_hp - amount)
	EventBus.hp_changed.emit(player_hp, player_max_hp)


func deck_size() -> int:
	return deck.size()


func glyph_counts() -> Dictionary:
	var counts: Dictionary = {}
	for c in deck:
		var g: String = c.glyph()
		counts[g] = int(counts.get(g, 0)) + 1
	return counts


## 生成初始战斗用的一批字实例（引用永久实例，战斗结束会放回）。
func make_battle_deck() -> Array:
	var out: Array = []
	for c in deck:
		out.append(c)
	return out


func mark_visited(act: int, node: int) -> void:
	visited["%d:%d" % [act, node]] = true


func is_visited(act: int, node: int) -> bool:
	return visited.has("%d:%d" % [act, node])


## 完成当前节点，推进到下一个；幕末则进入下一幕。
func complete_current_node() -> void:
	mark_visited(act_index, node_index)
	node_index += 1
	if node_index > 8:
		act_index += 1
		node_index = 1
	if act_index > 3:
		EventBus.run_ended.emit(true)


func run_complete() -> bool:
	return act_index > 3
