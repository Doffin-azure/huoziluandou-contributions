extends Node
## 庭院大循环 heuristic 试玩：只使用 RoomRunState 的合法动作，不直接改血量、铜钱或牌库。
## 目的不是证明 AI 会玩，而是观察事件、奖励、商店、遗物在多个种子下能否收敛成流派。
##
## 运行：
##   godot --headless --path . res://src/tools/courtyard_balance_sim.tscn
##
## 输出：
##   docs/courtyard_balance_report.json
##   docs/courtyard_balance_report.md

const RUN = preload("res://src/expedition/room_run_state.gd")
const EVENTS = preload("res://src/core/event_effects.gd")
const MAX_STEPS := 5000
const SEEDS := 24
const POLICIES := ["balanced", "lean", "focused"]
const OUTPUT_JSON := "res://docs/courtyard_balance_report.json"
const OUTPUT_MD := "res://docs/courtyard_balance_report.md"

var _word_count := {}


func _ready() -> void:
	for word: WordData in Database.words.values():
		if not word.implemented:
			continue
		for glyph in word.glyphs:
			_word_count[glyph] = int(_word_count.get(glyph, 0)) + 1
	var report: Array = []
	for policy in POLICIES:
		for seed_value in range(1, SEEDS + 1):
			var result := _play(seed_value, policy)
			report.append(result)
			print("[%s seed=%d] %s act=%d hp=%d/%d gold=%d deck=%d relics=%d events=%d battles=%d" % [
				policy, seed_value, result.phase, result.act, result.hp, result.max_hp,
				result.gold, result.deck_size, result.relics.size(), result.events.size(), result.battles,
			])
	_write_json(report)
	_write_markdown(report)
	print("[balance] %d runs -> %s" % [report.size(), OUTPUT_JSON])
	get_tree().quit(0)


func _play(seed_value: int, policy: String) -> Dictionary:
	var run := RUN.new()
	run.reset({"seed": seed_value, "layout": "compact_garden"})
	run.autosave = false
	var steps := 0
	var battles := 0
	var battle_losses := 0
	var events: Array = []
	var event_choices: Array = []
	var shops: Array = []
	var rests: Array = []
	var battle_records: Array = []
	var route: Array = []
	var map_log: Array = []
	var rewards_taken := 0
	var rewards_skipped := 0
	var gold_earned := 0
	var gold_spent := 0
	while not run.is_done() and steps < MAX_STEPS:
		steps += 1
		if run.phase == "generation_error":
			break
		var before_gold: int = GameState.gold
		var phase_before := run.phase
		var battle_hp_before: int = GameState.player_hp
		var battle_room := str(run.current_room)
		var battle_kind := str(run.graph.rooms.get(run.current_room, {}).get("kind", ""))
		var action := _choose(run, policy, events, event_choices, shops, rests)
		if action.is_empty():
			break
		if run.phase == "reward" and action.get("type") == "reward":
			rewards_taken += 1
		elif run.phase == "reward" and action.get("type") == "skip":
			rewards_skipped += 1
		if run.phase == "map" and action.get("type") == "enter_room":
			var preview: Array = []
			for id: String in run.next_rooms(): preview.append({"id": id, "kind": str(run.graph.rooms[id].kind)})
			map_log.append({"room": run.current_room, "next": preview, "chosen": str(action.get("room", ""))})
		if action.get("type") == "enter_room": route.append(str(action.get("room", "")))
		if action.get("type") == "interact": battles += 1
		var result: Dictionary = run.apply(action)
		if not result.get("ok", false):
			push_warning("illegal action %s: %s" % [action, result])
			break
		var delta: int = GameState.gold - before_gold
		if delta > 0: gold_earned += delta
		elif delta < 0: gold_spent += -delta
		if phase_before == "battle" and run.phase != "battle":
			var bh = run.battle_h
			var bs: Dictionary = bh.summary() if bh != null else {}
			battle_records.append({"room": battle_room, "kind": battle_kind, "hp_before": battle_hp_before, "hp_after": GameState.player_hp, "victory": run.phase == "reward", "turns": int(bs.get("turns", 0)), "words": int(bs.get("word_plays", 0)), "singles": int(bs.get("single_plays", 0))})
			if run.phase == "defeat": battle_losses += 1
	# 读取最终状态，不修改。
	var deck: Array = []
	var tag_counts := {}
	for inst: CharInstance in GameState.deck:
		var c := inst.data
		var tags: Array = c.tags.duplicate() if c != null else []
		for tag in tags:
			tag_counts[tag] = int(tag_counts.get(tag, 0)) + 1
		deck.append({
			"glyph": inst.glyph(), "id": inst.id(), "rarity": c.rarity if c != null else 0,
			"gilded": inst.gilded, "tags": tags, "pollutions": inst.pollutions.duplicate(),
		})
	var relics: Array = GameState.relics.duplicate()
	var relic_counters: Dictionary = GameState.relic_counters.duplicate()
	var summary := {
		"seed": seed_value, "policy": policy, "phase": run.phase,
		"act": GameState.act_index, "room": run.current_room, "steps": steps,
		"hp": GameState.player_hp, "max_hp": GameState.player_max_hp,
		"gold": GameState.gold, "deck_size": GameState.deck_size(),
		"resolved": run.resolved.size(), "visited": run.visited_rooms.size(),
		"battles": battles, "battle_losses": battle_losses,
		"rewards_taken": rewards_taken, "rewards_skipped": rewards_skipped,
		"gold_earned": gold_earned, "gold_spent": gold_spent,
		"relics": relics, "relic_counters": relic_counters,
		"events": events, "event_choices": event_choices,
		"shops": shops, "rests": rests, "battles_detail": battle_records, "route": route, "map_log": map_log,
		"seen_events": run.seen_events.duplicate(),
		"deck": deck, "tag_counts": tag_counts,
		"rarity_counts": _rarity_counts(deck),
		"generation_ms": run.generation_ms,
	}
	return summary


func _choose(run, policy: String, events: Array, event_choices: Array, shops: Array, rests: Array) -> Dictionary:
	match run.phase:
		"map": return _choose_room(run, policy)
		"encounter": return {"type": "interact"}
		"battle": return _pick_battle(run.legal_actions(), run.battle_h.observe() if run.battle_h != null else {})
		"reward": return _choose_reward(run, policy)
		"shop": return _choose_shop(run, policy, shops)
		"rest": return _choose_rest(run, policy, rests)
		"event":
			var action := _choose_event(run, policy)
			if not action.is_empty():
				var option: Dictionary = run.current_event().options[int(action.get("index", 0))]
				events.append(str(run.event_data.get("id", "")))
				event_choices.append({"id": str(run.event_data.get("id", "")), "text": str(option.get("text", ""))})
			return action
		"event_choose", "shop_choose", "rest_choose":
			return _pick_glyph(run)
		"act_end": return {"type": "next_act"}
		_:
			return {}


func _choose_room(run, policy: String) -> Dictionary:
	var next: Array = run.next_rooms()
	if next.is_empty(): return {}
	var best: String = ""
	var best_score := -1e9
	var hp_ratio := float(GameState.player_hp) / maxf(1.0, float(GameState.player_max_hp))
	for id: String in next:
		var score := _room_score(run, id, hp_ratio, policy)
		# 一目 lookahead：不要为了进事件而把自己送进精英房。
		for after: String in run.graph.rooms[id].get("next", []):
			var after_kind := str(run.graph.rooms[after].kind)
			match after_kind:
				"elite": score -= 34.0 if hp_ratio < 0.7 else 12.0
				"boss": score -= 120.0
				"battle": score -= 8.0 if hp_ratio < 0.45 else 0.0
				"rest", "shop": score += 5.0
		if score > best_score: best = id; best_score = score
	if best.is_empty(): return {}
	return {"type": "enter_room", "room": best}


func _room_score(run, id: String, hp_ratio: float, policy: String) -> float:
	match str(run.graph.rooms[id].kind):
		"treasure": return 100.0
		"event": return 82.0 if hp_ratio > 0.45 else 92.0
		"shop": return 70.0 if GameState.gold >= 35 else 42.0
		"rest": return 95.0 if hp_ratio < 0.55 else 46.0
		"battle": return 62.0 if hp_ratio > 0.45 else 26.0
		"elite": return 30.0 if hp_ratio > (0.85 if policy == "focused" else 0.72) else -25.0
		"boss": return 1000.0
	return 0.0


func _pick_battle(actions: Array, observed: Dictionary) -> Dictionary:
	var enemy: Dictionary = (observed.get("enemies", []) as Array)[0] if not (observed.get("enemies", []) as Array).is_empty() else {}
	var player: Dictionary = observed.get("player", {})
	var intent := _intent_damage(str(enemy.get("intent", "")))
	var hp := int(player.get("hp", 1))
	var block := int(player.get("block", 0)) + int(player.get("persistent_block", 0))
	var threat := maxi(0, intent - block)
	# 先用词：词同时消耗多枚字，通常比把字块拆成单字更接近正常打法。
	var best: Dictionary = {}
	var best_score := -999.0
	for action: Dictionary in actions:
		if action.get("type") != "play" or action.get("word") == null: continue
		var score := float(action.get("score", 0))
		if score > best_score: best = action; best_score = score
	if not best.is_empty(): return best
	# 没有词时，只打有价值的单字；不要为了“有动作”把牌面拆散。
	best = {}
	best_score = -999.0
	for action: Dictionary in actions:
		if action.get("type") != "play" or action.get("word") != null: continue
		var glyph := _action_glyph(action, observed)
		var score := float(action.get("score", 0))
		if glyph in ["防", "御", "护", "甲", "盾", "反"]: score += threat * 1.8
		if glyph in ["心", "息"]: score += maxi(0, int(player.get("max_hp", hp)) - hp) * 0.5
		if glyph in ["电", "蓄", "充", "能"]: score += 2.0
		if glyph in ["回", "流", "转", "分"]: score += 1.0
		if score > best_score: best = action; best_score = score
	if not best.is_empty() and best_score >= 3.0: return best
	return {"type": "end_turn"}


func _action_glyph(action: Dictionary, observed: Dictionary) -> String:
	var path: Array = action.get("path", [])
	if path.is_empty(): return ""
	var p: Array = path[0]
	var board: Array = observed.get("board", [])
	var y := int(p[1])
	var x := int(p[0])
	if y < 0 or y >= board.size(): return ""
	var row: Array = board[y]
	if x < 0 or x >= row.size(): return ""
	var cell = row[x]
	return str(cell.get("glyph", "")) if cell is Dictionary else ""


func _intent_damage(text: String) -> int:
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
		elif not digits.is_empty():
			break
	return int(digits) if not digits.is_empty() else 0


func _choose_reward(run, policy: String) -> Dictionary:
	var actions: Array = run.legal_actions()
	var deck_size: int = GameState.deck_size()
	var best: Dictionary = {}
	var best_score := -1e9
	for action: Dictionary in actions:
		if action.get("type") != "reward": continue
		var index := int(action.get("index", -1))
		if index < 0 or index >= run.reward_options.size(): continue
		var card: CharacterData = run.reward_options[index]
		var score := _card_score(card)
		if policy == "greedy": score += 50
		if policy == "lean" and (card.rarity < 2 or deck_size >= 14): score -= 30
		if policy == "focused" and (card.rarity < 2 or deck_size >= 16): score -= 35
		if policy == "balanced" and deck_size >= 18 and card.rarity < 2: score -= 25
		if deck_size >= 22 and card.rarity < 3: score -= 60
		if score > best_score: best = action; best_score = score
	if best.is_empty() or (policy != "greedy" and best_score < 6):
		return {"type": "skip"}
	return best


func _choose_shop(run, policy: String, shops: Array) -> Dictionary:
	var actions: Array = run.legal_actions()
	var leave: Dictionary = {}
	var best: Dictionary = {}
	var best_score := -1e9
	var hp_ratio := float(GameState.player_hp) / maxf(1.0, float(GameState.player_max_hp))
	var deck_size: int = GameState.deck_size()
	for action: Dictionary in actions:
		if action.get("type") == "shop_leave": leave = action; continue
		if action.get("type") != "shop_buy": continue
		if GameState.gold < int(action.get("price", 0)): continue
		var kind := str(action.get("kind", ""))
		var score := 0.0
		match kind:
			"buy_char":
				var card: CharacterData = Database.get_character_by_glyph(str(action.get("glyph", "")))
				if card != null and deck_size < (18 if policy != "greedy" else 24):
					score = _card_score(card) - int(action.get("price", 0)) * 0.25
			"heal":
				if hp_ratio < 0.68: score = (1.0 - hp_ratio) * 80.0 - int(action.get("price", 0)) * 0.2
			"remove":
				if deck_size > (14 if policy in ["lean", "focused"] else 19) or _pollution_count() > 0:
					score = 28.0 + _pollution_count() * 12.0 - int(action.get("price", 0)) * 0.15
			"copy":
				if policy != "focused" and deck_size < 18 and GameState.deck_size() > 0:
					score = 18.0 - int(action.get("price", 0)) * 0.2
		if score > best_score: best = action; best_score = score
	if not best.is_empty() and best_score > 2:
		shops.append({"kind": best.get("kind"), "price": best.get("price")})
		return best
	if not leave.is_empty(): return leave
	return {}


func _choose_rest(run, policy: String, rests: Array) -> Dictionary:
	var actions: Array = run.legal_actions()
	var hp_ratio := float(GameState.player_hp) / maxf(1.0, float(GameState.player_max_hp))
	for action: Dictionary in actions:
		if action.get("type") == "leave_service": continue
		match str(action.get("kind", "")):
			"heal":
				var heal_at := 0.82 if policy == "lean" else (0.55 if policy == "focused" else 0.72)
				if hp_ratio < heal_at: rests.append("heal"); return action
			"remove":
				if GameState.deck_size() > (14 if policy in ["lean", "focused"] else 18) or _pollution_count() > 0:
					rests.append("remove"); return action
			"upgrade":
				if policy != "lean" or GameState.deck_size() <= 14: rests.append("upgrade"); return action
	for action: Dictionary in actions:
		if action.get("type") == "leave_service": return action
	return {"type": "leave_service"}


func _choose_event(run, policy: String) -> Dictionary:
	var actions: Array = run.legal_actions()
	if actions.is_empty(): return {}
	var current: Dictionary = run.current_event()
	var options: Array = current.get("options", [])
	var hp_ratio := float(GameState.player_hp) / maxf(1.0, float(GameState.player_max_hp))
	var best: Dictionary = actions[0]
	var best_score := -1e9
	for action: Dictionary in actions:
		var index := int(action.get("index", -1))
		if index < 0 or index >= options.size(): continue
		var score := _effect_score(options[index].get("effects", []), hp_ratio, GameState.deck_size())
		if str(run.event_data.get("id", "")) == "borrow_life":
			var amount := 0
			for effect: Dictionary in options[index].get("effects", []):
				if effect.get("type") == "borrow_life": amount = int(effect.get("amount", 0))
			score = amount * (1.4 if hp_ratio < 0.55 else 0.15) - amount * 0.55
		elif str(run.event_data.get("id", "")) == "debt_collector":
			var debt: int = EVENTS.debt_amount()
			var max_cost := int(ceil(debt / 2.0))
			var text := str(options[index].get("text", ""))
			if text.begins_with("以气血"): score = 12.0 - min(debt, maxi(0, GameState.player_hp - 1)) * 0.35
			elif text.begins_with("以寿命"): score = 12.0 - max_cost * 1.1 - maxi(0, GameState.player_hp - GameState.player_max_hp + max_cost) * 0.2
			else: score = -25.0
		if policy == "greedy": score += 2.0
		if score > best_score: best = action; best_score = score
	return best


func _pick_glyph(run) -> Dictionary:
	var actions: Array = run.legal_actions()
	if actions.is_empty(): return {}
	var counts: Dictionary = GameState.glyph_counts()
	var best: Dictionary = actions[0]
	var best_score := -1e9
	var kind := str(run.pending_kind)
	for action: Dictionary in actions:
		var glyph := str(action.get("glyph", ""))
		var card: CharacterData = Database.get_character_by_glyph(glyph)
		if card == null: continue
		var score := 0.0
		if run.phase == "rest_choose" and kind == "upgrade":
			score = card.rarity * 10.0 + int(counts.get(glyph, 0)) * 0.5
		elif run.phase == "shop_choose" and kind == "copy":
			score = card.rarity * 10.0 + int(counts.get(glyph, 0)) * 0.5
		else:
			score = int(counts.get(glyph, 0)) * 2.0 - card.rarity * 2.0
			if card.is_pollution: score += 100.0
		if score > best_score: best = action; best_score = score
	return best


func _effect_score(effects: Array, hp_ratio: float, deck_size: int) -> float:
	var total := 0.0
	for effect: Dictionary in effects:
		var amount := float(effect.get("amount", 0))
		match str(effect.get("type", "")):
			"heal": total += amount * (1.4 - hp_ratio)
			"heal_percent": total += amount * 0.01 * GameState.player_max_hp * (1.4 - hp_ratio)
			"gold": total += amount * 0.45
			"max_hp": total += amount * 2.4
			"permanent_damage_reduction": total += 14.0 * amount
			"gain_character": total += 7.0
			"gain_relic": total += 32.0
			"remove_relic": total -= 22.0
			"gain_pollution": total -= 8.0 * maxf(1.0, amount)
			"remove_pollution": total += 9.0
			"damage": total -= amount * (1.8 if hp_ratio < 0.5 else 0.9)
			"remove_character": total += 7.0 if deck_size > 18 else -3.0
			"borrow_life": total += amount * (1.1 - hp_ratio) - amount * 0.4
			"repay_life_hp": total -= 18.0
			"repay_life_max_hp": total -= 18.0
			"refuse_debt": total -= 30.0
			"event_temp_hp": total += amount * 0.4
			"if":
				var branch: Array = effect.get("then", []) if EVENTS.condition_met(effect.get("condition", {})) else effect.get("else", [])
				total += _effect_score(branch, hp_ratio, deck_size)
	return total


func _card_score(card: CharacterData) -> float:
	if card == null: return -999.0
	var score := float(card.rarity) * 5.0
	score += minf(10.0, float(_word_count.get(card.glyph, 0)))
	for tag in card.tags:
		if tag in ["attack", "defense", "economy", "energy", "heat", "flow", "space", "utility"]:
			score += 1.0
	if card.is_pollution: score -= 100.0
	return score


func _pollution_count() -> int:
	var total := 0
	for inst: CharInstance in GameState.deck:
		if inst.data != null and inst.data.is_pollution: total += 1
	return total


func _rarity_counts(deck: Array) -> Dictionary:
	var out := {}
	for entry: Dictionary in deck:
		var r := int(entry.rarity)
		out[r] = int(out.get(r, 0)) + 1
	return out


func _write_json(report: Array) -> void:
	var file := FileAccess.open(OUTPUT_JSON, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(report, "  "))
	file.close()


func _write_markdown(report: Array) -> void:
	var file := FileAccess.open(OUTPUT_MD, FileAccess.WRITE)
	if file == null: return
	var lines: Array[String] = ["# 庭院大循环启发式试玩", "", "只通过 RoomRunState 的合法动作推进；不使用直接改血量、铜钱或牌库的作弊。", ""]
	for policy in POLICIES:
		var rows: Array = report.filter(func(r): return r.policy == policy)
		if rows.is_empty(): continue
		var wins := rows.filter(func(r): return r.phase == "victory").size()
		var hp := 0.0; var gold := 0.0; var deck := 0.0; var events := 0.0; var battles := 0.0
		var taken := 0.0; var skipped := 0.0; var earned := 0.0; var spent := 0.0
		for row in rows:
			hp += int(row.hp)
			gold += int(row.gold)
			deck += int(row.deck_size)
			events += (row.events as Array).size()
			battles += int(row.battles)
			taken += int(row.rewards_taken)
			skipped += int(row.rewards_skipped)
			earned += int(row.gold_earned)
			spent += int(row.gold_spent)
		var n := float(rows.size())
		lines.append("## %s" % policy)
		lines.append("")
		lines.append("| 指标 | 平均 |")
		lines.append("|---|---:|")
		lines.append("| 通关 | %.0f%% |" % (100.0 * wins / n))
		lines.append("| 终局气血 | %.1f |" % (hp / n))
		lines.append("| 终局铜钱 | %.1f |" % (gold / n))
		lines.append("| 终局牌数 | %.1f |" % (deck / n))
		lines.append("| 事件次数 | %.1f |" % (events / n))
		lines.append("| 战斗次数 | %.1f |" % (battles / n))
		lines.append("| 拿奖励 / 跳过 | %.1f / %.1f |" % [taken / n, skipped / n])
		lines.append("| 铜钱收入 / 支出 | %.1f / %.1f |" % [earned / n, spent / n])
		lines.append("")
	file.close()
