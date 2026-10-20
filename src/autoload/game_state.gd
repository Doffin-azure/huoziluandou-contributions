extends Node
## 一局冒险的全局状态：字袋、生命、金币、进度。
## 所有“构筑”操作（加字/删字/复制/换字）都通过这里改动 deck。

var rules: BattleRules = null

var deck: Array = []          ## Array[CharInstance] 永久字袋
var player_max_hp: int = 60
var player_hp: int = 60
var gold: int = 6
## 事件链临时气血：只在当前连续事件中有效，优先吸收事件伤害。
var event_temp_hp: int = 0

var act_index: int = 1
var node_index: int = 1        ## 当前可挑战的下一个节点序号（1..8）
var fork_choice: int = -1      ## 岔路选择：0 精英 1 事件
var visited: Dictionary = {}   ## "act:node" -> true

# --- V0.2 跨战永久能力 ---
var permanent_damage_reduction: int = 0
var battle_sequence: int = 0
var rng := RandomNumberGenerator.new()

## 自定义起始字袋（字形字符串列表，如 ["火","火","电"]）；非空时 start_new_run 优先用它。
## 调试入口与未来「自定义模式」共用这一处。
var custom_deck: Array = []

## 墨途远征的局内状态；经典冒险为 null
var expedition: Expedition = null
## New courtyard mode has independent room IDs and progression; legacy expedition stays intact.
var room_run: RefCounted = null
## 遗物（见 src/core/relics.gd）：按获得顺序；绑定类记永久实体 uid；计数器（字种）
var relics: Array = []
var relic_binds: Dictionary = {}
var relic_counters: Dictionary = {}
## 反死亡：本局存着的复活次数（一局最多拿到一次）
var revive_charges: int = 0


func _ready() -> void:
	rules = Database.rules
	rng.randomize()


func start_new_run(starter_id: String = "v03", custom_glyphs: Array = []) -> void:
	if Database.rules == null:
		Database.reload()
	rules = Database.rules
	deck.clear()
	expedition = null
	room_run = null
	relics.clear()
	relic_binds.clear()
	relic_counters.clear()
	revive_charges = 0
	player_max_hp = rules.player_max_hp
	player_hp = player_max_hp
	gold = rules.starting_gold
	event_temp_hp = 0
	if not custom_glyphs.is_empty():
		# 自定义模式 / 调试：按给定字形列表建袋
		custom_deck = custom_glyphs.duplicate()
		for g in custom_glyphs:
			var cd: CharacterData = Database.get_character_by_glyph(str(g))
			if cd != null:
				add_character(cd, 1)
	else:
		custom_deck.clear()
		var starter: StarterDeckData = Database.starter_decks.get(starter_id)
		if starter == null and not Database.starter_decks.is_empty():
			starter = Database.starter_decks.values()[0]
		if starter != null:
			for entry in starter.entries:
				add_character(entry.character, entry.count)
	act_index = 1
	node_index = 1
	fork_choice = -1
	visited.clear()
	permanent_damage_reduction = 0
	battle_sequence = 0
	EventBus.run_started.emit()
	EventBus.deck_changed.emit()
	EventBus.gold_changed.emit(gold)
	EventBus.hp_changed.emit(player_hp, player_max_hp)


func add_character(data: CharacterData, count: int = 1) -> void:
	if data == null:
		return
	# 许愿笺·千字同文：之后拿到的字都变成许愿的字；金字碑：新字也镀金
	data = Relics.redirect_glyph(data)
	for i in count:
		var inst := CharInstance.new(data)
		inst.gilded = relics.has("midas")
		deck.append(inst)
	EventBus.deck_changed.emit()


# ---------------------------------------------------------------- 遗物
func has_relic(id: String) -> bool:
	return relics.has(id)


## 按获得顺序追加；重复获得无效。绑定类遗物另需 bind_relic。
func add_relic(id: String) -> bool:
	if relics.has(id) or not Relics.DEFS.has(id):
		return false
	relics.append(id)
	Relics.on_pickup(id)
	return true


## 卖掉 / 失去：绑定和计数一起清掉（以后还能再得到）
func remove_relic(id: String) -> bool:
	if not relics.has(id):
		return false
	relics.erase(id)
	relic_binds.erase(id)
	relic_counters.erase(id)   # 「fireman_claimed」这类一局一次的标记不清
	return true


## 绑定到字袋里第一枚该字形、且没被别的遗物绑定的永久实体
func bind_relic(id: String, glyph_id: String) -> bool:
	if not relics.has(id):
		return false
	var bound: Array = relic_binds.values()
	for c in deck:
		if c.id() == glyph_id and not bound.has(c.uid):
			relic_binds[id] = c.uid
			return true
	return false


## 绑定的实体已不在字袋（被删、被熔）→ 返回 null，遗物暂时失效
func relic_bound_inst(id: String) -> CharInstance:
	var uid := int(relic_binds.get(id, -1))
	for c in deck:
		if c.uid == uid:
			return c
	return null


## 把战斗中收购得到的实体字永久加入字袋
func add_captured(instances: Array) -> void:
	for inst in instances:
		var c := CharInstance.new(inst.data)
		c.upgrade_level = inst.upgrade_level
		deck.append(c)
	if not instances.is_empty():
		EventBus.deck_changed.emit()


## 兼容现有胜利流程；金币在打字时即时结算。
func settle_victory_economy() -> void:
	pass


func remove_by_uid(uid: int) -> bool:
	for i in deck.size():
		if deck[i].uid == uid:
			deck.remove_at(i)
			EventBus.deck_changed.emit()
			return true
	return false


## 同字形有多枚时，先删没被遗物绑定的那一枚
func remove_character_id(id: String) -> bool:
	var bound: Array = relic_binds.values()
	var pick := -1
	for i in deck.size():
		if deck[i].id() == id:
			if pick < 0 or (bound.has(deck[pick].uid) and not bound.has(deck[i].uid)):
				pick = i
	if pick < 0:
		return false
	deck.remove_at(pick)
	EventBus.deck_changed.emit()
	return true


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


func add_event_temp_hp(amount: int) -> void:
	event_temp_hp = maxi(0, event_temp_hp + maxi(0, amount))
	EventBus.hp_changed.emit(player_hp, player_max_hp)


func clear_event_temp_hp() -> void:
	if event_temp_hp == 0: return
	event_temp_hp = 0
	EventBus.hp_changed.emit(player_hp, player_max_hp)


func spend_event_temp_hp(amount: int) -> void:
	if amount <= 0: return
	event_temp_hp = maxi(0, event_temp_hp - amount)
	EventBus.hp_changed.emit(player_hp, player_max_hp)


func damage(amount: int) -> void:
	var remaining := maxi(0, amount)
	var absorbed := mini(event_temp_hp, remaining)
	event_temp_hp -= absorbed
	remaining -= absorbed
	player_hp = max(0, player_hp - remaining)
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
