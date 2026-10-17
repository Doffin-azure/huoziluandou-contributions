extends RefCounted
class_name DebugCommands
## 调试命令注册表。新增命令 = 在 _register() 里加一行。
## 只在调试构建由 DebugConsole 安装。

static var _cmds: Dictionary = {}


static func is_empty() -> bool:
	return _cmds.is_empty()


static func register(name: String, help: String, fn: Callable) -> void:
	_cmds[name] = {"help": help, "fn": fn}


static func execute(line: String) -> Array:
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty():
		return []
	var name: String = parts[0]
	if name.begins_with("/"):
		name = name.substr(1)
	if name == "help" or name == "?":
		return _help()
	if not _cmds.has(name):
		return ["未知命令：/%s（用 /help 查看）" % name]
	var args: Array = []
	for i in range(1, parts.size()):
		args.append(parts[i])
	return _cmds[name]["fn"].call(args)


static func _help() -> Array:
	var out: Array = ["可用命令："]
	var keys: Array = _cmds.keys()
	keys.sort()
	for k in keys:
		out.append("  /%-14s %s" % [k, _cmds[k]["help"]])
	return out


# ---------------------------------------------------------------- 上下文
static func _battle() -> BattleState:
	var s = Router.current
	if s != null and s.get("battle") != null:
		return s.battle
	return null


static func _refresh() -> void:
	var s = Router.current
	if s != null and s.has_method("_refresh_all"):
		s.call("_refresh_all")


static func _ck() -> Array:
	return ["（当前不在战斗中）"]


## 把调试命令参数解析成字形列表：逐字拆分，支持 "火x2" / "火*2" / 逗号分隔。
static func _parse_glyphs(args: Array) -> Array:
	var out: Array = []
	for tok in args:
		var s := str(tok).replace("，", ",")
		var parts: Array = s.split(",", false) if s.contains(",") else [s]
		for p in parts:
			var t := str(p).strip_edges()
			if t.is_empty():
				continue
			var mult := 1
			var glyph := t
			var m := t.find("x")
			if m < 0:
				m = t.find("*")
			if m > 0:
				glyph = t.substr(0, m)
				mult = maxi(1, int(t.substr(m + 1)))
			elif t.length() > 1 and t.substr(t.length() - 1, 1).is_valid_int():
				glyph = t.substr(0, t.length() - 1)
				mult = maxi(1, int(t.substr(t.length() - 1, 1)))
			for k in mult:
				if Database.get_character_by_glyph(glyph) != null:
					out.append(glyph)
	return out


static func _glyph(args: Array, i: int) -> String:
	return str(args[i]) if args.size() > i else ""


static func _int(args: Array, i: int, d: int) -> int:
	return int(args[i]) if args.size() > i else d


# ---------------------------------------------------------------- 注册
static func install() -> void:
	if not _cmds.is_empty():
		return

	# ---- 通用 ----
	register("help", "列出命令", func(_a): return _help())
	register("cls", "清屏", func(_a): 
		if Debug != null: Debug.clear_log()
		return [])
	register("refresh", "刷新战斗界面", func(_a): _refresh(); return ["已刷新"])
	register("style", "切换风格 paper|neon", func(a):
		var id: String = _glyph(a, 0)
		if id != "paper" and id != "neon":
			return ["用法：/style paper|neon"]
		Ink.apply_style(GameStyle.get_style(id))
		Router.goto(Router.current_path)
		return ["风格已切到 " + id])
	register("seed", "固定本场随机种子", func(a):
		var b := _battle()
		if b == null: return _ck()
		b.rng.seed = _int(a, 0, 0)
		return ["种子 = %d" % b.rng.seed])
	register("custom", "自定义字袋重开一局：/custom 火火电电 或 /custom 火x2,电x2（无参数=查看当前）", func(a):
		if a.is_empty():
			return ["当前字袋：%s" % JSON.stringify(GameState.glyph_counts())]
		var glyphs := _parse_glyphs(a)
		if glyphs.is_empty():
			return ["用法：/custom 火火电电 或 /custom 火x2,电,回"]
		GameState.start_new_run("v03", glyphs)
		Router.goto("res://src/screens/map_screen.gd")
		return ["自定义字袋 %d 枚，已开新局" % GameState.deck_size()])

	# ---- A. 数值 / 规则 ----
	register("hp", "设置当前生命", func(a):
		var b := _battle()
		if b == null: return _ck()
		b.player.hp = clampi(_int(a, 0, b.player.hp), 0, b.player.max_hp)
		_refresh()
		return ["HP = %d" % b.player.hp])
	register("maxhp", "设置生命上限", func(a):
		var b := _battle()
		if b == null: return _ck()
		b.player.max_hp = maxi(1, _int(a, 0, b.player.max_hp))
		b.player.hp = mini(b.player.hp, b.player.max_hp)
		GameState.player_max_hp = b.player.max_hp
		_refresh()
		return ["MaxHP = %d" % b.player.max_hp])
	register("gold", "设置金币", func(a):
		GameState.gold = maxi(0, _int(a, 0, GameState.gold))
		EventBus.gold_changed.emit(GameState.gold)
		_refresh()
		return ["金币 = %d" % GameState.gold])
	register("heat", "设置热度", func(a):
		var b := _battle()
		if b == null: return _ck()
		b.player.heat = maxi(0, _int(a, 0, b.player.heat))
		_refresh()
		return ["热度 = %d" % b.player.heat])
	register("heatcap", "设置热容", func(a):
		var b := _battle()
		if b == null: return _ck()
		b.player.heat_capacity = maxi(1, _int(a, 0, b.player.heat_capacity))
		_refresh()
		return ["热容 = %d" % b.player.heat_capacity])
	register("energy", "设置储能", func(a):
		var b := _battle()
		if b == null: return _ck()
		b.player.energy = maxi(0, _int(a, 0, b.player.energy))
		_refresh()
		return ["储能 = %d" % b.player.energy])
	register("equity", "设置股权", func(a):
		var b := _battle()
		if b == null: return _ck()
		b.player.equity = maxi(0, _int(a, 0, b.player.equity))
		_refresh()
		return ["股权 = %d" % b.player.equity])
	register("funds", "设置临时资金", func(a):
		var b := _battle()
		if b == null: return _ck()
		b.player.temp_funds = maxi(0, _int(a, 0, b.player.temp_funds))
		_refresh()
		return ["临时资金 = %d" % b.player.temp_funds])
	register("draw", "手动补字 N", func(a):
		var b := _battle()
		if b == null: return _ck()
		var n: int = b.draw_to_board(_int(a, 0, 3))
		_refresh()
		return ["补 %d 字" % n])
	register("turn-draw", "设置每回合基础补字", func(a):
		Database.rules.turn_draw = maxi(0, _int(a, 0, Database.rules.turn_draw))
		_refresh()
		return ["每回合补字 = %d" % Database.rules.turn_draw])
	register("opening", "设置开局落盘数", func(a):
		Database.rules.opening_draw = maxi(0, _int(a, 0, Database.rules.opening_draw))
		return ["开局落盘 = %d（下一场生效）" % Database.rules.opening_draw])
	register("plays", "设置每回合出字次数（0=无限）", func(a):
		Database.rules.plays_per_turn = maxi(0, _int(a, 0, Database.rules.plays_per_turn))
		var b := _battle()
		if b != null: b.rules.plays_per_turn = Database.rules.plays_per_turn
		_refresh()
		return ["每回合出字 = %d" % Database.rules.plays_per_turn])
	register("goldcap", "设置每战金币收入上限（0 = 不限）", func(a):
		Database.rules.gold_cap_per_battle = maxi(0, _int(a, 0, Database.rules.gold_cap_per_battle))
		var b := _battle()
		if b != null: b.rules.gold_cap_per_battle = Database.rules.gold_cap_per_battle
		return ["金币上限 = %s" % ("不限" if Database.rules.gold_cap_per_battle <= 0 else str(Database.rules.gold_cap_per_battle))])

	# ---- B. 盘面 ----
	register("board", "打印字盘（0 基坐标）", func(_a): return _print_board())
	register("set", "在格放字：/set r c 字", func(a):
		var b := _battle()
		if b == null: return _ck()
		var r := _int(a, 0, -1)
		var c := _int(a, 1, -1)
		var g := _glyph(a, 2)
		if r < 0 or c < 0 or g.is_empty():
			return ["用法：/set r c 字"]
		var cd: CharacterData = Database.get_character_by_glyph(g)
		if cd == null:
			return ["没有这个字：" + g]
		b.board.set_cell(c, r, CharInstance.new(cd))
		_refresh()
		return ["(%d,%d) = %s" % [r, c, g]])
	register("clear", "清空盘面（不回收）", func(_a):
		var b := _battle()
		if b == null: return _ck()
		for i in b.board.cells.size(): b.board.cells[i] = null
		_refresh()
		return ["盘面已清空"])
	register("fill", "补满盘面", func(_a):
		var b := _battle()
		if b == null: return _ck()
		var n: int = b.draw_to_board(16)
		_refresh()
		return ["补 %d 字" % n])
	register("give4", "在空格生成 4 个同字", func(a):
		var b := _battle()
		if b == null: return _ck()
		var g := _glyph(a, 0)
		var cd: CharacterData = Database.get_character_by_glyph(g)
		if cd == null: return ["用法：/give4 字"]
		var empties: Array = b.board.empty_indices()
		var added := 0
		for i in mini(4, empties.size()):
			b.board.set_xy(empties[i], CharInstance.new(cd))
			added += 1
		_refresh()
		return ["生成 %d 个【%s】" % [added, g]])
	register("pollute", "给格加污染：/pollute r c rush|block|scorch", func(a):
		var b := _battle()
		if b == null: return _ck()
		var r := _int(a, 0, -1); var c := _int(a, 1, -1); var pid := _glyph(a, 2)
		if r < 0 or c < 0 or pid.is_empty(): return ["用法：/pollute r c rush|block|scorch"]
		var inst: CharInstance = b.board.get_cell(c, r)
		if inst == null: return ["该格没有字"]
		inst.add_pollution(pid)
		_refresh()
		return ["(%d,%d) 附加 %s" % [r, c, pid]])
	register("enemy-add", "空格注入敌方字：/enemy-add 字 [污染]", func(a):
		var b := _battle()
		if b == null: return _ck()
		var g := _glyph(a, 0)
		var cd: CharacterData = Database.get_character_by_glyph(g)
		if cd == null: return ["用法：/enemy-add 字 [污染]"]
		var empties: Array = b.board.empty_indices()
		if empties.is_empty(): return ["没有空格"]
		var inst := CharInstance.new(cd)
		inst.owner = CharInstance.Owner.ENEMY
		if a.size() > 1: inst.add_pollution(str(a[1]))
		b.board.set_xy(empties[0], inst)
		b.temp_chars.append(inst)
		_refresh()
		return ["注入敌方【%s】" % g])
	register("gravity", "全盘向下重力", func(_a):
		var b := _battle()
		if b == null: return _ck()
		b.apply_gravity(); _refresh(); return ["重力"])
	register("rotate", "2×2 顺时针：/rotate r c", func(a):
		var b := _battle()
		if b == null: return _ck()
		b.rotate_2x2(Vector2i(_int(a, 1, 0), _int(a, 0, 0)))
		_refresh(); return ["已旋转"])
	register("reverse", "反转行/列：/reverse row|col i", func(a):
		var b := _battle()
		if b == null: return _ck()
		var kind := _glyph(a, 0); var i := _int(a, 1, 0)
		for j in 2:
			var a1: Vector2i = Vector2i(j, i) if kind == "row" else Vector2i(i, j)
			var b1: Vector2i = Vector2i(3 - j, i) if kind == "row" else Vector2i(i, 3 - j)
			var t = b.board.get_xy(a1); b.board.set_xy(a1, b.board.get_xy(b1)); b.board.set_xy(b1, t)
		_refresh(); return ["已反转 %s %d" % [kind, i]])
	register("fuse", "直接融合：/fuse r1 c1 r2 c2", func(a):
		var b := _battle()
		if b == null: return _ck()
		var res: Dictionary = b.fuse_cards(Vector2i(_int(a, 1, 0), _int(a, 0, 0)), Vector2i(_int(a, 3, 0), _int(a, 2, 0)))
		_refresh()
		return [str(res.get("msg", "?"))])

	# ---- C. 战斗流程 ----
	register("endturn", "结束我方回合（敌人正常行动）", func(_a):
		var s = Router.current
		if s != null and s.has_method("_on_end_turn"):
			s.call("_on_end_turn")
			return ["已结束回合"]
		return _ck())
	register("nextturn", "跳过敌人，直接开新回合", func(_a):
		var b := _battle()
		if b == null: return _ck()
		b.begin_player_turn(true)
		_refresh(); return ["已进入回合 %d" % b.turn])
	register("win", "直接判定胜利", func(_a):
		var b := _battle()
		if b == null: return _ck()
		for e in b.enemies: e.hp = 0
		var s = Router.current
		if s != null and s.has_method("_check_battle_over"): s.call("_check_battle_over")
		return ["已判定胜利"])
	register("lose", "直接判定失败", func(_a):
		var b := _battle()
		if b == null: return _ck()
		b.player.hp = 0
		var s = Router.current
		if s != null and s.has_method("_check_battle_over"): s.call("_check_battle_over")
		return ["已判定失败"])
	register("heal", "回满生命", func(_a):
		var b := _battle()
		if b == null: return _ck()
		b.player.hp = b.player.max_hp
		_refresh(); return ["已回满"])
	register("god", "无敌开关（玩家免伤）", func(_a):
		var b := _battle()
		if b == null: return _ck()
		b.player.god_mode = not b.player.god_mode
		return ["无敌 = " + str(b.player.god_mode)])
	register("status", "状态：/status add|clear id [n]", func(a):
		var b := _battle()
		if b == null: return _ck()
		var op := _glyph(a, 0); var sid := _glyph(a, 1)
		if op == "add":
			b.player.add_status(sid, _int(a, 2, 1))
		elif op == "clear":
			b.player.statuses.clear()
		else:
			return ["用法：/status add|clear id [n]"]
		_refresh(); return ["已更新状态"])
	register("intent", "打印敌人行动序列", func(_a):
		var b := _battle()
		if b == null: return _ck()
		var out: Array = []
		for e in b.enemies:
			if not e.is_alive(): continue
			var seq: Array = []
			for m in e.enemy_data.moves:
				seq.append(m.intent_text())
			out.append("%s：%s" % [e.display_name, " → ".join(seq)])
		return out)

	# ---- D. 字袋 / 构筑 ----
	register("deck", "打印永久字袋", func(_a):
		var counts := GameState.glyph_counts()
		var out: Array = ["字袋 %d 枚：" % GameState.deck_size()]
		for g in counts.keys():
			out.append("  %s ×%d" % [g, counts[g]])
		return out)
	register("relic", "遗物：/relic（列出）| /relic 名字或id（得到）| /relic - 名字或id（移除）| /relic all", func(a):
		if a.is_empty():
			var out: Array = ["已有：" + ("、".join(GameState.relics.map(func(r): return Relics.name_of(r))) if not GameState.relics.is_empty() else "无")]
			for id in Relics.DEFS:
				out.append("%s　%s　%d档" % [id, Relics.text(id), Relics.TIER[id]])
			return out
		var drop: bool = a[0] == "-"
		var key: String = a[1] if drop and a.size() > 1 else a[0]
		var ids: Array = Relics.DEFS.keys() if key == "all" else Relics.DEFS.keys().filter(func(id): return id == key or Relics.name_of(id) == key)
		if ids.is_empty():
			return ["没有遗物「%s」，/relic 查看全部" % key]
		var done: Array = []
		for id in ids:
			if drop:
				if GameState.remove_relic(id): done.append(Relics.name_of(id))
			elif GameState.add_relic(id):
				done.append(Relics.name_of(id))
				if Relics.needs_bind(id) and not GameState.deck.is_empty() and not GameState.relic_binds.has(id):
					GameState.bind_relic(id, GameState.deck[0].id())
		var s = Router.current
		if s != null and s.has_method("refresh"): s.call("refresh")
		_refresh()
		return [("移除：" if drop else "得到：") + ("、".join(done) if not done.is_empty() else "无变化（绑定类自动绑字袋第一枚；战斗中改动下一场生效）")])
	register("tray", "远征字匣放字：/tray 火热强", func(a):
		var ex: Expedition = GameState.expedition
		if ex == null or a.is_empty(): return ["用法：在远征地图里 /tray 火热强"]
		for g in "".join(a):
			if Database.get_character_by_glyph(g) != null: ex.tray.append(g)
		var s = Router.current
		if s != null and s.has_method("refresh"): s.call("refresh")
		return ["字匣：" + "".join(ex.tray)])
	register("forge", "远征：在当前位置打开熔炉面板（需站在熔炉上使用）", func(_a):
		var ex: Expedition = GameState.expedition
		if ex == null: return ["只在远征地图里可用"]
		ex.push_panel({"kind": "forge", "k": ex.pos})
		var s = Router.current
		if s != null and s.has_method("refresh"): s.call("refresh")
		return ["熔炉已打开：在字匣点两枚字"])
	register("shop", "远征：在当前位置打开商店面板", func(_a):
		var ex: Expedition = GameState.expedition
		if ex == null: return ["只在远征地图里可用"]
		ex.push_panel({"kind": "shop"})
		var s = Router.current
		if s != null and s.has_method("refresh"): s.call("refresh")
		return ["商店已打开"])
	register("add", "加字：/add 字 [n]", func(a):
		var g := _glyph(a, 0)
		var cd: CharacterData = Database.get_character_by_glyph(g)
		if cd == null: return ["用法：/add 字 [n]"]
		GameState.add_character(cd, _int(a, 1, 1))
		_refresh(); return ["已加【%s】×%d" % [g, _int(a, 1, 1)]])
	register("remove", "删字：/remove 字", func(a):
		var g := _glyph(a, 0)
		var cd: CharacterData = Database.get_character_by_glyph(g)
		if cd == null: return ["用法：/remove 字"]
		var ok := GameState.remove_character_id(cd.id)
		_refresh(); return ["删除【%s】= %s" % [g, str(ok)]])
	register("clone", "复制字：/clone 字", func(a):
		var g := _glyph(a, 0)
		var cd: CharacterData = Database.get_character_by_glyph(g)
		if cd == null: return ["用法：/clone 字"]
		GameState.add_character(cd, 1)
		_refresh(); return ["已复制【%s】" % g])
	register("gild", "镀金字：/gild 字", func(a):
		var g := _glyph(a, 0)
		var n := 0
		for inst in GameState.deck:
			if inst.glyph() == g:
				inst.gilded = true; n += 1
		var b := _battle()
		if b != null:
			for c in b.board.cells:
				if c != null and c.glyph() == g: c.gilded = true
		_refresh(); return ["镀金【%s】×%d" % [g, n]])

	# ---- E. 词 / 字查询 ----
	register("word", "查词：/word 击破", func(a):
		var w: WordData = Database.get_word_by_glyphs_string(_glyph(a, 0))
		if w == null: return ["没有这个词"]
		var out: Array = ["《%s》 体系=%s 交互=%s 目标=%d" % [w.word, w.group, w.interaction, w.requires_target]]
		out.append("摘要：" + w.effect_summary)
		for e in w.effects:
			out.append("  · " + e.describe())
		return out)
	register("char", "查字：/char 击", func(a):
		var g := _glyph(a, 0)
		var cd: CharacterData = Database.get_character_by_glyph(g)
		if cd == null: return ["没有这个字"]
		var words: Array = []
		for w in Database.words.values():
			if w.glyphs.has(g): words.append(w.word)
		var out: Array = ["【%s】id=%s 标签=%s 稀有度=%d" % [g, cd.id, "、".join(cd.tags), cd.rarity]]
		var solo_txt := "（无）"
		if not cd.solo_effects.is_empty():
			var sp: Array = []
			for e in cd.solo_effects:
				sp.append(e.describe())
			solo_txt = "；".join(sp)
		out.append("单字：" + solo_txt)
		out.append("含此字的词（%d）：%s" % [words.size(), " ".join(words)])
		return out)
	register("words-of", "列出含某字的词", func(a):
		var g := _glyph(a, 0)
		var words: Array = []
		for w in Database.words.values():
			if w.glyphs.has(g): words.append(w.word)
		return ["含【%s】的词：%s" % [g, " ".join(words)]])
	register("reload", "重新加载 resources", func(_a):
		Database.reload()
		return ["已重载：字 %d / 词 %d（界面需重新进入才生效）" % [Database.characters.size(), Database.words.size()]])


# ---------------------------------------------------------------- 辅助
static func _print_board() -> Array:
	var b := _battle()
	if b == null: return _ck()
	var out: Array = ["　  c0    c1    c2    c3"]
	for r in 4:
		var line := "r%d " % r
		for c in 4:
			var inst: CharInstance = b.board.get_cell(c, r)
			if inst == null:
				line += "  ·   "
				continue
			var tag := inst.glyph()
			if inst.is_fused():
				tag += "*F"
			if inst.temporary:
				tag += "*T"
			if inst.is_enemy_owned():
				tag += "*E"
			if not inst.pollutions.is_empty():
				tag += "!" + "".join(inst.pollutions)
			if inst.temporary_uses > 0:
				tag += "^%d" % inst.temporary_uses
			if inst.gilded:
				tag += "$"
			line += "%-6s" % tag
		out.append(line)
	out.append("（F=融合 T=临时 E=敌方 !=污染 ^=层数 $=镀金）")
	return out
