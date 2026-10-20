extends RefCounted
## 每场正式战斗的只读观察器。测试/自定义战斗默认不创建。
var service: Node
var b: WeakRef
var key := ""
var serial := 0
var play_index := 0
var hp_lost := 0
var killed := {}
var ended := false
var current := {}
var attack_damage := 0
var attack_hits := 0
var attack_index := 0


func _init(owner: Node, battle: RefCounted, id: String) -> void:
	service = owner
	b = weakref(battle)
	key = id
	battle.player.feedback.connect(_player_feedback)
	for enemy in battle.enemies:
		enemy.feedback.connect(_enemy_feedback.bind(weakref(enemy)))
	sample()


func _context(action := "") -> Dictionary:
	var battle = b.get_ref()
	return {"run": service.run_id, "battle": key, "turn": "%s:%d" % [key, battle.turn], "action": action}


func emit_metrics(rows: Array, token := "") -> void:
	var battle = b.get_ref()
	if battle == null or ended: return
	if battle.player.god_mode: service.invalidate_run(); return
	serial += 1
	service.commit(token, rows, _context("%s:play:%d" % [key, play_index]), "battle/" + key, serial)


func sample() -> void:
	var battle = b.get_ref()
	if battle == null: return
	emit_metrics([{"metric": "energy_peak", "amount": battle.player.energy}, {"metric": "heat_peak", "amount": battle.player.heat}, {"metric": "persistent_shield", "amount": battle.player.persistent_block}])


func _player_feedback(event: Dictionary) -> void:
	if event.kind == "damage": hp_lost += int(event.hp_loss)
	if event.kind == "shield": emit_metrics([{"metric": "persistent_shield", "amount": int(event.persistent_block)}])


func _enemy_feedback(_event: Dictionary, reference: WeakRef) -> void:
	var enemy: Combatant = reference.get_ref()
	if enemy == null: return
	if enemy.is_alive() or killed.has(enemy.get_instance_id()) or enemy.enemy_data == null: return
	killed[enemy.get_instance_id()] = true
	emit_metrics([{"metric": "enemy_kills", "amount": 1, "filter": enemy.enemy_data.id}])


func begin_play(play: Dictionary) -> void:
	current = {"word": play.word, "temporary": 0, "polluted": 0, "pinned": 0, "extra": 0, "energy": 0, "cooled": 0, "replicate": []}
	var seen := {}
	for inst in play.instances:
		if inst == null or seen.has(inst.uid): continue
		seen[inst.uid] = true
		if inst.temporary: current.temporary += 1
		if not inst.pollutions.is_empty(): current.polluted += 1
		if inst.pinned: current.pinned += 1
	var battle = b.get_ref()
	for inst in battle.board.cells:
		if inst != null and inst.is_enemy_owned() and inst.has_pollution("replicate") and not bool(inst.statuses.get("achievement_replicated", false)):
			current.replicate.append(inst)


func finish_play(ok: bool) -> void:
	if current.is_empty(): return
	if not ok: current = {}; return
	play_index += 1
	var rows: Array = [{"metric": "extra_use_spent", "amount": current.extra}, {"metric": "pinned_used", "amount": current.pinned}, {"metric": "energy_spent", "amount": current.energy}, {"metric": "heat_cooled", "amount": current.cooled}]
	if current.word != null and current.word.length() >= 2:
		rows.append_array([{"metric": "word_plays", "amount": 1}, {"metric": "unique_words", "value": current.word.id}, {"metric": "temporary_word_tiles", "amount": current.temporary}, {"metric": "polluted_word_tiles", "amount": current.polluted}])
	var battle = b.get_ref()
	var stopped := 0
	for inst in current.replicate:
		if not battle.board.cells.has(inst) or not inst.has_pollution("replicate"):
			if not bool(inst.statuses.get("achievement_stopped", false)):
				inst.statuses.achievement_stopped = true
				stopped += 1
	rows.append({"metric": "replicate_removed", "amount": stopped})
	emit_metrics(rows)
	current = {}
	sample()


func spent_energy(amount: int) -> void:
	if not current.is_empty(): current.energy += amount


func cooled(amount: int) -> void:
	if not current.is_empty(): current.cooled += amount


func extra_use() -> void:
	if not current.is_empty(): current.extra += 1


func attack_begin() -> void:
	attack_damage = 0
	attack_hits = 0


func attack_hit(enemy: Combatant, before_hp: int, before_shield: int, grouped: bool) -> void:
	if enemy.is_player or before_hp <= 0: return
	if not grouped: attack_begin()
	attack_damage += maxi(0, before_hp - enemy.hp) + maxi(0, before_shield - enemy.block - enemy.persistent_block)
	attack_hits += 1
	if not grouped: attack_end()


func attack_end() -> void:
	if attack_hits <= 0: return
	attack_index += 1
	var rows := [{"metric": "attack_damage", "amount": attack_damage}, {"metric": "attack_hits", "amount": attack_hits}]
	# 每次攻击单独取最大；上下文动作不累加不同攻击。
	emit_metrics(rows)
	attack_damage = 0
	attack_hits = 0


func finish(victory: bool) -> void:
	if ended: return
	sample()
	if victory:
		var rows: Array = [{"metric": "battle_wins", "amount": 1}]
		if hp_lost == 0: rows.append({"metric": "flawless_wins", "amount": 1})
		emit_metrics(rows)
	ended = true
	service.save_progress()


func export_snapshot() -> Dictionary:
	return {"key":key,"serial":serial,"play_index":play_index,"hp_lost":hp_lost,"ended":ended,"attack_index":attack_index}


func restore_snapshot(data: Dictionary) -> void:
	serial = int(data.get("serial", 0))
	play_index = int(data.get("play_index", 0))
	hp_lost = int(data.get("hp_lost", 0))
	ended = bool(data.get("ended", false))
	attack_index = int(data.get("attack_index", 0))
	var battle = b.get_ref()
	for enemy in battle.enemies:
		if not enemy.is_alive(): killed[enemy.get_instance_id()] = true
