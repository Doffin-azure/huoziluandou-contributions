extends RefCounted
class_name BattleHarness
## 面向自动化/AI 的战斗接口（Gym 风格，纯逻辑、无 UI、可复现）。
##
##   var h := BattleHarness.new()
##   h.reset({"seed": 1, "deck": [{"glyph":"击","count":2}, ...], "enemies": ["ink_spirit"]})
##   while not h.is_done():
##       var acts := h.legal_actions()
##       h.apply(_pick(acts))
##   var s := h.summary()
##
## 也可从 JSON 场景驱动：见 src/tools/agent_bridge.gd。

static var _trie: Dictionary = {}

var battle: BattleState
var scenario: Dictionary = {}
var seed: int = 0
var invalid_tries: int = 0
var word_plays: int = 0
var single_plays: int = 0


func reset(cfg: Dictionary = {}) -> void:
	scenario = cfg.duplicate(true)
	seed = int(cfg.get("seed", 0))
	invalid_tries = 0
	word_plays = 0
	single_plays = 0

	var rules: BattleRules = Database.rules.duplicate()
	for k in ["opening_draw", "turn_draw", "plays_per_turn", "player_max_hp",
			"starting_gold", "gold_cap_per_battle", "heat_capacity"]:
		if cfg.has(k):
			rules.set(k, int(cfg[k]))

	var deck: Array = []
	for e in cfg.get("deck", _default_deck()):
		if typeof(e) == TYPE_DICTIONARY:
			var cd: CharacterData = Database.get_character_by_glyph(str(e.get("glyph", "")))
			if cd != null:
				for i in int(e.get("count", 1)):
					deck.append(CharInstance.new(cd))
		else:
			var cd2: CharacterData = Database.get_character_by_glyph(str(e))
			if cd2 != null:
				deck.append(CharInstance.new(cd2))

	var enemies: Array = []
	for g in cfg.get("enemies", ["ink_spirit"]):
		var ed: EnemyData = Database.get_enemy(str(g))
		if ed != null:
			enemies.append(ed)

	battle = BattleState.new(rules)
	GameState.player_max_hp = rules.player_max_hp
	GameState.player_hp = rules.player_max_hp
	GameState.gold = int(cfg.get("gold", rules.starting_gold))
	GameState.permanent_damage_reduction = 0
	GameState.gold_growth_percent = 0
	GameState.reinvest_gold = 0
	battle.start(deck, enemies, seed)
	if cfg.has("gold"):
		GameState.gold = int(cfg["gold"])
	if cfg.has("hp"):
		battle.player.hp = int(cfg["hp"])

	# 强制盘面：board = 16 个字形字符串（""=空），行优先
	if cfg.has("board"):
		var spec: Array = cfg["board"]
		for i in battle.board.cells.size():
			battle.board.cells[i] = null
		for i in mini(16, spec.size()):
			var g := str(spec[i])
			if g.is_empty():
				continue
			var cd3: CharacterData = Database.get_character_by_glyph(g)
			if cd3 != null:
				battle.board.cells[i] = CharInstance.new(cd3)


static func _default_deck() -> Array:
	return ["击", "击", "防", "防", "回", "回", "反", "破", "重", "流", "连", "御"]


# ---------------------------------------------------------------- 观察
func is_done() -> bool:
	return battle == null or battle.is_over()


func observe() -> Dictionary:
	var b := battle
	var board_rows: Array = []
	for r in b.board.size:
		var row: Array = []
		for c in b.board.size:
			row.append(_cell_dict(b.board.get_cell(c, r)))
		board_rows.append(row)
	var enemies: Array = []
	for e in b.enemies:
		enemies.append({
			"name": e.display_name, "hp": e.hp, "max_hp": e.max_hp, "block": e.block,
			"alive": e.is_alive(),
			"intent": (b.current_intent(e).intent_text() if e.is_alive() and b.current_intent(e) != null else ""),
		})
	return {
		"turn": b.turn,
		"done": is_done(),
		"board": board_rows,
		"bag": b.bag.size(),
		"discard": b.discard.size(),
		"player": {
			"hp": b.player.hp, "max_hp": b.player.max_hp,
			"block": b.player.block, "persistent_block": b.player.persistent_block,
			"energy": b.player.energy, "heat": b.player.heat, "heat_capacity": b.player.heat_capacity,
			"gold": GameState.gold, "temp_funds": b.player.temp_funds, "equity": b.player.equity,
			"statuses": b.player.statuses.duplicate(),
		},
		"enemies": enemies,
		"abilities": b.abilities.duplicate(),
	}


func _cell_dict(inst: CharInstance) -> Variant:
	if inst == null:
		return null
	return {
		"glyph": inst.glyph(),
		"owner": inst.owner,
		"temporary": inst.temporary,
		"fused": inst.fusion.duplicate(),
		"pollutions": inst.pollutions.duplicate(),
		"temp_uses": inst.temporary_uses,
		"gilded": inst.gilded,
	}


# ---------------------------------------------------------------- 合法动作
## 返回形如：
##  {"type":"play","path":[[x,y]...], "word":"击破"|null, "needs":"none|tile|2x2|empty|enemy|discard|glyph|line|fuse|same|merge"}
##  {"type":"end_turn"}
func legal_actions(limit := 60) -> Array:
	var out: Array = []
	var found := _find_words()
	for f in found:
		if out.size() >= limit:
			break
		var w: WordData = f["word"]
		out.append({
			"type": "play",
			"path": _path_out(f["path"]),
			"word": w.word,
			"needs": _needs_of(w),
			"score": _score_word(w),
		})
	# 单字
	for i in battle.board.cells.size():
		if out.size() >= limit:
			break
		var inst: CharInstance = battle.board.cells[i]
		if inst == null:
			continue
		var solo := 0
		if inst.data != null:
			for e in inst.data.solo_effects:
				solo += absi(e.amount)
		out.append({"type": "play", "path": [_xy_out(battle.board.to_xy(i))], "word": null,
			"needs": "none", "score": solo})
	out.append({"type": "end_turn"})
	return out


static func _xy_out(p: Vector2i) -> Array:
	return [p.x, p.y]


func _path_out(path: Array) -> Array:
	var out: Array = []
	for p in path:
		out.append(_xy_out(p))
	return out


## 把外部传入的坐标（[x,y] 数组 / "(x, y)" 字符串 / Vector2i）统一成 Vector2i
static func _to_xy(v) -> Vector2i:
	if v is Vector2i:
		return v
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	var s := str(v).replace("(", "").replace(")", "").replace(",", " ")
	var parts := s.split(" ", false)
	if parts.size() >= 2:
		return Vector2i(int(parts[0]), int(parts[1]))
	return Vector2i.ZERO


func _needs_of(w: WordData) -> String:
	if not w.interaction.is_empty():
		match w.interaction:
			"reveal_pick_board": return "tile"
			"choose_glyph_empower", "choose_glyph_gild": return "glyph"
			"choose_battle_card_remove": return "battle_card"
			"choose_fuse_pair", "choose_same_pair": return "pair"
			"choose_discard_place": return "discard"
			"choose_line": return "line"
			"choose_merge_flow": return "merge"
	match w.requires_target:
		EffectData.Target.BOARD_TILE: return "tile"
		EffectData.Target.BOARD_2X2: return "2x2"
		EffectData.Target.EMPTY_TILE: return "empty"
		EffectData.Target.ENEMY_GLYPH: return "enemy"
		EffectData.Target.DISCARD_GLYPH: return "discard"
	return "none"


func _score_word(w: WordData) -> int:
	var s := 0
	for e in w.effects:
		s += e.amount
		if e.kind == EffectData.Kind.DAMAGE: s += 6
		if e.kind == EffectData.Kind.DAMAGE_ALL: s += 8
		if e.kind == EffectData.Kind.BLOCK: s += 3
		if e.kind == EffectData.Kind.HEAL: s += 4
	return s


func _find_words() -> Array:
	_build_trie()
	var res: Array = []
	var seen: Dictionary = {}
	for i in battle.board.cells.size():
		if battle.board.cells[i] != null:
			_dfs(battle.board.to_xy(i), _trie, {}, res, seen, 24)
	return res


func _dfs(cell: Vector2i, node: Dictionary, path: Dictionary, res: Array, seen: Dictionary, cap: int) -> void:
	if res.size() >= cap:
		return
	var inst: CharInstance = battle.board.get_xy(cell)
	if inst == null:
		return
	var g: String = inst.glyph()
	if not node.has(g):
		return
	var nn: Dictionary = node[g]
	path[cell] = true
	if nn.has("#"):
		var wid: String = nn["#"]
		if not seen.has(wid):
			seen[wid] = true
			var p: Array = []
			for k in path.keys():
				p.append(k)
			res.append({"word": Database.words[wid], "path": p})
	for n in battle.board.neighbors(cell):
		if not path.has(n):
			_dfs(n, nn, path, res, seen, cap)
	path.erase(cell)


static func _build_trie() -> void:
	if not _trie.is_empty():
		return
	for w in Database.words.values():
		var node := _trie
		for g in w.glyphs:
			if not node.has(g):
				node[g] = {}
			node = node[g]
		node["#"] = w.id


# ---------------------------------------------------------------- 执行
func apply(action: Dictionary) -> Dictionary:
	var type: String = str(action.get("type", "end_turn"))
	if type == "end_turn":
		battle.end_player_turn()
		return {"ok": true, "type": "end_turn", "turn": battle.turn}
	var path: Array = _norm_path(action.get("path", []))
	var target: Dictionary = _norm_target(action.get("target", {}))
	var needs: String = str(action.get("needs", "none"))
	if target.is_empty() and needs != "none":
		target = _auto_target(needs)
	var result: Dictionary = battle.try_play(path, target)
	if not result.ok:
		invalid_tries += 1
		return {"ok": false, "reason": result.reason, "turn": battle.turn}
	if result.word != null:
		word_plays += 1
	else:
		single_plays += 1
	return {"ok": true, "word": (result.word.word if result.word != null else ""),
		"messages": result.messages.duplicate(), "turn": battle.turn}


func _norm_path(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for p in raw:
			out.append(_to_xy(p))
	return out


func _norm_target(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		if k in ["tile", "tile2", "enemy_glyph", "cell1", "cell2"]:
			out[k] = _to_xy(d[k])
		else:
			out[k] = d[k]
	return out


## 为需要目标的动作自动挑一个合法目标（批量测试用）。
func _auto_target(needs: String) -> Dictionary:
	var b := battle
	match needs:
		"tile", "enemy":
			for i in b.board.cells.size():
				var inst: CharInstance = b.board.cells[i]
				if inst != null and (needs == "tile" or inst.is_enemy_owned()):
					var p: Vector2i = b.board.to_xy(i)
					return {"tile": p, "enemy_glyph": p}
		"empty":
			var empties: Array = b.board.empty_indices()
			if not empties.is_empty():
				return {"tile": empties[0]}
		"2x2", "line":
			return {"tile": Vector2i(0, 0), "row": 0}
		"discard":
			var list: Array = b.discard_instances()
			if not list.is_empty():
				return {"discard_index": 0, "place_uid": int(list[0]["uid"])}
		"pair":
			for i in b.board.cells.size():
				var c1: CharInstance = b.board.cells[i]
				if c1 == null or not c1.is_player_owned():
					continue
				for n in b.board.neighbors(b.board.to_xy(i)):
					var c2: CharInstance = b.board.get_xy(n)
					if c2 != null and c2.is_player_owned():
						return {"tile": b.board.to_xy(i), "tile2": n}
		"glyph":
			var counts := GameState.glyph_counts()
			if not counts.is_empty():
				return {"empower_glyph": str(counts.keys()[0]), "gild_glyph": str(counts.keys()[0])}
		"battle_card":
			var bc: Dictionary = b.battle_card_counts()
			if not bc.is_empty():
				return {"remove_glyph": str(bc.keys()[0])}
		"merge":
			if b.has_adjacent_empty_pair() and not b.bag.is_empty() and not b.discard.is_empty():
				var empties2: Array = b.board.empty_indices()
				return {"tile": empties2[0], "cell1": empties2[0], "cell2": empties2[0],
					"merge_discard_uid": int(b.discard[0].uid)}
	return {}


func summary() -> Dictionary:
	return {
		"seed": seed,
		"victory": (battle.is_victory() if battle != null else false),
		"turns": (battle.turn if battle != null else 0),
		"player_hp": (battle.player.hp if battle != null else 0),
		"word_plays": word_plays,
		"single_plays": single_plays,
		"invalid_tries": invalid_tries,
		"gold_earned": (battle.gold_earned if battle != null else 0),
	}
